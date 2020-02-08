$NOLIST
$MOD9351
$LIST

; Clock speed
XTAL EQU 14746000
; TIMER 0 AND 1 INCLUDED IN timers.inc

; FOR SOUNDINIT.inc ;
CCU_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
CCU_RELOAD  EQU ((65536-((XTAL/(2*CCU_RATE)))))

; Serial
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)
; SPI
CE_ADC    EQU  P2.7
MY_MOSI   EQU  P2.6
MY_MISO   EQU  P2.5
MY_SCLK   EQU  P2.4
; Pin Assignments
LCD_RS equ P0.5
LCD_RW equ P0.6
LCD_E  equ P0.7
LCD_D4 equ P1.2
LCD_D5 equ P1.3
LCD_D6 equ P1.4
LCD_D7 equ P1.6
; Button ADC channels
B1_ADC equ 1
B2_ADC equ 2
B3_ADC equ 3
B4_ADC equ 4
; soundinit.inc buttons
FLASH_CE    EQU P1.0
SOUND       EQU P1.1

; VECTOR TABLE =================================================================
; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector
org 0x001B
	ljmp Timer1_ISR

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023
	reti

; ==============================================================================
dseg at 0x30
; PWM output (to oven) variables
PWM_Duty_Cycle255: ds 1
PWM_Cycle_Count: ds 1
; Timing Variables
Count10ms: ds 1
Count1s: ds 2 ; 2 byte value
Count_state: ds 1

; for soundinit.inc ;
w: ds 3 ; 24-bit play counter.  Decremented in CCU ISR

;soak_time_total: ds 1
;reflow_time_total: ds 1

; Temperature profile parameters
soak_temp: ds 1
soak_time: ds 1
reflow_temp: ds 1
reflow_time: ds 1

FSM_state_decider: ds 1 ; HELPS US SEE WHICH STATE WE ARE IN
; Button FSM Variables:
; Each FSM has its own timer and its own state counter
BFSM1_state: ds 1
BFSM2_state: ds 1
BFSM3_state: ds 1
BFSM4_state: ds 1
BFSM1_timer: ds 1
BFSM2_timer: ds 1
BFSM3_timer: ds 1
BFSM4_timer: ds 1
; 32 bit Math variables:
x:	ds 4
y:	ds 4
bcd:ds 5
; ADC reading
MCP3008_reading: ds 2

bseg
; Flag set by timer 1 every half second (can be changed if needed)
seconds_flag: dbit 1
; Buttons raw flag
Button1_raw: dbit 1
Button2_raw: dbit 1
Button3_raw: dbit 1
Button4_raw: dbit 1
; For each pushbutton we have a flag.  The corresponding FSM will set this
; flags to one when a valid press of the pushbutton is detected.
; THIS WILL BE CHANGED ACCORDING TO OUR OWN KEYS ;
B1_flag_bit: dbit 1
B2_flag_bit: dbit 1
B3_flag_bit: dbit 1
B4_flag_bit: dbit 1
mf:	dbit 1

; ==============================================================================
cseg
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD functions and utility macros
$include(math32.inc)
$include(timers.inc)
$include(button_ops.inc)
$include(soundinit.inc)
$include(LCD_ops.inc)
$LIST

; The 8-bit hex number passed in the accumulator is converted to
; BCD and stored in [R1, R0]
Hex_to_bcd_8bit:
	mov b, #100
	div ab
	mov R1, a   ; After dividing, a has the 100s
	mov a, b    ; Remainder is in register b
	mov b, #10
	div ab ; The tens are stored in a, the units are stored in b
	swap a
	anl a, #0xf0
	orl a, b
	mov R0, a
	ret

; SPI ==========================================================================
;Init_SPI:
	;setb MY_MISO	 	  ; Make MISO an input pin
	;clr MY_SCLK           ; Mode 0,0 default
	;ret
Init_SPI:
    ; Configure MOSI (P2.2), CS* (P2.4), and SPICLK (P2.5) as push-pull outputs (see table 42, page 51)
    anl P2M1, #low(not(00110100B))
    orl P2M2, #00110100B
    ; Configure MISO (P2.3) as input (see table 42, page 51)
    orl P2M1, #00001000B
    anl P2M2, #low(not(00001000B))
    ; Configure SPI
    mov SPCTL, #11010000B ; Ignore /SS, Enable SPI, DORD=0, Master=1, CPOL=0, CPHA=0, clk/4
    ret

DO_SPI_G:
	push acc
	mov R1, #0			  ; Received byte stored in R1
	mov R2, #8            ; Loop counter (8-bits)

DO_SPI_G_LOOP:
	mov a, R0             ; Byte to write is in R0
	rlc a                 ; Carry flag has bit to write
	mov R0, a
	mov MY_MOSI, c
	setb MY_SCLK          ; Transmit
	mov c, MY_MISO        ; Read received bit
	mov a, R1             ; Save received bit in R1
	rlc a
	mov R1, a
	clr MY_SCLK
	djnz R2, DO_SPI_G_LOOP
	pop acc
	ret

;Read_MCP3008(channel)
Read_MCP3008 MAC
    push ar7
    mov r7, #%0
    lcall ?Read_MCP3008
    pop ar7
ENDMAC

?Read_MCP3008:
	mov r0, #1 ; first byte to send
	clr CE_ADC
	lcall DO_SPI_G
	; ignore received data for that frame; it's garbage
    mov a, r7 ; get channel to read
    swap a
    orl a, #0x80
	mov r0, a ; specify single ended read on channel specified
	lcall DO_SPI_G
	mov a, r1 ; r1 holds received byte
	anl a, #0x03 ; only keep 2 least significant bits
	mov MCP3008_reading+1, a ; save upper 2 bits
	mov r0, #0x55 ; don't care what is sent here (so send alternating bits)
	lcall DO_SPI_G
	mov a, r1 ; r1 holds received byte
	mov MCP3008_reading+0, a ; save lower 2 bits
	setb CE_ADC
	ret

Calculate_Temp:
	mov x, MCP3008_reading
	mov x+1, MCP3008_reading+1
	mov x+2, #0
	mov x+3, #0
	load_y(311669)
	lcall mul32
	load_y(1000000)
	lcall div32
	lcall hex2bcd
	; Send_BCD(bcd)
	; mov a, #'\r'
	; lcall putchar
	; mov a, #'\n'
	; lcall putchar
	ret
; SERIAL =======================================================================
; Configure the serial port and baud rate
InitSerialPort:
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 ; Turn-on the baud rate generator
	mov	SCON,#0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	mov	P1M1,#0x00 ; Enable pins RxD and TXD
	mov	P1M2,#0x00 ; Enable pins RxD and TXD
	ret

; Send a character using the serial port
;JESUS'S NEW CODE IMPLEMENTS PUTCHAR AND GETCHAR DIFFERENTLY;
;IF THEY DON'T WORK, USE THE NEW ONES WHICH HAVE L1 COMPONENTS;
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

getchar:
	jnb RI, getchar
	clr RI
	mov a, SBUF
	ret

; BUTTONS ======================================================================
Check_Buttons:
    Read_MCP3008(B1_ADC)
    mov a, MCP3008_reading+1 ; get upper byte of ADC reading
    rr a ; get MSB of reading (the 2^9=512 valued bit)
    jnz button1_released ; jumpd if the ADC reading is less than 512
    setb Button1_raw
    sjmp read_button2
button1_released:
    clr Button1_raw
read_button2:
    Read_MCP3008(B2_ADC)
    mov a, MCP3008_reading+1 ; get upper byte of ADC reading
    rr a ; get MSB of reading (the 2^9=512 valued bit)
    jnz button2_released ; jumpd if the ADC reading is less than 512
    setb Button2_raw
    sjmp read_button3
button2_released:
    clr Button2_raw
read_button3:
    Read_MCP3008(B3_ADC)
    mov a, MCP3008_reading+1 ; get upper byte of ADC reading
    rr a ; get MSB of reading (the 2^9=512 valued bit)
    jnz button3_released ; jumpd if the ADC reading is less than 512
    setb Button3_raw
    sjmp read_button4
button3_released:
    clr Button3_raw
read_button4:
    Read_MCP3008(B4_ADC)
    mov a, MCP3008_reading+1 ; get upper byte of ADC reading
    rr a ; get MSB of reading (the 2^9=512 valued bit)
    jnz button4_released ; jumpd if the ADC reading is less than 512
    setb Button4_raw
    sjmp read_button_done
button4_released:
    clr Button4_raw

read_button_done:
    Button_FSM(BFSM1_state, BFSM1_timer, Button1_raw, B1_flag_bit)
    Button_FSM(BFSM2_state, BFSM2_timer, Button2_raw, B2_flag_bit)
    Button_FSM(BFSM3_state, BFSM3_timer, Button3_raw, B3_flag_bit)
    Button_FSM(BFSM4_state, BFSM4_timer, Button4_raw, B4_flag_bit)
    ret

; MAIN =========================================================================
main:
	; Initialization of hardware
    mov SP, #0x7F
    lcall Timer0_Init
    lcall LCD_4BIT
    lcall InitSerialPort
    lcall SendString
    lcall Init_SPI
    setb EA ; Enable Global interrupts

    ; Initialize variables
    ; Default Temperature profile parameters
    mov soak_temp, #80
    mov soak_time, #60
    mov reflow_temp, #230
    mov reflow_time, #40
    clr a
    mov PWM_Duty_Cycle255, a
    mov Count10ms, a
    mov Count1s+0, a
    mov Count1s+1, a
    mov Count_state, a
    mov FSM_state_decider, a
    mov BFSM1_state, a
    mov BFSM2_state, a
    mov BFSM3_state, a
    mov BFSM4_state, a
    mov BFSM1_timer, a
    mov BFSM2_timer, a
    mov BFSM3_timer, a
    mov BFSM4_timer,a
    mov MCP3008_reading+0, a
    mov MCP3008_reading+1, a
    Load_X(0)
    Load_y(0)


	; After initialization the program stays in this 'forever' loop
loop:
    mov FSM_state_decider, #0
    mov PWM_Duty_Cycle255, #0
	mov a, FSM_state_decider
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_standby) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    ; End Display_init_main_screen
FSM_RESET:
    mov a, FSM_state_decider
    cjne a, #0, FSM_RAMP_TO_SOAK
    clr a
    mov Count1s, a
    mov Count1s+1, a
    mov Count_state, a
    lcall Check_Buttons
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    Read_MCP3008(0)
    lcall Calculate_Temp
    ; Update temperature reading
    Set_Cursor(1,11)
    mov a, x
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)
    ; done updating temperature reading
    jnb B1_flag_bit, FSM_RESET
	inc FSM_state_decider
    clr B1_flag_bit
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_ramp1) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    ; End Display_init_main_screen

FSM_RAMP_TO_SOAK: ;  should be done in 1-3 seconds
    mov a, FSM_state_decider
	cjne a, #1, FSM_HOLD_TEMP_AT_SOAK_JUMP_TO
	mov PWM_Duty_Cycle255, #255
    Read_MCP3008(0)
    lcall Calculate_Temp
    lcall Display_update_main_screen
    clr a
    mov a, Count_state
    cjne a, #60, Continue
    load_y(50)
    lcall x_lt_y
    jnb mf, Continue

FSM_ERROR:
    mov PWM_Duty_Cycle255, #0
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_error) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    ; End Display_init_main_screen
    sjmp $

FSM_HOLD_TEMP_AT_SOAK_JUMP_TO:
	ljmp FSM_HOLD_TEMP_AT_SOAK

Continue:
    clr a
    load_y(150)
    lcall x_gteq_y
    jnb mf, FSM_RAMP_TO_SOAK_JUMP_TO
    inc FSM_state_decider
    clr a
    mov Count_state, a
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_soak) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    sjmp FSM_HOLD_TEMP_AT_SOAK
    ; End Display_init_main_screen
    ;check for conditions and keep calling measure_temp
      ;stop around 150 +-20 degrees

FSM_RAMP_TO_SOAK_JUMP_TO:
	ljmp FSM_RAMP_TO_SOAK

FSM_HOLD_TEMP_AT_SOAK: ; this state is where we acheck if it reaches 50C in 60 seconds
	; check if it's 50C or above at 60 seconds
    mov a, FSM_state_decider
	  cjne a, #2, FSM_RAMP_TO_REFLOW
    Read_MCP3008(0)
    lcall Calculate_Temp
    lcall Display_update_main_screen
    mov PWM_Duty_Cycle255, #127
    mov a, Count_state
    cjne a, #80, FSM_HOLD_TEMP_AT_SOAK
	  inc FSM_state_decider
    clr a
    mov Count_state, a
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_ramp2) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    ; End Display_init_main_screen

FSM_RAMP_TO_REFLOW:
	; HEAT THE OVEN ;
    mov a, FSM_state_decider
	cjne a, #3, FSM_HOLD_TEMP_AT_REFLOW
    Read_MCP3008(0)
    lcall Calculate_Temp
    lcall Display_update_main_screen
    mov PWM_Duty_Cycle255, #255
    clr a
    load_y(230)
    lcall x_gteq_y
    jnb mf, FSM_HOLD_TEMP_AT_REFLOW
	inc FSM_state_decider
    clr a
    mov Count_state, a
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_reflow) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    ; End Display_init_main_screen

FSM_HOLD_TEMP_AT_REFLOW:
	; KEEP THE TEMP ;
    mov a, FSM_state_decider
	cjne a, #4, FSM_COOLDOWN
    Read_MCP3008(0)
    lcall Calculate_Temp
    lcall Display_update_main_screen
	inc FSM_state_decider
    ; Display_init_main_screen
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_cooldown) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
    ; End Display_init_main_screen

FSM_COOLDOWN:
	; SHUT;
    mov a, FSM_state_decider
    cjne a, #5, FSM_DONE
    Read_MCP3008(0)
    lcall Calculate_Temp
    lcall Display_update_main_screen
    mov PWM_Duty_Cycle255, #0
    load_y(30)
    lcall x_lteq_y
    jnb mf, FSM_COOLDOWN
    clr a
    mov Count_state, a

FSM_DONE:
	ljmp loop

END

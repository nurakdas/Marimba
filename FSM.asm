; Authors: Andrew Hanlon, Nursultan Tugolbaev, Deniz Tabakci
; Purpose: The main .asm code of our reflow oven controller

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

; Pin Assignments
LCD_RS equ P0.5
LCD_RW equ P0.6
LCD_E  equ P0.7
LCD_D4 equ P1.2
LCD_D5 equ P1.3
LCD_D6 equ P1.4
LCD_D7 equ P1.6
; Button ADC channels
THERMOCOUPLE_ADC_REGISTER equ AD0DAT1 ; on P0.0
LM335_ADC_REGISTER equ AD0DAT0 ; on pin P1.7
BUTTONS_ADC_REGISTER equ AD0DAT2 ; on pin P2.0
; The last ADC channel's reading is in ADC0DAT (from pin P2.1)
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

; DSEG and BSEG variables ======================================================
dseg at 0x30
; for soundinit.inc ;
w: ds 3 ; 24-bit play counter.  Decremented in CCU ISR
;soak_time_total: ds 1
;reflow_time_total: ds 1
current_temp: ds 1
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
BFSM5_state: ds 1
BFSM6_state: ds 1
BFSM7_state: ds 1

BFSM1_timer: ds 1
BFSM2_timer: ds 1
BFSM3_timer: ds 1
BFSM4_timer: ds 1
BFSM5_timer: ds 1
BFSM6_timer: ds 1
BFSM7_timer: ds 1

; 32 bit Math variables:
x:	ds 4
y:	ds 4
bcd:ds 5

bseg
; Flag set by timer 1 every half second (can be changed if needed)
seconds_flag: dbit 1
; Buttons raw flag
Button1_raw: dbit 1
Button2_raw: dbit 1
Button3_raw: dbit 1
Button4_raw: dbit 1
Button5_raw: dbit 1
Button6_raw: dbit 1
Button7_raw: dbit 1
; For each pushbutton we have a flag.  The corresponding FSM will set this
; flags to one when a valid press of the pushbutton is detected.
; THIS WILL BE CHANGED ACCORDING TO OUR OWN KEYS ;
B1_flag_bit: dbit 1
B2_flag_bit: dbit 1
B3_flag_bit: dbit 1
B4_flag_bit: dbit 1
B5_flag_bit: dbit 1
B6_flag_bit: dbit 1
B7_flag_bit: dbit 1
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

; Returns temperature at thermocouple in register a
Get_Temp:
    ;mov current_temp, LM335_ADC_REGISTER
    ; First get cold junction temp from LM335
    mov x+0, LM335_ADC_REGISTER
    clr a
    mov x+1, a
    mov x+2, a
    mov x+3, a
    Load_y(330)
    lcall mul32
    Load_y(255)
    lcall div32
    Load_y(273)
    lcall sub32
    ; Cold-junction temp is now in x
    clr a
    mov y+1, a
    mov y+2, a
    mov y+3, a
    mov y+0, THERMOCOUPLE_ADC_REGISTER
    ; Thermocouple temp is now in y
    lcall add32 ; Add cold junction temp to thermocouple temp to get actual temp
    mov current_temp, x ; actual thermocouple temp is now in current_temp
    ret

; SPI ==========================================================================
;Init_SPI:
	;setb MY_MISO	 	  ; Make MISO an input pin
	;clr MY_SCLK           ; Mode 0,0 default
	;ret
Init_SPI:
    ; Configure MOSI (P2.2), CS* (P2.4), and SPICLK (P2.5) as push-pull outputs
    ; (see table 42, page 51)
    anl P2M1, #low(not(00110100B))
    orl P2M2, #00110100B
    ; Configure MISO (P2.3) as input (see table 42, page 51)
    orl P2M1, #00001000B
    anl P2M2, #low(not(00001000B))
    ; Configure SPI
    ; Ignore /SS, Enable SPI, DORD=0, Master=1, CPOL=0, CPHA=0, clk/4
    mov SPCTL, #11010000B
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
Check_Buttons: ; Checks to see if we pressed any buttons
    ; TODO: implement reading buttons from a resistor chain on the ADC
    lcall ADC_to_PB
read_button_done:
    Button_FSM(BFSM1_state, BFSM1_timer, Button1_raw, B1_flag_bit)
    Button_FSM(BFSM2_state, BFSM2_timer, Button2_raw, B2_flag_bit)
    Button_FSM(BFSM3_state, BFSM3_timer, Button3_raw, B3_flag_bit)
    Button_FSM(BFSM4_state, BFSM4_timer, Button4_raw, B4_flag_bit)
    Button_FSM(BFSM5_state, BFSM5_timer, Button5_raw, B5_flag_bit)
    Button_FSM(BFSM6_state, BFSM6_timer, Button6_raw, B6_flag_bit)
    Button_FSM(BFSM7_state, BFSM7_timer, Button7_raw, B7_flag_bit)
    ret
;------------------------------ADDED BY PLATEMAN-------------------------------
ADC_to_PB:
	setb Button7_raw
	setb Button6_raw
	setb Button5_raw
	setb Button4_raw
	setb Button3_raw
	setb Button2_raw
	setb Button1_raw
	; Check PB7
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(247-10) ; 3.2V=247*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L6
	clr Button7_raw
    ret
ADC_to_PB_L6:
	; Check PB5
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(212-10) ; 2.4V=185*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L5
	clr Button6_raw
    ret
ADC_to_PB_L5:
	; Check PB4
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(176-10) ; 2.0V=154*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L4
	clr Button5_raw
    ret
ADC_to_PB_L4:
	; Check PB3
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(141-10) ; 1.6V=123*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L3
	clr Button4_raw
    ret
ADC_to_PB_L3:
	; Check PB2
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(106-10) ; 1.2V=92*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L2
	clr Button3_raw
    ret
ADC_to_PB_L2:
	; Check PB1
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(70-10) ; 0.8V=61*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L1
	clr Button2_raw
    ret
ADC_to_PB_L1:
	; Check PB1
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(36-10) ; 0.4V=30*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L0
	clr Button1_raw
    ret
ADC_to_PB_L0:
	; No pusbutton pressed
	ret
;------------------------------END OF ADDED BY PLATEMAN----------------------------

; MAIN==========================================================================
main: ; MY COCK IS MUCH BIGGER THAN YOURS
	; Initialization of hardware
    mov SP, #0x7F
    lcall Ports_Init ; Default all pins as bidirectional I/O. See Table 42.
    lcall LCD_4BIT
    lcall Double_Clk
	;lcall InitSerialPort ; For sound
	  lcall InitADC0 ; Call after 'Ports_Init'
	  lcall InitDAC1 ; Call after 'Ports_Init'
	;lcall CCU_Inits ; for sound
	;lcall Init_SPI ; for sound
    lcall Timer0_Init
    lcall Timer1_Init
    setb EA ; Enable Global interrupts

    ; Initialize variables
    ; Default Temperature profile parameters
    mov soak_temp, #80
    mov soak_time, #60
    mov reflow_temp, #230
    mov reflow_time, #40
    clr a
    mov Count1ms, a
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
    mov current_temp, a
    Load_X(0)
    Load_y(0)

	; After initialization the program stays in this 'forever' loop
    mov FSM_state_decider, #0
    mov PWM_Duty_Cycle255, #0
    lcall Display_init_standby_screen
loop:

FSM_RESET:
    mov a, FSM_state_decider
    ; cjne a, #0, FSM_RAMP_TO_SOAK ; jump is too long for this
    clr c
    subb a, #0
	jz RESET_continue1
    ljmp FSM_RAMP_TO_SOAK
RESET_continue1:
    clr a
    mov Count1s, a
    mov Count1s+1, a
    mov Count_state, a
    mov PWM_Duty_Cycle255, a
    lcall Check_Buttons
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    lcall Get_Temp
    jnb seconds_flag, skip_display1
    clr seconds_flag
    Display_update_temperature(current_temp)
skip_display1:
    ; Check start/cancel button and start if pressed
    jnb B1_flag_bit, FSM_RAMP_TO_SOAK
	inc FSM_state_decider
    clr B1_flag_bit
    Display_init_main_screen(display_mode_ramp1)

FSM_RAMP_TO_SOAK: ;  should be done in 1-3 seconds
    ; cjne a, #1, FSM_HOLD_TEMP_AT_SOAK ; jump is too long for this
    mov a, FSM_state_decider
    clr c
    subb a, #1
    jz RAMP_TO_SOAK_continue1
    ljmp FSM_HOLD_TEMP_AT_SOAK
RAMP_TO_SOAK_continue1:
    mov PWM_Duty_Cycle255, #255
    lcall Check_Buttons
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit ; I looooooove ice cream!
    lcall Get_Temp
    jnb seconds_flag, skip_display2
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display2:
    ; Check cancel button
    jnb B1_flag_bit, RAMP_TO_SOAK_continue2
    clr B1_flag_bit
    ljmp FSM_COOLDOWN
RAMP_TO_SOAK_continue2:
    clr a
    mov a, Count_state
    cjne a, #60, RAMP_TO_SOAK_continue3
    load_y(50)
    lcall x_lt_y
    jnb mf, RAMP_TO_SOAK_continue3

FSM_ERROR:
    mov PWM_Duty_Cycle255, #0
    Display_init_main_screen(display_mode_error)
    lcall Display_clear_line2
FSM_ERROR_loop:
    jnb seconds_flag, skip_display_ERROR
    clr seconds_flag
    Display_update_temperature(current_temp)
skip_display_ERROR:
    sjmp FSM_ERROR_loop

RAMP_TO_SOAK_continue3:
    clr a
    load_y(150)
    lcall x_gteq_y
    ; jnb mf, FSM_RAMP_TO_SOAK ; the jump is too long for this
    jb mf, RAMP_TO_SOAK_continue4
    ljmp FSM_RAMP_TO_SOAK
RAMP_TO_SOAK_continue4:
    inc FSM_state_decider
    clr a
    mov Count_state, a
    Display_init_main_screen(display_mode_soak)
    ;check for conditions and keep calling measure_temp
      ;stop around 150 +-20 degrees

FSM_HOLD_TEMP_AT_SOAK: ; this state is where we acheck if it reaches 50C in 60 seconds
	; check if it's 50C or above at 60 seconds
    mov a, FSM_state_decider
	; cjne a, #2, FSM_RAMP_TO_REFLOW ; jump is too long for this
    clr c
    subb a, #2
    jz HOLD_TEMP_AT_SOAK_continue1
    ljmp FSM_RAMP_TO_REFLOW
HOLD_TEMP_AT_SOAK_continue1:
    lcall Check_Buttons
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    lcall Get_Temp
    jnb seconds_flag, skip_display3
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display3:
    ; Check cancel button
    jnb B1_flag_bit, HOLD_TEMP_AT_SOAK_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5
    ljmp FSM_COOLDOWN
HOLD_TEMP_AT_SOAK_continue2:
    mov PWM_Duty_Cycle255, #51
    mov a, Count_state
    clr c
    subb a, #80
    jz HOLD_TEMP_AT_SOAK_continue3
    ljmp FSM_RAMP_TO_REFLOW
HOLD_TEMP_AT_SOAK_continue3:
	inc FSM_state_decider
    clr a
    mov Count_state, a
    Display_init_main_screen(display_mode_ramp2)

FSM_RAMP_TO_REFLOW:
	; HEAT THE OVEN ;
    mov a, FSM_state_decider
	; cjne a, #3, FSM_HOLD_TEMP_AT_REFLOW ; jump is too long for this
    clr c
    subb a, #3
    jz RAMP_TO_REFLOW_continue1
    ljmp FSM_HOLD_TEMP_AT_REFLOW
RAMP_TO_REFLOW_continue1:
    lcall Check_Buttons
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    lcall Get_Temp
    jnb seconds_flag, skip_display4
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display4:
    ; Check for cancel button
    jnb B1_flag_bit, RAMP_TO_REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5
    ljmp FSM_COOLDOWN
RAMP_TO_REFLOW_continue2:
    mov PWM_Duty_Cycle255, #255
    clr a
    load_y(230)
    lcall x_gteq_y
    jnb mf, FSM_HOLD_TEMP_AT_REFLOW
	  inc FSM_state_decider
    clr a
    mov Count_state, a
    Display_init_main_screen(display_mode_reflow)

FSM_HOLD_TEMP_AT_REFLOW:
	; KEEP THE TEMP ;
    mov a, FSM_state_decider
    ; cjne a, #4, FSM_COOLDOWN ; jump is too long for this
    clr c
    subb a, #4
    jz HOLD_TEMP_AT_REFLOW_continue1
    ljmp FSM_COOLDOWN
HOLD_TEMP_AT_REFLOW_continue1:
    lcall Check_Buttons
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    lcall Get_Temp
    jnb seconds_flag, skip_display5
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display5:
    ; Check cancel button
    jnb B1_flag_bit, HOLD_TEMP_AT_REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5
    ljmp FSM_COOLDOWN
HOLD_TEMP_AT_REFLOW_continue2:
    mov PWM_Duty_Cycle255, #51
    ; Wait for 40s to pass before going to next state (TODO: should be a parameter)
    mov a, Count_state
    clr c
    subb a, #40
    jz HOLD_TEMP_AT_REFLOW_continue3
    ljmp FSM_COOLDOWN
HOLD_TEMP_AT_REFLOW_continue3:
    inc FSM_state_decider

FSM_COOLDOWN:
	; SHUT;
    mov a, FSM_state_decider
    ; cjne a, #5, FSM_DONE
    clr c
    subb a, #5
    jz COOLDOWN_continue1
    ljmp FSM_DONE
COOLDOWN_continue1:
    Display_init_main_screen(display_mode_cooldown)
    lcall Get_Temp
    jnb seconds_flag, skip_display6
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display6:
    mov PWM_Duty_Cycle255, #0
    load_y(30)
    lcall x_lteq_y
    jb mf, COOLDOWN_continue2
    ljmp FSM_DONE
COOLDOWN_continue2:
    clr a
    mov Count_state, a
    lcall Display_init_standby_screen
    lcall Display_clear_line2
FSM_DONE:
	ljmp loop

END

; JAMES 1:12
; BEATUS VIR QVI SVFFERT TENTATIONEM
; QVIANIQM CVM
; PROBATVS FVERIT ACCIPIET
; CORONAM VITAE

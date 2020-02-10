; Authors: Andrew Hanlon, Nursultan Tugolbaev, Deniz Tabakci
; Purpose: The main .asm code of our reflow oven controller
; This code was blessed by Allah (cc)
; Copyrights reserved. c 2020, Group Marimba

; Free Pins we have:
; 0.2
; 0.3
; 3.1
; 2.6

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
SOUND       EQU P2.7

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
    lcall hex2bcd
  	Send_BCD(bcd)
  	mov a, #'\r'
  	lcall putchar
  	mov a, #'\n'
  	lcall putchar
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
  ; Since the reset button bounces, we need to wait a bit before
  ; sending messages, otherwise we risk displaying gibberish!
  mov R1, #222
  mov R0, #11
  djnz R0, $   ; 3 cycles->3*678.15ns*11=22.51519us
  djnz R1, $-4 ; 22.51519us*222=4.998ms
  ; Now we can proceed with the configuration
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 ; Turn-on the baud rate generator
	mov	SCON,#0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	mov	P1M1,#0x00 ; Enable pins RxD and TXD
	mov	P1M2,#0x00 ; Enable pins RxD and TXD
	ret
; Andrew's serial string and BCD functions
; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret

Send_BCD mac
	push ar0
	mov r0, %0
	lcall ?Send_BCD
	pop ar0
endmac

?Send_BCD:
	; Write most significant digit
	lcall ?Send_Upper_BCD
	; write least significant digit
	lcall ?Send_Lower_BCD
	ret

Send_Lower_BCD mac
	push ar0
	mov r0, %0
	lcall ?Send_Lower_BCD
	pop ar0
endmac

?Send_Lower_BCD:
	push acc
	; write only the least significant digit
	mov a, r0
	anl a, #0fh
	orl a, #30h
	lcall putchar
	pop acc
	ret

Send_Upper_BCD mac
	push ar0
	mov r0, %0
	lcall ?Send_Upper_BCD
	pop ar0
endmac

?Send_Upper_BCD:
	push acc
	; write only the most significant digit
	mov a, r0
	anl a, #0f0h
	swap a
	orl a, #30h
	lcall putchar
	pop acc
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

; MAIN =========================================================================
main:
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
    ; lcall phython program
    lcall InitSerialPort ; make the Phython script read it with the SPI
    lcall SendString ; send the temperature through the SPI

    ; Initialize variables
    clr B1_flag_bit
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
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

    ; Default Temperature profile parameters
    mov soak_temp, #80
    mov soak_time, #60
    mov reflow_temp, #230
    mov reflow_time, #40

	; After initialization the program stays in this 'forever' loop
    mov FSM_state_decider, #0
    mov PWM_Duty_Cycle255, #0
    lcall Display_init_standby_screen
    setb seconds_flag

loop:
    ; start of the state machine
    clr SOUND
    lcall Check_Buttons
    lcall Get_Temp
FSM_RESET:
    mov a, FSM_state_decider
    ; cjne a, #0, FSM_RAMP_TO_SOAK ; jump is too long for this
    clr c
    subb a, #0
	jz RESET_continue1
    ljmp FSM_RAMP_TO_SOAK ; jump to next state check if state decider doesn't match
RESET_continue1:
    mov PWM_Duty_Cycle255, #0

    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    ; Update temperature display every second
    jnb seconds_flag, skip_display1
    clr seconds_flag
    Display_update_temperature(current_temp)
skip_display1:
    ; Check start/cancel button and start if pressed
    jnb B1_flag_bit, FSM_RAMP_TO_SOAK ; go to check for next state
    clr B1_flag_bit
	inc FSM_state_decider
    ; Reset state and total stopwatches
    mov Count1s, a
    mov Count1s+1, a
    mov Count_state, a
    setb seconds_flag
    Display_init_main_screen(display_mode_ramp1)

FSM_RAMP_TO_SOAK: ;  should be done in 1-3 seconds
    ; cjne a, #1, FSM_SOAK ; jump is too long for this
    mov a, FSM_state_decider
    clr c
    subb a, #1
    jz RAMP_TO_SOAK_continue1
    ljmp FSM_SOAK ; go to check for next state
RAMP_TO_SOAK_continue1:
    mov PWM_Duty_Cycle255, #255
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    ; Update temp every second
    jnb seconds_flag, skip_display2 ;
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display2:
    ; Check cancel button
    jnb B1_flag_bit, RAMP_TO_SOAK_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_SOAK
RAMP_TO_SOAK_continue2:
    ; Check if 60 seconds have passed without an increase in temp
    mov a, Count_state
    cjne a, #60, RAMP_TO_SOAK_continue3
    load_y(50)
    lcall x_lt_y
    jnb mf, RAMP_TO_SOAK_continue3
    ljmp FSM_ERROR ; if so, there's a problem!
    ; Otherwise continue...
RAMP_TO_SOAK_continue3:
    ; Check if temp is over 150 degress. If so, go to SOAK state
    clr a
    load_y(150) ; TODO: change to parameter rather than a hard coded value
    ; TODO: Also may have to account for overshoot
    lcall x_gteq_y
    jb mf, RAMP_TO_SOAK_continue4
    ljmp FSM_SOAK
RAMP_TO_SOAK_continue4:
    inc FSM_state_decider
    mov Count_state, #0 ; reset state stopwatch
    setb seconds_flag
    Display_init_main_screen(display_mode_soak) ; reinitialize display

FSM_SOAK: ; this state is where we check if it reaches 50C in 60 seconds
	; check if it's 50C or above at 60 seconds
    mov a, FSM_state_decider
	; cjne a, #2, FSM_RAMP_TO_REFLOW ; jump is too long for this
    clr c
    subb a, #2
    jz SOAK_continue1
    ljmp FSM_RAMP_TO_REFLOW ; go to next state check
SOAK_continue1:
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit

    ; Update temp display every second
    jnb seconds_flag, skip_display3
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display3:
    ; Check cancel button
    jnb B1_flag_bit, SOAK_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5 ; go to Cooldown
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_RAMP_TO_REFLOW ; go to next state check
SOAK_continue2:
    ; Check if soak time has elapsed
    mov PWM_Duty_Cycle255, #51
    mov a, Count_state
    clr c
    subb a, #80 ; TODO: use actual parameter
    jz SOAK_continue3
    ljmp FSM_RAMP_TO_REFLOW
SOAK_continue3:
    ; Go to next state if so
	inc FSM_state_decider
    mov Count_state, #0
    setb seconds_flag
    Display_init_main_screen(display_mode_ramp2)

FSM_RAMP_TO_REFLOW:
	; HEAT THE OVEN ;
    mov a, FSM_state_decider
    clr c
    subb a, #3
    jz RAMP_TO_REFLOW_continue1
    ljmp FSM_REFLOW ; go to next state check
RAMP_TO_REFLOW_continue1:
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    ; Update temp every second
    jnb seconds_flag, skip_display4
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display4:
    ; Check for cancel button
    jnb B1_flag_bit, RAMP_TO_REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_REFLOW
RAMP_TO_REFLOW_continue2:
    mov PWM_Duty_Cycle255, #255 ; Heat the oven up
    ; Check if reflow temperature reached
    load_y(230) ; TODO: change to an actual parameter (this is the reflow temp-ish)
    lcall x_gteq_y
    jnb mf, FSM_REFLOW
	inc FSM_state_decider
    mov Count_state, #0 ; Reset state stopwatch
    setb seconds_flag
    Display_init_main_screen(display_mode_reflow)

FSM_REFLOW:
	; KEEP THE TEMP ;
    mov a, FSM_state_decider
    clr c
    subb a, #4
    jz REFLOW_continue1
    ljmp FSM_COOLDOWN
REFLOW_continue1:
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    ; Update temp every second
    jnb seconds_flag, skip_display5
    clr seconds_flag
    Display_update_main_screen(current_temp, Count_state, Count1s)
skip_display5:
    ; Check cancel button
    jnb B1_flag_bit, REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #5
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_COOLDOWN
REFLOW_continue2:
    mov PWM_Duty_Cycle255, #51 ; Hold temp steady
    ; Wait for 40s to pass before going to next state (TODO: should be a parameter)
    mov a, Count_state
    clr c
    subb a, #40
    jnz FSM_COOLDOWN
    inc FSM_state_decider
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)


FSM_COOLDOWN:
	; SHUT;
    mov a, FSM_state_decider
    clr c
    subb a, #5
    jz COOLDOWN_continue1
    ljmp FSM_DONE
COOLDOWN_continue1:
    clr B1_flag_bit
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    ; Update temp every second
    jnb seconds_flag, skip_display6
    clr seconds_flag
    Display_update_temperature(current_temp)
skip_display6:
    mov PWM_Duty_Cycle255, #0 ; Shut off oven
    ; Wait for temperature to decrease to a safe level before going to standby/reset
    load_y(50)
    lcall x_lteq_y
    jnb mf, FSM_DONE
    mov FSM_state_decider, #0
    setb seconds_flag
    lcall Display_init_standby_screen
    ljmp FSM_DONE

FSM_DONE:
	ljmp loop


FSM_ERROR:
    ; This is a terminal state. Escape requires reset.
    mov PWM_Duty_Cycle255, #0
    Display_init_main_screen(display_mode_error)
    lcall Display_clear_line2
FSM_ERROR_loop:
    ; Update temp display every second
    jnb seconds_flag, skip_display_ERROR
    clr seconds_flag
    lcall Get_Temp
    Display_update_temperature(current_temp)
skip_display_ERROR:
    sjmp FSM_ERROR_loop

END

; JAMES 1:12
; BEATUS VIR QVI SVFFERT TENTATIONEM
; QVIANIQM CVM
; PROBATVS FVERIT ACCIPIET
; CORONAM VITAE

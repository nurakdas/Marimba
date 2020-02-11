; FSM.asm
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
FLASH_CE    EQU P2.4
SOUND       EQU P2.7

; State numbers
STATE_RESET EQU 0
STATE_RAMP_TO_SOAK EQU 1
STATE_SOAK EQU 2
STATE_RAMP_TO_REFLOW EQU 3
STATE_REFLOW EQU 4
STATE_COOLDOWN EQU 5
STATE_SET_SOAK EQU 6
STATE_SET_REFLOW EQU 7

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

org 0x005b
  lcall CCU_ISR

; DSEG and BSEG variables ======================================================
dseg at 0x30
; for soundinit.inc ;
w: ds 3 ; 24-bit play counter.  Decremented in CCU ISR
;soak_time_total: ds 1
;reflow_time_total: ds 1
current_temp: ds 1
; Temperature profile parameters
soak_temp: ds 1
soak_time_seconds: ds 1
soak_time_minutes: ds 1
reflow_temp: ds 1
reflow_time_seconds: ds 1
reflow_time_minutes: ds 1
;audio
T2S_FSM_state: ds 1
RamptoSoak_State: ds 1
Soak_State:				ds 1
RamptoReflow_State: ds 1
Reflow_State: ds 1
Cooling_State: ds 1
Ding_State: ds 1
AbortingProcess_State: ds 1
SolderingProcessComplete_State: ds 1

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
;Audio
T2S_FSM_start: dbit 1
Say_RamptoSoak_flag: 								dbit 1
Say_Soak_flag: 											dbit 1
Say_RamptoReflow_flag: 							dbit 1
Say_Reflow_flag: 										dbit 1
Say_Cooling_flag: 									dbit 1
Say_AbortingProcess_flag: 					dbit 1
Say_Ding_flag: 											dbit 1
Say_SolderingProcessComplete_flag:  dbit 1

; ==============================================================================
cseg
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD functions and utility macros
$include(math32.inc)
$include(timers.inc)
$include(button_ops.inc)
$include(soundinit.inc)
$include(LCD_ops.inc)
$include(audio.inc)
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

  Send_BCD mac
  	push ar0
  	mov r0, %0
  	lcall ?Send_BCD
  	pop ar0
  endmac

  ?Send_BCD:
  	lcall ?Send_Upper_BCD
  	; write least significant digit
  	lcall ?Send_Lower_BCD
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

send_putty:
    mov a, current_temp
    lcall Hex_to_bcd_8bit
    Send_Lower_BCD(ar1)
    Send_BCD(ar0)
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
	subb a, #(245-10) ; 3.2V=245*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L6
	clr Button7_raw
    ret
ADC_to_PB_L6:
	; Check PB5
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(210-10) ; 2.4V=210*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L5
	clr Button6_raw
    ret
ADC_to_PB_L5:
	; Check PB4
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(175-10) ; 2.0V=175*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L4
	clr Button5_raw
    ret
ADC_to_PB_L4:
	; Check PB3
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(140-10) ; 1.6V=140*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L3
	clr Button4_raw
    ret
ADC_to_PB_L3:
	; Check PB2
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(105-10) ; 1.2V=105*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L2
	clr Button3_raw
    ret
ADC_to_PB_L2:
	; Check PB1
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(70-10) ; 0.8V=70*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L1
	clr Button2_raw
    ret
ADC_to_PB_L1:
	; Check PB1
	clr c
	mov a, BUTTONS_ADC_REGISTER
	subb a, #(36-10) ; 0.458V=36*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L0
	clr Button1_raw
    ret
ADC_to_PB_L0:
	; No pusbutton pressed
	ret
;------------------------------END OF ADDED BY PLATEMAN----------------------------

;---------------------------------------Audio Init------------------------------
; ; Function to play audio through the speaker
Play_Sound_Using_Index:
	push b
	setb SOUND ; Turn speaker on
	clr TMOD20 ; Stop the CCU from playing previous request
	setb FLASH_CE

	; There are three bytes per row in our tables, so multiply index by three
	mov b, #3
	mul ab
	mov R0, a ; Make a copy of the index*3

	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory of where to start playing
	mov dptr, #sound_index
	mov a, R0
	movc a, @a+dptr
	lcall Send_SPI
	inc dptr
	mov a, R0
	movc a, @a+dptr
	lcall Send_SPI
	inc dptr
	mov a, R0
	movc a, @a+dptr
	lcall Send_SPI
	; Now set how many bytes to play
	mov dptr, #Size_Length
	mov a, R0
	movc a, @a+dptr
	mov w+2, a
	inc dptr
	mov a, R0
	movc a, @a+dptr
	mov w+1, a
	inc dptr
	mov a, R0
	movc a, @a+dptr
	mov w+0, a

	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI

  ;clr SOUND
	setb TMOD20 ; Start playback by enabling CCU timer
	pop b
	ret

; Approximate index of sounds in file 'Project1Sounds.wav'
sound_index:
    db 0x00, 0x00, 0x2b ; 0
    db 0x00, 0x26, 0xc0 ; 1
    db 0x00, 0x4f, 0xea ; 2
    db 0x00, 0x7d, 0xe5 ; 3
    db 0x00, 0xb6, 0x58 ; 4
    db 0x00, 0xec, 0x17 ; 5
    db 0x01, 0x2c, 0x1c ; 6
    db 0x01, 0x63, 0x25 ; 7
    db 0x01, 0x8f, 0x85 ; 8
    db 0x01, 0xc7, 0x20 ; 9
    db 0x02, 0x02, 0x56 ; 10
    db 0x02, 0x41, 0x0d ; 11
    db 0x02, 0x7c, 0x5e ; 12
    db 0x02, 0xbd, 0xe4 ; 13
    db 0x03, 0x0b, 0xea ; 14
    db 0x03, 0x4d, 0x6d ; 15
    db 0x03, 0x98, 0xaa ; 16
    db 0x03, 0xed, 0x93 ; 17
    db 0x04, 0x33, 0xa0 ; 18
    db 0x04, 0x86, 0xd8 ; 19
    db 0x04, 0xd2, 0x88 ; 20
    db 0x05, 0x0c, 0x03 ; 21
    db 0x05, 0x4b, 0x73 ; 22
    db 0x05, 0x8a, 0xbc ; 23
    db 0x05, 0xd0, 0x2a ; 24
    db 0x06, 0x13, 0x3f ; 25
    db 0x06, 0x42, 0x0f ; 26
    db 0x06, 0x7e, 0xa9 ; 27
    db 0x06, 0xbb, 0x20 ; 28
    db 0x06, 0xef, 0x15 ; 29
    db 0x07, 0x19, 0x31 ; 30
    db 0x07, 0x51, 0x7c ; 31
    db 0x07, 0x93, 0x94 ; 32
    db 0x07, 0xce, 0x4e ; 33
    db 0x08, 0x0a, 0x56 ; 34
    db 0x08, 0x4d, 0x94 ; 35
    db 0x08, 0x92, 0x50 ; 36
    db 0x08, 0xcc, 0x77 ; 37
    db 0x08, 0xf6, 0x71 ; 38
    db 0x09, 0x35, 0x97 ; 39
    db 0x09, 0x77, 0xb6 ; 40
    db 0x09, 0xa8, 0xb0 ; 41
    db 0x09, 0xea, 0xff ; 42
    db 0x0a, 0x0e, 0x6a ; 43
    db 0x0a, 0x36, 0xc4 ; 44
    db 0x0a, 0x6f, 0x37 ; 45
    db 0x0a, 0x8e, 0xfe ; 46
    db 0x0a, 0xb8, 0xc4 ; 47
    db 0x0a, 0xd9, 0xbc ; 48
    db 0x0a, 0xf9, 0xe7 ; 49
    db 0x0b, 0x31, 0xe8 ; 50
    db 0x0b, 0x63, 0xee ; 51
    db 0x0b, 0xb3, 0x56

; Size of each sound in 'sound_index'
Size_Length:
    db 0x00, 0x26, 0x95 ; 0 = '1'
    db 0x00, 0x29, 0x2a ; 1 = '2'
    db 0x00, 0x2d, 0xfb ; 2 = '3'
    db 0x00, 0x38, 0x73 ; 3 = '4'
    db 0x00, 0x35, 0xbf ; 4 = '5'
    db 0x00, 0x40, 0x05 ; 5 = '6'
    db 0x00, 0x37, 0x09 ; 6 = '7'
    db 0x00, 0x2c, 0x60 ; 7 = '8'
    db 0x00, 0x37, 0x9b ; 8 = '9'
    db 0x00, 0x3b, 0x36 ; 9 = '10'
    db 0x00, 0x3e, 0xb7 ; 10 = '11'
    db 0x00, 0x3b, 0x51 ; 11 = '12'
    db 0x00, 0x41, 0x86 ; 12 = '13'
    db 0x00, 0x4e, 0x06 ; 13 = '14'
    db 0x00, 0x41, 0x83 ; 14 = '15'
    db 0x00, 0x4b, 0x3d ; 15 = '16'
    db 0x00, 0x54, 0xe9 ; 16 = '17'
    db 0x00, 0x46, 0x0d ; 17 = '18'
    db 0x00, 0x53, 0x38 ; 18 = '19'
    db 0x00, 0x4b, 0xb0 ; 19 = '20'
    db 0x00, 0x39, 0x7b ; 20 = '30'
    db 0x00, 0x3f, 0x70 ; 21 = '40'
    db 0x00, 0x3f, 0x49 ; 22 = '50'
    db 0x00, 0x45, 0x6e ; 23 = '60'
    db 0x00, 0x43, 0x15 ; 24 = '70'
    db 0x00, 0x2e, 0xd0 ; 25 = '80'
    db 0x00, 0x3c, 0x9a ; 26 = '90'
    db 0x00, 0x3c, 0x77 ; 27 = 'hundred'
    db 0x00, 0x33, 0xf5 ; 28 = 'ramp'
    db 0x00, 0x2a, 0x1c ; 29 = 'to'
    db 0x00, 0x38, 0x4b ; 30 = 'soak'
    db 0x00, 0x42, 0x18 ; 31 = 'reflow'
    db 0x00, 0x3a, 0xba ; 32 = 'cooling'
    db 0x00, 0x3c, 0x08 ; 33 = 'stage'
    db 0x00, 0x43, 0x3e ; 34 = 'seconds'
    db 0x00, 0x44, 0xbc ; 35 = 'celsius'
    db 0x00, 0x3a, 0x27 ; 36 = 'current_temp'
    db 0x00, 0x29, 0xfa ; 37 = 'ding'
    db 0x00, 0x3f, 0x26 ; 38 = 'soldering'
    db 0x00, 0x42, 0x1f ; 39 = 'complete'
    db 0x00, 0x30, 0xfa ; 40 = 'oven'
    db 0x00, 0x42, 0x4f ; 41 = 'temperature'
    db 0x00, 0x23, 0x6b ; 42 = 'is'
    db 0x00, 0x28, 0x5a ; 43 = 'time'
    db 0x00, 0x38, 0x73 ; 44 = 'remaining'
    db 0x00, 0x1f, 0xc7 ; 45 = 'in'
    db 0x00, 0x29, 0xc6 ; 46 = 'please'
    db 0x00, 0x20, 0xf8 ; 47 = 'kill'
    db 0x00, 0x20, 0x2b ; 48 = 'me'
    db 0x00, 0x38, 0x01 ; 49 = 'aborting'
    db 0x00, 0x32, 0x06 ; 50 = 'process'
    db 0x00, 0x4f, 0x68 ; 51 = 'switch'
;---------------------------------------Audio end-------------------------------

; MAIN =========================================================================
main:
	; Initialization of hardware
    mov SP, #0x7F
    lcall Ports_Init ; Default all pins as bidirectional I/O. See Table 42.
    lcall LCD_4BIT
    lcall Double_Clk
    lcall InitSerialPort ; make the Phython script read it with the SPI
	;lcall InitSerialPort ; For sound
	  lcall InitADC0 ; Call after 'Ports_Init'
	  lcall InitDAC1 ; Call after 'Ports_Init'
	;lcall CCU_Inits ; for sound
	;lcall Init_SPI ; for sound
    lcall Timer0_Init
    lcall Timer1_Init
    setb EA ; Enable Global interrupts
    ; lcall phython program
    lcall SendString ; send the temperature through the SPI
    lcall CCU_Init
    lcall Init_SPI

    ; Initialize variables
    clr TMOD20
    clr B1_flag_bit
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    clr a
    mov Count1ms, a
    mov minutes_state, a
    mov seconds_state, a
    mov minutes_total, a
    mov seconds_total, a
    mov FSM_state_decider, a
    mov BFSM1_state, a
    mov BFSM2_state, a
    mov BFSM3_state, a
    mov BFSM4_state, a
    mov BFSM5_state, a
    mov BFSM6_state, a
    mov BFSM7_state, a
    mov BFSM1_timer, a
    mov BFSM2_timer, a
    mov BFSM3_timer, a
    mov BFSM4_timer, a
    mov BFSM5_timer, a
    mov BFSM6_timer, a
    mov BFSM7_timer, a
    mov current_temp, a
    Load_X(0)
    Load_y(0)

    ; Default Temperature profile parameters
    mov soak_temp, #150
    mov soak_time_minutes, #1
    mov soak_time_seconds, #20
    mov reflow_temp, #230
    mov reflow_time_seconds, #0
    mov reflow_time_minutes, #1

	; After initialization the program stays in this 'forever' loop
    mov FSM_state_decider, #0
    mov PWM_Duty_Cycle255, #0
    lcall Display_init_standby_screen
    setb seconds_flag

    ;Audio
    mov T2S_FSM_state, #0


loop:
    ; start of the state machine
    lcall Check_Buttons
    lcall Get_Temp
    lcall T2S_FSM
FSM_RESET:
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_RESET
	jz RESET_continue1
    ljmp FSM_RAMP_TO_SOAK ; jump to next state check if state decider doesn't match
RESET_continue1:

    ;clearing Audio at the start
    mov RamptoSoak_State, #0
    mov Soak_State, #0
    mov RamptoReflow_State, #0
    mov Reflow_State, #0
    mov Cooling_State, #0
    mov Ding_State, #0
    mov AbortingProcess_State, #0
    mov SolderingProcessComplete_State, #0
    ;---------------------------

    ;setting Audio flags
    setb Say_RamptoSoak_flag
    setb Say_Soak_flag
    setb Say_RamptoReflow_flag
    setb Say_Reflow_flag
    setb Say_Cooling_flag
    setb Say_AbortingProcess_flag
    setb Say_Ding_flag
    setb Say_SolderingProcessComplete_flag
    ;-------------------

    mov PWM_Duty_Cycle255, #0

    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    ; Update temperature display every second
    jnb seconds_flag, skip_display1
    clr seconds_flag
    lcall send_putty
    Display_update_temperature(current_temp)
skip_display1:
    ; Check set button (button 2) and change to SET_SOAK state if pressed
    jnb B2_flag_bit, RESET_check_start_button
    clr B2_flag_bit
    mov FSM_state_decider, #STATE_SET_SOAK
    Display_init_set_soak_screen()
    ljmp FSM_RAMP_TO_SOAK
RESET_check_start_button:
    ; Check start/cancel button and start if pressed
    jnb B1_flag_bit, FSM_RAMP_TO_SOAK ; go to check for next state
    clr B1_flag_bit
	inc FSM_state_decider
    Display_init_main_screen(display_mode_ramp1)
    lcall Say_RamptoSoak
    ; Reset state and total stopwatches
    clr a
    mov seconds_state, a
    mov minutes_state, a
    mov seconds_total, a
    mov minutes_total, a
    setb seconds_flag

FSM_RAMP_TO_SOAK: ;  should be done in 1-3 seconds
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_RAMP_TO_SOAK
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
    jnb seconds_flag, skip_display2
    clr seconds_flag
    lcall send_putty
    lcall Display_update_main_screen
skip_display2:
    ; Check cancel button
    jnb B1_flag_bit, RAMP_TO_SOAK_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #STATE_COOLDOWN
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_SOAK
RAMP_TO_SOAK_continue2:
    ; Check if 60 seconds have passed without an increase in temp (>50 deg).
    ; If so, there's a problem!
    mov a, minutes_state
    cjne a, #1, RAMP_TO_SOAK_continue3
    mov a, seconds_state
    cjne a, #0, RAMP_TO_SOAK_continue3
    load_y(50)
    lcall x_lt_y
    jnb mf, RAMP_TO_SOAK_continue3
    ljmp FSM_ERROR
    ; Otherwise continue...
RAMP_TO_SOAK_continue3:
    ; Check if temp is over soak_temp degrees.
    ; If so, go to SOAK state
    mov y+0, soak_temp
    clr a
    mov y+1, a
    mov y+2, a
    mov y+3, a
    lcall x_gteq_y
    jb mf, RAMP_TO_SOAK_continue4
    ljmp FSM_SOAK
RAMP_TO_SOAK_continue4:
    inc FSM_state_decider
    lcall Say_Soak
    clr a
    mov seconds_state, a
    mov minutes_state, a
    setb seconds_flag
    Display_init_main_screen(display_mode_soak) ; reinitialize display

FSM_SOAK:
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_SOAK
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
    lcall send_putty
    lcall Display_update_main_screen
skip_display3:
    ; Check cancel button
    jnb B1_flag_bit, SOAK_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #STATE_COOLDOWN
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_RAMP_TO_REFLOW ; go to next state check
SOAK_continue2:
    mov PWM_Duty_Cycle255, #51
    ; Check if soak time has elapsed
    mov a, minutes_state
    clr c
    subb a, soak_time_minutes
    jnz SOAK_continue3
    mov a, seconds_state
    clr c
    subb a, soak_time_seconds
    jnz SOAK_continue3
    inc FSM_state_decider
    lcall Say_RamptoReflow
    clr a
    mov seconds_state, a
    mov minutes_state, a
    setb seconds_flag
    Display_init_main_screen(display_mode_ramp2)
    ;setb seconds_flag
    ; ljmp FSM_RAMP_TO_REFLOW
SOAK_continue3:
    ; Go to next state if so

FSM_RAMP_TO_REFLOW:
	; HEAT THE OVEN ;
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_RAMP_TO_REFLOW
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
    lcall send_putty
    lcall Display_update_main_screen
skip_display4:
    ; Check for cancel button
    jnb B1_flag_bit, RAMP_TO_REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #STATE_COOLDOWN
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_REFLOW
RAMP_TO_REFLOW_continue2:
    mov PWM_Duty_Cycle255, #255 ; Heat the oven up
    ; Check if reflow temperature reached
    mov y+0, reflow_temp
    clr a
    mov y+1, a
    mov y+2, a
    mov y+3, a
    lcall x_gteq_y
    jnb mf, FSM_REFLOW
	  inc FSM_state_decider
    lcall Say_Reflow
    ; Reset state stopwatch
    clr a
    mov seconds_state, a
    mov minutes_state, a
    setb seconds_flag
    Display_init_main_screen(display_mode_reflow)

FSM_REFLOW:
	; KEEP THE TEMP ;
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_REFLOW
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
    lcall send_putty
    lcall Display_update_main_screen
skip_display5:
    ; Check cancel button
    jnb B1_flag_bit, REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #STATE_COOLDOWN
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)
    ljmp FSM_COOLDOWN
REFLOW_continue2:
    mov PWM_Duty_Cycle255, #51 ; Hold temp steady
    ; Wait for reflow time to pass before going to next state
    mov a, minutes_state
    clr c
    subb a, reflow_time_minutes
    jnz FSM_COOLDOWN
    mov a, seconds_state
    clr c
    subb a, reflow_time_seconds
    jnz FSM_COOLDOWN
    inc FSM_state_decider
    lcall Say_Cooling
    setb seconds_flag
    Display_init_main_screen(display_mode_cooldown)

FSM_COOLDOWN:
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_COOLDOWN
    jz COOLDOWN_continue1
    ljmp FSM_SET_SOAK
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
    lcall send_putty
    Display_update_temperature(current_temp)
skip_display6:
    mov PWM_Duty_Cycle255, #0 ; Shut off oven
    ; Wait for temperature to decrease to a safe level before going to standby/reset
    load_y(50)
    lcall x_lteq_y
    jnb mf, FSM_SET_SOAK
    mov FSM_state_decider, #STATE_RESET
    lcall Say_Ding
    lcall Say_SolderingProcessComplete
    setb seconds_flag
    lcall Display_init_standby_screen
    ljmp FSM_DONE

FSM_SET_SOAK:
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_SET_SOAK
    jz SET_SOAK_continue1
    ljmp FSM_SET_REFLOW
SET_SOAK_continue1:
    clr B7_flag_bit ; unused button
    ; Check cancel button and return to reset if pressed
    jnb B1_flag_bit, SET_SOAK_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #STATE_RESET
    setb seconds_flag
    lcall Display_init_standby_screen
    ljmp FSM_SET_REFLOW
SET_SOAK_continue2:
    ; Check set button (button 2) and go to SET_REFLOW if pressed
    jnb B2_flag_bit, SET_SOAK_continue3
    clr B2_flag_bit
    mov FSM_state_decider, #STATE_SET_REFLOW
    Display_init_set_reflow_screen()
    ljmp FSM_SET_REFLOW
SET_SOAK_continue3:
    ; Check button 3 and decrement time if pressed
    jnb B3_flag_bit, SET_SOAK_continue4
    clr B3_flag_bit
    Decrement_time_setting(soak_time_seconds, soak_time_minutes)
    ljmp SET_SOAK_continue7
SET_SOAK_continue4:
    ; Check button 4 and increment time if pressed
    jnb B4_flag_bit, SET_SOAK_continue5
    clr B4_flag_bit
    Increment_time_setting(soak_time_seconds, soak_time_minutes)
    ljmp SET_SOAK_continue7
SET_SOAK_continue5:
    ; Check button 5 and decrement temp if pressed
    jnb B5_flag_bit, SET_SOAK_continue6
    clr B5_flag_bit
    dec soak_temp
    ljmp SET_SOAK_continue7
SET_SOAK_continue6:
    ; Check button 6 and increment temp if pressed
    jnb B6_flag_bit, SET_SOAK_continue7
    clr B6_flag_bit
    inc soak_temp
    ljmp SET_SOAK_continue7
SET_SOAK_continue7:
    Display_update_set_screen(soak_time_seconds, soak_time_minutes, soak_temp)

FSM_SET_REFLOW:
    mov a, FSM_state_decider
    clr c
    subb a, #STATE_SET_REFLOW
    jz SET_REFLOW_continue1
    ljmp FSM_DONE
SET_REFLOW_continue1:
    clr B7_flag_bit ; unused button
    ; Check cancel button and return to reset if pressed
    jnb B1_flag_bit, SET_REFLOW_continue2
    clr B1_flag_bit
    mov FSM_state_decider, #STATE_RESET
    setb seconds_flag
    lcall Display_init_standby_screen
    ljmp FSM_DONE
SET_REFLOW_continue2:
    ; Check set button and return to reset if pressed
    jnb B2_flag_bit, SET_REFLOW_continue3
    clr B2_flag_bit
    mov FSM_state_decider, #STATE_RESET
    setb seconds_flag
    lcall Display_init_standby_screen
    ljmp FSM_DONE
SET_REFLOW_continue3:
    ; Check button 3 and decrement time if pressed
    jnb B3_flag_bit, SET_REFLOW_continue4
    clr B3_flag_bit
    Decrement_time_setting(reflow_time_seconds, reflow_time_minutes)
    ljmp SET_REFLOW_continue7
SET_REFLOW_continue4:
    ; Check button 4 and increment time if pressed
    jnb B4_flag_bit, SET_REFLOW_continue5
    clr B4_flag_bit
    Increment_time_setting(reflow_time_seconds, reflow_time_minutes)
    ljmp SET_REFLOW_continue7
SET_REFLOW_continue5:
    ; Check button 5 and decrement temp if pressed
    jnb B5_flag_bit, SET_REFLOW_continue6
    clr B5_flag_bit
    dec reflow_temp
    ljmp SET_REFLOW_continue7
SET_REFLOW_continue6:
    ; Check button 6 and increment temp if pressed
    jnb B6_flag_bit, SET_REFLOW_continue7
    clr B6_flag_bit
    inc reflow_temp
    ljmp SET_REFLOW_continue7
SET_REFLOW_continue7:
    Display_update_set_screen(reflow_time_seconds, reflow_time_minutes, reflow_temp)

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
    lcall send_putty
    Display_update_temperature(current_temp)
skip_display_ERROR:
    sjmp FSM_ERROR_loop

END

; JAMES 1:12
; BEATVS VIR QVI SVFFERT TENTATIONEM
; QVIANIQM CVM
; PROBATVS FVERIT ACCIPIET
; CORONAM VITAE

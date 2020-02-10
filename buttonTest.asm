; Authors: Andrew Hanlon, Nursultan Tugolbaev, Deniz Tabakci
; Purpose: The main .asm code of our reflow oven controller
; This code was blessed by Allah (cc)
; Copyrights reserved. c 2020, Group Marimba

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

b1: dbit 1
b2: dbit 1
b3: dbit 1
b4: dbit 1
b5: dbit 1
b6: dbit 1
b7: dbit 1

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

Display_PushButtons_ADC:
	Set_Cursor(2, 1)
	mov a, #'0'
	mov c, b1
	addc a, #0
    lcall ?WriteData
	mov a, #'0'
	mov c, b2
	addc a, #0
    lcall ?WriteData
	mov a, #'0'
	mov c, b3
	addc a, #0
    lcall ?WriteData
	mov a, #'0'
	mov c, b4
	addc a, #0
    lcall ?WriteData
	mov a, #'0'
	mov c, b5
	addc a, #0
    lcall ?WriteData
	mov a, #'0'
	mov c, b6
	addc a, #0
    lcall ?WriteData
	mov a, #'0'
	mov c, b7
	addc a, #0
    lcall ?WriteData
	ret

BBB MAC
    jnb B%0_flag_bit, skip%0
    clr B%0_flag_bit
    cpl b%0
    skip%0:
ENDMAC
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

    ; Initialize variables
    clr B1_flag_bit
    clr B2_flag_bit
    clr B3_flag_bit
    clr B4_flag_bit
    clr B5_flag_bit
    clr B6_flag_bit
    clr B7_flag_bit
    clr b1
    clr b2
    clr b3
    clr b4
    clr b5
    clr b6
    clr b7
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
    mov BFSM4_timer,a
    mov BFSM5_timer,a
    mov BFSM6_timer,a
    mov BFSM7_timer,a
    mov current_temp, a
    Load_X(0)
    Load_y(0)

    ; Default Temperature profile parameters
    mov soak_temp, #80
    mov soak_time_minutes, #1
    mov soak_time_seconds, #0
    mov reflow_temp, #230
    mov reflow_time_seconds, #40
    mov reflow_time_minutes, #0

	; After initialization the program stays in this 'forever' loop
    mov FSM_state_decider, #0
    mov PWM_Duty_Cycle255, #0
    setb seconds_flag

loop:
    ; start of the state machine
    lcall Check_Buttons
    lcall Get_Temp
    mov a, BFSM1_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,1)
    Display_Lower_BCD(ar0)
    mov a, BFSM2_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,2)
    Display_Lower_BCD(ar0)
    mov a, BFSM3_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,3)
    Display_Lower_BCD(ar0)
    mov a, BFSM4_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,4)
    Display_Lower_BCD(ar0)
    mov a, BFSM5_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,5)
    Display_Lower_BCD(ar0)
    mov a, BFSM6_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,6)
    Display_Lower_BCD(ar0)
    mov a, BFSM7_state
    lcall Hex_to_bcd_8bit
    Set_Cursor(1,7)
    Display_Lower_BCD(ar0)
    BBB(1)
    BBB(2)
    BBB(3)
    BBB(4)
    BBB(5)
    BBB(6)
    BBB(7)
    lcall Display_PushButtons_ADC

FSM_DONE:
	ljmp loop

END

; JAMES 1:12
; BEATVS VIR QVI SVFFERT TENTATIONEM
; QVIANIQM CVM
; PROBATVS FVERIT ACCIPIET
; CORONAM VITAE

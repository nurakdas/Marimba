$NOLIST
$MOD9351
$LIST

; Serial
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))
; SPI
CE_ADC    EQU  P2.7
MY_MOSI   EQU  P2.6
MY_MISO   EQU  P2.5
MY_SCLK   EQU  P2.4
; Pin Assignments
LCD_RS equ P0.7
LCD_RW equ P3.0
LCD_E  equ P3.1
LCD_D4 equ P2.0
LCD_D5 equ P2.1
LCD_D6 equ P2.2
LCD_D7 equ P2.3

; BUTTONS EQU PX.X GO HERE ;
;-------------------------;

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

dseg at 0x30
; PWM output (to oven) variables
PWM_Duty_Cycle255: ds 1
PWM_Cycle_Count: ds 1
; Timing Variable
Count10ms: ds 1

; Each FSM has its own timer
; Each FSM has its own state counter
FSM_state_decider: ds 1 ; HELPS US SEE WHICH STATE WE ARE IN
; THE STATES ARE ;
;----------------;

; Three counters to display.
; THIS WILL BE CHANGED ACCORDING TO OUR OWN KEYS ;
Count1:     ds 1 ; Incremented/decremented when KEY1 is pressed.
Count2:     ds 1 ; Incremented/decremented when KEY2 is pressed.
Count3:     ds 1 ; Incremented every second. Reset to zero when KEY3 is pressed.
x:	ds 4
y:	ds 4
bcd:ds 5
Result: ds 4

bseg
; Flag set by timer 1 every half second (can be changed if needed)
half_seconds_flag: dbit 1
; For each pushbutton we have a flag.  The corresponding FSM will set this
; flags to one when a valid press of the pushbutton is detected.
; THIS WILL BE CHANGED ACCORDING TO OUR OWN KEYS ;
Key1_flag: dbit 1
Key2_flag: dbit 1
Key3_flag: dbit 1
mf:	dbit 1

cseg
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$include(timers.inc)
$LIST

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;


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

INI_SPI:
	setb MY_MISO	 	  ; Make MISO an input pin
	clr MY_SCLK           ; Mode 0,0 default
	ret

DO_SPI_G:
	push acc
	mov R1,#0			  ; Received byte stored in R1
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

	; Configure the serial port and baud rate
InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can proceed with the configuration
	orl	PCON,#0x80
	mov	SCON,#0x52
	mov	BDRCON,#0x00
	mov	BRL,#BRG_VAL
	mov	BDRCON,#0x1E ; BDRCON=BRR|TBCK|RBCK|SPD;
    ret

	; Send a character using the serial port
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

SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString

SendStringDone:
    ret
;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization of hardware
    mov SP, #0x7F
    lcall Timer2_Init
	lcall LCD_4BIT
    lcall InitSerialPort
    lcall SendString
    lcall INI_SPI
    ; Turn off all the LEDs
    mov LEDRA, #0 ; LEDRA is bit addressable
    mov LEDRB, #0 ; LEDRB is NOT bit addresable
    setb EA   ; Enable Global interrupts

    ; Initialize variables
    mov FSM1_state, #0
    mov Count1, #0
    mov Count2, #0
    mov Count3, #0

    ; PUT ALL INITIALISATIONS HERE ;
    ;------------------------------;

	; After initialization the program stays in this 'forever' loop
loop:
    mov FSM_state_decider, #0

    ; PUT ALL INITIALISATIONS HERE ;
    ;------------------------------;
	mov a, FSM_state_decider
FSM_RESET:
	; SET TIMER TO 0 ;
	; SET TEMP TO ROOM TEMP ;
	; CLEAR THE DISPLAY FOR WHAT STATE WE'RE IN ;
	cjne a, #0, FSM_INITIALISE
loop0:
	lcall Measure_temp
	jb KEY.1, loop0
	Wait_Milli_Seconds(#50)
	jb KEY.1, loop0
	jnb KEY.1, $
	inc FSM_state_decider
FSM_INITIALISE:
	; WE CAN USE THIS STATE AS A DEBOUNCE STATE FOR THE BUTTON WE PRESS TO START THE PROGRAM ;
	cjne a, #1, FSM_RAMP_TO_SOAK


		; Turn on the oven ;
FSM_RAMP_TO_SOAK: ;  should be done in 1-3 seconds
	cjne a, #2, FSM_HOLD_TEMP_AT_SOAK
		; HEAT THE OVEN ;

FSM_HOLD_TEMP_AT_SOAK: ; this state is where we acheck if it reaches 50C in 60 seconds
	; check if it's 50C or above at 60 seconds ;
	cjne a, #3, FSM_RAMP_TO_REFLOW
	inc FSM_state_decider
	sjmp FSM_done
FSM_RAMP_TO_REFLOW:
	; HEAT THE OVEN ;
	cjne a, #4, FSM_HOLD_TEMP_AT_REFLOW
	;jnb KEY.1, FSM1_done
	;setb Key1_flag ; Suscesfully detected a valid KEY1 press/release
	inc FSM_state_decider
FSM_HOLD_TEMP_AT_REFLOW:
	; KEEP THE TEMP ;
	cjne a, #5, FSM_COOLDOWN
	inc FSM_state_decider
FSM_COOLDOWN:
	; SHUT EVERYTHING DOWN ;
FSM_done:
	mov FSM_state_decider, #0


;---------------------------------------;
; TEMPLATE CODE BELOW, LEAVE IT FOR NOW ;

; If KEY1 was detected, increment or decrement Count1.  Notice that we are displying only
; the least two signicant digits of a counter that can have values from 0 to 255.
	jbc Key1_flag, Increment_Count1
	sjmp Skip_Count1
Increment_Count1:
	jb SWA.0, Decrement_Count1
	inc Count1
	sjmp Display_Count1
Decrement_Count1:
	dec Count1
Display_Count1:
    mov a, Count1
    lcall Hex_to_bcd_8bit
	lcall Display_BCD_7_Seg_HEX10
Skip_Count1:

; If KEY2 was detected, increment or decrement Count2.  Notice that we are displying only
; the least two signicant digits of a counter that can have values from 0 to 255.
	jbc Key2_flag, Increment_Count2
	sjmp Skip_Count2
Increment_Count2:
	jb SWA.0, Decrement_Count2
	inc Count2
	sjmp Display_Count2
Decrement_Count2:
	dec Count2
Display_Count2:
    mov a, Count2
    lcall Hex_to_bcd_8bit
	lcall Display_BCD_7_Seg_HEX32
Skip_Count2:

; When KEY3 is pressed/released it resets the one second counter (Count3)
	jbc Key3_flag, Clear_Count3
	sjmp Skip_Count3
Clear_Count3:
    mov Count3, #0
    ; Reset also the state machine for the one second counter and its timer
    mov FSM4_state, #0
	mov FSM4_timer, #0
	; Display the new count
    mov a, Count3
    lcall Hex_to_bcd_8bit
	lcall Display_BCD_7_Seg_HEX54
Skip_Count3:
    ljmp loop
	sjmp FSM_RESET

Measure_temp:
	clr CE_ADC
	mov R0, #00000001B; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1          ; R1 contains bits 8 and 9
	anl a, #00000011B  ; We need only the two least significant bits
	mov Result+1, a    ; Save result high.
	mov R0, #55H		; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1     ; R1 contains bits 0 to 7.  Save result low.
	setb CE_ADC
	lcall Delay
	lcall Calculate
	mov a, FSM_state_decider
	ret

Delay:
	mov R2, #89
Le3:mov R1, #250
Le2:mov R0, #166
Le1:djnz R0, Le1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, Le2 ; 22.51519us*250=5.629ms
    djnz R2, Le3 ; 5.629ms*178=1s (approximately)
    ret

Calculate:
	mov x, Result
	mov x+1, Result+1
	mov x+2, #0
	mov x+3, #0
	load_y(410)
	lcall mul32
	load_y(1023)
	lcall div32
	load_y(273)
	lcall sub32
	lcall hex2bcd
	; Send_BCD(bcd)
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	ret

END

; Non_Blocking_FSM_example.asm:  Four FSMs are run in the forever loop.
; Three FSMs are used to detect (with debounce) when either KEY1, KEY2, or
; KEY3 are pressed.  The fourth FSM keeps a counter (Count3) that is incremented
; every second.  When KEY1 is detected the program increments/decrements Count1,
; depending on the position of SW0. When KEY2 is detected the program
; increments/decrements Count2, also base on the position of SW0.  When KEY3
; is detected, the program resets Count3 to zero.
;
$NOLIST
$MOD9351
$LIST

XTAL EQU 7373000 ; Microcontroller system crystal frequency in Hz
B1 EQU P0.0
B2 EQU P0.1
B3 EQU P0.2
SWITCH EQU P0.7

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
;	ljmp Timer0_ISR
    reti

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

dseg at 0x30
FSM1_state: ds 1
FSM2_state: ds 1
FSM3_state: ds 1
FSM4_state: ds 1
; Timers for each FSM:
FSM1_timer: ds 1
FSM2_timer: ds 1
FSM3_timer: ds 1
FSM4_timer: ds 1
; Three counters to display.
Count1:     ds 1 ; Incremented/decremented when KEY1 is pressed.
Count2:     ds 1 ; Incremented/decremented when KEY2 is pressed.
Count3:     ds 1 ; Incremented every second. Reset to zero when KEY3 is pressed.

bseg
half_seconds_flag: dbit 1
; For each pushbutton we have a flag.  The corresponding FSM will set this
; flags to one when a valid press of the pushbutton is detected.
Key1_flag: dbit 1
Key2_flag: dbit 1
Key3_flag: dbit 1

cseg
$NOLIST
$include(timers.inc)
$include(button_ops.inc)
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

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
main:
	; Initialization of hardware
    mov SP, #0x7F
    lcall Timer1_Init
    setb EA   ; Enable Global interrupts

    ; Initialize variables
    mov FSM1_state, #0
    mov FSM2_state, #0
    mov FSM3_state, #0
    mov FSM4_state, #0
    mov Count1, #0
    mov Count2, #0
    mov Count3, #0

; After initialization the program stays in this 'forever' loop
loop:

;-------------------------------------------------------------------------------
; non-blocking state machines for KEYs
Button_FSM(FSM1_state, FSM1_timer, B1, Key1_flag)
Button_FSM(FSM2_state, FSM2_timer, B2, Key2_flag)
Button_FSM(FSM3_state, FSM3_timer, B3, Key3_flag)
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; non-blocking FSM for the one second counter starts here.
	mov a, FSM4_state
FSM4_state0:
	cjne a, #3, FSM4_done
	mov a, FSM4_timer
	cjne a, #100, FSM4_done ; 1000 ms passed?
	mov FSM4_timer, #0
	mov FSM4_state, #0
	mov a, Count3
	cjne a, #59, IncCount3 ; Don't let the seconds counter pass 59
	mov Count3, #0
	sjmp DisplayCount3
IncCount3:
	inc Count3
DisplayCount3:
    mov a, Count3
    lcall Hex_to_bcd_8bit
    ; Would print to LCD or serial here
	mov FSM4_state, #0
FSM4_done:
;-------------------------------------------------------------------------------


; If KEY1 was detected, increment or decrement Count1.  Notice that we are displying only
; the least two signicant digits of a counter that can have values from 0 to 255.
	jbc Key1_flag, Increment_Count1
	sjmp Skip_Count1
Increment_Count1:
	jb SWITCH, Decrement_Count1
	inc Count1
	sjmp Display_Count1
Decrement_Count1:
	dec Count1
Display_Count1:
    mov a, Count1
    lcall Hex_to_bcd_8bit
    ; Would print to LCD or serial here
Skip_Count1:

; If KEY2 was detected, increment or decrement Count2.  Notice that we are displying only
; the least two signicant digits of a counter that can have values from 0 to 255.
	jbc Key2_flag, Increment_Count2
	sjmp Skip_Count2
Increment_Count2:
	jb SWITCH, Decrement_Count2
	inc Count2
	sjmp Display_Count2
Decrement_Count2:
	dec Count2
Display_Count2:
    mov a, Count2
    lcall Hex_to_bcd_8bit
    ; Would print to LCD or serial here
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
    ; Would print to LCD or serial here
Skip_Count3:

    ljmp loop
END

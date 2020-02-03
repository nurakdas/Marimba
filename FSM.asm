$NOLIST
$MODDE1SOC
$LIST

CLK           EQU 33333333 ; Microcontroller system crystal frequency in Hz
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/(12*TIMER2_RATE))))

; BUTTONS EQU PX.X GO HERE ;
;-------------------------;

; Reset vector
org 0x0000
    ljmp main

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

dseg at 0x30
; Each FSM has its own timer
FSM1_timer: ds 1
; Each FSM has its own state counter
FSM_state_decider: ds 1 ; HELPS US SEE WHICH STATE WE ARE IN
; THE STATES ARE ;
;----------------;

; Three counters to display.
; THIS WILL BE CHANGED ACCORDING TO OUR OWN KEYS ;
Count1:     ds 1 ; Incremented/decremented when KEY1 is pressed.
Count2:     ds 1 ; Incremented/decremented when KEY2 is pressed.
Count3:     ds 1 ; Incremented every second. Reset to zero when KEY3 is pressed.

bseg
; For each pushbutton we have a flag.  The corresponding FSM will set this
; flags to one when a valid press of the pushbutton is detected.
; THIS WILL BE CHANGED ACCORDING TO OUR OWN KEYS ;
Key1_flag: dbit 1
Key2_flag: dbit 1
Key3_flag: dbit 1

cseg
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$LIST
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2.  Runs evere ms ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	; Increment the timers for each FSM. That is all we do here!
	inc FSM1_timer 
	inc FSM2_timer 
	inc FSM3_timer 
	inc FSM4_timer 
	reti

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
    lcall Timer2_Init
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
	mov a, FSM_state_decider
FSM_RESET:
	; SET TIMER TO 0 ;
	; SET TEMP TO ROOM TEMP ;
	; CLEAR THE DISPLAY FOR WHAT STATE WE'RE IN ; 
	cjne a, #0, FSM_INITIALISE
	;jb KEY.1, FSM_done
	mov FSM1_timer, #0
	inc FSM_state_decider
	sjmp FSM_done
FSM_INITIALISE:
	; WE CAN USE THIS STATE AS A DEBOUNCE STATE FOR THE BUTTON WE PRESS TO START THE PROGRAM ; 
	cjne a, #1, FSM_RAMP_TO_SOAK
	; this is the debounce state
	mov a, FSM1_timer
	cjne a, #50, FSM_done ; 50 ms passed?
	inc FSM_state_decider
	sjmp FSM1_done
FSM_RAMP_TO_SOAK: ;  should be done in 1-3 seconds
	; HEAT THE OVEN ;
	cjne a, #2, FSM_HOLD_TEMP_AT_SOAK
	;jb KEY.1, FSM1_state2b
	inc FSM_state_decider
	sjmp FSM_done
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
	sjmp FSM_done
FSM_HOLD_TEMP_AT_REFLOW:
	; KEEP THE TEMP ;
	cjne a, #5, FSM_COOLDOWN
	inc FSM_state_decider
	sjmp FSM_done
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
END
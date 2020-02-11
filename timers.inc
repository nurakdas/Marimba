; timers.inc
; Date: 2020/02/03
; Author: Andrew Hanlon
;
; Initializations and ISR's for timer 0 and timer 1
; Timer 0 is used to generate a Pulse Width Modulation (PWM) signal
; Timer 1 provides timekeeping for the program.

; To set the duty cycle of the PWM, change the value of PWM_Duty_Cycle255
; 0 is 0% (always off), 127 is 50%, 255 is 100% (full beans)

; Microcontroller system clock frequency in Hz must be declared as "XTAL"
PWM_BASE_FREQ EQU 20 ; Hz frequency of PWM waveform
TIMER0_RATE   EQU (PWM_BASE_FREQ*256) ; 256 point time resolution
TIMER0_RELOAD EQU ((65536-(XTAL/(2*TIMER0_RATE))))
TIMER1_RATE   EQU 1000 ; 1000Hz, for a timer interrupt every 1ms
TIMER1_RELOAD EQU ((65536-(XTAL/(2*TIMER1_RATE))))

PWM_OUTPUT EQU P0.1

dseg
; variables program should access
; Timing Variables
; All variables are regular numbers. These are NOT BCD variables.
Count1ms: ds 1
seconds_total: ds 1
minutes_total: ds 1
seconds_state: ds 1
minutes_state: ds 1
PWM_Duty_Cycle255: ds 1
; variables program should not access
PWM_Cycle_Count: ds 1
internal_1ms_counter: ds 1
extension_counter0: ds 1
extension_counter1: ds 1
extension_counter2: ds 1

cseg
; Increment_time(seconds, minutes)
Increment_time MAC
	mov a, %0 ; seconds
	inc a
	cjne a, #60, done_seconds%M
	; clear seconds and increment minute if 60 seconds reached
	mov %0, #0 ; seconds
	mov a, %1 ; minutes
	inc a
	mov %1, a ; minutes
	sjmp done_minutes%M
done_seconds%M:
	mov %0, a ; seconds
done_minutes%M:
ENDMAC


Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
    mov PWM_Cycle_Count, #0
	mov PWM_Duty_Cycle255, #0
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

Timer0_ISR:
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	push acc
	push psw
    ; cpl P0.1 ; for debugging
    mov a, PWM_Duty_Cycle255
    jnz TTCheck_Full_Cycle
    clr PWM_OUTPUT
    sjmp Timer0_ISR_END
TTCheck_Full_Cycle:
    inc a
    jnz TTCheck_Cycle_Count ; If duty cycle was 255, adding 1 overflows to 0
    setb PWM_OUTPUT
    sjmp Timer0_ISR_END
TTCheck_Cycle_Count:
    ; Duty cycle is not at either extreme so PWM the output
    inc PWM_Cycle_Count
    mov a, PWM_Cycle_Count
    jnz TTCheck_Cycle_Count2  ; if the cycle count overflowed to 0
    setb PWM_OUTPUT     ; set the output high
TTCheck_Cycle_Count2:
    ; clear the output if the duty cycle threshold has been reached
    mov a, PWM_Cycle_Count
    cjne a, PWM_Duty_Cycle255, Timer0_ISR_END
    clr PWM_OUTPUT
Timer0_ISR_END:
	pop psw
	pop acc
	reti



Timer1_Init:
	mov a, TMOD
	anl a, #0x0f ; Clear the bits for timer 1
	orl a, #0x10 ; Configure timer 1 as 16-timer
	mov TMOD, a
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	clr a
	mov internal_1ms_counter, a
	mov extension_counter0, a
	mov extension_counter1, a
	mov extension_counter2, a
	; Enable the timer and interrupts
    setb ET1  ; Enable timer 1 interrupt
    setb TR1  ; Start timer 1
	ret

;---------------------------------;
; ISR for timer 1                 ;
;---------------------------------;
Timer1_ISR:
	mov TH1, #high(TIMER1_RELOAD)
	mov TL1, #low(TIMER1_RELOAD)
	; cpl P0.2 ; To check the interrupt rate with oscilloscope. It must be precisely a 10 ms pulse.

	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw

	; Increment the 8-bit 1 millisecond counter
	inc Count1ms
	inc internal_1ms_counter
	; The following are for the button_FSM_test.asm program
	inc BFSM1_timer
	inc BFSM2_timer
	inc BFSM3_timer
	inc BFSM4_timer
	inc BFSM5_timer
	inc BFSM6_timer
	inc BFSM7_timer

	mov a, internal_1ms_counter
	cjne a, #250, Timer1_ISR_done ; Warning: this instruction changes the carry flag!
	mov internal_1ms_counter, #0 ; reset the internal 1ms counter
	inc extension_counter0
	inc extension_counter1
	inc extension_counter2
	; The extension counters are incremented every 1/4 of a second

	; Check if half a second has passed with extension_counter0
	mov a, extension_counter0
	cjne a, #2, Timer1_check_four
	mov extension_counter0, #0
	setb seconds_flag ; Let the main program know a half-second had passed

Timer1_check_four:
	; Check if a second has passed with extension_counter1
	mov a, extension_counter1
	cjne a, #4, Timer1_check_twenty
	mov extension_counter1, #0
	; Increment the seconds counter
	Increment_time(seconds_state, minutes_state)
	Increment_time(seconds_total, minutes_total)

Timer1_check_twenty:
	; Set a flag every 5 seconds for the speech functionality
	mov a, extension_counter2
	cjne a, #20, Timer1_ISR_done
	mov extension_counter2, #0
	setb T2S_FSM_start ;TODO: uncomment once sound stuff is implemented

Timer1_ISR_done:
	pop psw
	pop acc
	reti

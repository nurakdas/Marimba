; button_ops.inc
; Date: 2020/02/05
;
; Includes routines for performing operations upon detection of a button press
; as well as a non-blocking FSM routine for facilitating the use of buttons.
; That routine is a macro.

; Decrement_time_setting(seconds, minutes)
Decrement_time_setting MAC
	clr c
	mov a, %0 ; seconds
	jnz decrement_time_seconds%M
	mov a, %1 ; minutes
	jz decrement_time_rollover%M
	; Seconds are zero, minutes are non-zero, so decrement minutes and rollover seconds
	dec %1
	mov %0, #59
	sjmp Decrement_time_setting_done%M
decrement_time_rollover%M:
	; Seconds and minutes are zero, so rollover to 9:59
	mov %1, #9
	mov %0, #59
	sjmp Decrement_time_setting_done%M
decrement_time_seconds%M:
	; Seconds are non-zero, so just decrement seconds
	dec %0
Decrement_time_setting_done%M:
ENDMAC

; Increment_time_setting(seconds, minutes)
Increment_time_setting MAC
	mov a, %0 ; seconds
	inc a
	cjne a, #60, done_setting_seconds%M
	; clear seconds and increment minute if 60 seconds reached
	mov %0, #0 ; seconds
	mov a, %1 ; minutes
	inc a
	mov %1, a ; minutes
	sjmp done_setting_minutes%M
done_setting_seconds%M:
	mov %0, a ; seconds
done_setting_minutes%M:
	; Check if time is 10:00 after increment. If so, roll it over to 0:00
	mov a, %0
	jnz Increment_time_setting_done%M
	mov a, %1
	jnz Increment_time_setting_done%M
	mov %0, #0
	mov %1, #0
Increment_time_setting_done%M:
ENDMAC

; Button_FSM(FSM_state, FSM_timer, GPIO_bit, flag_bit) =========================
; Non-blocking FSM for detecting a press/release cycle of a button on
; the pin "GPIO_bit". Indicates press to program via the "flag_bit" specified.
; NOTE: You MUST declare byte variables in dseg for the state and timer of EACH
; Button_FSM created by the macro for this to work properly.
Button_FSM MAC
	mov a, %0
FSM%M_state0:
	cjne a, #0, FSM%M_state1
	jb %2, FSM%M_done
	mov %1, #0
	inc %0
	sjmp FSM%M_done
FSM%M_state1:
	cjne a, #1, FSM%M_state2
	; this is the debounce state
	mov a, %1
	clr c
	subb a, #50
	jc FSM%M_done ; 50 ms passed?
	;cjne a, #50, FSM%M_done ; 50 ms passed?
	inc %0
	sjmp FSM%M_done
FSM%M_state2:
	; Check if button is still pressed
	cjne a, #2, FSM%M_state3
	jb %2, FSM%M_state2b
	inc %0
	sjmp FSM%M_done
FSM%M_state2b:
	mov %0, #0
	sjmp FSM%M_done
FSM%M_state3:
	; Wait for button to be released before setting flag bit
	cjne a, #3, FSM%M_done
	jnb %2, FSM%M_done
	setb %3 ; Successfully detected a valid button press/release
	mov %0, #0
FSM%M_done:
ENDMAC

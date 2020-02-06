; button_ops.inc
; Date: 2020/02/05
;
; Includes routines for performing operations upon detection of a button press
; depending on the currently selected option (ie. cursor position),
; as well as a non-blocking FSM routine for facilitating the use of buttons.
; That routine is a macro.

; WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP WIP
; Move the setting cursor ======================================================
; MoveSettingCursor:
; 	; modified from example code above
; 	mov a, SettingCursor
; 	mov b, #11
; 	mul ab
; 	mov dptr, #Move_table
; 	jmp @A+dptr
; Move_table:
; 	; Positions Must be changed according to interface details
; 	Set_Cursor(1,8)
; 	ret
; 	Set_Cursor(1,11)
; 	ret
; 	Set_Cursor(1,14)
; 	ret
; 	Set_Cursor(1,15)
; 	ret
;
; ; Increment the setting cursor =================================================
; IncSettingCursor:
; 	mov a, SettingCursor
; 	inc a
; 	cjne a, #4, done_SettingCursor
; 	mov a, #0
; done_SettingCursor:
; 	mov SettingCursor, a
; 	ret
;
; ; Button 2 Operations ==========================================================
; Button2_Ops:
; 	mov a, SettingCursor
; 	mov b, #2
; 	mul ab
; 	mov dptr, #Button2_table
; 	jmp @A+dptr
; Button2_table:
; 	sjmp b20
; 	sjmp b21
; 	sjmp b22
; 	sjmp b23
;
; b20:
; 	; increment soak temp
; 	mov a, Hours
; 	add a, #0x01
; 	da a
; 	cjne a, #0x13, b20_end
; 	mov a, #0x01
; b20_end:
; 	mov Hours, a
; 	sjmp b2_end
; b21:
; 	; increment time minute
; 	mov a, Minutes
; 	add a, #0x01
; 	da a
; 	cjne a, #0x60, b21_end
; 	clr a
; b21_end:
; 	mov Minutes, a
; 	sjmp b2_end
; b22:
;     ; increment time seconds
;     mov a, Seconds
;     add a, #0x01
;     da a
;     cjne a, #0x60, b22_end
;     clr a
; b22_end:
;     mov Seconds, a
;     sjmp b2_end
; b23:
; 	; toggle time AM/PM
; 	cpl AM_PM_flag
; 	sjmp b2_end
;
; b2_end:
; 	ret
;
; ; Button 3 Operations ==========================================================
; Button3_Ops:
; ;	clr TR2 ; disable timer 2 for a moment to avoid conflicts
; 	mov a, SettingCursor
; 	mov b, #2
; 	mul ab
; 	mov dptr, #Button3_table
; 	jmp @A+dptr
; Button3_table:
; 	sjmp b30
; 	sjmp b31
; 	sjmp b32
; 	sjmp b33
; b30:
; 	; decrement time hour
; 	mov a, Hours
; 	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1
; 	da a
; 	cjne a, #0x00, b30_end
; 	mov a, #0x12
; b30_end:
; 	mov Hours, a
; 	sjmp b3_end
; b31:
; 	; decrement time minute
; 	mov a, Minutes
; 	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1
; 	da a
; 	cjne a, #0x99, b31_end
; 	mov a, #0x59
; b31_end:
; 	mov Minutes, a
; 	sjmp b3_end
; b32:
;     mov a, Seconds
;     add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1
;     da a
;     cjne a, #0x99, b32_end
;     mov a, #0x59
; b32_end:
;     ; decrement time seconds
;     mov Seconds, a
;     sjmp b3_end
; b33:
; 	; toggle time AM/PM
; 	cpl AM_PM_flag
; 	sjmp b3_end
;
; b3_end:
; 	ret

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
	cjne a, #5, FSM%M_done ; 5 * 10 = 50 ms passed?
	inc %0
	sjmp FSM%M_done
FSM%M_state2:
	cjne a, #2, FSM%M_state3
	jb %2, FSM%M_state2b
	inc %0
	sjmp FSM%M_done
FSM%M_state2b:
	mov %0, #0
	sjmp FSM%M_done
FSM%M_state3:
	cjne a, #3, FSM%M_done
	jnb %2, FSM%M_done
	setb %3 ; Successfully detected a valid button press/release
	mov %0, #0
FSM%M_done:
ENDMAC

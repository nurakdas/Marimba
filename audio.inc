; Audio feedback routine
; Written by: Michael O'Keefe, Anthony Wang, Nusair Islam
; This code was blessed by Allah (cc)
; Copyrights reserved. c 2020, Group Marimba

; FSM to say current temperature reading
T2S_FSM:
	setb SOUND
	push acc
	mov a, T2S_FSM_state

T2S_FSM_State0: ; Checks for the start signal (T2S_FSM_Start==1) "T2S_FSM_Start==1 when routine is called by controller"
	cjne a, #0, T2S_FSM_State1
	jnb T2S_FSM_Start, T2S_FSM_State0_Done
	; Check if current_temp is larger than 19
	clr c
	mov a, current_temp
	mov r7, a
	;push acccccc
	subb a, #20
	jnc current_temp_gt_19
	mov T2S_FSM_state, #1
	sjmp T2S_FSM_State0_Done
current_temp_gt_19:
	mov T2S_FSM_state, #3
T2S_FSM_State0_Done:
	pop acc
	ret

T2S_FSM_State1: ; Plays current_temp when current_temp is less than 20
	cjne a, #1, T2S_FSM_State2
	;pop acccc
	mov a, r7
	subb a, #1 ;each index is 1 less than what is wants to say
	lcall Play_Sound_Using_Index
	mov T2S_FSM_State, #2
	pop acc
	ret

T2S_FSM_State2: ; Stay in this state until value <19 finishes playing
	cjne a, #2, T2S_FSM_State3
	jb TMOD20, T2S_FSM_State2_Done
	mov T2S_FSM_State, #8
T2S_FSM_State2_Done:
	pop acc
	ret

T2S_FSM_State3: ; Plays the hundreds when current_temp is larger than 19, for example for 42 current_temp, it plays 'forty'
	cjne a, #3, T2S_FSM_State4
	mov a, r7
	;pop acccc
	mov b, #100
	div ab
	jz lt_100
	subb a, #1
	lcall Play_Sound_Using_Index ;plays hundredth digit
	mov T2S_FSM_State, #4
	pop acc
	ret
lt_100:
	mov T2S_FSM_State, #5
	pop acc
	ret

T2S_FSM_State4: ; Stay in this state until hundredth position finishes playing
	cjne a, #4, T2S_FSM_State5
	jb TMOD20, T2S_FSM_State4_Done
	mov T2S_FSM_State, #10
T2S_FSM_State4_Done:
pop acc
    ret

T2S_FSM_State5: ; Plays the tens when current_temp is larger than 19, for example for 42 current_temp, it plays 'forty'
	cjne a, #5, T2S_FSM_State6
	;mov a, current_temp
	mov a, b ;put remainder into a
	mov r6, a
	mov b, #10
	div ab
	cjne a, #1, ten_not_1
	mov T2S_FSM_State, #15
	pop acc
	ret
ten_not_1:
	jz T2S_FSM_STATE5_Done ;if number has no tens place,
	add a, #17
	lcall Play_Sound_Using_Index
T2S_FSM_STATE5_Done:
	mov T2S_FSM_State, #6
	;mov a, r6
	pop acc
	ret

T2S_FSM_State6: ; Stay in this state until sound finishes playing
	cjne a, #6, T2S_FSM_State7
	jb TMOD20, T2S_FSM_State6_Done
	mov T2S_FSM_State, #7
T2S_FSM_State6_Done:
pop acc
    ret

T2S_FSM_State7: ; Plays the ones when current_temp is larger than 19, for example for 42 current_temp, it plays 'two'
	cjne a, #7, T2S_FSM_State8 ;go to state11 buffer
;	mov a, current_temp
	mov a, b
	mov b, #10
	div ab
	mov a, b
	jz T2S_FSM_State7_Done ; Prevents from playing something like 'forty zero'
	subb a, #1
	lcall Play_Sound_Using_Index
T2S_FSM_State7_Done:
	mov T2S_FSM_State, #11
	pop acc
	ret

T2S_FSM_State8: ; Plays the words 'degrees'
	cjne a, #8, T2S_FSM_State9
	mov a, #36 ; Index 36 has the words 'degrees'
	lcall Play_Sound_Using_Index ; "degrees"
	mov T2S_FSM_State, #9
	pop acc
	ret

T2S_FSM_State9: ; Stay in this state until sound finishes playing
	cjne a, #9, T2S_FSM_State10
	jb TMOD20, T2S_FSM_State9_Done
	clr T2S_FSM_Start
	mov T2S_FSM_State, #0
T2S_FSM_State9_Done:
	pop acc
	ret

T2S_FSM_State10: ; Plays the word 'hundred'
	cjne a, #10, T2S_FSM_State11
	mov a, #27
	lcall Play_Sound_Using_Index ;plays 'hundred' word
	mov T2S_FSM_State, #17
	pop acc
	ret

T2S_FSM_State11: ;buffer to play ones units
	cjne a, #11, T2S_FSM_State15
	jb TMOD20, T2S_FSM_State11_Done
	mov T2S_FSM_State, #8
T2S_FSM_State11_Done:
pop acc
	ret

T2S_FSM_State15: ; Plays current_temp when current_temp is less than 20
	cjne a, #15, T2S_FSM_State16
	mov a, r6
	subb a, #1 ;each index is 1 less than what is wants to say
	lcall Play_Sound_Using_Index
	mov T2S_FSM_State, #16
	pop acc
	ret

T2S_FSM_State16: ; Stay in this state to wait for current_temp value to play
	cjne a, #16, T2S_FSM_State17
	jb TMOD20, T2S_FSM_State16_Done
	mov T2S_FSM_State, #8
T2S_FSM_State16_Done:
pop acc
	ret

T2S_FSM_State17: ; Stay in this state to wait for current_temp value to play
	cjne a, #17, T2S_FSM_Error
	jb TMOD20, T2S_FSM_State17_Done
	mov T2S_FSM_State, #5
T2S_FSM_State17_Done:
pop acc
	ret

T2S_FSM_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov T2S_FSM_state, #0
	clr T2S_FSM_Start
	pop acc
	ret
; End of FSM that plays current_temp and seconds

;---------------------------------------------------Start of FSM for stages------------------------------------------

;FSM to say RamptoSoak;-----------------------------------------
Say_RamptoSoak:
setb SOUND
push acc
	mov a, RamptoSoak_State

RamptoSoak_State0: ; Play first word
	cjne a, #0, RamptoSoak_State1
	jnb Say_RamptoSoak_flag, Say_RamptoSoak_done
	clr c
	mov a, #28
  lcall Play_Sound_Using_Index ;"Ramp"
	mov RamptoSoak_State, #1
Say_RamptoSoak_done:
pop acc
	ret

RamptoSoak_State1: ; Wait for first word to finish playing
	cjne a, #1, RamptoSoak_State2
	jb TMOD20, RamptoSoak_State1_done
	mov RamptoSoak_State, #2
RamptoSoak_State1_done:
pop acc
	ret

RamptoSoak_State2:
	cjne a, #2, RamptoSoak_State3
	mov a, #29
	lcall Play_Sound_Using_Index ; "to"
	mov RamptoSoak_State, #3
	pop acc
	ret

RamptoSoak_State3: ; Wait for second word to finish playing
	cjne a, #3, RamptoSoak_State4
	jb TMOD20, RamptoSoak_State3_done
	mov RamptoSoak_State, #4
RamptoSoak_State3_done:
pop acc
	ret

RamptoSoak_State4:
	cjne a, #4, RamptoSoak_State5
	mov a, #30
  lcall Play_Sound_Using_Index ; "Soak"
	mov RamptoSoak_State, #5
	pop acc
	ret

RamptoSoak_State5: ; Wait for third word to finish playing
	cjne a, #5, RamptoSoak_Error
	jb TMOD20, RamptoSoak_State5_done
	clr Say_RamptoSoak_flag
	mov RamptoSoak_State, #0
RamptoSoak_State5_done:
pop acc
	ret

RamptoSoak_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov RamptoSoak_State, #0
	clr Say_RamptoSoak_flag
	pop acc
	ret

;FSM to say Soak-----------------------------
Say_Soak:
setb SOUND
push acc
	mov a, Soak_State

Soak_State0: ; Play first word
	cjne a, #0, Soak_State1
	jnb Say_Soak_flag, Say_Soak_done
	clr c
	mov a, #30
  lcall Play_Sound_Using_Index ; "Soak"
	mov Soak_State, #1
Say_Soak_done:
pop acc
	ret

Soak_State1: ; Wait for first word to finish playing
	cjne a, #1, Soak_Error
	jb TMOD20, Soak_State1_done
	mov Soak_State, #0
	clr Say_Soak_flag
Soak_State1_done:
pop acc
	ret

Soak_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Soak_State, #0
	clr Say_Soak_flag
	pop acc
	ret

;FSM to say RamptoReflow-----------------------------
Say_RamptoReflow:
setb SOUND
push acc
	mov a, RamptoReflow_State

RamptoReflow_State0: ; Play first word
	cjne a, #0, RamptoReflow_State1
	jnb Say_RamptoReflow_flag, Say_RamptoReflow_done
	clr c
	mov a, #28
  lcall Play_Sound_Using_Index ; "Ramp"
	mov RamptoReflow_State, #1
Say_RamptoReflow_done:
pop acc
	ret

RamptoReflow_State1: ; Wait for first word to finish playing
	cjne a, #1, RamptoReflow_State2
	jb TMOD20, RamptoReflow_State1_done
	mov RamptoReflow_State, #2
RamptoReflow_State1_done:
pop acc
	ret

RamptoReflow_State2:
	cjne a, #2, RamptoReflow_State3
	mov a, #29
	lcall Play_Sound_Using_Index ; "to"
	mov RamptoReflow_State, #3
	pop acc
	ret

RamptoReflow_State3: ; Wait for second word to finish playing
	cjne a, #3, RamptoReflow_State4
	jb TMOD20, RamptoReflow_State3_done
	mov RamptoReflow_State, #4
RamptoReflow_State3_done:
pop acc
	ret

RamptoReflow_State4:
	cjne a, #4, RamptoReflow_State5
	mov a, #31
  lcall Play_Sound_Using_Index ; "Reflow"
	mov RamptoReflow_State, #5
	pop acc
	ret

RamptoReflow_State5: ; Wait for third word to finish playing
	cjne a, #5, RamptoReflow_Error
	jb TMOD20, RamptoReflow_State5_done
	clr Say_RamptoReflow_flag
	mov RamptoReflow_State, #0
RamptoReflow_State5_done:
pop acc
	ret

RamptoReflow_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov RamptoReflow_State, #0
	clr Say_RamptoReflow_flag
	pop acc
	ret


;FSM to say Reflow---------------------
Say_Reflow:
setb SOUND
push acc
	mov a, Reflow_State

Reflow_State0: ; Play first word
	cjne a, #0, Reflow_State1
	jnb Say_Reflow_flag, Say_Reflow_done
	clr c
	mov a, #31
  lcall Play_Sound_Using_Index ; "Reflow"
	mov Reflow_State, #1
Say_Reflow_done:
pop acc
	ret

Reflow_State1: ; Wait for first word to finish playing
	cjne a, #1, Reflow_Error
	jb TMOD20, Reflow_State1_done
	mov Reflow_State, #0
	clr Say_Reflow_flag
Reflow_State1_done:
pop acc
	ret

Reflow_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Reflow_State, #0
	pop acc
	ret

;FSM to say Cooling-------------------
Say_Cooling:
setb SOUND
push acc
	mov a, Cooling_State

Cooling_State0: ; Play first word
	cjne a, #0, Cooling_State1
	jnb Say_Cooling_flag, Say_Cooling_done
	clr c
	mov a, #32
  lcall Play_Sound_Using_Index ; "Cooling"
	mov Cooling_State, #1
Say_Cooling_done:
pop acc
	ret

Cooling_State1: ; Wait for first word to finish playing
	cjne a, #1, Cooling_Error
	jb TMOD20, Cooling_State1_done
	mov Cooling_State, #0
	clr Say_Cooling_flag
Cooling_State1_done:
pop acc
	ret

Cooling_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Cooling_State, #0
	pop acc
	ret

;FSM for Aborting Process-----------------
Say_AbortingProcess:
setb SOUND
push acc
	mov a, AbortingProcess_State

AbortingProcess_State0: ; Play first word
	cjne a, #0, AbortingProcess_State1
	jnb Say_AbortingProcess_flag, Say_AbortingProcess_done
	clr c
	mov a, #49
  lcall Play_Sound_Using_Index ; "Aborting"
	mov AbortingProcess_State, #1
Say_AbortingProcess_done:
pop acc
	ret

AbortingProcess_State1: ; Wait for first word to finish playing
	cjne a, #1, AbortingProcess_State2
	jb TMOD20, AbortingProcess_State1_done
	mov AbortingProcess_State, #2
AbortingProcess_State1_done:
pop acc
	ret

AbortingProcess_State2:
	cjne a, #2, AbortingProcess_State3
	mov a, #50
  lcall Play_Sound_Using_Index ; "Process"
	mov AbortingProcess_State, #3
	pop acc
	ret

AbortingProcess_State3: ; Wait for second word to finish playing
	cjne a, #3, AbortingProcess_Error
	jb TMOD20, AbortingProcess_State3_done
	mov AbortingProcess_State, #0
	clr Say_AbortingProcess_flag
AbortingProcess_State3_done:
pop acc
	ret

AbortingProcess_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov AbortingProcess_State, #0
	clr Say_AbortingProcess_flag
	pop acc
	ret

;FSM to say Ding------------------
Say_Ding:
setb SOUND
push acc
	mov a, Ding_State

Ding_State0: ; Play first word
	cjne a, #0, Ding_State1
	jnb Say_Ding_flag, Say_Ding_done
	clr c
	mov a, #37
  lcall Play_Sound_Using_Index ; "Ding"
	mov Ding_State, #1
Say_Ding_done:
pop acc
	ret

Ding_State1: ; Wait for first word to finish playing
	cjne a, #1, Ding_Error
	jb TMOD20, Ding_State1_done
	mov Ding_State, #0
	clr Say_Ding_flag
Ding_State1_done:
pop acc
	ret

Ding_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Ding_State, #0
	clr Say_Ding_flag
	pop acc
	ret

;FSM to say Soldering Process Complete---------------------
Say_SolderingProcessComplete:
setb SOUND
push acc
	mov a, SolderingProcessComplete_State

SolderingProcessComplete_State0: ; Play first word
	cjne a, #0, SolderingProcessComplete_State1
	jnb Say_SolderingProcessComplete_flag, Say_SolderingProcessComplete_done
	clr c
	mov a, #38
  lcall Play_Sound_Using_Index ; "Soldering"
	mov SolderingProcessComplete_State, #1
Say_SolderingProcessComplete_done:
pop acc
	ret

SolderingProcessComplete_State1: ; Wait for first word to finish playing
	cjne a, #1, SolderingProcessComplete_State2
	jb TMOD20, SolderingProcessComplete_State1_done
	mov SolderingProcessComplete_State, #2
SolderingProcessComplete_State1_done:
pop acc
	ret

SolderingProcessComplete_State2:
	cjne a, #2, SolderingProcessComplete_State3
	mov a, #50
	lcall Play_Sound_Using_Index ; "Process"
	mov SolderingProcessComplete_State, #3
	pop acc
	ret

SolderingProcessComplete_State3: ; Wait for second word to finish playing
	cjne a, #3, SolderingProcessComplete_State4
	jb TMOD20, SolderingProcessComplete_State3_done
	mov SolderingProcessComplete_State, #4
SolderingProcessComplete_State3_done:
pop acc
	ret

SolderingProcessComplete_State4:
	cjne a, #4, SolderingProcessComplete_State5
	mov a, #39
  lcall Play_Sound_Using_Index ; "Complete"
	mov SolderingProcessComplete_State, #5
	pop acc
	ret

SolderingProcessComplete_State5: ; Wait for third word to finish playing
	cjne a, #5, SolderingProcessComplete_Error
	jb TMOD20, SolderingProcessComplete_State5_done
	clr Say_SolderingProcessComplete_flag
	mov SolderingProcessComplete_State, #0
SolderingProcessComplete_State5_done:
pop acc
	ret

SolderingProcessComplete_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov SolderingProcessComplete_State, #0
	clr Say_SolderingProcessComplete_flag
	pop acc
	ret

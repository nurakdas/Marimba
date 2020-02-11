; Audio feedback routine
; Written by: Michael O'Keefe, Anthony Wang, Nusair Islam
; This code was blessed by Allah (cc)
; Copyrights reserved. c 2020, Group Marimba


;testing -------------------------------
; ; Function to play audio through the speaker
; Play_Sound_Using_Index:
; 	push b
; 	setb SOUND ; Turn speaker on
; 	clr TMOD20 ; Stop the CCU from playing previous request
; 	setb FLASH_CE
;
; 	; There are three bytes per row in our tables, so multiply index by three
; 	mov b, #3
; 	mul ab
; 	mov R0, a ; Make a copy of the index*3
;
; 	clr FLASH_CE ; Enable SPI Flash
; 	mov a, #READ_BYTES
; 	lcall Send_SPI
; 	; Set the initial position in memory of where to start playing
; 	mov dptr, #sound_index
; 	mov a, R0
; 	movc a, @a+dptr
; 	lcall Send_SPI
; 	inc dptr
; 	mov a, R0
; 	movc a, @a+dptr
; 	lcall Send_SPI
; 	inc dptr
; 	mov a, R0
; 	movc a, @a+dptr
; 	lcall Send_SPI
; 	; Now set how many bytes to play
; 	mov dptr, #Size_Length
; 	mov a, R0
; 	movc a, @a+dptr
; 	mov w+2, a
; 	inc dptr
; 	mov a, R0
; 	movc a, @a+dptr
; 	mov w+1, a
; 	inc dptr
; 	mov a, R0
; 	movc a, @a+dptr
; 	mov w+0, a
;
; 	mov a, #0x00 ; Request first byte to send to DAC
; 	lcall Send_SPI
;
; 	setb TMOD20 ; Start playback by enabling CCU timer
; 	pop b
; 	ret
;
; ; Approximate index of sounds in file 'Project1Sounds.wav'
; sound_index:
;     db 0x00, 0x00, 0x2b ; 0
;     db 0x00, 0x26, 0xc0 ; 1
;     db 0x00, 0x4f, 0xea ; 2
;     db 0x00, 0x7d, 0xe5 ; 3
;     db 0x00, 0xb6, 0x58 ; 4
;     db 0x00, 0xec, 0x17 ; 5
;     db 0x01, 0x2c, 0x1c ; 6
;     db 0x01, 0x63, 0x25 ; 7
;     db 0x01, 0x8f, 0x85 ; 8
;     db 0x01, 0xc7, 0x20 ; 9
;     db 0x02, 0x02, 0x56 ; 10
;     db 0x02, 0x41, 0x0d ; 11
;     db 0x02, 0x7c, 0x5e ; 12
;     db 0x02, 0xbd, 0xe4 ; 13
;     db 0x03, 0x0b, 0xea ; 14
;     db 0x03, 0x4d, 0x6d ; 15
;     db 0x03, 0x98, 0xaa ; 16
;     db 0x03, 0xed, 0x93 ; 17
;     db 0x04, 0x33, 0xa0 ; 18
;     db 0x04, 0x86, 0xd8 ; 19
;     db 0x04, 0xd2, 0x88 ; 20
;     db 0x05, 0x0c, 0x03 ; 21
;     db 0x05, 0x4b, 0x73 ; 22
;     db 0x05, 0x8a, 0xbc ; 23
;     db 0x05, 0xd0, 0x2a ; 24
;     db 0x06, 0x13, 0x3f ; 25
;     db 0x06, 0x42, 0x0f ; 26
;     db 0x06, 0x7e, 0xa9 ; 27
;     db 0x06, 0xbb, 0x20 ; 28
;     db 0x06, 0xef, 0x15 ; 29
;     db 0x07, 0x19, 0x31 ; 30
;     db 0x07, 0x51, 0x7c ; 31
;     db 0x07, 0x93, 0x94 ; 32
;     db 0x07, 0xce, 0x4e ; 33
;     db 0x08, 0x0a, 0x56 ; 34
;     db 0x08, 0x4d, 0x94 ; 35
;     db 0x08, 0x92, 0x50 ; 36
;     db 0x08, 0xcc, 0x77 ; 37
;     db 0x08, 0xf6, 0x71 ; 38
;     db 0x09, 0x35, 0x97 ; 39
;     db 0x09, 0x77, 0xb6 ; 40
;     db 0x09, 0xa8, 0xb0 ; 41
;     db 0x09, 0xea, 0xff ; 42
;     db 0x0a, 0x0e, 0x6a ; 43
;     db 0x0a, 0x36, 0xc4 ; 44
;     db 0x0a, 0x6f, 0x37 ; 45
;     db 0x0a, 0x8e, 0xfe ; 46
;     db 0x0a, 0xb8, 0xc4 ; 47
;     db 0x0a, 0xd9, 0xbc ; 48
;     db 0x0a, 0xf9, 0xe7 ; 49
;     db 0x0b, 0x31, 0xe8 ; 50
;     db 0x0b, 0x63, 0xee ; 51
;     db 0x0b, 0xb3, 0x56
;
; ; Size of each sound in 'sound_index'
; Size_Length:
;     db 0x00, 0x26, 0x95 ; 0 = '1'
;     db 0x00, 0x29, 0x2a ; 1 = '2'
;     db 0x00, 0x2d, 0xfb ; 2 = '3'
;     db 0x00, 0x38, 0x73 ; 3 = '4'
;     db 0x00, 0x35, 0xbf ; 4 = '5'
;     db 0x00, 0x40, 0x05 ; 5 = '6'
;     db 0x00, 0x37, 0x09 ; 6 = '7'
;     db 0x00, 0x2c, 0x60 ; 7 = '8'
;     db 0x00, 0x37, 0x9b ; 8 = '9'
;     db 0x00, 0x3b, 0x36 ; 9 = '10'
;     db 0x00, 0x3e, 0xb7 ; 10 = '11'
;     db 0x00, 0x3b, 0x51 ; 11 = '12'
;     db 0x00, 0x41, 0x86 ; 12 = '13'
;     db 0x00, 0x4e, 0x06 ; 13 = '14'
;     db 0x00, 0x41, 0x83 ; 14 = '15'
;     db 0x00, 0x4b, 0x3d ; 15 = '16'
;     db 0x00, 0x54, 0xe9 ; 16 = '17'
;     db 0x00, 0x46, 0x0d ; 17 = '18'
;     db 0x00, 0x53, 0x38 ; 18 = '19'
;     db 0x00, 0x4b, 0xb0 ; 19 = '20'
;     db 0x00, 0x39, 0x7b ; 20 = '30'
;     db 0x00, 0x3f, 0x70 ; 21 = '40'
;     db 0x00, 0x3f, 0x49 ; 22 = '50'
;     db 0x00, 0x45, 0x6e ; 23 = '60'
;     db 0x00, 0x43, 0x15 ; 24 = '70'
;     db 0x00, 0x2e, 0xd0 ; 25 = '80'
;     db 0x00, 0x3c, 0x9a ; 26 = '90'
;     db 0x00, 0x3c, 0x77 ; 27 = 'hundred'
;     db 0x00, 0x33, 0xf5 ; 28 = 'ramp'
;     db 0x00, 0x2a, 0x1c ; 29 = 'to'
;     db 0x00, 0x38, 0x4b ; 30 = 'soak'
;     db 0x00, 0x42, 0x18 ; 31 = 'reflow'
;     db 0x00, 0x3a, 0xba ; 32 = 'cooling'
;     db 0x00, 0x3c, 0x08 ; 33 = 'stage'
;     db 0x00, 0x43, 0x3e ; 34 = 'seconds'
;     db 0x00, 0x44, 0xbc ; 35 = 'celsius'
;     db 0x00, 0x3a, 0x27 ; 36 = 'current_temp'
;     db 0x00, 0x29, 0xfa ; 37 = 'ding'
;     db 0x00, 0x3f, 0x26 ; 38 = 'soldering'
;     db 0x00, 0x42, 0x1f ; 39 = 'complete'
;     db 0x00, 0x30, 0xfa ; 40 = 'oven'
;     db 0x00, 0x42, 0x4f ; 41 = 'temperature'
;     db 0x00, 0x23, 0x6b ; 42 = 'is'
;     db 0x00, 0x28, 0x5a ; 43 = 'time'
;     db 0x00, 0x38, 0x73 ; 44 = 'remaining'
;     db 0x00, 0x1f, 0xc7 ; 45 = 'in'
;     db 0x00, 0x29, 0xc6 ; 46 = 'please'
;     db 0x00, 0x20, 0xf8 ; 47 = 'kill'
;     db 0x00, 0x20, 0x2b ; 48 = 'me'
;     db 0x00, 0x38, 0x01 ; 49 = 'aborting'
;     db 0x00, 0x32, 0x06 ; 50 = 'process'
;     db 0x00, 0x4f, 0x68 ; 51 = 'switch'

; FSM to say current temperature reading
T2S_FSM:
	mov a, T2S_FSM_state

T2S_FSM_State0: ; Checks for the start signal (T2S_FSM_Start==1) "T2S_FSM_Start==1 when routine is called by controller"
	cjne a, #0, T2S_FSM_State1
	jnb T2S_FSM_Start, T2S_FSM_State0_Done
	; Check if current_temp is larger than 19
	clr c
	mov a, current_temp
	mov r7, a
	subb a, #20
	jnc current_temp_gt_19
	mov T2S_FSM_state, #1
	sjmp T2S_FSM_State0_Done
current_temp_gt_19:
	mov T2S_FSM_state, #3
T2S_FSM_State0_Done:
	ret

T2S_FSM_State1: ; Plays current_temp when current_temp is less than 20
	cjne a, #1, T2S_FSM_State2
	mov a, r7
	subb a, #1 ;each index is 1 less than what is wants to say
	lcall Play_Sound_Using_Index
	mov T2S_FSM_State, #2
	ret

T2S_FSM_State2: ; Stay in this state until value <19 finishes playing
	cjne a, #2, T2S_FSM_State3
	jb TMOD20, T2S_FSM_State2_Done
	mov T2S_FSM_State, #8
T2S_FSM_State2_Done:
	ret

T2S_FSM_State3: ; Plays the hundreds when current_temp is larger than 19, for example for 42 current_temp, it plays 'forty'
	cjne a, #3, T2S_FSM_State4
	mov a, r7
	mov b, #100
	div ab
	jz lt_100
	subb a, #1
	lcall Play_Sound_Using_Index ;plays hundredth digit
	mov T2S_FSM_State, #4
	ret
lt_100:
	mov T2S_FSM_State, #5
	ret

T2S_FSM_State4: ; Stay in this state until hundredth position finishes playing
	cjne a, #4, T2S_FSM_State5
	jb TMOD20, T2S_FSM_State4_Done
	mov T2S_FSM_State, #10
T2S_FSM_State4_Done:
    ret

T2S_FSM_State5: ; Plays the tens when current_temp is larger than 19, for example for 42 current_temp, it plays 'forty'
	cjne a, #5, T2S_FSM_State6
	mov a, b ;put remainder into a
	mov r6, a
	mov b, #10
	div ab
	cjne a, #1, ten_not_1
	mov T2S_FSM_State, #15
	ret
ten_not_1:
	jz T2S_FSM_STATE5_Done ;if number has no tens place,
	add a, #17
	lcall Play_Sound_Using_Index
T2S_FSM_STATE5_Done:
	mov T2S_FSM_State, #6
	ret

T2S_FSM_State6: ; Stay in this state until sound finishes playing
	cjne a, #6, T2S_FSM_State7
	jb TMOD20, T2S_FSM_State6_Done
	mov T2S_FSM_State, #7
T2S_FSM_State6_Done:
    ret

T2S_FSM_State7: ; Plays the ones when current_temp is larger than 19, for example for 42 current_temp, it plays 'two'
	cjne a, #7, T2S_FSM_State8 ;go to state11 buffer
	mov a, b
	mov b, #10
	div ab
	mov a, b
	jz T2S_FSM_State7_Done ; Prevents from playing something like 'forty zero'
	subb a, #1
	lcall Play_Sound_Using_Index
T2S_FSM_State7_Done:
	mov T2S_FSM_State, #11
	ret

T2S_FSM_State8: ; Plays the words 'degrees'
	cjne a, #8, T2S_FSM_State9
	mov a, #36 ; Index 36 has the words 'degrees'
	lcall Play_Sound_Using_Index ; "degrees"
	mov T2S_FSM_State, #9
	ret

T2S_FSM_State9: ; Stay in this state until sound finishes playing
	cjne a, #9, T2S_FSM_State10
	jb TMOD20, T2S_FSM_State9_Done
	clr T2S_FSM_Start
	mov T2S_FSM_State, #0
T2S_FSM_State9_Done:
	ret

T2S_FSM_State10: ; Plays the word 'hundred'
	cjne a, #10, T2S_FSM_State11
	mov a, #27
	lcall Play_Sound_Using_Index ;plays 'hundred' word
	mov T2S_FSM_State, #17
	ret

T2S_FSM_State11: ;buffer to play ones units
	cjne a, #11, T2S_FSM_State15
	jb TMOD20, T2S_FSM_State11_Done
	mov T2S_FSM_State, #8
T2S_FSM_State11_Done:
	ret

T2S_FSM_State15: ; Plays current_temp when current_temp is less than 20
	cjne a, #15, T2S_FSM_State16
	mov a, r6
	subb a, #1 ;each index is 1 less than what is wants to say
	lcall Play_Sound_Using_Index
	mov T2S_FSM_State, #16
	ret

T2S_FSM_State16: ; Stay in this state to wait for current_temp value to play
	cjne a, #16, T2S_FSM_State17
	jb TMOD20, T2S_FSM_State16_Done
	mov T2S_FSM_State, #8
T2S_FSM_State16_Done:
	ret

T2S_FSM_State17: ; Stay in this state to wait for current_temp value to play
	cjne a, #17, T2S_FSM_Error
	jb TMOD20, T2S_FSM_State17_Done
	mov T2S_FSM_State, #5
T2S_FSM_State17_Done:
	ret

T2S_FSM_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov T2S_FSM_state, #0
	clr T2S_FSM_Start
	ret
; End of FSM that plays current_temp and seconds

;---------------------------------------------------Start of FSM for stages------------------------------------------

;FSM to say RamptoSoak;-----------------------------------------
Say_RamptoSoak:
	mov a, RamptoSoak_State

RamptoSoak_State0: ; Play first word
	cjne a, #0, RamptoSoak_State1
	jnb Say_RamptoSoak_flag, Say_RamptoSoak_done
	clr c
	mov a, #28
  lcall Play_Sound_Using_Index ;"Ramp"
	mov RamptoSoak_State, #1
Say_RamptoSoak_done:
	ret

RamptoSoak_State1: ; Wait for first word to finish playing
	cjne a, #1, RamptoSoak_State2
	jb TMOD20, RamptoSoak_State1_done
	mov RamptoSoak_State, #2
RamptoSoak_State1_done:
	ret

RamptoSoak_State2:
	cjne a, #2, RamptoSoak_State3
	mov a, #29
	lcall Play_Sound_Using_Index ; "to"
	mov RamptoSoak_State, #3
	ret

RamptoSoak_State3: ; Wait for second word to finish playing
	cjne a, #3, RamptoSoak_State4
	jb TMOD20, RamptoSoak_State3_done
	mov RamptoSoak_State, #4
RamptoSoak_State3_done:
	ret

RamptoSoak_State4:
	cjne a, #4, RamptoSoak_State5
	mov a, #30
  lcall Play_Sound_Using_Index ; "Soak"
	mov RamptoSoak_State, #5
	ret

RamptoSoak_State5: ; Wait for third word to finish playing
	cjne a, #5, RamptoSoak_Error
	jb TMOD20, RamptoSoak_State5_done
	clr Say_RamptoSoak_flag
	mov RamptoSoak_State, #0
RamptoSoak_State5_done:
	ret

RamptoSoak_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov RamptoSoak_State, #0
	clr Say_RamptoSoak_flag
	ret

;FSM to say Soak-----------------------------
Say_Soak:
	mov a, Soak_State

Soak_State0: ; Play first word
	cjne a, #0, Soak_State1
	jnb Say_Soak_flag, Say_Soak_done
	clr c
	mov a, #30
  lcall Play_Sound_Using_Index ; "Soak"
	mov Soak_State, #1
Say_Soak_done:
	ret

Soak_State1: ; Wait for first word to finish playing
	cjne a, #1, Soak_Error
	jb TMOD20, Soak_State1_done
	mov Soak_State, #0
	clr Say_Soak_flag
Soak_State1_done:
	ret

Soak_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Soak_State, #0
	clr Say_Soak_flag
	ret

;FSM to say RamptoReflow-----------------------------
Say_RamptoReflow:
	mov a, RamptoReflow_State

RamptoReflow_State0: ; Play first word
	cjne a, #0, RamptoReflow_State1
	jnb Say_RamptoReflow_flag, Say_RamptoReflow_done
	clr c
	mov a, #28
  lcall Play_Sound_Using_Index ; "Ramp"
	mov RamptoReflow_State, #1
Say_RamptoReflow_done:
	ret

RamptoReflow_State1: ; Wait for first word to finish playing
	cjne a, #1, RamptoReflow_State2
	jb TMOD20, RamptoReflow_State1_done
	mov RamptoReflow_State, #2
RamptoReflow_State1_done:
	ret

RamptoReflow_State2:
	cjne a, #2, RamptoReflow_State3
	mov a, #29
	lcall Play_Sound_Using_Index ; "to"
	mov RamptoReflow_State, #3
	ret

RamptoReflow_State3: ; Wait for second word to finish playing
	cjne a, #3, RamptoReflow_State4
	jb TMOD20, RamptoReflow_State3_done
	mov RamptoReflow_State, #4
RamptoReflow_State3_done:
	ret

RamptoReflow_State4:
	cjne a, #4, RamptoReflow_State5
	mov a, #31
  lcall Play_Sound_Using_Index ; "Reflow"
	mov RamptoReflow_State, #5
	ret

RamptoReflow_State5: ; Wait for third word to finish playing
	cjne a, #5, RamptoReflow_Error
	jb TMOD20, RamptoReflow_State5_done
	clr Say_RamptoReflow_flag
	mov RamptoReflow_State, #0
RamptoReflow_State5_done:
	ret

RamptoReflow_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov RamptoReflow_State, #0
	clr Say_RamptoReflow_flag
	ret


;FSM to say Reflow---------------------
Say_Reflow:
	mov a, Reflow_State

Reflow_State0: ; Play first word
	cjne a, #0, Reflow_State1
	jnb Say_Reflow_flag, Say_Reflow_done
	clr c
	mov a, #31
  lcall Play_Sound_Using_Index ; "Reflow"
	mov Reflow_State, #1
Say_Reflow_done:
	ret

Reflow_State1: ; Wait for first word to finish playing
	cjne a, #1, Reflow_Error
	jb TMOD20, Reflow_State1_done
	mov Reflow_State, #0
	clr Say_Reflow_flag
Reflow_State1_done:
	ret

Reflow_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Reflow_State, #0
	ret

;FSM to say Cooling-------------------
Say_Cooling:
	mov a, Cooling_State

Cooling_State0: ; Play first word
	cjne a, #0, Cooling_State1
	jnb Say_Cooling_flag, Say_Cooling_done
	clr c
	mov a, #32
  lcall Play_Sound_Using_Index ; "Cooling"
	mov Cooling_State, #1
Say_Cooling_done:
	ret

Cooling_State1: ; Wait for first word to finish playing
	cjne a, #1, Cooling_Error
	jb TMOD20, Cooling_State1_done
	mov Cooling_State, #0
	clr Say_Cooling_flag
Cooling_State1_done:
	ret

Cooling_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Cooling_State, #0
	ret

;FSM for Aborting Process-----------------
Say_AbortingProcess:
	mov a, AbortingProcess_State

AbortingProcess_State0: ; Play first word
	cjne a, #0, AbortingProcess_State1
	jnb Say_AbortingProcess_flag, Say_AbortingProcess_done
	clr c
	mov a, #49
  lcall Play_Sound_Using_Index ; "Aborting"
	mov AbortingProcess_State, #1
Say_AbortingProcess_done:
	ret

AbortingProcess_State1: ; Wait for first word to finish playing
	cjne a, #1, AbortingProcess_State2
	jb TMOD20, AbortingProcess_State1_done
	mov AbortingProcess_State, #2
AbortingProcess_State1_done:
	ret

AbortingProcess_State2:
	cjne a, #2, AbortingProcess_State3
	mov a, #50
  lcall Play_Sound_Using_Index ; "Process"
	mov AbortingProcess_State, #3
	ret

AbortingProcess_State3: ; Wait for second word to finish playing
	cjne a, #3, AbortingProcess_Error
	jb TMOD20, AbortingProcess_State3_done
	mov AbortingProcess_State, #0
	clr Say_AbortingProcess_flag
AbortingProcess_State3_done:
	ret

AbortingProcess_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov AbortingProcess_State, #0
	clr Say_AbortingProcess_flag
	ret

;FSM to say Ding------------------
Say_Ding:
	mov a, Ding_State

Ding_State0: ; Play first word
	cjne a, #0, Ding_State1
	jnb Say_Ding_flag, Say_Ding_done
	clr c
	mov a, #37
  lcall Play_Sound_Using_Index ; "Ding"
	mov Ding_State, #1
Say_Ding_done:
	ret

Ding_State1: ; Wait for first word to finish playing
	cjne a, #1, Ding_Error
	jb TMOD20, Ding_State1_done
	mov Ding_State, #0
	clr Say_Ding_flag
Ding_State1_done:
	ret

Ding_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov Ding_State, #0
	clr Say_Ding_flag
	ret

;FSM to say Soldering Process Complete---------------------
Say_SolderingProcessComplete:
	mov a, SolderingProcessComplete_State

SolderingProcessComplete_State0: ; Play first word
	cjne a, #0, SolderingProcessComplete_State1
	jnb Say_SolderingProcessComplete_flag, Say_SolderingProcessComplete_done
	clr c
	mov a, #38
  lcall Play_Sound_Using_Index ; "Soldering"
	mov SolderingProcessComplete_State, #1
Say_SolderingProcessComplete_done:
	ret

SolderingProcessComplete_State1: ; Wait for first word to finish playing
	cjne a, #1, SolderingProcessComplete_State2
	jb TMOD20, SolderingProcessComplete_State1_done
	mov SolderingProcessComplete_State, #2
SolderingProcessComplete_State1_done:
	ret

SolderingProcessComplete_State2:
	cjne a, #2, SolderingProcessComplete_State3
	mov a, #50
	lcall Play_Sound_Using_Index ; "Process"
	mov SolderingProcessComplete_State, #3
	ret

SolderingProcessComplete_State3: ; Wait for second word to finish playing
	cjne a, #3, SolderingProcessComplete_State4
	jb TMOD20, SolderingProcessComplete_State3_done
	mov SolderingProcessComplete_State, #4
SolderingProcessComplete_State3_done:
	ret

SolderingProcessComplete_State4:
	cjne a, #4, SolderingProcessComplete_State5
	mov a, #39
  lcall Play_Sound_Using_Index ; "Complete"
	mov SolderingProcessComplete_State, #5
	ret

SolderingProcessComplete_State5: ; Wait for third word to finish playing
	cjne a, #5, SolderingProcessComplete_Error
	jb TMOD20, SolderingProcessComplete_State5_done
	clr Say_SolderingProcessComplete_flag
	mov SolderingProcessComplete_State, #0
SolderingProcessComplete_State5_done:
	ret

SolderingProcessComplete_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov SolderingProcessComplete_State, #0
	clr Say_SolderingProcessComplete_flag
	ret

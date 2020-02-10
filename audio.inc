; Audio feedback routine
; Written by: Michael O'Keefe, Anthony Wang, Nusair Islam
; This code was blessed by Allah (cc)
; Copyrights reserved. c 2020, Group Marimba

;$NOLIST
;$MOD9351
;$LIST

; BSEG
; T2S_FSM_start: dbit 1
;
; dseg  at 30h
; T2S_FSM_state: ds 1
; current_temp:       ds 1
; w:						 ds 3
;
; cseg
;
; ; Function to play audio through the speaker
; Play_Sound_Using_Index:
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
;
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

T2S_FSM:
	mov a, T2S_FSM_state

T2S_FSM_State0: ; Checks for the start signal (T2S_FSM_Start==1) "T2S_FSM_Start==1 when routine is called by controller"
	cjne a, #0, T2S_FSM_State1
	jnb T2S_FSM_Start, T2S_FSM_State0_Done
	; Check if current_temp is larger than 19
	clr c
	mov a, current_temp
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
	mov a, current_temp
	subb a, #1 ;each index is 1 less than what is wants to say
	lcall Play_Sound_Using_Index
	mov T2S_FSM_State, #2
	ret

T2S_FSM_State2: ; Stay in this state until value >10 finishes playing
	cjne a, #2, T2S_FSM_State3
	jb TMOD20, T2S_FSM_State2_Done
	mov T2S_FSM_State, #8
T2S_FSM_State2_Done:
	ret

T2S_FSM_State3: ; Plays the hundreds when current_temp is larger than 19, for example for 42 current_temp, it plays 'forty'
	cjne a, #3, T2S_FSM_State4
	mov a, current_temp
	mov b, #100
	div ab
	jz T2S_FSM_State3_Done
	lcall Play_Sound_Using_Index ;plays hundredth digit
  mov a, #27
  lcall Play_Sound_Using_Index ;plays 'hundred' word

T2S_FSM_State3_Done:
	mov R3, b
	mov T2S_FSM_State, #4
	ret

T2S_FSM_State4: ; Stay in this state until hundredth position finishes playing
	cjne a, #4, T2S_FSM_State5
	jb TMOD20, T2S_FSM_State4_Done
	mov T2S_FSM_State, #5
T2S_FSM_State4_Done:
    ret

T2S_FSM_State5: ; Plays the tens when current_temp is larger than 19, for example for 42 current_temp, it plays 'forty'
	cjne a, #5, T2S_FSM_State6
	;mov a, current_temp
	mov a, R3 ;put remainder into a
	mov b, #10
	div ab
	jz T2S_FSM_STATE5_Done ;if number has no tens place, skip
	add a, #18
	lcall Play_Sound_Using_Index
T2S_FSM_STATE5_Done:
	mov R4, b
	mov T2S_FSM_State, #6
	ret

T2S_FSM_State6: ; Stay in this state until sound finishes playing
	cjne a, #6, T2S_FSM_State7
	jb TMOD20, T2S_FSM_State6_Done
	mov T2S_FSM_State, #7

T2S_FSM_State6_Done:
    ret

T2S_FSM_State7: ; Plays the units when current_temp is larger than 19, for example for 42 current_temp, it plays 'two'
	cjne a, #7, T2S_FSM_State8
	;mov a, current_temp
	mov a, R4
	mov b, #10
	div ab
	mov a, b
	jz T2S_FSM_State7_Done ; Prevents from playing something like 'forty zero'
	lcall Play_Sound_Using_Index

T2S_FSM_State7_Done:
	mov T2S_FSM_State, #8
	ret

T2S_FSM_State8: ; Plays the words 'current_temp ce'
	cjne a, #8, T2S_FSM_State9
	mov a, #36 ; Index 36 has the words 'current_temp'
	lcall Play_Sound_Using_Index ; "current_temp"
  mov a, #35
  lcall Play_Sound_Using_Index ; "celsius"
	mov T2S_FSM_State, #9
	ret

T2S_FSM_State9: ; Stay in this state until sound finishes playing
	cjne a, #9, T2S_FSM_Error
	jb TMOD20, T2S_FSM_State9_Done
	clr T2S_FSM_Start
	;mov T2S_FSM_State, #0
T2S_FSM_State9_Done:
	mov T2S_FSM_state, #0
	clr T2S_FSM_Start
	ret

T2S_FSM_Error: ; If we got to this point, there is an error in the finite state machine.  Restart it.
	mov T2S_FSM_state, #0
	clr T2S_FSM_Start
	ret
; End of FSM that plays current_temp and seconds

Say_RamptoSoak:
  mov a, #28
  lcall Play_Sound_Using_Index ;"Ramp"
	jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #29
  lcall Play_Sound_Using_Index ; "to"
	jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #30
  lcall Play_Sound_Using_Index ; "Soak"
	jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #33
  lcall Play_Sound_Using_Index ; "Stage"
	jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_Soak:
  mov a, #30
  lcall Play_Sound_Using_Index ; "Soak"
	jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #33
  lcall Play_Sound_Using_Index ; "Stage"
	jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_RamptoReflow:
  mov a, #28
  lcall Play_Sound_Using_Index ; "Ramp"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #29
  lcall Play_Sound_Using_Index ; "to"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #31
  lcall Play_Sound_Using_Index ; "Reflow"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #33
  lcall Play_Sound_Using_Index ; "Stage"
  jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_Reflow:
  mov a, #31
  lcall Play_Sound_Using_Index ; "Reflow"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #33
  lcall Play_Sound_Using_Index ; "Stage"
  jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_Cooling:
  mov a, #32
  lcall Play_Sound_Using_Index ; "Cooling"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #33
  lcall Play_Sound_Using_Index ; "Stage"
  jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_AbortingProcess:
  mov a, #49
  lcall Play_Sound_Using_Index ; "Aborting"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #50
  lcall Play_Sound_Using_Index ; "Process"
  jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_Ding:
  mov a, #37
  lcall Play_Sound_Using_Index ; "Ding"
  jb TMOD20, $ ; Wait for sound to finish playing
  ret

Say_SolderingProcessComplete:
  mov a, #38
  lcall Play_Sound_Using_Index ; "Soldering"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #50
  lcall Play_Sound_Using_Index ; "Process"
  jb TMOD20, $ ; Wait for sound to finish playing
  mov a, #39
  lcall Play_Sound_Using_Index ; "Complete"
  jb TMOD20, $ ; Wait for sound to finish playing
  ret

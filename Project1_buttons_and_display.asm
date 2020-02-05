$NOLIST
$MOD9351
$LIST

CLK             EQU 7373000  ; Microcontroller system crystal frequency in Hz
TIMER0_RATE     EQU 4096     ; 2048Hz squ	arewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD   EQU ((65536-(CLK/(2*TIMER0_RATE))))
TIMER1_RATE     EQU 100     ; 100Hz, for a timer tick of 10ms

SELECT_BUTTON   EQU P1.7
HUNDREDS_BUTTON EQU P1.6
TENS_BUTTON     EQU P1.4
ONES_BUTTON     EQU P1.3

START_BUTTON    EQU P?.?
KILL_SWITCH:    EQU P?.?

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count10ms:    ds 1 ; Used to determine when half second has passed
set_ones:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
set_tens: ds 1
set_hundreds: ds 1

soak_temp_total: ds 1
soak_time_total: ds 1
reflow_temp_total: ds 1
reflow_time_total: ds 1

soak_temp: ds 1
soak_time: ds 1
reflow_temp: ds 1
reflow_time: ds 1

current_parameter: ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P0.7
LCD_RW equ P3.0
LCD_E  equ P3.1
LCD_D4 equ P2.0
LCD_D5 equ P2.1
LCD_D6 equ P2.2
LCD_D7 equ P2.3
$NOLIST
$include(LCD_4bit_LPC9351.inc) ; A library of LCD related functions and utility macros
$LIST

;                         1234567890123456    <- This helps determine the location of the counter

soak_time_display:    db 'Soak Time: xxx s', 0
soak_time_num:        db '      xxx  s    ', 0

soak_temp_display:    db 'Soak Temp:      ', 0
soak_temp_num:        db '      xxx C     ', 0

reflow_time_display:  db 'Reflow Time: xxx', 0
reflow_time_num:      db '      xxx  s    ', 0

reflow_temp_display:  db 'Reflow Temp: xxx', 0
reflow_temp_num:      db '      xxx C     ', 0

;increases ones
INC_ONES_Button:
	jb ONES_BUTTON, return_ones_button ; if the 'ONES' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb ONES_BUTTON, return_ones_button  ; if the 'ONES' button is not pressed skip
	jnb ONES_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
set_ones_button:
	mov a, set_ones
	add a, #0x01
	da a
	cjne a, #0x10, ones_button_done ;set max value for ones to be 10
	clr a
ones_button_done:
	mov set_ones, a
return_ones_button:
	ret

;increases tens
INC_TENS_Button:
	jb TENS_BUTTON, return_tens_button ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb TENS_BUTTON, return_tens_button  ; if the 'BOOT' button is not pressed skip
	jnb TENS_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
set_tens_button:
	mov a, set_tens
	add a, #0x01
	da a
	cjne a, #0x10, tens_button_done ;set max value for seconds to be 60
	clr a
tens_button_done:
	mov set_tens, a
return_tens_button:
	ret

;increases hundreds
INC_HUNDREDS_Button:
	jb HUNDREDS_BUTTON, return_hundreds_button ; if the 'ONES' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb HUNDREDS_BUTTON, return_hundreds_button  ; if the 'ONES' button is not pressed skip
	jnb HUNDREDS_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
set_hundreds_button:
	mov a, set_hundreds
	add a, #0x01
	da a
	cjne a, #0x10, hundreds_button_done ;set max value for ones to be 10
	clr a
hundreds_button_done:
	mov set_hundreds, a
return_hundreds_button:
	ret

;triggers alarm mode
check_parameter_mode:
	jb SELECT_BUTTON, select_quick_exit  ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb SELECT_BUTTON, select_quick_exit  ; if the 'BOOT' button is not pressed skip
	jnb SELECT_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.

	mov a, #0x01 ;  Clear screen command (takes some time)
    lcall ?WriteCommand
    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    Wait_Milli_Seconds(#2)

	mov a, current_parameter
  cjne a, #0x01,
	sjmp set_alarm_display

select_quick_exit:
	ret

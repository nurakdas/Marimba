; PWMtest.asm
; Date: 2020/02/03
; Author: Andrew Hanlon

$NOLIST
$MOD9351
$LIST

XTAL equ 14746000

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

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:    ds 1 ; Used to determine when half second has passed
Count1s: ds 1
Count_state: ds 1
BFSM1_timer: ds 1
BFSM2_timer: ds 1
BFSM3_timer: ds 1
BFSM4_timer: ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed

cseg

$NOLIST
$include(timers.inc)
$LIST

Double_Clk:
  mov dptr, #CLKCON
  movx a, @dptr
  orl a, #00001000B ; double the clock speed to 14.746MHz
  movx @dptr,a
  ret

; main =========================================================================
main:
	; Initialization
    mov SP, #0x7F
    lcall Double_Clk
    lcall Timer0_Init
    lcall Timer1_Init
    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1kohm pull-up resistors!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
    setb EA   ; Enable Global interrupts

    clr seconds_flag
    clr a
    mov PWM_Duty_Cycle255, #0

	; After initialization the program stays in this 'forever' loop
loop:
	jnb seconds_flag, loop
loop_b:
    clr seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 1
    mov a, PWM_Duty_Cycle255
    add a, #15
    mov PWM_Duty_Cycle255, a
    ljmp loop
END

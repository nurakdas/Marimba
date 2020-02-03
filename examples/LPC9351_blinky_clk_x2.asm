; Blinky.asm: blinks an LED connected to pin 0 of the 
; microcontroller each second.

$MOD9351

org 0000H
    ljmp myprogram
org 001BH
	ljmp 1803H ; Needed by the debugger if present

;For a 7.373MHz internal oscillator one machine cycle takes 2/7.373MHz =0.27126us
WaitHalfSec:
    mov R2, #20
L3: mov R1, #250
L2: mov R0, #184
L1: djnz R0, L1 ; 2 machine cycles-> 2*0.27126us*184=100us
    djnz R1, L2 ; 100us*250=0.025s
    djnz R2, L3 ; 0.025s*20=0.5s
    ret

myprogram:
    mov SP, #7FH
    ;Since we will be using P0.0, make it bi-directional...
    mov P0M1, #00H
    mov P0M2, #00H
    
    mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B ; double the clock speed to 14.746MHz
    movx @dptr,a
M0:
    cpl P0.0
    lcall WaitHalfSec
    jmp M0
END

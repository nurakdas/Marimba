$MOD9351

XTAL EQU 14746000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

	CSEG at 0x0000
	ljmp	MainProgram

putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret
	
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

Wait1S:
	mov R2, #40
L3:	mov R1, #250
L2:	mov R0, #184
L1:	djnz R0, L1 ; 2 machine cycles-> 2*0.27126us*184=100us
	mov AD1DAT3, R1 ; Ouput a ramp to the DAC (P0.4)
	djnz R1, L2 ; 100us*250=0.025s
	djnz R2, L3 ; 0.025s*40=1s
	ret

InitSerialPort:
	mov	BRGCON,#0x00
	mov	BRGR1,#high(BRVAL)
	mov	BRGR0,#low(BRVAL)
	mov	BRGCON,#0x03 ; Turn-on the baud rate generator
	mov	SCON,#0x52 ; Serial port in mode 1, ren, txrdy, rxempty
	mov	P1M1,#0x00 ; Enable pins RxD and TXD
	mov	P1M2,#0x00 ; Enable pins RxD and TXD
	ret

SendString:
    clr a
    movc a, @a+dptr
    jz SendString_L1
    lcall putchar
    inc dptr
    sjmp SendString  
SendString_L1:
	ret

; Warning, the ADC/DAC can work only as ADC or DAC, not both
InitDAC:
    ; Configure pin P0.4 (DAC output pin) as open drain
	orl	P0M1,   #00010000B
	orl	P0M2,   #00010000B
    mov ADMODB, #00101000B ; Select main clock/2 for ADC/DAC.  Also enable DAC1 output (Table 25 of reference manual)
	mov	ADCON1, #00000100B ; Enable the converter
	ret
	
Double_Clk:
    mov dptr, #CLKCON
    movx a, @dptr
    orl a, #00001000B ; double the clock speed to 14.746MHz
    movx @dptr,a
	ret

InitialMessage: db '\r\nP89LPC9351 DAC test program\r\n', 0
	
MainProgram:
    mov SP, #0x7F
    
    lcall Double_Clk
	lcall InitSerialPort
	lcall InitDAC
    
	mov dptr, #InitialMessage
	lcall SendString
	
	; Connect an LED to P0.0.  Configure the pin as bidirection I/O. See Table 42.
	anl	P0M1,   #11111110B
	anl	P0M2,   #11111110B

forever_loop:
	lcall Wait1S
	cpl P0.0
	sjmp forever_loop

end

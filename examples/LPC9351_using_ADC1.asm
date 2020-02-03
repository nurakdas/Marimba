$MOD9351

XTAL EQU 7373000
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

InitADC1:
    ; Configure pins P0.4, P0.3, P0.2, and P0.1 as inputs
	orl	P0M1,#0x1E
	anl	P0M2,#0xE1
	setb BURST1 ; Autoscan continuos conversion mode
	mov	ADMODB,#0x20 ;ADC1 clock is 7.3728MHz/2
	mov	ADINS,#0xF0 ; Select the four channels for conversion
	mov	ADCON1,#0x05 ; Enable the converter and start immediately
	; Wait for first conversion to complete
InitADC1_L1:
	mov	a,ADCON1
	jnb	acc.3,InitADC1_L1
	ret

HexAscii: db '0123456789ABCDEF'

SendHex:
	mov a, #'0'
	lcall putchar
	mov a, #'x'
	lcall putchar
	mov dptr, #HexAscii 
	mov a, b
	swap a
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, b
	anl a, #0xf
	movc a, @a+dptr
	lcall putchar
	mov a, #' '
	lcall putchar
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

InitialMessage: db '\r\nP89LPC9351 ADC1 test program.  Input pins are P0.1, P0.2, P0.3, P0.4.\r\n', 0
	
MainProgram:
    mov SP, #0x7F
	lcall InitSerialPort
	lcall InitADC1

	lcall Wait1S ; Wait a bit so PUTTy has a chance to start
	mov dptr, #InitialMessage
	lcall SendString

forever_loop:
    ; Send the conversion results via the serial port to putty.
	mov a, #'\r' ; move cursor all the way to the left
    lcall putchar
    ; Display converted value from P0.1
	mov	b, AD1DAT0
	lcall SendHex
    ; Display converted value from P0.2
	mov	b, AD1DAT1
	lcall SendHex
    ; Display converted value from P0.3
	mov	b, AD1DAT2
	lcall SendHex
    ; Display converted value from P0.4
	mov	b, AD1DAT3
	lcall SendHex
	lcall Wait1S
	sjmp forever_loop

end

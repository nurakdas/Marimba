; This program shows how to read many push buttons using just one analog input.
; The idea is to make a voltage divider with many resistors and the push buttons
; connect the diferent voltages to an analog input.  In this example we have seven push
; buttons.  The diagram is in this image: push_button_adc.jpg.  The common pin of all
; the push buttons is connected to pin P0.4.
;

$MOD9351

XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

	CSEG at 0x0000
	ljmp	MainProgram

bseg
PB0: dbit 1 ; Variable to store the state of pushbutton 0 after calling ADC_to_PB below
PB1: dbit 1 ; Variable to store the state of pushbutton 1 after calling ADC_to_PB below
PB2: dbit 1 ; Variable to store the state of pushbutton 2 after calling ADC_to_PB below
PB3: dbit 1 ; Variable to store the state of pushbutton 3 after calling ADC_to_PB below
PB4: dbit 1 ; Variable to store the state of pushbutton 4 after calling ADC_to_PB below
PB5: dbit 1 ; Variable to store the state of pushbutton 5 after calling ADC_to_PB below
PB6: dbit 1 ; Variable to store the state of pushbutton 6 after calling ADC_to_PB below

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
M3:	mov R1, #250
M2:	mov R0, #184
M1:	djnz R0, M1 ; 2 machine cycles-> 2*0.27126us*184=100us
	djnz R1, M2 ; 100us*250=0.025s
	djnz R2, M3 ; 0.025s*40=1s
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

ADC_to_PB:
	setb PB6
	setb PB5
	setb PB4
	setb PB3
	setb PB2
	setb PB1
	setb PB0
	; Check PB6
	clr c
	mov a, AD1DAT3
	subb a, #(206-10) ; 2.8V=216*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L6
	clr PB6
	ret
ADC_to_PB_L6:
	; Check PB5
	clr c
	mov a, AD1DAT3
	subb a, #(185-10) ; 2.4V=185*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L5
	clr PB5
	ret
ADC_to_PB_L5:
	; Check PB4
	clr c
	mov a, AD1DAT3
	subb a, #(154-10) ; 2.0V=154*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L4
	clr PB4
	ret
ADC_to_PB_L4:
	; Check PB3
	clr c
	mov a, AD1DAT3
	subb a, #(123-10) ; 1.6V=123*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L3
	clr PB3
	ret
ADC_to_PB_L3:
	; Check PB2
	clr c
	mov a, AD1DAT3
	subb a, #(92-10) ; 1.2V=92*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L2
	clr PB2
	ret
ADC_to_PB_L2:
	; Check PB1
	clr c
	mov a, AD1DAT3
	subb a, #(61-10) ; 0.8V=61*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L1
	clr PB1
	ret
ADC_to_PB_L1:
	; Check PB1
	clr c
	mov a, AD1DAT3
	subb a, #(30-10) ; 0.4V=30*(3.3/255); the -10 is to prevent false readings
	jc ADC_to_PB_L0
	clr PB0
	ret
ADC_to_PB_L0:
	; No pusbutton pressed	
	ret

Display_PushButtons_ADC:
	Set_Cursor(2, 1)
	mov a, #'0'
	mov c, PB6
	addc a, #0
    lcall ?WriteData	
	mov a, #'0'
	mov c, PB5
	addc a, #0
    lcall ?WriteData	
	mov a, #'0'
	mov c, PB4
	addc a, #0
    lcall ?WriteData	
	mov a, #'0'
	mov c, PB3
	addc a, #0
    lcall ?WriteData	
	mov a, #'0'
	mov c, PB2
	addc a, #0
    lcall ?WriteData	
	mov a, #'0'
	mov c, PB1
	addc a, #0
    lcall ?WriteData	
	mov a, #'0'
	mov c, PB0
	addc a, #0
    lcall ?WriteData	
	ret

Title: db 'ADC push buttons', 0
InitialMessage: db '\r\nADC push buttons.  The push buttons voltage divider is connected to P0.4\r\n', 0
	
MainProgram:
    mov SP, #0x7F

    ; Configure all the ports in bidirectional mode:
    mov P0M1, #00H
    mov P0M2, #00H
    mov P1M1, #00H
    mov P1M2, #00H ; WARNING: P1.2 and P1.3 need 1kohm pull-up resistors!
    mov P2M1, #00H
    mov P2M2, #00H
    mov P3M1, #00H
    mov P3M2, #00H
	
	lcall InitSerialPort
	lcall InitADC1
	
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit_LPC9351.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Title)

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
	
	lcall ADC_to_PB
	lcall Display_PushButtons_ADC
	;lcall Wait1S
	
	sjmp forever_loop

end

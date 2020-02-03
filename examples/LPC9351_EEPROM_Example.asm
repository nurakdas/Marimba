$MOD9351

XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

CSEG at 0x0000
	ljmp	MainProgram

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

SendString:
    clr a
    movc a, @a+dptr
    jz SendString_L1
    lcall putchar
    inc dptr
    sjmp SendString  
SendString_L1:
	ret

; These two funcionts allow writing and reading to/from the internal EEPROM of
; the P89LPC9351

; Address to write to passed in DPTR.  Data to write passed in register 'A'
EEPROM_Write:
	mov DEECON, DPH ; ECTL1/ECTL0 (DEECON[5:4]) = ‘00’, EADR8
	mov DEEDAT, a ; Byte to write
	mov DEEADR, DPL ; Address to write to.  This initializes the write process
	; Wait for write operation to complete
EEPROM_Write_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_Write_L1 ; bit 7 of DEECON is EEIF
	ret

; Address to read from passed in DPTR.  Data read returned via register 'A'
EEPROM_Read:
	mov DEECON, DPH ; ECTL1/ECTL0 (DEECON[5:4]) = ‘00’, EADR8=0
	mov DEEADR, DPL ; Address to read from.  This initializes the write process
	; wait for read operation to complete
EEPROM_Read_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_Read_L1 ; bit 7 of DEECON is EEIF
	mov a, DEEDAT
	ret

Title: db 'EEPROM Test', 0
InitialMessage: db '\r\nEEPROM Test\r\n', 0
Pass: db 'PASS', 0
Fail: db 'FAIL', 0
	
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
	
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit_LPC9351.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Title)

	lcall Wait1S ; Wait a bit so PUTTy has a chance to start
	mov dptr, #InitialMessage
	lcall SendString

	; Write something to the EEPROM
	mov dptr, #0x0010
	mov a, #0x55
	lcall EEPROM_Write

	; Read back from the EEPROM
	mov dptr, #0x0010
	lcall EEPROM_Read

	; Check that what we read is what we wrote
	cjne a, #0x55, EEPROM_Fail

	; Try another address
	mov dptr, #0x0025
	mov a, #0xaa
	lcall EEPROM_Write

	; Read back from the EEPROM
	mov dptr, #0x0025
	lcall EEPROM_Read

	; Check that what we read is what we wrote
	cjne a, #0xaa, EEPROM_Fail

	Set_Cursor(2, 1)
    Send_Constant_String(#Pass)
    sjmp forever_loop
EEPROM_Fail:	
	Set_Cursor(2, 1)
    Send_Constant_String(#Fail)

forever_loop:
	sjmp forever_loop

end

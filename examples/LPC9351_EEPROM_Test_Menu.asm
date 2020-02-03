$MOD9351

XTAL EQU 7373000
BAUD EQU 115200
BRVAL EQU ((XTAL/BAUD)-16)

CSEG at 0x0000
	ljmp	MainProgram

DSEG at 0x30
ASCII_Line:  ds 16

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
    lcall putchar ; echo back what was received
	ret

Send_nl:
    mov a, #'\r'
    lcall putchar
    mov a, #'\n'
    lcall putchar
    ret

getbyte:
    push b
    ; Get most significant nibble
    lcall getchar
    anl a, #00011111B ; To deal with upercase/lowercase
    jb acc.4, getbyte_1
    add a, #9
getbyte_1:
    anl a, #00001111B
    swap a
    mov b, a
    ; Get least significant nibble
    lcall getchar
    anl a, #00011111B ; To deal with upercase/lowercase
    jb acc.4, getbyte_2
    add a, #9
getbyte_2:
    anl a, #00001111B
    orl a, b
    pop b
    ret

getaddress:
    push acc
    lcall getchar
    anl a, #00000001B
    mov dph, a
    lcall getbyte
    mov dpl, a
    pop acc
    ret

hex: db '0123456789abcdef',0

putbyte:
    ; Preserve used registers
    push acc
    push dpl
    push dph
    ; Display a hex byte 
    push acc
    mov dptr, #hex
    swap a
    anl a, #00001111B
    movc a,@a+dptr
    lcall putchar
    pop acc
    anl a, #00001111B
    movc a,@a+dptr
    lcall putchar
    ; Restore used registers
    pop dph
    pop dpl
    pop acc
    ret
    
putadd:
    ; Preserve used registers
    push acc
    push dpl
    push dph
    ; Display a hex address     
    mov a, dph
    push dpl
    mov dptr, #hex
    anl a, #00001111B
    movc a,@a+dptr
    lcall putchar
    pop acc
    lcall putbyte
    ; Restore used registers
    pop dph
    pop dpl
    pop acc
    ret
    
Add_msg: DB '\r\nAddress: ', 0
Val_msg: DB '\r\nValue: ', 0
    
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

; These two functions allow writing and reading to/from the internal EEPROM of
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

EEPROM_BlockFill:
	mov DEECON, #00110001B
	mov DEEDAT, a ; Byte to write
	mov DEEADR, #0 ; Address to write to.  This initializes the write process
	; Wait for write operation to complete
EEPROM_BlockFill_L1:
	mov a, DEECON
	jnb acc.7, EEPROM_BlockFill_L1 ; bit 7 of DEECON is EEIF
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

Write_Byte:
    mov dptr, #Add_msg
    lcall SendString
    lcall getaddress
    push dpl
    push dph
    mov dptr, #Val_msg
    lcall SendString
    lcall getbyte
    pop dph
    pop dpl
    lcall EEPROM_Write
    ret

Display_memory:
    mov dptr, #0
Display_memory_0:
    mov a, dpl
    anl a, #0x0f
    jnz Display_memory_1
    lcall Send_nl
    lcall putadd
    mov a, #':'
    lcall putchar
    mov a, #' '
    lcall putchar
Display_memory_1:
    lcall EEPROM_Read
    mov b, a ; Make a copy
    
    ; Fill the line of ASCII characters
    mov a, dpl
    anl a, #00001111B
    add a, #ASCII_Line
    mov R0, a
    
    ; If the value is larger than 0x7e display a '.'
    mov a, b
    clr c
    subb a, #0x7e
    jnc adddot
    
    ; If the value is smaller than 0x20 display a '.'
    mov a, b
    clr c
    subb a, #0x20
    jc adddot
    ; The value read is betwee 0x20 and 0x7e, display as ASCII
    mov @R0, b
    sjmp good_ascii
adddot:
    mov @R0, #'.'
good_ascii:

    mov a, b
    lcall putbyte
    mov a, #' '
    lcall putchar
    inc dptr
    
    ; Display the line of ASCII characters
    mov a, dpl
    anl a, #00001111B
    jnz skip_ascii
    mov R0, #ASCII_Line
    mov R1, #16
out_ascii:
    mov a, @R0
    lcall putchar
    inc R0
    djnz R1, out_ascii
   
skip_ascii:
    mov a, dph
    jb acc.1, Display_memory_2
    sjmp Display_memory_0
Display_memory_2:      
    lcall Send_nl
    lcall Send_nl
    ret

Erase_memory:
	mov a, #0xff
	lcall EEPROM_BlockFill
    lcall Send_nl
    ret

Fill_memory:
    mov dptr, #Val_msg
    lcall SendString
    lcall getbyte
    lcall EEPROM_BlockFill
    lcall Send_nl
    ret
    
test_msg: db '\r\nTest patern ', 0
error_msg: db ' error', 0
ok_msg: db 'Pass!', 0

test_byte mac
   mov b, #low(%0)
   lcall ?test_byte
endmac

?test_byte:
    mov dptr, #test_msg
    lcall SendString
    mov a, b
    lcall putbyte
    mov a, #':'
    lcall putchar
    mov a, #' '
    lcall putchar
    
	mov R6, #0
	mov R7, #0
	mov a, b
    lcall EEPROM_BlockFill
    mov dptr, #0
next_byte:
    lcall EEPROM_Read
    clr c
    subb a, b
    jnz inc_error
    sjmp check_end
inc_error:
    mov R5, #1 ; Set error flag
    inc R6
    mov a, R6
    jnz check_end
    inc R7
check_end:
    inc dptr
    mov a, dph
    jnb acc.1, next_byte ; This checks if dptr is 0x0200
    
    mov a, R6
    orl a, R7
    jz all_ok
    
    mov a, #'0'
    lcall putchar
    mov a, #'x'
    lcall putchar
    mov dpl, R6
    mov dph, R7
    lcall putadd
    mov dptr, #error_msg
    lcall SendString
    cjne R6, #0x01, print_s
    cjne R7, #0x00, print_s
    ret
    
print_s:    
    mov a, #'s'
    lcall putchar
    ret
    
all_ok:
    mov dptr, #ok_msg
    lcall SendString
    ret

Warn_Msg: db '\r\n\r\nWARNING: MEMORY ERRORS DETECTED!\r\n', 0

test_memory:
    mov R5, #0 ; Error flag

	test_byte(0x00)
	test_byte(0x55)
	test_byte(0xaa)
	test_byte(0x0f)
	test_byte(0xf0)
	test_byte(0x5a)
	test_byte(0xa5)
	
	test_byte(0x01)
	test_byte(0x02)
	test_byte(0x04)
	test_byte(0x08)
	test_byte(0x10)
	test_byte(0x20)
	test_byte(0x40)
	test_byte(0x80)
	
	test_byte(not(0x01))
	test_byte(not(0x02))
	test_byte(not(0x04))
	test_byte(not(0x08))
	test_byte(not(0x10))
	test_byte(not(0x20))
	test_byte(not(0x40))
	test_byte(not(0x80))

  
    cjne R5, #0x01, test_memory_done
    mov dptr, #Warn_Msg
    lcall SendString
    
test_memory_done:
    lcall Send_nl
    lcall Send_nl
    ret

String_msg:  db '\r\nType string (Enter to finish): ', 0

Write_String:
    mov dptr, #Add_msg
    lcall SendString
    lcall getaddress
    push dpl
    push dph
    mov dptr, #String_msg
    lcall SendString
    pop dph
    pop dpl
    
Write_String_loop:
    lcall getchar
    mov b, a
    xrl a, #'\r'
    jz Write_String_done
    xrl a, #'\n'
    jz Write_String_done
    mov a, b
    lcall EEPROM_Write
    inc dptr
    sjmp Write_String_loop
    
Write_String_done:
    lcall Send_nl
    ret
             
menu:
    DB 'P89LPC9351 EEPROM test\r\n'
    DB '   1) Write byte\r\n'
    DB '   2) Display memory\r\n'
    DB '   3) Erase memory\r\n'
    DB '   4) Fill memory\r\n'
    DB '   5) Test memory\r\n'
    DB '   6) Write string\r\n'
    DB 'Option: '
    DB 0

Title: db 'EEPROM Test', 0
	
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
forever:
    mov dptr, #menu
    lcall SendString
    lcall getchar
    push acc
    lcall Send_nl
    pop acc
Option1:    
    cjne a, #'1', Option2
    lcall Write_Byte
    ljmp forever
Option2:    
    cjne a, #'2', Option3
    lcall Display_memory
    ljmp forever
Option3:    
    cjne a, #'3', Option4
    lcall Erase_memory
    ljmp forever
Option4:    
    cjne a, #'4', Option5
    lcall Fill_memory
    ljmp forever
Option5:    
    cjne a, #'5', Option6
    lcall Test_memory
    ljmp forever
Option6:    
    cjne a, #'6', done
    lcall Write_String

done:    
    ljmp forever

end

; LCD_ops.inc
; Date: 2020/02/04
; Author: Andrew Hanlon

; Display strings ==============================================================
;                           1234567890123456
set_soak_display1:      db 'Set Soak:       ', 0
set_reflow_display1:    db 'Set Reflow:     ', 0
set_display2:           db 'x:xx at xxx', 0xDF, 'C   ', 0 ; 0xDF is degree symbol code

display_mode_standby:   db 'Standby    xxx', 0xDF, 'C', 0
display_mode_ramp1:     db 'Ramp 1     xxx', 0xDF, 'C', 0
display_mode_soak:      db 'Soak       xxx', 0xDF, 'C', 0
display_mode_ramp2:     db 'Ramp 2     xxx', 0xDF, 'C', 0
display_mode_reflow:    db 'Reflow     xxx', 0xDF, 'C', 0
display_mode_cooldown:  db 'Cooldown   xxx', 0xDF, 'C', 0
display_mode_error:     db 'ERROR      xxx', 0xDF, 'C', 0

standby_display2:       db 'Start or Config ', 0
main_init_display2:     db 'x:xx, Total x:xx', 0
display_empty_line:     db '                ', 0

; Main Screen ==================================================================

Display_init_standby_screen:
    Set_Cursor(1,1)
    Send_Constant_String(#display_mode_standby) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#standby_display2)
    ret

; Display_init_main_screen(mode_string)
Display_init_main_screen MAC
    Set_Cursor(1,1)
    Send_Constant_String(#%0) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#main_init_display2)
ENDMAC

Display_clear_line2:
    Set_Cursor(2,1)
    Send_Constant_String(#display_empty_line)
    ret

; Display_update_temperature(temperature_var)
Display_update_temperature MAC
    ; display temperature
    Set_Cursor(1,12)
    mov a, %0
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)
ENDMAC

; Display_main_screen_temp()
Display_update_main_screen:
    Display_update_temperature(current_temp)
    ; display state time
    Set_Cursor(2,1)
    mov a, minutes_state
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar0)
    Set_Cursor(2,3)
    mov a, seconds_state
    lcall Hex_to_bcd_8bit
    Display_BCD(ar0)

    ; display total time
    Set_Cursor(2,13)
    mov a, minutes_total
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar0)
    Set_Cursor(2,15)
    mov a, seconds_total
    lcall Hex_to_bcd_8bit
    Display_BCD(ar0)
    ret

; Set Screen ===================================================================
Display_init_set_soak_screen MAC
    Set_Cursor(1,1)
    Send_Constant_String(#set_soak_display1)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
ENDMAC

Display_init_set_reflow_screen MAC
    Set_Cursor(1,1)
    Send_Constant_String(#set_reflow_display1)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
ENDMAC

; TODO: UPDATE FOR USE OF MINUTES
; Display_update_set_screen(time_seconds, time_minutes, temp)
Display_update_set_screen MAC
    Set_Cursor(2,1)
    mov a, %1
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar0)
    Set_Cursor(2,3)
    mov a, %0
    lcall Hex_to_bcd_8bit
    Display_BCD(ar0)

    Set_Cursor(2, 9)
    mov a, %2
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)
ENDMAC

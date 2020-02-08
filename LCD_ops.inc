; Display strings ==============================================================
;                           1234567890123456
set_soak_display1:      db 'Set Soak:       ', 0
set_reflow_display1:    db 'Set Reflow:     ', 0
set_display2:           db 'xxx s at xxx ', 0xDF, 'C ', 0 ; 0xDF is degree symbol code

display_mode_standby:   db 'Standby   xxx ', 0xDF, 'C', 0
display_mode_ramp1:     db 'Ramp 1    xxx ', 0xDF, 'C', 0
display_mode_soak:      db 'Soak      xxx ', 0xDF, 'C', 0
display_mode_ramp2:     db 'Ramp 2    xxx ', 0xDF, 'C', 0
display_mode_reflow:    db 'Reflow    xxx ', 0xDF, 'C', 0
display_mode_cooldown:  db 'Cooldown  xxx ', 0xDF, 'C', 0
display_mode_error:     db 'ERROR     xxx ', 0xDF, 'C', 0

; Main Screen ==================================================================
; Display_main_screen_mode(mode_string)
Display_init_main_screen MAC
    Set_Cursor(1,1)
    Send_Constant_String(#%0) ; Display the mode (and temp placeholder)
    Set_Cursor(2,1)
    Send_Constant_String(#set_display2)
ENDMAC

; Display_main_screen_temp(temperature_var, state_time_var, total_time_var)
Display_update_main_screen MAC
    ; display temperature
    Set_Cursor(1,11)
    mov a, %0
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)

    ; display state time
    Set_Cursor(2,1)
    mov a, %1
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)

    ; display total time
    Set_Cursor(2,10)
    mov a, %2
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)
ENDMAC

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

; Display_update_set_screen(time, temp)
Display_update_set_screen MAC
    Set_Cursor(2,1)
    mov a, %0
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)

    Set_Cursor(2, 10)
    mov a, %1
    lcall Hex_to_bcd_8bit
    ; BCD is stored in [r1, r0]
    Display_Lower_BCD(ar1)
    Display_BCD(ar0)
ENDMAC

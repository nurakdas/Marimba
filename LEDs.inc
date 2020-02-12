; LEDs.inc
; Author: Andrew Hanlon
; Date: 2020/02/12

; HOW TO USE:
; 1. include this file
; 2. "lcall Set_LEDs" at top of the main FSM loop (ie. with the calls to
;    Get_temp, Check_Buttons, etc.)
; 3. Edit the pin assignments below
; 4. Add the following line under "setb seconds_flag" in Timer1_ISR (timers.inc)
;    "setb LED_blink_flag"

; LED pin assignments
LED0 equ PX.X
LED1 equ PX.X
LED2 equ PX.X
LED3 equ PX.X

bseg
LED_blink_flag: dbit 1 ; Set by timer
LED_state_flag: dbit 1

cseg
Set_LEDs:
    mov a, FSM_state_decider
    mov b, #3
    mul ab
    mov dptr, #Jump_table
    jmp @A+dptr
Jump_table:
    ljmp LED_RESET ; This instruction uses 3 bytes
    ljmp LED_RAMP_TO_SOAK
    ljmp LED_SOAK
    ljmp LED_RAMP_TO_REFLOW
    ljmp LED_REFLOW
    ljmp LED_COOLDOWN
    ljmp LED_RESET
    ljmp LED_RESET
    ljmp LED_RESET
LED_RESET:
    ; All LED's off
    clr LED0
    clr LED1
    clr LED2
    clr LED3
    ret
LED_RAMP_TO_SOAK:
    ; LED0 blinking
    jnb LED_blink_flag, LED_RAMP_TO_SOAK_skip
    clr LED_blink_flag
    cpl LED0
LED_RAMP_TO_SOAK_skip:
    clr LED1
    clr LED2
    clr LED3
    ret
LED_SOAK:
    ; LED0 Steady, LED1 blinking
    setb LED0
    jnb LED_blink_flag, LED_SOAK_skip
    clr LED_blink_flag
    cpl LED1
LED_SOAK_skip:
    clr LED2
    clr LED3
    ret
LED_RAMP_TO_REFLOW:
    ; LED0 and LED1 steady, LED2 blinking
    setb LED0
    setb LED1
    jnb LED_blink_flag, LED_RAMP_TO_REFLOW_skip
    clr LED_blink_flag
    cpl LED2
LED_RAMP_TO_REFLOW_skip:
    clr LED3
    ret
LED_REFLOW:
    ; LED0, LED1, LED2 steady, LED3 blinking
    setb LED0
    setb LED1
    setb LED2
    jnb LED_blink_flag, LED_REFLOW_skip
    clr LED_blink_flag
    cpl LED3
LED_REFLOW_skip:
    ret
LED_COOLDOWN:
    ; LED0, LED1, LED2, LED3 (all 4) steady
    setb LED0
    setb LED1
    setb LED2
    setb LED3
    ret
LED_ERROR:
    ; all LED's blinking
    jnb LED_blink_flag, LED_ERROR_done
    clr LED_blink_flag
    jnb LED_state_flag, LED_ERROR_off
    setb LED0
    setb LED1
    setb LED2
    setb LED3
    cpl LED_state_flag
    ret
LED_ERROR_off:
    setb LED0
    setb LED1
    setb LED2
    setb LED3
    cpl LED_state_flag
LED_ERROR_done:
    ret

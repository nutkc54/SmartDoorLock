LIST P=16F877A
        #include <P16F877A.INC>

        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _LVP_OFF

;=====================
; RAM Definition
;=====================
CBLOCK 0x20
COUNT1, COUNT2, COUNT3      ; สำหรับ Delay
KEY                         ; เก็บปุ่มที่กดล่าสุด
WRONG_COUNT                 ; นับจำนวนครั้งที่กดผิด
DIG1, DIG2, DIG3, DIG4      ; เก็บตัวเลข 4 หลักที่กดเข้ามา
ENDC

; กำหนดขาอุปกรณ์
#define LED_RED     PORTC,2
#define LED_GREEN   PORTC,3
#define BUZZER      PORTC,4

        ORG 0x00
        GOTO START

;=====================
; INITIALIZE
;=====================
START
        BSF     STATUS,RP0  ; Bank 1
        MOVLW   B'11110000' ; RB4-7=In, RB0-3=Out
        MOVWF   TRISB
        CLRF    TRISD       ; LCD Data
        CLRF    TRISC       ; LEDs & Buzzer & LCD Control
        BCF     OPTION_REG,7 ; Enable Pull-ups
        BCF     STATUS,RP0  ; Bank 0

        CLRF    PORTC
        CLRF    WRONG_COUNT
        CALL    LCD_INIT
        
LOCK_SYSTEM
        BSF     LED_RED     ; สถานะล็อค: ไฟแดงติด
        BCF     LED_GREEN   ; ไฟเขียวดับ
        CALL    LCD_CLEAR
        MOVLW   'L'
        CALL    LCD_DATA
        MOVLW   'O'
        CALL    LCD_DATA
        MOVLW   'C'
        CALL    LCD_DATA
        MOVLW   'K'
        CALL    LCD_DATA

;=====================
; GET PASSCODE (4 DIGITS)
;=====================
GET_PASS
        CALL    WAIT_KEY    ; รอหลักที่ 1
        MOVWF   DIG1
        CALL    WAIT_KEY    ; รอหลักที่ 2
        MOVWF   DIG2
        CALL    WAIT_KEY    ; รอหลักที่ 3
        MOVWF   DIG3
        CALL    WAIT_KEY    ; รอหลักที่ 4
        MOVWF   DIG4

        ; เริ่มเช็ครหัส 8888
        MOVF    DIG1,W
        XORLW   '8'
        BTFSS   STATUS,Z
        GOTO    WRONG_PASS

        MOVF    DIG2,W
        XORLW   '8'
        BTFSS   STATUS,Z
        GOTO    WRONG_PASS

        MOVF    DIG3,W
        XORLW   '8'
        BTFSS   STATUS,Z
        GOTO    WRONG_PASS

        MOVF    DIG4,W
        XORLW   '8'
        BTFSS   STATUS,Z
        GOTO    WRONG_PASS

;=====================
; SUCCESS / FAIL
;=====================
RIGHT_PASS
        CLRF    WRONG_COUNT
        BCF     LED_RED
        BSF     LED_GREEN   ; ปลดล็อค: ไฟเขียวติด
        CALL    LCD_CLEAR
        MOVLW   'O'
        CALL    LCD_DATA
        MOVLW   'P'
        CALL    LCD_DATA
        MOVLW   'E'
        CALL    LCD_DATA
        MOVLW   'N'
        CALL    LCD_DATA
        CALL    DELAY_5S    ; เปิดค้างไว้ 5 วินาที
        GOTO    LOCK_SYSTEM

WRONG_PASS
        INCF    WRONG_COUNT,F
        CALL    LCD_CLEAR
        MOVLW   'E'
        CALL    LCD_DATA
        MOVLW   'R'
        CALL    LCD_DATA
        MOVLW   'R'
        CALL    LCD_DATA
        
        MOVLW   D'3'
        SUBWF   WRONG_COUNT,W
        BTFSC   STATUS,Z    ; ถ้าผิดครบ 3 รอบ
        GOTO    ALARM
        
        CALL    DELAY_MS
        GOTO    LOCK_SYSTEM

ALARM
        BSF     BUZZER      ; เสียงเตือนดัง 5 วินาที
        CALL    DELAY_5S
        BCF     BUZZER
        CLRF    WRONG_COUNT
        GOTO    LOCK_SYSTEM

;=====================
; LCD & KEYPAD FUNCTIONS
;=====================
WAIT_KEY
        CALL    KEYPAD_SCAN
        MOVWF   KEY
        MOVF    KEY,W
        BTFSC   STATUS,Z
        GOTO    WAIT_KEY    ; วนรอจนกว่าจะกดปุ่ม
        MOVLW   '*'         ; แสดง * แทนตัวเลขจริง
        CALL    LCD_DATA
RELEASE_KEY                 ; รอจนกว่าจะปล่อยปุ่ม
        MOVLW   B'00000000'
        MOVWF   PORTB
        MOVF    PORTB,W
        ANDLW   B'11110000'
        XORLW   B'11110000'
        BTFSS   STATUS,Z
        GOTO    RELEASE_KEY
        MOVF    KEY,W       ; คืนค่า ASCII ที่กดจริงกลับไป
        RETURN

KEYPAD_SCAN
        MOVLW B'11111110'   ; แถว 1
        MOVWF PORTB
        BTFSS PORTB,4
        RETLW '1'
        BTFSS PORTB,5
        RETLW '2'
        BTFSS PORTB,6
        RETLW '3'
        BTFSS PORTB,7
        RETLW 'A'
        MOVLW B'11111101'   ; แถว 2
        MOVWF PORTB
        BTFSS PORTB,4
        RETLW '4'
        BTFSS PORTB,5
        RETLW '5'
        BTFSS PORTB,6
        RETLW '6'
        BTFSS PORTB,7
        RETLW 'B'
        MOVLW B'11111011'   ; แถว 3
        MOVWF PORTB
        BTFSS PORTB,4
        RETLW '7'
        BTFSS PORTB,5
        RETLW '8'
        BTFSS PORTB,6
        RETLW '9'
        BTFSS PORTB,7
        RETLW 'C'
        MOVLW B'11110111'   ; แถว 4
        MOVWF PORTB
        BTFSS PORTB,4
        RETLW '*'
        BTFSS PORTB,5
        RETLW '0'
        BTFSS PORTB,6
        RETLW '#'
        BTFSS PORTB,7
        RETLW 'D'
        RETLW 0x00

LCD_INIT
        MOVLW 0x38          ; 8-bit mode
        CALL LCD_CMD
        MOVLW 0x0C          ; Display ON
        CALL LCD_CMD
        MOVLW 0x01          ; Clear Screen
        CALL LCD_CMD
        RETURN

LCD_CMD
        MOVWF PORTD
        BCF PORTC,0         ; RS=0
        BSF PORTC,1         ; EN=1
        NOP
        BCF PORTC,1         ; EN=0
        CALL DELAY_MS
        RETURN

LCD_DATA
        MOVWF PORTD
        BSF PORTC,0         ; RS=1
        BSF PORTC,1         ; EN=1
        NOP
        BCF PORTC,1         ; EN=0
        CALL DELAY_MS
        RETURN

LCD_CLEAR
        MOVLW 0x01
        CALL LCD_CMD
        RETURN

;=====================
; DELAY FUNCTIONS
;=====================
DELAY_5S
        MOVLW D'50'
        MOVWF COUNT3
L3      CALL DELAY_MS
        DECFSZ COUNT3,F
        GOTO L3
        RETURN

DELAY_MS
        MOVLW D'100'
        MOVWF COUNT2
D2      MOVLW D'255'
        MOVWF COUNT1
D1      DECFSZ COUNT1,F
        GOTO D1
        DECFSZ COUNT2,F
        GOTO D2
        RETURN

        END
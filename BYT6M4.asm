;******Program: BYT_6_M_4_Releese_05_05_2011 **********************************
; Обработка 20-клавишной сенсорной клавиатуры, обработка АЦП,
; обработка результата, вывод данных на ЖКИ, сохранение в EEPROM
; обработка зависания АЦП.
.include "m8515def.inc"
.device ATMega8515

;----- Регистры общего назначения -----
.def KEYBOARD_1 = r27	; Регистр данных для первых 8 клавиш
.def KEYBOARD_2 = r28	; Регистр данных для 9 и 10 клавиши
.def T0 = r3		; Большая пауза
.def T1 = r4
.def T2 = r5
.def I2C_DATA = r6	; Отправка данных по I2C

.def STATUS = r16
; 7 бит: если 1, то температура отрицательна, если 0, то положительна
.equ F_PLUS = 7
; 6 бит: если 1, то в результате температуры есть сотни, если 0, то сотен нет
.equ F_STO = 6
; 5 бит: если 1, то в результате температуры есть десятки, если 0, то десятков нет
.equ F_DEC = 5
; 4 бит: если 1, то нагреватели можно включать
.equ F_HEATER_ON = 4
; 3 бит: если 1, то нагреватели нельзя включать
.equ F_HEATER_OFF = 3
; 2 бит: если 1, то картинка обновилась, если 0, то дисплей не трогаем
.equ F_DIS_REL = 2
; 1 бит: если 1, то был импульс 10мс и можно начать отсчёт, если 0, импульса 10мс пока не было
.equ F_10MS = 1

.def STATUS_2 = r19
; 2 бит: если 1, то пришло время сбросить АЦП, если 0, то АЦП сброшен недавно
.equ F_WANT_ADC_RESET = 1

.def BUFFER = r17
.def C = r18

.def fbinL = r20            ;двоичное значение, младший байт
.def fbinH = r21            ;двоичное значение, старший байт
.def tBCD0 = r21            ;BCD значение, цифры 1 и 0
.def tBCD1 = r22            ;BCD значение, цифры 3 и 2
.def tBCD2 = r23            ;BCD значение, цифра 4
.def SPI_DATA = r24	; Отправка данных по SPI
.def A = r25		; Арифметические реистры
.def B = r26
.def SAVESREG = r1

; ----- Физические адреса подключения AD7788 -----
.equ MOSI = PB1
.equ MISO = PB2
.equ SCK = PB3
.equ CS = PB0

; ----- Формат посылки TIC32 I2C -----
.equ Slave_address = 0b01111010	; Адрес TIC32
.equ Co = 7	; Бит количества посылок
.equ RS = 6	; Бит записи данных в ВИДЕО-ОЗУ TIC32
; Для маски использовать команду exp2(RS)

; ----- Контраст дисплея -----
.equ LCD_Contrast = 8

; ----- Смещения оси X для отображения чисел на индикаторе -----
.equ shag = 19
.equ X_1 = 0
.equ X_2 = X_1 + shag
.equ X_3 = X_2 + shag
.equ X_4 = X_3 + shag
.equ X_5 = X_4 + shag
.equ X_6 = X_5 + shag
.equ X_7 = X_6 + shag

.equ Symbol_Rezolution_X = 12 ; Размер символа кодовой таблицы по оси X

; ----- Физические адреса подключения TIC32 -----
.equ SDA = PD0
.equ SCL = PD1
.equ RES = PD2

; ----- Физические адреса подключения Quantum -----
.equ Q_1W_1 = PC1
.equ Q_1W_2 = PC4
.equ CHANGE_1 = PC2
.equ CHANGE_2 = PC3
.equ RST_1 = PC0
.equ RST_2 = PC5

; ======================================================================================
; ===== Раздел памяти программ =========================================================
; ======================================================================================
.cseg

; ***** Векторы прерываний  

.org 0x000
		rjmp OnRESET ; По сбросу
;.org 0x001
;		rjmp OnINT0 ; По внешнему прерыванию INT0
;.org 0x002
		;rjmp OnINT1 ; По внешнему прерыванию INT1
;.org 0x003
;		rjmp OnTC1capt ; По захвату TC1
.org 0x004
		rjmp OnTC1compA ; По сравнению A ТС1 
;.org 0x005
;		rjmp OnTC1compB ; По сравнению B ТС1 
.org 0x006
		rjmp OnTC1ovf ; По переполнению ТС1 
;.org 0x007
;		rjmp OnTC0ovf ; По переполнению ТС0 
;.org 0x008
;		rjmp OnSPItxc ; По завершению передачи SPI 
;.org 0x009
;		rjmp OnUSARTrxc	; По завершению приёма USART
;.org 0x00A
;		rjmp OnUSARTudre ; По очищению UDR USART
;.org 0x00B
;		rjmp OnUSARTtxc	; По завершению передачи USART
;.org 0x00C
;		rjmp OnANAcomp ; По сигналу компаратора
;.org 0x00D
;		rjmp OnINT2 ; По внешнему прерыванию INT2
;.org 0x00E
;		rjmp OnTC0comp ; По сравнению TC0
;.org 0x00F
;		rjmp OnEErdy ; По готовности EEPROM
;.org 0x010
;		rjmp OnSPMrdy ; По готовности памяти программ
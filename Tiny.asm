.include "tn2313def.inc"
.device ATtiny2313

;----- Регистры общего назначения -----
.def SAVESREG = r1
.def T0 = r3			; Большая пауза
.def T1 = r4
.def T2 = r5

.def STATUS = r16
; 7 бит: если 1, мега готова передать код мощности, если 0, мощность не передаётся
.equ F_RECIVE = 7
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

.def BUFFER = r17
.def C = r18
.def A = r19		; Арифметические реистры
.def B = r20
.def SPI_DATA = r21	; Отправка данных по SPI

; ----- Физические адреса подключения оптотиристоров и входа прерывания -----
.equ PI_Z1 = PB0
.equ PI_Z2 = PB1
.equ PI_Z3 = PB2
.equ PI_Z4 = PB3
.equ PI_Z5 = PB4
.equ PI_Z6 = PB5


; ----- Физические адреса подключения Mega -----
.equ M_D0 = PD1
.equ M_D1 = PD4
.equ M_D2 = PD5
.equ M_D3 = PD6
.equ M_INT = PD3
.equ M_TN_OUT = PD0
.equ INT_10 = PD2


; ----- Максимальное и минимальное значение температуры -----
.equ Power_Max = 95
.equ Power_Min = 10

; ----- Адреса ОЗУ -----
.equ RAM_Start = 0x60

;- 1 зона
.equ Zone_1_input = 0x61
;- 2 зона
.equ Zone_2_input = 0x62
;- 3 зона
.equ Zone_3_input = 0x63
;- 4 зона
.equ Zone_4_input = 0x64
;- 5 зона
.equ Zone_5_input = 0x65
;- 6 зона
.equ Zone_6_input = 0x66

.equ Delay_5_us = 0x67
.equ Zone_Adress = 0xC0
.equ Zone_Power = 0xC1

; ----- Карта фазо-ипульсного управления -----
.equ Predel_95_Proc = 0x68
.equ Predel_10_Proc = 0xBF


;***** Вектора прерываний *****
.org 0x000
			rjmp RESET ; Reset Handler
			rjmp ON_INT0 ; External Interrupt0 Handler
			rjmp ON_INT1 ; External Interrupt1 Handler
;0x0003 rjmp TIM1_CAPT ; Timer1 Capture Handler
.org 0x0004 
			rjmp OnTC1compA ; Timer1 CompareA Handler
;0x0005 rjmp TIM1_OVF ; Timer1 Overflow Handler
;0x0006 rjmp TIM0_OVF ; Timer0 Overflow Handler
;0x0007 rjmp USART0_RXC ; USART0 RX Complete Handler
;0x0008 rjmp USART0_DRE ; USART0,UDR Empty Handler
;0x0009 rjmp USART0_TXC ; USART0 TX Complete Handler
;0x000A rjmp ANA_COMP ; Analog Comparator Handler
;0x000B rjmp PCINT ; Pin Change Interrupt
;0x000C rjmp TIMER1_COMPB ; Timer1 Compare B Handler
;0x000D rjmp TIMER0_COMPA ; Timer0 Compare A Handler
;0x000E rjmp TIMER0_COMPB ; Timer0 Compare B Handler
;0x000F rjmp USI_START ; USI Start Handler
;0x0010 rjmp USI_OVERFLOW ; USI Overflow Handler
;0x0011 rjmp EE_READY ; EEPROM Ready Handler
;0x0012 rjmp WDT_OVERFLOW ; Watchdog Overflow Handler

;***** Начальные настройки *****

RESET:		ldi BUFFER, low(ramend) 	; Настройка стека
			out SPL, BUFFER				
		
; --------------- Настройка INT_0 и INT_1 -----
			ldi BUFFER, (1<<ISC01)+(1<<ISC00)+(1<<ISC11)+(1<<ISC10) ; Обработка по нарастающему фронту 
			out MCUCR, BUFFER
	
			ldi BUFFER, (1<<INT0)+(1<<INT1)	; Разрешение прерывания INT0 (PD2)
			out GIMSK, BUFFER
				
			ldi BUFFER, (1<<INTF0)+(1<<INTF1)	; Убираем глюки прерывания
			out EIFR, BUFFER	
			
				
; --------------- Настройка портов В/В -----			
; PORTD: 
; 		-Mega8515:
;				M_SCK = PD0 (Вход\Выход)
;				M_DATA = PD1 (Вход)
;				M_SYNC = PD3 (Вход\Выход)
;				M_HEAT = PD4 (Вход)
;
;				INT_10 = PD2 (вход\прерывание)
;
; PORTB:		
;		-Phase_impulse	
;				PI_Z1 = PB0 (выход)
;				PI_Z2 = PB1 (выход)
;				PI_Z3 = PB2 (выход)
;				PI_Z4 = PB3 (выход)
;				PI_Z5 = PB4 (выход)
;				PI_Z6 = PB5 (выход)
;				PI_Z7 = PB6 (выход)
;				PI_Z8 = PB7 (выход)
			
			ldi BUFFER, (0<<INT_10)+(1<<M_TN_OUT)+(0<<M_INT)+(0<<M_D3)+(0<<M_D2)+(0<<M_D1)+(0<<M_D0)
			out DDRD, BUFFER
			sbi PORTD,	M_TN_OUT	; Сообщаем, что тайни занята
			
					
			ser BUFFER
			out DDRB, BUFFER
			clr BUFFER
			out PORTB, BUFFER	
						
; ----- Установка начальных значений -----
			clr BUFFER			
			ldi ZH, high(RAM_Start)
			ldi ZL, low(RAM_Start)
SRAM_Erase_Cycle:
			st Z+, BUFFER
			cpi ZH, high(Predel_95_Proc)
			brne SRAM_Erase_Cycle
			cpi ZL, low(Predel_95_Proc)
			brne SRAM_Erase_Cycle
			
			clr SAVESREG
			clr STATUS
			clr BUFFER
			clr B

			ldi BUFFER, 10				; Значение мощности
			sts Zone_1_input, BUFFER
			
			ldi BUFFER, 10				; Значение мощности
			sts Zone_2_input, BUFFER
			
			ldi BUFFER, 10				; Значение мощности
			sts Zone_3_input, BUFFER
			
			ldi BUFFER, 10				; Значение мощности
			sts Zone_4_input, BUFFER
			
			ldi BUFFER, 10				; Значение мощности
			sts Zone_5_input, BUFFER
			
			ldi BUFFER, 10				; Значение мощности
			sts Zone_6_input, BUFFER
			
			cbr STATUS, exp2(F_HEATER_ON)		; Сообщаем, что нагреватели нужно отключить

			sei						; Разрешаем все прерывания


; ********* Скелет основной программы *********
Main:			;ldi BUFFER, 2
			;mov A, BUFFER
			;rcall Pause
			nop
			rjmp Main


Pause:		nop
Time_2:		ser B
Time_1:		ser C
Edit:			dec  C
			brne Edit
			dec B
			brne Time_1
			dec A
			brne Time_2
			
			lds BUFFER, Zone_1_input
			inc BUFFER
			sts Zone_1_input, BUFFER
			cpi BUFFER, 95
			brne Pause_Exit
			ldi BUFFER, 10
			sts Zone_1_input, BUFFER	
Pause_Exit:		
			ret




; ----- Приём данных от Меги -----
ON_INT1:		push BUFFER
			push A
			cbi PORTD, M_TN_OUT	; \____
			
			in A, PIND			; Приняли старший полубайт
			clr BUFFER			
			bst A, M_D0
			bld BUFFER, PB4
			bst A, M_D1
			bld BUFFER, PB5
			bst A, M_D2
			bld BUFFER, PB6
			bst A, M_D3
			bld BUFFER, PB7
			
			sbi PORTD, M_TN_OUT	; _/
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли младший полубайт
			bst A, M_D0
			bld BUFFER, PB0
			bst A, M_D1
			bld BUFFER, PB1
			bst A, M_D2
			bld BUFFER, PB2
			bst A, M_D3
			bld BUFFER, PB3
			
			sbi PORTD, M_TN_OUT	; _/
			
			cpi BUFFER, 10
			brlo ON_INT1_H_OFF
			rjmp ON_INT1_H_ON

ON_INT1_H_OFF:	cbr STATUS, exp2(F_HEATER_ON)
			rjmp ON_INT1_Out
			
			
ON_INT1_H_ON:	sbr STATUS, exp2(F_HEATER_ON)
			sts Zone_1_input, BUFFER
			
			
			
;------------------------------------------------------------------------------			
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли старший полубайт
			clr BUFFER			
			bst A, M_D0
			bld BUFFER, PB4
			bst A, M_D1
			bld BUFFER, PB5
			bst A, M_D2
			bld BUFFER, PB6
			bst A, M_D3
			bld BUFFER, PB7
			
			sbi PORTD, M_TN_OUT	; _/
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли младший полубайт
			bst A, M_D0
			bld BUFFER, PB0
			bst A, M_D1
			bld BUFFER, PB1
			bst A, M_D2
			bld BUFFER, PB2
			bst A, M_D3
			bld BUFFER, PB3
			sbi PORTD, M_TN_OUT	; _/
			sts Zone_2_input, BUFFER

;------------------------------------------------------------------------------			
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли старший полубайт
			clr BUFFER			
			bst A, M_D0
			bld BUFFER, PB4
			bst A, M_D1
			bld BUFFER, PB5
			bst A, M_D2
			bld BUFFER, PB6
			bst A, M_D3
			bld BUFFER, PB7
			
			sbi PORTD, M_TN_OUT	; _/
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли младший полубайт
			bst A, M_D0
			bld BUFFER, PB0
			bst A, M_D1
			bld BUFFER, PB1
			bst A, M_D2
			bld BUFFER, PB2
			bst A, M_D3
			bld BUFFER, PB3
			sbi PORTD, M_TN_OUT	; _/
			sts Zone_3_input, BUFFER

;------------------------------------------------------------------------------			
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли старший полубайт
			clr BUFFER			
			bst A, M_D0
			bld BUFFER, PB4
			bst A, M_D1
			bld BUFFER, PB5
			bst A, M_D2
			bld BUFFER, PB6
			bst A, M_D3
			bld BUFFER, PB7
			
			sbi PORTD, M_TN_OUT	; _/
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли младший полубайт
			bst A, M_D0
			bld BUFFER, PB0
			bst A, M_D1
			bld BUFFER, PB1
			bst A, M_D2
			bld BUFFER, PB2
			bst A, M_D3
			bld BUFFER, PB3
			sbi PORTD, M_TN_OUT	; _/
			sts Zone_4_input, BUFFER

;------------------------------------------------------------------------------			
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли старший полубайт
			clr BUFFER			
			bst A, M_D0
			bld BUFFER, PB4
			bst A, M_D1
			bld BUFFER, PB5
			bst A, M_D2
			bld BUFFER, PB6
			bst A, M_D3
			bld BUFFER, PB7
			
			sbi PORTD, M_TN_OUT	; _/
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли младший полубайт
			bst A, M_D0
			bld BUFFER, PB0
			bst A, M_D1
			bld BUFFER, PB1
			bst A, M_D2
			bld BUFFER, PB2
			bst A, M_D3
			bld BUFFER, PB3
			sbi PORTD, M_TN_OUT	; _/
			sts Zone_5_input, BUFFER

;------------------------------------------------------------------------------			
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли старший полубайт
			clr BUFFER			
			bst A, M_D0
			bld BUFFER, PB4
			bst A, M_D1
			bld BUFFER, PB5
			bst A, M_D2
			bld BUFFER, PB6
			bst A, M_D3
			bld BUFFER, PB7
			
			sbi PORTD, M_TN_OUT	; _/
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT	; \____

			in A, PIND			; Приняли младший полубайт
			bst A, M_D0
			bld BUFFER, PB0
			bst A, M_D1
			bld BUFFER, PB1
			bst A, M_D2
			bld BUFFER, PB2
			bst A, M_D3
			bld BUFFER, PB3
			sbi PORTD, M_TN_OUT	; _/
			sts Zone_6_input, BUFFER

ON_INT1_Out:	pop A
			pop BUFFER
			reti







			
SPI_Delay:		rcall SPI_Delay_1
			rcall SPI_Delay_1
			rcall SPI_Delay_1
			rcall SPI_Delay_1
			ret

SPI_Delay_1:	nop
			nop
			nop
			ret











;----------------------------------------------------------------------------------------
FIU_Page_Load:
			clr BUFFER					; Очистили страницу мощности
			ldi ZH, high(Predel_95_Proc)
			ldi ZL, low(Predel_95_Proc)
SRAM_Erase_Cycle_1:
			st Z+, BUFFER
			cpi ZH, high(Predel_10_Proc)
			brne SRAM_Erase_Cycle_1
			cpi ZL, low(Predel_10_Proc)
			brne SRAM_Erase_Cycle_1
												
			lds BUFFER, Zone_1_Input
			ldi C, 95
			sub C, BUFFER				; смещение по таблице
			ldi BUFFER, Predel_95_Proc 		; смещение до таблицы
			add C, BUFFER				; Получили адрес мощности в таблице
			clr XH	
			mov XL, C					; Задали адрес мощности
			ld BUFFER, X
			sbr BUFFER, exp2(PI_Z1)
			st X+, BUFFER
			lds BUFFER, Zone_2_Input
			ldi C, 95
			sub C, BUFFER				; смещение по таблице
			ldi BUFFER, Predel_95_Proc 		; смещение до таблицы
			add C, BUFFER				; Получили адрес мощности в таблице
			clr XH	
			mov XL, C					;  Задали адрес мощности
			ld BUFFER, X
			sbr BUFFER, exp2(PI_Z2)
			st X+, BUFFER
			lds BUFFER, Zone_3_Input
			ldi C, 95
			sub C, BUFFER				; смещение по таблице
			ldi BUFFER, Predel_95_Proc		; смещение до таблицы
			add C, BUFFER				; Получили адрес мощности в таблице
			clr XH
			mov XL, C					;  Задали адрес мощности
			ld BUFFER, X
			sbr BUFFER, exp2(PI_Z3)
			st X+, BUFFER
			lds BUFFER, Zone_4_Input
			ldi C, 95
			sub C, BUFFER				; смещение по таблице
			ldi BUFFER, Predel_95_Proc 		; смещение до таблицы
			add C, BUFFER				; Получили адрес мощности в таблице
			clr XH
			mov XL, C					;  Задали адрес мощности
			ld BUFFER, X
			sbr BUFFER, exp2(PI_Z4)
			st X+, BUFFER
			lds BUFFER, Zone_5_Input
			ldi C, 95
			sub C, BUFFER				; смещение по таблице
			ldi BUFFER, Predel_95_Proc 		; смещение до таблицы
			add C, BUFFER				; Получили адрес мощности в таблице
			clr XH
			mov XL, C					;  Задали адрес мощности
			ld BUFFER, X
			sbr BUFFER, exp2(PI_Z5)
			st X+, BUFFER
			lds BUFFER, Zone_6_Input
			ldi C, 95
			sub C, BUFFER				; смещение по таблице
			ldi BUFFER, Predel_95_Proc 		; смещение до таблицы
			add C, BUFFER				; Получили адрес мощности в таблице
			clr XH		
			mov XL, C					;  Задали адрес мощности
			ld BUFFER, X
			sbr BUFFER, exp2(PI_Z6)
			st X+, BUFFER
			ret


; ----- Обработка прерывания 100us -----
OnTC1compA:		cbi PORTD, M_TN_OUT	; Сообщаем, что tiny занята
			push BUFFER
			sbrs STATUS, F_10MS		; Если не было старта, то нагреватели не трогаем
			rjmp OnTC1compA_Exit
						
			;lds BUFFER, Delay_5_us
			;inc BUFFER
			;sts Delay_5_us, BUFFER
			;cpi BUFFER, 2
			;brlo OnTC1compA_Exit
	
			ld BUFFER, X+			; читаем текущее значение и выкидываем его в порт
			sbrc STATUS, F_HEATER_ON
			out PORTB, BUFFER

				
			cpi XL, Predel_10_Proc		; Всё ли включили?
			brne OnTC1compA_Exit
			
			cbr STATUS, exp2(F_10MS)	; Сообщаем, что 9,5 мс прошло
			ldi BUFFER, (0<<OCIE1A)		; Отключаем таймер_1
			out TIMSK, BUFFER

			clr BUFFER				; Отключаем все тиристоры
			out PORTB, BUFFER
			
			cbi DDRD, INT_10			; Включаем ожидание следущего импульса
			clr XH				; Встаём в начало таблицы мощности
			ldi XL, Predel_95_Proc
			
			sbi PORTD, M_TN_OUT
			rcall SPI_Delay
			cbi PORTD, M_TN_OUT			

OnTC1compA_Exit:	
			;sbi PORTD, M_TN_OUT
			pop BUFFER
			reti


; ----- Обработка прерывания от входа 10 ms -----
ON_INT0:		cbi PORTD, M_TN_OUT	; Сообщаем, что tiny занята
			push BUFFER
			
			cli
			rcall Reset_Timer_1
			
			rcall FIU_Page_Load		; Задаём новые значения мощности			

			clr XH				; Встаём в начало таблицы мощности
			ldi XL, Predel_95_Proc
						
			sbi DDRD, INT_10			; Получили импульс, устанавливаем низкий уровень
			cbi PORTD, INT_10			; нужно настроить 10мс на вход через 9,7мс
			
			clr BUFFER				; Отключаем все тиристоры
			out PORTB, BUFFER
			sts Delay_5_us, BUFFER
			
			sbr STATUS, exp2(F_10MS)	; Сообщаем, что был импульс 10мс
		
OnINT2_Exit:	pop BUFFER
			sei
			;sbi PORTD, M_TN_OUT		
			reti

; ----- Сброс и запуск 0,1мс 9.7мс -----
Reset_Timer_1:	ldi BUFFER,	0x01			; Сброс и прерывание при достижении 461 (0.1мс)
			out OCR1AH, BUFFER		; (0x01CD)
			ldi BUFFER, 0xCD
			out OCR1AL, BUFFER

			clr BUFFER
			out TCNT1H, BUFFER
			out TCNT1L, BUFFER
				
			ldi BUFFER, (0<<COM1A1)+(0<<COM1A0)+(0<<COM1B1)+(0<<COM1B0)+(0<<WGM11)+(0<<WGM10)
			out TCCR1A, BUFFER
			
			ldi BUFFER, (0<<WGM13)+(1<<WGM12)+(0<<CS12)+(0<<CS11)+(1<<CS10)+(0<<ICNC1)+(0<<ICES1)
			out TCCR1B, BUFFER
		
			ldi BUFFER, (1<<OCIE1A)		; Прерывание по переполнению от  таймера_0 и по совпадению T1A
			out TIMSK, BUFFER
			
			ser BUFFER
			out TIFR, BUFFER

			ret




















.exit

	PROCESSOR 16F84A
	INCLUDE <P16F84A.INC>
	__config  _HS_OSC & _WDT_OFF & _PWRTE_ON

BUFF1 	EQU 0EH
BUFF2	EQU 0FH
BUFF3	EQU 10H
FLAG	EQU 11H
COUNT	EQU 12H

	ORG 0
	GOTO INIT		;goto initialization routine

	ORG 4
	GOTO ISR		;interrupt routine

INIT
	;########## reg init
	CLRF BUFF1
	CLRF BUFF2
	CLRF BUFF3

	MOVLW .8
	MOVWF COUNT

	MOVLW B'00000111'
	MOVWF FLAG			;reciv 3 bytes
	;########## end of reg init

	MOVLW B'10010000'	;enable RB0/INT interrupt
	MOVWF INTCON

	BCF STATUS,RP0		;select BANK1
	CLRF PORTB

	BSF STATUS,RP0
	MOVLW B'10000011'
	MOVWF TRISB
	MOVLW B'00011'
	MOVWF TRISA

	MOVLW B'11111111'	;PGT on RB0/INT
	MOVWF OPTION_REG
	BCF STATUS,RP0		;select BANK0

	CLRF PORTB
	CLRF PORTA

	BCF PORTB,6			;COIL OFF
	BSF PORTB,2			;ready to reciv data
MAIN
	NOP
	GOTO MAIN

;################################
;################################
ISR
	;MOVLW 2
	;ADDWF PORTB,1

	;CHECK WHERE TO PUT DATA, RECIV OR WHAT TO DO
	BTFSC FLAG,7
	GOTO AFTER_REPORT	;PIECE REPORT

	BTFSC FLAG,4
	GOTO SEND_BYTE1
	BTFSC FLAG,5
	GOTO SEND_BYTE2

	BTFSC FLAG,0
	GOTO GET_BYTE1
	BTFSC FLAG,1
	GOTO GET_BYTE2
	GOTO GET_BYTE3
;###############################



;###############################
SEND_BYTE1
	BTFSC BUFF1,7		;TEST MSB OF BUFF1
	BSF PORTB,2			;SET DATA OUT
	BTFSS BUFF1,7		;
	BCF PORTB,2			;CLR DATA OUT
	RLF BUFF1

	DECFSZ COUNT
	GOTO ISR_END
	MOVLW .9			;1 CLK FOR FINAL RECEPTION
	MOVWF COUNT
	BCF FLAG,4	
	GOTO ISR_END
;###############################




;###############################
SEND_BYTE2
	BTFSC BUFF2,7		;TEST MSB OF BUFF1
	BSF PORTB,2			;SET DATA OUT
	BTFSS BUFF2,7		;
	BCF PORTB,2			;CLR DATA OUT
	RLF BUFF2

	DECFSZ COUNT
	GOTO ISR_END
	MOVLW .8
	MOVWF COUNT
	BCF FLAG,5
	BSF PORTB,2			;READY TO RECIV AGAIN	
	GOTO ISR_END
;###############################




;###############################
;FIRST BYTE OF DATA TO BE RECIV
GET_BYTE1
	RLF BUFF1			
	BTFSC PORTB,1		;input data from RB1 of PORTB to BUFF1
	BSF BUFF1,0			
	BTFSS PORTB,1		
	BCF BUFF1,0	
	
	DECFSZ COUNT
	GOTO ISR_END
	MOVLW .8
	MOVWF COUNT
	BCF FLAG,0
	GOTO ISR_END

;SECOND BYTE OF DATA 
GET_BYTE2
	RLF BUFF2			
	BTFSC PORTB,1		;input data from RB1 of PORTB to BUFF2
	BSF BUFF2,0			
	BTFSS PORTB,1		
	BCF BUFF2,0		

	DECFSZ COUNT
	GOTO ISR_END
	MOVLW .8
	MOVWF COUNT
	BCF FLAG,1
	GOTO ISR_END

;THIRD BYTE OF DATA
GET_BYTE3
	RLF BUFF3			
	BTFSC PORTB,1		;input data from RB1 of PORTB to BUFF3
	BSF BUFF3,0			
	BTFSS PORTB,1		
	BCF BUFF3,0		

	DECFSZ COUNT
	GOTO ISR_END

;///end of recieving 3 bytes of data
	BCF PORTB,2			;set PIC to busy
	MOVLW .8
	MOVWF COUNT
	MOVLW B'00000111'	;RE-INIT FLAG
	MOVWF FLAG

	BTFSC BUFF3,1		;SET DIRECTION
	BSF PORTB,5			;HOME DIR
	BTFSS BUFF3,1
	BCF PORTB,5			;AWAY DIR

	BTFSC BUFF3,4		
	GOTO SET_ONLY		;without stepping

	BTFSC BUFF2,7
	GOTO REPORT_PIECE	;REPORT IS PIECE IS PRESENT

	BTFSC BUFF3,2		;TEST STOP AT HOME
	GOTO HOME		;stop at home sensor?

	BTFSC BUFF3,3		;TEST STOP AT LDR
	GOTO STEP_LDR
	GOTO START_STEP		;NUMBERED STEPS
;###############################




;###############################
SET_ONLY
	BTFSS BUFF3,5
	BCF PORTB,6			;TURN OFF COIL
	BTFSC BUFF3,5
	BSF PORTB,6			;TURN ON COIL

	BTFSS BUFF3,6
	BCF PORTA,2			;TURN OFF LASER
	BTFSC BUFF3,6
	BSF PORTA,2

	BTFSS BUFF3,7
	BCF PORTA,3			;TURN OFF EM
	BTFSC BUFF3,7
	BSF PORTA,3			;TURN ON EM

	BSF PORTB,2
	GOTO ISR_END
;###############################



;###############################
HOME
	BTFSC BUFF3,3
	GOTO STEP_LDR
STEP_HOME
	BTFSS PORTB,7
	GOTO AFTER_STEP

	BCF PORTB,4
	BSF PORTB,4
	CALL DELAY
	GOTO STEP_HOME
;###############################




;###############################
STEP_LDR
	BTFSC PORTA,0		;TEST LDR0 (RA0)
	GOTO REPORT
	BTFSC PORTA,1		;TEST LDR1 (RA1)
	GOTO REPORT

	;BCF PORTB,4
	;BSF PORTB,4
	;CALL DELAY
	;GOTO STEP_LDR
	DECFSZ BUFF1		;DEC BYTE1
	GOTO STEP_MOTOR_LDR	;START STEPPING
	DECFSZ BUFF2		;DEC BYTE2
	GOTO STEP_LDR		;CHECK AGAIN
	GOTO REPORT			;CHECK REPORT EN

STEP_MOTOR_LDR
	BCF PORTB,4
	BSF PORTB,4
	CALL DELAY
	GOTO STEP_LDR
;###############################




;###############################
REPORT
	BTFSS BUFF3,2
	GOTO AFTER_STEP
STEP_REPORT
	BSF FLAG,4
	BSF FLAG,5
	GOTO AFTER_STEP
;###############################



;###############################
REPORT_PIECE
	BCF PORTB,2			;INITIAL: NO PIECE
	BTFSC PORTA,0
	BSF PORTB,2			;THERE IS (RA0 BLOCKED)
	BTFSC PORTA,1
	BSF PORTB,2			;THRE IS (RA1 BLOCKED)

	BSF FLAG,7
	GOTO ISR_END
;###############################




;###############################
AFTER_REPORT
	BCF FLAG,7
	BSF PORTB,2
	GOTO ISR_END
;###############################





;###############################
	;setting output
START_STEP
	DECFSZ BUFF1
	GOTO STEP_MOTOR		;steps the motor several times, based on data stored in DataIn
	DECFSZ BUFF2
	GOTO START_STEP
	GOTO AFTER_STEP		;ends stepping when DataIn is zero, and start waiting for steps again

STEP_MOTOR
	BCF PORTB,4
	BSF PORTB,4
	CALL DELAY
	GOTO START_STEP
;###############################



;###############################
AFTER_STEP
	;COIL ON/OFF
	BTFSC BUFF3,0		
	BSF PORTB,6			;COIL ON
	BTFSS BUFF3,0
	BCF PORTB,6

	BSF PORTB,2			;PIC ready to reciv data again
	GOTO ISR_END
;###############################




;###############################
ISR_END
	BCF INTCON,1		;RBO/INT interrupt did not occur (RETURN TO MAIN)
	RETFIE
;###############################
;###############################

DELAY
	;MOVF MOTOR_SPEED,0		;0A0H
	MOVLW 0FCH
	MOVWF 0CH
	MOVLW 15H	;15H
D1	MOVWF 0DH
D2	DECFSZ 0DH
	GOTO D2
	DECFSZ 0CH
	GOTO D1
	RETURN

	END

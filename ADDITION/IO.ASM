; Copyright 2022 Hideki EIRAKU <hdk_2@users.sourceforge.net>
; Based on
;# MS-DOS v1.25 and v2.0 Source Code
;
;Copyright (c) Microsoft Corporation.
;All rights reserved.
;
;## MIT License.
;
;Permission is hereby granted, free of charge, to any person obtaining
;a copy of this software and associated documentation files (the
;Software), to deal in the Software without restriction, including
;without limitation the rights to use, copy, modify, merge, publish,
;distribute, sublicense, and/or sell copies of the Software, and to
;permit persons to whom the Software is furnished to do so, subject to
;the following conditions:
;
;The above copyright notice and this permission notice shall be
;included in all copies or substantial portions of the Software.
;
;THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND,
;EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;ACTION OF CONTRACT,TORT OR OTHERWISE, ARISING FROM OUT OF OR IN
;CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;SOFTWARE.

CODE    SEGMENT BYTE PUBLIC  'CODE'
        ASSUME  SS:DOSGROUP,CS:DOSGROUP

.xcref
INCLUDE DOSSYM.ASM
.cref
.list

	I_NEED CARPOS,BYTE
	I_NEED STARTPOS,BYTE
	I_NEED INBUF,128
	I_NEED INSMODE,BYTE
	I_NEED ESCCHAR,BYTE

	INCLUDE	STRIN.ASM

entry	BUFOUT
; called by STRIN.ASM and CTRLC.ASM with following comments:
; - "Print control chars nicely" (STRIN.ASM)
; - "Display "^C"" (CTRLC.ASM)
	CMP	AL,' '
	JNB	OUT
	CMP	AL,c_HT
	JE	OUT
	PUSH	AX
	MOV	AL,'^'
	CALL	OUT
	POP	AX
	ADD	AL,'@'
	; Fall through
entry	OUT
; called by STRIN.ASM, DISK.ASM and MISC.ASM.
	;; Expanding tabs and updating CARPOS.
	;; Output with AH=40H is handled in DISK.ASM
	;; which calls this in case of cooked CON only.
	;; Output with AH=02H or AH=09H calls this
	;; even if output is redirected...
	CMP	AL,c_CR
	JE	OUT_CR
	CMP	AL,c_BS
	JE	OUT_BS
	CMP	AL,c_LF
	JE	OUT_LF
	CMP	AL,c_HT
	JNE	OUT_CHAR
entry	TAB
; called by PUTNEW in STRIN.ASM.
	MOV	AL,' '
	CALL	OUT_CHAR
	TEST	[CARPOS],7
	JNE	TAB
	RET
OUT_CR:
	MOV	[CARPOS],1
OUT_BS:
	DEC	[CARPOS]
	JMP	SHORT OUT_LF
OUT_CHAR:
	INC	[CARPOS]
OUT_LF:
	PUSH	DS
	PUSH	SI
	invoke	RAWOUT
	POP	SI
	POP	DS
	RET

; Use the same way as $RAW_CON_INPUT and RAWNORM.
IO_COMMON:
	PUSH	DS
	PUSH	SI
	PUSH	BX
	PUSH	AX
IO_COMMON_STAT:
	invoke	STATCHK
	POP	AX
	POP	BX
	PUSH	BX
	PUSH	AX
        invoke  GET_IO_FCB
	POP	AX
	JC	IO_COMMON_ERROR
	PUSH	AX
	INC	AH
        invoke  IOFUNC
	JZ	IO_COMMON_LOOP
	POP	AX
        invoke  IOFUNC
	CLC
IO_COMMON_ERROR:
	POP	BX
	POP	SI
	POP	DS
	RET
IO_COMMON_LOOP:
        invoke  SPOOLINT
	JMP	IO_COMMON_STAT

        procedure   $STD_CON_INPUT,NEAR   ; System call 1
	XOR	BX,BX
	XOR	AX,AX
	CALL	IO_COMMON
	PUSH	AX
	CALL	OUT
	POP	AX
	CLC
	return
$STD_CON_INPUT ENDP

        procedure   $STD_CON_OUTPUT,NEAR   ; System call 2
	MOV	AL,DL
	CALL	OUT
	return
$STD_CON_OUTPUT ENDP

        procedure   $STD_AUX_INPUT,NEAR   ; System call 3
	MOV	BX,3
	XOR	AX,AX
	CALL	IO_COMMON
	return
$STD_AUX_INPUT ENDP

        procedure   $STD_AUX_OUTPUT,NEAR   ; System call 4
	MOV	BX,3
	MOV	AH,2
	MOV	AL,DL
	CALL	IO_COMMON
	return
$STD_AUX_OUTPUT ENDP

        procedure   $STD_PRINTER_OUTPUT,NEAR   ; System call 5
	MOV	BX,4
	MOV	AH,2
	MOV	AL,DL
	CALL	IO_COMMON
	return
$STD_PRINTER_OUTPUT ENDP

        procedure   $STD_CON_INPUT_NO_ECHO,NEAR   ; System call 8
	XOR	BX,BX
	XOR	AX,AX
	CALL	IO_COMMON
	return
$STD_CON_INPUT_NO_ECHO ENDP

        procedure   $STD_CON_STRING_OUTPUT,NEAR   ; System call 9
	MOV	SI,DX
STROUT_LOOP:
	CLD
	LODSB
	CMP	AL,'$'
	JE	STROUT_END
	CALL	OUT
	JMP	STROUT_LOOP
STROUT_END:
	return
$STD_CON_STRING_OUTPUT ENDP

        procedure   $STD_CON_INPUT_STATUS,NEAR   ; System call 11
	invoke	STATCHK
	XOR	BX,BX
        invoke  GET_IO_FCB
	MOV	AL,0
	JC	INSTAT_NO
	MOV	AH,1
        invoke  IOFUNC
	MOV	AL,0
	JZ	INSTAT_NO
	MOV	AL,0FFH
INSTAT_NO:
	return
$STD_CON_INPUT_STATUS ENDP

; Macro copied from DOSMES.ASM
TransferIf  MACRO   value,address
        local   a
        CMP     AL,value
        JNZ     a
        transfer    address
a:
ENDM

        procedure   $STD_CON_INPUT_FLUSH,NEAR   ; System call 12
	XOR	BX,BX
        invoke  GET_IO_FCB
	JC	FLUSH_RET
	MOV	AH,4
        invoke  IOFUNC
	TransferIf 1,$STD_CON_INPUT
	TransferIf 6,$RAW_CON_IO
	TransferIf 7,$RAW_CON_INPUT
	TransferIf 8,$STD_CON_INPUT_NO_ECHO
	TransferIf 10,$STD_CON_STRING_INPUT
	CLC
FLUSH_RET:
	return
$STD_CON_INPUT_FLUSH ENDP

 CODE   ENDS
        END

; Copyright 2022 Hideki EIRAKU <hdk_2@users.sourceforge.net>
; 
; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; "Software"), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:
; 
; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	
A	SEGMENT
	ASSUME	CS:A,DS:A,ES:A,SS:A
	ORG	100H
START:
	MOV	SP,OFFSET STACK
	MOV	BX,80H
	MOV	AL,[BX]
	CBW
	INC	BX
	LEA	DX,[BX+1]
	ADD	BX,AX
	MOV	BYTE PTR [BX],0
	MOV	AX,3D00H
	INT	21H
	JNC	OPEN_OK
	MOV	DX,OFFSET OPEN_ERR
ERR_EXIT:
	MOV	BX,DX
	XOR	CX,CX
ERR_LOOP:
	CMP	BYTE PTR [BX],CH
	JE	ERR_PRINT
	INC	BX
	INC	CL
	JNE	ERR_LOOP
ERR_PRINT:
	MOV	BX,2
	MOV	AH,40H
	INT	21H
	CALL	CLOSE
	MOV	AX,4C01H
	INT	21H
CLOSE:
	MOV	BX,[HANDLE]
	TEST	BX,BX
	JS	CLOSED
	MOV	AH,3EH
	INT	21H
CLOSED:
	RET
GETBYTE:
	PUSH	AX
	MOV	DX,SP
	MOV	CX,1
	MOV	BX,[HANDLE]
	MOV	AH,3FH
	INT	21H
	MOV	DX,OFFSET READ_ERR
	JC	ERR_EXIT
	CMP	AX,1
	POP	AX
	CLD
	RET
EOF:
	CALL	CLOSE
	MOV	AX,4C00H
	INT	21H
PUT:
	MOV	BX,1
	MOV	AH,40H
	INT	21H
	MOV	DX,OFFSET WRITE_ERR
	JC	ERR_EXIT
	CMP	AX,CX
	JB	ERR_EXIT
	CLD
	RET
PUTBYTE:
	PUSH	AX
	MOV	DX,SP
	MOV	CX,1
	CALL	PUT
	POP	AX
	RET
OPEN_OK:
	MOV	[HANDLE],AX
	MOV	DI,OFFSET STOR
MAINLOOP:
	CALL	GETBYTE
	JC	EOF
	CMP	AL,'%'
	JE	VARIABLE
	CMP	AL,'{'
	JE	BLOCK_BEGIN
	CMP	AL,'}'
	JNE	NOT_BLOCK_END
	CALL	WORD PTR [CB_BLOCK_END]
	JMP	MAINLOOP
NOT_BLOCK_END:
	CALL	PUTBYTE
	JMP	MAINLOOP
VARIABLE:
	PUSH	DI
VARIABLE_LOOP:
	CALL	GETBYTE
	JC	EOF
	CALL	CHARCHECK
	CALL	BUFCHECK
	STOSB
	CMP	AL,'%'
	JNE	VARIABLE_LOOP
	MOV	BYTE PTR [DI-1],0
	POP	DI
	PUSH	DI
	MOV	BX,DI
	CALL	GET_VARIABLE
	MOV	CX,DI
	POP	DI
	MOV	DX,DI
	SUB	CX,DX
	CALL	PUT
	JMP	MAINLOOP
BLOCK_BEGIN:
	CALL	GETBYTE
	CMP	AL,'('
	JE	BLOCK_BEGIN_OK1
	MOV	DX,OFFSET BEGIN_ERR
	JMP	ERR_EXIT
BLOCK_BEGIN_OK1:
	PUSH	DI
	XOR	DX,DX
BLOCK_BEGIN_LOOP1:
	PUSH	DX
	CALL	GETBYTE
	POP	DX
	CALL	CHARCHECK
	CALL	BUFCHECK
	STOSB
	CMP	AL,'('
	JNE	BLOCK_BEGIN_CMP1
	MOV	BYTE PTR [DI-1],0
	INC	DX
	JMP	BLOCK_BEGIN_LOOP1
BLOCK_BEGIN_CMP1:
	CMP	AL,')'
	JNE	BLOCK_BEGIN_LOOP1
	MOV	BYTE PTR [DI-1],0
	DEC	DX
	JNS	BLOCK_BEGIN_LOOP1
	MOV	AL,0
	STOSB
	POP	DI
	MOV	BX,[FUNCLIST]
BLOCK_BEGIN_FL_LOOP2:
	TEST	BX,BX
	JNE	BLOCK_BEGIN_FL_FIND
	CALL	LABELASSIGN
	JMP	MAINLOOP
BLOCK_BEGIN_FL_FIND:
	PUSH	BX
	MOV	CX,[BX+4]
	XOR	BX,BX
BLOCK_BEGIN_FL_LOOP:
	ADD	BX,CX
	MOV	AL,[BX]
	SUB	BX,CX
	CMP	AL,[BX+DI]
	JNE	BLOCK_BEGIN_FL_DIFF
	CMP	AL,0
	JE	BLOCK_BEGIN_FL_FOUND
	INC	BX
	JMP	BLOCK_BEGIN_FL_LOOP
BLOCK_BEGIN_FL_DIFF:
	POP	BX
	MOV	BX,[BX]
	JMP	BLOCK_BEGIN_FL_LOOP2
BLOCK_BEGIN_FL_FOUND:
	MOV	CX,BX
	ADD	CX,DI
	INC	CX
	POP	BX
	CALL	WORD PTR [BX+2]
	JMP	MAINLOOP

GET_VARIABLE:
	MOV	CX,BX
	MOV	DX,[VARLIST]
GET_VARIABLE_LOOP2:
	MOV	BX,DX
	TEST	BX,BX
	JE	GET_VARIABLE_ERROR
	MOV	BX,[BX+2]
	PUSH	CX
GET_VARIABLE_LOOP1:
	MOV	AL,[BX]
	XCHG	BX,CX
	CMP	AL,[BX]
	XCHG	BX,CX
	JNE	GET_VARIABLE_DIFF
	CMP	AL,0
	JE	GET_VARIABLE_FOUND
	INC	BX
	INC	CX
	JMP	GET_VARIABLE_LOOP1
GET_VARIABLE_DIFF:
	POP	CX
	MOV	BX,DX
	MOV	DX,[BX]
	JMP	GET_VARIABLE_LOOP2
GET_VARIABLE_FOUND:
	POP	CX
	MOV	BX,DX
	MOV	BX,[BX+4]
GET_VARIABLE_LOOP3:
	MOV	AL,[BX]
	CMP	AL,0
	JE	GET_VARIABLE_END
	STOSB
	INC	BX
	JMP	GET_VARIABLE_LOOP3
GET_VARIABLE_END:
	RET
GET_VARIABLE_ERROR:
	MOV	DX,OFFSET VAR_ERR
	JMP	ERR_EXIT

CB_ERROR:
	MOV	DX,OFFSET END_ERR
	JMP	ERR_EXIT

CB_PROC:
	MOV	DX,CX
	MOV	BX,CX
CB_PROC_LOOP:
	CMP	BYTE PTR [BX],0
	JE	CB_PROC_OK
	INC	BX
	JMP	CB_PROC_LOOP
CB_PROC_OK:
	MOV	CX,BX
	SUB	CX,DX
	MOV	AX,DI
	MOV	DI,BX
	STOSW
	MOV	AX,DX
	STOSW
	MOV	AX,CX
	STOSW
	CALL	SAVE
	MOV	WORD PTR [CB_BLOCK_END],OFFSET CB_PROCEND
	MOV	[DATA_BLOCK_END],DI
	CALL	PUT
	MOV	DX,OFFSET STR_PROC
	MOV	CX,STR_PROC_LEN
	JMP	PUT
CB_PROCEND:
	CALL	LOAD
	LODSW
	MOV	CX,AX
	LODSW
	MOV	DX,AX
	MOV	DI,[SI]
	CLD
	CALL	PUT
	MOV	DX,OFFSET STR_PROCEND
	MOV	CX,STR_PROCEND_LEN
	JMP	PUT
CB_ARG:
	MOV	BX,CX
CB_ARG_LOOP:
	CMP	BYTE PTR [BX],0
	JE	CB_ARG_OK
	INC	BX
	JMP	CB_ARG_LOOP
CB_ARG_OK:
	MOV	AX,DI
	LEA	DI,[BX+1]
	STOSW
	CALL	SAVE
	MOV	WORD PTR [CB_BLOCK_END],OFFSET CB_ARGEND
	MOV	[DATA_BLOCK_END],DI
	MOV	BX,CX
	MOV	CX,4
CB_ARG_LOOP3:
	MOV	AL,[BX]
	CMP	AL,0
	JE	CB_ARG_DONE
	MOV	DX,DI
	MOV	AX,[VARLIST]
	STOSW
	MOV	AX,BX
	STOSW
	LEA	AX,[DI+2]
	STOSW
	MOV	[VARLIST],DX
CB_ARG_LOOP2:
	INC	BX
	MOV	AL,[BX]
	CMP	AL,0
	JE	CB_ARG_DONE0
	CMP	AL,','
	JNE	CB_ARG_LOOP2
	MOV	BYTE PTR [BX],0
CB_ARG_DONE0:
	PUSH	AX
	MOV	AX,'[' OR ('B' SHL 8)
	STOSW
	MOV	AX,'P' OR ('+' SHL 8)
	STOSW
	MOV	AX,CX
	ADD	CX,2
	CALL	HEXWRITE
	MOV	AX,']'
	STOSW
	POP	AX
	INC	BX
	CMP	AL,0
	JNE	CB_ARG_LOOP3
CB_ARG_DONE:
	MOV	DX,OFFSET STR_ARG
	MOV	CX,STR_ARG_LEN
	JMP	PUT
CB_ARGEND:
	CALL	LOAD
	MOV	DI,[SI]
	CLD
	MOV	DX,OFFSET STR_ARGEND
	MOV	CX,STR_ARGEND_LEN
	JMP	PUT
CB_LOCAL:
	MOV	BX,CX
CB_LOCAL_LOOP:
	CMP	BYTE PTR [BX],0
	JE	CB_LOCAL_OK
	INC	BX
	JMP	CB_LOCAL_LOOP
CB_LOCAL_OK:
	MOV	AX,DI
	LEA	DI,[BX+1]
	STOSW
	CALL	SAVE
	MOV	WORD PTR [CB_BLOCK_END],OFFSET CB_LOCALEND
	MOV	[DATA_BLOCK_END],DI
	MOV	BX,CX
	XOR	CX,CX
CB_LOCAL_LOOP3:
	MOV	AL,[BX]
	CMP	AL,0
	JE	CB_LOCAL_DONE
	MOV	AX,[VARLIST]
	MOV	[VARLIST],DI
	STOSW
	MOV	AX,BX
	STOSW
	LEA	AX,[DI+2]
	STOSW
CB_LOCAL_LOOP2:
	INC	BX
	MOV	AL,[BX]
	CMP	AL,0
	JE	CB_LOCAL_DONE0
	CMP	AL,','
	JNE	CB_LOCAL_LOOP2
	MOV	BYTE PTR [BX],0
CB_LOCAL_DONE0:
	PUSH	AX
	MOV	AX,'[' OR ('B' SHL 8)
	STOSW
	MOV	AX,'P' OR ('-' SHL 8)
	STOSW
	ADD	CX,2
	MOV	AX,CX
	CALL	HEXWRITE
	MOV	AX,']'
	STOSW
	POP	AX
	INC	BX
	CMP	AL,0
	JNE	CB_LOCAL_LOOP3
CB_LOCAL_DONE:
	PUSH	CX
	MOV	DX,OFFSET STR_LOCAL
	MOV	CX,STR_LOCAL_LEN
	CALL	PUT
	POP	AX
	JMP	HEXPUT
CB_LOCALEND:
	CALL	LOAD
	MOV	DI,[SI]
	CLD
	MOV	DX,OFFSET STR_LOCALEND
	MOV	CX,STR_LOCALEND_LEN
	JMP	PUT

LABELASSIGN:
	XOR	AX,AX
	CMP	[DI],AL
	JE	FOR_TMP
FUNC_DEFINE:
	MOV	BX,DI
FUNC_DEFINE_LOOP1:
	INC	BX
	CMP	BYTE PTR [BX],AL
	JNE	FUNC_DEFINE_LOOP1
	INC	BX
	PUSH	BX
FUNC_DEFINE_LOOP2:
	CMP	BYTE PTR [BX],AL
	JE	FUNC_DEFINE_END
	INC	BX
	JMP	FUNC_DEFINE_LOOP2
FUNC_DEFINE_END:
	PUSH	DI
	LEA	DI,[BX+1]
	MOV	AX,[FUNCLIST]
	MOV	[FUNCLIST],DI
	STOSW
	MOV	AX,OFFSET CB_FUNC
	STOSW
	POP	AX
	STOSW
	POP	AX
	STOSW
	CALL	SAVE
	MOV	WORD PTR [CB_BLOCK_END],OFFSET SIMPLE_END
	MOV	[DATA_BLOCK_END],DI
	RET
FOR_TMP:
	MOV	BX,DI
FOR_TMP_LOOP:
	INC	BX
	CMP	[BX],AL
	JNE	FOR_TMP_LOOP
	MOV	AX,DI
	MOV	DX,DI
	LEA	DI,[BX+1]
	STOSW
	CALL	SAVE
	MOV	WORD PTR [CB_BLOCK_END],OFFSET FOR_TMPEND
	MOV	[DATA_BLOCK_END],DI
	MOV	BX,DX
	INC	BX
FOR_TMP_LOOP3:
	MOV	AL,[BX]
	CMP	AL,0
	JE	FOR_TMP_DONE
	MOV	AX,[VARLIST]
	MOV	[VARLIST],DI
	STOSW
	MOV	AX,BX
	STOSW
	LEA	AX,[DI+2]
	STOSW
FOR_TMP_LOOP2:
	INC	BX
	MOV	AL,[BX]
	CMP	AL,0
	JE	FOR_TMP_DONE0
	CMP	AL,','
	JNE	FOR_TMP_LOOP2
	MOV	BYTE PTR [BX],0
FOR_TMP_DONE0:
	PUSH	AX
	CALL	MAKE_LABEL
	POP	AX
	INC	BX
	CMP	AL,0
	JNE	FOR_TMP_LOOP3
FOR_TMP_DONE:
	RET

FOR_TMPEND:
	CALL	LOAD
	MOV	DI,[SI]
	CLD
	RET

CB_FUNC:
	XCHG	BX,CX
	CMP	BYTE PTR [BX],0
	XCHG	BX,CX
	JE	CB_FUNC_OK
	MOV	DX,OFFSET FUNC_ERR
	JMP	ERR_EXIT
CB_FUNC_OK:
	MOV	BX,[BX+6]
	CALL	SAVE
	MOV	WORD PTR [CB_BLOCK_END],OFFSET SIMPLE_END
	MOV	[DATA_BLOCK_END],DI
CB_FUNC_LOOP2:
	MOV	DX,DI
	MOV	AL,[BX]
	CMP	AL,0
	JE	CB_FUNC_DONE
CB_FUNC_LOOP1:
	STOSB
	CMP	AL,0
	JE	CB_FUNC_DONE1
	CMP	AL,','
	JE	CB_FUNC_DONE1
	INC	BX
	MOV	AL,[BX]
	JMP	CB_FUNC_LOOP1
CB_FUNC_DONE1:
	PUSH	AX
	MOV	BYTE PTR [DI-1],0
	MOV	CX,DI
	CALL	MAKE_LABEL
	MOV	AX,[VARLIST]
	MOV	[VARLIST],DI
	STOSW
	MOV	AX,DX
	STOSW
	MOV	AX,CX
	STOSW
	POP	AX
	INC	BX
	CMP	AL,0
	JNE	CB_FUNC_LOOP2
CB_FUNC_DONE:
	RET

MAKE_LABEL:
	MOV	AL,'L'
	STOSB
	MOV	AX,[LABEL_COUNT]
	INC	WORD PTR [LABEL_COUNT]
	CALL	HEXWRITE4
	MOV	AL,0
	STOSB
	RET

SIMPLE_END:
	CALL	LOAD
	CLD
	LEA	DI,[SI+2]
	RET

SAVE:
	MOV	AX,[VARLIST]
	STOSW
	MOV	AX,[FUNCLIST]
	STOSW
	MOV	AX,[CB_BLOCK_END]
	STOSW
	MOV	AX,[DATA_BLOCK_END]
	STOSW
	RET

LOAD:
	MOV	SI,[DATA_BLOCK_END]
	STD
	DEC	SI
	DEC	SI
	LODSW
	MOV	[DATA_BLOCK_END],AX
	LODSW
	MOV	[CB_BLOCK_END],AX
	LODSW
	MOV	[FUNCLIST],AX
	LODSW
	MOV	[VARLIST],AX
	RET

HEXWRITE:
	PUSH	AX
	MOV	AL,'0'
	STOSB
	POP	AX
	CALL	HEXWRITE4
	MOV	AL,'H'
	STOSB
	RET
HEXWRITE4:
	XCHG	AH,AL
	CALL	HEXWRITE2
	XCHG	AH,AL
HEXWRITE2:
	PUSH	CX
	MOV	CL,4
	ROL	AL,CL
	CALL	HEXWRITE1
	ROL	AL,CL
	POP	CX
HEXWRITE1:
	PUSH	AX
	AND	AL,0FH
	ADD	AL,90H
	DAA
	ADC	 AL,40H
	DAA
	STOSB
	POP	AX
	RET
HEXPUT:
	PUSH	DI
	CALL	HEXWRITE
	MOV	CX,DI
	POP	DI
	MOV	DX,DI
	SUB	CX,DI
	JMP	PUT

CHARCHECK:
	CMP	AL,' '
	JLE	CHARCHECK_ERROR
	RET
CHARCHECK_ERROR:
	MOV	DX,OFFSET CHAR_ERR
	JMP	ERR_EXIT

BUFCHECK:
	CMP	DI,OFFSET STOREND
	JNB	BUFCHECK_ERROR
	RET
BUFCHECK_ERROR:
	MOV	DX,OFFSET BUF_ERR
	JMP	ERR_EXIT

OPEN_ERR	DB	'OPEN FAILED',13,10,0
READ_ERR	DB	'READ ERROR',13,10,0
WRITE_ERR	DB	'WRITE ERROR',13,10,0
BEGIN_ERR	DB	'{( ERROR',13,10,0
VAR_ERR		DB	'VARIABLE NOT FOUND',13,10,0
END_ERR		DB	'} ERROR',13,10,0
FUNC_ERR	DB	'FUNC REDEFINED',13,10,0
CHAR_ERR	DB	'CHAR ERROR',13,10,0
BUF_ERR		DB	'OUT OF MEMORY',13,10,0
STR_PROC	DB	' PROC NEAR'
STR_PROC_LEN	EQU	OFFSET $ - OFFSET STR_PROC
STR_PROCEND	DB	' ENDP'
STR_PROCEND_LEN	EQU	OFFSET $ - OFFSET STR_PROCEND
STR_ARG		DB	'PUSH BP',13,10,'MOV BP,SP'
STR_ARG_LEN	EQU	OFFSET $ - OFFSET STR_ARG
STR_ARGEND	DB	'POP BP',13,10,'RET'
STR_ARGEND_LEN	EQU	OFFSET $ - OFFSET STR_ARGEND
STR_LOCAL	DB	'SUB SP,'
STR_LOCAL_LEN	EQU	OFFSET $ - OFFSET STR_LOCAL
STR_LOCALEND	DB	'MOV SP,BP'
STR_LOCALEND_LEN EQU	OFFSET $ - OFFSET STR_LOCALEND
HANDLE		DW	-1
CB_BLOCK_END	DW	OFFSET CB_ERROR
DATA_BLOCK_END	DW	0
LABEL_COUNT	DW	0
FUNCLIST	DW	OFFSET FL_PROC
VARLIST		DW	0
NAME_PROC	DB	'PROC',0
NAME_ARG	DB	'ARG',0
NAME_LOCAL	DB	'LOCAL',0
FL_PROC		DW	OFFSET FL_ARG
		DW	OFFSET CB_PROC
		DW	OFFSET NAME_PROC
FL_ARG		DW	OFFSET FL_LOCAL
		DW	OFFSET CB_ARG
		DW	OFFSET NAME_ARG
FL_LOCAL	DW	0
		DW	OFFSET CB_LOCAL
		DW	OFFSET NAME_LOCAL

STACK	EQU	$+4096
STOR	EQU	$+4096
STOREND	EQU	STOR+32768

A	ENDS
	END	START

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
	MOV	DX,OFFSET EPARM
	XOR	CX,CX
	MOV	BX,81H
	ADD	BL,[BX-1]
PARMLP:
	DEC	BX
	CMP	BX,81H
	JE	ERR
	MOV	AL,[BX]
	CMP	AL,' '
	JE	PARMEN
	CMP	AL,'0'
	JB	ERR
	CMP	AL,'9'
	JBE	HEX09
	CMP	AL,'A'
	JB	ERR
	CMP	AL,'F'
	JBE	HEXAF
	CMP	AL,'a'
	JB	ERR
	CMP	AL,'f'
	JA	ERR
HEXAF:
	ADD	AL,9
HEX09:
	AND	AL,0FH
	CMP	CL,4
	JE	ERR
	INC	CX
	PUSH	AX
	JMP	PARMLP
ERRC:
	MOV	AH,3EH		; CLOSE
	INT	21H
ERR:
	MOV	AH,9		; OUTPUT STRING
	INT	21H
	MOV	AX,4C01H	; EXIT
	INT	21H
PARMEN:
	TEST	CX,CX
	JE	ERR
	XOR	DX,DX
HEXTOV:
	POP	AX
	PUSH	CX
	MOV	CL,4
	SHL	DX,CL
	POP	CX
	OR	DL,AL
	LOOP	HEXTOV
	PUSH	DX
	MOV	BYTE PTR [BX],0
	MOV	DX,82H
	MOV	AX,3D02H	; OPEN
	INT	21H
	MOV	DX,OFFSET EOPEN
	JC	ERR
	XCHG	BX,AX
	MOV	DX,OFFSET BUF
	MOV	CX,14H
	MOV	AH,3FH		; READ
	INT	21H
	MOV	DX,OFFSET EREAD
	JC	ERRC
	MOV	AX,[BUF+0CH]	; MAXIMUM ALLOCATION FIELD
	POP	CX
	MOV	[BUF+0CH],CX	; MAXIMUM ALLOCATION FIELD
	SUB	AX,CX
	ADD	[BUF+12H],AX	; CHECKSUM FIELD
	XOR	CX,CX
	XOR	DX,DX
	MOV	AX,4200H	; SEEK_SET
	INT	21H		; LSEEK
	MOV	DX,OFFSET ELSEEK
	JC	ERRC
	MOV	DX,OFFSET BUF
	MOV	CX,14H
	MOV	AH,40H		; WRITE
	INT	21H
	MOV	DX,OFFSET EWRITE
	JC	ERRC
	MOV	AH,3EH		; CLOSE
	INT	21H
	MOV	DX,OFFSET ECLOSE
	JC	ERR
	MOV	AX,4C00H	; EXIT
	INT	21H

EPARM	DB	'Usage: SETMAXAL.COM FILENAME.EXE maximum-allocation(hex)'
	DB	13,10,'$'
EOPEN	DB	'Open error',13,10,'$'
EREAD	DB	'Read error',13,10,'$'
ELSEEK	DB	'LSeek error',13,10,'$'
EWRITE	DB	'Write error',13,10,'$'
ECLOSE	DB	'Close error',13,10,'$'
BUF	LABEL	WORD

A	ENDS
	END	START

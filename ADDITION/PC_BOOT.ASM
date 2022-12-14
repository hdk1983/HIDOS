;;; Boot sector code for IBM PC compatible or JX
;;; Copyright 2022 Hideki EIRAKU <hdk_2@users.sourceforge.net>

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

;;; Options
;;; JX Japanese BIOS seems to use BIOS data at address < 2000H
LOADSEG	EQU	200H
DSKKiB	EQU	720
;DSKKiB	EQU	1440
;DSKKiB	EQU	1232

IF DSKKiB EQ 720
	SECSIZ	EQU	512
	NSECCLS	EQU	2
	NSECRES	EQU	1
	NFATS	EQU	2
	NRDIR	EQU	112
	NSEC	EQU	1440
	MEDID	EQU	0F9H
	NSECFAT	EQU	3
	NSECTRK	EQU	9
	NHEADS	EQU	2
ENDIF
IF DSKKiB EQ 1440
	SECSIZ	EQU	512
	NSECCLS	EQU	1
	NSECRES	EQU	1
	NFATS	EQU	2
	NRDIR	EQU	224
	NSEC	EQU	2880
	MEDID	EQU	0F0H
	NSECFAT	EQU	9
	NSECTRK	EQU	18
	NHEADS	EQU	2
ENDIF
IF DSKKiB EQ 1232
	SECSIZ	EQU	1024
	NSECCLS	EQU	1
	NSECRES	EQU	1
	NFATS	EQU	2
	NRDIR	EQU	192
	NSEC	EQU	1232
	MEDID	EQU	0FEH
	NSECFAT	EQU	2
	NSECTRK	EQU	8
	NHEADS	EQU	2
ENDIF

A	SEGMENT
	ASSUME	CS:A
	ORG	0
START:
	JMP	MAIN
	ORG	3
	DB	'IBMJHIDO'
	DW	SECSIZ
	DB	NSECCLS
	DW	NSECRES
	DB	NFATS
	DW	NRDIR
	DW	NSEC
	DB	MEDID
	DW	NSECFAT
	DW	NSECTRK
	DW	NHEADS
	DW	0
	DW	0
	DW	0
	DW	0
	DB	0
	DB	0
	DB	0		; No extended boot signature
	DW	0
	DW	0
	DB	'           '
	DB	'FAT12   '

DSKERR	DB	'READ ERROR',0
FILEERR	LABEL BYTE
IO_FILENAME DB 	'IO      SYS'
	DB	' NOT FOUND',0
DISKBIOSNOERR PROC NEAR
	PUSH	BP
	MOV	BP,-3		; Retry count
DISKBIOS_RETRY:
	PUSH	AX
	PUSH	CX
	PUSH	DX
	MOV	BX,DI
	INT	13H
	JNC	DISKBIOS_RET
	INC	BP
	JNS	DISKBIOSERR
	POP	DX
	PUSH	DX
	MOV	AH,0
	INT	13H
	POP	DX
	POP	CX
	POP	AX
	JNC	DISKBIOS_RETRY
	XOR	BP,BP
	JMP	DISKBIOS_RETRY
DISKBIOS_RET:
	POP	BP
	POP	BP
	POP	BP
	POP	BP
	RET
DISKBIOSERR:
	MOV	SI,OFFSET DSKERR
ERRSTOP:
	CLD
	LODS	BYTE PTR CS:[SI]
	DB	0A8H		; TEST AL,immediate
ERRSTOP1:
	HLT			; 0F4H
	JE	ERRSTOP1
	MOV	AH,0EH
	INT	10H
	JMP	ERRSTOP
DISKBIOSNOERR ENDP

MAIN:
	DB	0EAH		; JMP FAR
	DW	OFFSET MAIN2
	DW	7C0H
MAIN2:
	MOV	AX,CS
	MOV	SS,AX
	MOV	SP,1024
	XOR	BP,BP
	PUSH	DX
	TEST	DL,40H
	JE	DLOK
	CMP	BYTE PTR [BP+11+10],0FCH ; Media ID
	JB	DLOK
	;; Booting 40 track disk on JX
	XOR	DL,40H
DLOK:
	MOV	AX,LOADSEG
	MOV	ES,AX
	XOR	DI,DI
	MOV	SI,OFFSET IO_FILENAME
	JMP	SHORT RDR_START
FILENOTFOUND:
	MOV	SI,OFFSET FILEERR
	JMP	ERRSTOP
	INCLUDE	FIL_RDR.ASM
	PUSH	ES		; Avoid debugging detection
	POP	DS		; and for relocation
	XOR	BX,BX
	POP	DX
	PUSH	ES
	CMP	DS:[BX],'M' OR ('Z' SHL 8)
	JNE	NOTR
	;; Relocatable IO.SYS!
	;; Jump to the paragraph just after the header.
	;; Relocation will be done in IO.SYS.
	POP	AX
	ADD	AX,DS:[BX+8]	; Header size in paragraph
	PUSH	AX
NOTR:
	PUSH	BX
GOTO	PROC	FAR
	RET
GOTO	ENDP
	ORG	510
	DB	55H,0AAH
A	ENDS
	END	START

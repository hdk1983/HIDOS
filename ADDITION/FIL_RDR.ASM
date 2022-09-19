;;; Simple file reader for boot sector code
;;; Copyright 2022 Hideki EIRAKU <hdk_2@users.sourceforge.net>

;;; JMP RDR_START with following definitions:
;;; Registers
;;; DL		Drive
;;; ES:DI	Destination (will be updated to next to FAT)
;;; BP		-13 + Offset of BIOS Parameter Block (BPB)
;;;		WORD PTR [BP+0] is used for temporary
;;; CS:SI	File name (11 bytes)
;;; Symbols
;;; DISKBIOSNOERR	Procedure calling disk bios with error handling
;;;			and retry if necessary (use DI for BX)
;;; FILENOTFOUND	Procedure handling file not found error

RDR_LBA	PROC	NEAR
	PUSH	AX
	PUSH	CX
	PUSH	DX
	XCHG	AX,CX
	CWD			   ; LBA is expected less than 32768
	DIV	WORD PTR [BP+11+13] ; BPB Number of sectors per track
	INC	DX
	MOV	CL,DL
	CWD
	DIV	BYTE PTR [BP+11+15] ; BPB Number of heads
	MOV	DH,AH
	MOV	CH,AL
	POP	AX
	MOV	DL,AL
	MOV	AX,201H
	CALL	DISKBIOSNOERR
	POP	CX
	POP	AX
	ADD	DI,[BP+11]	; BPB Sector size
	INC	CX
	RET
RDR_LBA	ENDP

RDR_START:
	PUSH	DI
	MOV	CX,[BP+11+3]	; BPB Reserved sectors
	MOV	AX,[BP+11+11]	; BPB Number of FAT sectors
RDR_FATLOOP:
	CALL	RDR_LBA
	DEC	AX
	JNE	RDR_FATLOOP
	PUSH	DI
	MOV	AL,[BP+11+5]	; BPB Number of FATs
RDR_SKIPFAT:
	DEC	AX
	JE	RDR_READROOT
	ADD	CX,[BP+11+11]	; BPB Number of FAT sectors
	JMP	RDR_SKIPFAT
RDR_READROOT:
	MOV	AX,[BP+11+6]	; BPB Number of root directory entries
	PUSH	CX
	MOV	CL,5
	SHL	AX,CL		; Each entry is 32-byte long.
	POP	CX
RDR_READROOT_LOOP:
	CALL	RDR_LBA
	SUB	AX,[BP+11]	; BPB Sector size
	JA	RDR_READROOT_LOOP
	MOV	BYTE PTR ES:[DI],0
	POP	DI
	MOV	[BP+0],CX
	MOV	CL,4
	SHR	DI,CL
	MOV	AX,ES
	MOV	DS,AX
	ADD	AX,DI
	MOV	ES,AX
	XOR	DI,DI
RDR_SEARCH:
	CMP	BYTE PTR ES:[DI],0
	JE	FILENOTFOUND
	PUSH	DI
	PUSH	SI
	MOV	CX,11
	CLD
RDR_CMPS:			; Avoid using REPE for 8088 bug workaround
	CMPS	BYTE PTR CS:[SI],ES:[DI]
	LOOPE	RDR_CMPS
	POP	SI
	POP	DI
	LEA	DI,[DI+32]
	JNE	RDR_SEARCH
	MOV	AX,ES:[DI-32+1AH] ; Start cluster
	XOR	DI,DI
RDR_READLOOP:
	CMP	AX,0FF0H
	JAE	RDR_DONE
	PUSH	AX
	PUSH	DX
	DEC	AX
	DEC	AX
	XCHG	AX,CX
	MOV	AL,[BP+11+2]	; BPB Number of sectors per cluster
	CBW
	PUSH	AX
	MUL	CX
	ADD	AX,[BP+0]
	XCHG	AX,CX
	POP	AX
	POP	DX
RDR_CLUSTER_LOOP:
	CALL	RDR_LBA
	DEC	AX
	JNE	RDR_CLUSTER_LOOP
	POP	AX
	POP	SI
	PUSH	SI
	SHR	AX,1
	MOV	CL,0
	JNC	RDR_CLUSTER_EVEN
	MOV	CL,4
RDR_CLUSTER_EVEN:
	ADC	SI,AX
	ADD	SI,AX
	ADD	SI,AX
	MOV	AX,[SI]
	SHR	AX,CL
	AND	AX,0FFFH
	JMP	RDR_READLOOP
RDR_DONE:
	POP	SI

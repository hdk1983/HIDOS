; IO.SYS as a DOS application
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

       TITLE   IO.SYS

; I/O system for Version 2.x of MSDOS.

;This BIOS designed to be linked with the SYSINIT module provided by
;Microsoft

;Things needed to communicate with SYSINIT

EXTRN   SYSINIT:FAR                   ;The entry point of SYSINIT
EXTRN   CURRENT_DOS_LOCATION:WORD     ;Where the DOS is when SYSINIT called
EXTRN   FINAL_DOS_LOCATION:WORD       ;Where I want SYSINIT to put the DOS
EXTRN   DEVICE_LIST:DWORD             ;Pointer to the DEVICE list.
EXTRN   MEMORY_SIZE:WORD              ;Size in paragraphs of Physical memory.
EXTRN   DEFAULT_DRIVE:BYTE            ;Default Drive to use when system booted
EXTRN   BUFFERS:BYTE                  ;Number of default buffers.
                                      ; Leave as is and SYSINIT uses only 2.

CODE    SEGMENT
CODE    ENDS

STACK	SEGMENT STACK
STACKSIZE EQU 128
	DB	STACKSIZE DUP (?)
STACK	ENDS

SYSINITSEG      SEGMENT PUBLIC 'SYSTEM_INIT'
SYSINITSEG      ENDS

LAST	SEGMENT PUBLIC 'LAST'
LAST	ENDS

CODE    SEGMENT
ASSUME  CS:CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING
BIOSSEG	EQU	CODE

        ORG     0               ;Starts at an offset of zero.

        PAGE

        SUBTTL  Device driver tables.

;-----------------------------------------------+
;     DWORD pointer to next device              | 1 word offset.
;         (-1,-1 if last device)                | 1 word segement.
;-----------------------------------------------+
;     Device attribute WORD                     ; 1 word.
;       Bit 15 = 1 for chacter devices.         ;
;                0 for Block devices.           ;
;                                               ;
;       Charcter devices. (Bit 15=1)            ;
;         Bit 0 = 1  current sti device.        ;
;         Bit 1 = 1  current sto device.        ;
;         Bit 2 = 1  current NUL device.        ;
;         Bit 3 = 1  current Clock device.      ;
;                                               ;
;         Bit 13 = 1 for non IBM machines.      ;
;                  0 for IBM machines only.     ;
;         Bit 14 = 1 IOCTL control bit.         ;
;-----------------------------------------------+
;     Device strategy pointer.                  ; 1 word offset.
;-----------------------------------------------+
;     Device interrupt pointer.                 ; 1 word offset.
;-----------------------------------------------+
;     Device name field.                        ; 8 bytes.
;       Character devices are any valid name    ;
;         left justified, in a space filled     ;
;         field.                                ;
;       Block devices contain # of units in     ;
;         the first byte.                       ;
;-----------------------------------------------+

DEVSTART LABEL WORD
CONDEV:                         ;Header for device CON
        DW      AUXDEV,BIOSSEG  ;Link to next device
        DW      8013H           ;Attributes - console input, output device
				; and SPECIAL
        DW      STRATEGY        ;Srategy entry point
        DW      CON_INT         ;Interrupt entry point
        DB      "CON     "      ;Device name

AUXDEV:                         ;Header for device AUX
        DW      PRNDEV,BIOSSEG
        DW      8000H
        DW      STRATEGY
        DW      AUX_INT
        DB      "AUX     "

PRNDEV:                         ;Header for device PRN
        DW      TIMDEV,BIOSSEG
        DW      8000H
        DW      STRATEGY
        DW      PRN_INT
        DB      "PRN     "

TIMDEV:                         ;Header for device CLOCK
	DW	EXTDEV,BIOSSEG
        DW      8008H
        DW      STRATEGY
        DW      TIM_INT
        DB      "CLOCK   "

EXTDEV:
        DW      DSKDEV,BIOSSEG
        DW      8000H
        DW      STRATEGY
	DW	EXT_INT
        DB      "EXIT$   "

DSKDEV:                         ;Header for disk devices
        DW      -1,-1           ;Last device
        DW      2000H           ;Is a block device
        DW      STRATEGY
        DW      DSK_INT
DRVMAX  DB      1               ;Number of Units
        DB      7 DUP (?)

        PAGE
        SUBTTL  Dispatch tables for each device.

DSKTBL: DW      DSK_INIT        ;0  - Initialize Driver.
        DW      MEDIAC          ;1  - Return current media code.
        DW      GET_BPB         ;2  - Get Bios Parameter Block.
        DW      CMDERR          ;3  - Reserved. (currently returns error)
        DW      DSK_RED         ;4  - Block read.
        DW      BUS_EXIT        ;5  - (Not used, return busy flag)
        DW      EXIT            ;6  - Return status. (Not used)
        DW      EXIT            ;7  - Flush input buffer. (Not used.)
        DW      DSK_WRT         ;8  - Block write.
        DW      DSK_WRV         ;9  - Block write with verify.
        DW      EXIT            ;10 - Return output status.
        DW      EXIT            ;11 - Flush output buffer. (Not used.)
        DW      EXIT            ;12 - IO Control.

CONTBL: DW      EXIT            ;0  - Init. (Not used)
        DW      EXIT            ;1  - Media check (Not used)
        DW      EXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      CMDERR          ;3  - Reserved. (Currently returns error)
        DW      CON_READ        ;4  - Character read. (Destructive)
        DW      CON_RDND        ;5  - Character read. (Non-destructive)
        DW      EXIT            ;6  - Return status. (Not used)
        DW      CON_FLSH        ;7  - Flush Input buffer.
        DW      CON_WRIT        ;8  - Character write.
        DW      CON_WRIT        ;9  - Character write with Verify.
        DW      CON_WRST        ;10 - Character write status.
        DW      EXIT            ;11 - Flush output buffer. (Not used.)
        DW      EXIT            ;12 - IO Control.

AUXTBL: DW      EXIT            ;0  - Init. (Not used)
        DW      EXIT            ;1  - Media check (Not used)
        DW      EXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      CMDERR          ;3  - Reserved. (Returns an error)
        DW      AUX_READ        ;4  - Character read. (Destructive)
        DW      AUX_RDND        ;5  - Character read. (Non-destructive)
        DW      EXIT            ;6  - Return status. (Not used)
        DW      AUX_CLR         ;7  - Flush Input buffer.
        DW      AUX_WRIT        ;8  - Character write.
        DW      AUX_WRIT        ;9  - Character write with verify.
        DW      AUX_WRST        ;10 - Character write status.
        DW      EXIT            ;11 - Flush output buffer. (Not used.)
        DW      EXIT            ;12 - IO Control.

TIMTBL: DW      EXIT            ;0  - Init. (Not used)
        DW      EXIT            ;1  - Media check (Not used)
        DW      EXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      CMDERR          ;3  - Reserved. (Currently returns an error)
        DW      TIM_RED         ;4  - Character read. (Destructive)
        DW      BUS_EXIT        ;5  - (Not used, returns busy flag.)
        DW      EXIT            ;6  - Return status. (Not used)
        DW      EXIT            ;7  - Flush Input buffer. (Not used)
        DW      TIM_WRT         ;8  - Character write.
        DW      TIM_WRT         ;9  - Character write with verify.
        DW      EXIT            ;10 - Character write status. (Not used)
        DW      EXIT            ;11 - Flush output buffer. (Not used)
        DW      EXIT            ;12 - IO Control.

PRNTBL: DW      EXIT            ;0  - (Not used)
        DW      EXIT            ;1  - (Not used)
        DW      EXIT            ;2  - Block (Not used)
        DW      CMDERR          ;3  - Reserved. (currently returns error)
        DW      EXIT            ;4  - (Not used)
        DW      BUS_EXIT        ;5  - (Not used, returns busy flag.)
        DW      EXIT            ;6  - (Not used)
        DW      EXIT            ;7  - (Not used)
        DW      PRN_WRT         ;8  - Character write.
        DW      PRN_WRT         ;9  - Character write with verify.
        DW      PRN_STA         ;10 - Character write status.
        DW      EXIT            ;11 - (Not used.)
        DW      EXIT            ;12 - IO Control.

EXTTBL: DW      EXIT            ;0  - (Not used)
        DW      EXIT            ;1  - (Not used)
        DW      EXIT            ;2  - Block (Not used)
        DW      CMDERR          ;3  - Reserved. (currently returns error)
        DW      EXIT            ;4  - (Not used)
        DW      BUS_EXIT        ;5  - (Not used, returns busy flag.)
        DW      EXIT            ;6  - (Not used)
        DW      EXIT            ;7  - (Not used)
        DW      EXT_WRT         ;8  - Character write.
        DW      EXT_WRT         ;9  - Character write with verify.
        DW      EXT_STA         ;10 - Character write status.
        DW      EXIT            ;11 - (Not used.)
        DW      EXIT            ;12 - IO Control.

        PAGE
        SUBTTL  Strategy and Software Interrupt routines.

;Define offsets for io data packet

IODAT   STRUC
CMDLEN  DB      ?               ;LENGTH OF THIS COMMAND
UNIT    DB      ?               ;SUB UNIT SPECIFIER
CMD     DB      ?               ;COMMAND CODE
STATUS  DW      ?               ;STATUS
        DB      8 DUP (?)
MEDIA   DB      ?               ;MEDIA DESCRIPTOR
TRANS   DD      ?               ;TRANSFER ADDRESS
COUNT   DW      ?               ;COUNT OF BLOCKS OR CHARACTERS
START   DW      ?               ;FIRST BLOCK TO TRANSFER
IODAT   ENDS

PTRSAV  DD      0               ;Strategy pointer save.

;
; Simplistic Strategy routine for non-multi-Tasking system.
;
;   Currently just saves I/O packet pointers in PTRSAV for
;   later processing by the individual interrupt routines.
;

STRATP  PROC    FAR

STRATEGY:
        MOV     WORD PTR CS:[PTRSAV],BX
        MOV     WORD PTR CS:[PTRSAV+2],ES
	PUBLIC RE_INIT
RE_INIT LABEL FAR
        RET

STRATP  ENDP

;
; Console interrupt routine for processing I/O packets.
;

CON_INT:
        PUSH    SI
        MOV     SI,OFFSET CONTBL
        JMP     SHORT ENTRY

;
; Auxilary interrupt routine for processing I/O packets.
;

AUX_INT:
        PUSH    SI
        MOV     SI,OFFSET AUXTBL
        JMP     SHORT ENTRY

;
; Printer interrupt routine for processing I/O packets.
;

PRN_INT:
        PUSH    SI
        MOV     SI,OFFSET PRNTBL
        JMP     SHORT ENTRY

;
; Clock interrupt routine for processing I/O packets.
;

TIM_INT:
        PUSH    SI
        MOV     SI,OFFSET TIMTBL
        JMP     SHORT ENTRY

EXT_INT:
        PUSH    SI
        MOV     SI,OFFSET EXTTBL
        JMP     SHORT ENTRY

;
; Disk interrupt routine for processing I/O packets.
;

DSK_INT:
        PUSH    SI
        MOV     SI,OFFSET DSKTBL

;
; Common program for handling the simplistic I/O packet
;   processing scheme in MSDOS 2.0
;

ENTRY:  PUSH    AX              ;Save all nessacary registers.
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    BP
        PUSH    DS
        PUSH    ES
        PUSH    BX

	CLD
        LDS     BX,CS:[PTRSAV]  ;Retrieve pointer to I/O Packet.

        MOV     AL,[BX.UNIT]    ;AL = Unit code.
        MOV     AH,[BX.MEDIA]   ;AH = Media descriptor.
        MOV     CX,[BX.COUNT]   ;CX = Contains byte/sector count.
        MOV     DX,[BX.START]   ;DX = Starting Logical sector.

        XCHG    DI,AX           ;Move Unit & Media into DI temporarily.
        MOV     AL,[BX.CMD]     ;Retrieve Command type. (1 => 11)
        XOR     AH,AH           ;Clear upper half of AX for calculation.
        ADD     SI,AX           ;Compute entry pointer in dispatch table.
        ADD     SI,AX
        CMP     AL,11           ;Verify that not more than 11 commands.
        JA      CMDERR          ;Ah, well, error out.
        XCHG    AX,DI           ;Move Unit & Media back where they belong.
        LES     DI,[BX.TRANS]   ;DI contains addess of Transfer address.
                                ;ES contains segment.
        PUSH    CS
        POP     DS              ;Data segment same as Code segment.
	ASSUME	DS:CODE
        JMP     [SI]            ;Perform I/O packet command.

        PAGE
        SUBTTL  Common error and exit points.

BUS_EXIT:                       ;Device busy exit.
        MOV     AH,00000011B    ;Set busy and done bits.
        JMP     SHORT EXIT1

CMDERR: MOV     AL,3            ;Set unknown command error #.

;
;  Common error processing routine.
;   AL contains actual error code.
;
;   Error # 0 = Write Protect violation.
;           1 = Unkown unit.
;           2 = Drive not ready.
;           3 = Unknown command in I/O packet.
;           4 = CRC error.
;           5 = Bad drive request structure length.
;           6 = Seek error.
;           7 = Unknown media discovered.
;           8 = Sector not found.
;           9 = Printer out of paper.
;          10 = Write fault.
;          11 = Read fault.
;          12 = General failure.
;

ERR_EXIT:
        MOV     AH,10000001B    ;Set error and done bits.
        STC                     ;Set carry bit also.
        JMP     SHORT EXIT1     ;Quick way out.

EXITP   PROC    FAR             ;Normal exit for device drivers.

EXIT:   MOV     AH,00000001B    ;Set done bit for MSDOS.
EXIT1:  LDS     BX,CS:[PTRSAV]
        MOV     [BX.STATUS],AX  ;Save operation compete and status.

        POP     BX              ;Restore registers.
        POP     ES
        POP     DS
        POP     BP
        POP     DI
        POP     DX
        POP     CX
        POP     AX
        POP     SI
        RET                             ;RESTORE REGS AND RETURN
EXITP   ENDP

        PAGE
        SUBTTL  Main console I/O section.

;
; Console keyboard handler.
;

;
; Console read non-destructive.
;

CON_RDND:
	MOV	SI,OFFSET CON_BUF
	LODSB
	DEC	AL
	JE	CON_RDND4
	CALL	VECTSWAP
	MOV	DL,0FFH
	MOV	AH,6		; Raw console input/output
	INT	21H
	LAHF
	CALL	VECTSWAP
	SAHF
	JZ	CON_RDND3
	MOV	BYTE PTR [SI-1],1
	MOV	[SI],AL
	DB	0A8H		; TEST AL,immediate
CON_RDND4:
	LODSB
	LDS	BX,[PTRSAV]
	MOV	[BX.MEDIA],AL
	JMP	EXIT
CON_RDND3:
	JMP	BUS_EXIT

;
; Console destructive read.
;

CON_READ:
	MOV	SI,OFFSET CON_BUF
	LODSB
	DEC	AL
	JNE	CON_READ2
	MOV	[SI-1],AL
	MOVSB
	LOOP	CON_READ2
	JMP	EXIT
CON_READ2:
	CALL	VECTSWAP
CON_READ3:
	MOV	AH,7		; Raw console input
	INT	21H
	STOSB
	LOOP	CON_READ3
	CALL	VECTSWAP
	JMP	EXIT
;
; Console flush routine. (ctrl-c, ctrl-f, or ctrl-s inspired)
;

CON_FLSH:
	MOV	BYTE PTR [CON_BUF],0
	CALL	VECTSWAP
	MOV	AX,0C00H	; Console input flush
	INT	21H
	CALL	VECTSWAP
        JMP     EXIT

;
; Console output status routine.
;

CON_WRST:
        JMP     EXIT            ;Yes, normal exit.

;
; Console output routine.
;

WRITE_COMMON:
	CALL	VECTSWAP
	PUSH	DS
	MOV	AX,ES
	MOV	DS,AX
	MOV	DX,DI
	MOV	AH,40H
	INT	21H
	POP	DS
	CALL	VECTSWAP
	JMP	EXIT

CON_WRIT:
	MOV	BX,1
	JMP	WRITE_COMMON

;
; Console character output routine.
;

INT29H:
	PUSH	DX
	CALL	VECTSWAP
	CMP	AL,0FFH
	JE	INT29H_VERYSLOW
	MOV	DL,AL
	PUSH	AX
	MOV	AH,6		; Raw console input/output
	INT	21H
	POP	AX
INT29H_RET:
	CALL	VECTSWAP
	POP	DX
	IRET
INT29H_VERYSLOW:
	PUSH	DS
	PUSH	BX
	PUSH	CX
	PUSH	AX
	MOV	AX,SS
	MOV	DS,AX
	MOV	DX,SP
	MOV	CX,1
	MOV	BX,1
	MOV	AH,40H		; Write
	INT	21H
	POP	AX
	POP	CX
	POP	BX
	POP	DS
	JMP	INT29H_RET

        PAGE
        SUBTTL  Printer buffer handler.

;
; Printer status routine.
;

PRN_STA:
        JMP     EXIT

;
; Printer write routine.
;

PRN_WRT:
	MOV	BX,4
	JMP	WRITE_COMMON

        PAGE
        SUBTTL  Auxilary I/O routines.

;
; Non-Destructive Auxilary read routine.
;

AUX_RDND:
	MOV	SI,OFFSET AUX_BUF
	MOV	BX,3
	CMP	BYTE PTR [SI],0
	JE	RDND2
RDND1:
	MOV	AL,[SI+1]
	LDS	BX,[PTRSAV]
        MOV     [BX.MEDIA],AL
        JMP     EXIT
RDND2:
	CALL	VECTSWAP
	MOV	AX,4406H	; Ioctl / Get input status
	INT	21H
	JC	RDND3
	TEST	AL,AL
	JE	RDND3
	LEA	DX,[SI+1]
	MOV	CX,1
	MOV	AH,3FH		; Read
	INT	21H
	JC	RDND3
	TEST	AX,AX
	JE	RDND3
	MOV	[SI],AL
RDND3:
	CALL	VECTSWAP
	CMP	BYTE PTR [SI],0
	JNE	RDND1
        JMP     BUS_EXIT

;
; Destructive Auxilary read routine.
;

AUX_READ:
	MOV	SI,OFFSET AUX_BUF
	MOV	BX,3
	LODSB
	DEC	AL
	JNE	READ_COMMON2
	MOV	[SI-1],AL
	MOVSB
	LOOP	READ_COMMON2
	JMP	EXIT
READ_COMMON2:
	CALL	VECTSWAP
	PUSH	DS
	MOV	AX,ES
	MOV	DS,AX
	MOV	DX,DI
	MOV	AH,3FH		; Read
	INT	21H
	POP	DS
	JC	READ_ERROR
	CALL	VECTSWAP
	LDS	BX,[PTRSAV]
	MOV	[BX.COUNT],AX
	JMP	EXIT
READ_ERROR:
	CALL	VECTSWAP
	MOV	AL,11
	JMP	ERR_EXIT

;
; Auxilary clear type a head.
;

AUX_CLR:
	MOV	BYTE PTR [AUX_BUF],0
        JMP     EXIT

;
; Auxilary write port status.
;

AUX_WRST:
        JMP     EXIT

;
; Auxilary write.
;

AUX_WRIT:
	MOV	BX,3
	JMP	WRITE_COMMON

        PAGE
        SUBTTL  Date/Time Routines.

TIM	STRUC
TIM_DAYS  DW    ?               ;Number of days since 1-1-80.
TIM_MINS  DB    ?               ;Minutes.
TIM_HRS   DB    ?               ;Hours.
TIM_HSEC  DB    ?               ;Hundreths of a second.
TIM_SECS  DB    ?               ;Seconds.
TIM	ENDS

;
; Time write routine.
;

TIM_WRT:
	CMP	CX,6
	JAE	TIM_WRT1
	MOV	AL,10
	JMP	ERR_EXIT
TIM_WRT1:
	CALL	VECTSWAP
	XOR	CX,CX
	XOR	DX,DX
	MOV	AH,2DH		; Set time
	INT	21H
	XOR	CX,CX
	MOV	AX,ES:[DI.TIM_DAYS]
	CMP	AX,36524+7305+60
	JB	TIM_WRT2
	MOV	CX,100
	SUB	AX,36524
TIM_WRT2:
	SUB	AX,7305+60
	SBB	DX,DX
	MOV	BX,365*4+1
	IDIV	BX
	TEST	DX,DX
	JNS	TIM_WRT3
	ADD	DX,BX
	DEC	AX
TIM_WRT3:
	SAL	AX,1
	SAL	AX,1
	ADD	CX,AX
	XCHG	AX,DX
	CWD
	MOV	BX,365
	DIV	BX
	CMP	AX,4
	JB	TIM_WRT5
	ADD	DX,BX
TIM_WRT5:
	ADC	AX,2000-1
	ADD	CX,AX
	MOV	AX,DX
	SHL	AX,1
	SHL	AX,1
	ADD	AX,DX
	INC	AX
	INC	AX
	MOV	BL,153
	DIV	BL
	MOV	BH,AL
	MUL	BL
	INC	AX
	INC	AX
	MOV	BL,10
	DIV	BL
	CMP	AH,5
	CMC
	MOV	AH,0
	RCL	AX,1
	SUB	DX,AX
	MOV	DH,BH
	ADD	DX,0301H
	CMP	DH,12
	JBE	TIM_WRT4
	SUB	DH,12
	INC	CX
TIM_WRT4:
	MOV	AH,2BH		; Set date
	INT	21H
	MOV	CX,WORD PTR ES:[DI.TIM_MINS]
	MOV	DX,WORD PTR ES:[DI.TIM_HSEC]
	MOV	AH,2DH		; Set time
	INT	21H
	CALL	VECTSWAP
	LDS	BX,[PTRSAV]
	MOV	[BX.COUNT],6
	JMP	EXIT

;
; Time read routine.
;

TIM_RED:
	CMP	CX,6
	JAE	TIM_RED1
	MOV	AL,11
	JMP	ERR_EXIT
TIM_RED1:
	CALL	VECTSWAP
	MOV	AH,2AH		; Get date
	INT	21H
TIM_RED2:			; CX,DX=Date
	PUSH	CX
	PUSH	DX
	MOV	AH,2CH		; Get time
	INT	21H
	MOV	WORD PTR ES:[DI.TIM_MINS],CX
	MOV	WORD PTR ES:[DI.TIM_HSEC],DX
	MOV	AH,2AH		; Get date
	INT	21H
	POP	BX
	POP	AX
	CMP	AX,CX		; Compare date
	JNE	TIM_RED2
	CMP	BX,DX
	JNE	TIM_RED2
	SUB	BH,3
	JNB	TIM_RED3
	ADD	BH,12
	DEC	AX
TIM_RED3:
	CWD
	MOV	CX,100
	DIV	CX
	SUB	AX,20
	JE	TIM_RED4
	MOV	AX,36524	; 2000-03-01 - 2100-02-28
	JA	TIM_RED4
	NOT	AX		; 1900-03-01 - 2000-02-29
TIM_RED4:
	ADD	AX,7305+60-1
	XCHG	AX,CX
	MOV	AX,DX
	SHR	AX,1
	SHR	AX,1
	ADD	CX,AX
	MOV	AX,365
	MUL	DX
	ADD	CX,AX
	MOV	AL,153
	MUL	BH
	INC	AX
	INC	AX
	MOV	BH,10
	DIV	BH
	CMP	AH,5
	CMC
	MOV	AH,0
	MOV	BH,AH
	RCL	AX,1
	ADD	CX,AX
	ADD	CX,BX
	MOV	ES:[DI.TIM_DAYS],CX
	CALL	VECTSWAP
	LDS	BX,[PTRSAV]
	MOV	[BX.COUNT],6
	JMP	EXIT

	PAGE

EXT_WRT:
	MOV	SI,DI
EXT_LOOP:
	LODS	BYTE PTR ES:[SI]
	CMP	AL,'0'
	JB	EXT_CONT
	CMP	AL,'9'
	JBE	EXT_EXIT
EXT_CONT:
	LOOP	EXT_LOOP
EXT_STA:
        JMP     EXIT
EXT_EXIT:
	CALL	VECTSWAP
	PUSH	AX
	MOV	DX,OFFSET EXIT_MESSAGE
	MOV	AH,9
	INT	21H
	MOV	AX,3301H
	MOV	DL,CS:[OLDBREAK]
	INT	21H
	;; Restore raw/cooked mode in reverse order
	;; because 0, 1 and 2 may share the same mode.
	MOV	BX,4
RESTORE_LOOP:
	MOV	AX,4400H	; Ioctl / Get device information
	INT	21H
	JC	RESTORE_SKIP
	TEST	DL,DL
	JNS	RESTORE_SKIP	; Skip if file
	AND	DH,7FH		; Clear reserved bit
	MOV	DL,CS:[OLDDEVMODE+BX]
	MOV	AX,4401H	; Ioctl / Set device information
	INT	21H
RESTORE_SKIP:
	DEC	BX
	JNS	RESTORE_LOOP
	POP	AX
	AND	AL,0FH
	MOV	AH,4CH		; Exit
	INT	21H

        PAGE
        SUBTTL  Drive Tables.

DBP     STRUC

JMPNEAR DB      3 DUP (?)       ;Jmp Near xxxx  for boot.
NAMEVER DB      8 DUP (?)       ;Name / Version of OS.

;-------  Start of Drive Parameter Block.

SECSIZE DW      ?               ;Sector size in bytes.                  (dpb)
ALLOC   DB      ?               ;Number of sectors per alloc. block.    (dpb)
RESSEC  DW      ?               ;Reserved sectors.                      (dpb)
FATS    DB      ?               ;Number of FAT's.                       (dpb)
MAXDIR  DW      ?               ;Number of root directory entries.      (dpb)
SECTORS DW      ?               ;Number of sectors per diskette.        (dpb)
MEDIAID DB      ?               ;Media byte ID.                         (dpb)
FATSEC  DW      ?               ;Number of FAT Sectors.                 (dpb)

;-------  End of Drive Parameter Block.

SECTRK  DW      ?               ;Number of Sectors per track.
NHEADS	DW	?		;Number of heads

DBP     ENDS

LDDRIV1 DBP	<,,4096,1,1,2,192,1232,0FEH,2,8,2>

DSK_INIT:
	MOV	SI,[INITTAB_ADDR]
	MOV     AX,1
DSKNUNT	EQU	$-2
	MOV	CX,AX
	XOR	BX,BX
DISK_INIT_LOOP:
	MOV	WORD PTR [BX+SI],OFFSET LDDRIV1.SECSIZE
	INC	BX
	INC	BX
	LOOP	DISK_INIT_LOOP
        JMP     GET_BP5

DISK_RW_COMMON:
	PUSH	AX
	MOV	BX,OFFSET DISKFLAG
	MOV	SI,0FFH
	AND	SI,AX
	XLAT
	CMP	AL,0
	JNE	DISK_RW9
	JMP	DISK_RW1
DISK_RW9:
	TEST	AL,2		; Read-only file flag
	JE	DISK_RW4
	CMP	AH,40H
	JNE	DISK_RW4
	POP	AX
	MOV	AL,0		; Write protect violation
	STC
	RET
DISK_RW4:
	TEST	AL,4		; Check for first access
	MOV	AX,0
	JNE	DISK_RW7
	OR	BYTE PTR [BX+SI],4
	INC	AX
DISK_RW7:
	PUSH	AX
	MOV	AX,SI
	MOV	AH,SIZE DBP
	MUL	AH
	MOV	BX,[DBP_ADDR]
	ADD	BX,AX
	CALL	VECTSWAP
	POP	AX
	TEST	AX,AX
	JE	DISK_RW8
	PUSH	DX
	PUSH	CX
	PUSH	BX
	MOV	DX,BX
	MOV	CX,SIZE DBP
	MOV	BX,OFFSET DISKFD
	ADD	BX,SI
	ADD	BX,SI
	MOV	BX,[BX]
	MOV	AH,3FH		; Read
	INT	21H
	POP	BX
	POP	CX
	POP	DX
	JC	DISK_ERROR_RW
DISK_RW8:
	MOV	BX,[BX.SECSIZE]
	MOV	AX,DX
	MUL	BX
	PUSH	DX
	PUSH	AX
	MOV	AX,CX
	MUL	BX
	POP	DX
	POP	CX
	PUSH	AX
	MOV	BX,OFFSET DISKFD
	ADD	SI,SI
	MOV	BX,[BX+SI]
	MOV	AX,4200H	; LSeek
	INT	21H
	POP	CX
	POP	AX
	JC	DISK_ERROR_SEEK
	PUSH	DS
	MOV	DX,ES
	MOV	DS,DX
	MOV	DX,DI
	INT	21H
	POP	DS
	JC	DISK_ERROR_RW
	CMP	AX,CX
	JNE	DISK_ERROR_RW
	CALL	VECTSWAP
	XOR	AX,AX
	RET
DISK_RW1:
	POP	AX
	SHL	AL,1
	MOV	BX,OFFSET DISKFD
	XLAT
	CALL	VECTSWAP
	PUSH	DS
	MOV	[DISK_RW_TMP],SP
	MOV	BX,ES
	MOV	DS,BX
	MOV	BX,DI
	CMP	AH,40H
	JE	DISK_RW5
	INT	25H
	JMP	SHORT DISK_RW6
DISK_RW5:
	INT	26H
DISK_RW6:
	MOV	SP,CS:[DISK_RW_TMP]
	POP	DS
	JC	DISK_ERROR_RW
	CALL	VECTSWAP
	XOR	AX,AX
	RET
DISK_ERROR_SEEK:
	CALL	VECTSWAP
	MOV	AL,6
	STC
	RET
DISK_ERROR_RW:
	CALL	VECTSWAP
	MOV	AL,8
	STC
	RET

DISK_READ:
	MOV	AH,3FH		; Read
	JMP	DISK_RW_COMMON
DISK_WRITE:
	MOV	AH,40H		; Write
	JMP	DISK_RW_COMMON

        PAGE
        SUBTTL  Media check routine

;
; Media check routine.
; On entry:
;       AL = disk unit number.
;       AH = media byte
; On exit:
;
;       [MEDIA FLAG] = -1 (FF hex) if disk is changed.
;       [MEDIA FLAG] = 0 if don't know.
;       [MEDIA FLAG] = 1 if not changed.
;

MEDIAS  STRUC
        DB      13 DUP(?)               ;Static request header.
MEDIAS1 DB      ?                       ;Media byte.
MEDIAS2 DB      ?                       ;Media status byte flag.
MEDIAS  ENDS

MEDIAC:
	MOV	BX,OFFSET DISKFLAG
	XLAT
	MOV	AH,0
	CMP	AL,0
	JE	MEDIA1
	MOV	AH,1
MEDIA1: LDS     BX,[PTRSAV]     ;Udate media section of data block.
        MOV     [BX.MEDIAS2],AH
	MOV	AL,0
        JMP     EXIT

        PAGE
        SUBTTL  Build and return Bios Parameter Block for a diskette.

;
; Build Bios Parameter Blocks.
;
;       On entry:  ES:DI contains the address of a scratch sector buffer.
;                  AL = Unit number.
;                  AH = Current media byte.
;
;       On exit:   Return a DWORD pointer to the associated BPB
;                  in the Request packet.
;

BPBS    STRUC
        DB      13 DUP(?)               ;Static request header.
BPB1    DB      ?                       ;Media byte.
BPB2    DW      ?                       ;DWORD transfer address.
        DW      ?
BPB3    DW      ?                       ;DWORD pointer to BPB
        DW      ?
BPBS    ENDS

GET_BPB:
	PUSH	AX
	MOV	CX,1
	XOR	DX,DX
	PUSH	DI
	CALL	DISK_READ
	POP	DI
	JNC	GET_BPB_OK
	ADD	SP,2
	JMP	ERR_EXIT
GET_BPB_OK:
	POP	AX
	MOV	SI,[DBP_ADDR]
	XOR	BX,BX
	MOV	CX,SIZE DBP
	MUL	CL
	ADD	SI,AX
GET_BPB_LOOP:
	MOV	AL,ES:[BX+DI]
	MOV	[BX+SI],AL
	INC	BX
	LOOP	GET_BPB_LOOP
	XOR	AX,AX

GET_BP4:MOV     AL,[SI.MEDIAID]
        ADD     SI,11           ;Convert to DPB pointer

GET_BP5:LDS     BX,[PTRSAV]     ;Update I/O data packet.
        MOV     [BX.BPB1],AL    ;Media byte.
        MOV     [BX.BPB3],SI    ;DPB pointer.
        MOV     [BX.BPB3+2],CS  ;Code segment.
	OR	AH,AH
	JNZ	GET_BP6
	MOV	AL,0
	JMP     EXIT
GET_BP6:MOV	AX,7
	JMP	ERR_EXIT

        PAGE
        SUBTTL  MSDOS 2.x Disk I/O drivers.

;
; Disk READ/WRITE functions.
;
; On entry:
;       AL = Disk I/O driver number
;       AH = Media byte.
;       ES = Disk transfer segment.
;       DI = Disk transfer offset in ES.
;       CX = Number of sectors to transfer
;       DX = Logical starting sector.
;
; On exit:
;       Normal exit through common exit routine.
;
;       Abnormal exit through common error routine.
;

DSK_RED:
	CALL	DISK_READ
        JMP     SHORT DSK_COM
DSK_WRV:
DSK_WRT:CALL	DISK_WRITE

DSK_COM:
	JC	DSK_COM_ERROR
	JMP	EXIT
DSK_COM_ERROR:
        JMP     ERR_EXIT

	PAGE

VECTSWAP PROC	NEAR
	PUSH	DS
	PUSH	AX
	PUSH	BX
	PUSH	DX
	PUSH	SI
	XOR	AX,AX
	MOV	DS,AX
	MOV	SI,CS:[VECT_ADDR]
	XOR	BX,BX
VECTSWAP1:
	MOV	AX,DS:[20H*4+BX]
	MOV	DX,CS:[SI+BX]
	MOV	CS:[SI+BX],AX
	MOV	DS:[20H*4+BX],DX
	INC	BX
	INC	BX
	CMP	BX,48H
	JB	VECTSWAP1
	MOV	AX,DS:[0]
	MOV	DX,CS:[SI+BX]
	MOV	CS:[SI+BX],AX
	MOV	DS:[0],DX
	MOV	AX,DS:[2]
	MOV	DX,CS:[SI+BX+2]
	MOV	CS:[SI+BX+2],AX
	MOV	DS:[2],DX
	POP	SI
	POP	DX
	POP	BX
	POP	AX
	POP	DS
	RET
VECTSWAP ENDP

	PAGE

EXIT_MESSAGE	DB	'Exiting',13,10,'$'
DISKFLAG	DB	26 DUP (?)
DISKFD		DW	26 DUP (?)
INITTAB_ADDR	DW	?
DBP_ADDR	DW	?
VECT_ADDR	DW	?
OLDBREAK	DB	?
OLDDEVMODE	DB	5 DUP (?)
CON_BUF		DB	0,?
AUX_BUF		DB	0,?
DISK_RW_TMP	DW	?

        PAGE
        SUBTTL  Initalization code and temporary work areas.

;
; Overlayed by MSDOS by SYSINIT.
;
DRVEND	LABEL	BYTE
	ASSUME	DS:NOTHING

USAGE	DB	'Usage: DOS_IO.EXE MSDOS.SYS (drive-list)',13,10,'$'
OPEN_MSDOS_ERROR DB 'Open MSDOS.SYS failed',13,10,'$'
OUT_OF_MEMORY_ERROR DB 'Out of memory',13,10,'$'
READ_MSDOS_ERROR DB 'Read MSDOS.SYS failed',13,10,'$'
DRIVE_ERROR DB	'Invalid drive parameter',13,10,'$'
FILE_ERROR DB	'Open file failed',13,10,'$'

HWINIT:
	;; Get arguments
	MOV	BP,SP
	MOV	SI,81H
	CLD
ARG1:
	LODSB
	CMP	AL,' '
	JE	ARG1
	CMP	AL,13
	JE	ARGEND
	DEC	SI
	PUSH	SI
ARG2:
	LODSB
	CMP	AL,13
	JE	ARGEND2
	CMP	AL,' '
	JNE	ARG2
	MOV	BYTE PTR [SI-1],0
	JMP	ARG1
ARGEND2:
	MOV	BYTE PTR [SI-1],0
ARGEND:
	LEA	AX,[BP-4]
	CMP	AX,SP
	JAE	ARGOK
	MOV	DX,OFFSET USAGE
ERREND:
	MOV	AX,CS
	MOV	DS,AX
	MOV	AH,9
	INT	21H
	MOV	AX,4C01H
	INT	21H
ARGOK:
	;; Read MSDOS.SYS
	MOV	DX,[BP-2]
	MOV	AX,3D00H	; Open
	INT	21H
	JNC	OPENOK
	MOV	DX,OFFSET OPEN_MSDOS_ERROR
	JMP	ERREND
OUT_OF_MEMORY:
	MOV	DX,OFFSET OUT_OF_MEMORY_ERROR
	JMP	ERREND
OPENOK:
	PUSH	DS
	MOV	BX,AX
	MOV	DX,DS:[2]
	MOV	AX,LAST
	MOV	DS,AX
	ADD	AX,STACKSIZE/16
	SUB	DX,AX
	JBE	OUT_OF_MEMORY
	MOV	AX,16
	MUL	DX
	CMP	DL,1
	CMC
	SBB	DX,DX
	OR	AX,DX
	XCHG	AX,CX
	XOR	DX,DX
	MOV	AH,3FH
	INT	21H		; Read
	POP	DS
	JNC	READOK
	MOV	DX,OFFSET READ_MSDOS_ERROR
	JMP	ERREND
READOK:
	CMP	AX,CX
	JE	OUT_OF_MEMORY
	MOV	CS:[MSDOS_SIZE],AX
	MOV	AH,3EH		; Close
	INT	21H
	;; Set devices to raw mode
	XOR	BX,BX
SETRAW_LOOP:
	MOV	AX,4400H	; Ioctl / Get device information
	INT	21H
	JC	SETRAW_SKIP
	TEST	DL,DL
	JNS	SETRAW_SKIP	; Skip if file
	MOV	CS:[OLDDEVMODE+BX],DL
	AND	DH,7FH		; Clear reserved bit
	OR	DL,20H		; Set raw bit
	MOV	AX,4401H	; Ioctl / Set device information
	INT	21H
SETRAW_SKIP:
	INC	BX
	CMP	BX,5
	JB	SETRAW_LOOP
	;; Disable ^C check
	MOV	AX,3300H
	INT	21H
	MOV	CS:[OLDBREAK],DL
	MOV	DL,0
	MOV	AX,3301H
	INT	21H
	;; Count number of drives
	LEA	AX,[BP-2]
	SUB	AX,SP
	SHR	AX,1
	MOV	WORD PTR CS:[DSKNUNT],AX
	MOV	CX,AX
	;; Set addresses
	MOV	AX,OFFSET DRVEND
	MOV	CS:[VECT_ADDR],AX
	ADD	AX,48H+4
	MOV	CS:[INITTAB_ADDR],AX
	ADD	AX,CX
	ADD	AX,CX
	MOV	CS:[DBP_ADDR],AX
	XCHG	AX,SI
	MOV	AL,SIZE DBP
	MUL	CL
	ADD	AX,SI
	MOV	CS:[FINAL_LOC],AX
	;; Open images
	MOV	SI,-1
OPEN_LOOP:
	INC	SI
	CMP	SI,CX
	JAE	OPEN_END
	MOV	DI,SI
	SHL	DI,1
	NEG	DI
	MOV	BX,[BP-4+DI]
	NEG	DI
	CMP	WORD PTR [BX+1],':'
	JNE	ISFILE
	MOV	AL,[BX]
	AND	AX,0DFH
	CMP	AL,'A'
	JB	DRIVEERR
	CMP	AL,'Z'
	JBE	DRIVEOK
DRIVEERR:
	MOV	DX,OFFSET DRIVE_ERROR
	JMP	ERREND
DRIVEOK:
	SUB	AL,'A'
	MOV	CS:[DISKFD+DI],AX
	MOV	CS:[DISKFLAG+SI],AH
	JMP	OPEN_LOOP
ISFILE:
	MOV	DX,BX
	MOV	AX,3D02H	; Open
	INT	21H
	MOV	DL,1		; Read-write file flag
	JNC	OPENIMGOK
	MOV	DX,BX
	MOV	AX,3D00H	; Open
	INT	21H
	MOV	DL,2		; Read-only file flag
	JNC	OPENIMGOK
	MOV	DX,OFFSET FILE_ERROR
	JMP	ERREND
OPENIMGOK:
	MOV	CS:[DISKFD+DI],AX
	MOV	CS:[DISKFLAG+SI],DL
	JMP	OPEN_LOOP
OPEN_END:
	;; Stack at the end of the DOS will be used until the SYSINIT
	;; moves the DOS to the FINAL_DOS_LOCATION.
	MOV	AX,CS:[MSDOS_SIZE]
	ADD	AX,15
	MOV	CL,4
	SHR	AX,CL
	ADD	AX,LAST
	MOV	SS,AX
	MOV	SP,STACKSIZE

	;; Prepare interrupt vector
	XOR	BX,BX
	MOV	SI,CS:[VECT_ADDR]
	XOR	AX,AX
VECTCLEAR_LOOP:
	MOV	CS:[SI+BX],AX
	INC	BX
	INC	BX
	CMP	BX,48H+4
	JB	VECTCLEAR_LOOP

	;; CON SPECIAL support
	PUSH	DS
	XOR	AX,AX
	MOV	DS,AX
	MOV	BX,29H*4
	MOV	AX,OFFSET INT29H
	MOV	CX,CS
	TEST	CS:[OLDDEVMODE+1],90H ; ISDEV|SPECL
	JE	STDOUT_NOT_SPECIAL
	JPO	STDOUT_NOT_SPECIAL
	;; Fast path!
	MOV	AX,DS:[BX+0]
	MOV	CX,DS:[BX+2]
STDOUT_NOT_SPECIAL:
	CALL	VECTSWAP
	MOV	DS:[BX+0],AX
	MOV	DS:[BX+2],CX
	POP	DS

	MOV	BX,DS:[2]
	MOV	AX,SEG SYSINIT
        MOV     DS,AX

ASSUME  DS:SEG SYSINIT

        MOV     DS:[MEMORY_SIZE],BX
        MOV     DS:[CURRENT_DOS_LOCATION],LAST
	MOV	AX,CS:[FINAL_LOC]
	ADD	AX,15
	MOV	CL,4
	SHR	AX,CL
	ADD	AX,CODE
        MOV     DS:[FINAL_DOS_LOCATION],AX
        MOV     WORD PTR DS:[DEVICE_LIST],OFFSET DEVSTART
        MOV     WORD PTR DS:[DEVICE_LIST+2],CS
	JMP	SYSINIT

MSDOS_SIZE DW	?
FINAL_LOC DW	?

CODE    ENDS

        END	HWINIT

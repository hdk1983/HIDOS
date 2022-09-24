; IO.SYS for a HIDOS virtual machine
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

ANSI    EQU     0               ;Ansi switch.

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
ASSUME  CS:CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING
BIOSSEG	EQU	CODE

        ORG     0               ;Starts at an offset of zero.

IOSTRUC	STRUC
IODEV	DW	?		; Disk, Console, ...
IOIDX	DW	?		; 0, 1, ...
IOCMD	DW	?		; Read, Write, ...
IOBUF	DW	?,?		; Short buffer
IOADR	DW	?,?		; Address
IOSIZ	DW	?,?		; Length in bytes
IOSTRUC	ENDS

IOAREA	LABEL	IOSTRUC
INIT:   JMP     HWINIT
	ORG	OFFSET INIT + SIZE IOSTRUC

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
IF ANSI
        DW      8003H           ;Attributes - console input, output device
ENDIF
IFE ANSI
	DW	8013H		; and SPECIAL
ENDIF
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
        DW      DSKDEV,BIOSSEG
        DW      8008H
        DW      STRATEGY
        DW      TIM_INT
        DB      "CLOCK   "

DSKDEV:                         ;Header for disk devices
        DW      -1,-1           ;Last device
        DW      2000H           ;Is a block device
        DW      STRATEGY
        DW      DSK_INT
DRVMAX  DB      1               ;Number of Units
        DB      7 DUP (?)

        PAGE
        SUBTTL  Dispatch tables for each device.

DSKTBL:	DW	'DI'
	DW      DSK_INIT        ;0  - Initialize Driver.
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

CONTBL:	DW	'CO'
	DW      EXIT            ;0  - Init. (Not used)
        DW      EXIT            ;1  - Media check (Not used)
        DW      EXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      CMDERR          ;3  - Reserved. (Currently returns error)
        DW      CHAR_READ       ;4  - Character read. (Destructive)
        DW      CHAR_RDND       ;5  - Character read. (Non-destructive)
        DW      EXIT            ;6  - Return status. (Not used)
        DW      EXIT            ;7  - Flush Input buffer.
        DW      CHAR_WRIT       ;8  - Character write.
        DW      CHAR_WRIT       ;9  - Character write with Verify.
        DW      EXIT            ;10 - Character write status.
        DW      EXIT            ;11 - Flush output buffer. (Not used.)
        DW      EXIT            ;12 - IO Control.

AUXTBL:	DW	'AU'
	DW      EXIT            ;0  - Init. (Not used)
        DW      EXIT            ;1  - Media check (Not used)
        DW      EXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      CMDERR          ;3  - Reserved. (Currently returns error)
        DW      CHAR_READ       ;4  - Character read. (Destructive)
        DW      CHAR_RDND       ;5  - Character read. (Non-destructive)
        DW      EXIT            ;6  - Return status. (Not used)
        DW      EXIT            ;7  - Flush Input buffer.
        DW      CHAR_WRIT       ;8  - Character write.
        DW      CHAR_WRIT       ;9  - Character write with Verify.
        DW      EXIT            ;10 - Character write status.
        DW      EXIT            ;11 - Flush output buffer. (Not used.)
        DW      EXIT            ;12 - IO Control.

TIMTBL:	DW	'CL'
	DW      EXIT            ;0  - Init. (Not used)
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

PRNTBL:	DW	'PR'
	DW      EXIT            ;0  - (Not used)
        DW      EXIT            ;1  - (Not used)
        DW      EXIT            ;2  - Block (Not used)
        DW      CMDERR          ;3  - Reserved. (currently returns error)
        DW      EXIT            ;4  - (Not used)
        DW      BUS_EXIT        ;5  - (Not used, returns busy flag.)
        DW      EXIT            ;6  - (Not used)
        DW      EXIT            ;7  - (Not used)
        DW      CHAR_WRIT       ;8  - Character write.
        DW      CHAR_WRIT       ;9  - Character write with verify.
        DW      EXIT            ;10 - Character write status.
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
        RET

STRATP  ENDP

	PUBLIC RE_INIT
RE_INIT	PROC	FAR
	PUSH	BX
	PUSH	DS
	XOR	BX,BX
	MOV	DS,BX
	MOV	BX,28H*4
	PUSH	DS:[BX]
	PUSH	DS:[BX+2]
	POP	CS:[ORIG28H+2]
	POP	CS:[ORIG28H]
	MOV	WORD PTR DS:[BX],OFFSET INT28H
	MOV	DS:[BX+2],CS
	POP	DS
	POP	BX
	RET
RE_INIT	ENDP

INT28H:
	MOV	CS:[IOAREA.IODEV],'CO'
	MOV	CS:[IOAREA.IOCMD],'RW'
	CALL	CALLIO0
	DB	0EAH
ORIG28H	DW	?,?

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
	LODS	WORD PTR CS:[SI]
	MOV	CS:[IOAREA.IODEV],AX

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

CALLIO0	PROC	NEAR
	MOV	CS:[IOAREA.IOIDX],0
CALLIO:
	PUSH	AX
	MOV	AX,CS
	INT	86H
	POP	AX
	RET
CALLIO0	ENDP

STORADR	PROC	NEAR
	PUSH	BP
	MOV	BP,SP
	PUSH	AX
	PUSH	DX
	MOV	AX,16
	MUL	WORD PTR [BP+6]
	ADD	AX,[BP+4]
	ADC	DX,0
	MOV	[IOAREA.IOADR+0],AX
	MOV	[IOAREA.IOADR+2],DX
	POP	DX
	POP	AX
	POP	BP
	RET	4
STORADR	ENDP

	PAGE
	SUBTTL	Character device I/O section.

CHARSTAT:
	MOV	[IOAREA.IOCMD],'RP'
	CALL	CALLIO0
	MOV	AX,[IOAREA.IOBUF]
	TEST	AX,AX
	RET

CHARREAD:
	MOV	[IOAREA.IOCMD],'R1'
	CALL	CALLIO0
	MOV	AX,[IOAREA.IOBUF]
	RET

CHARINP:
	CALL	CHARSTAT
	JE	CHARINP
	CALL	CHARREAD
	RET

CHAR_RDND:
	CALL	CHARSTAT
	JE	CHAR_RDND1
        LDS     BX,CS:[PTRSAV]
        MOV     [BX.MEDIA],AL
        JMP     EXIT
CHAR_RDND1:
        JMP     BUS_EXIT

CHAR_READ:
	CALL	CHARINP
	STOSB
	LOOP	CHAR_READ
        JMP     EXIT

CHAR_WRIT:
	XOR	AX,AX
	MOV	[IOAREA.IOIDX],AX
	MOV	[IOAREA.IOCMD],'WR'
	PUSH	ES
	PUSH	DI
	CALL	STORADR
	MOV	[IOAREA.IOSIZ+0],CX
	MOV	[IOAREA.IOSIZ+2],AX
	CALL	CALLIO
        JMP     EXIT

        PAGE
        SUBTTL  Main console I/O section.

INT29H:
	MOV	CS:[IOAREA.IODEV],'CO'
	MOV	CS:[IOAREA.IOCMD],'W1'
	MOV	CS:[IOAREA.IOBUF],AX
	CALL	CALLIO0
	IRET

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
	JMP	BUS_EXIT
TIM_WRT1:
	MOV	AL,ES:[DI.TIM_HSEC]
	CBW
	MOV	CX,10000
	MUL	CX		; To microseconds
	PUSH	DX
	PUSH	AX
	MOV	AL,ES:[DI.TIM_HRS]
	MOV	CX,60
	MUL	CL
	XCHG	AX,BX
	MOV	AL,ES:[DI.TIM_MINS]
	CBW
	ADD	AX,BX
	MUL	CX
	XCHG	AX,BX
	MOV	AL,ES:[DI.TIM_SECS]
	CBW
	ADD	AX,BX
	ADC	DX,0
	PUSH	DX
	PUSH	AX
	MOV	AX,3652		; Number of days 1970-01-01 - 1980-01-01
	CWD
	ADD	AX,ES:[DI.TIM_DAYS]
	PUSH	DX
	PUSH	AX
	MOV	[IOAREA.IOIDX],DX
	MOV	[IOAREA.IOCMD],'WR'
	MOV	CX,SP
	PUSH	SS
	PUSH	CX
	CALL	STORADR
	MOV	[IOAREA.IOSIZ+0],12
	MOV	[IOAREA.IOSIZ+2],DX
	CALL	CALLIO
	ADD	SP,12
        JMP     EXIT

;
; Time read routine.
;

TIM_RED:
	CMP	CX,6
	JAE	TIM_RED1
	JMP	BUS_EXIT
TIM_RED1:
	SUB	SP,12
	XOR	AX,AX
	MOV	[IOAREA.IOIDX],AX
	MOV	[IOAREA.IOCMD],'RD'
	MOV	CX,SP
	PUSH	SS
	PUSH	CX
	CALL	STORADR
	MOV	[IOAREA.IOSIZ+0],12
	MOV	[IOAREA.IOSIZ+2],AX
	CALL	CALLIO
	POP	AX
	POP	DX
	SUB	AX,3652
	MOV	ES:[DI.TIM_DAYS],AX
	POP	AX
	POP	DX
	MOV	CX,60
	DIV	CX
	MOV	ES:[DI.TIM_SECS],DL
	DIV	CL
	MOV	ES:[DI.TIM_MINS],AH
	MOV	ES:[DI.TIM_HRS],AL
	POP	AX
	POP	DX
	MOV	CX,10000
	DIV	CX
	MOV	ES:[DI.TIM_HSEC],AL
        JMP     EXIT

        PAGE
        SUBTTL  Drive Tables.


;
; MSDOS drive initialization tables and other what not.
;

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

MOVIMM	STRUC
	DB	?
IMM	DW	?
MOVIMM	ENDS

DSK_INIT:
DSKNUNT	LABEL	MOVIMM
	MOV	AX,1
	MOV	SI,OFFSET INITTAB
        JMP     SHORT GET_BP5

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
	MOV	AX,100H
MEDIA1: LDS     BX,[PTRSAV]     ;Udate media section of data block.
        MOV     [BX.MEDIAS2],AH
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
	CBW
	MOV	[IOAREA.IOIDX],AX
	ADD	AX,AX
	XCHG	AX,BX
	MOV	SI,[OFFSET INITTAB+BX]
	LEA	SI,[SI-11]
	XOR	AX,AX
	MOV	[IOAREA.IOCMD],'RD'
	MOV	[IOAREA.IOBUF+0],AX
	MOV	[IOAREA.IOBUF+2],AX
	MOV	[IOAREA.IOSIZ+0],SIZE DBP
	MOV	[IOAREA.IOSIZ+2],AX
	PUSH	CS
	PUSH	SI
	CALL	STORADR
	CALL	CALLIO
	CMP	[IOAREA.IOBUF+0],AX
	JE	GET_BP6
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
	MOV	BX,'RD'
        JMP     SHORT DSK_COM
DSK_WRV:
DSK_WRT:MOV	BX,'WR'

DSK_COM:
	CBW
	MOV	[IOAREA.IOIDX],AX
	MOV	[IOAREA.IOCMD],BX
	ADD	AX,AX
	XCHG	AX,BX
	MOV	BX,[OFFSET INITTAB+BX]
	MOV	AX,[BX]		;SECSIZE
	PUSH	AX
	MUL	DX
	MOV	[IOAREA.IOBUF+0],AX
	MOV	[IOAREA.IOBUF+2],DX
	POP	AX
	MUL	CX
	MOV	[IOAREA.IOSIZ+0],AX
	MOV	[IOAREA.IOSIZ+2],DX
	PUSH	ES
	PUSH	DI
	CALL	STORADR
	CALL	CALLIO
	XOR	AX,AX
	CMP	[IOAREA.IOBUF+0],AX
	JE	DERROR
        JMP	EXIT                    ;All done.

        PAGE
        SUBTTL  Disk Error processing.

;
; Disk error routine.
;

DERROR: LDS     BX,CS:[PTRSAV]
        MOV     [BX.COUNT],0
        PUSH    CS
        POP     DS
	MOV	AL,8
	JMP	ERR_EXIT

        PAGE
        SUBTTL  Initalization code and temporary work areas.

;
; Overlayed by MSDOS by SYSINIT.
;
INITTAB	LABEL	WORD
	ASSUME	DS:NOTHING

HWINIT:
	MOV	AX,7000H
	MOV	SS,AX
	MOV	SP,0
	CLD
	ASSUME	DS:CODE,ES:CODE
	MOV	AX,CODE
	MOV	ES,AX
	MOV	AX,CS
	MOV	DS,AX
	XOR	SI,SI
	XOR	DI,DI
	MOV	CX,OFFSET INITTAB
	REP	MOVSB
SEGOK:
	;; Scan drives
	MOV	[IOAREA.IODEV],'IN'
	MOV	[IOAREA.IOCMD],'DI'
	CALL	CALLIO0
	MOV	AX,[IOAREA.IOBUF]
	MOV	ES:[DSKNUNT.IMM],AX
	XCHG	AX,CX
	PUSH	CX
	MOV	DI,OFFSET INITTAB
	LEA	AX,[DI+11]
	ADD	AX,CX
	ADD	AX,CX
CREATE_INITTAB:
	STOSW
	ADD	AX,SIZE DBP
	LOOP	CREATE_INITTAB
	SUB	AX,11
	MOV	[ENDADDR.IMM],AX
	POP	CX
	XOR	BX,BX
LOAD_INITBPBS:
	CMP	BX,CX
	JAE	LOAD_INITBPBS_DONE
	XOR	AX,AX
	MOV	[IOAREA.IODEV],'DI'
	MOV	[IOAREA.IOIDX],BX
	MOV	[IOAREA.IOCMD],'RD'
	MOV	[IOAREA.IOBUF+0],AX
	MOV	[IOAREA.IOBUF+2],AX
	MOV	[IOAREA.IOSIZ+0],SIZE DBP
	MOV	[IOAREA.IOSIZ+2],AX
	PUSH	ES
	PUSH	DI
	CALL	STORADR
	CALL	CALLIO
	INC	BX
	ADD	DI,SIZE DBP
	CMP	[IOAREA.IOBUF+0],AX
	JNE	LOAD_INITBPBS
	MOV	AL,'E'
	PUSHF
	PUSH	CS
	CALL	INT29H
HLTLOOP:
	HLT
	JMP	HLTLOOP
LOAD_INITBPBS_DONE:

	;; CON SPECIAL support
	ASSUME	DS:NOTHING,ES:NOTHING
	XOR	AX,AX
	MOV	DS,AX
	MOV	WORD PTR DS:[29H*4+0],OFFSET INT29H
	MOV	WORD PTR DS:[29H*4+2],ES

	MOV	AX,CS
	SUB	AX,CODE
	ADD	AX,SEG SYSINIT
        MOV     DS,AX
ASSUME  DS:SEG SYSINIT

	MOV	CS:[IOAREA.IODEV],'IN'
	MOV	CS:[IOAREA.IOCMD],'RA'
	CALL	CALLIO0
	MOV	AX,CS:[IOAREA.IOBUF+0]
	MOV	DX,CS:[IOAREA.IOBUF+2]
	MOV	CX,16
	DIV	CX
        MOV     DS:[MEMORY_SIZE],AX

	MOV	CS:[IOAREA.IODEV],'IN'
	MOV	CS:[IOAREA.IOCMD],'DO'
	CALL	CALLIO0
	MOV	AX,CS:[IOAREA.IOBUF]
        MOV     DS:[CURRENT_DOS_LOCATION],AX

ENDADDR	LABEL	MOVIMM
	MOV	AX,0
	ADD	AX,OFFSET INITTAB+15
	MOV	CL,4
	SHR	AX,CL
	ADD	AX,CODE
        MOV     DS:[FINAL_DOS_LOCATION],AX

        MOV     WORD PTR DS:[DEVICE_LIST+2],CODE
        MOV     WORD PTR DS:[DEVICE_LIST],OFFSET DEVSTART

	MOV	AX,OFFSET SYSINIT
	PUSH	DS
	PUSH	AX
GOTO	PROC	FAR
	RET
GOTO	ENDP

CODE    ENDS

        END

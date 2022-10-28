; IO.SYS for PC-98
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

RELOC	SEGMENT
RELOC	ENDS

CODE    SEGMENT
CODE    ENDS

SYSINITSEG      SEGMENT PUBLIC 'SYSTEM_INIT'
SYSINITSEG      ENDS

STACK	SEGMENT STACK 'STACK'
STACKSIZE EQU 128
	DB	STACKSIZE DUP (?)
STACK	ENDS

LAST	SEGMENT PUBLIC 'LAST'
LAST	ENDS

SEG_98	EQU	1E0H

RELOC	SEGMENT
	ORG	0
	;; The 98_BOOT.BIN jumps to here.
	;; MZ header is at DS:0.
	;; Relocate to the address that IO.SYS will stay at.
	;; The address might be different from loaded address.
	ASSUME	CS:RELOC
RELOCPR	PROC	FAR
	MOV	AX,SEG_98
	SUB	AX,CODE		; This CODE value is not relocated yet!
	XOR	BX,BX
	CMP	WORD PTR DS:[BX],'M' OR ('Z' SHL 8)
	JNE	$		; Sanity check
	MOV	CX,DS:[BX+6]	; Number of relocation
	JCXZ	$		; Sanity check
	MOV	SI,DS:[BX+18H]	; Relocation table offset
	MOV	BX,CS		; Loaded segment (DS+header size)
RELOC_LOOP:
	ADD	DS:[SI+2],BX
	LES	DI,DWORD PTR DS:[SI]
	ADD	ES:[DI],AX
	ADD	SI,4
	LOOP	RELOC_LOOP
	;; Relocation has been completed.
	;; Jump to the initialization code.
	MOV	AX,CS
	SUB	AX,RELOC
	ADD	AX,CODE
	PUSH	AX
	MOV	AX,OFFSET CODE:HWINIT2
	PUSH	AX
	RET
RELOCPR	ENDP
RELOC	ENDS

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

CONTBL: DW      FEXIT            ;0  - Init. (Not used)
        DW      FEXIT            ;1  - Media check (Not used)
        DW      FEXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      FCMDERR          ;3  - Reserved. (Currently returns error)
        DW      FCON_READ        ;4  - Character read. (Destructive)
        DW      FCON_RDND        ;5  - Character read. (Non-destructive)
        DW      FEXIT            ;6  - Return status. (Not used)
        DW      FCON_FLSH        ;7  - Flush Input buffer.
        DW      FCON_WRIT        ;8  - Character write.
        DW      FCON_WRIT        ;9  - Character write with Verify.
        DW      FCON_WRST        ;10 - Character write status.
        DW      FEXIT            ;11 - Flush output buffer. (Not used.)
        DW      FEXIT            ;12 - IO Control.

AUXTBL: DW      FEXIT            ;0  - Init. (Not used)
        DW      FEXIT            ;1  - Media check (Not used)
        DW      FEXIT            ;2  - Get Bios Parameter Block (Not used)
        DW      FCMDERR          ;3  - Reserved. (Returns an error)
        DW      FAUX_READ        ;4  - Character read. (Destructive)
        DW      FAUX_RDND        ;5  - Character read. (Non-destructive)
        DW      FEXIT            ;6  - Return status. (Not used)
        DW      FAUX_CLR         ;7  - Flush Input buffer.
        DW      FAUX_WRIT        ;8  - Character write.
        DW      FAUX_WRIT        ;9  - Character write with verify.
        DW      FAUX_WRST        ;10 - Character write status.
        DW      FEXIT            ;11 - Flush output buffer. (Not used.)
        DW      FEXIT            ;12 - IO Control.

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

PRNTBL: DW      FEXIT            ;0  - (Not used)
        DW      FEXIT            ;1  - (Not used)
        DW      FEXIT            ;2  - Block (Not used)
        DW      FCMDERR          ;3  - Reserved. (currently returns error)
        DW      FEXIT            ;4  - (Not used)
        DW      FBUS_EXIT        ;5  - (Not used, returns busy flag.)
        DW      FEXIT            ;6  - (Not used)
        DW      FEXIT            ;7  - (Not used)
        DW      FPRN_WRT         ;8  - Character write.
        DW      FPRN_WRT         ;9  - Character write with verify.
        DW      FPRN_STA         ;10 - Character write status.
        DW      FEXIT            ;11 - (Not used.)
        DW      FEXIT            ;12 - IO Control.

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
; Auxilary interrupt routine for processing I/O packets.
;

AUX_INT:
        PUSH    BX
        MOV     BX,OFFSET AUXTBL
        JMP     SHORT FENTRY

;
; Printer interrupt routine for processing I/O packets.
;

PRN_INT:
        PUSH    BX
        MOV     BX,OFFSET PRNTBL
        JMP     SHORT FENTRY

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

;
; Console interrupt routine for processing I/O packets.
;

CON_INT:
        PUSH    BX
        MOV     BX,OFFSET CONTBL

;;; Fast version of ENTRY for character devices.
;;; Most registers used in ENTRY are for block devices.
;;; Fast version skips saving/setting such registers.

FENTRY:
	PUSH	AX
	PUSH	SI
	PUSH	DS
	PUSH	ES
	MOV	AX,CS
	MOV	DS,AX
	LES	SI,[PTRSAV]
	MOV	AL,ES:[SI.CMD]
	CMP	AL,12
	JA	FCMDERR
	CBW
	ADD	AX,AX
	ADD	BX,AX
	JMP	[BX]
FEXIT:
	MOV	AH,1		; Done
FEXIT1:
	MOV	ES:[SI.STATUS],AX
	POP	ES
	POP	DS
	POP	SI
	POP	AX
	POP	BX
FEXITR	PROC	FAR
	RET
FEXITR	ENDP
FBUS_EXIT:
	MOV	AH,3		; Busy + done
	JMP	FEXIT1
FCMDERR:
	MOV	AL,3
FERR_EXIT:
	MOV	AH,81H		; Error + done
	JMP	FEXIT1

        PAGE
        SUBTTL  Main console I/O section.

	; Table from DOSMES.ASM except *F8
	; Must be sorted by key code
KEYCODELIST LABEL BYTE
	DB	62H			; F.1
        DB      "S"                     ; F1 Copy one char
	DB	63H			; F.2
        DB      "T"                     ; F2 Copy to char
	DB	64H			; F.3
        DB      "U"                     ; F3 Copy line
	DB	65H			; F.4
        DB      "W"                     ; F5 Skip to char
	DB	66H			; F.5
        DB      "J"                     ; ERASE Reedit line (new template)
	DB	67H			; F.6
        DB      "Z"                     ; ^Z inserter
	DB	68H			; F.7
        DB      "R"                     ; GRAY Escape character
	DB	69H			; F.8
        DB      "E"                     ; SHIFT ERASE Kill line (no change in template)
	DB	3BH			; Left
        DB      "D"                     ; LEFT Backspace
	DB	3CH			; Right
        DB      "S"                     ; F1 Copy one char
	DB	38H			; INS
        DB      "P"                     ; BLUE Enter insert mode
	DB	39H			; DEL
        DB      "V"                     ; F4 Skip one char
	DB	255			; End
	DB	"R"			;

;;; Default is that function keys are converted to escape sequences.
;;; PC DOS like mode is that they are NUL and key code sequences.
;;; ESC F10 switches the mode.
CON_BUF	DB	0		; Length
	DB	?		; Buffer
	DB	27		; ESC or NUL

;
; Console keyboard handler.
;

CISTAT:
	MOV	BX,OFFSET CON_BUF
	MOV	AL,[BX]
	TEST	AL,AL
	JNE	CISTAT_XLAT
	MOV	AH,1
	INT	18H
	TEST	BH,BH
	JE	CISTAT_RET	; ZF=1
	MOV	AH,0
	INT	18H
	MOV	BX,OFFSET CON_BUF
	TEST	AL,AL
	JNE	CISTAT_1BYTE
	MOV	AL,27		; ESC
	CMP	AH,6BH		; F10
	JNE	CISTAT_NOTTOGGLE
	CMP	BYTE PTR [BX+1],AL
	JNE	CISTAT_NOTTOGGLE
	;; Toggle mode
	XOR	BYTE PTR [BX+2],AL ; Switch mode
	TEST	AL,AL		; ZF=0
CISTAT_1BYTE:
	;; 1-byte ZF=0
	MOV	BYTE PTR [BX],1
	MOV	[BX+1],AL
CISTAT_RET:
	RET
CISTAT_NOTTOGGLE:
	CMP	BYTE PTR [BX+2],AL
	JNE	CISTAT_KEYCODEMODE
	;; Key code conversion: ESC, alphabet
	MOV	BX,OFFSET KEYCODELIST-2
CISTAT_LOOP:
	INC	BX
	INC	BX
	CMP	AH,[BX]
	JB	CISTAT_NOT_MATCH
	JNE	CISTAT_LOOP
	MOV	AH,[BX+1]
	MOV	BX,OFFSET CON_BUF
CISTAT_KEYCODEMODE:
	;; PC DOS compatible: NUL, keycode
	SUB	AL,27-2		; ZF=0
	MOV	[BX],AX		; Second byte
CISTAT_XLAT:			; ZF=0
	XLAT
	RET
CISTAT_NOT_MATCH:
	CMP	AL,AL		; ZF=1
	RET

;
; Get a character from the buffer queue.
;

CINP:   CALL    CISTAT          ;Check for character ready in queue.
        JZ      CINP            ;Cycle until one ready.
	DEC	BYTE PTR [BX]
        RET

;
; Console read non-destructive.
;

FCON_RDND:
        CALL    CISTAT          ;See if character ready.
        JZ      CON_RDN2        ;No, return busy signal.
CON_RDN1:
	MOV	ES:[SI.MEDIA],AL
        JMP     FEXIT
CON_RDN2:
        JMP     FBUS_EXIT

;
; Console destructive read.
;

FCON_READ:
	PUSH	CX
	PUSH	DI
	MOV	CX,ES:[SI.COUNT]
	LES	DI,ES:[SI.TRANS]
CON_READ:
        CALL    CINP            ;Get character.
        STOSB                   ;Save it in users buffer.
        LOOP    CON_READ        ;Loop until CX is exhausted.
	MOV	ES,WORD PTR [PTRSAV+2]
	POP	DI
	POP	CX
        JMP     FEXIT

;
; Console flush routine. (ctrl-c, ctrl-f, or ctrl-s inspired)
;

FCON_FLSH:
	MOV	BYTE PTR [CON_BUF],0
        JMP     FEXIT

;
; Console output status routine.
;

FCON_WRST:
        JMP     FEXIT            ;Yes, normal exit.

;
; Console output routine.
;

FCON_WRIT:
	MOV	BX,ES:[SI.COUNT]
	LES	SI,ES:[SI.TRANS]
CON_WRI1:
        LODS    BYTE PTR ES:[SI]
IF      ANSI
        CALL    CONOUT          ;Call ansi driver.
        ENDIF
IFE     ANSI
        CALL    OUTCHR
        ENDIF
	DEC	BX
	JNE	CON_WRI1
	LES	SI,[PTRSAV]
        JMP     FEXIT

;
; Console character output routine.
;

CURLIN	DW	0
CURCOL	DB	0
DBCHR	DB	0

OUTCHR:
	PUSH	AX
	PUSH	DX
	PUSH	BX
	PUSH	DS
	MOV	BX,0A000H	; Text VRAM segment
	MOV	DS,BX
	MOV	BX,OFFSET DBCHR
	CMP	BYTE PTR CS:[BX],0
	JNE	OUTCHR_2ND
	CMP	AL,81H
	JB	OUTCHR_SIN
	CMP	AL,0A0H
	JB	OUTCHR_1ST
	CMP	AL,0E0H
	JB	OUTCHR_SIN
	CMP	AL,0EFH		; Shift_JIS EFFC => JIS X 0208 7E7E
	JA	OUTCHR_SIN
	SUB	AL,0E0H-0A0H	; 81H-AFH
OUTCHR_1ST:
	SHL	AL,1		; 02H-5EH
	MOV	CS:[BX],AL
	JMP	OUTCHR_EXIT
OUTCHR_2ND:
	MOV	AH,CS:[BX]
	MOV	BYTE PTR CS:[BX],0
	CMP	AL,40H
	JB	OUTCHR_SIN
	CMP	AL,7FH
	JB	OUTCHR_2ND1
	CMP	AL,80H
	JB	OUTCHR_SIN
	CMP	AL,0FDH
	JNB	OUTCHR_SIN
	DEC	AX		; 40H-FBH
OUTCHR_2ND1:
	SUB	AX,11FH		; 0121H-5EDCH
	CMP	AL,7FH
	JB	OUTCHR_2ND2
	ADD	AX,0A2H		; 0221H-5F7EH
OUTCHR_2ND2:
	XCHG	AH,AL
	JMP	SHORT OUTCHR_WRITE
OUTCHR_BELL:
	MOV	AH,17H		; Start beep
	INT	18H
	XOR	AX,AX
OUTCHR_BELLLOOP:
	DEC	AX
	JNE	OUTCHR_BELLLOOP
	MOV	AH,18H		; Stop beep
	INT	18H
	JMP	OUTCHR_EXIT
OUTCHR_LF:
	CALL	OUTCHR_LFP
	JMP	SHORT OUTCHR_WRITE1
OUTCHR_BS:
	DEC	CS:[CURCOL]
	JNS	OUTCHR_WRITE1
OUTCHR_CR:
	MOV	CS:[CURCOL],0
	JMP	SHORT OUTCHR_WRITE1
OUTCHR_SIN:
	CMP	AL,7
	JE	OUTCHR_BELL
	CMP	AL,8
	JE	OUTCHR_BS
	CMP	AL,10
	JE	OUTCHR_LF
	CMP	AL,13
	JE	OUTCHR_CR
	MOV	AH,0
OUTCHR_WRITE:
	MOV	BL,80
	CMP	AH,1
	ADC	BL,-1
	CMP	CS:[CURCOL],BL
	JB	OUTCHR_WRITE2
	SHR	BL,1
	JNC	OUTCHR_WRITE3
	MOV	BX,CS:[CURLIN]
	MOV	WORD PTR DS:[BX+79*2],' ' ; Character
	MOV	BYTE PTR DS:[BX+1000H+79*2],0E1H ; Attributes
OUTCHR_WRITE3:
	MOV	CS:[CURCOL],0
	CALL	OUTCHR_LFP
OUTCHR_WRITE2:
	MOV	BL,CS:[CURCOL]
	INC	CS:[CURCOL]
	MOV	BH,0
	ADD	BX,BX
	ADD	BX,CS:[CURLIN]
	MOV	DS:[BX],AX	; Character
	MOV	BYTE PTR DS:[BX+1000H],0E1H ; Attributes
	ADD	AH,80H
	CMP	AH,80H
	JA	OUTCHR_WRITE2
OUTCHR_WRITE1:
	MOV	DL,CS:[CURCOL]
	MOV	DH,0
	CMP	DL,80
	ADC	DL,-1
	ADD	DX,DX
	ADD	DX,CS:[CURLIN]
	MOV	AH,13H		; Set cursor position
	INT	18H
OUTCHR_EXIT:
	POP	DS
	POP	BX
	POP	DX
	POP	AX
        RET
OUTCHR_LFP:
	MOV	BX,CS:[CURLIN]
	ADD	BX,80*2
	CMP	BX,80*2*25
	JB	OUTCHR_LFP_OK
	;; Scroll up
	XOR	BX,BX
OUTCHR_LFP_LOOP:
	MOV	DX,DS:[BX+80*2]	; Character
	MOV	DS:[BX],DX
	MOV	DL,DS:[BX+1000H+80*2] ; Attributes
	MOV	DS:[BX+1000H],DL
	INC	BX
	INC	BX
	CMP	BX,80*2*24
	JB	OUTCHR_LFP_LOOP
OUTCHR_LFP_LOOP2:
	MOV	WORD PTR DS:[BX],' ' ; Character
	MOV	BYTE PTR DS:[BX+1000H],0E1H ; Attributes
	INC	BX
	INC	BX
	CMP	BX,80*2*25
	JB	OUTCHR_LFP_LOOP2
	RET
OUTCHR_LFP_OK:
	MOV	CS:[CURLIN],BX
	RET

IFE ANSI
INT29H:
        CALL    OUTCHR
	IRET
ENDIF

        PAGE

IF      ANSI

        SUBTTL  ANSI interface section.

;
;ANSI Info and routines. ANSI driver implemented as a finite state automata
;This ANSI driver translates the ANSI standard escape sequences into the
; Zenith Escape sequences used on the Zenith(Heath) Z(H)-19 terminal.
;This is not a full implementation of ANSI, but rather a minimal implementation
; which implements all of the necessary ANSI functions.
;

ESC     EQU     1BH             ;Escape character used in this implementation.
STATE   DW      ST1             ;Current ANSI character state.
PRMPNT  DW      PARMS           ;Current parameter pointer.
PARMS   DB      0,0,0,0,0,0,0   ;Allow for up to eight parameters.
LASTPRM DB      0               ;With this being the eight one.

CMDTABL DB      'A'             ;Cursor up.  "esc","[",#,"A"
        DW      CUU
        DB      'B'             ;Cursor down. "esc","[",#,"B"
        DW      CUD
        DB      'C'             ;Cursor forward. "esc","[",#,"C"
        DW      CUF
        DB      'D'             ;Cursor back. "esc","[",#,"D"
        DW      CUB
        DB      'H'             ;Direct cursor posit. "esc","[",x,y,"H"
        DW      CUP
        DB      'J'             ;Erase. "esc","[",code,"J"
        DW      ED
        DB      'K'             ;Erase in line. "esc","[",code,"K"
        DW      EL
        DB      'f'             ;Direct cursor posit. "esc","[",x,y,"f"
        DW      CUP
        DB      'm'             ;Special video mode. "esc","[",code,"m"
        DW      SGR
        DB      's'             ;Save cursor posit. "esc","[","s"
        DW      PSCP
        DB      'u'             ;Move cursor to saved. "esc","[","u"
        DW      PRCP
        DB      00              ;End of table.

;
; ANSI console output driver.
;

CONOUT: MOV     DI,OFFSET STATE ;Retrieve current ansi state.
        JMP     [DI]            ;Jump to it.

;
; State one (1).
;   Looks for an Escape character.
;

ST1:    CMP     AL,ESC          ;See if this the first character is ESC.
        JNZ     OUTCHR          ;No, treat as regular character output.
        MOV     WORD PTR [DI],OFFSET ST2        ;Yes, setup state two.
        RET

;
; State two (2).
;   Looks for the "[" character.
;

ST2:    CMP     AL,'['          ;See if a valide state two.
        JNZ     OUTCHR          ;No, treat as regular charcter
        MOV     BX,OFFSET PARMS ;Yes, get parameter pointer.
        MOV     WORD PTR [PRMPNT],BX    ;Setup in pointer index.
        MOV     WORD PTR [BX],0 ;Clear first entry.
        MOV     WORD PTR [DI],OFFSET ST3;Setup for state three.
        RET

;
; State three (3).
;   Entered one or more times for parameter passing.
;

ST3:    CMP     AL,';'          ;Look for decimal # seperator.
        JNZ     ST3A            ;No check phase A.
        INC     WORD PTR [PRMPNT]       ;Yes, incr. pointer to next param.
        MOV     AX,OFFSET LASTPRM       ;Check for outside parameter list.
        CMP     [PRMPNT],AX
        JBE     RETST3          ;Yes, proceed with next parameter.
        MOV     [PRMPNT],AX     ;No, treat as extentsion to old.
RETST3: MOV     DI,[PRMPNT]     ;Setup for next parameter.
        MOV     BYTE PTR [DI],0 ;Pre-Initialize it to zero.
        RET

;
; State three A (3A).
;   Check for a ascii digit.
;

ST3A:   CMP     AL,'0'          ;Check for ASCII digit.
        JB      ST3B            ;No, check for seconday command character.
        CMP     AL,'9'          ;Still checking for ASCII digit.
        JA      ST3B            ;No, it must be a secondary.
        SUB     AL,'0'          ;Convert to binary.
        MOV     DI,[PRMPNT]     ;Get the current parameter pointer.
        XCHG    [DI],AL         ;Get existing #.
        MOV     AH,10           ;Scale by 10.
        MUL     AH
        ADD     [DI],AL         ;Add to new digit.
        RET

;
; State three B (3B).
;   Wasn't a ascii digit, so check for secondary command.
;

ST3B:   MOV     [DI],OFFSET ST1         ;Preset STATE to state 1 just in case.
        MOV     DI,OFFSET PARMS-1       ;Get pointer to start of parameters.
        MOV     [PRMPNT],DI             ;Save it in Parameter pointer.
        MOV     DI,OFFSET CMDTABL-3     ;Get start of Secondary command table.

ST3B1:  ADD     DI,3            ;Update Command table pointer.
        CMP     BYTE PTR [DI],0 ;Check for end of table.
        JNZ     ST3B2           ;No, continue processing.
        JMP     OUTCHR          ;Yes, treat as regular character.
ST3B2:  CMP     AL,[DI]         ;Check for valid. command.
        JNZ     ST3B1           ;No, keep checking.
        JMP     [DI+1]          ;Yes, transfer to that secondary command.

;
; Get binary parameter from storage and return a one if = 0
;

GETONE: CALL    GETPARM         ;Get parameter form list.
        OR      AL,AL           ;Verify for non-zero.
        JNZ     GETRET          ;Good, then return to caller.
        INC     AL              ;Bad, make it at least a one.
GETRET: CBW                     ;Sign extend AL.
        MOV     CX,AX           ;Copy of it to CX.
        RET

GETPARM:INC     WORD PTR [PRMPNT]       ;Increment parameter pointer.
GOTPARM:MOV     DI,[PRMPNT]     ;Get parameter pointer.
        MOV     AL,[DI]         ;Get parameter value.
        RET

;
; Send escape, character sequence.
;

OUTESC: MOV     AL,ESC          ;Send escape character.
        CALL    OUTCHR
        MOV     AL,BL           ;Send follow character.
        JMP     OUTCHR

;
; Cursor Positioning routines.
;

CUU:    MOV     BL,'A'          ;Cursor up.
        JMP     SHORT CURPOS
CUD:    MOV     BL,'B'          ;Cursor down.
        JMP     SHORT CURPOS
CUF:    MOV     BL,'C'          ;Cursor forward.
        JMP     SHORT CURPOS
CUB:    MOV     BL,'D'          ;Cursor back.

CURPOS: CALL    GETONE          ;Get number of positions to move into CX.
MOVCUR: CALL    OUTESC          ;Send escape, command characters.
        LOOP    MOVCUR          ;Keep moving until done.
        RET

;
; Direct cursor positioning routine.
;

CUP:    CALL    GETONE          ;Get X position.
        MOV     DX,AX           ;Save in DX.
        CALL    GETONE          ;Get Y position.
        MOV     BL,'Y'
        CALL    OUTESC          ;Send escape, "Y" sequence.
        MOV     AL,DL
        ADD     AL,' '-1        ;Convert binary to Character.
        CALL    OUTCHR          ;Send X posit.
        MOV     AL,CL
        ADD     AL,' '-1        ;Convert binary to Character.
        JMP     OUTCHR          ;Send Y posit.

;
; Erase all/part of screen.
;

ED:     CALL    GETPARM         ;Get trinary command type.
        MOV     BL,'b'
        DEC     AL              ;See if erase from begining of screen.
        JZ      ED1             ;Yes, perform ZDS function.
        MOV     BL,'E'
        DEC     AL              ;See if erase from end of screen.
        JZ      ED1             ;Yes, perform ZDS function.
        MOV     BL,'J'          ;Now we assume erase whole screen.
ED1:    JMP     OUTESC

;
; Erase all/part of a line.
;

EL:     CALL    GETPARM         ;Get trinary command type.
        MOV     BL,'o'
        DEC     AL              ;See if erase from begining of line.
        JZ      EL1             ;Yes, perform ZDS function.
        MOV     BL,'l'
        DEC     AL              ;See if erase whole line.
        JZ      EL1             ;Yes, perform ZDS function.
        MOV     BL,'K'          ;Now we assume erase to end of line.
EL1:    JMP     OUTESC

;
; Special video modes.
;

SGR:    CALL    GETPARM         ;Get trinary command type.
        MOV     BL,'p'
        CMP     AL,7            ;See if enter reverse video mode.
        JZ      SGR2            ;Yes, perform ZDS function.
        MOV     BL,'q'
        OR      AL,AL           ;See if exit reverse video mode.
        JNZ     SGR3            ;No, ignore.
SGR2:   CALL    OUTESC
SGR3:   RET

;
; Save / restore cursor position.
;

PSCP:   MOV     BL,'j'          ;Set save cursor posit. mode.
        JMP     OUTESC

PRCP:   MOV     BL,'k'          ;Restore last cursor save.
        JMP     OUTESC

        ENDIF


        PAGE
        SUBTTL  Printer buffer handler.

;
; Printer status routine.
;

FPRN_STA:
	MOV	AH,12H
	INT	1AH
	TEST	AH,1
	JNE	FPRN_EXIT
	JMP	FBUS_EXIT

;
; Printer write routine.
;

FPRN_WRT:
	PUSH	CX
	PUSH	DX
	MOV	CX,ES:[SI.COUNT]
	LES	SI,ES:[SI.TRANS]
PRN_WR1:LODS    BYTE PTR ES:[SI];Get a data byte.
	MOV	AH,11H
	INT	1AH
	TEST	AH,3
	LOOPE	PRN_WR1
	LES	SI,[PTRSAV]
	JE	PRN_WR2
	INC	CX
	SUB	ES:[SI.COUNT],CX
PRN_WR2:
	POP	DX
	POP	CX
FPRN_EXIT:
	JMP	FEXIT

        PAGE
        SUBTTL  Auxilary I/O routines.

AUX_BUF	DW	0
AUX_DAT	DB	32 DUP (?)

;
; Status routine for Auxilary port.
;

AISTAT: MOV     AX,[AUX_BUF]
        TEST    AH,AH
        JNZ     AISTA9          ;Character already waiting.
	PUSH	CX
	MOV	AH,6		; Get status
	INT	19H
	TEST	AH,2
        JZ      AISTA8          ;Still none waiting.
	MOV	AH,4		; Receive
	INT	19H
	MOV	AL,CH
	MOV	AH,1
	MOV	[AUX_BUF],AX
	TEST	AX,AX
AISTA8:
	POP	CX
AISTA9:
        RET

;
; Auxilary port read.
;

AIN:    CALL    AISTAT          ;Get status and/or char.
        JZ      AIN             ;Cycle until one is ready.
	MOV	BYTE PTR [AUX_BUF+1],0
        RET

;
; Write routine for Auxilary port.
;

AOUT:
	PUSH	CX
	MOV	AH,3		; Send
	INT	19H
	POP	CX
        RET

;
; Non-Destructive Auxilary read routine.
;

FAUX_RDND:
        CALL    AISTAT          ;Get status and copy of char. waiting if any.
        JZ      AUX_RDN2        ;No character waiting, exit.
        JMP     CON_RDN1
AUX_RDN2:
        JMP     FBUS_EXIT

;
; Destructive Auxilary read routine.
;

FAUX_READ:
	PUSH	CX
	PUSH	DI
	MOV	CX,ES:[SI.COUNT]
	LES	DI,ES:[SI.TRANS]
AUX_READ:
        CALL    AIN             ;Get data character.
        STOSB                   ;Save it through DI.
        LOOP    AUX_READ        ;Cycle until user buffer full.
	MOV	ES,WORD PTR [PTRSAV+2]
	POP	DI
	POP	CX
        JMP     FEXIT

;
; Auxilary clear type a head.
;

FAUX_CLR:
	MOV	BYTE PTR [AUX_BUF+1],0
        JMP     FEXIT

;
; Auxilary write port status.
;

FAUX_WRST:
        JMP     FEXIT

;
; Auxilary write.
;

FAUX_WRIT:
	PUSH	DX
	MOV	BX,ES:[SI.COUNT]
	LES	SI,ES:[SI.TRANS]
AUX_WRI1:
        LODS    BYTE PTR ES:[SI]        ;Get char. from users buffer.
        CALL    AOUT            ;Send it to device.
	DEC	BX
	JNE	AUX_WRI1
	LES	SI,[PTRSAV]
	POP	DX
        JMP     FEXIT

        PAGE
        SUBTTL  Date/Time Routines.

TIM	STRUC
TIM_DAYS  DW    ?               ;Number of days since 1-1-80.
TIM_MINS  DB    ?               ;Minutes.
TIM_HRS   DB    ?               ;Hours.
TIM_HSEC  DB    ?               ;Hundreths of a second.
TIM_SECS  DB    ?               ;Seconds.
TIM	ENDS

RTCBUF	LABEL	BYTE
RTCYEAR	DB	?
RTCMOWE	DB	?
RTCDAYS	DB	?
RTCHRS	DB	?
RTCMINS	DB	?
RTCSECS	DB	?

;
; Time write routine.
;

AAM_N	MACRO	N
	DB	0D4H,N
ENDM

AAD_N	MACRO	N
	DB	0D5H,N
ENDM

TIM_WRT:
	CMP	CX,6
	JAE	TIM_WRT1
	MOV	AL,10
	JMP	ERR_EXIT
TIM_WRT_LODBCD:
	LODS	BYTE PTR ES:[SI]
	AAM
	AAD_N	10H
	RET
TIM_WRT1:
	XOR	DX,DX
	MOV	SI,DI
	LODS	WORD PTR ES:[SI] ; MOV AX,ES:[SI.TIM_DAYS]
	ADD	AX,1401		; 1980-01-01 => 1976-03-01
	PUSH	AX
	INC	AX
	MOV	BX,7
	DIV	BX
	MOV	BL,DL		; Week
	CWD
	POP	AX
	MOV	DI,365*4+1
	DIV	DI
	MOV	CL,2
	SHL	AX,CL
	SHR	DI,CL		; DI=365
	XCHG	AX,CX
	XCHG	AX,DX
	CWD
	DIV	DI
	CMP	AL,4
	JB	TIM_WRT2
	ADD	DX,DI
TIM_WRT2:
	ADC	CX,AX
	MOV	AL,5
	MUL	DX
	ADD	AX,153*3+2
	MOV	DL,153
	DIV	DL
	CMP	AL,12
	JBE	TIM_WRT3
	SUB	AL,12
	INC	CX
TIM_WRT3:
	XCHG	AL,AH
	PUSH	AX
	MOV	AL,BL
	AAD_N	10H
	MOV	[RTCMOWE],AL
	POP	AX
	AAM_N	5
	MOV	AL,AH
	INC	AX
	AAM
	AAD_N	10H
	MOV	[RTCDAYS],AL
	XCHG	AX,CX
	AAM			; 5-104 -> 0:5-10:4
	AAD_N	10H
	ADD	AL,75H		; 05H-A4H ->
	DAA			; 80H-79H
	MOV	BX,OFFSET RTCBUF
	MOV	[BX],AL		; [RTCYEAR]
	CALL	TIM_WRT_LODBCD	; ES:[SI.TIM_MINS]
	MOV	[RTCMINS],AL
	CALL	TIM_WRT_LODBCD	; ES:[SI.TIM_HRS]
	MOV	[RTCHRS],AL
	INC	SI
	CALL	TIM_WRT_LODBCD	; ES:[SI.TIM_SECS]
	MOV	[RTCSECS],AL
	PUSH	CS
	POP	ES
	MOV	AH,1		; Set RTC
	INT	1CH
        JMP     EXIT

;
; Time read routine.
;

TIM_RED:
	CMP	CX,6
	JAE	TIM_RED1
	MOV	AL,11
	JMP	ERR_EXIT
TIM_RED1:
	PUSH	ES
	PUSH	CS
	POP	ES
	MOV	BX,OFFSET RTCBUF
	MOV	AH,0		; Get RTC
	INT	1CH
	POP	ES
	MOV	SI,BX
	LODSB			; MOV AL,[RTCYEAR]
	SUB	AL,80H		; 80H-79H ->
	DAS			; 00H-99H
	AAM_N	10H
	AAD
	XCHG	AX,CX
	LODSB			; MOV AL,[RTCMOWE]
	SUB	AL,3*10H
	JNB	TIM_RED2
	ADD	AL,12*10H
TIM_RED2:
	XCHG	AX,CX
	SBB	AL,-4		; 0-99 -> 3-103
	XCHG	AX,BX
	MOV	AX,365
	MUL	BX
	SHR	BX,1
	SHR	BX,1
	ADD	BX,AX
	XCHG	AX,CX
	AAM_N	10H
	MOV	AL,153
	MUL	AH
	INC	AX
	INC	AX
	MOV	CX,5
	DIV	CX
	ADD	BX,AX
	LODSB			; MOV AL,[RTCDAYS]
	AAM_N	10H
	AAD
	SUB	AX,1+1401
	ADD	AX,BX
	STOSW			; MOV ES:[DI.TIM_DAYS],AX
	MOV	AL,[RTCMINS]
	AAM_N	10H
	AAD
	STOSB			; MOV ES:[DI.TIM_MINS],AL
	LODSW			; MOV AL,[RTCHRS]
	AAM_N	10H
	AAD
	STOSW			; MOV WORD PTR ES:[DI.TIM_HRS],AX
	LODSB			; MOV AL,[RTCSECS]
	AAM_N	10H
	AAD
	STOSB			; MOV ES:[DI.TIM_SECS],AL
        JMP     EXIT

IF 0
;;; CLOCK Test code
TESTCODE:
	MOV	AX,351CH
	INT	21H
	PUSH	ES
	PUSH	BX
	PUSH	CS
	POP	DS
	PUSH	CS
	POP	ES
	MOV	DX,OFFSET TESTHANDLER
	MOV	AX,251CH
	INT	21H
	MOV	WORD PTR [TESTIOR.TRANS+0],OFFSET TESTBUF
	MOV	WORD PTR [TESTIOR.TRANS+2],CS
	MOV	WORD PTR [TESTIOW.TRANS+0],OFFSET TESTBUF
	MOV	WORD PTR [TESTIOW.TRANS+2],CS
	MOV	AL,59
	MOV	BX,OFFSET TESTSRC.TIM_SECS
	CALL	TESTLP
	MOV	AL,59
	MOV	BX,OFFSET TESTSRC.TIM_MINS
	CALL	TESTLP
	MOV	AL,23
	MOV	BX,OFFSET TESTSRC.TIM_HRS
	CALL	TESTLP
	MOV	AX,36524	; 2079-12-31
	MOV	CL,0		; Sunday
TESTLL:	MOV	[TESTSRC.TIM_DAYS],AX
	CALL	TESTSB
	MOV	AL,BYTE PTR [TESTDATA+1]
	AND	AL,0FH
	CMP	AL,CL
	JNE	BAD2
	SUB	CL,1
	SBB	AL,AL
	AND	AL,7
	ADD	CL,AL
	MOV	AX,[TESTSRC.TIM_DAYS]
	SUB	AX,1
	JAE	TESTLL
	MOV	AH,2
	MOV	DL,'O'
	INT	21H
	POP	DX
	POP	DS
	MOV	AX,251CH
	INT	21H
	MOV	AX,4C00H
	INT	21H
BAD2:	CALL	E
TESTLP:	MOV	[BX],AL
	PUSH	BX
	CALL	TESTSB
	POP	BX
	MOV	AL,[BX]
	SUB	AL,1
	JAE	TESTLP
	RET
TESTSB:	MOV	SI,OFFSET TESTSRC
	MOV	DI,OFFSET TESTBUF
	CLD
	MOVSW
	MOVSW
	MOVSW
	MOV	BX,OFFSET TESTIOW
	CALL	GO
	MOV	BX,OFFSET TESTIOR
	CALL	GO
	MOV	SI,OFFSET TESTSRC
	MOV	DI,OFFSET TESTBUF
	CMPSW
	JNE	BAD1
	CMPSW
	JNE	BAD1
	CMPSW
	JNE	BAD1
	RET
BAD1:	CALL	E
GO:	PUSH	CS
	CALL	STRATEGY
	PUSH	CS
	CALL	TIM_INT
	MOV	AX,[BX.STATUS]
	CMP	AH,1
	JE	OK
	CALL	E
E:	MOV	DX,OFFSET ERROR
	MOV	AH,9
	INT	21H
	MOV	AX,4C01H
	INT	21H
OK:	RET
TESTSRC	TIM	<0,0,0,0,0>
TESTBUF	TIM	<1,1,1,1,1>
TESTIOR	IODAT	<SIZE IODAT,0,4,0,,0,,6,0>
TESTIOW	IODAT	<SIZE IODAT,0,8,0,,0,,6,0>
ERROR	DB	'ERROR$'
TESTDATA DW	3 DUP (?)
TESTHANDLER:
	CMP	AH,0
	JE	TESTHANDLER1
	MOV	AX,ES:[BX+0]
	MOV	CS:[TESTDATA+0],AX
	MOV	AX,ES:[BX+2]
	MOV	CS:[TESTDATA+2],AX
	MOV	AX,ES:[BX+4]
	MOV	CS:[TESTDATA+4],AX
	IRET
TESTHANDLER1:
	MOV	AX,CS:[TESTDATA+0]
	MOV	ES:[BX+0],AX
	MOV	AX,CS:[TESTDATA+2]
	MOV	ES:[BX+2],AX
	MOV	AX,CS:[TESTDATA+4]
	MOV	ES:[BX+4],AX
	IRET
ENDIF

        PAGE
        SUBTTL  Drive Tables.


;
; MSDOS drive initialization tables and other what not.
;
;;; Supported format list:
;;; ID sector-size cyl spt head  (JX Japanese DOS FORMAT.COM switch)
;;; 2DD
;;; FF         512  40   8    2  /4 /8
;;; FE         512  40   8    1  /4 /8 /1
;;; FD         512  40   9    2  /4                 - PCjr PC DOS default
;;; FC         512  40   9    1  /4    /1
;;; FB         512  80   8    2     /8
;;; FA         512  80   8    1     /8 /1
;;; F9         512  80   9    2                     - JX Japanese DOS default
;;; F8         512  80   9    1        /1
;;; 2HD
;;; FE        1024  77   8    2  ---                - PC-98 DOS default
;;; F0         512  80  18    2  ---                - PS/2, the standard

DPB     STRUC

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

DPB     ENDS

DPBLIST	LABEL	DPB
DPB1232	DPB	<1024,1,1,2,192,1232,0FEH,2,8,2>
DPB1440	DPB	<512,1,1,2,224,2880,0F0H,9,18,2>
	DPB	<512,2,1,2,112,640,0FFH,1,8,2>
	DPB	<512,1,1,2,64,320,0FEH,1,8,1>
DPB360	DPB	<512,2,1,2,112,720,0FDH,2,9,2>
	DPB	<512,1,1,2,64,360,0FCH,2,9,1>
	DPB	<512,2,1,2,112,1280,0FBH,2,8,2>
	DPB	<512,2,1,2,112,640,0FAH,1,8,1>
DPB720	DPB	<512,2,1,2,112,1440,0F9H,3,9,2>
	DPB	<512,2,1,2,112,720,0F8H,2,9,1>

DPB2DD	DB	2,3,4,5,6,7,8,9
DPB2DDEND LABEL BYTE
DRVS	DB	4 DUP (?)
DRVMASK	EQU	3		; UA 0-3
DRV50	EQU	4		; 2D
DRV70	EQU	8		; 2DD
DRV10	EQU	16		; 2DD
DRV90	EQU	32		; 2HD
DRVF0	EQU	64		; 2HD
DRV30	EQU	128		; 2HD 300rpm
DRVTYP	DB	4 DUP (0)
DRVDA	DB	50H,70H,10H,90H,0F0H,30H
NDRVDA	EQU	6
DRVDAHD	EQU	3
DRVDA30	EQU	5
DRVDA50	EQU	0

DSK_INIT:
	MOV     AX,1
DSKNUNT	EQU	$-2
	MOV	SI,OFFSET INITTAB
        JMP     GET_BP5

LASTDPB	LABEL	WORD
INITTAB:
	DW	DPBLIST
	DW	DPBLIST
	DW	DPBLIST
	DW	DPBLIST

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
	MOV	AH,0
	CMP	AL,BYTE PTR [DSKNUNT]
	JB	MEDIA1
	JMP	BADRIV
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

DISKBIOS_DEF:
	PUSH	SI
	MOV	SI,OFFSET DPB1440
	CMP	DL,30H
	JB	DISKBIOS_DEF_2DD
	CMP	DL,33H
	JBE	DISKBIOS_DEF_GO
	MOV	SI,OFFSET DPB360
	CMP	DL,50H
	JB	DISKBIOS_DEF_2DD
	CMP	DL,53H
	JBE	DISKBIOS_DEF_GO
	MOV	SI,OFFSET DPB1232
	CMP	DL,90H
	JB	DISKBIOS_DEF_2DD
	CMP	DL,93H
	JBE	DISKBIOS_DEF_GO
	CMP	DL,0F0H
	JB	DISKBIOS_DEF_2DD
	CMP	DL,0F3H
	JBE	DISKBIOS_DEF_GO
DISKBIOS_DEF_2DD:
	MOV	SI,OFFSET DPB720
DISKBIOS_DEF_GO:
	CALL	DISKBIOS_SI_DPB
	POP	SI
	RET

DISKBIOS_SI_DPB:
	PUSH	BP
	PUSH	WORD PTR [SI.MEDIAID]
	PUSH	[SI.SECSIZE]
	MOV	BP,SP
	CALL	DISKBIOS_98
	LEA	SP,[BP+4]
	POP	BP
	RET

;;; PC    AL=nsectors ES:BX=address CH=cylinder CL=sector DH=head DL=drive
;;;       AH=2:read AH=3:write
;;; PC-98 BX=nbytes   ES:BP=address CL=cylinder DL=sector DH=head AL=drive
;;;       CH=sector-size(N)
;;; This routine: ES:DI=address [BP+0]=sector size [BP+2]=Media ID
DISKBIOS_98:
	PUSH	BP
	PUSH	CX
	PUSH	DX
	MOV	BX,[BP+0]	; Sector size
	SHL	BX,1		; BH bit0- 128,256,512,1024,2048,4096,8192,16384
DISKBIOS_SECSIZLOOP:
	INC	BX
	SHR	BH,1
	JNE	DISKBIOS_SECSIZLOOP
	DEC	BX
	XCHG	BL,CH
	XCHG	BL,CL
	XCHG	BL,DL
	PUSH	DX
	PUSH	AX
	MOV	AH,0
	MUL	WORD PTR [BP+0] ; Sector size
	MOV	DX,BX
	XCHG	AX,BX
	POP	AX
	MOV	AL,DL
	POP	DX
	NEG	AH
	ADD	AH,46H+2	; AH=2:READ 46H AH=3:WRITE 45H
	TEST	AL,50H
	JE	DISKBIOS_NEW
	JPO	DISKBIOS_NEW
	TEST	AL,0A0H
	JNE	DISKBIOS_NEW
	;; For 2D drive machines... not tested at all!
	SUB	AH,40H		; Old command READ 6 WRITE 5
	JMP	SHORT DISKBIOS_OLD
DISKBIOS_NEW:
	PUSH	AX
	PUSH	CX
	;; Seek
	TEST	AL,90H
	JS	DISKBIOS_NOT2D	; 2HD (>= 80H)
	JE	DISKBIOS_NOT2D	; 00H, 20H, 40H, 60H
	TEST	AL,60H
	JPO	DISKBIOS_NOT2D	; 30H (2HD 300rpm), 50H
	CMP	BYTE PTR [BP+2],0FCH
	JB	DISKBIOS_NOT2D
	ADD	CL,CL		; 2D access with 2DD drive
DISKBIOS_NOT2D:
	MOV	AH,10H		; SEEK
	INT	1BH
	POP	CX
	POP	BP
	JC	DISKBIOS_RET
	XCHG	AX,BP
DISKBIOS_OLD:
	MOV	BP,DI
	INT	1BH
DISKBIOS_RET:
	POP	DX
	POP	CX
	POP	BP
	RET

GET_BPB:
	CMP	AL,BYTE PTR [DSKNUNT]
	JB	GET_BPB_ALOK
BADRIV:
	MOV	AL,1
	JMP	ERR_EXIT
GET_BPB_ALOK:
	CBW
	XCHG	AX,SI
	MOV	AL,[SI+DRVS]
	TEST	AL,AL
	JE	BADRIV
	MOV	CH,NDRVDA*3
	MOV	BH,0
	MOV	BL,[SI+DRVTYP]
GET_BPB_TRYNEXT:
	MOV	CL,BL
	MOV	AH,4
	SHL	AH,CL
	TEST	AL,AH
	JNE	GET_BPB_TRY1
GET_BPB_INCBL:
	INC	BL
	CMP	BL,6
	SBB	AH,AH
	AND	BL,AH
	DEC	CH
	JNE	GET_BPB_TRYNEXT
	;; FAILED!
	MOV	SI,OFFSET DPBLIST ; Default DPB
	MOV	AH,1		; Error
	JMP	GET_BP4
GET_BPB_TRY1:
	CMP	BL,DRVDA50
	JE	GET_BPB_2D
	PUSH	AX
	PUSH	BX
	PUSH	CX
	AND	AL,3
	OR	AL,[BX+DRVDA]
	PUSH	AX
	MOV	AH,27H		; RECALIBRATE
	INT	1BH
	POP	AX
	MOV	DH,0		; Head 0
	MOV	AH,6AH		; READ ID
	INT	1BH
	MOV	DH,CH		; Sector-size
	POP	CX
	POP	BX
	POP	AX
	JC	GET_BPB_INCBL
	;; Sanity check
	PUSH	DX
	CMP	BL,DRVDAHD
	JB	GET_BPB_2DD
	CMP	BL,DRVDA30
	SBB	AH,AH		; -1 for 1M
	ADD	DH,AH
GET_BPB_2DD:
	CMP	DH,2		; 2:512B 3:1024B
	POP	DX
	JNE	GET_BPB_INCBL
GET_BPB_2D:
	MOV	[SI+DRVTYP],BL
	AND	AL,3
	OR	AL,[BX+DRVDA]
	MOV	SI,AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	DL,AL
	MOV	DH,0
	MOV	CX,1
	MOV	AX,201H
	CALL	DISKBIOS_DEF
	POP	DX
	POP	CX
	POP	BX
	JC	DISKERR2
GET_BP1:MOV     AL,ES:[DI+11+MEDIAID] ;Get diskettes media ID.
	TEST	AL,AL
	JNE	GET_BP2
	;; Old format might not have the DPB.
	MOV	AX,SI
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	DL,AL
	MOV	DH,0
	MOV	CX,2
	MOV	AX,201H
	CALL	DISKBIOS_DEF
	POP	DX
	POP	CX
	POP	BX
DISKERR2:
	JC	DISKERR
	MOV	AL,ES:[DI]	; Media ID in the FAT first byte
GET_BP2:
	AND	SI,3
	ADD	SI,SI
	LEA	DI,[SI+LASTDPB]
	MOV	AH,1
	CMP	BL,DRVDAHD
	JB	GET_BP3
	CMP	BL,DRVDA30
	SBB	SI,SI
	AND	SI,-(OFFSET DPB1440-OFFSET DPB1232)
	ADD	SI,OFFSET DPB1440
	CMP	AL,[SI.MEDIAID]
	JNE	GET_BP4
	JMP	SHORT GET_BPB_OK
GET_BP3:
	MOV	SI,OFFSET DPBLIST
	NOT	AL
	CMP	AL,OFFSET DPB2DDEND-OFFSET DPB2DD
	JAE	GET_BP4
	MOV	BX,OFFSET DPB2DD
	XLAT
	TEST	AL,AL
	JS	GET_BP4
	MOV	AH,SIZE DPB
	MUL	AH
	ADD	SI,AX
GET_BPB_OK:
	MOV	[DI],SI
	XOR	AX,AX
GET_BP4:MOV     AL,[SI.MEDIAID]

GET_BP5:LDS     BX,[PTRSAV]     ;Update I/O data packet.
        MOV     [BX.BPB1],AL    ;Media byte.
        MOV     [BX.BPB3],SI    ;DPB pointer.
        MOV     [BX.BPB3+2],CS  ;Code segment.
	TEST	AH,AH
	JNZ	GET_BP6
	MOV	AL,0
	JMP     EXIT
GET_BP6:MOV	AX,7
	JMP	ERR_EXIT
DISKERR:
	MOV	BX,OFFSET DISKERR_CODE
	MOV	CL,12
	SHR	AX,CL
	XLAT
	JMP	ERR_EXIT
DISKERR_CODE LABEL BYTE
	DB	12,12,12,12,12,12,2,0,12,12,12,4,8,6,12,8

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
	MOV	BL,2
        JMP     SHORT DSK_COM
DSK_WRV:
DSK_WRT:MOV	BL,3

DSK_COM:
	CMP	AL,BYTE PTR [DSKNUNT]
	JB	DSK_COM_ALOK
	JMP	BADRIV
DSK_COM_ALOK:
	;; Get DPB address.
	MOV	SI,3
	AND	SI,AX
	ADD	SI,SI
	MOV	SI,[SI+LASTDPB]
	CMP	AH,[SI.MEDIAID]
	JNE	GET_BP6
	;; Get drive (DA/UA).
	PUSH	BX
	MOV	BX,OFFSET DRVS
	MOV	AH,AL
	XLAT
	AND	AL,DRVMASK
	XCHG	AH,AL
	MOV	BX,OFFSET DRVTYP
	XLAT
	MOV	BX,OFFSET DRVDA
	XLAT
	OR	AL,AH
	POP	BX
	PUSH	AX
	PUSH	DI
	SHR	DI,1
	SHR	DI,1
	SHR	DI,1
	SHR	DI,1
	MOV	AX,ES
	ADD	AX,DI
	MOV	ES,AX
	POP	DI
	AND	DI,0FH
	POP	AX
RW_LOOP:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CALL	DISKRW
	POP	DX
	POP	CX
	POP	BX
	JNC	DISKRWDONE
	POP	BX
	JMP	DERROR
DISKRWDONE:
	POP	AX
	TEST	CX,CX
	JNE	RW_LOOP
        MOV     AL,0
        JMP	EXIT                    ;All done.
DISKRW:
	PUSH	BP
	MOV	BP,SP
	MOV	AX,[BP+4]
	XOR	DX,DX
	MOV	BX,[SI.SECTRK]
	DIV	BX
	SUB	BX,DX
	INC	DL
	MOV	CL,DL		; Sector
	XOR	DX,DX
	DIV	[SI.NHEADS]
	MOV	DH,DL		; Head
	MOV	CH,AL		; Cylinder
	MOV	AL,0
	SHR	AX,1
	SHR	AX,1
	OR	CL,AL
	MOV	DL,[BP+10]	; Drive
	MOV	AX,[BP+6]	; Number of sectors
	CMP	AX,BX
	JB	DISKRW_NSECOK
	MOV	AX,BX
DISKRW_NSECOK:
	MOV	BX,[SI.SECSIZE]
	CALL	DISKRW_GETBSEC
	CMP	AX,BX
	JB	DISKRW_BOK
	TEST	BX,BX
	JE	DISKRW_BHIT
	MOV	AX,BX
DISKRW_BOK:
	PUSH	AX
	MOV	AH,[BP+8]	; Command
	CALL	DISKBIOS_SI_DPB
	POP	DX
	JC	DISKRW_ERR
DISKRW_BDONE:
	ADD	[BP+4],DX
	SUB	[BP+6],DX
	MOV	AX,[SI.SECSIZE]
	MOV	CL,4
	SHR	AX,CL
	MUL	DX
	MOV	DX,ES
	ADD	DX,AX
	MOV	ES,DX
	CLC
DISKRW_ERR:
	POP	BP
	RET
DISKRW_BHIT:
	LEA	SP,[BP-14]
	;; Normally this module is loaded into segment 1E0H, segment
	;; 1A0H for 1024 byte sector is available for temporary use.
	PUSH	AX
	MOV	AX,[SI.SECSIZE]
	PUSH	AX
	PUSH	CX
	;; [BP-14]=Sector size
	MOV	[BP-14],AX
	;; [BP-12]=Media ID
	MOV	BL,[SI.MEDIAID]
	MOV	[BP-12],BL
	;; [BP-10]=CX
	MOV	[BP-10],CX
	;; [BP-8]=ES:DI
	MOV	[BP-8],DI
	MOV	[BP-6],ES
	;; [BP-4]=0
	MOV	WORD PTR [BP-4],0
	;; [BP-2]=CS-SECSIZE/16
	MOV	CL,4
	SHR	AX,CL
	MOV	BX,CS
	SUB	BX,AX
	MOV	[BP-2],BX
	POP	CX
	POP	BX
	POP	AX
	ASSUME	DS:NOTHING
	;; If number of sectors is more than 1, read/write the next
	;; part first to reduce time of waiting for a sector.
	PUSH	AX
	PUSH	SI
	DEC	AX
	JE	DISKRW_BHIT1
	INC	CX		; Next sector
	ADD	DI,BX		; Next offset
	CALL	DISKRW_BHIT_CALL
	JNC	DISKRW_BHIT1
DISKRW_BHIT_DONE:
	LES	DI,DWORD PTR [BP-8]
	MOV	CX,[BP-10]
	PUSH	CS
	POP	DS
	POP	SI
	POP	DX
	MOV	SP,BP
	JC	DISKRW_ERR
	JMP	DISKRW_BDONE
DISKRW_BHIT1:
	SHR	BX,1
	;; Read one sector to temporary memory and copy or
	;; copy one sector to temporary memory and write.
	CMP	BYTE PTR [BP+8],2 ; Read
	JE	DISKRW_BHIT2
	LDS	SI,DWORD PTR [BP-8]
	LES	DI,DWORD PTR [BP-4]
	MOV	CX,BX
	CLD
	REP	MOVSW
DISKRW_BHIT2:
	LES	DI,DWORD PTR [BP-4]
	MOV	CX,[BP-10]
	MOV	AL,1
	CALL	DISKRW_BHIT_CALL
	JC	DISKRW_BHIT_DONE
	CMP	BYTE PTR [BP+8],2 ; Read
	JNE	DISKRW_BHIT3
	LDS	SI,DWORD PTR [BP-4]
	LES	DI,DWORD PTR [BP-8]
	MOV	CX,BX
	CLD
	REP	MOVSW
DISKRW_BHIT3:
	CLC
	JMP	DISKRW_BHIT_DONE
DISKRW_BHIT_CALL:
	PUSH	BX
	MOV	AH,[BP+8]	; Command
	SUB	BP,14
	CALL	DISKBIOS_98
	LEA	BP,[BP+14]
	POP	BX
	RET
	ASSUME	DS:CODE

DISKRW_GETBSEC PROC NEAR
	PUSH	AX
	PUSH	CX
	MOV	AX,ES
	MOV	CL,4
	SHL	AX,CL
	ADD	AX,DI
	JE	DMA64K
	NEG	AX
	MOV	AL,0
	XCHG	AL,AH		; Remaining bytes / 256
	DIV	BH
	CBW			; Sector size must be < 32768
	MOV	BX,AX
DMA64K:
	POP	CX
	POP	AX
	RET
DISKRW_GETBSEC ENDP

        PAGE
        SUBTTL  Disk Error processing.

;
; Disk error routine.
;

DERROR: LDS     BX,CS:[PTRSAV]
        MOV     [BX.COUNT],0
        PUSH    CS
        POP     DS
	JMP	DISKERR

        PAGE
        SUBTTL  Initalization code and temporary work areas.

;
; Overlayed by MSDOS by SYSINIT.
;
DEVSTART LABEL WORD
	ASSUME	DS:NOTHING

MEMERR	DB	'LOAD ADDRESS ERROR',0
DSKERR	DB	'READ ERROR',0
FILEERR	LABEL BYTE
MSDOS_FILENAME DB 'MSDOS   SYS'
	DB	' NOT FOUND',0
NOFDD	DB	'NO FDD',0

DISKBIOSNOERR PROC NEAR
	PUSH	BP
	PUSH	[BP+11+10]	; Media ID
	PUSH	[BP+11]		; Sector size
	MOV	BP,SP
	CALL	DISKBIOS_98
	LEA	SP,[BP+4]
	POP	BP
	JC	DISKBIOSERR
	RET
DISKBIOSERR:
	MOV	SI,OFFSET DSKERR
ERRSTOP:
	MOV	DX,(0E1H SHL 8) OR ' '
	MOV	AH,16H		; Fill VRAM
	INT	18H
	MOV	AH,17H		; Start beep
	INT	18H
	MOV	AX,0A000H	; Text VRAM segment
	MOV	ES,AX
	XOR	DI,DI
	XOR	AX,AX
	CLD
ERRSTOP2:
	LODS	BYTE PTR CS:[SI]
	DB	0A8H		; TEST AL,immediate
ERRSTOP1:
	HLT			; 0F4H
	JE	ERRSTOP1
	STOSW
	JMP	ERRSTOP2
DISKBIOSNOERR ENDP

GETSEGDIFF PROC NEAR
	MOV	AX,CS
	SUB	AX,CODE
	RET
GETSEGDIFF ENDP

HWINIT:
	;; For debugging: EXE is runnable from DOS
	MOV	DL,30H
IFDEF TESTCODE
	JMP	TESTCODE
ENDIF
HWINIT2:
	CALL	GETSEGDIFF
	ADD	AX,STACK
	MOV	SS,AX
	MOV	SP,STACKSIZE

	;; Load MSDOS
	CALL	GETSEGDIFF
	ADD	AX,LAST
	MOV	BP,AX
	MOV	ES,AX
	XOR	DI,DI
	MOV	CX,1
	MOV	DH,0
	MOV	AX,201H
	PUSH	CS
	POP	DS
	CALL	DISKBIOS_DEF
	JC	DISKBIOSERR
	MOV	DI,ES:[DI+11]	; BPB Sector size
	MOV	SS,BP
	MOV	SP,DI
	XOR	BP,BP
	MOV	SI,OFFSET MSDOS_FILENAME
	JMP	RDR_START
FILENOTFOUND:
	MOV	SI,OFFSET FILEERR
	JMP	ERRSTOP
	INCLUDE	FIL_RDR.ASM
	;; Stack at the end of the DOS will be used until the SYSINIT
	;; moves the DOS to the FINAL_DOS_LOCATION.
	PUSH	ES
	POP	SS
	LEA	SP,[DI+STACKSIZE]

	CLD
	MOV	AX,CODE
	MOV	ES,AX
	ASSUME	ES:CODE
	MOV	BX,CS
	CMP	BX,AX
	JE	SEGOK
	JA	SEGMOVE
	MOV	SI,OFFSET MEMERR
	JMP	ERRSTOP
SEGMOVE:
	;; Move the driver part to proper segment
	MOV	DS,BX
	XOR	SI,SI
	XOR	DI,DI
	MOV	CX,OFFSET DEVSTART
	REP	MOVSB
SEGOK:
	PUSH	ES
	POP	DS
	ASSUME	DS:CODE

	;; Get number of drives
	PUSH	DX
	XOR	AX,AX
	MOV	ES,AX
	MOV	SI,OFFSET DRVS
	MOV	DX,ES:[55CH]
	MOV	BH,ES:[5AEH]
	MOV	BL,ES:[494H]
	XOR	CX,CX
	MOV	AX,1001H
DSK_INIT7:
	MOV	BYTE PTR [SI],CH
	TEST	AL,BH		; 2HD 300rpm support
	JE	DSK_INIT1
	OR	BYTE PTR [SI],DRV30
DSK_INIT1:
	TEST	AL,DL		; 2HD/2DD support
	JE	DSK_INIT2
	OR	BYTE PTR [SI],DRV90 OR DRV10
DSK_INIT2:
	CMP	BYTE PTR [SI],CH
	JNE	DSK_INIT8
	;; Old style
	TEST	AH,DL		; 2D support
	JE	DSK_INIT3
	OR	BYTE PTR [SI],DRV50
	JMP	SHORT DSK_INIT8
DSK_INIT3:
	TEST	AH,DH		; 2DD support
	JE	DSK_INIT4
	OR	BYTE PTR [SI],DRV70
DSK_INIT4:
	TEST	AH,BL		; 2HD support
	JE	DSK_INIT5
	OR	BYTE PTR [SI],DRVF0
DSK_INIT5:
	CMP	BYTE PTR [SI],CH
	JE	DSK_INIT6
DSK_INIT8:
	OR	BYTE PTR [SI],CL ; UA
	INC	SI
DSK_INIT6:
	INC	CX
	SHL	AX,1
	JNC	DSK_INIT7
	XCHG	AX,SI
	SUB	AX,OFFSET DRVS
	POP	DX
	TEST	AX,AX
	JNE	YESFDD
	MOV	SI,OFFSET NOFDD
	JMP	ERRSTOP
	;; Compressed device driver list
DEVS	LABEL	BYTE
IF ANSI
        DW      8003H           ;Attributes - console input, output device
ENDIF
IFE ANSI
	DW	8013H		; and SPECIAL
ENDIF
        DW      CON_INT         ;Interrupt entry point
	DB	'CON '
        DW      8000H
        DW      AUX_INT
	DB	'AUX '
        DW      8000H
        DW      PRN_INT
	DB	'PRN '
        DW      8008H
        DW      TIM_INT
	DB	'CLOCK '
        DW      2000H           ;Is a block device
        DW      DSK_INT
	DB	4,' '
NDEVS	EQU	5
YESFDD:
	MOV	BYTE PTR [DSKNUNT],AL
	PUSH	DS
	POP	ES

	;; Create device driver tables.
	PUSH	CS
	POP	DS
	ASSUME	DS:CODE
	MOV	SI,OFFSET DEVS
	MOV	DI,OFFSET DEVSTART
	MOV	CX,NDEVS
DEVSLP:
	CMP	CX,2
	SBB	BX,BX
	LEA	AX,[DI+18]	; Next entry offset
	OR	AX,BX		; -1 for last entry
	STOSW			; Link offset
	MOV	AX,ES
	OR	AX,BX
	STOSW			; Link segment
	MOVSW			; Attributes
	MOV	AX,OFFSET STRATEGY
	STOSW			; Srategy entry point
	MOVSW			; Interrupt entry point
	LEA	BX,[DI+8]	; Next entry offset
DEVSNL:
	LODSB
DEVSFL:
	STOSB
	CMP	AL,' '
	JNE	DEVSNL		; Copy name
	CMP	DI,BX
	JB	DEVSFL		; Fill space
	MOV	DI,BX		; Move back if name is 8-byte long.
	LOOP	DEVSLP

	;; AUX initialize
	PUSH	DI
	MOV	DI,OFFSET AUX_DAT
	MOV	DX,12
	MOV	CX,4E15H
	MOV	BX,101H
	MOV	AX,7H		; Initialize
	INT	19H
	POP	DI

	ASSUME	DS:NOTHING,ES:NOTHING

	;; CON initialize
	MOV	AX,0A00H	; Set mode 80x25, kanji, vertical line
	INT	18H
	MOV	AH,0CH		; Enable text
	INT	18H
	XOR	DX,DX
	MOV	AH,0EH		; Text display start
	INT	18H
	MOV	AX,1001H	; Disable cursor blink
	INT	18H
	MOV	AH,11H		; Show cursor
	INT	18H
	XOR	DX,DX
	MOV	AH,13H		; Set cursor position
	INT	18H
	MOV	DX,(0E1H SHL 8) OR ' '
	MOV	AH,16H		; Fill VRAM
	INT	18H

IFE ANSI
	;; CON SPECIAL support
	XOR	AX,AX
	MOV	DS,AX
	MOV	WORD PTR DS:[29H*4+0],OFFSET INT29H
	MOV	WORD PTR DS:[29H*4+2],CODE
ENDIF

	;; HWINIT part and SYSINITSEG may be run with a different
	;; segment.
	CALL	GETSEGDIFF
	ADD	AX,SEG SYSINIT
        MOV     DS,AX

ASSUME  DS:SEG SYSINIT

	XOR	AX,AX
	MOV	ES,AX
	MOV	AL,ES:[501H]
	AND	AL,7		; Memory size
	MOV	BX,640*40H
	SUB	AX,4		; -4
	JE	MEMORY_SIZE_OK
	MOV	BX,512*40H
	INC	AX		; -3
	JE	MEMORY_SIZE_OK
	MOV	BX,384*40H
	INC	AX		; -2
	JE	MEMORY_SIZE_OK
	MOV	BX,256*40H
	INC	AX		; -1
	JE	MEMORY_SIZE_OK
	MOV	BX,128*40H
MEMORY_SIZE_OK:
        MOV     DS:[MEMORY_SIZE],BX

	MOV	AX,CODE
	MOV	ES,AX
	MOV	SI,OFFSET DRVS
	AND	DL,3
DRVSLP:
	LODS	BYTE PTR ES:[SI]
	AND	AL,3
	CMP	AL,DL
	JNE	DRVSLP
	XCHG	AX,SI
	SUB	AX,OFFSET DRVS
	MOV	DS:[DEFAULT_DRIVE],AL

        MOV     DS:[CURRENT_DOS_LOCATION],SS

	LEA	AX,[DI+15]
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

        END	HWINIT

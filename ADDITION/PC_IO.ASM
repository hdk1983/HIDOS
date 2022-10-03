; IO.SYS for IBM PC compatible
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
CODE    ENDS

STACK	SEGMENT
	DB	128 DUP (?)
STACKEND LABEL WORD
STACK	ENDS

SYSINITSEG      SEGMENT PUBLIC 'SYSTEM_INIT'
SYSINITSEG      ENDS

LAST	SEGMENT PUBLIC 'LAST'
LAST	ENDS

CODE    SEGMENT
ASSUME  CS:CODE,DS:NOTHING,ES:NOTHING,SS:NOTHING
BIOSSEG	EQU	CODE

        ORG     0               ;Starts at an offset of zero.

INIT:   JMP     HWINIT

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

        PAGE
        SUBTTL  Main console I/O section.

CHAR    DB      ?               ;Small typeahead buffer for now.
CHAR2	DB	?
	; Table from DOSMES.ASM except *F8
	; Must be sorted by key code
KEYCODELIST LABEL BYTE
        DB      59                      ; Copy one char - F1
        DB      "S"                     ; F1 Copy one char
        DB      60                      ; Copy to char - F2
        DB      "T"                     ; F2 Copy to char
        DB      61                      ; Copy line - F3
        DB      "U"                     ; F3 Copy line
        DB      62                      ; Skip to char - F4
        DB      "W"                     ; F5 Skip to char
        DB      63                      ; Reedit line (new template) - F5
        DB      "J"                     ; ERASE Reedit line (new template)
        DB      64                      ; Ctrl-Z - F6
        DB      "Z"                     ; ^Z inserter
        DB      65                      ; Escape character - F7
        DB      "R"                     ; GRAY Escape character
        DB      66                      ; *F8 (ESC on PC DOS)
        DB      "E"                     ; SHIFT ERASE Kill line (no change in template)
        DB      75                      ; Backspace - <--
        DB      "D"                     ; LEFT Backspace
        DB      77                      ; Copy one char - -->
        DB      "S"                     ; F1 Copy one char
        DB      82                      ; Enter insert mode - INS (toggle)
        DB      "P"                     ; BLUE Enter insert mode
        DB      83                      ; Skip one char - DEL
        DB      "V"                     ; F4 Skip one char
	DB	255			; End
	DB	"R"			;

;
; Console keyboard handler.
;

CISTAT: PUSH    CX              ;Save CX pair.
        MOV     AL,[CHAR]
        OR      AL,AL
        JNZ     CISTA9          ;Character still in buffer.
	MOV	AL,[CHAR2]
	TEST	AL,AL
	JE	CISTA1
	MOV	[CHAR],AL
	MOV	[CHAR2],0
        JNZ     CISTA9          ;Character still in buffer.
CISTA1:
	MOV	AH,1
	INT	16H
        JZ      CISTA9
	MOV	AH,0
	INT	16H
	MOV	[CHAR],AL
	TEST	AL,AL
	JNE	CISTA9
	PUSH	BX
	MOV	BX,OFFSET KEYCODELIST-2
CISTAT_LOOP:
	INC	BX
	INC	BX
	CMP	AH,[BX]
	JB	CISTAT_NOT_MATCH
	JNE	CISTAT_LOOP
	MOV	AL,[BX+1]
	MOV	[CHAR2],AL
	MOV	AL,27		; ESC
	MOV	[CHAR],AL
	TEST	AL,AL
CISTAT_NOT_MATCH:
	POP	BX
CISTA9: POP     CX              ;Can't lose CX pair.
        RET

;
; Get a character from the buffer queue.
;

CINP:   CALL    CISTAT          ;Check for character ready in queue.
        JZ      CINP            ;Cycle until one ready.
        MOV     [CHAR],0        ;We have character in AL, clear type a head.
        RET

;
; Console read non-destructive.
;

CON_RDND:
        CALL    CISTAT          ;See if character ready.
        JZ      CON_RDN2        ;No, return busy signal.
CON_RDN1:
        LDS     BX,CS:[PTRSAV]
        MOV     [BX.MEDIA],AL
        JMP     EXIT
CON_RDN2:
        JMP     BUS_EXIT

;
; Console destructive read.
;

CON_READ:
        CALL    CINP            ;Get character.
        STOSB                   ;Save it in users buffer.
        LOOP    CON_READ        ;Loop until CX is exhausted.
        JMP     EXIT

;
; Console flush routine. (ctrl-c, ctrl-f, or ctrl-s inspired)
;

CON_FLSH:
        MOV     [CHAR],0        ;Clear small type a head buffer.
	MOV	[CHAR2],0
        JMP     EXIT

;
; Console output status routine.
;

CON_WRST:
        JMP     EXIT            ;Yes, normal exit.

;
; Console output routine.
;

CON_WRIT:
        MOV     SI,DI           ;Get destination to source.
CON_WRI1:
        LODS    BYTE PTR ES:[SI]
        PUSH    CX
IF      ANSI
        CALL    CONOUT          ;Call ansi driver.
        ENDIF
IFE     ANSI
        CALL    OUTCHR
        ENDIF
        POP     CX
        LOOP    CON_WRI1        ;Keep going until user buffer through.
        JMP     EXIT

;
; Console character output routine.
;

OUTCHR:
	PUSH	AX
	PUSH	BX
	MOV	BX,7
	CMP	AL,9		; Tab
	JE	OUTCHR_TAB
	MOV	AH,0EH
	INT	10H
OUTCHR_RET:
	POP	BX
	POP	AX
        RET
OUTCHR_TAB:
	PUSH	CX
	PUSH	DX
	MOV	AH,3
	INT	10H
	DB	83H,0CAH,0F8H	; OR DX,-8
OUTCHR_TAB_LOOP:
	MOV	AX,0E00H+' '
	INT	10H
	INC	DX
	JNE	OUTCHR_TAB_LOOP
	POP	DX
	POP	CX
	JMP	OUTCHR_RET
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

PRN_STA:
        JMP     EXIT

;
; Printer write routine.
;

PRN_WRT:MOV     SI,DI           ;Set source = destination index.

PRN_WR1:LODS    BYTE PTR ES:[SI];Get a data byte.
        PUSH    CX
	MOV	AH,0
	XOR	DX,DX
	INT	17H
        POP     CX
        LOOP    PRN_WR1
        RET

        PAGE
        SUBTTL  Auxilary I/O routines.

AUXCHAR DB      0               ;Temporary AUX ahead storage.

;
; Status routine for Auxilary port.
;

AISTAT: MOV     AL,[AUXCHAR]
        TEST    AL,AL
        JNZ     AISTA9          ;Character already waiting.
	MOV	AX,300H
	XOR	DX,DX
	INT	14H
	MOV	AL,AH
	AND	AL,1
        JZ      AISTA9          ;Still none waiting.
	MOV	AX,200H
	XOR	DX,DX
	INT	14H
	TEST	AX,AX
	JNS	AISTA9
	XOR	AX,AX
AISTA9: MOV     [AUXCHAR],AL
        RET

;
; Auxilary port read.
;

AIN:    CALL    AISTAT          ;Get status and/or char.
        JZ      AIN             ;Cycle until one is ready.
        MOV     [AUXCHAR],0
        RET

;
; Write routine for Auxilary port.
;

AOUT:
	MOV	AH,1
	XOR	DX,DX
	INT	14H
        RET

;
; Non-Destructive Auxilary read routine.
;

AUX_RDND:
        CALL    AISTAT          ;Get status and copy of char. waiting if any.
        JZ      AUX_RDN2        ;No character waiting, exit.
        JMP     CON_RDN1
AUX_RDN2:
        JMP     BUS_EXIT

;
; Destructive Auxilary read routine.
;

AUX_READ:
        CALL    AIN             ;Get data character.
        STOSB                   ;Save it through DI.
        LOOP    AUX_READ        ;Cycle until user buffer full.
        JMP     EXIT

;
; Auxilary clear type a head.
;

AUX_CLR:
        MOV     [AUXCHAR],0
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
        MOV     SI,DI
AUX_WRI1:
        LODS    BYTE PTR ES:[SI]        ;Get char. from users buffer.
        CALL    AOUT            ;Send it to device.
        LOOP    AUX_WRI1        ;Cycle until all done.
        JMP     EXIT

        PAGE
        SUBTTL  Date/Time Routines.

TIM_DAYS: DB    2 DUP (?)       ;Number of days since 1-1-80.
TIM_MINS  DB    ?               ;Minutes.
TIM_HRS   DB    ?               ;Hours.
TIM_HSEC  DB    ?               ;Hundreths of a second.
TIM_SECS  DB    ?               ;Seconds.

;;; 1573040 = 2809 * 560
TIM_V1A	EQU	2809
TIM_V1B	EQU	560
;;; 8640000 = 33750 * 256
TIM_V2A	EQU	33750
;;; 8640000 * 1573040 < 2**48
TIM_TMP	DW	?,?,?

;;; uint48_t TIM_TMP *= BX
TIM_MUL	PROC	NEAR
	XOR	CX,CX
	MOV	SI,OFFSET TIM_TMP
TIM_MUL_LOOP:
	LODSW
	XOR	DX,DX
	MUL	BX
	ADD	AX,CX
	ADC	DX,0
	MOV	[SI-2],AX
	MOV	CX,DX
	CMP	SI,OFFSET TIM_TMP+6
	JNE	TIM_MUL_LOOP
	RET
TIM_MUL	ENDP

;;; uint48_t TIM_TMP /= BX
;;; DX = TIM_TMP % BX
TIM_DIV	PROC	NEAR
	XOR	DX,DX
	MOV	SI,OFFSET TIM_TMP+4
	STD
TIM_DIV_LOOP:
	LODSW
	DIV	BX
	MOV	[SI+2],AX
	CMP	SI,OFFSET TIM_TMP-2
	JNE	TIM_DIV_LOOP
	CLD
	RET
TIM_DIV	ENDP

;
; Time write routine.
;

TIM_WRT:
        MOV     SI,OFFSET TIM_DAYS
        XCHG    SI,DI
        PUSH    ES
        MOV     AX,DS
        POP     DS
        MOV     ES,AX
	MOVSW
	MOVSW
	MOVSW
	PUSH	CS
	POP	DS
	XOR	DI,DI		; DI=0
	MOV	CX,60
	MOV	AL,[TIM_HRS]
	MUL	CL		; AX=HRS*60
	XCHG	AX,BX		; BX=HRS*60
	MOV	AL,[TIM_MINS]
	CBW			; AX=MINS
	ADD	AX,BX		; AX=HRS*60+MINS
	MUL	CX		; DX:AX=(HRS*60+MINS)*60
	XCHG	AX,BX		; DX:BX=(HRS*60+MINS)*60
	MOV	AL,[TIM_SECS]
	CBW			; AX=SECS DX:BX=(HRS*60+MINS)*60
	ADD	BX,AX
	ADC	DX,DI		; DX:BX=(HRS*60+MINS)*60+SECS
	XCHG	AX,DX		; AX:BX=(HRS*60+MINS)*60+SECS
				; AX:BX < 86400, so AX:BX*100 < UINT32_MAX
	MOV	CL,100		; CX=100
	MUL	CX
	XCHG	AX,BX
	MUL	CX
	ADD	DX,BX		; DX:AX=((HRS*60+MINS)*60+SECS)*100
	XCHG	AX,BX		; DX:BX=((HRS*60+MINS)*60+SECS)*100
	MOV	AL,[TIM_HSEC]
	CBW
	ADD	AX,BX
	ADC	DX,DI		; DX:AX=((HRS*60+MINS)*60+SECS)*100+HSEC
	MOV	[TIM_TMP+0],AX
	MOV	[TIM_TMP+2],DX
	MOV	[TIM_TMP+4],DI
	MOV	BX,TIM_V1A
	CALL	TIM_MUL
	MOV	BX,TIM_V1B
	CALL	TIM_MUL
	MOV	BX,TIM_V2A
	CALL	TIM_DIV
	MOV	DX,[TIM_TMP+1]
	MOV	CX,[TIM_TMP+3]
	MOV	AH,1
	INT	1AH
        JMP     EXIT

;
; Time read routine.
;

TIMEREAD PROC NEAR
	MOV	AH,0
	INT	1AH
	TEST	AL,AL
	JE	TIMEREAD_SAMEDAY
	INC	WORD PTR [TIM_DAYS]
TIMEREAD_SAMEDAY:
	RET
TIMEREAD ENDP

TIM_RED:
	CALL	TIMEREAD
	MOV	BYTE PTR [TIM_TMP+0],0
	MOV	[TIM_TMP+1],DX
	MOV	[TIM_TMP+3],CX
	MOV	BYTE PTR [TIM_TMP+5],0
	MOV	BX,TIM_V2A
	CALL	TIM_MUL
	MOV	BX,TIM_V1A
	CALL	TIM_DIV
	MOV	BX,TIM_V1B
	CALL	TIM_DIV
	MOV	BX,100
	CALL	TIM_DIV
	MOV	[TIM_HSEC],DL
	MOV	BX,60
	CALL	TIM_DIV
	MOV	[TIM_SECS],DL
	MOV	AX,[TIM_TMP+0]
	DIV	BL
	MOV	[TIM_MINS],AH
	MOV	[TIM_HRS],AL
        MOV     SI,OFFSET TIM_DAYS
	MOVSW
	MOVSW
	MOVSW
        MOV     AL,0
        JMP     EXIT

        PAGE
        SUBTTL  Drive Tables.


;
; MSDOS drive initialization tables and other what not.
;
;  Drive 0 is:
;    Double sided, double density,
;    80x2 track with 9 512 byte sectors per track (720 KiB)
;    ,,512,2,1,2,112,1440,0F9H,3,9
;  or
;    Double sided, double density,
;    80x2 track with 19 512 byte sectors per track (1440 KiB)
;    ,,512,1,1,2,224,2880,0F0H,9,18
;  or
;    Double sided, double density,
;    77x2 track with 8 1024 byte sectors per track (1232 KiB)
;    ,,1024,1,1,2,192,1232,0FEH,2,8
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

LDDRIV1 DBP     <,,512,2,1,2,112,1440,0F9H,3,9,2>
LDDRIV2	DBP	<,,512,1,1,2,224,2880,0F0H,9,18,2>
LDDRIV3 DBP	<,,1024,1,1,2,192,1232,0FEH,2,8,2>

DSK_INIT:
	MOV     AX,1
DSKNUNT	EQU	$-2
	MOV	SI,OFFSET INITTAB
        JMP     GET_BP5

INITTAB:
        DW      LDDRIV3.SECSIZE
        DW      LDDRIV3.SECSIZE
        DW      LDDRIV3.SECSIZE
        DW      LDDRIV3.SECSIZE
DRVFLG	DB	0

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
;       [MEDIA] = 0FEH for Standard single density.
;       [MEDIA] = 0FDH for Altos single density.
;       [MEDIA] = 0F4H for Altos double density.
;

MEDIAS  STRUC
        DB      13 DUP(?)               ;Static request header.
MEDIAS1 DB      ?                       ;Media byte.
MEDIAS2 DB      ?                       ;Media status byte flag.
MEDIAS  ENDS

MEDIAC:
	MOV	AH,0
	CMP	AL,BYTE PTR [DSKNUNT]
	JNB	BADRIV
	;; If less than 32 ticks from last access, the media is
	;; treated as not changed.
	CMP	AL,-1
LSTADRV EQU $-1
	JNE	MEDIA1
	CALL	TIMEREAD
	SUB	DX,5678H
LSTATIML EQU $-2
	SBB	CX,1234H
LSTATIMH EQU $-2
	JE	MEDIACCMP
	JA	MEDIA1
	ADD	DX,0B0H
	ADC	CX,18H
	JNE	MEDIA1
MEDIACCMP:
	CMP	DX,32
	JA	MEDIA1
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

DISKBIOS:
	PUSH	BP
	MOV	BP,-3		; Retry count
DISKBIOS_RETRY:
	PUSH	AX
	PUSH	CX
	PUSH	DX
	MOV	BX,DI
	INT	13H
	POP	DX
	JNC	DISKBIOS_RET
	INC	BP		; Carry flag is kept
	JNS	DISKBIOS_RET
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
	POP	CX
	POP	BP
	POP	BP
	RET

GET_BPB:
	CMP	AL,BYTE PTR [DSKNUNT]
	JB	GET_BPB_ALOK
BADRIV:
	MOV	AL,1
	JMP	ERR_EXIT
GET_BPB_ALOK:
	PUSH    ES
        PUSH    DI
	MOV	CX,1
	CBW
	XCHG	AX,DX
	OR	DL,[DRVFLG]
	MOV	AX,201H
	CALL	DISKBIOS
	POP	DI
        POP     ES
	JC	DISKERR
	XOR	AX,AX

GET_BP1:MOV     AL,ES:[DI.MEDIAID] ;Get diskettes media ID.
        MOV     SI,OFFSET LDDRIV1
        CMP     AL,[SI.MEDIAID]
        JZ      GET_BP4
        MOV     SI,OFFSET LDDRIV2
        CMP     AL,[SI.MEDIAID]
        JZ      GET_BP4
	MOV	SI,OFFSET LDDRIV3
	CMP	AL,[SI.MEDIAID]
	JZ	GET_BP4

GET_BP3:MOV     SI,OFFSET LDDRIV3

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
DISKERR:
	MOV	BX,OFFSET DISKERR_CODE
DISKERR_LOOP:
	SHR	AH,1
	JE	DISKERR_FOUND
	INC	BX
	JMP	DISKERR_LOOP
DISKERR_FOUND:
	MOV	AL,[BX]
	JMP	ERR_EXIT
DISKERR_CODE LABEL BYTE
	DB	3,0,8,12,4,12,6,2

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

DSK_COM:MOV     SI,OFFSET LDDRIV1
	CMP	AL,BYTE PTR [DSKNUNT]
	JB	DSK_COM_ALOK
	JMP	BADRIV
DSK_COM_ALOK:
        CMP     AH,[SI.MEDIAID]
        JE      DSK_CO2
        MOV     SI,OFFSET LDDRIV2
        CMP     AH,[SI.MEDIAID]
        JE      DSK_CO2
        MOV     SI,OFFSET LDDRIV3
        CMP     AH,[SI.MEDIAID]
        JE      DSK_CO2
        MOV     AL,7
        JMP     ERR_EXIT

DSK_CO2:

DSK_CO3:
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
	CALL	TIMEREAD
	MOV	WORD PTR [LSTATIML],DX
	MOV	WORD PTR [LSTATIMH],CX
	MOV	BYTE PTR [LSTADRV],AL
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
	OR	DL,[DRVFLG]
	MOV	AX,[BP+6]	; Number of sectors
	CMP	AX,BX
	JB	DISKRW_NSECOK
	MOV	AX,BX
DISKRW_NSECOK:
	MOV	BX,[SI.SECSIZE]
DRVDMA	LABEL	BYTE		; 0A9H TEST AX,immediate if no DMA
	CALL	DISKRW_GETBSEC
	CMP	AX,BX
	JB	DISKRW_BOK
	TEST	BX,BX
	JE	DISKRW_BHIT
	MOV	AX,BX
DISKRW_BOK:
	PUSH	AX
	MOV	AH,[BP+8]	; Command
	CALL	DISKBIOS
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
	LEA	SP,[BP-10]
	;; Normally this module is loaded into segment 200H, segment
	;; 1E0H for 512 byte sector is available for temporary use.
	PUSH	AX
	MOV	AX,[SI.SECSIZE]
	PUSH	AX
	PUSH	CX
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
	CALL	DISKBIOS
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
DRVEND	LABEL	BYTE
	ASSUME	DS:NOTHING

MEMERR	DB	'LOAD ADDRESS ERROR',0
DSKERR	DB	'READ ERROR',0
FILEERR	LABEL BYTE
MSDOS_FILENAME DB 'MSDOS   SYS'
	DB	' NOT FOUND',0
DOSSEG_SAVE DW ?
DMAFLAG	DB	0

;;; DMA boundary test and read
BTESTREAD PROC NEAR
	INT	12H
	CMP	AX,64
	MOV	AX,201H
	JB	DISKBIOSNOERR
	PUSH	ES
	PUSH	AX
	MOV	AX,0FFFH
	MOV	ES,AX
	POP	AX
	CALL	DISKBIOS
	POP	ES
	JC	BTESTREAD_ERROR
	PUSH	DS
	PUSH	DI
	MOV	AX,0FFFH
	MOV	DS,AX
	MOV	SI,DI
	MOV	CX,32
	CLD
	REP	MOVSW
	POP	DI
	POP	DS
	RET
BTESTREAD_ERROR:
	CMP	AH,9
	JNE	DISKBIOSERR
	MOV	[DMAFLAG],1
	MOV	AX,201H
BTESTREAD ENDP
	;; Fall through
DISKBIOSNOERR PROC NEAR
	CALL	DISKBIOS
	JC	DISKBIOSERR
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

GETSEGDIFF PROC NEAR
	MOV	AX,CS
	SUB	AX,CODE
	RET
GETSEGDIFF ENDP

HWINIT:
	CALL	GETSEGDIFF
	ADD	AX,STACK
	MOV	SS,AX
	MOV	SP,OFFSET STACKEND

	;; For debugging: EXE is runnable from DOS
	MOV	AX,CS
	MOV	BX,DS
	SUB	AX,BX
	CMP	AX,10H
	JNE	NOTDEBUG
	MOV	AX,ES
	SUB	BX,AX
	JNE	NOTDEBUG
	CMP	[BX],20CDH
	JNE	NOTDEBUG
	XOR	DX,DX
NOTDEBUG:

	;; Load MSDOS
	CALL	GETSEGDIFF
	ADD	AX,LAST
	MOV	BP,AX
	MOV	ES,AX
	XOR	DI,DI
	MOV	CX,1
	MOV	DH,0
	CALL	BTESTREAD
	CMP	[DMAFLAG],DH
	JNE	USEDMA
	MOV	[DRVDMA],0A9H	; TEST AX,immediate
USEDMA:
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
	MOV	[DOSSEG_SAVE],ES
	;; Stack at the end of the DOS will be used until the SYSINIT
	;; moves the DOS to the FINAL_DOS_LOCATION.
	PUSH	ES
	POP	SS
	LEA	SP,[DI+OFFSET STACKEND]

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
	MOV	CX,OFFSET DRVEND
	REP	MOVSB
SEGOK:
	;; Scan drives
	PUSH	DX
	;; Save 80 tracks per side flag of JX
	MOV	AL,40H
	AND	AL,DL
	MOV	ES:[DRVFLG],AL
DRVSCN:
	;; Find maximum drive number
	INC	DL
	TEST	DL,3
	JE	MAXDRIVE
	MOV	AH,0
	INT	13H
	JNC	DRVSCN
MAXDRIVE:
	DEC	DX
	AND	DL,3
	INC	DX
	MOV	BYTE PTR ES:[DSKNUNT],DL
	POP	DX

	ASSUME	ES:NOTHING

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

	INT	12H
	;; MEMORY_SIZE = AX*400H/10H = AX*40H
	MOV	CL,6
	SHL	AX,CL
        MOV     DS:[MEMORY_SIZE],AX

	AND	DL,3
	INC	DL		; looks like starting from 1
	MOV	DS:[DEFAULT_DRIVE],DL

	MOV	AX,[DOSSEG_SAVE]
        MOV     DS:[CURRENT_DOS_LOCATION],AX

	MOV	AX,CODE
	ADD	AX,((OFFSET DRVEND - OFFSET INIT) + 15) / 16
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

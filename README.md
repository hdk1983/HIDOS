# HIDOS

Tools and scripts for building MS-DOS with DEBUG, MASM, LINK and EXE2BIN utilities.

## Files

- MS-DOS/ is a submodule repository of the MS-DOS source code with some fixes.
- TOOLS/ contains tools for building MS-DOS with MASM Version 1.10 and LINK Version 2.00.
- ADDITION/ contains additional source files for building MS-DOS.
- BUILD/ contains a batch file, input files for EXE2BIN, and symbolic links to the source code and utilities (DEBUG, MASM, LINK and EXE2BIN).
- hidosvm/ contains a simple virtual machine for running VM_IO.SYS.
- cross/ contains files for cross build.

## How to Build

1. Prepare DOS environment.  (MS-DOS, FreeDOS and DOSBox are usable.)
2. Copy files in the BUILD/ directory to a file system accessible from the DOS.
3. Change current working directory to the BUILD/ directory and run M.BAT on the DOS.  Binaries will be stored to BUILD/BIN/ directory.

See cross/HOWTO.md for cross build details.

## Build on MS-DOS 2.11

If the MS-DOS has been built successfully, you can build MS-DOS on itself.
Disk space more than a floppy disk is needed, but current `PC_IO.SYS` does not support hard drives.
Using the HIDOS virtual machine is easy.
Especially, the hidoskvm is fast.

## IO.SYS

The build process generates the following IO.SYS binaries:

- `SKELIO.SYS`
- `PC_IO.SYS` (`PC_IO.EXE`)
- `VM_IO.SYS`
- `DOS_IO.EXE`

`SKELIO.SYS` is skeltal BIOS for the ALTOS ACS-86C.
Not tested.

`PC_IO.SYS` is BIOS for IBM PC compatible.
It can be booted by `PC_BOOT.BIN` boot code only.
`PC_IO.EXE` is for debugging.
Keyboard input routine converts function keys ans arrow keys to 2-byte escape sequences handled by DOSMES.ASM which says them as "VT52 equivalences" by default.
Maybe applications expect PC DOS compatible input -- 1st byte is NUL and 2nd byte is PC key code.
The BIOS also supports the PC DOS compatible mode.
Typing ESC F10 toggles the mode.

`VM_IO.SYS` is BIOS for the HIDOS virtual machine.
The virtual machine loads it directly from a file system.
Keyboard input is not converted.
Since VT100 escape sequences are different from the "VT52 equivalences", input escape sequence directly for line editing, like M-U (ESC U) for copy line, M-S (ESC S) for copy one char, etc.

`DOS_IO.EXE` is BIOS for MS-DOS -- DOS on DOS.
Instead of calling ROM BIOS or accessing devices directly, it calls the host DOS system.
It can use disk image files for drives.
`MSDOS.SYS` is loaded on the host too.
At least one FAT12 file system image or disk which contains `COMMAND.COM` is needed.
It works on 32-bit Windows command prompt, MS-DOS, DOSBox and FreeDOS.

## Boot on PC

### Starting From Existing DOS (for Debugging)

`PC_IO.EXE` may be able to be executed from a DOS environment.

### Booting From Floppy Disk

`PC_BOOT.BIN` is a boot sector binary file for floppy disks.
To write it to drive A:

```
A>DEBUG PC_BOOT.BIN
-W 100 0 0 1
-Q
A>
```

Note: this contains BIOS Parameter Block (BPB) for 720KiB format.
To use different format of a floppy disk, modify the `PC_BOOT.ASM` and build, or copy the first 3 bytes (JMP) and from byte offset 3EH, as follows:

```
A>DEBUG PC_BOOT.BIN
-L 800 0 0 1
-M 803 83D 103
-W 100 0 0 1
-Q
```

Then rename `PC_IO.SYS` to `IO.SYS` and copy `IO.SYS`, `MSDOS.SYS`, and `COMMAND.COM` to the disk.

The boot code is probably not compatible with other DOS.
It loads `IO.SYS` only, then `IO.SYS` loads `MSDOS.SYS`.

## Boot on a HIDOS virtual machine

The `VM_IO.SYS` is for the HIDOS virtual machine.
Copy `VM_IO.SYS`, `MSDOS.SYS`, and `COMMAND.COM` to a disk image.
Then start hidosvm/hidosvm or hidosvm/hidoskvm command with the disk image file name.

The HIDOS virtual machine is very simple architecture and NOT compatible with PC.
See hidosvm/hidosvm.txt for details.

## Boot on DOS

The `DOS_IO.EXE` is IO.SYS implemented as a DOS application.
Its command line parameter is MSDOS.SYS file name followed by drive-list that consists of FAT12 image file name or drive name (e.g. A:).
A character device `EXIT$` is installed for exiting the DOS environment.
Writing a digit (0 to 9) to the device exits the DOS with exit code specified by the digit.

Examples: start DOS with mounting the image FDD.IMG to drive A:

```
A>DOS_IO.EXE MSDOS.SYS FDD.IMG
```

Start DOS with using the drive A and B as is:

```
A>DOS_IO.EXE MSDOS.SYS A: B:
```

Exit the DOS:

```
A>ECHO 0 > \DEV\EXIT$
```

## Current Status

| File Name         | Build               | Run                        |
| ----------------- | ------------------- | -------------------------- |
| CHKDSK.COM        | OK                  | OK (on MS-DOS)             |
| COMMAND.COM       | OK                  | OK (on MS-DOS)             |
| DEBUG.COM         | OK                  | OK                         |
| DISKCOPY.COM      | OK                  | OK (on MS-DOS)             |
| EDLIN.COM         | OK                  | OK                         |
| EXE2BIN.EXE       | OK                  | OK                         |
| FC.EXE            | OK                  | OK                         |
| FIND.EXE          | OK                  | OK                         |
| FORMAT.COM        | OK                  | OK                         |
| HRDDRV.SYS        | OK                  | Not for PCs                |
| IO.SYS            | OK                  | OK                         |
| MORE.COM          | OK                  | OK                         |
| MSDOS.SYS         | OK                  | OK                         |
| PROFIL.COM        | OK                  |                            |
| PRINT.COM         | OK                  | OK (resident on MS-DOS)    |
| RECOVER.COM       | OK                  | OK (on MS-DOS)             |
| SORT.EXE          | OK                  | OK                         |
| SYS.COM           | OK                  | OK (on MS-DOS)             |

## Bugs

### MSDOS.SYS

The `CARPOS` variable is only updated in IO.ASM.
Therefore the variable is not updated if applications use raw output or INT 29H.
DEBUG.COM and COMMAND.COM seem OK with this implementation.
The behavior looks similar to PC DOS, as follows:

- AH=02H or 09H (INT 21H) updates `CARPOS` and expands (horizontal) tabs.
- AH=06H does not update `CARPOS` and does not expand tabs.
- Cooked mode CON output acts like AH=02H or AH=09H.
- Raw mode CON output acts like AH=06H.

Unlike other DOS, if only one floppy drive is found, B: does not exist.

### COMMAND.COM

`CLS` command prints ANSI escape sequence (`ESC [ 2 J`).
The screen is not cleared because currently ANSI switch is not enabled in IO.SYS.
IBM version seems calling ROM BIOS directly from COMMAND.COM.

`DIR /P` command pauses per 23 lines, defined as LINPERPAG in COMEQU.ASM.
It is not good if the screen has less than 24 lines, like JX Japanese kihon-mode.

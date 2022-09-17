# HIDOS

Tools and scripts for building MS-DOS with MASM, LINK and EXE2BIN
utilities.

## Files

- MS-DOS/ is a submodule repository of the MS-DOS source code with some fixes.
- TOOLS/ contains two preprocessor tools for building MS-DOS with MASM Version 1.10.
- ADDITION/ contains additional source files for building MS-DOS.
- BUILD/ contains two batch files and symbolic links to the source code and utilities (MASM, LINK and EXE2BIN).

## How to Build

1. Prepare DOS environment.  (FreeDOS is usable.  DOSBox might not support CALL in batch files.)
2. Copy files in the BUILD/ directory to a file system accessible from the DOS.
3. Change current working directory to the BUILD/ directory and run M.BAT on the DOS.  Binaries will be stored to BUILD/BIN/ directory.

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
| IO.SYS            | Need some symbols   |                            |
| MORE.COM          | OK                  | OK                         |
| MSDOS.SYS         | OK                  | OK                         |
| PROFIL.COM        | OK                  |                            |
| PRINT.COM         | OK                  | OK (resident on MS-DOS)    |
| RECOVER.COM       | OK                  | OK (on MS-DOS)             |
| SORT.EXE          | OK                  | OK                         |
| SYS.COM           | OK                  | OK (on MS-DOS)             |

## Bugs

### MSDOS.SYS

String input routine in STRIN.ASM refers `CARPOS` variable but it is not set.
Because of this, typing backspace may delete incorrect number of spaces for a tab.

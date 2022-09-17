# HIDOS

Tools and scripts for building MS-DOS with MASM, LINK and EXE2BIN
utilities.

## Files

- MS-DOS/ is a submodule repository of the MS-DOS source code with some fixes.
- TOOLS/ contains two preprocessor tools for building MS-DOS with MASM Version 1.10.
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
| FORMAT.COM        | OK                  | Not for PCs                |
| HRDDRV.SYS        | OK                  | Not for PCs                |
| IO.SYS            | Need some symbols   |                            |
| MORE.COM          | OK                  | OK                         |
| MSDOS.SYS         | Need STDIO          |                            |
| PROFIL.COM        | OK                  |                            |
| PRINT.COM         | OK                  | Not for PCs                |
| RECOVER.COM       | OK                  |                            |
| SORT.EXE          | OK                  | OK                         |
| SYS.COM           | OK                  | OK (on MS-DOS)             |

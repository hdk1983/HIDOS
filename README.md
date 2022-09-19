# HIDOS

Tools and scripts for building MS-DOS with MASM, LINK and EXE2BIN
utilities.

## Files

- MS-DOS/ is a submodule repository of the MS-DOS source code with some fixes.
- TOOLS/ contains two preprocessor tools for building MS-DOS with MASM Version 1.10.
- ADDITION/ contains additional source files for building MS-DOS.
- BUILD/ contains two batch files, input files for EXE2BIN, and symbolic links to the source code and utilities (MASM, LINK and EXE2BIN).

## How to Build

1. Prepare DOS environment.  (FreeDOS is usable.  DOSBox might not support CALL in batch files.)
2. Copy files in the BUILD/ directory to a file system accessible from the DOS.
3. Change current working directory to the BUILD/ directory and run M.BAT on the DOS.  Binaries will be stored to BUILD/BIN/ directory.

## Boot

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

Then rename `PC_IO.SYS` to `IO.SYS` and copy `IO.SYS`, `MSDOS.SYS`, and `COMMAND.COM` to the disk.

The boot code is probably not compatible with other DOS.
It loads `IO.SYS` only, then `IO.SYS` loads `MSDOS.SYS`.

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
Therefore the variable is not properly updated if applications use stdout or INT 29H.
DEBUG.COM and COMMAND.COM seem OK with this implementation.

Unlike other DOS, if only one floppy drive is found, B: does not exist.

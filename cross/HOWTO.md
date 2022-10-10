# Cross Build How To

Describing how to do cross build MS-DOS, without using virtual machines or existing DOS environment.

## Build on GNU/Linux (x86 including 64-bit)

Use doscomm and the crossmakefile to build on x86 GNU/Linux.
Make sure 32-bit libc and compilation tools are installed before running the following commands.

```
HIDOS/cross$ make
cc -no-pie -m32 -o doscomm doscomm.s
HIDOS/cross$ cd ../BUILD/
HIDOS/BUILD$ make -f ../cross/crossmakefile all
```

Use -j option for make command to do parallel make.

NUL.MAP file is created but never used.

## Build on GNU/Linux (not x86)

Not tested.

Since the doscomm program is written in x86 assembly language, use a cross compiler to make the doscomm binary.
Then use qemu-i386 command (QEMU user emulator) to run the doscomm binary.
Makefile modification may be needed.

## Build on Windows (32-bit x86)

Tested on Windows 2000 (x86).

For Windows 10 only.
Windows 11 32-bit version is not released.

Since 32-bit Windows can run MS-DOS applications, it can run the build batch file directly.
However, parallel make is probably not straightforward.

The doscomm program may work on 32-bit Windows.

## Build on Windows (64-bit x86)

Partially tested.

The doscomm program works on 64-bit Windows.
However the crossmakefile needs a Unix-like shell and make command.
64-bit Windows also supports Windows Subsystem for Linux (WSL), but 32-bit Linux binary looks like not supported by WSL1.

Using doscomm Windows binary built with MinGW from WSL GNU make looks good.
Note that normal Windows binary cannot read symbolic links, so copying BUILD/ files to a different directory is needed.

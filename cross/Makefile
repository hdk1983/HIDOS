MINGWCC=i686-w64-mingw32-gcc-posix

.PHONY : all
all : doscomm

doscomm : doscomm.S
	$(CC) -no-pie -m32 -o doscomm doscomm.S

doscomm.exe : doscomm.S
	$(MINGWCC) -no-pie -m32 -o doscomm.exe doscomm.S

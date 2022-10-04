/* HIDOS Virtual Machine
; Copyright 2022 Hideki EIRAKU <hdk_2@users.sourceforge.net>
;
; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; "Software"), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:
;
; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
; OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
; WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/poll.h>
#include <time.h>
#include <sys/time.h>
#include <sys/file.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include "common.h"

enum
  {
    IODEV = 0,
    IOIDX = 2,
    IOCMD = 4,
    IOBUF = 6,
    IOADR = 10,
    IOSIZ = 14,
  };

static uint8_t *mem;
static int ndisks;
static int *diskfd;
static struct timespec *diskmtim;
static uint32_t msdos_addr;
static uint32_t ram_size;

static void
sttycooked (void)
{
  system ("stty cooked echo");
}

static void
sttyraw (void)
{
  system ("stty -cooked -echo");
}

static uint8_t *
memp (uint32_t addr)
{
  return &mem[addr & (MEMSIZE8086 - 1)];
}

unsigned
memr (uint32_t addr)
{
  return *memp (addr);
}

void
memw (uint32_t addr, unsigned value)
{
  uint8_t *p = memp (addr);
  if (p - mem < ram_size)
    *p = value;
}

unsigned
memr2 (uint32_t addr)
{
  return memr (addr) | memr (addr + 1) << 8;
}

uint32_t
memr4 (uint32_t addr)
{
  return memr2 (addr) | memr2 (addr + 2) << 16;
}

void
memw2 (uint32_t addr, unsigned value)
{
  memw (addr, value);
  memw (addr + 1, value >> 8);
}

void
memw4 (uint32_t addr, uint32_t value)
{
  memw2 (addr, value);
  memw2 (addr + 2, value >> 16);
}

static unsigned
diskch (int drive)
{
  int fd = diskfd[drive];
  struct stat s;
  if (diskmtim[drive].tv_sec == 0 && diskmtim[drive].tv_nsec == 1)
    return 0;
  if (fstat (fd, &s) < 0)
    {
      perror ("fstat");
      diskmtim[drive].tv_sec = 0;
      diskmtim[drive].tv_nsec = 1;
      return 0;
    }
  if (s.st_mtim.tv_sec == diskmtim[drive].tv_sec &&
      s.st_mtim.tv_nsec == diskmtim[drive].tv_nsec)
    return 1;
  diskmtim[drive].tv_sec = s.st_mtim.tv_sec;
  diskmtim[drive].tv_nsec = s.st_mtim.tv_nsec;
  return ~0;
}

static int
diskrw (int drive, int wr, uint32_t addr, uint32_t off, uint32_t len)
{
  if (drive < 0 || drive >= ndisks)
    {
      fprintf (stderr, "Invalid drive %d\r\n", drive);
      return -1;
    }
  int fd = diskfd[drive];
  if (flock (fd, (wr ? LOCK_EX : LOCK_SH) | LOCK_NB) < 0)
    return -1;
  int ret = 0;
  while (len > 0)
    {
      uint32_t remaining = MEMSIZE8086 - (memp (addr) - mem);
      if (remaining > len)
	remaining = len;
      if (wr)
	{
	  if (pwrite (fd, memp (addr), remaining, off) != remaining)
	    {
	      perror ("pwrite");
	      ret = -1;
	      break;
	    }
	}
      else
	{
	  if (pread (fd, memp (addr), remaining, off) != remaining)
	    {
	      perror ("pread");
	      ret = -1;
	      break;
	    }
	}
      addr += remaining;
      off += remaining;
      len -= remaining;
    }
  if (wr)
    {
      struct stat s;
      if (fstat (fd, &s) < 0)
	{
	  perror ("fstat");
	  diskmtim[drive].tv_sec = 0;
	  diskmtim[drive].tv_nsec = 1;
	}
      else
	{
	  diskmtim[drive].tv_sec = s.st_mtim.tv_sec;
	  diskmtim[drive].tv_nsec = s.st_mtim.tv_nsec;
	}
    }
  if (flock (fd, LOCK_UN) < 0)
    perror ("flock");
  return ret;
}

static uint32_t
load_file (uint8_t *filename, uint32_t addr, int showerr)
{
  if (diskrw (0, 0, 0, 0, 512))
    return 0;
  int secsiz = memr2 (11);
  int nseccls = memr (13);
  int nsecres = memr2 (14);
  int nfats = memr (16);
  int nrdir = memr2 (17);
  int nsecfat = memr2 (22);
  int root_start = nsecres + nfats * nsecfat;
  int data_start = root_start + (32 * nrdir + secsiz - 1) / secsiz;
  if (diskrw (0, 0, 0, secsiz * root_start, 32 * nrdir))
    return 0;
  uint32_t cluster;
  for (int i = 0; i < nrdir; i++)
    {
      if (!memcmp (memp (32 * i), filename, 11))
	{
	  cluster = memr2 (32 * i + 0x1a);
	  goto found;
	}
      if (!memr (32 * i))
	break;
    }
  if (showerr)
    fprintf (stderr, "\"%s\" not found\r\n", filename);
  return 0;
 found:
  if (diskrw (0, 0, addr, secsiz * (data_start + nseccls * (cluster - 2)),
	      secsiz * nseccls))
    return 0;
  addr += secsiz * nseccls;
  if (diskrw (0, 0, 0, secsiz * nsecres + (cluster / 2) * 3, 3))
    return 0;
  if (cluster % 2)
    cluster = memr2 (1) >> 4;
  else
    cluster = memr2 (0) & 0xfff;
  if (cluster < 0xff0)
    goto found;
  return addr;
}

int
load (void)
{
  memset (&mem[0x80000], 0, 0x7fff0);
  msdos_addr = load_file ((uint8_t *)"VM_IO   SYS", 0x80000, 0);
  if (!msdos_addr)
    msdos_addr = load_file ((uint8_t *)"IO      SYS", 0x80000, 1);
  if (!msdos_addr)
    return -1;
  if (!load_file ((uint8_t *)"MSDOS   SYS", msdos_addr, 1))
    return -1;
  memset (&mem[0], 0, 0x80000);
  mem[0x86 * 4 + 0] = 0x7;	/* INT 86H handler FFFFH:0007H */
  mem[0x86 * 4 + 1] = 0x0;
  mem[0x86 * 4 + 2] = 0xff;
  mem[0x86 * 4 + 3] = 0xff;
  return 0;
}

static int
io_init (unsigned addr, unsigned idx, unsigned cmd)
{
  if (idx)
    return -1;
  switch (cmd)
    {
    case 'D' << 8 | 'I':	/* Disks */
      memw2 (addr + IOBUF, ndisks);
      break;
    case 'R' << 8 | 'A':	/* RAM size */
      memw4 (addr + IOBUF, ram_size);
      break;
    case 'D' << 8 | 'O':	/* DOS address */
      memw2 (addr + IOBUF, msdos_addr >> 4);
      break;
    default:
      return -1;
    }
  return 0;
}

static int
io_disk (unsigned addr, unsigned idx, unsigned cmd)
{
  if (idx >= ndisks)
    return -1;
  uint32_t buf = memr4 (addr + IOBUF);
  uint32_t siz = memr4 (addr + IOSIZ);
  uint32_t adr = memr4 (addr + IOADR);
  switch (cmd)
    {
    case 'R' << 8 | 'D':	/* Read */
      if (diskrw (idx, 0, adr, buf, siz))
	memw2 (addr + IOBUF, 0);
      else
	memw2 (addr + IOBUF, 1);
      break;
    case 'W' << 8 | 'R':	/* Write */
      if (diskrw (idx, 1, adr, buf, siz))
	memw2 (addr + IOBUF, 0);
      else
	memw2 (addr + IOBUF, 1);
      break;
    case 'C' << 8 | 'H':	/* Media change */
      memw2 (addr + IOBUF, diskch (idx));
      break;
    default:
      return -1;
    }
  return 0;
}

int
conin (uint16_t *in)
{
  static uint16_t state = 1;
  if (state == 0xffff)
    return -2;
  uint8_t buf;
  if ((state & 0xff) == 3)
    {
      if (!in)
	return 1;
      buf = state >> 8;
      state = 0;
    }
  else
    {
      struct pollfd pf;
      pf.fd = 0;
      pf.events = POLLIN;
      if (poll (&pf, 1, in ? 0 : 10) != 1)
	return 0;
      if (!in)
	return 1;
      if (read (0, &buf, 1) != 1)
	return -1;
    }
  if (state == 1)
    {
      if (buf == '~')
	{
	  state = 2;
	  return 0;
	}
      state = 0;
    }
  if (state == 2)
    {
      if (buf == '.')
	{
	  fprintf (stderr, "\r\nQuit!\r\n");
	  state = 0xffff;
	  return -2;
	}
      if (buf != '~')
	{
	  state = 3 | buf << 8;
	  *in = '~';
	  return 1;
	}
      state = 0;
    }
  if (buf == '\r')
    state = 1;
  *in = buf;
  return 1;
}

static int
io_con (unsigned addr, unsigned idx, unsigned cmd)
{
  if (idx)
    return -1;
  static int init;
  if (!init)
    {
      atexit (sttycooked);
      sttyraw ();
      init = 1;
    }
  switch (cmd)
    {
      static unsigned count;
      static uint16_t last;
    case 'W' << 8 | '1':	/* Write one byte */
      count = 0;
      if (write (1, memp (addr + IOBUF), 1) != 1)
	return -1;
      break;
    case 'W' << 8 | 'R':	/* Write */
      count = 0;
      if (write (1, memp (memr4 (addr + IOADR)), memr4 (addr + IOSIZ))
	  != memr4 (addr + IOSIZ))
	return -1;
      break;
    case 'R' << 8 | 'P':	/* Read poll */
    case 'R' << 8 | '1':	/* Read one byte */
      if (!last)
	{
	  switch (conin (&last))
	    {
	    case 0:
	      break;
	    case 1:
	      last |= 0x100;
	      break;
	    case -2:
	      return -2;
	    default:
	      return -1;
	    }
	}
      if (last)
	count = 0;
      memw2 (addr + IOBUF, last);
      if (cmd == ('R' << 8 | '1'))
	last = 0;
      break;
    case 'R' << 8 | 'W':	/* Read wait (for lower CPU usage) */
      if (last)
	count = 0;
      else if (count < 16)
	count++;
      else if (conin (NULL))
	count = 0;
      break;
    default:
      return -1;
    }
  return 0;
}

static int
io_aux (unsigned addr, unsigned idx, unsigned cmd)
{
  if (idx)
    return -1;
  switch (cmd)
    {
    case 'W' << 8 | '1':	/* Write one byte */
      break;
    case 'W' << 8 | 'R':	/* Write */
      break;
    case 'R' << 8 | 'P':	/* Read poll */
      memw2 (addr + IOBUF, 0);
      break;
    case 'R' << 8 | '1':	/* Read one byte */
      break;
    default:
      return -1;
    }
  return 0;
}

static int
io_clock (unsigned addr, unsigned idx, unsigned cmd)
{
  if (idx)
    return -1;
  uint32_t siz = memr4 (addr + IOSIZ);
  uint32_t adr = memr4 (addr + IOADR);
  if (siz != 12)
    return -1;
  static struct timeval tv_base = { 0, 0 };
  struct timeval tv;
  struct tm tim;
  switch (cmd)
    {
    case 'R' << 8 | 'D':	/* Read */
      gettimeofday (&tv, NULL);
      tv.tv_sec += tv_base.tv_sec;
      tv.tv_usec += tv_base.tv_usec;
      while (tv.tv_usec >= 1000000)
	tv.tv_usec -= 1000000, tv.tv_sec++;
      memw4 (adr + 8, tv.tv_usec);
      tim = *localtime (&tv.tv_sec);
      memw4 (adr + 4, tim.tm_hour * 3600 + tim.tm_min * 60 + tim.tm_sec);
      tim.tm_year = 70;
      tim.tm_mon = 0;
      tim.tm_mday = 1;
      memw4 (adr + 0, (tv.tv_sec - mktime (&tim)) / 86400);
      break;
    case 'W' << 8 | 'R':	/* Write */
      gettimeofday (&tv, NULL);
      tim = *localtime (&tv.tv_sec);
      tv_base.tv_sec = memr4 (adr + 4);
      tim.tm_hour = tv_base.tv_sec / 3600;
      tim.tm_min = (tv_base.tv_sec / 60) % 60;
      tim.tm_sec = tv_base.tv_sec % 60;
      tim.tm_year = 70;
      tim.tm_mon = 0;
      tim.tm_mday = 1;
      tv_base.tv_sec = mktime (&tim) + memr4 (adr + 0) * 86400;
      tv_base.tv_usec = memr4 (adr + 8);
      tv_base.tv_sec -= tv.tv_sec;
      while (tv_base.tv_usec < tv.tv_usec)
	tv_base.tv_usec += 1000000, tv_base.tv_sec--;
      break;
    default:
      return -1;
    }
  return 0;
}

static int
io_printer (unsigned addr, unsigned idx, unsigned cmd)
{
  if (idx)
    return -1;
  switch (cmd)
    {
    case 'W' << 8 | '1':	/* Write one byte */
      break;
    case 'W' << 8 | 'R':	/* Write */
      break;
    case 'R' << 8 | 'P':	/* Read poll */
      memw2 (addr + IOBUF, 0);
      break;
    case 'R' << 8 | '1':	/* Read one byte */
      break;
    default:
      return -1;
    }
  return 0;
}

int
vmio (unsigned addr)
{
  unsigned dev = memr2 (addr + IODEV);
  unsigned idx = memr2 (addr + IOIDX);
  unsigned cmd = memr2 (addr + IOCMD);
  int ret = -1;
  switch (dev)
    {
    case 'I' << 8 | 'N':
      ret = io_init (addr, idx, cmd);
      break;
    case 'D' << 8 | 'I':
      ret = io_disk (addr, idx, cmd);
      break;
    case 'C' << 8 | 'O':
      ret = io_con (addr, idx, cmd);
      break;
    case 'A' << 8 | 'U':
      ret = io_aux (addr, idx, cmd);
      break;
    case 'C' << 8 | 'L':
      ret = io_clock (addr, idx, cmd);
      break;
    case 'P' << 8 | 'R':
      ret = io_printer (addr, idx, cmd);
      break;
    }
  if (ret && ret != -2)
    fprintf (stderr, "error %d dev=%x idx=%x cmd=%x\r\n", ret, dev, idx, cmd);
  return ret;
}

void
init_common (int argc, char **argv)
{
  ndisks = argc - 1;
  if (!ndisks)
    {
      fprintf (stderr, "Error: no disk specified\n");
      exit (EXIT_FAILURE);
    }
  diskfd = malloc (sizeof *diskfd * ndisks);
  if (!diskfd)
    {
      perror ("malloc");
      exit (EXIT_FAILURE);
    }
  diskmtim = malloc (sizeof *diskmtim * ndisks);
  if (!diskmtim)
    {
      perror ("malloc");
      exit (EXIT_FAILURE);
    }
  char **disks = &argv[1];
  for (int i = 0; i < ndisks; i++)
    {
      int fd = open (disks[i], O_RDWR);
      if (fd < 0)
	{
	  fd = open (disks[i], O_RDONLY);
	  if (fd < 0)
	    {
	      perror ("open");
	      exit (EXIT_FAILURE);
	    }
	}
      struct stat s;
      int statok = 0;
      if (fstat (fd, &s) < 0)
	perror ("fstat");
      else if ((s.st_mode & S_IFMT) == S_IFREG)
	statok = 1;
      diskfd[i] = fd;
      diskmtim[i].tv_sec = statok ? s.st_mtim.tv_sec : 0;
      diskmtim[i].tv_nsec = statok ? s.st_mtim.tv_nsec : 1;
    }
}

void
set_memory (void *m, uint32_t ramsize)
{
  mem = m;
  ram_size = ramsize;
  mem[0xffff0] = 0xe6;		/* OUT 80H,AL */
  mem[0xffff1] = 0x80;
  mem[0xffff2] = 0xea;		/* JMP 8000H:0000H */
  mem[0xffff3] = 0;
  mem[0xffff4] = 0;
  mem[0xffff5] = 0;
  mem[0xffff6] = 0x80;
  mem[0xffff7] = 0xe7;		/* OUT 86H,AX */
  mem[0xffff8] = 0x86;
  mem[0xffff9] = 0xcf;		/* IRET */
}

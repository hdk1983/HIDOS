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
#include <x86emu.h>
#include "common.h"

static uint8_t mem[MEMSIZE8086];

static unsigned
memio_handler (x86emu_t *vm, u32 addr, u32 *val, unsigned type)
{
  switch (type)
    {
    case X86EMU_MEMIO_X | X86EMU_MEMIO_8:
    case X86EMU_MEMIO_X | X86EMU_MEMIO_8_NOPERM:
      /* Trap flag (TF) support hack for debugging! */
      if (vm->x86.R_EFLG & F_TF)
	x86emu_intr_raise (vm, 1, INTR_TYPE_SOFT, 0);
      /* Fall through */
    case X86EMU_MEMIO_R | X86EMU_MEMIO_8:
    case X86EMU_MEMIO_R | X86EMU_MEMIO_8_NOPERM:
      *val = memr (addr);
      break;
    case X86EMU_MEMIO_R | X86EMU_MEMIO_16:
    case X86EMU_MEMIO_X | X86EMU_MEMIO_16:
      *val = memr2 (addr);
      break;
    case X86EMU_MEMIO_R | X86EMU_MEMIO_32:
    case X86EMU_MEMIO_X | X86EMU_MEMIO_32:
      *val = memr4 (addr);
      break;
    case X86EMU_MEMIO_W | X86EMU_MEMIO_8:
    case X86EMU_MEMIO_W | X86EMU_MEMIO_8_NOPERM:
      memw (addr, *val);
      break;
    case X86EMU_MEMIO_W | X86EMU_MEMIO_16:
      memw2 (addr, *val);
      break;
    case X86EMU_MEMIO_W | X86EMU_MEMIO_32:
      memw4 (addr, *val);
      break;
    case X86EMU_MEMIO_O | X86EMU_MEMIO_8:
    case X86EMU_MEMIO_O | X86EMU_MEMIO_8_NOPERM:
      if (addr == 0x80 && !load ())
	break;
      goto bad;
    case X86EMU_MEMIO_O | X86EMU_MEMIO_16:
      if (addr == 0x86 && !vmio (*val << 4))
	break;
      goto bad;
    case X86EMU_MEMIO_I | X86EMU_MEMIO_8:
    case X86EMU_MEMIO_I | X86EMU_MEMIO_8_NOPERM:
    case X86EMU_MEMIO_I | X86EMU_MEMIO_16:
    case X86EMU_MEMIO_I | X86EMU_MEMIO_32:
    case X86EMU_MEMIO_O | X86EMU_MEMIO_32:
    default:
    bad:
      if (conin (NULL) != -2)
	fprintf (stderr, "addr %x val %x type %x\r\n", addr, *val, type);
      x86emu_stop (vm);
    }
  return 0;
}

int
main (int argc, char **argv)
{
  init_common (argc, argv);
  set_memory (mem, 0xffff0);
  x86emu_t *vm = x86emu_new (0, 0);
  x86emu_set_memio_handler (vm, memio_handler);
  x86emu_reset (vm);
  x86emu_run (vm, 0);
  x86emu_done (vm);
  exit (EXIT_SUCCESS);
}

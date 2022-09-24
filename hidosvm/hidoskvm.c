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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <poll.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/kvm.h>
#include "common.h"

int
main (int argc, char **argv)
{
  init_common (argc, argv);
  int fd = open ("/dev/kvm", O_RDONLY);
  if (fd < 0)
    {
      perror ("open kvm");
      exit (EXIT_FAILURE);
    }
  int kvm_version = ioctl (fd, KVM_GET_API_VERSION, 0);
  if (kvm_version != 12)
    {
      fprintf (stderr, "kvm_version %d != 12\n", kvm_version);
      exit (EXIT_FAILURE);
    }
  if (ioctl (fd, KVM_CHECK_EXTENSION, KVM_CAP_USER_MEMORY) <= 0)
    {
      fprintf (stderr, "KVM_CAP_USER_MEMORY not available\n");
      exit (EXIT_FAILURE);
    }
  int vmfd = ioctl (fd, KVM_CREATE_VM, 0);
  if (vmfd < 0)
    {
      perror ("KVM_CREATE_VM");
      exit (EXIT_FAILURE);
    }
  char *mem = mmap (NULL, MEMSIZE8086, PROT_READ | PROT_WRITE,
		    MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (mem == MAP_FAILED)
    {
      perror ("mmap mem");
      exit (EXIT_FAILURE);
    }
  struct kvm_userspace_memory_region memregion[] =
    {
      {
	.slot = 0,
	.flags = 0,
	.guest_phys_addr = 0,
	.memory_size = 0xff000,
	.userspace_addr = (uintptr_t)mem,
      },
      {
	.slot = 1,
	.flags = KVM_MEM_READONLY,
	.guest_phys_addr = 0xff000,
	.memory_size = 0x1000,
	.userspace_addr = (uintptr_t)mem + 0xff000,
      },
      {
	.slot = 2,
	.flags = 0,
	.guest_phys_addr = 0x100000,
	.memory_size = 0x10000,
	.userspace_addr = (uintptr_t)mem,
      },
      {
	.slot = 3,
	.flags = KVM_MEM_READONLY,
	.guest_phys_addr = 0xfffff000,
	.memory_size = 0x1000,
	.userspace_addr = (uintptr_t)mem + 0xff000,
      },
    };
  for (int i = 0; i < sizeof memregion / sizeof memregion[0]; i++)
    {
      if (ioctl (vmfd, KVM_SET_USER_MEMORY_REGION, &memregion[i]))
	{
	  perror ("KVM_SET_USER_MEMORY_REGION");
	  exit (EXIT_FAILURE);
	}
    }
  int vcpufd = ioctl (vmfd, KVM_CREATE_VCPU, 0);
  if (vcpufd < 0)
    {
      perror ("KVM_CREATE_VCPU");
      exit (EXIT_FAILURE);
    }
  int vcpu_mmap_size = ioctl (fd, KVM_GET_VCPU_MMAP_SIZE, 0);
  if (vcpu_mmap_size < 0)
    {
      perror ("KVM_GET_VCPU_MMAP_SIZE");
      exit (EXIT_FAILURE);
    }
  struct kvm_run *kvm_run_structure = mmap (NULL, vcpu_mmap_size,
					    PROT_READ | PROT_WRITE, MAP_SHARED,
					    vcpufd, 0);
  if (kvm_run_structure == MAP_FAILED)
    {
      perror ("mmap vcpu");
      exit (EXIT_FAILURE);
    }
  set_memory (mem, 0xff000);
  for (;;)
    {
      if (ioctl (vcpufd, KVM_RUN, 0))
	{
	  perror ("KVM_RUN");
	  exit (EXIT_FAILURE);
	}
      switch (kvm_run_structure->exit_reason)
	{
	  uint8_t *io_data, io_size;
	case KVM_EXIT_IO:
	  io_data = kvm_run_structure->io.data_offset +
	    (uint8_t *)kvm_run_structure;
	  io_size = kvm_run_structure->io.size;
	  switch (kvm_run_structure->io.direction)
	    {
	    case KVM_EXIT_IO_OUT:
	      switch (kvm_run_structure->io.port)
		{
		case 0x80:
		  if (io_size == 1 && !load ())
		    break;
		  goto bad;
		case 0x86:
		  if (io_size == 2)
		    {
		      uint16_t val;
		      memcpy (&val, io_data, sizeof val);
		      if (!vmio (val << 4))
			break;
		    }
		  goto bad;
		default:
		  goto bad;
		}
	      break;
	    default:
	    bad:
	      if (conin (NULL) != -2)
		fprintf (stderr, "unexpected io port %x dir %x\r\n",
			 (unsigned int)kvm_run_structure->io.port,
			 (unsigned int)kvm_run_structure->io.direction);
	      exit (EXIT_FAILURE);
	    }
	  break;
	case KVM_EXIT_HLT:
	  fprintf (stderr, "HLT!\r\n");
	  exit (EXIT_SUCCESS);
	  break;
	case KVM_EXIT_MMIO:
	  break;
	default:
	  fprintf (stderr, "unexpected exit reason %x\r\n",
		   (unsigned int)kvm_run_structure->exit_reason);
	  exit (EXIT_FAILURE);
	}
    }
}

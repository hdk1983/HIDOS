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

	.text
#ifdef __WIN32__
#define close _close
#define creat _creat
#define dup _dup
#define exit _exit
#define getchar _getchar
#define gmtime _gmtime
#define lseek64 _lseek64
#define main _main
#define open _open
#define printf _printf
#define read _read
#define time _time
#define write _write
#define SET_BINARY(a) pushl $0x8000; pushl a; call _setmode; add $4*2,%esp
#else
#define SET_BINARY(a)
#endif
main:	.global	main
	push	%ebp
	mov	%esp,%ebp
	pushl	$1
	call	dup		/* for fd=3 AUX */
	pushl	$2
	call	dup		/* for fd=4 PRN */
	cmpl	$2,4*2(%ebp)	/* argc */
	jae	1f
	pushl	$3f-2f
	pushl	$2f
	pushl	$2
	.section .rodata
2:	.ascii	"Parameter error\n"
3:	.text
	call	write
	push	$1
	call	exit
1:	mov	4*3(%ebp),%ebx	/* argv */
	pushl	$0
	pushl	4*1(%ebx)	/* argv[1] */
	call	open
	test	%eax,%eax
	jns	1f
	pushl	$3f-2f
	pushl	$2f
	pushl	$2
	.section .rodata
2:	.ascii	"Open error\n"
3:	.text
	call	write
	push	$1
	call	exit
1:	mov	%eax,%ebx
	pushl	$0x20000
	pushl	$code
	push	%ebx
	call	read
	cmp	$1,%eax
	jnl	1f
	pushl	$3f-2f
	pushl	$2f
	pushl	$2
	.section .rodata
2:	.ascii	"Read error\n"
3:	.text
	call	write
	push	$1
	call	exit
1:	push	%ebx
	call	close
	SET_BINARY($1)
	mov	%ebp,%esp
	/* Create Program Segment Prefix */
	cld
	movw	$0x20cd,psp+0x0
	movw	$(memend-mem-1)/16,psp+0x2
	movb	$0,psp+0x80
	mov	4*3(%ebp),%ebx	/* argv */
	mov	4*2(%ebx),%esi	/* argv[2] */
	mov	$psp+0x81,%edi
	test	%esi,%esi
	je	3f
2:	add	$4,%ebx
	mov	$' ',%al
1:	stosb
	incb	psp+0x80
	lodsb
	cmp	$0,%al
	jne	1b
	mov	4*2(%ebx),%esi
	test	%esi,%esi
	jne	2b
3:	mov	$'\r',%al
	stosb
	/* Relocate EXE */
	cmpw	$'M'|'Z'<<8,code
	jne	com
	movzwl	code+0x8,%eax	/* Header size in paragraph */
	add	$(code-mem)/16,%eax /* Start segment */
	lea	(,%eax,4),%ebx
	lea	mem(,%ebx,4),%ebx /* Start address */
	add	%ax,code+0xe	/* Initial SS */
	add	%ax,code+0x16	/* Initial CS */
	movzwl	code+0x6,%ecx	/* Number of relocation */
	movzwl	code+0x18,%esi	/* Relocation table offset */
	lea	code(%esi),%esi
	mov	%eax,%edx
	movzwl	code+0xe,%eax	/* Relocated SS */
	mov	%ax,sgval+2*2
	shl	$4,%eax
	mov	%eax,sgb_ss
	movzwl	code+0x10,%eax	/* Initial SP */
	mov	%ax,gr_sp
	movzwl	code+0x14,%eax	/* Initial IP */
	mov	%ax,ip
	movzwl	code+0x16,%eax	/* Relocated CS */
	mov	%ax,sgval+2*1
	shl	$4,%eax
	mov	%eax,sgb_cs
	jecxz	com
1:	xor	%eax,%eax
	lodsw
	mov	%eax,%edi
	lodsw
	shl	$4,%eax
	add	%edi,%eax
	add	%dx,(%ebx,%eax)
	loop	1b
com:	/* Start program! */
	mov	sgb_cs,%ebp
	movzwl	ip,%eax
	add	%eax,%ebp
	cld
	xor	%eax,%eax	/* Clean flags */
	/* From here keep flags register for the code! */
mnext:
mloop:	movl	$0,prefix
mpre:	movzbl	mem(%ebp),%eax
	/*call	dbg*/
	lea	1(%ebp),%ebp
	jmp	*itbl(,%eax,4)
mjnear:	call	getip
	lea	(%eax,%edx),%eax
mnextj:	movzwl	%ax,%eax
	mov	sgb_cs,%ebp
	lea	(%ebp,%eax),%ebp
	jmp	mloop

dbg:	pushf
	pusha
	movzwl	gr_di,%eax
	push	%eax
	movzbl	mem(%ebp),%eax
	push	%eax
	movzwl	gr_sp,%eax
	push	%eax
	pushl	sgb_ss
	sub	sgb_cs,%ebp
	push	%ebp
	pushl	sgb_cs
	push	$2f
	.section .rodata
2:	.string	"cs:ip %x:%x ss:sp %x:%x opcode %x di=%x\n"
	.text
	call	printf
	lea	4*7(%esp),%esp
	popa
	popf
	ret

inthdl:	cmp	$0x20,%al
	jne	1f
	pushl	$0
	call	exit
1:	cmp	$0x21,%al
	jne	badsys
	andl	$~1,4*9(%esp)
	movzbl	gr_ah,%eax
	cmp	$0x30,%al	/* Get version */
	jne	1f
	movw	$0xb02,gr_ax
	ret
1:	cmp	$0x25,%al
	jne	1f
	movzbl	gr_al,%eax
	movzwl	gr_bx,%ebx
	mov	%bx,mem(,%eax,4)
	mov	sgb_es,%ebx
	shr	$4,%ebx
	mov	%bx,mem+2(,%eax,4)
	ret
1:	cmp	$0x40,%al	/* Write */
	jne	1f
	movzwl	gr_cx,%eax
	push	%eax
	movzwl	gr_dx,%eax
	add	sgb_ds,%eax
	add	$mem,%eax
	push	%eax
	movzwl	gr_bx,%eax
	push	%eax
	call	write
	add	$4*3,%esp
	test	%eax,%eax
	js	doserr
	mov	%ax,gr_ax
	ret
doserr:	mov	$1,%eax
doser2:	mov	%ax,gr_ax
	orl	$1,4*9(%esp)
	ret
1:	cmp	$0x2a,%al	/* Get date */
	jne	1f
	sub	$0x10,%esp
	lea	4(%esp),%eax
	mov	%eax,(%esp)
	call	time
	lea	4(%esp),%eax
	mov	%eax,(%esp)
	call	gmtime
	mov	4*5(%eax),%ebx	/* tm_year */
	add	$1900,%ebx
	mov	%bx,gr_cx
	mov	4*4(%eax),%ebx	/* tm_mon */
	inc	%ebx
	mov	%bl,%bh
	mov	4*3(%eax),%bl	/* tm_mday */
	mov	%bx,gr_dx
	add	$0x10,%esp
	ret
1:	cmp	$0xa,%al	/* Buffered input */
	jne	1f
	movzwl	gr_dx,%ebx
	add	sgb_ds,%ebx
	add	$mem,%ebx
	xor	%ecx,%ecx
2:	mov	%cl,1(%ebx)
	cmp	%cl,(%ebx)
	je	2f
	call	getchar
	movzbl	1(%ebx),%ecx
	cmp	$'\n',%al
	je	2f
	test	%eax,%eax
	js	2f
	mov	%al,2(%ebx,%ecx)
	inc	%ecx
	jmp	2b
2:	movb	$'\r',2(%ebx,%ecx)
	ret
1:	cmp	$0x3c,%al	/* Creat */
	jne	1f
	pushl	$0666
	call	filnam
	push	%eax
	call	creat
	add	$4*2,%esp
	test	%eax,%eax
	js	doserr
	mov	%ax,gr_ax
	SET_BINARY(%eax)
	ret
1:	cmp	$0x3d,%al	/* Open */
	jne	1f
	pushl	$-1
	movzbl	gr_al,%eax
	push	%eax
	call	filnam
	push	%eax
	call	open
	add	$4*3,%esp
	test	%eax,%eax
	js	doserr
	mov	%ax,gr_ax
	SET_BINARY(%eax)
	ret
1:	cmp	$0x3f,%al	/* Read */
	jne	1f
	movzwl	gr_cx,%eax
	push	%eax
	movzwl	gr_dx,%eax
	add	sgb_ds,%eax
	add	$mem,%eax
	push	%eax
	movzwl	gr_bx,%eax
	push	%eax
	call	read
	add	$4*3,%esp
	test	%eax,%eax
	js	doserr
	mov	%ax,gr_ax
	ret
1:	cmp	$0x42,%al	/* LSeek */
	jne	1f
	movzbl	gr_al,%eax
	push	%eax
	movzwl	gr_cx,%eax
	shl	$16,%eax
	mov	gr_dx,%ax
	push	%eax
	pushl	%eax
	sarl	$31,4(%esp)
	movzwl	gr_bx,%eax
	push	%eax
	call	lseek64
	add	$4*4,%esp
	test	%eax,%eax
	js	doserr
	mov	%ax,gr_ax
	shr	$16,%eax
	mov	%ax,gr_dx
	ret
1:	cmp	$0x3e,%al	/* Close */
	jne	1f
	movzwl	gr_bx,%eax
	push	%eax
	call	close
	add	$4*1,%esp
	test	%eax,%eax
	js	doserr
	movw	$0,gr_ax
	ret
1:	cmp	$0x4c,%al	/* Exit */
	jne	1f
	movzbl	gr_al,%eax
	push	%eax
	call	exit
1:	cmp	$0x37,%al	/* CharOper */
	jne	1f
	movzbl	gr_al,%eax
	cmp	$0,%al
	jne	2f
	movzbl	swtchr,%eax
	mov	%al,gr_dx
	ret
2:	cmp	$1,%al
	jne	2f
	movzbl	gr_dx,%eax
	mov	%al,swtchr
	ret
2:	cmp	$2,%al
	jne	2f
	movzbl	devavl,%eax
	mov	%al,gr_dx
	ret
2:	cmp	$3,%al
	jne	2f
	movzbl	gr_dx,%eax
	mov	%al,devavl
	ret
2:	mov	$0xff,%al
	jmp	doser2
1:	cmp	$0x19,%al	/* Get default drive */
	jne	1f
	movb	$0,gr_al
	ret
1:	cmp	$0x9,%al	/* Write string */
	jne	1f
	movzwl	gr_dx,%eax
	add	sgb_ds,%eax
	add	$mem,%eax
	lea	-1(%eax),%ebx
2:	inc	%ebx
	cmpb	$'$',(%ebx)
	jne	2b
	sub	%eax,%ebx
	push	%ebx
	push	%eax
	pushl	$1
	call	write
	add	$4*3,%esp
	ret
1:	/* Not yet implemented */
	jmp	badsys

/* LINK seems to add default drive. Get DS:DX and remove drive. */
filnam:	movzwl	gr_dx,%eax
	add	sgb_ds,%eax
	add	$mem,%eax
	cmpw	$'A'|':'<<8,(%eax)
	jne	2f
	add	$2,%eax
2:	ret

badsys:	mov	4*8(%esp),%eax
	push	%eax
	movzwl	gr_di,%eax
	push	%eax
	movzwl	gr_si,%eax
	push	%eax
	movzwl	gr_bp,%eax
	push	%eax
	movzwl	gr_sp,%eax
	push	%eax
	movzwl	gr_bx,%eax
	push	%eax
	movzwl	gr_dx,%eax
	push	%eax
	movzwl	gr_cx,%eax
	push	%eax
	movzwl	gr_ax,%eax
	push	%eax
	pushl	sgb_ds
	pushl	sgb_ss
	pushl	sgb_cs
	pushl	sgb_es
	pushl	$2f
	.section .rodata
2:	.ascii	"System call es=%x cs=%x ss=%x ds=%x\n"
	.string	"ax=%x cx=%x dx=%x bx=%x sp=%x bp=%x si=%x di=%x int %x\n"
	.text
	call	printf
	push	$1
	call	exit
bad:
	pushl	$3f-2f
	pushl	$2f
	pushl	$2
	.section .rodata
2:	.ascii	"Bad instruction\n"
3:	.text
	call	write
	push	$1
	call	exit

/* ----- 8086 instructions implementation ----- */
.macro	i00like	s,a,b,c
	call	modrm
	call	mrmb
	mov	rbtbl(%edx),%dl
	lea	greg(%edx),%edx
	movzbl	(\s),\s
	\a	\b,\c
	jmp	mnext
.endm
.macro	i01like	s,a,b,c
	call	modrm
	call	mrmw
	lea	greg(%edx,%edx),%edx
	movzwl	(\s),\s
	\a	\b,\c
	jmp	mnext
.endm
.macro	i04like	a
	call	imm1
	\a	%al,gr_ax
	jmp	mnext
.endm
.macro	i05like	a
	call	imm2
	\a	%ax,gr_ax
	jmp	mnext
.endm
.macro	i06like	a
	mov	$\a,%edx
	call	pshseg
	jmp	mnext
.endm
.macro	i07like	a
	mov	$\a,%edx
	call	popseg
	jmp	mnext
.endm
.macro	i26like	a
	movb	$\a+1,prefix_seg
	jmp	mpre
.endm
.macro	i27like	a
	mov	gr_ax,%ax
	\a
	mov	%ax,gr_ax
	jmp	mnext
.endm
.macro	i40like	a,b
	\a	\b
	jmp	mnext
.endm
.macro	i50like	a
	movzwl	\a,%edx
	call	psh
	jmp	mnext
.endm
.macro	i58like	a
	call	pop
	mov	%di,\a
	jmp	mnext
.endm
.macro	i70like	a
	call	imm1
	\a	1f
	jmp	mnext
1:	movsbl	%al,%eax
	jmp	mjnear
.endm

i00:	i00like	%edx,add,%dl,(%eax)
i01:	i01like	%edx,add,%dx,(%eax)
i02:	i00like	%eax,add,%al,(%edx)
i03:	i01like	%eax,add,%ax,(%edx)
i04:	i04like	add
i05:	i05like	add
i06:	i06like	0
i07:	i07like	0
i08:	i00like	%edx,or,%dl,(%eax)
i09:	i01like	%edx,or,%dx,(%eax)
i0a:	i00like	%eax,or,%al,(%edx)
i0b:	i01like	%eax,or,%ax,(%edx)
i0c:	i04like	or
i0d:	i05like	or
i0e:	i06like	1
i0f:	i07like	1
i10:	i00like	%edx,adc,%dl,(%eax)
i11:	i01like	%edx,adc,%dx,(%eax)
i12:	i00like	%eax,adc,%al,(%edx)
i13:	i01like	%eax,adc,%ax,(%edx)
i14:	i04like	adc
i15:	i05like	adc
i16:	i06like	2
i17:	i07like	2
i18:	i00like	%edx,sbb,%dl,(%eax)
i19:	i01like	%edx,sbb,%dx,(%eax)
i1a:	i00like	%eax,sbb,%al,(%edx)
i1b:	i01like	%eax,sbb,%ax,(%edx)
i1c:	i04like	sbb
i1d:	i05like	sbb
i1e:	i06like	3
i1f:	i07like	3
i20:	i00like	%edx,and,%dl,(%eax)
i21:	i01like	%edx,and,%dx,(%eax)
i22:	i00like	%eax,and,%al,(%edx)
i23:	i01like	%eax,and,%ax,(%edx)
i24:	i04like	and
i25:	i05like	and
i26:	i26like	0
i27:	i27like	daa
i28:	i00like	%edx,sub,%dl,(%eax)
i29:	i01like	%edx,sub,%dx,(%eax)
i2a:	i00like	%eax,sub,%al,(%edx)
i2b:	i01like	%eax,sub,%ax,(%edx)
i2c:	i04like	sub
i2d:	i05like	sub
i2e:	i26like	1
i2f:	i27like	das
i30:	i00like	%edx,xor,%dl,(%eax)
i31:	i01like	%edx,xor,%dx,(%eax)
i32:	i00like	%eax,xor,%al,(%edx)
i33:	i01like	%eax,xor,%ax,(%edx)
i34:	i04like	xor
i35:	i05like	xor
i36:	i26like	2
i37:	i27like	aaa
i38:	i00like	%edx,cmp,%dl,(%eax)
i39:	i01like	%edx,cmp,%dx,(%eax)
i3a:	i00like	%eax,cmp,%al,(%edx)
i3b:	i01like	%eax,cmp,%ax,(%edx)
i3c:	i04like	cmp
i3d:	i05like	cmp
i3e:	i26like	3
i3f:	i27like	aas
i40:	i40like	incw,gr_ax
i41:	i40like	incw,gr_cx
i42:	i40like	incw,gr_dx
i43:	i40like	incw,gr_bx
i44:	i40like	incw,gr_sp
i45:	i40like	incw,gr_bp
i46:	i40like	incw,gr_si
i47:	i40like	incw,gr_di
i48:	i40like	decw,gr_ax
i49:	i40like	decw,gr_cx
i4a:	i40like	decw,gr_dx
i4b:	i40like	decw,gr_bx
i4c:	i40like	decw,gr_sp
i4d:	i40like	decw,gr_bp
i4e:	i40like	decw,gr_si
i4f:	i40like	decw,gr_di
i50:	i50like	gr_ax
i51:	i50like	gr_cx
i52:	i50like	gr_dx
i53:	i50like	gr_bx
i54:	i50like	gr_sp
i55:	i50like	gr_bp
i56:	i50like	gr_si
i57:	i50like	gr_di
i58:	i58like	gr_ax
i59:	i58like	gr_cx
i5a:	i58like	gr_dx
i5b:	i58like	gr_bx
i5c:	i58like	gr_sp
i5d:	i58like	gr_bp
i5e:	i58like	gr_si
i5f:	i58like	gr_di
i70:	i70like	jo
i71:	i70like	jno
i72:	i70like	jb
i73:	i70like	jnb
i74:	i70like	je
i75:	i70like	jne
i76:	i70like	jbe
i77:	i70like	jnbe
i78:	i70like	js
i79:	i70like	jns
i7a:	i70like	jp
i7b:	i70like	jnp
i7c:	i70like	jl
i7d:	i70like	jge
i7e:	i70like	jle
i7f:	i70like	jg
i80:	call	modrm
	call	mrmb
	movzbl	mem(%ebp),%ebx
	lea	1(%ebp),%ebp
	jmp	*tbl1b(,%edx,4)
i81:	call	modrm
	call	mrmw
	movzwl	mem(%ebp),%ebx
	lea	2(%ebp),%ebp
	jmp	*tbl1w(,%edx,4)
i82=i80
i83:	call	modrm
	call	mrmw
	movsbl	mem(%ebp),%ebx
	lea	1(%ebp),%ebp
	jmp	*tbl1w(,%edx,4)
i84:	i00like	%edx,test,%dl,(%eax)
i85:	i01like	%edx,test,%dx,(%eax)
i86:	call	modrm
	call	mrmb
	mov	rbtbl(%edx),%dl
	lea	greg(%edx),%edx
	movzbl	(%edx),%ecx
	movzbl	(%eax),%ebx
	mov	%cl,(%eax)
	mov	%bl,(%edx)
	jmp	mnext
i87:	call	modrm
	call	mrmw
	lea	greg(%edx,%edx),%edx
	movzwl	(%edx),%ecx
	movzwl	(%eax),%ebx
	mov	%cx,(%eax)
	mov	%bx,(%edx)
	jmp	mnext
i88:	i00like	%edx,mov,%dl,(%eax)
i89:	i01like	%edx,mov,%dx,(%eax)
i8a:	i00like	%eax,mov,%al,(%edx)
i8b:	i01like	%eax,mov,%ax,(%edx)
i8c:	call	modrm
	call	mrmw
	movzbl	stbl(%edx),%edx
	movzwl	sgval(%edx,%edx),%edx
	mov	%dx,(%eax)
	jmp	mnext
i8d:	call	modrm
	mov	%ax,greg(%edx,%edx)
	jmp	mnext
i8e:	call	modrm
	call	mrmw
	movzbl	stbl(%edx),%edx
	movzwl	(%eax),%edi
	call	setseg
	jmp	mnext
i8f:	call	modrm
	call	mrmw
	mov	%eax,%ebx
	call	pop
	mov	%di,(%ebx)
	jmp	mnext

.macro	i90like	a
	movzwl	gr_ax,%eax
	movzwl	\a,%edx
	mov	%ax,\a
	mov	%dx,gr_ax
	jmp	mnext
.endm

i90:	i90like	gr_ax
i91:	i90like	gr_cx
i92:	i90like	gr_dx
i93:	i90like	gr_bx
i94:	i90like	gr_sp
i95:	i90like	gr_bp
i96:	i90like	gr_si
i97:	i90like	gr_di
i98:	i27like	cbtw
i99:	mov	gr_ax,%ax
	cwtd
	mov	%dx,gr_dx
	jmp	mnext
i9a:	mov	$1,%edx
	call	pshseg
	call	getip
	lea	4(%edx),%edx
	call	psh
	jmp	iea
i9c:	pushf
	pop	%edx
	call	psh
	jmp	mnext
i9d:	call	pop
	push	%edi
	popf
	jmp	mnext
i9e:	i27like	sahf
i9f:	i27like	lahf

.macro	ia0like	a,b,c,d,e,f
	call	imm2
	mov	$3,%ecx
	call	mrmb
	\a	\b,\c
	\d	\e,\f
	jmp	mnext
.endm
.macro	ia1like	a,b,c,d,e,f
	call	imm2
	mov	$3,%edi
	call	memw
	\a	\b,\c
	\d	\e,\f
	jmp	mnext
.endm
ia0:	ia0like	movzbl,(%eax),%edx,mov,%dl,gr_al
ia1:	ia1like	movzwl,(%eax),%edx,mov,%dx,gr_ax
ia2:	ia0like	movzbl,gr_al,%edx,mov,%dl,(%eax)
ia3:	ia1like	movzwl,gr_ax,%edx,mov,%dx,(%eax)

.macro	ia4like	a
	movzbl	prefix_rep,%ecx
	jecxz	1f
2:	movzwl	gr_cx,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	mov	%cx,gr_cx
1:	call	strsi
	mov	%eax,%esi
	call	strdi
	\a
	not	%eax
	lea	1(%eax,%esi),%eax
	movzwl	gr_si,%edx
	lea	(%edx,%eax),%edx
	mov	%dx,gr_si
	movzwl	gr_di,%edx
	lea	(%edx,%eax),%edx
	mov	%dx,gr_di
	movzbl	prefix_rep,%ecx
	jecxz	2f
	jmp	2b
2:	jmp	mnext
.endm
.macro	ia6like	a
	movzbl	prefix_rep,%ecx
	jecxz	1f
2:	movzwl	gr_cx,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	mov	%cx,gr_cx
1:	call	strsi
	mov	%eax,%esi
	call	strdi
	\a
	not	%eax
	lea	1(%eax,%esi),%eax
	movzwl	gr_si,%edx
	lea	(%edx,%eax),%edx
	mov	%dx,gr_si
	movzwl	gr_di,%edx
	lea	(%edx,%eax),%edx
	mov	%dx,gr_di
	movzbl	prefix_rep,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	jecxz	3f
	je	2b
	jmp	mnext
3:	jne	2b
2:	jmp	mnext
.endm
ia4:	ia4like	movsb
ia5:	ia4like	movsw
ia6:	ia6like	cmpsb
ia7:	ia6like	cmpsw
ia8:	i04like	test
ia9:	i05like	test

.macro	iaalike	a
	movzbl	prefix_rep,%ecx
	jecxz	1f
2:	movzwl	gr_cx,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	mov	%cx,gr_cx
1:	call	strdi
	mov	%edi,%ebx
	movzwl	gr_ax,%eax
	\a
	not	%ebx
	lea	1(%ebx,%edi),%ebx
	movzwl	gr_di,%edx
	lea	(%edx,%ebx),%edx
	mov	%dx,gr_di
	movzbl	prefix_rep,%ecx
	jecxz	2f
	jmp	2b
2:	jmp	mnext
.endm
.macro	iaclike	a,b
	movzbl	prefix_rep,%ecx
	jecxz	1f
2:	movzwl	gr_cx,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	mov	%cx,gr_cx
1:	call	strsi
	mov	%eax,%esi
	mov	%eax,%ebx
	\a
	mov	\b,gr_ax
	not	%ebx
	lea	1(%ebx,%esi),%ebx
	movzwl	gr_si,%edx
	lea	(%edx,%ebx),%edx
	mov	%dx,gr_si
	movzbl	prefix_rep,%ecx
	jecxz	2f
	jmp	2b
2:	jmp	mnext
.endm
.macro	iaelike	a
	movzbl	prefix_rep,%ecx
	jecxz	1f
2:	movzwl	gr_cx,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	mov	%cx,gr_cx
1:	call	strdi
	mov	%edi,%ebx
	movzwl	gr_ax,%eax
	\a
	not	%ebx
	lea	1(%ebx,%edi),%ebx
	movzwl	gr_di,%edx
	lea	(%edx,%ebx),%edx
	mov	%dx,gr_di
	movzbl	prefix_rep,%ecx
	jecxz	2f
	lea	-1(%ecx),%ecx
	jecxz	3f
	je	2b
	jmp	mnext
3:	jne	2b
2:	jmp	mnext
.endm
iaa:	iaalike	stosb
iab:	iaalike	stosw
iac:	iaclike	lodsb,%al
iad:	iaclike	lodsw,%ax
iae:	iaelike	scasb
iaf:	iaelike	scasw

.macro	ib0like	a,b,c
	call	\a
	mov	\b,\c
	jmp	mnext
.endm
ib0:	ib0like	imm1,%al,gr_al
ib1:	ib0like	imm1,%al,gr_cl
ib2:	ib0like	imm1,%al,gr_dl
ib3:	ib0like	imm1,%al,gr_bl
ib4:	ib0like	imm1,%al,gr_ah
ib5:	ib0like	imm1,%al,gr_ch
ib6:	ib0like	imm1,%al,gr_dh
ib7:	ib0like	imm1,%al,gr_bh
ib8:	ib0like	imm2,%ax,gr_ax
ib9:	ib0like	imm2,%ax,gr_cx
iba:	ib0like	imm2,%ax,gr_dx
ibb:	ib0like	imm2,%ax,gr_bx
ibc:	ib0like	imm2,%ax,gr_sp
ibd:	ib0like	imm2,%ax,gr_bp
ibe:	ib0like	imm2,%ax,gr_si
ibf:	ib0like	imm2,%ax,gr_di
ic2:	call	imm2
	mov	%eax,%edx
1:	movzwl	gr_sp,%eax
	mov	sgb_ss,%edi
	movzwl	mem(%eax,%edi),%edi
	lea	2(%eax,%edx),%eax
	movw	%ax,gr_sp
	mov	%edi,%eax
	jmp	mnextj
ic3:	mov	$0,%edx
	jmp	1b
ic4:	call	modrm
	call	mrmw
	lea	greg(%edx,%edx),%edx
	movzwl	(%eax),%ecx
	mov	%cx,(%edx)
	movzwl	2(%eax),%edi
	mov	$0,%edx
	call	setseg
	jmp	mnext
ic5:	call	modrm
	call	mrmw
	lea	greg(%edx,%edx),%edx
	movzwl	(%eax),%ecx
	mov	%cx,(%edx)
	movzwl	2(%eax),%edi
	mov	$3,%edx
	call	setseg
	jmp	mnext
ic6:	call	modrm
	call	mrmb
	mov	%eax,%ebx
	call	imm1
	mov	%al,(%ebx)
	jmp	mnext
ic7:	call	modrm
	call	mrmw
	mov	%eax,%ebx
	call	imm2
	mov	%ax,(%ebx)
	jmp	mnext
ica:	call	imm2
	mov	%eax,%edx
1:	movzwl	gr_sp,%eax
	mov	sgb_ss,%edi
	movzwl	mem(%eax,%edi),%esi
	lea	2(%eax),%eax
	movzwl	%ax,%eax
	movzwl	mem(%eax,%edi),%edi
	lea	2(%eax,%edx),%eax
	movw	%ax,gr_sp
	mov	$1,%edx
	mov	%esi,%eax
	call	setseg
	jmp	mnextj
icb:	mov	$0,%edx
	jmp	1b
icd:	call	imm1
	pushf
	pusha
	call	inthdl
	popa
	popf
	jmp	mnext
icf:	movzwl	gr_sp,%eax
	mov	sgb_ss,%edi
	movzwl	mem(%eax,%edi),%esi
	add	$2,%ax
	movzwl	mem(%eax,%edi),%ebx
	add	$2,%ax
	movzwl	mem(%eax,%edi),%edi
	add	$2,%ax
	movw	%ax,gr_sp
	push	%edi
	popf
	mov	$1,%edx
	mov	%ebx,%edi
	mov	%esi,%eax
	call	setseg
	jmp	mnextj
id0:	call	modrm
	call	mrmb
	mov	$1,%ecx
	jmp	*tbl2b(,%edx,4)
id1:	call	modrm
	call	mrmw
	mov	$1,%ecx
	jmp	*tbl2w(,%edx,4)
id2:	call	modrm
	call	mrmb
	movzbl	gr_cx,%ecx
	jmp	*tbl2b(,%edx,4)
id3:	call	modrm
	call	mrmw
	movzbl	gr_cx,%ecx
	jmp	*tbl2w(,%edx,4)
id4:	call	imm1
	mov	%eax,%edx
	movzbl	gr_ax,%eax
	div	%dl
	xchg	%ah,%al
	mov	%ax,gr_ax
	test	%al,%al
	jmp	mnext
id5:	call	imm1
	mov	%eax,%edx
	movzbl	gr_ah,%eax
	mul	%dl
	add	gr_al,%al
	movzbl	%al,%eax
	mov	%ax,gr_ax
	jmp	mnext
id6:	.byte	0xd6
	mov	%al,gr_al
	jmp	mnext
id7:	movzwl	gr_bx,%edx
	movzbl	gr_al,%eax
	lea	(%eax,%edx),%eax
	movzwl	%ax,%eax
	mov	$3,%edi
	call	memb
	movzbl	(%eax),%eax
	mov	%al,gr_al
	jmp	mnext
ie0:	call	imm1
	movzwl	gr_cx,%ecx
	loopne	1f
	mov	%cx,gr_cx
	jmp	mnext
1:	mov	%cx,gr_cx
	movsbl	%al,%eax
	jmp	mjnear
ie1:	call	imm1
	movzwl	gr_cx,%ecx
	loope	1f
	mov	%cx,gr_cx
	jmp	mnext
1:	mov	%cx,gr_cx
	movsbl	%al,%eax
	jmp	mjnear
ie2:	call	imm1
	movzwl	gr_cx,%ecx
	loop	1f
	mov	%cx,gr_cx
	jmp	mnext
1:	mov	%cx,gr_cx
	movsbl	%al,%eax
	jmp	mjnear
ie3:	call	imm1
	movzwl	gr_cx,%ecx
	jecxz	1f
	jmp	mnext
1:	movsbl	%al,%eax
	jmp	mjnear
ie8:	call	imm2
	mov	%eax,%ecx
	call	getip
	call	psh
	lea	(%edx,%ecx),%eax
	jmp	mnextj
ie9:	call	imm2
	jmp	mjnear
iea:	call	imm2
	mov	%eax,%ecx
	call	imm2
	mov	$1,%edx
	mov	%eax,%edi
	mov	%ecx,%eax
	call	setseg
	jmp	mnextj
ieb:	call	imm1
	movsbl	%al,%eax
	jmp	mjnear
if0:	jmp	mpre
if2:	movb	$1,prefix_rep
	jmp	mpre
if3:	movb	$2,prefix_rep
	jmp	mpre

.macro	if5like	a
	\a
	jmp	mnext
.endm
if5:	if5like	cmc
if6:	call	modrm
	call	mrmb
	jmp	*tbl3b(,%edx,4)
if7:	call	modrm
	call	mrmw
	jmp	*tbl3w(,%edx,4)
if8:	if5like	clc
if9:	if5like	stc
ifa=i90
ifb=i90
ifc:	if5like	cld
ifd:	if5like	std
ife:	call	modrm
	call	mrmb
	jmp	*tbl4(,%edx,4)
iff:	call	modrm
	call	mrmw
	jmp	*tbl5(,%edx,4)

pshseg:	movzwl	sgval(%edx,%edx),%edx
psh:	movzwl	gr_sp,%eax
	mov	sgb_ss,%edi
	lea	-2(%eax),%eax
	movzwl	%ax,%eax
	movw	%ax,gr_sp
	mov	%dx,mem(%eax,%edi)
	ret
pop:	movzwl	gr_sp,%eax
	mov	sgb_ss,%edi
	movzwl	mem(%eax,%edi),%edi
	lea	2(%eax),%eax
	movw	%ax,gr_sp
	ret
popseg:	call	pop
setseg:	mov	%di,sgval(%edx,%edx)
	lea	(,%edi,4),%edi
	lea	(,%edi,4),%edi
	mov	%edi,sgbase(,%edx,4)
	ret
mrmb:	jecxz	1f
	mov	%ecx,%edi
memb:	movzbl	prefix_seg,%ecx
	jecxz	2f
	lea	-1(%ecx),%edi
2:	mov	sgbase(,%edi,4),%edi
	lea	mem(%edi,%eax),%eax
	ret
1:	mov	rbtbl(%eax),%al
	lea	greg(%eax),%eax
	ret
mrmw:	jecxz	1f
	mov	%ecx,%edi
memw:	movzbl	prefix_seg,%ecx
	jecxz	2f
	lea	-1(%ecx),%edi
2:	mov	sgbase(,%edi,4),%edi
	lea	mem(%edi,%eax),%eax
	ret
1:	lea	greg(%eax,%eax),%eax
	ret
imm1:	movzbl	mem(%ebp),%eax
	lea	1(%ebp),%ebp
	ret
imm2:	movzwl	mem(%ebp),%eax
	lea	2(%ebp),%ebp
	ret
strsi:	movzwl	gr_si,%eax
	mov	$3,%edi
	jmp	memw
strdi:	mov	sgb_es,%edi
	movzwl	gr_di,%ecx
	lea	mem(%ecx,%edi),%edi
	ret
getip:	mov	sgb_cs,%edx
	not	%edx
	lea	1(%edx,%ebp),%edx
	ret

	/* Output:
	   %ecx=2:memory(%bp) %eax=memory offset
	   %ecx=3:memory(not %bp) %eax=memory offset
	   %ecx=0:register %eax=register index
	   %edx:REG field
	*/
modrm:	movzbl	mem(%ebp),%eax
	lea	1(%ebp),%ebp
	movzbl	%ah,%edx
	lea	(,%eax,4),%eax
	xchg	%ah,%dl
	lea	(,%eax,4),%eax
	lea	(%eax,%eax),%eax
	xchg	%ah,%dl
	lea	(,%eax,4),%eax
	lea	(%eax,%eax),%eax
	xchg	%ah,%al
	jmp	*mrtbl(,%eax,4)

m00:	movzwl	gr_bx,%eax
	movzwl	gr_si,%ecx
m0p:	lea	(%eax,%ecx),%eax
	movzwl	%ax,%eax
m0:	mov	$3,%ecx
	ret
m0ssp:	lea	(%eax,%ecx),%eax
	movzwl	%ax,%eax
	mov	$2,%ecx
	ret
.macro	modrmmp	j,reg1,reg2
	movzwl	\reg1,%eax
	movzwl	\reg2,%ecx
	jmp	\j
.endm
.macro	modrmm	j,reg1
	movzwl	\reg1,%eax
	jmp	\j
.endm
m01:	modrmmp	m0p,gr_bx,gr_di
m02:	modrmmp	m0ssp,gr_bp,gr_si
m03:	modrmmp	m0ssp,gr_bp,gr_di
m04:	modrmm	m0,gr_si
m05:	modrmm	m0,gr_di
m06:	mov	$3,%ecx
	jmp	imm2
m07:	modrmm	m0,gr_bx
m10:	movzwl	gr_bx,%eax
	movzwl	gr_si,%ecx
m1p:	lea	(%eax,%ecx),%eax
m1:	movsbl	mem(%ebp),%ecx
	lea	1(%ebp),%ebp
	lea	(%eax,%ecx),%eax
	movzwl	%ax,%eax
	mov	$3,%ecx
	ret
m1ssp:	lea	(%eax,%ecx),%eax
m1ss:	movsbl	mem(%ebp),%ecx
	lea	1(%ebp),%ebp
	lea	(%eax,%ecx),%eax
	movzwl	%ax,%eax
	mov	$2,%ecx
	ret
m11:	modrmmp	m1p,gr_bx,gr_di
m12:	modrmmp	m1ssp,gr_bp,gr_si
m13:	modrmmp	m1ssp,gr_bp,gr_di
m14:	modrmm	m1,gr_si
m15:	modrmm	m1,gr_di
m16:	modrmm	m1ss,gr_bp
m17:	modrmm	m1,gr_bx
m20:	movzwl	gr_bx,%eax
	movzwl	gr_si,%ecx
m2p:	lea	(%eax,%ecx),%eax
m2:	movzwl	mem(%ebp),%ecx
	lea	2(%ebp),%ebp
	lea	(%eax,%ecx),%eax
	movzwl	%ax,%eax
	mov	$3,%ecx
	ret
m2ssp:	lea	(%eax,%ecx),%eax
m2ss:	movzwl	mem(%ebp),%ecx
	lea	2(%ebp),%ebp
	lea	(%eax,%ecx),%eax
	movzwl	%ax,%eax
	mov	$2,%ecx
	ret
m21:	modrmmp	m2p,gr_bx,gr_di
m22:	modrmmp	m2ssp,gr_bp,gr_si
m23:	modrmmp	m2ssp,gr_bp,gr_di
m24:	modrmm	m2,gr_si
m25:	modrmm	m2,gr_di
m26:	modrmm	m2ss,gr_bp
m27:	modrmm	m2,gr_bx
.macro	modrmr	i
	mov	$\i,%eax
	mov	$0,%ecx
	ret
.endm
m30:	modrmr	0
m31:	modrmr	1
m32:	modrmr	2
m33:	modrmr	3
m34:	modrmr	4
m35:	modrmr	5
m36:	modrmr	6
m37:	modrmr	7

.macro	t1like	a,b
	\a	\b,(%eax)
	jmp	mnext
.endm
t1b0:	t1like	add,%bl
t1b1:	t1like	or,%bl
t1b2:	t1like	adc,%bl
t1b3:	t1like	sbb,%bl
t1b4:	t1like	and,%bl
t1b5:	t1like	sub,%bl
t1b6:	t1like	xor,%bl
t1b7:	t1like	cmp,%bl
t1w0:	t1like	add,%bx
t1w1:	t1like	or,%bx
t1w2:	t1like	adc,%bx
t1w3:	t1like	sbb,%bx
t1w4:	t1like	and,%bx
t1w5:	t1like	sub,%bx
t1w6:	t1like	xor,%bx
t1w7:	t1like	cmp,%bx
t2b0:	t1like	rolb,%cl
t2b1:	t1like	rorb,%cl
t2b2:	t1like	rclb,%cl
t2b3:	t1like	rcrb,%cl
t2b4:	t1like	shlb,%cl
t2b5:	t1like	shrb,%cl
t2b6:	t1like	salb,%cl
t2b7:	t1like	sarb,%cl
t2w0:	t1like	rolw,%cl
t2w1:	t1like	rorw,%cl
t2w2:	t1like	rclw,%cl
t2w3:	t1like	rcrw,%cl
t2w4:	t1like	shlw,%cl
t2w5:	t1like	shrw,%cl
t2w6:	t1like	salw,%cl
t2w7:	t1like	sarw,%cl
t3b0:	mov	%eax,%ebx
	call	imm1
	test	%al,(%ebx)
	jmp	mnext
t3b2:	notb	(%eax)
	jmp	mnext
t3b3:	negb	(%eax)
	jmp	mnext
t3b4:	mov	%eax,%ebx
	movzbl	gr_al,%eax
	mulb	(%ebx)
	mov	%ax,gr_ax
	jmp	mnext
t3b5:	mov	%eax,%ebx
	movzbl	gr_al,%eax
	imulb	(%ebx)
	mov	%ax,gr_ax
	jmp	mnext
t3b6:	mov	%eax,%ebx
	movzwl	gr_ax,%eax
	divb	(%ebx)
	mov	%ax,gr_ax
	jmp	mnext
t3b7:	mov	%eax,%ebx
	movzwl	gr_ax,%eax
	idivb	(%ebx)
	mov	%ax,gr_ax
	jmp	mnext
t3w0:	mov	%eax,%ebx
	call	imm2
	test	%ax,(%ebx)
	jmp	mnext
t3w2:	notw	(%eax)
	jmp	mnext
t3w3:	negw	(%eax)
	jmp	mnext
t3w4:	mov	%eax,%ebx
	movzwl	gr_ax,%eax
	mulw	(%ebx)
	mov	%ax,gr_ax
	mov	%dx,gr_dx
	jmp	mnext
t3w5:	mov	%eax,%ebx
	movzwl	gr_ax,%eax
	imulw	(%ebx)
	mov	%ax,gr_ax
	mov	%dx,gr_dx
	jmp	mnext
t3w6:	mov	%eax,%ebx
	movzwl	gr_ax,%eax
	movzwl	gr_dx,%edx
	divw	(%ebx)
	mov	%ax,gr_ax
	mov	%dx,gr_dx
	jmp	mnext
t3w7:	mov	%eax,%ebx
	movzwl	gr_ax,%eax
	movzwl	gr_dx,%edx
	idivw	(%ebx)
	mov	%ax,gr_ax
	mov	%dx,gr_dx
	jmp	mnext
t40:	incb	(%eax)
	jmp	mnext
t41:	decb	(%eax)
	jmp	mnext
t50:	incw	(%eax)
	jmp	mnext
t51:	decw	(%eax)
	jmp	mnext
t52:	movzwl	(%eax),%ecx
	call	getip
	call	psh
1:	mov	%ecx,%eax
	jmp	mnextj
t53:	movzwl	2(%eax),%ebx
	movzwl	(%eax),%ecx
	mov	$1,%edx
	call	pshseg
	call	getip
	call	psh
	mov	%ecx,%eax
	mov	%ebx,%edi
1:	mov	$1,%edx
	call	setseg
	jmp	mnextj
t54:	movzwl	(%eax),%eax
	jmp	mnextj
t55:	movzwl	2(%eax),%edi
	movzwl	(%eax),%eax
	jmp	1b
t56:	movzwl	(%eax),%edx
	call	psh
	jmp	mnext

	.section .rodata
	.align	4
mrtbl:	.long	m00,m01,m02,m03,m04,m05,m06,m07
	.long	m10,m11,m12,m13,m14,m15,m16,m17
	.long	m20,m21,m22,m23,m24,m25,m26,m27
	.long	m30,m31,m32,m33,m34,m35,m36,m37
tbl1b:	.long	t1b0,t1b1,t1b2,t1b3,t1b4,t1b5,t1b6,t1b7
tbl1w:	.long	t1w0,t1w1,t1w2,t1w3,t1w4,t1w5,t1w6,t1w7
tbl2b:	.long	t2b0,t2b1,t2b2,t2b3,t2b4,t2b5,t2b6,t2b7
tbl2w:	.long	t2w0,t2w1,t2w2,t2w3,t2w4,t2w5,t2w6,t2w7
tbl3b:	.long	t3b0,t3b0,t3b2,t3b3,t3b4,t3b5,t3b6,t3b7
tbl3w:	.long	t3w0,t3w0,t3w2,t3w3,t3w4,t3w5,t3w6,t3w7
tbl4:	.long	t40,t41,bad,bad,bad,bad,bad,bad
tbl5:	.long	t50,t51,t52,t53,t54,t55,t56,t56
itbl:	.long	i00,i01,i02,i03,i04,i05,i06,i07,i08,i09,i0a,i0b,i0c,i0d,i0e,i0f
	.long	i10,i11,i12,i13,i14,i15,i16,i17,i18,i19,i1a,i1b,i1c,i1d,i1e,i1f
	.long	i20,i21,i22,i23,i24,i25,i26,i27,i28,i29,i2a,i2b,i2c,i2d,i2e,i2f
	.long	i30,i31,i32,i33,i34,i35,i36,i37,i38,i39,i3a,i3b,i3c,i3d,i3e,i3f
	.long	i40,i41,i42,i43,i44,i45,i46,i47,i48,i49,i4a,i4b,i4c,i4d,i4e,i4f
	.long	i50,i51,i52,i53,i54,i55,i56,i57,i58,i59,i5a,i5b,i5c,i5d,i5e,i5f
	.long	bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad,bad
	.long	i70,i71,i72,i73,i74,i75,i76,i77,i78,i79,i7a,i7b,i7c,i7d,i7e,i7f
	.long	i80,i81,i82,i83,i84,i85,i86,i87,i88,i89,i8a,i8b,i8c,i8d,i8e,i8f
	.long	i90,i91,i92,i93,i94,i95,i96,i97,i98,i99,i9a,bad,i9c,i9d,i9e,i9f
	.long	ia0,ia1,ia2,ia3,ia4,ia5,ia6,ia7,ia8,ia9,iaa,iab,iac,iad,iae,iaf
	.long	ib0,ib1,ib2,ib3,ib4,ib5,ib6,ib7,ib8,ib9,iba,ibb,ibc,ibd,ibe,ibf
	.long	bad,bad,ic2,ic3,ic4,ic5,ic6,ic7,bad,bad,ica,icb,bad,icd,bad,icf
	.long	id0,id1,id2,id3,id4,id5,id6,id7,bad,bad,bad,bad,bad,bad,bad,bad
	.long	ie0,ie1,ie2,ie3,bad,bad,bad,bad,ie8,ie9,iea,ieb,bad,bad,bad,bad
	.long	if0,bad,if2,if3,bad,if5,if6,if7,if8,if9,ifa,ifb,ifc,ifd,ife,iff
rbtbl:	.byte	0,2,4,6,1,3,5,7
stbl:	.byte	0,1,2,3,0,1,2,3

	.data
	.align	4
prefix:	.long	0
prefix_seg=prefix+0
prefix_rep=prefix+1
sgval:	.word	(psp-mem)/16
	.word	(psp-mem)/16
	.word	(psp-mem)/16
	.word	(psp-mem)/16
sgbase:
sgb_es:	.long	psp-mem
sgb_cs:	.long	psp-mem
sgb_ss:	.long	psp-mem
sgb_ds:	.long	psp-mem
ip:	.word	0x100
greg:
gr_ax:	.word	0
gr_cx:	.word	0
gr_dx:	.word	0
gr_bx:	.word	0
gr_sp:	.word	0xfffe
gr_bp:	.word	0
gr_si:	.word	0
gr_di:	.word	0
gr_al=gr_ax
gr_ah=gr_ax+1
gr_cl=gr_cx
gr_ch=gr_cx+1
gr_dl=gr_dx
gr_dh=gr_dx+1
gr_bl=gr_bx
gr_bh=gr_bx+1
swtchr:	.byte	'-'
devavl:	.byte	0
	.bss
mem:	.space	0x31000
memend:
psp=mem+0xf00
code=psp+0x100

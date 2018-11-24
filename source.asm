;****************************************************************************
;****************************************************************************
;*
;* USING THE FRAMEBUFFER DEVICE UNDER LINUX
;*
;* written by Karsten Scheibler, 2003-DEC-08
;*
;****************************************************************************
;****************************************************************************





global fb_start

;look at the vt example code for more
%ifdef USE_VT
%include "vt.n"
%endif ;USE_VT



;****************************************************************************
;* some assign's
;****************************************************************************
%assign SYS_READ			3
%assign SYS_OPEN			5
%assign SYS_IOCTL			54
%assign SYS_MMAP			90

%assign PROT_READ			1
%assign PROT_WRITE			2

%assign MAP_SHARED			1

%assign STDIN				0
%assign STDERR				2

%assign O_RDWR				2

%assign FBIOGET_VSCREENINFO		0x00004600
%assign FBIOPUT_VSCREENINFO		0x00004601
%assign FBIOGETCMAP			0x00004604
%assign FBIOPUTCMAP			0x00004605
%assign KDSETMODE			0x00004b3a
%assign KDGETMODE			0x00004b3b

%assign KD_TEXT				0
%assign KD_GRAPHICS			1

					struc	tcmap
					alignb	4
tcmap_offset:				resd	1
tcmap_length:				resd	1
tcmap_red:				resd	1
tcmap_green:				resd	1
tcmap_blue:				resd	1
tcmap_transparent:			resd	1
					endstruc



					struc	tscreen
					alignb	4
tscreen_x_resolution:			resd	1
tscreen_y_resolution:			resd	1
tscreen_virtual_x_resolution:		resd	1
tscreen_virtual_y_resolution:		resd	1
tscreen_x_offset:			resd	1
tscreen_y_offset:			resd	1
tscreen_bits_per_pixel:			resd	1
tscreen_grayscale:			resd	1
tscreen_red_offset:			resd	1
tscreen_red_length:			resd	1
tscreen_red_msb_right:			resd	1
tscreen_green_offset:			resd	1
tscreen_green_length:			resd	1
tscreen_green_msb_right:		resd	1
tscreen_blue_offset:			resd	1
tscreen_blue_length:			resd	1
tscreen_blue_msb_right:			resd	1
tscreen_transparent_offset:		resd	1
tscreen_transparent_length:		resd	1
tscreen_transparent_msb_right:		resd	1
tscreen_non_standard_format:		resd	1
tscreen_activate:			resd	1
tscreen_height:				resd	1
tscreen_width:				resd	1
tscreen_acceleration_flags:		resd	1
tscreen_pixel_clock:			resd	1
tscreen_left_margin:			resd	1
tscreen_right_margin:			resd	1
tscreen_upper_margin:			resd	1
tscreen_lower_margin:			resd	1
tscreen_hsync_length:			resd	1
tscreen_vsync_length:			resd	1
tscreen_sync:				resd	1
tscreen_vmode:				resd	1
tscreen_reserved:			resd	6
					endstruc

%assign FB_KDMODE_SAVED			0x00000001
%assign FB_SCREENINFO_SAVED		0x00000002
%assign FB_COLORMAP_SAVED		0x00000004



;****************************************************************************
;* data
;****************************************************************************
section .data
					align	4
fb_state:				dd	0
fb_handle:				dd	0
fb_address:				dd	0
fb_kdmode:				dd	0
colormap_saved:				istruc tcmap
					at tcmap_offset,	dd 0
					at tcmap_length,	dd 256
					at tcmap_red,		dd red_saved
					at tcmap_green,		dd green_saved
					at tcmap_blue,		dd blue_saved
					at tcmap_transparent,	dd transparent_saved
					iend
colormap_data:				istruc tcmap
					at tcmap_offset,	dd 0
					at tcmap_length,	dd 256
					at tcmap_red,		dd grey_scale
					at tcmap_green,		dd grey_scale
					at tcmap_blue,		dd grey_scale
					at tcmap_transparent,	dd transparent_saved
					iend

section .bss
					alignb	4
screeninfo_saved:			resb	tscreen_size
screeninfo_data:			resb	tscreen_size
grey_scale:				resw	256
red_saved:				resw	256
green_saved:				resw	256
blue_saved:				resw	256
transparent_saved:			resw	256




;****************************************************************************
;* fb_start
;****************************************************************************
section .text
fb_start:

	mov	dword eax, SYS_IOCTL
	mov	dword ebx, STDIN
	mov	dword ecx, KDGETMODE
	mov	dword edx, fb_kdmode
	int	byte  0x80
	test	dword eax, eax
	js	near  fb_error
	or	dword [fb_state], FB_KDMODE_SAVED

	;tell kernel that we switch to graphics mode.
	;this means the kernel won't do things that may change the video ram
	;(vt switching, vt blanking, cursor, mouse cursor [gpm])

	mov	dword eax, SYS_IOCTL
	mov	dword ebx, STDIN
	mov	dword ecx, KDSETMODE
	mov	dword edx, KD_GRAPHICS
	int	byte  0x80
	test	dword eax, eax
	js	near  fb_error

	;open

	mov	dword eax, SYS_OPEN
	mov	dword ebx, .device
	mov	dword ecx, O_RDWR
	int	byte  0x80
	test	dword eax, eax
	js	near  fb_error
	mov	dword [fb_handle], eax

	;get screen parameters

	mov	dword ebx, eax
	mov	dword eax, SYS_IOCTL
	mov	dword ecx, FBIOGET_VSCREENINFO
	mov	dword edx, screeninfo_saved
	int	byte  0x80
	test	dword eax, eax
	js	near  fb_error
	xor	dword eax, eax
	mov	dword [screeninfo_saved + tscreen_x_offset], eax
	mov	dword [screeninfo_saved + tscreen_y_offset], eax
	mov	dword esi, screeninfo_saved
	mov	dword edi, screeninfo_data
	mov	dword ecx, (tscreen_size / 4)
	cld
	rep movsd
	or	dword  [fb_state], FB_SCREENINFO_SAVED

	;get current colormap

	mov	dword eax, SYS_IOCTL
	mov	dword ebx, [fb_handle]
	mov	dword ecx, FBIOGETCMAP
	mov	dword edx, colormap_saved
	int	byte  0x80
	test	dword eax, eax
	js	short .no_colormap_saved
	or	dword [fb_state], FB_COLORMAP_SAVED
.no_colormap_saved:

	;set screen parameters

	mov	dword eax, [screeninfo_data + tscreen_x_resolution]
	mov	dword ebx, [screeninfo_data + tscreen_y_resolution]
	mov	dword ecx, 8
	mov	dword [screeninfo_data + tscreen_virtual_x_resolution], eax
	mov	dword [screeninfo_data + tscreen_virtual_y_resolution], ebx
	mov	dword [screeninfo_data + tscreen_bits_per_pixel], ecx
	mov	dword eax, SYS_IOCTL
	mov	dword ebx, [fb_handle]
	mov	dword ecx, FBIOPUT_VSCREENINFO
	mov	dword edx, screeninfo_data
	int	byte  0x80
	test	dword eax, eax
	js	near  fb_error
	cmp	dword [screeninfo_data + tscreen_bits_per_pixel], 8
	jne	near  fb_error

	;set colormap

	mov	dword eax, 0x01000000
	xor	dword ebx, ebx
.set_grey:
	mov	dword [grey_scale + 4 * ebx], eax
	add	dword eax, 0x02000200
	inc	dword ebx
	cmp	dword ebx, byte 127
	jbe	short .set_grey
	mov	dword eax, SYS_IOCTL
	mov	dword ebx, [fb_handle]
	mov	dword ecx, FBIOPUTCMAP
	mov	dword edx, colormap_data
	int	byte  0x80

	;mmap

	mov	dword eax, [screeninfo_data + tscreen_y_resolution]
	mul	dword [screeninfo_data + tscreen_virtual_x_resolution]
	xor	dword ebx, ebx
	push	dword ebx
	push	dword [fb_handle]
	push	dword MAP_SHARED
	push	dword (PROT_READ | PROT_WRITE)
	push	dword eax
	push	dword ebx
	mov	dword eax, SYS_MMAP
	mov	dword ebx, esp
	int	byte  0x80
	add	dword esp, byte 24
	test	dword eax, eax
	jz	near  fb_error
	mov	dword [fb_address], eax

	;"press enter to exit" ...

%ifndef USE_VT
	call	near  fb_draw
	push	dword eax
	mov	dword eax, SYS_READ
	mov	dword ebx, STDIN
	mov	dword ecx, esp
	mov	dword edx, 1
	int	byte  0x80
	add	dword esp, byte 4
	jmp	near  fb_end
%else ;USE_VT
	mov	dword eax, fb_end
	mov	dword ebx, fb_error
	call	near  vt_init

	;mainloop

.loop:
	call	near  fb_draw
.keypress1:
	call	near  vt_check_keypress
	cmp	dword eax, byte 1
	je	near  fb_end
	call	near  vt_check_release
	test	dword eax, eax
	js	short .keypress1
	call	near  vt_commit_release
	test	dword eax, eax
	js	short .keypress1
.keypress2:
	call	near  vt_check_keypress	;vt is not active => no keypress
					;possible, we simply use select to
					;wait here
	call	near  vt_check_acquire
	test	dword eax, eax
	js	short .keypress2
	jmp	short .loop
%endif ;USE_VT

.device:				db	"/dev/fb0", 0



;****************************************************************************
;* fb_draw
;****************************************************************************
section .text
fb_draw:
	mov	dword edi, [fb_address]
	mov	dword ebp, [screeninfo_data + tscreen_virtual_x_resolution]
	sub	dword ebp, [screeninfo_data + tscreen_x_resolution]
	mov	dword ebx, [screeninfo_data + tscreen_y_resolution]
.draw_line:
	mov	dword eax, ebx
	mov	dword ecx, [screeninfo_data + tscreen_x_resolution]
.draw_pixel:
	stosb
	inc	dword eax
	dec	dword ecx
	jnz	short .draw_pixel
	add	dword edi, ebp
	dec	dword ebx
	jnz	short .draw_line
	ret



;****************************************************************************
;* fb_restore
;****************************************************************************
section .text
fb_restore:
	test	dword [fb_state], FB_SCREENINFO_SAVED
	jz	short .skip_screeninfo
	mov	dword eax, SYS_IOCTL
	mov	dword ebx, [fb_handle]
	mov	dword ecx, FBIOPUT_VSCREENINFO
	mov	dword edx, screeninfo_saved
	int	byte  0x80
.skip_screeninfo:
	test	dword [fb_state], FB_COLORMAP_SAVED
	jz	short .skip_colormap
	mov	dword eax, SYS_IOCTL
	mov	dword ebx, [fb_handle]
	mov	dword ecx, FBIOPUTCMAP
	mov	dword edx, colormap_saved
	int	byte  0x80
.skip_colormap:
	test	dword [fb_state], FB_KDMODE_SAVED
	jz	short .skip_kdmode
	mov	dword eax, SYS_IOCTL
	mov	dword ebx, STDIN
	mov	dword ecx, KDSETMODE
	mov	dword edx, [fb_kdmode]
	int	byte  0x80
.skip_kdmode:
	ret



;****************************************************************************
;* fb_error
;****************************************************************************
section .text
fb_error:
	call	near  fb_restore
	xor	dword eax, eax
	inc	dword eax
	mov	dword ebx, eax
	int	byte  0x80



;****************************************************************************
;* fb_end
;****************************************************************************
section .text
fb_end:
	call	near  fb_restore
	xor	dword eax, eax
	xor	dword ebx, ebx
	inc	dword eax
	int	byte  0x80
;*********************************************** linuxassembly@unusedino.de *


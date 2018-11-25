.text
.global main

.intel_syntax noprefix

.equ true, 1
.equ false, 0

printstr:
	sub rsp, 0x8

	mov rdi, rax
	call puts 

	add rsp, 0x8
	ret
	
printint:
	sub rsp, 0x8

	mov rdi, OFFSET intformat
	mov rsi, rax
	mov rax, 0x0
	call printf

	add rsp, 0x8
	ret

#screw the stack up ~~a little~~ quite a bit, don't reference stack variables relative to rsp
align:
	mov rax, [rsp]
	and rsp, 0xFFFFFFFFFFFFFFF0
	jmp rax


inittexture:
	sub rsp, 0x8

	mov rdi, globalRendererPtr
	mov rsi, 373694468         # SDL_PIXELFORMAT_RGBA8888
	mov rdx, 1                 # SDL_TEXTUREACCESS_STREAMING
	mov rcx, winWidth
	mov r8, winHeight
	call SDL_CreateTexture
	mov globalTexturePtr, rax

	call SDL_GetError
	call printstr

	mov rcx, winHeight
	mov rdi, winWidth
	imul rdi, rcx  
	lea rdi, [rdi*4]
	mov pixelBufSize, rdi
	call malloc
	mov globalPixelBufPtr, rax
	
	add rsp, 0x8
	ret

#rdi is clear color
clearwindow:
	mov rax, pixelBufSize
	
	mov rbx, globalPixelBufPtr 
	lea rcx, [rbx+rax]
clearwindow_while:
	mov [rbx], rdi
	add rbx, 4
	cmp rbx, rcx
	jl clearwindow_while
	
	ret

# [x + y * width] = color
# [rdi + rsi * winWidth] = rdx
drawpixel:
	imul rsi, winWidth
	add rdi, rsi
	mov rax, globalPixelBufPtr
	mov [rax+rdi*4], rdx
	ret
		
# SDL_UpdateTexture(framebuffer , NULL, pixels, width * sizeof (uint32_t));
#
# SDL_RenderClear(renderer);
# SDL_RenderCopy(renderer, framebuffer , NULL, NULL);
# SDL_RenderPresent(renderer);
switchbuffers:
	sub rsp, 0x8

	mov rdi, globalTexturePtr
	mov rsi, 0
	mov rdx, globalPixelBufPtr
	mov rcx, winWidth
	lea rcx, [rcx*4]
	call SDL_UpdateTexture

	mov rdi, globalRendererPtr
	call SDL_RenderClear
	
	mov rdi, globalRendererPtr
	mov rsi, globalTexturePtr
	mov rdx, 0
	mov rcx, 0
	call SDL_RenderCopy

	mov rdi, globalRendererPtr
	call SDL_RenderPresent	

	add rsp, 0x8
	ret

main:
	mov rbp, rsp
	call align
	mov rdi, 0x20 # SDL_INIT_VIDEO
	call SDL_Init

	mov rax, winWidth
	call printint
	mov rax, winHeight
	call printint

	mov rdi, winWidth
	mov rsi, winHeight
	mov rdx, 0x0
	mov rcx, OFFSET globalWindowPtr
	mov r8, OFFSET globalRendererPtr
	call SDL_CreateWindowAndRenderer

	call inittexture




	#mov rdi, OFFSET winTitle # Title
	#mov rsi, 0x2FFF0000      # SDL_WINDOWPOS_CENTERED
	#mov rdx, 0x2FFF0000      # SDL_WINDOWPOS_CENTERED
	#mov rcx, winWidth        # Width
	#mov r8,  winHeight       # Height
	#mov r9,  0x0             # Flags
	#call SDL_CreateWindow

	#mov window, rax

	call SDL_GetError
	call printstr
	

mainLoop:
	
	mov rdi, 0xFF00FFFF
	call clearwindow

	mov rdi, 100
	mov rsi, 100
	mov rdx, 0xFF0000FF
	call drawpixel

eventLoop:
	
	
	mov rdi, OFFSET eventToProcess
	call SDL_PollEvent
	
	cmp al, false
	je endEventLoop
	

	mov eax, eventToProcess
	cmp eax, 0x100               # SDL_QUIT
	
	jne eventswitch_keyEvent	
		mov ebx, 0
		mov running, ebx
		jmp eventLoop

	eventswitch_keyEvent:

	cmp eax, 0x300              # SDL_KeyEvent	
	jne eventswitch_default
		mov ebx, eventToProcess+16
		mov eax, ebx
		call printint
		cmp ebx, 41  # SDL_SCANCODE_ESCAPE		
		jne keypress_default
			mov ebx, 0
			mov running, ebx
			jmp eventLoop
		keypress_default:
		

			jmp eventLoop
	
	eventswitch_default:

	

endEventLoop:
	
	


	call switchbuffers

	


	mov eax, running
	cmp eax, false
	jne mainLoop

	# DESTROY HER
	mov rdi, globalTexturePtr
	call SDL_DestroyTexture
	mov rdi, globalRendererPtr
	call SDL_DestroyRenderer
	mov rdi, globalWindowPtr 
	call SDL_DestroyWindow 

	call SDL_Quit

	jmp quit

quit:
	mov rax, 60
	mov rdi, 0
	syscall

.data
	eventToProcess:	.space 56
	globalWindowPtr: .space 8
	pixelBufSize: .quad 0
	globalPixelBufPtr: .space 8	
	globalTexturePtr: .space 8
	globalRendererPtr: .space 8

	running: .int 1

	myobjects: .long 1,12, 0,0,0, 1,0,0
	winWidth: .quad 600
	winHeight: .quad 400
	winTitle: .asciz ""
	intformat: .asciz "here is an int: %i\n"
; AdamJ @ DemoBit 2017
; 256B, DosBox compatible
; Use NASM to compile

		org 100h

INIT_ADLIB:
		mov dx, 7
		mov bx, 0

_init_adlib_loop:
		mov ax, [aAdLibSetupData+bx]
		mov cl, ah
		inc bl
		inc bl

		call ADLIB_CTRL
		dec dx
		jnz _init_adlib_loop

INIT_GRAPHICS:				
		mov ax, 0x13
		int 0x10
		
		mov ah, 9
		mov edx, aMessage
		int 0x21
		
INIT_MUSIC:
		; initialize the counter
		mov ax, 0

; Main iteration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NEXT_BEAT:

		; Let's call the VBI sync routine 120x
		; There are probably better 
		mov dx, 120
_next_beat_delay_cycle:
		call VBI_SYNC
		dec dx
		jnz _next_beat_delay_cycle

		; remember the current state of the counter
		push ax

			; turn off the current note
			push ax
				mov al, 0xb0
				mov cl, 0x11
				call ADLIB_CTRL 
			pop ax

			push ax
				; set frequency
				mov bx, ax
				and bl, 0x1f
				mov al, 0xA0
				mov cx, [aMelody+bx]
				call ADLIB_CTRL

				mov ax, [aMelody+bx]
				mov bx, 2560
				call DRAW ; destroys registers
			pop ax

			; automation
			mov bx, ax
			and bx, 0x70
			shr bx, 3
			
			mov ax, [aAutomation+bx]
			mov cl, ah
			
			; mov al, [aAutomation+bx]
			; inc bx
			; mov cl, [aAutomation+bx]
			call ADLIB_CTRL

			; turn on the current note
			mov al, 0xb0
			mov cl, 0x31
			call ADLIB_CTRL

			; press ESC to quit
			in al, 0x60
			dec al
			jz TERMINATE ; scan code of ESC == 1
			
		; increment the current step counter. Low nibble = melody step; High nibble = automation
		pop ax
		inc al

		jmp NEXT_BEAT

; Draw the line
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DRAW:
		; Set ES:DI
		push 0xa000
		pop es
		push bx
		pop di
		mov bx, 640
		
DRAW_iteration:
		stosb
		dec bx
		jnz DRAW_iteration
		ret

; Send data to AdLib
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ADLIB_CTRL:
		pusha
		mov dx, 0x388
		out dx, al
		call _adlib_ctrl_wait
		
		mov dx, 0x389
		mov ax, cx
		out dx, al
		call _adlib_ctrl_wait
		popa
		
		ret

_adlib_ctrl_wait:
		push ax
		mov al, 255
		nop
		dec al
		pop ax
		ret
		
; Busy-wait for VBI
; https://www.gamedev.net/topic/283658-x86-detect-vga-vertical-retrace/
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
VBI_SYNC:
		pusha
		; push AX
		; push DX
		mov DX, 03DAH ; VGA Input Status Register

_vsync_retrace:
		in AL,DX			; AL := Port[03DAH]
		test AL,8			; Is bit 3 set?
		jz _vsync_retrace ; No, continue waiting

		; pop dx
		; pop	ax
		popa
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; TERMINATE

TERMINATE:	
		; kill the aufio
		mov cl, 0x11
		mov al, 0xb0
		call ADLIB_CTRL 

		; terminate
		int 0x20

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DATA

aMessage:
		DB "AdamJ's 256B$"

; Two bars of melody in some weird scale
aMelody:
		DB 100,  50, 100,  50    ; bar 1  
		DB 150,  50, 200, 100
		DB 100, 100,  50, 100
		DB 150, 250,  50,  20

		DB 50,  100, 100,  50    ; bar 2
		DB 150,  50, 200, 100
		DB 100, 150,  50, 100
		DB 150, 250,  20,  35

; What gets set at the boundary of each bar
aAutomation:
		DB 0x63, 0xf0 ; long decay 
		DB 0x23, 0x02 ; carrier multiple
		DB 0x63, 0xf7 ; short decay
		DB 0x23, 0x01 ; carrier multiple
		DB 0x63, 0xf0 ; long decay
		DB 0x20, 0x00 ; modulator multiple
		DB 0x63, 0xf7 ; short decay
		DB 0x20, 0x01 ; modulator multiple

; The following values were taken from
; https://courses.engr.illinois.edu/ece390/resources/sound/adlib.txt.html
aAdLibSetupData:
		DB 0x20, 0x01   ; Set the modulator's multiple to 1
		DB 0x40, 0x10   ; Set the modulator's level to about 40 dB
		DB 0x60, 0xf8   ; Modulator attack:  quick;   decay:   long
		DB 0x80, 0x77   ; Modulator sustain: medium;  release: medium
		; DB 0xa0, 0x90   ; Set voice frequency's LSB (it'll be a D#)
		DB 0x23, 0x01   ; Set the carrier's multiple to 1
		DB 0x43, 0x00   ; Set the carrier to maximum volume (about 47 dB)
		; DB 0x63, 0x2f   ; Carrier attack:  quick;   decay:   long
		DB 0x83, 0x77   ; Carrier sustain: medium;  release: medium
		; DB 0xb0, 0x11   ; Turn the voice on; set the octave and freq MSB 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; END
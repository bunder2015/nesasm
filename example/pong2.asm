	.inesprg 1	; 1x 16KB PRG ROM
	.ineschr 1	; 1x  8KB CHR ROM
	.inesprs 0	; 0x  8KB PRG RAM
	.inesmap 0	; iNES mapper 0
	.inesmir 1	; Vertical mirroring (horizontal scrolling)
	.inesfsm 0	; No four-screen mirroring
	.inesbat 0	; No battery
	.inesreg 0	; NTSC video region
	.inesbus 0	; No bus conflicts (technically NROM has them but they are irrelevant)

;;;;;;;;;;;;;;;

	.include "nes-const.asm"	; List of NES constants (registers)
	.include "pong2-const.asm"	; List of game constants

	.zp
gamestate:	.ds 1	; 0 = title, 1 = playing, 2 = gameover
buttons1:	.ds 1	; player 1 gamepad buttons, one bit per button
buttons2:	.ds 1	; player 2 gamepad buttons, one bit per button

	.bss
	.include "nes-ppu-bss.asm"	; List of NES sprite slots
ballx:		.ds 1	; ball horizontal position
bally:		.ds 1	; ball vertical position
ballup:		.ds 1	; 1 = ball moving up
balldown:	.ds 1	; 1 = ball moving down
ballleft:	.ds 1	; 1 = ball moving left
ballright:	.ds 1	; 1 = ball moving right
ballspeedx:	.ds 1	; ball horizontal speed per frame
ballspeedy:	.ds 1	; ball vertical speed per frame
paddle1ytop:	.ds 1	; player 1 paddle top vertical position
paddle2ybot:	.ds 1	; player 2 paddle bottom vertical position
scoreOnes:	.ds 1	; byte for each digit in the decimal score
scoreTens:	.ds 1
scoreHundreds:	.ds 1

;;;;;;;;;;;;;;;;;;

	.code
	.bank 0
	.org $C000

RESET:
	SEI		; disable IRQs
	CLD		; disable decimal mode
	LDX #$40
	STX APUFRAME	; disable APU frame IRQ
	LDX #$FF
	TXS		; Set up stack
	INX		; now X = 0
	STX PPUCTRL	; disable NMI
	STX PPUMASK	; disable rendering
	STX DMCFREQ	; disable DMC IRQs

vblankwait1:		; First wait for vblank to make sure PPU is ready
	BIT $2002
	BPL vblankwait1

clrmem:
	LDA #$00
	STA $0000,x
	STA $0100,x
	STA $0300,x
	STA $0400,x
	STA $0500,x
	STA $0600,x
	STA $0700,x
	LDA #$FE
	STA $0200,x
	INX
	BNE clrmem

vblankwait2:		; Second wait for vblank, PPU is ready after this
	BIT PPUSTATUS
	BPL vblankwait2

LoadPalettes:
	LDA PPUSTATUS	; read PPU status to reset the high/low latch
	LDA #$3F
	STA PPUADDR	; write the high byte of $3F00 address
	LDA #$00
	STA PPUADDR	; write the low byte of $3F00 address
	LDX #$00	; start out at 0
LoadPalettesLoop:
	LDA palette,x	; load data from address (palette + the value in x)
			; 1st time through loop it will load palette+0
			; 2nd time through loop it will load palette+1
			; 3rd time through loop it will load palette+2
			; etc
	STA PPUDATA	; write to PPU
	INX		; X = X + 1
	CPX #$20	; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
	BNE LoadPalettesLoop	; Branch to LoadPalettesLoop if compare was Not Equal to zero
				; if compare was equal to 32, keep going down

; Set some initial ball stats
	LDA #$01
	STA balldown
	STA ballright
	LDA #$00
	STA ballup
	STA ballleft

	LDA #$50
	STA bally

	LDA #$80
	STA ballx

	LDA #$02
	STA ballspeedx
	STA ballspeedy

; Set initial score value
	LDA #$00
	STA scoreOnes
	STA scoreTens
	STA scoreHundreds

; Set starting game state
	LDA #STATEPLAYING
	STA <gamestate

	LDA #%10010000	; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	STA PPUCTRL

	LDA #%00011110	; enable sprites, enable background, no clipping on left side
	STA PPUMASK

Forever:
	JMP Forever	; jump back to Forever, infinite loop, waiting for NMI

NMI:
	LDA #$00
	STA OAMADDR	; set the low byte (00) of the RAM address
	LDA #$02
	STA OAMDMA	; set the high byte (02) of the RAM address, start the transfer

	JSR DrawScore

; This is the PPU clean up section, so rendering the next frame starts properly.
	LDA #%10010000	; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
	STA PPUCTRL
	LDA #%00011110	; enable sprites, enable background, no clipping on left side
	STA PPUMASK
	LDA #$00	; tell the ppu there is no background scrolling
	STA PPUSCROLL
	STA $2005

; all graphics updates done by here, run game engine
	JSR ReadController1	; get the current button data for player 1
	JSR ReadController2	; get the current button data for player 2

GameEngine:
	LDA <gamestate
	CMP #STATETITLE
	BEQ EngineTitle		; game is displaying title screen

	LDA <gamestate
	CMP #STATEGAMEOVER
	BEQ EngineGameOver	; game is displaying ending screen

	LDA <gamestate
	CMP #STATEPLAYING
	BEQ EnginePlaying	; game is playing

GameEngineDone:
	JSR UpdateSprites	; set ball/paddle sprites from positions
	RTI			; return from interrupt

;;;;;;;;;;;;;;;;;;

EngineTitle:
	; if start button pressed
	; turn screen off
	; load game screen
	; set starting paddle/ball position
	; go to Playing State
	; turn screen on
	JMP GameEngineDone

;;;;;;;;;;;;;;;;;;

EngineGameOver:
	; if start button pressed
	; turn screen off
	; load title screen
	; go to Title State
	; turn screen on
	JMP GameEngineDone

;;;;;;;;;;;;;;;;;;

EnginePlaying:

MoveBallRight:
	LDA ballright
	BEQ MoveBallRightDone	; if ballright=0, skip this section

	LDA ballx
	CLC
	ADC ballspeedx		; ballx position = ballx + ballspeedx
	STA ballx

	LDA ballx
	CMP #RIGHTWALL
	BCC MoveBallRightDone	; if ball x < right wall, still on screen, skip next section
	LDA #$00
	STA ballright
	LDA #$01
	STA ballleft		; bounce, ball now moving left
; in real game, give point to player 1, reset ball
	JSR IncrementScore
MoveBallRightDone:

MoveBallLeft:
	LDA ballleft
	BEQ MoveBallLeftDone	; if ballleft=0, skip this section

	LDA ballx
	SEC
	SBC ballspeedx		; ballx position = ballx - ballspeedx
	STA ballx

	LDA ballx
	CMP #LEFTWALL
	BCS MoveBallLeftDone	; if ball x > left wall, still on screen, skip next section
	LDA #$01
	STA ballright
	LDA #$00
	STA ballleft		; bounce, ball now moving right
; in real game, give point to player 2, reset ball
	JSR IncrementScore
MoveBallLeftDone:

MoveBallUp:
	LDA ballup
	BEQ MoveBallUpDone	; if ballup=0, skip this section

	LDA bally
	SEC
	SBC ballspeedy		; bally position = bally - ballspeedy
	STA bally

	LDA bally
	CMP #TOPWALL
	BCS MoveBallUpDone      ; if ball y > top wall, still on screen, skip next section
	LDA #$01
	STA balldown
	LDA #$00
	STA ballup		; bounce, ball now moving down
MoveBallUpDone:

MoveBallDown:
	LDA balldown
	BEQ MoveBallDownDone	; if ballup=0, skip this section

	LDA bally
	CLC
	ADC ballspeedy		; bally position = bally + ballspeedy
	STA bally

	LDA bally
	CMP #BOTTOMWALL
	BCC MoveBallDownDone	; if ball y < bottom wall, still on screen, skip next section
	LDA #$00
	STA balldown
	LDA #$01
	STA ballup		; bounce, ball now moving down
MoveBallDownDone:

MovePaddleUp:
	; if up button pressed
	; if paddle top > top wall
	; move paddle top and bottom up
MovePaddleUpDone:

MovePaddleDown:
	; if down button pressed
	; if paddle bottom < bottom wall
	; move paddle top and bottom down
MovePaddleDownDone:

CheckPaddleCollision:
	; if ball x < paddle1x
	; if ball y > paddle y top
	; if ball y < paddle y bottom
	; bounce, ball now moving left
CheckPaddleCollisionDone:
	JMP GameEngineDone

UpdateSprites:
	LDA bally	; update all ball sprite info
	STA SPR0Y

	LDA #$30
	STA SPR0TILE

	LDA #$00
	STA SPR0ATTR

	LDA ballx
	STA SPR0X

	; update paddle sprites
	RTS

DrawScore:
	LDA PPUSTATUS
	LDA #$20
	STA PPUADDR
	LDA #$20
	STA PPUADDR	; start drawing the score at PPU $2020

	LDA scoreHundreds	; get first digit
	;CLC
	;ADC #$30	; add ascii offset (this is unused because the tiles for digits start at 0)
	STA PPUDATA	; draw to background
	LDA scoreTens	; next digit
	;CLC
	;ADC #$30	; add ascii offset
	STA PPUDATA
	LDA scoreOnes	; last digit
	;CLC
	;ADC #$30	; add ascii offset
	STA PPUDATA
	RTS

IncrementScore:
IncOnes:
	LDA scoreOnes	; load the lowest digit of the number
	CLC
	ADC #$01	; add one
	STA scoreOnes
	CMP #$0A	; check if it overflowed, now equals 10
	BNE IncDone	; if there was no overflow, all done
IncTens:
	LDA #$00
	STA scoreOnes	; wrap digit to 0
	LDA scoreTens	; load the next digit
	CLC
	ADC #$01	; add one, the carry from previous digit
	STA scoreTens
	CMP #$0A	; check if it overflowed, now equals 10
	BNE IncDone	; if there was no overflow, all done
IncHundreds:
	LDA #$00
	STA scoreTens	; wrap digit to 0
	LDA scoreHundreds	; load the next digit
	CLC
	ADC #$01	; add one, the carry from previous digit
	STA scoreHundreds
IncDone:

ReadController1:
	LDA #$01
	STA STROBE
	LDA #$00
	STA STROBE
	LDX #$08
ReadController1Loop:
	LDA JOY1
	LSR A		; bit0 -> Carry
	ROL <buttons1	; bit0 <- Carry
	DEX
	BNE ReadController1Loop
	RTS

ReadController2:
	LDA #$01
	STA STROBE
	LDA #$00
	STA STROBE
	LDX #$08
ReadController2Loop:
	LDA JOY2
	LSR A		; bit0 -> Carry
	ROL <buttons2	; bit0 <- Carry
	DEX
	BNE ReadController2Loop
	RTS

;;;;;;;;;;;;;;;;;;

	.code
	.bank 1
	.org $E000

palette:
	.db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F	; background palette
	.db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C	; sprite palette

sprites:
	; vert tile attr horiz
	.db $80, $32, $00, $80	; sprite 0
	.db $80, $33, $00, $88	; sprite 1
	.db $88, $34, $00, $80	; sprite 2
	.db $88, $35, $00, $88	; sprite 3

	.org $FFFA	; first of the three vectors starts here
	.dw NMI		; when an NMI happens (once per frame if enabled) the
			; processor will jump to the label NMI:
	.dw RESET	; when the processor first turns on or is reset, it will jump
			; to the label RESET:
	.dw 0		; external interrupt IRQ is not used in this tutorial

;;;;;;;;;;;;;;;;;;

	.data
	.bank 2
	.org $0000

	.incbin "mario.chr"	;includes 8KB graphics file from SMB1

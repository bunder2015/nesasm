STATETITLE	.equ $00	; displaying title screen
STATEPLAYING	.equ $01	; move paddles/ball, check for collisions
STATEGAMEOVER	.equ $02	; displaying game over screen

RIGHTWALL	.equ $F4	; when ball reaches one of these, do something
TOPWALL		.equ $20
BOTTOMWALL	.equ $E0
LEFTWALL	.equ $04

PADDLE1X	.equ $08	; horizontal position for paddles, doesnt move
PADDLE2X	.equ $F0

##########
#
# Nerdy Nights (week 9) "pong2" by bunnyboy
# Borrowed from:
#	http://nintendoage.com/forum/messageview.cfm?catid=22&threadid=33308
# Slightly modified syntax for the improved nesasm by bunder2015 (and others)
#	https://github.com/bunder2015/nesasm
#
##########

Assemble with: nesasm -S pong2.asm

This directory also contains two extra files:
	nes-const.asm - A list of NES register variables
	nes-ppu-bss.asm - A list of sprite slots if using $0200-02FF for PPU 
		OAM transfers

Game variables were spread across ZP and BSS for syntax examples, the .rs
directive is not needed.

A bug was fixed where ZP access was being done through absolute addressing
rather than ZP addressing.

This code appears to be incomplete and buggy, however it does assemble and run.
It displays a screen full of "0" characters, the incrementing score in the top
left corner, and some garbled graphics floating around the screen.

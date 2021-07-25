INCLUDE "hardware.inc"

SECTION "Image", ROM0
INCBIN "obj/image.2bpp"

SECTION "MainCode", ROM0
ASSERT SIZEOF("Image") <= ((160 * 144 * 2) / 8), "Image is too large! Needs to be 160 x 144"
EntryPoint::
    ld sp, $E000 ; Set the stack pointer to the top of RAM to free up HRAM

    ; Turn off the LCD
.waitVBlank:
	ld a, [rLY]
	cp 144 ; Check if the LCD is past VBlank
	jr c, .waitVBlank
	xor a ; turn off the LCD
	ld [rLCDC], a

    ; Copy image tileset into VRAM
    ld hl, _VRAM
    ld de, STARTOF("Image")
    ld bc, SIZEOF("Image")
    call memcpy

    ; Copy first chunk of tilemap into VRAM
    ld hl, _SCRN0
    xor a
    ld bc, 12 ; Offset needed to jump from end of this line to start of next line
    ld e, 20 ; 20 tiles in a line
.tilemapCopyLp1:
    ld [hli], a
    dec e
    jr nz, .noNewLine
    add hl, bc
    ld e, 20
.noNewLine:
    inc a
    cp $F0
    jr nz, .tilemapCopyLp1

    ; Copy second chunk of tilemap into VRAM
    ld hl, _SCRN1 + $180
    ld a, -16
    ld e, 20
.tilemapCopyLp2:
    ld [hli], a
    dec e
    jr nz, .noNewLine2
    add hl, bc
    ld e, 20
.noNewLine2:
    inc a
    cp $68
    jr nz, .tilemapCopyLp2

    ; Init display registers
	ld a, %11100100 ; Init background palette
	ldh [rBGP], a
    xor a ; Init scroll registers
	ldh [rSCY], a
	ldh [rSCX], a

    ; Init mid-screen interrupt
    ld a, 96 ; Scanline to interrupt on
    ld [rLYC], a
    ld a, STATF_LYC ; Enable LY=LYC interrupt source
    ld [rSTAT], a

    ; Shut sound down
    xor a
    ldh [rNR52], a

    ; Enable screen and initialise screen settings
    ld a, LCDCF_ON | LCDCF_WIN9C00 | LCDCF_WINOFF | LCDCF_BG8000 \
        | LCDCF_BG9800 | LCDCF_OBJ8 | LCDCF_OBJOFF | LCDCF_BGON
    ldh [rLCDC], a

    ; Disable all interrupts except VBlank and LCDC
	ld a, IEF_VBLANK | IEF_LCDC
	ldh [rIE], a
	ei
MainLoop:
    halt
    jr MainLoop

VBlank::
    ld a, [rLCDC]
    set 4, a ; set background tileset to LCDCF_BG8000
    res 3, a ; set background tilemap to LCDCF_BG9800
    ld [rLCDC], a
    reti

LCDInterrupt::
    ld a, [rLCDC]
    res 4, a ; set background tileset to LCDCF_BG8800
    set 3, a ; set background tilemap to LCDCF_BG9C00
    ld [rLCDC], a
    reti

; Copies a block of data
; Input - HL = Destination address
; Input - DE = Start address
; Input - BC = Data length
; Sets	- A B C to 0
; Sets	- H L D E to garbage
memcpy::
	ld a, [de] ; Grab 1 byte from the source
	ld [hli], a ; Place it at the destination, incrementing hl
	inc de ; Move to next byte
	dec bc ; Decrement count
	ld a, b ; Check if count is 0, since `dec bc` doesn't update flags
	or c
	jr nz, memcpy
	ret
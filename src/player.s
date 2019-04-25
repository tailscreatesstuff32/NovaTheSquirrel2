; Super Princess Engine
; Copyright (C) 2019 NovaSquirrel
;
; This program is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation; either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
.include "snes.inc"
.include "global.inc"
.smart

.segment "ZEROPAGE"

.segment "Player"

.a16
.i16
.import PlayerGraphics
.proc PlayerFrameUpload
  php
  seta16

  ; Set DMA parameters  
  lda #DMAMODE_PPUDATA
  sta DMAMODE+$00
  sta DMAMODE+$10

  lda PlayerFrame
  and #255         ; Zero extend
  xba              ; *256
  asl              ; *512
  ora #$8000
  sta DMAADDR+$00
  ora #256
  sta DMAADDR+$10

  lda #32*8 ; 8 tiles for each DMA
  sta DMALEN+$00
  sta DMALEN+$10

  lda #($8000)>>1
  sta PPUADDR
  seta8
  lda #^PlayerGraphics
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #%00000001
  sta COPYSTART

  ; Bottom row -------------------
  seta16
  lda #($8200)>>1
  sta PPUADDR
  seta8
  lda #%00000010
  sta COPYSTART

  plp
  rtl
.endproc

.a16
.i16
.proc RunPlayer
  php
  phk
  plb

  jsr HandlePlayer
  jsr DrawPlayer

  ; Automatically cycle through the walk animation
  seta8
  lda retraces
  lsr
  lsr
  and #7
  inc a
  sta PlayerFrame 

  plp
  rtl
.endproc

.a16
.i16
.proc HandlePlayer
cur_keys = JOY1CUR
  lda cur_keys
  and #KEY_RIGHT
  beq :+
    seta8
    stz PlayerDir
    seta16

    lda PlayerPX
    add #16*4
    sta PlayerPX
  :

  lda cur_keys
  and #KEY_LEFT
  beq :+
    seta8
    lda #1
    sta PlayerDir
    seta16

    lda PlayerPX
    sub #16*4
    sta PlayerPX
    bcs :+
      stz PlayerPX
  :

  lda cur_keys
  and #KEY_UP
  beq :+
    lda PlayerPY
    sub #16*4
    sta PlayerPY
    bcs :+
      stz PlayerPY
  :

  lda cur_keys
  and #KEY_DOWN
  beq :+
    lda PlayerPY
    add #16*4
    sta PlayerPY
  :


  setaxy16
  rts
.endproc

.a16
.i16
.proc DrawPlayer
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3
  ldx OamPtr

  ; X coordinate to pixels
  lda PlayerPX
  sub ScrollX
  lsr
  lsr
  lsr
  lsr
  sta 0

  ; Y coordinate to pixels
  lda PlayerPY
  sub ScrollY
  lsr
  lsr
  lsr
  lsr
  sta 2

  lda #$0200  ; Use 16x16 sprites
  sta OAMHI+(4*0),x
  sta OAMHI+(4*1),x
  sta OAMHI+(4*2),x
  sta OAMHI+(4*3),x

  seta8
  lda 0
  sta OAM_XPOS+(4*1),x
  sta OAM_XPOS+(4*3),x
  sub #16
  sta OAM_XPOS+(4*0),x
  sta OAM_XPOS+(4*2),x

  lda 2
  sta OAM_YPOS+(4*2),x
  sta OAM_YPOS+(4*3),x
  sub #16
  sta OAM_YPOS+(4*0),x
  sta OAM_YPOS+(4*1),x


  ; Tile numbers
  lda #0
  sta OAM_TILE+(4*0),x
  lda #2
  sta OAM_TILE+(4*1),x
  lda #4
  sta OAM_TILE+(4*2),x
  lda #6
  sta OAM_TILE+(4*3),x

  ; Background flip
  lda PlayerDir
  beq :+
    ; Rewrite tile numbers
    lda #2
    sta OAM_TILE+(4*0),x
    lda #0
    sta OAM_TILE+(4*1),x
    lda #6
    sta OAM_TILE+(4*2),x
    lda #4
    sta OAM_TILE+(4*3),x

    lda #%01000000
  :
  ora #%00100000 ; priority
  sta OAM_ATTR+(4*0),x
  sta OAM_ATTR+(4*1),x
  sta OAM_ATTR+(4*2),x
  sta OAM_ATTR+(4*3),x
 
  seta16
  ; Four sprites
  txa
  clc
  adc #4*4
  sta OamPtr
  rts
.endproc

; Super Princess Engine
; Copyright (C) 2019-2020 NovaSquirrel
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
.include "blockenum.s"
.import ActorRun, ActorDraw, ActorFlags, ActorWidth, ActorHeight, ActorBank, ActorGraphic, ActorPalette
.import ActorGetShot
.smart

.segment "ActorCommon"

; Two comparisons to make to determine if something is a slope
SlopeBCC = Block::MedSlopeL_DL
SlopeBCS = Block::GradualSlopeR_U4_Dirt+1
.export SlopeBCC, SlopeBCS
SlopeY = 2

.export RunAllActors
.proc RunAllActors
  setaxy16

  ; Prepare for the loop
  lda PaletteInUse+0
  sta PaletteInUseLast+0
  lda PaletteInUse+2
  sta PaletteInUseLast+2
  lda SpriteTilesInUse+0
  sta SpriteTilesInUseLast+0
  lda SpriteTilesInUse+2
  sta SpriteTilesInUseLast+2
  lda SpriteTilesInUse+4
  sta SpriteTilesInUseLast+4
  lda SpriteTilesInUse+6
  sta SpriteTilesInUseLast+6
  lda SpriteTilesInUse+8
  sta SpriteTilesInUseLast+8
  ; Prepare for the next frame
  stz PaletteInUse+0
  stz PaletteInUse+2
  stz SpriteTilesInUse+0
  stz SpriteTilesInUse+2
  stz SpriteTilesInUse+4
  stz SpriteTilesInUse+6

  ; Load X with the actual pointer
  ldx #ActorStart
Loop:
  ; Don't do anything if it's an empty slot
  lda ActorType,x
  bne :+
@JmpSkipEntity:
    jmp SkipEntity 
  :


  lda ActorState,x
  and #255
  cmp #ActorStateValue::Override
  bne NotOverride
    ; Substitute the run routine for something else
    phk
    plb
    txy ; All override routines will have to TYX
    lda ActorTimer,x ; Reuse the timer to determine which override to use
    tax

    assert_same_banks RunAllActors, ActorRunOverrideList
    .import ActorRunOverrideList
    jsr (.loword(ActorRunOverrideList),x)

    ; Call the draw routine now
    lda ActorType,x
    jsl CallDraw

    ; Don't run the common routines
    bra @JmpSkipEntity
  NotOverride:

  ; Call the run and draw routines
  lda ActorType,x ; Reloading is faster than push/pull
  jsl CallRun
  lda ActorType,x
  jsl CallDraw

  ; Call the common routines
  lda ActorType,x
  beq SkipEntity
  phx
  tax
  lda f:ActorFlags,x
  plx

  lsr ; AutoRemove
  bcc NotAutoRemove
    ; Remove entity if too far away from the player
    pha
    lda ActorPX,x
    sub PlayerPX
    abs
    cmp #$2000 ; How about two screens of distance does it?
    bcc :+
      jsl ActorSafeRemoveX
      pla
      bra SkipEntity   ; Skip doing anything else with this entity since it no longer exists
    :
    pla
  NotAutoRemove:

  lsr ; AutoReset
  bcc NotAutoReset
    pha
    lda ActorTimer,x
    beq :+
    dec ActorTimer,x
    bne :+
      ; Clear the state
      seta8
      stz ActorState,x
      seta16
    :
    pla
  NotAutoReset:

  lsr ; GetShot
  bcc NotGetShot
    pha
    jsl ActorGetShot
    pla
  NotGetShot:

  lsr ; WaitUntilNear
  bcc NotWaitUntilNear
    pha
    jsl ActorActivateIfNear
    pla
  NotWaitUntilNear:

  lsr ; WaitForCameraVertically
  bcc NotWaitCameraVertically
    pha
    jsl ActorWaitForCameraVertically
    pla
  NotWaitCameraVertically:

  ; Reset the "init" state
  seta8
  lda ActorState,x
  cmp #ActorStateValue::Init
  bne :+
    stz ActorState,x
  :
  seta16
SkipEntity:

  ; Next entity
  txa
  add #ActorSize
  tax
  cpx #ProjectileEnd ; NOT ActorEnd, go and run the projectiles too
  jne Loop

  jml RunAllParticles

; Call the Actor run code
.a16
CallRun:
  phx
  tax
  seta8
  lda f:ActorBank+0,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorRun,x
  sta 0
  plx

  ; Jump to it and return with an RTL
  jml [0]

; Call the Actor draw code
.a16
CallDraw:
  phx
  tax
  seta8
  lda f:ActorBank+1,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorDraw,x
  sta 0

  ; Get the desired tileset
  lda f:ActorGraphic,x
  jmi UseZero ; Using $ffff to indicate a tileset is not needed

  ; Detect the correct tile base
  ; using an unrolled loop
  cmp SpriteTileSlots+2*0
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*0
    inc SpriteTilesInUse+0
    lda #$100
    jmp FoundTileset
  :
  cmp SpriteTileSlots+2*1
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*1
    inc SpriteTilesInUse+1
    lda #$120
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*2
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*2
    inc SpriteTilesInUse+2
    lda #$140
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*3
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*3
    inc SpriteTilesInUse+3
    lda #$160
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*4
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*4
    inc SpriteTilesInUse+4
    lda #$180
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*5
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*5
    inc SpriteTilesInUse+5
    lda #$1A0
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*6
  bne :+
    lda framecount
    sta SpriteTilesUseTime+2*6
    inc SpriteTilesInUse+6
    lda #$1C0
    bra FoundTileset
  :
  cmp SpriteTileSlots+2*7
  jne SpriteTilesNotFound
    lda framecount
    sta SpriteTilesUseTime+2*7
    inc SpriteTilesInUse+7
    lda #$1E0
    bra FoundTileset

UseZero:
  lda #0
FoundTileset:
  sta SpriteTileBase

  ; Detect the correct palette
  ; using an unrolled loop again
  lda f:ActorPalette,x
  bmi NoPaletteNeeded ; $ffff for no palette
  cmp SpritePaletteSlots+2*0
  bne :+
    inc PaletteInUse+0
    lda #%1000<<8
    bra FoundPalette
  :
  cmp SpritePaletteSlots+2*1
  bne :+
    inc PaletteInUse+1
    lda #%1010<<8
    bra FoundPalette
  :
  cmp SpritePaletteSlots+2*2
  bne :+
    inc PaletteInUse+2
    lda #%1100<<8
    bra FoundPalette
  :
  cmp SpritePaletteSlots+2*3
  bne :+
    inc PaletteInUse+3
    lda #%1110<<8
    bra FoundPalette
  :

  ; -----------------------------------
  ; Palette not found, so request it!
  lda PaletteRequestIndex
  bne PaletteNotFound ; Unless a palette is already being requested, then wait for next frame

  ; Prefer unassigned palette slots first
  ldy #4*2-2
  lda #$ffff
: cmp SpritePaletteSlots,y
  beq FoundPaletteRequestIndex
  dey
  dey
  bpl :-

  ; No unassigned ones? Just look for one that wasn't used last frame
  seta8
  ldy #4-1
: lda PaletteInUseLast,y
  beq FoundPaletteRequestIndex2 ; No Actors using this palette
  dey
  bpl :-
  ; No suitable slots found, so give up for this frame
  seta16
  bra PaletteNotFound

FoundPaletteRequestIndex2:
  ; Convert the index since PaletteInUseLast is 8-bit while SpritePaletteSlots is 16-bit
  seta16
  tya
  asl
  tay
FoundPaletteRequestIndex:
  ; Write the desired palette into the list of active palettes
  lda f:ActorPalette,x
  sta SpritePaletteSlots,y

  seta8
  ; And also that's the palette we need to request
  sta PaletteRequestValue

  ; Calculate index to upload it to
  tya
  lsr
  ora #8+4 ; Last four sprite palettes
  sta PaletteRequestIndex
  seta16

  ; Use the new palette index,
  ; since it will be there by the time we do OAM DMA
  tya              ; ........ .....pp.
  xba              ; .....pp. ........
  ora #OAM_COLOR_4 ; ....1pp. ........
  bra FoundPalette ; yxPPpppt tttttttt

NoPaletteNeeded:
PaletteNotFound:
  ; Probably exit without drawing it, instead of drawing with the wrong colors
  lda #0
FoundPalette:
  tsb SpriteTileBase

  ; Jump to the per-Actor routine and return with an RTL
  plx ; X now equals the Actor index base again
  jml [0]
.endproc

.pushseg
.segment "ParticleCode"
.a16
.i16
.import ParticleRun, ParticleDraw
assert_same_banks RunAllParticles, ParticleRun
assert_same_banks RunAllParticles, ParticleDraw
.proc RunAllParticles
  phk
  plb

  ldx #ParticleStart
Loop:
  lda ParticleType,x
  beq SkipEntity   ; Skip if empty

  ; Call the run and draw routines
  asl
  pha
  jsr CallRun
  pla
  jsr CallDraw

SkipEntity:
  ; Next particle
  txa
  add #ParticleSize
  tax
  cpx #ParticleEnd
  bne Loop
  rtl

CallRun:
  tay
  lda ParticleRun,y
  pha
  rts
CallDraw:
  tay
  lda ParticleDraw,y
  pha
  rts
.endproc
.popseg

.a16
.i16
.proc SpriteTilesNotFound
; 0 1 and 2 are used as a pointer we don't want to overwrite
WantedGraphic = 4
SmallestValue = 6
SmallestIndex = 8
  ; Attempt to load in the missing tileset dynamically
  sta WantedGraphic ; Accumulator is f:ActorGraphic,x

  lda SpriteTilesRequestSource+2
  and #255
  beq :+
Fail:
    ; Figure out what to do here?
    jmp RunAllActors::FoundTileset
  :

  ; First look for empty slots
  ; (and keep track of what the smallest index is)
  ldy #2*8-2
FindEmpty:
  lda SpriteTileSlots,y ; $00ff marks empty slots currently
  cmp #$00ff
  beq FoundEmpty
  dey
  dey
  bpl FindEmpty

  ; -----------------------------------

  ; If that fails, try to find the smallest slot
  lda #$ffff
  sta SmallestValue
  stz SmallestIndex

  phx
  ldx #7
  ldy #2*8-2
FindSmallest:
  lda SpriteTilesInUseLast,x
  and #255
  bne :+
  lda SpriteTilesUseTime,y
  cmp SmallestValue
  bcs :+
    sta SmallestValue
    sty SmallestIndex
  :
  dex
  dey
  dey
  bpl FindSmallest
  plx

  ; If it somehow couldn't find anything, fail
  lda SmallestValue
  ina
  beq Fail

  ; Okay, now we're ready
  ldy SmallestIndex
FoundEmpty:
  ; Store the value into the correct spot
  lda WantedGraphic
  sta SpriteTileSlots,y

  ; Multiply by 7 by subtracting the original value from value*8
  phx
  lda WantedGraphic
  asl
  asl
  asl
  sub WantedGraphic
  tax
  ; First three bytes are the pointer
  .import GraphicsDirectory
  lda f:GraphicsDirectory+0,x
  sta SpriteTilesRequestSource+0
  lda f:GraphicsDirectory+1,x
  sta SpriteTilesRequestSource+1 ; Gets +2 too

  tya ; Y = Sprite slot number * 2
  xba
  ora #(SpriteCHRBase+$2000) >> 1
  sta SpriteTilesRequestDestination
  plx
  jmp RunAllActors::FoundTileset
.endproc

.a16
.i16
.proc FindFreeActorX
  ldx #ActorStart
Loop:
  lda ActorType,x
  beq Found
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne Loop
  clc
  rtl
Found:
  lda #$ffff
  sta ActorIndexInLevel,x
  seta8
  sta ActorDynamicSlot,x
  seta16
  stz ActorState,x ; Also zeros ActorOnGround
  sec
  rtl
.endproc

.a16
.i16
.proc FindFreeActorY
  ldy #ActorStart
Loop:
  lda ActorType,y
  beq Found
  tya
  add #ActorSize
  tay
  cpy #ActorEnd
  bne Loop
  clc
  rtl
Found:
  lda #$ffff
  sta ActorIndexInLevel,y
  seta8
  sta ActorDynamicSlot,y
  seta16
  tdc ; A = 0
  sta ActorState,y ; Also zeros ActorOnGround
  sec
  rtl
.endproc


.a16
.i16
.proc FindFreeParticleY
  ldy #ParticleStart
Loop:
  lda ParticleType,y
  beq Found
  tya
  add #ParticleSize
  tay
  cpy #ParticleEnd
  bne Loop
  clc
  rtl
Found:
  lda #0
  sta ParticleTimer,y
  sta ParticleVX,y
  sta ParticleVY,y
  sec
  rtl
.endproc

; Just flip the LSB of ActorDirection
.export ActorTurnAround
.a16
.proc ActorTurnAround
  ; No harm in using it as a 16-bit value here, it's just written back
  lda ActorDirection,x
  eor #1
  sta ActorDirection,x
  rtl
.endproc

.export ActorLookAtPlayer
.a16
.proc ActorLookAtPlayer
  lda ActorPX,x
  cmp PlayerPX

  ; No harm in using it as a 16-bit value here, it's just written back
  lda ActorDirection,x
  and #$fffe
  adc #0
  sta ActorDirection,x

  rtl
.endproc

; Causes the Actor to hover in place
; takes over ActorVarC and uses it for hover position
.export ActorHover
.a16
.proc ActorHover
  phb
  phk ; To access the table at the end
  plb
  ldy ActorVarC,x

  seta8
  lda Wavy,y
  sex
  sta 0

  lda ActorPY+0,x
  add Wavy,y
  sta ActorPY+0,x
  lda ActorPY+1,x
  adc 0
  sta ActorPY+1,x

  lda ActorVarC,x
  ina
  and #63
  sta ActorVarC,x
  seta16

  plb
  rtl
Wavy:
  .byt 0, 0, 1, 2, 3, 3, 4
  .byt 5, 5, 6, 6, 7, 7, 7
  .byt 7, 7, 7, 7, 7, 7, 7
  .byt 6, 6, 5, 5, 4, 3, 3
  .byt 2, 1, 0, 0

  .byt <-0, <-0, <-1, <-2, <-3, <-3, <-4
  .byt <-5, <-5, <-6, <-6, <-7, <-7, <-7
  .byt <-7, <-7, <-7, <-7, <-7, <-7, <-7
  .byt <-6, <-6, <-5, <-5, <-4, <-3, <-3
  .byt <-2, <-1, <-0, <-0
.endproc

; Causes the enemy to move back and forth horizontally,
; seeking the player
.export LakituMovement
.a16
.proc LakituMovement
  jsl ActorApplyXVelocity

  ; Bump into enemy barriers
  ldy ActorPY,x
  lda ActorPX,x
  jsl GetLevelPtrXY
  cmp #Block::EnemyBarrier
  bne :+
    lda ActorVX,x
    neg
    sta ActorVX,x
  :

  ; Stop if stunned
  lda ActorState,x ; Ignore high byte
  and #255
  beq :+
    stz ActorVX,x
  :

  ; Change direction to face the player
  jsl ActorLookAtPlayer

  ; Only speed up if not around player
  lda ActorPX,x
  sub PlayerPX
  abs
  cmp #$300
  bcc TooClose
  lda #4
  jsl ActorNegIfLeft
  add ActorVX,x

  ; Limit speed to 3 pixels/frame
  php ; Take absolute value and negate it back if it was negative
  ; Flags are still from the previous add
  bpl :+
    eor #$ffff
    inc a
  :

  cmp #$0030
  bcc :+
    lda #$0030
  :

  plp
  bpl :+
    eor #$ffff
    inc a
  :

  sta ActorVX,x
TooClose:

  rtl
.endproc

; Takes a speed in the accumulator, and negates it if Actor facing left
.a16
.export ActorNegIfLeft
.proc ActorNegIfLeft
  pha
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcs Left
Right:
  pla ; No change
  rtl
Left:
  pla ; Negate
  neg
  rtl
.endproc

.export ActorApplyVelocity
.proc ActorApplyVelocity
  lda ActorPX,x
  add ActorVX,x
  sta ActorPX,x
YOnly:
  lda ActorPY,x
  add ActorVY,x
  sta ActorPY,x
  rtl
.endproc
ActorApplyYVelocity = ActorApplyVelocity::YOnly

.export ActorApplyXVelocity
.export ActorApplyYVelocity
.proc ActorApplyXVelocity
  lda ActorPX,x
  add ActorVX,x
  sta ActorPX,x
  rtl
.endproc


; Walks forward, and turns around if walking farther
; would cause the Actor to fall off the edge of a platform
; input: A (walk speed), X (Actor slot)
.export ActorWalkOnPlatform
.proc ActorWalkOnPlatform
  jsl ActorWalk
  jsl ActorAutoBump
.endproc
; fallthrough
.a16
.export ActorStayOnPlatform
.proc ActorStayOnPlatform
  ; Check forward a bit
  ldy ActorPY,x
  lda #8*16
  jsl ActorNegIfLeft
  add ActorPX,x
  jsl ActorTryDownInteraction

  cmp #$4000 ; Test for solid on top
  bcs :+
    jsl ActorTurnAround
  :
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; Will try the second layer if the first is not solid
; A = X coordinate, Y = Y coordinate
.export ActorTryUpInteraction
.import BlockRunInteractionActorTopBottom
.proc ActorTryUpInteraction
  bit TwoLayerInteraction-1
  bmi TwoLayer
FirstLayer:
  jsl GetLevelPtrXY
Run:
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl

TwoLayer:
  pha
  phy
  jsl FirstLayer
  bmi FirstSolid

  ; Try second layer
  pla
  add FG2OffsetY
  tay
  pla
  add FG2OffsetX
  jsl GetLevelPtrXY
  lda #$4000
  tsb LevelBlockPtr
  lda [LevelBlockPtr]
  bra Run

FirstSolid:
  ply
  pla
  lda BlockFlag
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; Will try the second layer if the first is not solid or solid on top
; A = X coordinate, Y = Y coordinate
.export ActorTryDownInteraction
.proc ActorTryDownInteraction
  bit TwoLayerInteraction-1
  bmi TwoLayer
FirstLayer:
  jsl GetLevelPtrXY
Run:
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl

TwoLayer:
  pha
  phy
  jsl FirstLayer
  cmp #$4000
  bcs FirstSolid

  ; Try second layer
  pla
  add FG2OffsetY
  tay
  pla
  add FG2OffsetX
  jsl GetLevelPtrXY
  lda #$4000
  tsb LevelBlockPtr
  lda [LevelBlockPtr]
  bra Run

FirstSolid:
  ply
  pla
  lda BlockFlag
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; A = X coordinate, Y = Y coordinate
.export ActorTrySideInteraction
.import BlockRunInteractionActorSide
.proc ActorTrySideInteraction
  bit TwoLayerInteraction-1
  bmi TwoLayer
FirstLayer:
  jsl GetLevelPtrXY
Run:
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorSide
  lda BlockFlag
  rtl

TwoLayer:
  pha
  phy
  jsl FirstLayer
  bmi FirstSolid

  ; Try second layer
  pla
  add FG2OffsetY
  tay
  pla
  add FG2OffsetX
  jsl GetLevelPtrXY
  lda #$4000
  tsb LevelBlockPtr
  lda [LevelBlockPtr]
  bra Run

FirstSolid:
  ply
  pla
  lda BlockFlag
  rtl
.endproc

.a16
.export ActorWalk
.proc ActorWalk
WalkDistance = 0
  jsl ActorNegIfLeft
  sta WalkDistance

  ; Don't walk if the state is nonzero
  lda ActorState,x
  and #255
  beq :+
    clc
    rtl
  :

  ; Look up if the wall is solid
  lda ActorPY,x
  sub #1<<7
  tay
  lda ActorPX,x
  add WalkDistance
  jsl ActorTrySideInteraction
  bpl NotSolid
  Solid:
     sec
     rtl
  NotSolid:

  ; Apply the walk
  lda ActorPX,x
  add WalkDistance
  sta ActorPX,x
  ; Fall into ActorDownhillFix
.endproc
.a16
.proc ActorDownhillFix

  ; Going downhill requires special help
  seta8
  lda ActorOnGround,x ; Need to have been on ground last frame
  beq NoSlopeDown
  lda ActorVY+1,x
  bmi NoSlopeDown
  seta16
    jsr ActorGetSlopeYPos
    bcs :+
      ; Try again one block below
      inc LevelBlockPtr
      inc LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorGetSlopeYPosBelow
      bcc NoSlopeDown
    :

    lda SlopeY
    sta ActorPY,x
    stz ActorVY,x
  NoSlopeDown:
  seta16

  ; Reset carry to indicate not bumping into something
  ; because ActorWalk falls into this
  clc
  rtl
.endproc

.a16
.export ActorGravity
.proc ActorGravity
  lda ActorVY,x
  bmi OK
  cmp #$60
  bcs Skip
OK:
  add #4
  sta ActorVY,x
Skip:
  jmp ActorApplyYVelocity
.endproc

; Calls ActorGravity and then fixes things if they land on a solid block
; input: X (Actor pointer)
; output: carry (standing on platform)
.a16
.export ActorFall
.proc ActorFall
  jsl ActorGravity
OnlyGroundCheck:
  ; Remove if too far off the bottom
  lda ActorPY,x
  bmi :+
    cmp #32*256
    bcc :+
    cmp #$ffff - 2*256
    bcs :+
      jml ActorSafeRemoveX
  :

  jmp ActorCheckStandingOnSolid
.endproc
ActorFallOnlyGroundCheck = ActorFall::OnlyGroundCheck
.export ActorFallOnlyGroundCheck

.a16
.export ActorBumpAgainstCeiling
.proc ActorBumpAgainstCeiling
  phx
  lda ActorType,x
  tax
  lda f:ActorHeight,x
  plx
  ; Reverse subtraction
  eor #$ffff
  sec
  adc ActorPY,x
  tay
  lda ActorPX,x
  jsl ActorTryUpInteraction
  asl
  bcc :+
    lda #$ffff
    sta 0 ; Did hit the ceiling - communicate this a different way?
    lda #$20
    sta ActorVY,x
    clc
  :
  rtl
.endproc

; Checks if an Actor is on top of a solid block
; input: X (Actor slot)
; output: Zero flag (not zero if on top of a solid block)
; locals: 0, 1
; Currently 0 is set to $ffff if it bumps against the ceiling, but that's sort of flimsy
.a16
.export ActorCheckStandingOnSolid
.proc ActorCheckStandingOnSolid
  seta8
  stz ActorOnGround,x
  seta16

  ; If going upwards, bounce against ceilings
  stz 0
  lda ActorVY,x
  bmi ActorBumpAgainstCeiling

  ; Check for slope interaction
  jsr ActorGetSlopeYPos
  bcc :+
    lda SlopeY
;    cmp ActorPY,x
;    bcs :+
    sta ActorPY,x
    stz ActorVY,x

    seta8
    inc ActorOnGround,x
    seta16
    ; Don't do the normal ground check
    sec
    rtl
  :

  ; Maybe add checks for the sides
  ldy ActorPY,x
  lda ActorPX,x
  jsl ActorTryDownInteraction
  cmp #$4000
  rol 0

  lda 0
  seta8
  sta ActorOnGround,x
  ; React to touching the ground
  beq NotSnapToGround
    lda LevelBlockPtr+1
    and #$40
    bne SecondLayer

    stz ActorPY,x ; Clear the low byte
    seta16
    stz ActorVY,x
    sec
    rtl
  ; On the second layer, take the Y offset into account
  SecondLayer:
    ; Mark as standing on the second layer
    stz ActorVY,x
    seta8
    lda #128
    ora ActorOnGround,x
    sta ActorOnGround,x
    seta16

    lda FG2OffsetY
    and #$00ff
    sta 0
    lda ActorPY,x
    add 0
    and #$ff00
    sub 0
    sta ActorPY,x
    sec
    rtl
  NotSnapToGround:
  seta16
  clc
  rtl
.endproc

; Get the Y position of the slope under the player's hotspot (SlopeY)
; and also return if they're on a slope at all (carry)
.a16
.proc ActorGetSlopeYPos
  ldy ActorPY,x
  lda ActorPX,x
  jsl GetLevelPtrXY
  jsr ActorIsSlope
  bcc NotSlope
    assert_same_banks ActorGetSlopeYPos, SlopeHeightTable
    phk
    plb
    lda ActorPY,x
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorIsSlope
      bcc :+
        lda ActorPY,x
        sbc #$0100 ; assert((PS & 1) == 1) Carry already set
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  rts
.endproc

.a16
; Similar but for checking one block below
.proc ActorGetSlopeYPosBelow
  jsr ActorIsSlope
  bcc NotSlope
    assert_same_banks ActorGetSlopeYPos, SlopeHeightTable
    lda ActorPY,x
    add #$0100
    and #$ff00
    ora SlopeHeightTable,y
    sta SlopeY

    lda SlopeHeightTable,y
    bne :+
      ; Move the level pointer up and reread
      dec LevelBlockPtr
      dec LevelBlockPtr
      lda [LevelBlockPtr]
      jsr ActorIsSlope
      bcc :+
        lda ActorPY,x
        ora SlopeHeightTable,y
        sta SlopeY
    :
  sec
NotSlope:
  rts
.endproc

.a16
.proc ActorIsSlope
  cmp #SlopeBCC
  bcc :+
  cmp #SlopeBCS
  bcs :+
  sub #SlopeBCC
  ; Now we have the block ID times 2

  ; Multiply by 16 to get the index into the slope table
  asl
  asl
  asl
  asl
  sta 0

  ; Select the column
  lda ActorPX,x
  and #$f0 ; Get the pixels within a block
  lsr
  lsr
  lsr
  ora 0
  tay

  sec ; Success
  rts
: clc ; Failure
  rts
.endproc

; Automatically turn around when bumping
; into something during ActorWalk
.a16
.export ActorAutoBump
.proc ActorAutoBump
  bcc NoBump
  jmp ActorTurnAround
NoBump:
  rtl
.endproc

; Automatically removes an Actor if they're too far away from the camera
.a16
.export ActorAutoRemove
.proc ActorAutoRemove
  lda ActorPX
  sub ScrollX
  cmp #.loword(-8*256)
  bcs Good
  cmp #32*256
  bcc Good
  jml ActorSafeRemoveX
Good:
  rtl
.endproc

; Automatically removes an Actor if they're too far away from the camera
; (Bigger range)
.a16
.export ActorAutoRemoveFar
.proc ActorAutoRemoveFar
  lda ActorPX
  sub ScrollX
  cmp #.loword(-24*256)
  bcs Good
  cmp #40*256
  bcc Good
  jml ActorSafeRemoveX
Good:
  rtl
.endproc


; Calculate the position of the 16x16 Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition16x16
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  sub FGScrollXPixels
  sub #8
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  adc #0 ; Why do I need to round Y and not X?
  sub FGScrollYPixels
  sub #17
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; Calculate the position of the 8x8 Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition8x8
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  sub FGScrollXPixels
  sub #4
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  adc #0 ; Why do I need to round Y and not X?
  sub FGScrollYPixels
  sub #9
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; For meta sprites
; TODO: Don't round the object and camera positions together
.a16
.proc ActorDrawPositionMeta
  lda ActorPX,x
  sub ScrollX
  cmp #.loword(-1*256)
  bcs :+
  cmp #17*256
  bcs ActorDrawPosition16x16::Invalid
: jsr Shift
  ; No hardcoded offset
  sta 0

  lda ActorPY,x
  sub ScrollY
  ; TODO: properly allow sprites to be partially offscreen on the top
;  cmp #.loword(-1*256)
;  bcs :+
  cmp #16*256
  bcs ActorDrawPosition16x16::Invalid
  jsr Shift
  ; No hardcoded offset
  sta 2

  sec
  rts

Shift:
  eor #.loword(-$8000)
  lsr
  lsr
  lsr
  lsr
  add #.loword(-($8000 >> 4))
  rts
.endproc

; A = tile to draw
.a16
.export DispActor16x16
.proc DispActor16x16
  sta 4

  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  ldy OamPtr

  jsr ActorDrawPosition16x16
  bcs :+
    seta8
    stz ActorOnScreen,x
    seta16
    rtl
  :  

  ; If stunned, flip upside down
  lda ActorState,x
  and #$00ff
  cmp #ActorStateValue::Stunned
  bne :+
    phx
    ; Adjust Y position, for actors that are not the full 16 pixels tall
    lda ActorType,x
    tax
    lda #16<<4
    sub f:ActorHeight,x
    lsr
    lsr
    lsr
    lsr
    add 2
    sta 2

    ; Use Y flip
    lda #OAM_YFLIP
    tsb 4
    plx
  :

  lda 4
  ora SpriteTileBase
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00000001
  lda #1 ; 16x16 sprites
  sta ActorOnScreen,x
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc

; A = tile to draw, with X and/or Y flips embedded
; but where X flips ignore the original direction
; locals: 0
.a16
.export DispActor16x16FlippedAbsolute
.proc DispActor16x16FlippedAbsolute
  sta 0

  ; Direction and state are right next to each other, so they can be saved together
  ; with a 16-bit push/pull
  lda ActorDirection,x
  pha
  stz ActorDirection,x ; Start as zero

  ; Temporarily write new values
  seta8
  lda #>OAM_XFLIP
  trb 1
  beq :+
    inc ActorDirection,x
  :
Finish:
  lda #>OAM_YFLIP
  trb 1
  beq :+
    lda #ActorStateValue::Stunned
    sta ActorState,x
  :
  seta16

  lda 0
  jsl DispActor16x16

  ; Restore direction and state
  pla
  sta ActorDirection,x

  rtl
.endproc

; A = tile to draw, with X and/or Y flips embedded
; where the X flip bit inverts the original direction
; locals: 0
.a16
.export DispActor16x16Flipped
.proc DispActor16x16Flipped
  sta 0

  ; Direction and state are right next to each other, so they can be saved together
  ; with a 16-bit push/pull
  lda ActorDirection,x
  pha
  ; Don't clear ActorDirection,x

  ; Temporarily write new values
  seta8
  lda #>OAM_XFLIP
  trb 1
  beq :+
    lda ActorDirection,x
    eor #1
    sta ActorDirection,x
  :
  bra DispActor16x16FlippedAbsolute::Finish
.endproc

; A = tile to draw
.a16
.export DispActor8x8
.proc DispActor8x8
  sta 4

  stz SpriteXYOffset
CustomOffset:
  ; If facing left, set the X flip bit
  lda ActorDirection,x ; Ignore high byte
  lsr
  bcc :+
    lda #OAM_XFLIP
    tsb 4
  :

  ldy OamPtr

  jsr ActorDrawPosition8x8
  bcs :+
    rtl
  :

  lda 4
  ora SpriteTileBase
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  add SpriteXYOffset+0
  sta OAM_XPOS,y
  lda 2
  add SpriteXYOffset+1
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00000001
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl

WithOffset:
  sta 4
  bra CustomOffset
.endproc
DispActor8x8WithOffset = DispActor8x8::WithOffset
.export DispActor8x8WithOffset


.a16
.i16
.export DispActorMetaLeft
.proc DispActorMetaLeft
  lda SpriteTileBase
  eor #OAM_XFLIP
  sta SpriteTileBase

  lda #.loword(-8)
  sta 8 ;WidthUnit
  bra DispActorMetaLeftOrRight
.endproc

.a16
.i16
.export DispActorMetaPriority2
.proc DispActorMetaPriority2
  pha
  lda #OAM_PRIORITY_2
  tsb SpriteTileBase
  pla
  bra DispActorMeta
.endproc

; Appropriately selects left or right
.a16
.i16
.export DispActorMeta
.proc DispActorMeta
  sta DecodePointer
  seta8
  lda ActorDirection,x
  lsr
  seta16
  bcs DispActorMetaLeft
  ; Fall into the next routine
.endproc
; -------------------- keep together --------------------
.a16
.i16
.export DispActorMetaRight
.proc DispActorMetaRight
  lda #8
  sta 8 ;WidthUnit
.endproc
.proc DispActorMetaLeftOrRight
BasePixelX = 0
BasePixelY = 2
Pointer = DecodePointer
CurrentX = 4
CurrentY = 6
WidthUnit= 8
Count    = 10
TempTile = 12
  ldy OamPtr

  ; Get the base pixel positions
  jsr ActorDrawPositionMeta
  bcs :+
    rtl
  :

StripStart:
  ; Size bit and count
  lda (Pointer)
  inc Pointer
  and #255
  cmp #255
  beq Exit
  pha ; Save size bit
  and #15
  sta Count

  pla
  and #128
  bne SixteenStripStart

  ; X
  lda (Pointer)
  ; Negate if WidthUnit goes left
  bit WidthUnit
  bpl :+
    neg
  :
  add BasePixelX
  sub #4
  sta CurrentX
  inc Pointer
  inc Pointer

  ; Y
  lda (Pointer)
  add BasePixelY
  sub #7
  sta CurrentY
  inc Pointer
  inc Pointer

.a16
StripLoop:
  ; Now read off a series of tiles
  lda (Pointer)
  and #64
  bne StripSkip

  jsr StripLoopCommon
  .a8
  lda #0
  rol
  sta OAMHI+1,y
  seta16

  ; Next sprite
  iny
  iny
  iny
  iny
StripSkip:
  inc Pointer

  lda CurrentX
  add WidthUnit
  sta CurrentX
  dec Count
  bne StripLoop
  bra StripStart
  
Exit:
  sty OamPtr
  rtl

; -------------------------------------

.a16
SixteenStripStart:
  ; Use 16 pixel units instead
  asl WidthUnit

  ; X
  lda (Pointer)
  ; Negate if WidthUnit goes left
  bit WidthUnit
  bpl :+
    neg
  :
  add BasePixelX
  sub #8
  sta CurrentX
  inc Pointer
  inc Pointer

  ; Y
  lda (Pointer)
  add BasePixelY
  sub #15
  sta CurrentY
  inc Pointer
  inc Pointer

SixteenStripLoop:
  ; Now read off a series of tiles
  lda (Pointer)
  and #64
  bne SixteenStripSkip

  jsr StripLoopCommon
  .a8
  lda #1
  rol
  sta OAMHI+1,y
  seta16

  ; Next sprite
  iny
  iny
  iny
  iny
SixteenStripSkip:
  inc Pointer

  lda CurrentX
  add WidthUnit
  sta CurrentX
  dec Count
  bne SixteenStripLoop

  ; Set WidthUnit back to how it was
  lda WidthUnit
  asr
  sta WidthUnit
  jmp StripStart

.a16
StripLoopCommon:
  lda (Pointer)
  pha
  and #31
  ora SpriteTileBase
  sta TempTile
  pla
  and #%11000000 ; The X and Y flip bits
  xba            ; Shift them over to where they are in the attributes
  eor TempTile
  sta OAM_TILE,y

  seta8
  lda CurrentX
  sta OAM_XPOS,y
  lda CurrentY
  sta OAM_YPOS,y
  lda CurrentX+1
  cmp #%00000001
  rts
.endproc

.a16
.proc ParticleDrawPosition
  lda ParticlePX,x
  sub ScrollX
  cmp #.loword(-1*256)
  bcs :+
  cmp #16*256
  bcs Invalid
: lsr
  lsr
  lsr
  lsr
  sub #4
  sta 0

  lda ParticlePY,x
  sub ScrollY
  cmp #15*256
  bcs Invalid
  lsr
  lsr
  lsr
  lsr
  sub #4
  sta 2

  sec
  rts
Invalid:
  clc
  rts
.endproc

; A = tile to draw
; Very similar to DispParticle8x8; maybe combine them somehow?
.a16
.export DispParticle16x16
.proc DispParticle16x16
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #1 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc


; A = tile to draw
.a16
.export DispParticle8x8
.proc DispParticle8x8
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc

.export SlopeHeightTable
.proc SlopeHeightTable
; MedSlopeL_DL
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; MedSlopeR_DR
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeL_D1
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeL_D2
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeR_D3
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; GradualSlopeR_D4
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; SteepSlopeL_D
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

; SteepSlopeR_D
.word $00, $00, $00, $00, $00, $00, $00, $00
.word $00, $00, $00, $00, $00, $00, $00, $00

.repeat 2
;MedSlopeL_UL
.word $f0, $f0, $e0, $e0, $d0, $d0, $c0, $c0
.word $b0, $b0, $a0, $a0, $90, $90, $80, $80

;MedSlopeL_UR
.word $70, $70, $60, $60, $50, $50, $40, $40
.word $30, $30, $20, $20, $10, $10, $00, $00

;MedSlopeR_UL
.word $00, $00, $10, $10, $20, $20, $30, $30
.word $40, $40, $50, $50, $60, $60, $70, $70

;MedSlopeR_UR
.word $80, $80, $90, $90, $a0, $a0, $b0, $b0
.word $c0, $c0, $d0, $d0, $e0, $e0, $f0, $f0

;SteepSlopeL_U
.word $f0, $e0, $d0, $c0, $b0, $a0, $90, $80
.word $70, $60, $50, $40, $30, $20, $10, $00

;SteepSlopeR_U
.word $00, $10, $20, $30, $40, $50, $60, $70
.word $80, $90, $a0, $b0, $c0, $d0, $e0, $f0

;GradualSlopeL_U1
.word $f0, $f0, $f0, $f0, $e0, $e0, $e0, $e0
.word $d0, $d0, $d0, $d0, $c0, $c0, $c0, $c0

;GradualSlopeL_U2
.word $b0, $b0, $b0, $b0, $a0, $a0, $a0, $a0
.word $90, $90, $90, $90, $80, $80, $80, $80

;GradualSlopeL_U3
.word $70, $70, $70, $70, $60, $60, $60, $60
.word $50, $50, $50, $50, $40, $40, $40, $40

;GradualSlopeL_U4
.word $30, $30, $30, $30, $20, $20, $20, $20
.word $10, $10, $10, $10, $00, $00, $00, $00

;GradualSlopeR_U1
.word $00, $00, $00, $00, $10, $10, $10, $10
.word $20, $20, $20, $20, $30, $30, $30, $30

;GradualSlopeR_U2
.word $40, $40, $40, $40, $50, $50, $50, $50
.word $60, $60, $60, $60, $70, $70, $70, $70

;GradualSlopeR_U3
.word $80, $80, $80, $80, $90, $90, $90, $90
.word $a0, $a0, $a0, $a0, $b0, $b0, $b0, $b0

;GradualSlopeR_U4
.word $c0, $c0, $c0, $c0, $d0, $d0, $d0, $d0
.word $e0, $e0, $e0, $e0, $f0, $f0, $f0, $f0
.endrep
.endproc

.pushseg
.segment "Player"
.export SlopeFlagTable
.proc SlopeFlagTable
Left  = $8000
Right = $0000
Gradual = 1
Medium  = 2
Steep   = 4

.word Left  ; MedSlopeL_DL
.word Right ; MedSlopeR_DR
.word Left  ; GradualSlopeL_D1
.word Left  ; GradualSlopeL_D2
.word Right ; GradualSlopeR_D3
.word Right ; GradualSlopeR_D4
.word Left  ; SteepSlopeL_D
.word Right ; SteepSlopeR_D
.repeat 2
.word Left  | Medium  ; MedSlopeL_UL
.word Left  | Medium  ; MedSlopeL_UR
.word Right | Medium  ; MedSlopeR_UL
.word Right | Medium  ; MedSlopeR_UR
.word Left  | Steep   ; SteepSlopeL_U
.word Right | Steep   ; SteepSlopeR_U
.word Left  | Gradual ; GradualSlopeL_U1
.word Left  | Gradual ; GradualSlopeL_U2
.word Left  | Gradual ; GradualSlopeL_U3
.word Left  | Gradual ; GradualSlopeL_U4
.word Right | Gradual ; GradualSlopeR_U1
.word Right | Gradual ; GradualSlopeR_U2
.word Right | Gradual ; GradualSlopeR_U3
.word Right | Gradual ; GradualSlopeR_U4
.endrep
.endproc
.popseg


; Tests if two actors overlap
; Inputs: Actor pointers X and Y
.export TwoActorCollision
.a16
.i16
.proc TwoActorCollision
AWidth   = TouchTemp+0
AHeight1 = TouchTemp+2
AHeight2 = TouchTemp+4
AYPos    = TouchTemp+6
  ; Test X positions

  ; Add the two widths together
  phx
  lda ActorType,x
  tax
  lda f:ActorHeight,x
  sta AHeight1

  ; The two actors' widths are added together, so just do this math now
  lda f:ActorWidth,x
  ldx ActorType,y
  add f:ActorWidth,x
  sta AWidth

  lda f:ActorHeight,x
  sta AHeight2
  plx

  ; Assert that (abs(a.x - b.x) * 2 < (a.width + b.width))
  lda ActorPX,x
  sub ActorPX,y
  bpl :+       ; Take the absolute value
    eor #$ffff
    ina
  :
  asl
  cmp AWidth
  bcs No

  ; -----------------------------------

  ; Test Y positions
  ; Y positions of actors are the bottom, so get the top of the actors
  lda ActorPY,x
  sub AHeight1
  pha

  lda ActorPY,y
  sub AHeight2
  sta AYPos

  dec AHeight2 ; For satisfying the SIZE2-1
  lda AHeight2
  add AHeight1 ; And now it's modified so it'll have the -1 for SIZE1+SIZE2-1
  sta AHeight1

  pla
  clc
  sbc AYPos    ; Note will subtract n-1
  sbc AHeight2 ; #SIZE2-1
  adc AHeight1 ; #SIZE1+SIZE2-1; Carry set if overlap
  bcc No

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc


.export PlayerActorCollision
.a16
.i16
.proc PlayerActorCollision
AWidth   = TouchTemp+0
AHeight1 = TouchTemp+2
AYPos    = TouchTemp+4
  ; Test X positions

  ; Add the two widths together
  phx
  lda ActorType,x
  tax
  lda f:ActorHeight,x
  sta AHeight1

  ; Player and actor width are added together
  lda f:ActorWidth,x
  add #8<<4 ; Player width
  sta AWidth
  plx

  ; Assert that (abs(a.x - b.x) * 2 < (a.width + b.width))
  lda PlayerPX
  sub ActorPX,x
  bpl :+       ; Take the absolute value
    eor #$ffff
    ina
  :
  asl
  cmp AWidth
  bcs No

  ; -----------------------------------

  ; Test Y positions
  ; Y positions of actors are the bottom, so get the top of the actor
  lda ActorPY,x
  sub AHeight1
  pha

  ; And we also need the two heights added together
  lda AHeight1
  add #PlayerHeight-1
  sta AHeight1

  pla
  clc
  sbc PlayerPYTop     ; Note will subtract n-1
  sbc #PlayerHeight-1 ; #SIZE2-1
  adc AHeight1        ; #SIZE1+SIZE2-1; Carry set if overlap
  bcc No

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc


.export PlayerActorCollisionHurt
.a16
.i16
.proc PlayerActorCollisionHurt
  ; Don't hurt the player if the actor is stunned
  lda ActorState,x
  and #$00ff
  cmp #ActorStateValue::Stunned
  beq Exit

  jsl PlayerActorCollision
  bcc :+
    .import HurtPlayer
    jml HurtPlayer
  :
Exit:
  rtl
.endproc


; If an actor is initializing, change it to the paused state
; and hold it in the paused state until the player is near
.export ActorActivateIfNear
.proc ActorActivateIfNear
  seta8
  ; If already activated, just exit
  lda ActorState,x
  beq Exit
  cmp #ActorStateValue::Paused
  beq OK
  ; If it's initializing, automatically start pausing
  cmp #ActorStateValue::Init
  bne Exit
  ; Change to paused
  lda #ActorStateValue::Paused
  sta ActorState,x
OK:

  ; Stop pausing if close enough
  lda PlayerPX+1
  sub ActorPX+1,x
  abs
  cmp #7
  bcs Exit

  ; Also require being close vertically if vertical scrolling is on
  lda VerticalScrollEnabled
  beq :+
    lda PlayerPY+1
    sub ActorPY+1,x
    abs
    cmp #7
    bcs Exit
  :

Yes: ; Change to normal state
  lda #ActorStateValue::None
  sta ActorState,x
Exit:
  seta16
  rtl
.endproc

; If an actor is initializing, change it to the paused state
; and hold it in the paused state until the actor is within the camera's height
.export ActorWaitForCameraVertically
.proc ActorWaitForCameraVertically
  seta8
  ; If no vertical scrolling, just exit
  lda VerticalScrollEnabled
  beq Exit
  ; If already activated, just exit
  lda ActorState,x
  beq Exit
  cmp #ActorStateValue::Paused
  beq OK
  ; If it's initializing, automatically start pausing
  cmp #ActorStateValue::Init
  bne Exit
  ; Change to paused
  lda #ActorStateValue::Paused
  sta ActorState,x
OK:

  ; Stop pausing if close enough
  lda ScrollY+1
  add #8
  sub ActorPY+1,x
  abs
  cmp #6
  bcs Exit

Yes: ; Change to normal state
  lda #ActorStateValue::None
  sta ActorState,x
Exit:
  seta16
  rtl
.endproc



.export ActorClearX
.a16
.i16
.proc ActorClearX
  stz ActorVarA,x
  stz ActorVarB,x
  stz ActorVarC,x
  stz ActorVX,x
  stz ActorVY,x
  stz ActorTimer,x
  stz ActorDirection,x
  stz ActorOnGround,x
  ; Change this if another 8-bit property is added
  seta8
  stz ActorDamage,x
  seta16
  rtl
.endproc

.export ActorClearY
.a16
.i16
.proc ActorClearY
  phx
  tyx
  jsl ActorClearX
  plx
  rtl
.endproc

.export ActorRoverMovement
.a16
.i16
.proc ActorRoverMovement
  lda ActorPX,x
  sub PlayerPX
  abs
  ; Face the player if too far away
  xba
  and #255
  cmp #5
  bcc :+
  pha
  jsl ActorLookAtPlayer
  pla
: ; Run faster when farther away
  asl
  asl
  jsl ActorWalk
  jml ActorAutoBump
.endproc


; Counts the amount of a certain actor that currently exists
; inputs: A (actor type * 2)
; outputs: Y (count)
; locals: 0
.export CountActorAmount
.a16
.i16
.proc CountActorAmount
  phx
  sta 0  ; 0 = object num
  ldy #0 ; Y = counter for number of matching objects

  ldx #ActorStart
Loop:
  lda ActorType,x
  cmp 0
  bne :+
    iny
  :
  txa
  add #ActorSize
  tax
  cpx #ActorEnd
  bne Loop

  plx
  tya
  rtl
.endproc

; Counts the amount of a certain projectile actor that currently exists
; TODO: maybe measure the projectile type, instead of the actor type?
; inputs: A (actor type * 2)
; outputs: Y (count)
; locals: 0
.export CountProjectileAmount
.a16
.i16
.proc CountProjectileAmount
  phx
  sta 0  ; 0 = object num
  ldy #0 ; Y = counter for number of matching objects

  ldx #ProjectileStart
Loop:
  lda ActorType,x
  cmp 0
  bne :+
    iny
  :
  txa
  add #ActorSize
  tax
  cpx #ProjectileEnd
  bne Loop

  plx
  tya
  rtl
.endproc



.export ActorCopyPosXY
.a16
.i16
.proc ActorCopyPosXY
  seta8
  lda #0
  sta ActorState,y
  seta16
  lda ActorPX,x
  sta ActorPX,y
  lda ActorPY,x
  sta ActorPY,y
  rtl
.endproc

; Removes an actor, but also marks any used dynamic sprite slots as free
.export ActorSafeRemoveX
.a16
.i16
.proc ActorSafeRemoveX
  stz ActorType,x

  tdc ; Clear all of accumulator
  seta8
  lda ActorDynamicSlot,x  ; 255 is used to mark an empty slot, so >=128 empty
  bmi NoAllocation
    phx
    tax
    dec DynamicSpriteSlotUsed,x
    bpl :+ ; If it rolls over to -1, just reset to zero
      stz DynamicSpriteSlotUsed,x
    :
    plx
    lda #255 ; Just in case - don't try to free it a second time
    sta ActorDynamicSlot,x
  NoAllocation:
  seta16
  rtl
.endproc

.export ActorSafeRemoveY
.proc ActorSafeRemoveY
  phx
  tyx
  jsl ActorSafeRemoveX
  plx
  rtl
.endproc

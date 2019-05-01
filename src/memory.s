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

; Format for 16-bit X and Y positions and speeds:
; HHHHHHHH LLLLSSSS
; |||||||| ||||++++ - subpixels
; ++++++++ ++++------ actual pixels

.include "memory.inc"

.segment "ZEROPAGE"
  retraces: .res 1
  keydown:  .res 2
  keylast:  .res 2
  keynew:   .res 2

  ScrollX:  .res 2
  ScrollY:  .res 2

  LevelBlockPtr: .res 3 ; Pointer to one block or a column of blocks. 00xxxxxxxxyyyyy0
  BlockFlag:     .res 2 ; Contains block class, solid flags, and interaction set
  BlockRealX:    .res 2 ; Real X coordinate used to calculate LevelBlockPtr
  BlockRealY:    .res 2 ; Real Y coordinate used to calculate LevelBlockPtr
 

  PlayerPX:        .res 2 ; \ player X and Y positions
  PlayerPY:        .res 2 ; /
  PlayerVX:        .res 2 ; \
  PlayerVY:        .res 2 ; /
  PlayerFrame:     .res 1 ; Player animation frame

  PlayerWasRunning: .res 1     ; was the player running when they jumped?
  PlayerDir:        .res 1     ; currently facing left?
  PlayerJumping:    .res 1     ; true if jumping (not falling)
  PlayerOnGround:   .res 1     ; true if on ground
  PlayerWalkLock:   .res 1     ; timer for the player being unable to move left/right
  PlayerDownTimer:  .res 1     ; timer for how long the player has been holding down
                               ; (used for fallthrough platforms)
  PlayerSelectTimer:  .res 1   ; timer for how long the player has been holding select
  PlayerHealth:     .res 1     ; current health, measured in half hearts

  LevelNumber:           .res 1 ; Current level number (actual map number from the game)
  StartedLevelNumber:    .res 1 ; Level number that was picked from the level select (level select number)
  NeedLevelReload:       .res 1 ; If set, decode LevelNumber again

  OamPtr:           .res 2 ;
  TempVal:          .res 4
  TempX:            .res 1 ; for saving the X register
  TempY:            .res 1 ; for saving the Y register

.segment "BSS" ; First 8KB of RAM
  ObjectLen = 16
  ObjectPX:    .res ObjectLen*2 ; Positions
  ObjectPY:    .res ObjectLen*2 ;
  ObjectVX:    .res ObjectLen*2 ; Speeds
  ObjectVY:    .res ObjectLen*2 ;
  ObjectF1:    .res ObjectLen*2 ; TTTTTTTD SSSSSSSS, Type, Direction, State
  ObjectF2:    .res ObjectLen*2 ; 
  ObjectF3:    .res ObjectLen*2 ; 
  ObjectF4:    .res ObjectLen*2 ; 
  ObjectIndexInLevel: .res ObjectLen*2 ; object's index in level list, prevents object from being respawned until it's despawned
  ObjectTimer: .res ObjectLen*2 ; when timer reaches 0, reset state

  OAM:   .res 512
  OAMHI: .res 512
  ; OAMHI contains bit 8 of X (the horizontal position) and the size
  ; bit for each sprite.  It's a bit wasteful of memory, as the
  ; 512-byte OAMHI needs to be packed by software into 32 bytes before
  ; being sent to the PPU, but it makes sprite drawing code much
  ; simpler.

  ; Video updates from scrolling
  ColumnUpdateAddress: .res 2     ; Address to upload to, or zero for none
  ColumnUpdateBuffer:  .res 32*2  ; 32 tiles vertically
  RowUpdateAddress:    .res 2     ; Address to upload to, or zero for none
  RowUpdateBuffer:     .res 64*2  ; 64 tiles horizontally

  BlockUpdateAddress:  .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataTL:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataTR:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataBL:   .res BLOCK_UPDATE_COUNT*2
  BlockUpdateDataBR:   .res BLOCK_UPDATE_COUNT*2


  PlayerAccelSpeed: .res 2
  PlayerDecelSpeed: .res 2
  JumpGracePeriod: .res 1
  PlayerJumpCancelLock: .res 1 ; timer for the player being unable to cancel a jump
  PlayerJumpCancel: .res 1

.segment "BSS7E"


.segment "BSS7F"
  LevelBuf: .res 256*32*2 ; 16KB



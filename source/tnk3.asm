; TNK III native Amiga AGA conversion checkpoint.
; ROM tiles/route/sprites, compile-time7/8-plane variants, double-buffered cache.
; Gameplay below is a first native implementation, not a Z80 instruction port.
    include "display.i"
CUSTOM equ $dff000
CIAAPRA equ $bfe001
CIAADDRA equ $bfe201
CIAASDR equ $bfec01
CIAACRA equ $bfee01
CIAAICR equ $bfed01
POTGOR equ $016
POTGO equ $034
VHPOSR equ $006
DIW_Y equ 44
GAME_Y equ DIW_Y+16
DIRTY_MAX equ 128
ENTITY_COUNT equ 32
BULLET_COUNT equ 32
EXPLOSION_COUNT equ 16

    section code,code
Start:
    movem.l d0-d7/a0-a6,-(sp)
    lea MapPacked,a0
    lea MapCells,a1
    bsr UnpackMap
    bsr InitNativeSprites
    bsr AttractInit
    bsr FrontendInit
    bsr LoadAlternativeMusic
    move.l 4.w,a6
    lea GfxName,a1
    moveq #0,d0
    jsr -552(a6)
    move.l d0,GfxBase
    beq.w Exit
    move.l d0,a6
    move.l 34(a6),OldView
    move.l 38(a6),OldCopper
    sub.l a1,a1
    jsr -222(a6)
    jsr -270(a6)
    jsr -270(a6)
    jsr -456(a6)
    jsr -228(a6)
    lea CUSTOM,a6
    move.w $002(a6),d0
    or.w #$8000,d0
    move.w d0,OldDMA
    move.w $01c(a6),d0
    or.w #$8000,d0
    move.w d0,OldINT
    move.w #$7fff,$09a(a6)
    move.w #$7fff,$09c(a6)
    move.w #$7fff,$096(a6)
    move.w #$8240,$096(a6)
    if PLANES=7
    bsr InitDisplayPalette
    endif
    lea RingA,a0
    move.l a0,BackBuffer
    lea RingB,a0
    move.l a0,FrontBuffer
    lea CopperA,a0
    move.l a0,BackCopper
    lea CopperB,a0
    move.l a0,FrontCopper
    move.l #HudA,BackHUD
    move.l #HudB,FrontHUD
    move.w #-1,BackHUDMode
    move.w #-1,FrontHUDMode
    lea DirtyA,a0
    move.l a0,DirtyList
    lea DirtyB,a0
    move.l a0,OtherDirty
    move.w #-10000,CacheA
    move.w #-10000,CacheB
    move.w #-10000,CleanCam
    bsr ResetGame
    clr.w GameMode
    bsr AttractReset
    bsr ReadLogicClock
    move.w d0,LogicClockLast
    bsr FrontendFPSReset
MainLoop:
    bsr PollKeyboard
    bsr ReadPad
    bsr ReadControls
    bsr FrontendInput
    tst.w QuitRequested
    bne.w ShutDown
    tst.b EscapePressed
    beq.w .continue
    cmp.w #4,GameMode
    blt.w ShutDown
    cmp.w #6,GameMode
    bgt.w ShutDown
.continue:
    bsr MusicTick
    bsr SfxTick
    bsr AdvanceGame
    bsr FrontendFPSMeasure
    bsr FrontendIsPage
    tst.w d0
    beq.w .world_buffers
    bsr WaitBlitter
    move.l DirtyList,a0
    clr.w (a0)
    move.w #-10000,CacheA
    bra.w .draw
.world_buffers:
    move.w #-1,UIBackRevision
    clr.w UIBackArtwork
    bsr PrepareCleanCache
    bsr RestoreDirty
    bsr PrepareCache
.draw:
    bsr DrawScene
    bsr DrawHUD
    bsr BuildCopper
    bsr WaitBlitter
    bsr WaitVBL
    move.l BackCopper,$080(a6)
    move.w #0,$088(a6)
    move.w #$83c0,$096(a6)
    bsr WaitFrameStart
    move.l BackBuffer,d0
    move.l FrontBuffer,BackBuffer
    move.l d0,FrontBuffer
    move.l BackCopper,d0
    move.l FrontCopper,BackCopper
    move.l d0,FrontCopper
    move.l BackHUD,d0
    move.l FrontHUD,BackHUD
    move.l d0,FrontHUD
    move.w BackHUDMode,d0
    move.w FrontHUDMode,BackHUDMode
    move.w d0,FrontHUDMode
    move.w UIBackRevision,d0
    move.w UIFrontRevision,UIBackRevision
    move.w d0,UIFrontRevision
    move.w UIBackArtwork,d0
    move.w UIFrontArtwork,UIBackArtwork
    move.w d0,UIFrontArtwork
    move.l DirtyList,d0
    move.l OtherDirty,DirtyList
    move.l d0,OtherDirty
    move.w CacheA,d0
    move.w CacheB,CacheA
    move.w d0,CacheB
    addq.l #1,FrameCounter
    tst.w MusicReady
    bne.w MainLoop
    bsr MusicStart
    bra.w MainLoop

ShutDown:
    bsr WaitBlitter
    move.w #0,$0a8(a6)
    move.w #0,$0b8(a6)
    move.w #0,$0c8(a6)
    move.w #0,$0d8(a6)
    move.w #$7fff,$096(a6)
    move.w #$7fff,$09a(a6)
    move.w #$7fff,$09c(a6)
    move.l OldCopper,$080(a6)
    move.w #0,$088(a6)
    move.w OldDMA,$096(a6)
    move.w OldINT,$09a(a6)
    move.l GfxBase,a6
    jsr -462(a6)
    move.l OldView,a1
    jsr -222(a6)
    jsr -270(a6)
    move.l 4.w,a6
    move.l GfxBase,a1
    jsr -414(a6)
    bsr SavePreferences
Exit:
    bsr FreeAlternativeMusic
    bsr ClosePreferences
    movem.l (sp)+,d0-d7/a0-a6
    moveq #0,d0
    rts

WaitBlitter:
    tst.b $002(a6)
.wait:
    btst #6,$002(a6)
    bne.s .wait
    rts
WaitVBL:
.a: move.l $004(a6),d0
    lsr.l #8,d0
    and.w #$1ff,d0
    cmp.w #292,d0
    bcc.s .a
.b: move.l $004(a6),d0
    lsr.l #8,d0
    and.w #$1ff,d0
    cmp.w #292,d0
    bcs.s .b
    rts

; Let the Copper handoff cross the physical frame boundary before recycling
; the previous display buffer. Deferred scanout must finish reading it first.
WaitFrameStart:
    move.l $004(a6),d0
    lsr.l #8,d0
    and.w #$1ff,d0
    cmp.w #292,d0
    bcc.s WaitFrameStart
    rts

PollKeyboard:
    lea KeyState,a0
.drain:
    btst #3,CIAAICR
    beq.s .done
    move.b CIAASDR,d0
    or.b #$40,CIAACRA
    moveq #2,d1
.wait:
    move.b VHPOSR+CUSTOM,d2
.line:
    cmp.b VHPOSR+CUSTOM,d2
    beq.s .line
    dbf d1,.wait
    and.b #$bf,CIAACRA
    not.b d0
    ror.b #1,d0
    move.w d0,d1
    and.w #127,d1
    btst #7,d0
    seq (a0,d1.w)
    bra.s .drain
.done:
    rts
    include "inputs.i"

; Gameplay uses PAL elapsed time even when a busy render takes more than a
; display period. Keep frame publication separate from simulation ticks.
ReadLogicClock:
    move.b $bfea01,d1
    moveq #0,d0
    move.b $bfe901,d0
    lsl.w #8,d0
    move.b $bfe801,d0
    rts
AdvanceGame:
    bsr ReadLogicClock
    move.w d0,d1
    sub.w LogicClockLast,d1
    cmp.w #4,d1
    bls.s .bounded
    moveq #4,d1
.bounded:
    add.w d1,LogicClockLast
    move.w d1,LogicRemaining
    beq.s .done
.tick:
    addq.l #1,GameTicks
    move.w #1,NativeStep
    addq.w #1,NativeFraction
    cmp.w #5,NativeFraction
    blt.s .native_step
    clr.w NativeFraction
    move.w #2,NativeStep
.native_step:
    moveq #0,d0
    move.w NativeStep,d0
    add.l d0,ArcadeTicks
    bsr UpdateGame
    subq.w #1,LogicRemaining
    bne.s .tick
.done:
    rts

ReadControls:
    clr.w InputX
    clr.w InputY
    move.w $00c(a6),d0
    move.w d0,d1
    lsr.w #1,d1
    eor.w d0,d1
    btst #1,d0
    beq.s .left
    addq.w #1,InputX
.left:
    btst #9,d0
    beq.s .down
    subq.w #1,InputX
.down:
    btst #0,d1
    beq.s .up
    addq.w #1,InputY
.up:
    btst #8,d1
    beq.s .keys
    subq.w #1,InputY
.keys:
    lea KeyState,a0
    tst.b $4e(a0)
    beq.s .kl
    move.w #1,InputX
.kl:
    tst.b $4f(a0)
    beq.s .kd
    move.w #-1,InputX
.kd:
    tst.b $4d(a0)
    beq.s .ku
    move.w #1,InputY
.ku:
    tst.b $4c(a0)
    beq.s .start
    move.w #-1,InputY
.start:
    move.b PadButtons,d0
    move.b d0,Buttons
    tst.b $63(a0)
    beq.s .b
    bset #1,Buttons
.b:
    tst.b $40(a0)
    beq.s .l
    bset #0,Buttons
.l:
    tst.b $31(a0)
    beq.s .r
    bset #5,Buttons
.r:
    tst.b $33(a0)
    beq.s .go
    bset #4,Buttons
.go:
    tst.b $37(a0)
    beq.s .mup
    tst.b PrevMute
    bne.s .mheld
    cmp.w #1,GameMode
    bne.s .mheld
    eor.w #1,MusicMuted
    bsr FrontendMarkDirty
.mheld:
    move.b #1,PrevMute
    bra.s .startkey
.mup:
    clr.b PrevMute
.startkey:
    ; '1' remains literal input while entering initials. Other pages retain
    ; the existing arcade-preset Start mapping.
    cmp.w #6,GameMode
    beq.s .start_return
    tst.b $01(a0)
    bne.s .press_start
.start_return:
    tst.b $43(a0)
    bne.s .press_start
    tst.b $44(a0)
    beq.s .done
.press_start:
    bset #6,Buttons
.done:
    rts

ResetGame:
    move.w #182,PlayerX
    move.w #WORLD_H-72,PlayerY
    clr.w TurretDir
    move.w #4,BodyDir
    clr.w HullDir
    move.w #3,Lives
    clr.l Score
    clr.l ShotsFired
    clr.w DeathTimer
    clr.w FireDelay
    clr.w MGDelay
    clr.w RotateDelay
    clr.w Invincible
    clr.w MotionFrac
    clr.w GameProgress
    clr.w EnemiesKilled
    lea Bullets,a0
    move.w #(BULLET_COUNT*16/4)-1,d0
.clear:
    clr.l (a0)+
    dbf d0,.clear
    bsr ResetEntities
    bsr AttractReset
    bsr FollowCamera
    rts

UpdateGame:
    cmp.w #1,GameMode
    bne.w FrontendTick
    btst #6,UIPressed
    beq.w .run
    moveq #1,d0
    bsr FrontendOpenOptions
    rts
.run:
    tst.w DeathTimer
    beq.w .alive
    move.w NativeStep,d0
    add.w d0,DeathAge
    subq.w #1,DeathTimer
    bne.w .actors
    bra PlayersAfterDeath
.alive:
    tst.w Invincible
    beq.s .motion
    subq.w #1,Invincible
.motion:
    moveq #1,d5
    addq.w #1,MotionFrac
    cmp.w #5,MotionFrac
    blt.s .step
    clr.w MotionFrac
    moveq #2,d5
.step:
    move.w InputX,d0
    add.w PlayerX,d0
    move.w PlayerY,d1
    movem.l d0-d1,-(sp)
    bsr CanPlayerMove
    tst.w d2
    movem.l (sp)+,d0-d1
    bne.s .my
    move.w d0,PlayerX
.my:
    move.w InputY,d1
    add.w PlayerY,d1
    move.w PlayerX,d0
    movem.l d0-d1,-(sp)
    bsr CanPlayerMove
    tst.w d2
    movem.l (sp)+,d0-d1
    bne.s .turn
    move.w d1,PlayerY
.turn:
    subq.w #1,d5
    bne.s .step
    move.w InputX,d0
    move.w InputY,d1
    or.w d1,d0
    beq.s .turret
    moveq #0,d0
    tst.w InputY
    bmi.s .updir
    beq.s .horizontal
    moveq #4,d0
    tst.w InputX
    beq.s .hull
    bmi.s .southwest
    moveq #3,d0
    bra.s .hull
.southwest:
    moveq #5,d0
    bra.s .hull
.updir:
    tst.w InputX
    beq.s .hull
    bmi.s .northwest
    moveq #1,d0
    bra.s .hull
.northwest:
    moveq #7,d0
    bra.s .hull
.horizontal:
    moveq #2,d0
    tst.w InputX
    bpl.s .hull
    moveq #6,d0
.hull:
    move.w d0,HullDir
    add.w d0,d0
    lea HullAtlas,a0
    move.w (a0,d0.w),BodyDir
.turret:
    tst.w RotateDelay
    beq.s .rotate
    subq.w #1,RotateDelay
    bra.s .fire
.rotate:
    btst #5,Buttons
    beq.s .right
    subq.w #1,TurretDir
    bpl.s .rotok
    move.w #7,TurretDir
    bra.s .rotok
.right:
    btst #4,Buttons
    beq.s .fire
    addq.w #1,TurretDir
    cmp.w #8,TurretDir
    blt.s .rotok
    clr.w TurretDir
.rotok:
    move.w #5,RotateDelay
.fire:
    tst.w FireDelay
    beq.s .tryc
    subq.w #1,FireDelay
    bra.s .mg
.tryc:
    btst #1,Buttons
    beq.s .mg
    moveq #0,d6
    bsr FirePlayer
    move.w #53,FireDelay
    tst.w AmmoReserve
    beq.s .mg
    subq.w #1,AmmoReserve
    move.w #7,FireDelay
.mg:
    tst.w MGDelay
    beq.s .trym
    subq.w #1,MGDelay
    bra.s .camera
.trym:
    btst #0,Buttons
    beq.s .camera
    moveq #1,d6
    bsr FirePlayer
    move.w #8,MGDelay
.camera:
    move.w #WORLD_H-104,d0
    sub.w PlayerY,d0
    bpl.s .progress
    moveq #0,d0
.progress:
    move.w d0,GameProgress
    bsr FollowCamera
.actors:
    bsr SpawnWaves
    bsr TickEntities
    bsr TickBullets
    bsr TickExplosions
    cmp.w #ROUTE_END_PROGRESS,GameProgress
    blt.s .done_game
    moveq #1,d0
    bsr PlayersFinishRun
.done_game:
    bra FrontendConsume

; Native clearance probes are evaluated at the current centre before a step.
; Cardinals use the two original leading-edge samples. Diagonal travel slides
; by testing each cardinal axis; the native combined-direction mask is retained
; in Clearance for the next gameplay pass.
CanPlayerMove:
    moveq #1,d2
    cmp.w #18,d0
    blt.w .done
    cmp.w #WORLD_W-18,d0
    bgt.w .done
    cmp.w #18,d1
    blt.w .done
    cmp.w #WORLD_H-18,d1
    bgt.w .done
    moveq #0,d3
    cmp.w PlayerX,d0
    beq.s .vertical
    blt.s .west
    moveq #2,d3
    bra.s .probes
.west:
    moveq #6,d3
    bra.s .probes
.vertical:
    cmp.w PlayerY,d1
    beq.s .allow
    blt.s .probes
    moveq #4,d3
.probes:
    lsl.w #2,d3
    lea Clearance,a1
    adda.w d3,a1
    moveq #0,d3
    move.w PlayerX,d3
    subq.w #4,d3
    lsr.w #3,d3
    move.w PlayerY,d4
    addq.w #3,d4
    lsr.w #3,d4
    mulu #WORLD_COLS,d4
    add.l d3,d4
    lea Collision,a0
    move.w (a1)+,d6
    ext.l d6
    add.l d4,d6
    tst.b (a0,d6.l)
    bne.s .done
    move.w (a1),d6
    ext.l d6
    add.l d4,d6
    tst.b (a0,d6.l)
    bne.s .done
.allow:
    bsr EntitiesBlockPlayer
.done:
    rts

CanStand:
    moveq #1,d2
    cmp.w #18,d0
    blt.s .done
    cmp.w #WORLD_W-18,d0
    bgt.s .done
    cmp.w #18,d1
    blt.s .done
    cmp.w #WORLD_H-18,d1
    bgt.s .done
    ; Sample centre and front edge. This is the documented prototype mask.
    moveq #0,d3
    move.w d0,d3
    lsr.w #3,d3
    move.w d1,d4
    lsr.w #3,d4
    mulu #WORLD_COLS,d4
    add.l d3,d4
    lea Collision,a0
    tst.b (a0,d4.l)
    bne.s .done
    moveq #0,d2
.done:
    rts

FollowCamera:
    move.w PlayerX,d0
    sub.w #160,d0
    bpl.s .xlow
    moveq #0,d0
.xlow:
    cmp.w #WORLD_W-VIEW_W,d0
    ble.s .xhigh
    move.w #WORLD_W-VIEW_W,d0
.xhigh:
    move.w d0,CamX
    move.w PlayerY,d0
    sub.w #144,d0
    cmp.w #WORLD_H-248,d0
    ble.s .entry_camera
    move.w #WORLD_H-248,d0
.entry_camera:
    tst.w d0
    bpl.s .ylow
    moveq #0,d0
.ylow:
    cmp.w #WORLD_H-VIEW_H,d0
    ble.s .yhigh
    move.w #WORLD_H-VIEW_H,d0
.yhigh:
    move.w d0,CamY
    rts

; Bullets16-byte records: active,x,y,vx,vy,life,kind,pad.
FirePlayer:
    movem.l d0-d7/a0-a5,-(sp)
    lea Bullets,a0
    moveq #BULLET_COUNT-1,d7
.slot:
    tst.w (a0)
    beq.s .found
    lea 16(a0),a0
    dbf d7,.slot
    bra.w .done
.found:
    move.w #1,(a0)
    move.w PlayerX,2(a0)
    move.w PlayerY,4(a0)
    move.w #70,10(a0)
    move.w d6,12(a0)
    move.w #$e7,14(a0)
    tst.w d6
    bne.s .mg_shape
    btst #0,CannonPower+1
    beq.s .pierce_shape
    move.w #$e4,14(a0)
.pierce_shape:
    btst #1,CannonPower+1
    beq.s .shot_direction
    move.w #$e5,14(a0)
    bra.s .shot_direction
.mg_shape:
    move.w HullDir,d0
    and.w #3,d0
    add.w #$ac,d0
    move.w d0,14(a0)
.shot_direction:
    move.w TurretDir,d0
    tst.w d6
    beq.s .dir
    move.w HullDir,d0
.dir:
    lsl.w #2,d0
    lea ShotVectors,a1
    move.w (a1,d0.w),6(a0)
    move.w 2(a1,d0.w),8(a0)
    tst.w d6
    beq.s .speed_done
    move.w 6(a0),d0
    bsr .faster
    move.w d0,6(a0)
    move.w 8(a0),d0
    bsr .faster
    move.w d0,8(a0)
.speed_done:
    ; Emit at the barrel, outside the tank's opaque body. A centre-born shot
    ; could hit infantry hidden under the tank and expose its death sprite.
    ; Probe each short step so the barrel cannot skip through a thin wall.
    moveq #5,d7
    tst.w d6
    beq.w .muzzle
    moveq #3,d7
.muzzle:
    move.w 6(a0),d0
    add.w d0,2(a0)
    move.w 8(a0),d0
    add.w d0,4(a0)
    movem.l d0-d7/a0-a1,-(sp)
    move.w 2(a0),d0
    move.w 4(a0),d1
    bsr ProjectileCanPass
    tst.w d2
    movem.l (sp)+,d0-d7/a0-a1
    bne.w .muzzle_wall
    dbf d7,.muzzle
    bra.w .emitted
.muzzle_wall:
    ; Leave the shot one step before the obstruction. Its ordinary first
    ; update produces the authentic terrain impact at that obstruction.
    move.w 6(a0),d0
    sub.w d0,2(a0)
    move.w 8(a0),d0
    sub.w d0,4(a0)
.emitted:
    addq.l #1,ShotsFired
    move.w d6,d0
    bsr SfxPlay
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts
.faster:
    tst.w d0
    beq.s .return
    bmi.s .neg
    addq.w #1,d0
    rts
.neg:
    subq.w #1,d0
.return:
    rts

    include "entities.i"
    include "native_sprites.i"
    include "attract.i"
    include "frontend.i"
    include "players.i"
    include "storage.i"
    include "music_bank.i"

; Render d0=world row into d1=first byte/d2=byte count of BackBuffer.
; One map cell is one eight-pixel byte per plane, already in Amiga format.
RenderNativeRow:
    movem.l d0-d7/a0-a5,-(sp)
    move.w d0,d7
    and.w #511,d7
    mulu #ROW_BYTES,d7
    move.l BackBuffer,a2
    adda.l d7,a2
    adda.w d1,a2
    tst.w d0
    bpl.s .notop
    moveq #0,d0
.notop:
    cmp.w #WORLD_H,d0
    blt.s .nobottom
    move.w #WORLD_H-1,d0
.nobottom:
    move.w d0,d4
    and.w #7,d4
    mulu #PLANES,d4
    lsr.w #3,d0
    mulu #WORLD_COLS*2,d0
    lea MapCells,a0
    adda.l d0,a0
    move.w d2,d6
    subq.w #1,d6
.byte:
    move.w d1,d0
    subq.w #4,d0
    bpl.s .left
    moveq #0,d0
.left:
    cmp.w #WORLD_COLS,d0
    blt.s .right
    move.w #WORLD_COLS-1,d0
.right:
    add.w d0,d0
    moveq #0,d3
    move.w (a0,d0.w),d3
    mulu #8*PLANES,d3
    add.w d4,d3
    lea TileAtlas,a1
    adda.l d3,a1
    move.b (a1)+,0*STRIDE(a2)
    move.b (a1)+,1*STRIDE(a2)
    move.b (a1)+,2*STRIDE(a2)
    move.b (a1)+,3*STRIDE(a2)
    if PLANES>4
    move.b (a1)+,4*STRIDE(a2)
    move.b (a1)+,5*STRIDE(a2)
    move.b (a1)+,6*STRIDE(a2)
    endif
    if PLANES=8
    move.b (a1)+,7*STRIDE(a2)
    endif
    addq.l #1,a2
    addq.w #1,d1
    dbf d6,.byte
    movem.l (sp)+,d0-d7/a0-a5
    rts

PrepareCache:
    move.w CacheA,d3
    move.w CamY,d4
    move.w d4,CacheA
    sub.w d4,d3
    cmp.w #64,d3
    bgt.s .fill
    cmp.w #-64,d3
    blt.s .fill
    tst.w d3
    beq.s .done
    bmi.s .down
    move.w d4,d0
    sub.w #32,d0
    move.w d3,d5
    bra.s .rows
.down:
    move.w d4,d0
    add.w d3,d0
    add.w #VIEW_H+32,d0
    move.w d3,d5
    neg.w d5
    bra.s .rows
.fill:
    move.w CamY,d0
    sub.w #32,d0
    move.w #VIEW_H+64,d5
.rows:
    moveq #0,d1
    move.w #STRIDE,d2
    subq.w #1,d5
.row:
    bsr RenderRow
    addq.w #1,d0
    dbf d5,.row
.done:
    rts

RestoreDirty:
    move.w #1,RestoringDirty
    bsr WaitBlitter
    move.l DirtyList,a4
    move.w (a4)+,d6
    beq.s .done
    subq.w #1,d6
.rect:
    move.w (a4)+,d1
    move.w (a4)+,d0
    move.w (a4)+,d5
    move.w (a4)+,d2
    bsr CopyCleanRect
    dbf d6,.rect
.done:
    move.l DirtyList,a4
    clr.w (a4)
    clr.w RestoringDirty
    rts

; A third clean cache supplies fast blitter restores, with no per-pixel work.
PrepareCleanCache:
    move.l BackBuffer,-(sp)
    move.w CacheA,-(sp)
    move.l #CleanRing,BackBuffer
    move.w CleanCam,CacheA
    move.w #1,RenderingClean
    bsr PrepareCache
    clr.w RenderingClean
    move.w CacheA,CleanCam
    move.w (sp)+,CacheA
    move.l (sp)+,BackBuffer
    rts
RenderRow:
    tst.w RenderingClean
    bne.w RenderNativeRow
    move.w d5,-(sp)
    moveq #1,d5
    bsr CopyCleanRect
    move.w (sp)+,d5
    rts

; d0=worldY d1=byteX d2=widthbytes d5=height; rows0..255 mirror at512.
CopyCleanRect:
    movem.l d0-d7/a0-a5,-(sp)
    move.w d0,d4
    move.w d5,d6
.part:
    move.w d4,d0
    and.w #511,d0
    move.w #512,d7
    cmp.w #256,d0
    bge.s .bound
    move.w #256,d7
.bound:
    sub.w d0,d7
    cmp.w d6,d7
    ble.s .height
    move.w d6,d7
.height:
    move.w d0,d3
    mulu #ROW_BYTES,d0
    lea CleanRing,a0
    adda.l d0,a0
    adda.w d1,a0
    move.l BackBuffer,a1
    adda.l d0,a1
    adda.w d1,a1
    tst.w RestoringDirty
    beq.s .both_copies
    cmp.w #256,d3
    bge.s .restore_one
    move.w CacheA,d0
    and.w #511,d0
    cmp.w #288,d0
    ble.s .restore_one
    adda.l #512*ROW_BYTES,a1
.restore_one:
    bsr .blit
    bra.s .advance
.both_copies:
    bsr .blit
    cmp.w #256,d3
    bge.s .advance
    adda.l #512*ROW_BYTES,a1
    bsr .blit
.advance:
    add.w d7,d4
    sub.w d7,d6
    bne.s .part
    movem.l (sp)+,d0-d7/a0-a5
    rts
.blit:
    bsr WaitBlitter
    move.w #$09f0,$040(a6)
    clr.w $042(a6)
    move.l #$ffffffff,$044(a6)
    move.w #STRIDE,d0
    sub.w d2,d0
    move.w d0,$064(a6)
    move.w d0,$066(a6)
    move.l a0,$050(a6)
    move.l a1,$054(a6)
    move.w d7,d0
    mulu #PLANES*64,d0
    move.w d2,d5
    lsr.w #1,d5
    or.w d5,d0
    move.w d0,$058(a6)
    rts

; d0=BOB record, d1=world left, d2=world top. Masked blit into hidden cache.
DrawBob:
    movem.l d0-d7/a0-a5,-(sp)
    cmp.w #-31,d1
    blt.w .done
    cmp.w #-31,d2
    blt.w .done
    cmp.w #WORLD_W-1,d1
    bgt.w .done
    move.w d2,d3
    sub.w CamY,d3
    cmp.w #-32,d3
    blt.w .done
    ; A fully offscreen lower actor must not write past the mirrored tail.
    ; Visible starts0..223 plus max32px height fit in the256px tail.
    cmp.w #VIEW_H-1,d3
    bgt.w .done
    cmp.w #WORLD_H-1,d2
    bgt.w .done
    lsl.w #4,d0
    lea ActorTable,a3
    adda.w d0,a3
    move.l DirtyList,a4
    move.w (a4),d0
    cmp.w #DIRTY_MAX,d0
    blt.s .dirty_room
    addq.l #1,DroppedBOBs
    bra.w .done
.dirty_room:
    addq.w #1,(a4)
    move.w (a4),d5
    cmp.w PeakDrawCount,d5
    ble.s .draw_record
    move.w d5,PeakDrawCount
.draw_record:
    lsl.w #3,d0
    lea 2(a4,d0.w),a4
    move.w d1,d0
    asr.w #4,d0
    add.w d0,d0
    addq.w #4,d0
    move.w d0,(a4)+
    move.w d2,(a4)+
    move.w 10(a3),(a4)+
    move.w 12(a3),(a4)+
    move.w d0,d4
    move.w d1,d3
    and.w #15,d3
    ror.w #4,d3
    bsr WaitBlitter
    move.w d3,d0
    or.w #$0fca,d0
    move.w d0,$040(a6)
    move.w d3,$042(a6)
    move.l #$ffff0000,$044(a6)
    clr.w $064(a6)
    clr.w $062(a6)
    move.w #STRIDE,d0
    sub.w 12(a3),d0
    move.w d0,$060(a6)
    move.w d0,$066(a6)
    move.l (a3),a0
    move.l 4(a3),a1
    move.w 10(a3),d5
.part:
    move.w d2,d0
    and.w #511,d0
    move.w #512,d6
    sub.w d0,d6
    cmp.w d5,d6
    ble.s .size
    move.w d5,d6
.size:
    move.w CamY,d1
    and.w #511,d1
    cmp.w #288,d1
    ble.s .primary
    cmp.w #256,d0
    bge.s .primary
    add.w #512,d0
.primary:
    mulu #ROW_BYTES,d0
    move.l BackBuffer,a2
    adda.l d0,a2
    adda.w d4,a2
    bsr WaitBlitter
    move.l a1,$050(a6)
    move.l a0,$04c(a6)
    move.l a2,$048(a6)
    move.l a2,$054(a6)
    move.w d6,d0
    mulu #PLANES*64,d0
    move.w 12(a3),d7
    lsr.w #1,d7
    or.w d7,d0
    move.w d0,$058(a6)
    move.w d6,d0
    mulu #PLANES,d0
    mulu 12(a3),d0
    adda.l d0,a0
    adda.l d0,a1
    add.w d6,d2
    sub.w d6,d5
    bne.s .part
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

DrawScene:
    bsr FrontendIsPage
    tst.w d0
    bne.w FrontendDraw
    cmp.w #3,GameMode
    bne.w .live
    bra DrawAttract
.live:
    bsr DrawEntities
    tst.w DeathTimer
    beq.s .tank
    move.w DeathAge,d4
    neg.w d4
    add.w d4,d4
    moveq #$7a,d0
    moveq #-1,d1
    move.w PlayerX,d2
    move.w PlayerY,d3
    bsr DrawQuadShape
    bra.s .effects
.tank:
    move.w BodyDir,d0
    move.l ArcadeTicks,d3
    and.w #8,d3
    beq.s .body
    cmp.w #4,d0
    bne.s .body
    moveq #0,d0
.body:
    move.w PlayerX,d1
    sub.w #16,d1
    move.w PlayerY,d2
    sub.w #16,d2
    bsr DrawBob
    move.w TurretDir,d0
    add.w d0,d0
    lea TurretAtlas,a0
    move.w (a0,d0.w),d0
    move.w PlayerX,d1
    subq.w #8,d1
    move.w PlayerY,d2
    subq.w #8,d2
    bsr DrawBob
.effects:
    bsr DrawBullets
    bsr DrawExplosions
    rts

DrawHUD:
    move.w GameMode,d0
    cmp.w BackHUDMode,d0
    beq.w .numbers
    move.w d0,BackHUDMode
    move.l BackHUD,a0
    move.w #160-1,d0
.clear:
    clr.l (a0)+
    dbf d0,.clear
    cmp.w #1,GameMode
    bne.w .numbers
    bsr PlayersDrawHUDLabels
.numbers:
    cmp.w #1,GameMode
    bne.s .done
    bsr PlayersDrawHUD
.done:
    bra FrontendHUD
HudNumber:
    lea DigitText,a0
    lea DecimalPowers,a2
    moveq #6,d3
    sub.w d2,d3
    lsl.w #2,d3
    adda.w d3,a2
    subq.w #1,d2
.digit:
    move.l (a2)+,d4
    moveq #'0',d3
.subtract:
    cmp.l d4,d0
    blo.s .emit
    sub.l d4,d0
    addq.b #1,d3
    bra.s .subtract
.emit:
    move.b d3,(a0)+
    dbf d2,.digit
    clr.b (a0)
    lea DigitText,a0
HudString:
    moveq #0,d0
    move.b (a0)+,d0
    beq.s .done
    sub.w #32,d0
    lsl.w #3,d0
    lea Font,a2
    adda.w d0,a2
    move.b (a2)+,0*40(a1)
    move.b (a2)+,1*40(a1)
    move.b (a2)+,2*40(a1)
    move.b (a2)+,3*40(a1)
    move.b (a2)+,4*40(a1)
    move.b (a2)+,5*40(a1)
    move.b (a2)+,6*40(a1)
    move.b (a2)+,7*40(a1)
    addq.l #1,a1
    bra.s HudString
.done:
    rts

    if PLANES=7
; This display palette is fixed across terrain, actors, HUD and title. Load it
; once rather than re-uploading unchanged RGB registers in every Copper list.
InitDisplayPalette:
    lea Palette,a0
    moveq #0,d5
.bank:
    moveq #1,d6
.half:
    move.w d5,d0
    ror.w #3,d0
    or.w #$0020,d0
    tst.w d6
    bne.s .high
    or.w #$0200,d0
.high:
    move.w d0,$106(a6)
    lea $180(a6),a1
    moveq #PALETTE_REGISTERS-1,d7
.col:
    move.w (a0)+,(a1)+
    dbf d7,.col
    dbf d6,.half
    addq.w #1,d5
    cmp.w #PALETTE_BANKS,d5
    blt.s .bank
    move.w #$0020,$106(a6)
    rts
    endif

BuildCopper:
    move.l BackCopper,a1
    move.l #$01fc0001,(a1)+
    move.l #$01001201,(a1)+
    move.l #$01040200,(a1)+
    move.l #$01060020,(a1)+
    move.l #$010c0000,(a1)+
    move.l #$01020000,(a1)+
    move.l #$008e2c81,(a1)+
    move.l #$00901cc1,(a1)+
    move.l #$00920030,(a1)+
    move.l #$009400c0,(a1)+
    move.l #$01080000,(a1)+
    move.l #$010a0000,(a1)+
    if PLANES=8
    ; 256 exact RGB colours, high and low nibble AGA banks.
    lea Palette,a0
    moveq #0,d5
.bank:
    moveq #1,d6
.half:
    move.w #$0106,(a1)+
    move.w d5,d0
    ror.w #3,d0
    or.w #$0020,d0
    tst.w d6
    bne.s .high
    or.w #$0200,d0
.high:
    move.w d0,(a1)+
    move.w #$0180,d1
    moveq #PALETTE_REGISTERS-1,d7
.col:
    move.w d1,(a1)+
    move.w (a0)+,(a1)+
    addq.w #2,d1
    dbf d7,.col
    dbf d6,.half
    addq.w #1,d5
    cmp.w #PALETTE_BANKS,d5
    blt.s .bank
    move.l #$01060020,(a1)+
    endif
    move.l BackHUD,d0
    move.w #$00e0,d1
    bsr CopperPointer
    move.w CamX,d0
    move.w d0,d1
    and.w #31,d1
    lsr.w #5,d0
    tst.w d1
    beq.s .aligned
    addq.w #1,d0
.aligned:
    lsl.w #2,d0
    move.w d0,CopperX
    neg.w d1
    and.w #31,d1
    move.w d1,d2
    and.w #15,d2
    move.w d2,d3
    lsl.w #4,d3
    or.w d3,d2
    and.w #16,d1
    lsl.w #6,d1
    or.w d1,d2
    lsl.w #4,d1
    or.w d1,d2
    move.w d2,GameScroll
    move.w CamY,d0
    and.w #511,d0
    mulu #ROW_BYTES,d0
    add.l BackBuffer,d0
    moveq #0,d1
    move.w CopperX,d1
    add.l d1,d0
    move.l d0,GamePlane0
    add.l #STRIDE,d0
    move.w #$00e4,d1
    moveq #PLANES-2,d7
.ptr:
    bsr CopperPointer
    add.l #STRIDE,d0
    dbf d7,.ptr
    ; HUD's last fetch has finished. All game registers precede next DDF.
    move.w #((GAME_Y-1)<<8)|$df,(a1)+
    move.w #$fffe,(a1)+
    move.l GamePlane0,d0
    move.w #$00e0,d1
    bsr CopperPointer
    move.l #$01000000|GAME_BPLCON0,(a1)+
    move.l #$00920028,(a1)+
    move.l #$009400c8,(a1)+
    move.w #$0108,(a1)+
    move.w #ROW_BYTES-44,(a1)+
    move.w #$010a,(a1)+
    move.w #ROW_BYTES-44,(a1)+
    move.w #$0102,(a1)+
    move.w GameScroll,(a1)+
    move.l #$fffffffe,(a1)+
    rts
CopperPointer:
    move.w d1,(a1)+
    swap d0
    move.w d0,(a1)+
    swap d0
    addq.w #2,d1
    move.w d1,(a1)+
    move.w d0,(a1)+
    addq.w #2,d1
    rts

; Headered4KBwindowLZSS, independently checked by tools/lzss.py.
UnpackMap:
    move.l (a0)+,d7
    move.l a1,a3
    adda.l d7,a3
.outer:
    cmpa.l a3,a1
    bcc.s .done
    move.b (a0)+,d6
    moveq #7,d5
.bit:
    cmpa.l a3,a1
    bcc.s .done
    btst d5,d6
    beq.s .match
    move.b (a0)+,(a1)+
    dbf d5,.bit
    bra.s .outer
.match:
    moveq #0,d0
    move.b (a0)+,d0
    lsl.w #8,d0
    move.b (a0)+,d0
    move.w d0,d1
    lsr.w #4,d0
    and.w #15,d1
    addq.w #2,d1
    move.l a1,a2
    suba.w d0,a2
.copy:
    move.b (a2)+,(a1)+
    dbf d1,.copy
    dbf d5,.bit
    bra.s .outer
.done:
    rts

SfxTick:
    tst.w SfxActive
    beq.s .done
    move.w $01e(a6),d0
    and.w #$0200,d0
    beq.s .done
    move.w #$0600,$09c(a6)
    move.l #Silence,$0c0(a6)
    move.l #Silence,$0d0(a6)
    move.w #2,$0c4(a6)
    move.w #2,$0d4(a6)
    clr.w SfxActive
.done:
    rts

MusicStart:
    bsr MusicResolve
    move.l a0,MusicSource
    move.w d0,MusicBlockCount
    clr.w MusicBlock
    clr.w MusicPhase
    lea MusicA,a1
    bsr CopyMusic
    lea MusicB,a1
    bsr CopyMusic
    move.w #3,$096(a6)
    move.w #$0180,$09c(a6)
    move.l #MusicA,$0a0(a6)
    move.l #MusicA,$0b0(a6)
    move.w #256,$0a4(a6)
    move.w #256,$0b4(a6)
    move.w #443,$0a6(a6)
    move.w #443,$0b6(a6)
    moveq #32,d0
    tst.w MusicMuted
    beq.s .volume
    moveq #0,d0
.volume:
    move.w d0,$0a8(a6)
    move.w d0,$0b8(a6)
    move.w #$8203,$096(a6)
    move.w #1,MusicReady
    rts
CopyMusic:
    movem.l d0-d2/a0-a1,-(sp)
    moveq #0,d0
    move.w MusicBlock,d0
    addq.w #1,MusicBlock
    move.w MusicBlockCount,d1
    cmp.w MusicBlock,d1
    bgt.s .ok
    clr.w MusicBlock
.ok:
    lsl.l #8,d0
    add.l d0,d0
    move.l MusicSource,a0
    adda.l d0,a0
    move.w #127,d2
.copy:
    move.l (a0)+,(a1)+
    dbf d2,.copy
    movem.l (sp)+,d0-d2/a0-a1
    rts
MusicTick:
    bsr MusicResolve
    cmpa.l MusicSource,a0
    beq.w .source_ok
    bsr MusicStart
.source_ok:
    moveq #32,d0
    tst.w MusicMuted
    beq.s .vol
    moveq #0,d0
.vol:
    move.w d0,$0a8(a6)
    move.w d0,$0b8(a6)
    tst.w MusicReady
    beq.s .done
    move.w $01e(a6),d0
    and.w #$0080,d0
    beq.s .done
    move.w #$0180,$09c(a6)
    tst.w MusicPhase
    bne.s .stream
    move.w #1,MusicPhase
    lea MusicB,a1
    bra.s .queue
.stream:
    move.w MusicPhase,d0
    eor.w #3,d0
    move.w d0,MusicPhase
    lea MusicA,a1
    cmp.w #2,d0
    beq.s .fill
    lea MusicB,a1
.fill:
    bsr CopyMusic
.queue:
    move.l a1,$0a0(a6)
    move.l a1,$0b0(a6)
    move.w #256,$0a4(a6)
    move.w #256,$0b4(a6)
.done:
    rts
SfxPlay:
    tst.w SfxMuted
    bne.w .muted
    movem.l d0-d3/a0,-(sp)
    move.w #$000c,$096(a6)
    move.w #$0600,$09c(a6)
    lsl.w #3,d0
    lea SfxTable,a0
    adda.w d0,a0
    move.l (a0),$0c0(a6)
    move.l (a0),$0d0(a6)
    move.w 4(a0),$0c4(a6)
    move.w 4(a0),$0d4(a6)
    move.w #443,$0c6(a6)
    move.w #443,$0d6(a6)
    move.w #56,$0c8(a6)
    move.w #56,$0d8(a6)
    move.w #$820c,$096(a6)
    move.w #1,SfxActive
    movem.l (sp)+,d0-d3/a0
.muted:
    rts

    section data,data
GfxName: dc.b "graphics.library",0
TitleText: dc.b "TNK III  MAIN MENU",0
MenuHeaderText: dc.b "TNK III",0
MenuHelpText: dc.b "DIRECTIONS: SELECT  A/START: OK",0
PlayText: dc.b "TNK III   SCORE             LIVES",0
AttractText: dc.b "TNK III  DEMO",0
DemoControlText: dc.b "PRESS FIRE OR START TO PLAY",0
CompleteText: dc.b "TNK III  ROUTE COMPLETE",0
ControlText: dc.b "A:CANNON B:MG L/R:TURRET ESC:QUIT",0
DigitText: ds.b 8
    even
DecimalPowers: dc.l 100000,10000,1000,100,10,1
DirectionGrid: dc.w 7,0,1,6,0,2,5,4,3
EnemyShotVectors: dc.w 0,-2,1,-1,2,0,1,1,0,2,-1,1,-2,0,-1,-1
DroppedPickupShapes: dc.w $64,$66,$63,$67
DroppedPickupTypes: dc.w $38,$39,$3a,$3e
SfxTable:
    dc.l SfxCannon
    dc.w (SfxMG-SfxCannon)/2,0
    dc.l SfxMG
    dc.w (SfxHit-SfxMG)/2,0
    dc.l SfxHit
    dc.w (SfxExplosion-SfxHit)/2,0
    dc.l SfxExplosion
    dc.w (SfxPickup-SfxExplosion)/2,0
    dc.l SfxPickup
    dc.w (SfxCompletion-SfxPickup)/2,0
    dc.l SfxCompletion
    dc.w (SfxEnd-SfxCompletion)/2,0
ShotVectors:
    dc.w 0,-3,2,-2,3,0,2,2,0,3,-2,2,-3,0,-2,-2
TurretAtlas: dc.w 20,25,23,27,21,26,22,24
HullAtlas: dc.w 4,9,6,11,0,10,2,8
Clearance:
    dc.w -2*WORLD_COLS,1-2*WORLD_COLS
    dc.w 1-2*WORLD_COLS,2-WORLD_COLS
    dc.w 2-WORLD_COLS,2
    dc.w 2,1+WORLD_COLS
    dc.w 1+WORLD_COLS,WORLD_COLS
    dc.w WORLD_COLS,-1
    dc.w -1,-1-WORLD_COLS
    dc.w -1-WORLD_COLS,-2*WORLD_COLS
    include "actors.i"
    include "native_actor_records.i"
    include "native_sprite_data.i"
    include "attract_data.i"
    include "waves.i"
    include "frontend_data.i"
    include "players_data.i"
    include "variant_assets.i"
MusicData: incbin "assets/audio/tnk_music.bin"
MusicEnd:

    section chipdata,data_c
    include "variant_actor_data.i"
Silence: dc.l 0
SfxCannon: incbin "assets/audio/tnk_sfx_cannon.bin"
SfxMG: incbin "assets/audio/tnk_sfx_machinegun.bin"
SfxHit: incbin "assets/audio/tnk_sfx_hit.bin"
SfxExplosion: incbin "assets/audio/tnk_sfx_explosion.bin"
SfxPickup: incbin "assets/audio/tnk_sfx_pickup.bin"
SfxCompletion: incbin "assets/audio/tnk_sfx_completion.bin"
SfxEnd:
    section chipbss,bss_c
    cnop 0,8
RingA: ds.b RING_BYTES
RingB: ds.b RING_BYTES
CleanRing: ds.b RING_H*ROW_BYTES
CopperA: ds.b 4096
CopperB: ds.b 4096
HudA: ds.b 640
HudB: ds.b 640
MusicA: ds.b 512
MusicB: ds.b 512
    include "native_chip_bss.i"

    section vars,bss
MapCells: ds.b MAP_CELL_BYTES
Collision: ds.b COLLISION_BYTES
ProjectileCollision: ds.b PROJECTILE_COLLISION_BYTES
    even
GfxBase: ds.l 1
OldView: ds.l 1
OldCopper: ds.l 1
OldDMA: ds.w 1
OldINT: ds.w 1
BackBuffer: ds.l 1
FrontBuffer: ds.l 1
BackCopper: ds.l 1
FrontCopper: ds.l 1
BackHUD: ds.l 1
FrontHUD: ds.l 1
BackHUDMode: ds.w 1
FrontHUDMode: ds.w 1
DirtyList: ds.l 1
OtherDirty: ds.l 1
CacheA: ds.w 1
CacheB: ds.w 1
CleanCam: ds.w 1
RenderingClean: ds.w 1
RestoringDirty: ds.w 1
GameScroll: ds.w 1
GamePlane0: ds.l 1
CopperX: ds.w 1
FrameCounter: ds.l 1
GameTicks: ds.l 1
ArcadeTicks: ds.l 1
LogicClockLast: ds.w 1
LogicRemaining: ds.w 1
NativeFraction: ds.w 1
NativeStep: ds.w 1
GameProgress: ds.w 1
PlayerX: ds.w 1
PlayerY: ds.w 1
CamX: ds.w 1
CamY: ds.w 1
BodyDir: ds.w 1
HullDir: ds.w 1
TurretDir: ds.w 1
Lives: ds.w 1
Score: ds.l 1
ShotsFired: ds.l 1
EnemiesKilled: ds.w 1
DeathTimer: ds.w 1
Invincible: ds.w 1
SfxActive: ds.w 1
MusicReady: ds.w 1
MusicBlock: ds.w 1
MusicPhase: ds.w 1
MusicMuted: ds.w 1
PrevMute: ds.b 1
    even
FireDelay: ds.w 1
MGDelay: ds.w 1
RotateDelay: ds.w 1
GameMode: ds.w 1
InputX: ds.w 1
InputY: ds.w 1
MotionFrac: ds.w 1
Buttons: ds.b 1
PadButtons: ds.b 1
PadIsCD32: ds.b 1
    even
PadSerialRaw: ds.w 1
KeyState: ds.b 128
DirtyA: ds.w 1+DIRTY_MAX*4
DirtyB: ds.w 1+DIRTY_MAX*4
Enemies:
Entities: ds.b ENTITY_COUNT*32
Explosions: ds.b EXPLOSION_COUNT*12
Bullets: ds.b BULLET_COUNT*16
EntitiesActive: ds.w 1
ExplosionsActive: ds.w 1
WaveIndex: ds.w 1
NewEntityPool: ds.w 1
DeathAge: ds.w 1
PlayerDamage: ds.w 1
CannonPower: ds.w 1
AmmoCounter: ds.w 1
ShieldCounter: ds.w 1
LifeCounter: ds.w 1
PierceCounter: ds.w 1
AmmoReserve: ds.w 1
EntitiesSpawned: ds.l 1
SpawnRequestsSkipped: ds.l 1
ExplosionEvents: ds.l 1
ObjectsCollected: ds.l 1
BulletsHitTerrain: ds.l 1
DroppedBOBs: ds.l 1
PeakDrawCount: ds.w 1
NativeTypesSeen: ds.b 16
EnemyNavState: ds.b ENTITY_COUNT*16
EnemyNavProbes: ds.l 1
EnemyNavTurns: ds.l 1
EnemyNavBlocked: ds.l 1
    include "native_sprite_bss.i"
    include "attract_bss.i"
    include "frontend_bss.i"
    include "players_bss.i"
    end

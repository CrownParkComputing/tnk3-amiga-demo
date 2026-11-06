; Native wave requests and artwork; portable movement/attack state machines.
; The original initializer data is retained in waves.i. Some original timed
; re-spawns and advanced attack decisions remain separate from these states.
E_X equ 0
E_Y equ 2
E_HP equ 4
E_CLOCK equ 6
E_CLASS equ 8
E_FLAGS equ 10
E_DIR equ 12
E_FIRE equ 14
E_STATE equ 16
E_TIMER equ 18
E_SHAPE equ 20
E_PAL equ 22
E_SIZE equ 24
E_POINTS equ 26
E_POOL equ 28
E_ID equ 30
E_BYTES equ 32
; Separate navigation state keeps the public32-byte actor/death/art ABI stable.
N_ID equ 0
N_HULL equ 2
N_MODE equ 4
N_COMMIT equ 4
N_WALL equ 5
N_SIDE equ 6
N_HITDIST equ 8
N_AGE equ 10
N_PATH equ 12
N_COMMAND equ 14
N_LEFT equ 15

ResetEntities:
    movem.l d0-d7/a0-a5,-(sp)
    lea Entities,a0
    move.w #(ENTITY_COUNT*E_BYTES/4)-1,d0
.clear:
    clr.l (a0)+
    dbf d0,.clear
    lea Explosions,a0
    move.w #(EXPLOSION_COUNT*12/4)-1,d0
.effects:
    clr.l (a0)+
    dbf d0,.effects
    clr.w WaveIndex
    clr.w EntitiesActive
    clr.w ExplosionsActive
    clr.w PlayerDamage
    clr.w CannonPower
    clr.w AmmoCounter
    clr.w ShieldCounter
    clr.w LifeCounter
    clr.w PierceCounter
    clr.w AmmoReserve
    clr.w DeathAge
    clr.l EntitiesSpawned
    clr.l SpawnRequestsSkipped
    clr.l ExplosionEvents
    clr.l ObjectsCollected
    clr.l BulletsHitTerrain
    lea NativeTypesSeen,a0
    moveq #3,d0
.seen:
    clr.l (a0)+
    dbf d0,.seen
    lea EnemyNavState,a0
    move.w #(ENTITY_COUNT*16/4)-1,d0
.navigation:
    clr.l (a0)+
    dbf d0,.navigation
    clr.l EnemyNavProbes
    clr.l EnemyNavTurns
    clr.l EnemyNavBlocked
    movem.l (sp)+,d0-d7/a0-a5
    rts

; Input d2=pool ID, output d0=count including actors still dying.
CountPool:
    movem.l d1-d7/a0-a1,-(sp)
    moveq #0,d0
    lea Entities,a0
    moveq #ENTITY_COUNT-1,d1
.slot:
    tst.w E_STATE(a0)
    beq.w .next
    cmp.w E_POOL(a0),d2
    bne.w .next
    addq.w #1,d0
.next:
    lea E_BYTES(a0),a0
    dbf d1,.slot
    movem.l (sp)+,d1-d7/a0-a1
    rts

; Inputs class d0/raw flags d1; output pool d2/cap d3.
ChoosePool:
    moveq #4,d2
    moveq #10,d3
    tst.w d0
    bne.w .vehicle
    moveq #1,d2
    moveq #3,d3
    btst #0,d1
    beq.w .done
    addq.w #1,d2
    addq.w #1,d3
    rts
.vehicle:
    cmp.w #1,d0
    beq.w .tank
    cmp.w #2,d0
    beq.w .tank
    cmp.w #5,d0
    bne.w .gun
.tank:
    moveq #3,d2
    moveq #3,d3
    rts
.gun:
    cmp.w #3,d0
    bne.w .air
    moveq #6,d2
    moveq #3,d3
    rts
.air:
    cmp.w #9,d0
    bne.w .boss
    moveq #5,d2
    moveq #3,d3
    rts
.boss:
    cmp.w #10,d0
    bne.w .done
    moveq #7,d2
    moveq #1,d3
.done:
    rts

SpawnWaves:
    movem.l d0-d7/a0-a5,-(sp)
.request:
    moveq #0,d0
    move.w WaveIndex,d0
    cmp.w #WAVE_COUNT,d0
    bcc.w .done
    lsl.l #4,d0
    lea WaveTable,a4
    adda.l d0,a4
    move.w (a4),d0
    cmp.w GameProgress,d0
    bgt.w .done
    addq.w #1,WaveIndex
    move.w 6(a4),d0
    move.w 12(a4),d1
    bsr ChoosePool
    move.w d2,NewEntityPool
    bsr CountPool
    cmp.w d3,d0
    bge.w .skip
    ; Generic slots0..9 and gun slots3..5 share hardware space. The third
    ; composite vehicle reserves four of those slots; the boss reserves all.
    cmp.w #3,d2
    beq.w .check_vehicle
    cmp.w #4,d2
    beq.w .check_generic
    cmp.w #6,d2
    beq.w .check_generic
    cmp.w #7,d2
    beq.w .check_boss
    bra.w .allocate
.check_vehicle:
    move.w d0,d5
    moveq #7,d2
    bsr CountPool
    tst.w d0
    beq.w .third
    tst.w d5
    bne.w .skip
.third:
    cmp.w #2,d5
    blt.w .allocate
    bsr GenericPoolCount
    cmp.w #6,d0
    bge.w .skip
    bra.w .allocate
.check_generic:
    moveq #7,d2
    bsr CountPool
    tst.w d0
    bne.w .skip
    moveq #3,d2
    bsr CountPool
    moveq #10,d5
    cmp.w #3,d0
    bne.w .generic_space
    moveq #6,d5
.generic_space:
    bsr GenericPoolCount
    cmp.w d5,d0
    bge.w .skip
    bra.w .allocate
.check_boss:
    bsr GenericPoolCount
    tst.w d0
    bne.w .skip
    moveq #3,d2
    bsr CountPool
    cmp.w #1,d0
    bgt.w .skip
.allocate:
    lea Entities,a3
    moveq #ENTITY_COUNT-1,d7
.slot:
    tst.w E_STATE(a3)
    beq.w .init
    lea E_BYTES(a3),a3
    dbf d7,.slot
    bra.w .skip
.init:
    move.w 2(a4),d0
    cmp.w #$8000,d0
    bne.w .x
    move.w PlayerX,d0
    cmp.w #9,6(a4)
    bne.w .x
    sub.w #64,d0
    move.l GameTicks,d1
    btst #0,d1
    beq.w .x
    add.w #160,d0
.x:
    cmp.w #16,d0
    bge.w .left
    moveq #16,d0
.left:
    cmp.w #WORLD_W-16,d0
    ble.w .right
    move.w #WORLD_W-16,d0
.right:
    move.w d0,E_X(a3)
    move.w 4(a4),E_Y(a3)
    move.w 14(a4),d0
    bne.w .hp
    moveq #1,d0
.hp:
    move.w d0,E_HP(a3)
    clr.w E_CLOCK(a3)
    move.w 6(a4),E_CLASS(a3)
    move.w 12(a4),E_FLAGS(a3)
    move.w #4,E_DIR(a3)
    move.w #72,E_FIRE(a3)
    move.w #1,E_STATE(a3)
    clr.w E_TIMER(a3)
    move.w 8(a4),E_SHAPE(a3)
    move.w 10(a4),E_PAL(a3)
    move.w #16,E_SIZE(a3)
    move.w #100,E_POINTS(a3)
    move.w NewEntityPool,E_POOL(a3)
    move.w WaveIndex,E_ID(a3)
    cmp.w #3,E_POOL(a3)
    bne.w .navigation_done
    bsr InitEnemyNavigation
.navigation_done:
    cmp.w #3,E_POOL(a3)
    bne.w .boss_size
    move.w #32,E_SIZE(a3)
    move.w #300,E_POINTS(a3)
.boss_size:
    cmp.w #10,E_CLASS(a3)
    bne.w .count
    move.w #80,E_SIZE(a3)
    move.w #2000,E_POINTS(a3)
.count:
    addq.l #1,EntitiesSpawned
    move.w E_FLAGS(a3),d0
    lsr.w #8,d0
    and.w #127,d0
    lea NativeTypesSeen,a0
    move.w d0,d1
    lsr.w #3,d1
    and.w #7,d0
    bset d0,(a0,d1.w)
    bra.w .request
.skip:
    cmp.w #10,6(a4)
    bne.w .skip_request
    subq.w #1,WaveIndex
    bra.w .done
.skip_request:
    addq.l #1,SpawnRequestsSkipped
    bra.w .request
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

GenericPoolCount:
    moveq #4,d2
    bsr CountPool
    move.w d0,d4
    moveq #6,d2
    bsr CountPool
    add.w d4,d0
    rts

; Return clockwise direction d2 (0=N), movement signs d3/d4.
AimAtPlayer:
    movem.l d5-d7,-(sp)
    move.w PlayerX,d3
    sub.w d0,d3
    move.w PlayerY,d4
    sub.w d1,d4
    move.w d3,d5
    bpl.w .ax
    neg.w d5
.ax:
    move.w d4,d6
    bpl.w .ay
    neg.w d6
.ay:
    move.w d5,d7
    add.w d7,d7
    cmp.w d6,d7
    bge.w .horizontal
    clr.w d3
    bra.w .signs
.horizontal:
    move.w d6,d7
    add.w d7,d7
    cmp.w d5,d7
    bge.w .signs
    clr.w d4
.signs:
    tst.w d3
    beq.w .sy
    bmi.w .nx
    moveq #1,d3
    bra.w .sy
.nx:
    moveq #-1,d3
.sy:
    tst.w d4
    beq.w .angle
    bmi.w .ny
    moveq #1,d4
    bra.w .angle
.ny:
    moveq #-1,d4
.angle:
    move.w d4,d2
    addq.w #1,d2
    mulu #3,d2
    add.w d3,d2
    addq.w #1,d2
    add.w d2,d2
    lea DirectionGrid,a0
    move.w (a0,d2.w),d2
    movem.l (sp)+,d5-d7
    rts

; Native body and turret headings are distinct (main+0F/+10). E_DIR remains
; the turret/weapon target. a3 actor -> d6 hull direction, other regs intact.
GetEnemyHullDirection:
    movem.l d0-d5/d7/a0-a5,-(sp)
    bsr EnemyNavigationAddress
    move.w E_DIR(a3),d6
    move.w N_ID(a5),d0
    beq.w .done
    cmp.w E_ID(a3),d0
    bne.w .done
    move.w N_HULL(a5),d6
.done:
    movem.l (sp)+,d0-d5/d7/a0-a5
    rts

; a3 actor -> a5 private16-byte state. Clobbers d0 only.
EnemyNavigationAddress:
    move.l a3,d0
    sub.l #Entities,d0
    lsr.l #1,d0
    lea EnemyNavState,a5
    adda.l d0,a5
    rts

InitEnemyNavigation:
    movem.l d0-d7/a0-a5,-(sp)
    bsr EnemyNavigationAddress
    clr.l (a5)
    clr.l 4(a5)
    clr.l 8(a5)
    clr.l 12(a5)
    move.w E_ID(a3),N_ID(a5)
    move.w #1,N_SIDE(a5)
    move.w E_FLAGS(a3),d1
    move.w E_ID(a3),d0
    eor.w d0,d1
    btst #0,d1
    beq.w .side
    move.w #-1,N_SIDE(a5)
.side:
    move.w #-1,N_PATH(a5)
    move.w E_FLAGS(a3),d1
    lsr.w #8,d1
    and.w #127,d1
    moveq #-1,d2
    cmp.w #1,d1
    bne.w .type2
    moveq #0,d2
    bra.w .path
.type2:
    cmp.w #2,d1
    beq.w .second
    cmp.w #3,d1
    bne.w .type6
.second:
    move.w #$200,d2
    bra.w .path
.type6:
    cmp.w #6,d1
    bne.w .type7
    move.w #$220,d2
    bra.w .path
.type7:
    cmp.w #7,d1
    bne.w .type9
    move.w #$420,d2
    bra.w .path
.type9:
    cmp.w #9,d1
    bne.w .typeA
    move.w #$620,d2
    bra.w .path
.typeA:
    cmp.w #10,d1
    beq.w .last
    cmp.w #11,d1
    bne.w .done
.last:
    move.w #$820,d2
.path:
    move.w E_FLAGS(a3),d0
    move.w d0,d1
    and.w #15,d0
    btst #15,d1
    beq.w .parameter
    add.w #16,d0
.parameter:
    lsl.w #4,d0
    add.w d0,d2
    move.w d2,N_PATH(a5)
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

; Original command decoder: $3EF0/$3FB6/$41C2. Each movement route has16
; bytes. Zero hands control back to chase; low-nibble commands jump within
; that route; bits1..3 select heading; bit0 waits/turns rather than travels;
; bits5..7 give movement tile count or a longer turn/wait duration.
; a5 state -> d0 desired heading, or E_DIR after source route terminates.
EnemyScriptDirection:
    move.w E_DIR(a3),d0
    tst.w N_PATH(a5)
    bmi.w .done
    tst.b N_LEFT(a5)
    bne.w .heading
    moveq #15,d7
.decode:
    moveq #0,d1
    move.w N_PATH(a5),d1
    cmp.w #$A20,d1
    bcc.w .end
    lea NativeEnemyPathCommands,a0
    moveq #0,d2
    move.b (a0,d1.w),d2
    beq.w .end
    move.w d2,d3
    and.w #$E0,d3
    bne.w .command
    move.w d1,d3
    add.w d2,d3
    and.w #15,d3
    and.w #$FFF0,d1
    or.w d3,d1
    move.w d1,N_PATH(a5)
    dbf d7,.decode
.end:
    move.w #-1,N_PATH(a5)
    clr.b N_LEFT(a5)
    move.w E_DIR(a3),d0
    rts
.command:
    move.b d2,N_COMMAND(a5)
    btst #0,d2
    beq.w .travel_duration
    lsr.w #1,d3
    bra.w .duration
.travel_duration:
    lsr.w #2,d3
.duration:
    move.b d3,N_LEFT(a5)
    move.w d1,d3
    addq.w #1,d3
    and.w #15,d3
    and.w #$FFF0,d1
    or.w d3,d1
    move.w d1,N_PATH(a5)
.heading:
    moveq #0,d0
    move.b N_COMMAND(a5),d0
    and.w #14,d0
    lsr.w #1,d0
.done:
    rts

; Source route command bit4 permits a shot. Free vehicles retain their
; existing aimed shot timer. Return d0=0/1, all other registers intact.
EnemyScriptMayFire:
    movem.l d1-d7/a0-a5,-(sp)
    bsr EnemyNavigationAddress
    moveq #1,d0
    tst.w N_PATH(a5)
    bmi.w .done
    moveq #0,d0
    btst #4,N_COMMAND(a5)
    beq.w .done
    moveq #1,d0
.done:
    movem.l (sp)+,d1-d7/a0-a5
    rts

; One shared eight-direction terrain probe. d0 heading, d1 lookahead.
; Returns d2 blocked, preserves everything else. The leading edge checks
; stop diagonal corner cutting; source main$423C-$43E4 similarly rejects
; blocked directions before its clockwise/counterclockwise turn search.
EnemyProbeDirection:
    movem.l d0-d1/d3-d7/a0-a5,-(sp)
    addq.l #1,EnemyNavProbes
    ; A distant endpoint may be beyond a thin wall while the first pixel is
    ; still blocked. Require the immediate step as well as the lookahead.
    cmp.w #1,d1
    ble.w .distance_ready
    move.w d1,-(sp)
    moveq #1,d1
    bsr EnemyProbeDirection
    move.w (sp)+,d1
    tst.w d2
    bne.w .done
.distance_ready:
    lsl.w #2,d0
    lea EnemyMoveVectors,a0
    move.w (a0,d0.w),d5
    move.w 2(a0,d0.w),d6
    move.w E_X(a3),d3
    move.w E_Y(a3),d4
    move.w d5,d0
    muls.w d1,d0
    add.w d0,d3
    move.w d6,d0
    muls.w d1,d0
    add.w d0,d4
    moveq #1,d2
    cmp.w #16,d3
    blt.w .done
    cmp.w #WORLD_W-16,d3
    bgt.w .done
    cmp.w #16,d4
    blt.w .done
    cmp.w #WORLD_H-16,d4
    bgt.w .done
    move.w d3,d0
    move.w d4,d1
    bsr EnemyTerrainPoint
    tst.w d2
    bne.w .done
    ; Add the projected leading edge to the proposed centre.
    muls.w #10,d5
    muls.w #10,d6
    add.w d5,d3
    add.w d6,d4
    move.w d3,d0
    move.w d4,d1
    bsr EnemyTerrainPoint
    tst.w d2
    bne.w .done
    tst.w d5
    beq.w .vertical
    tst.w d6
    bne.w .diagonal
    move.w d3,d0
    move.w d4,d1
    subq.w #6,d1
    bsr EnemyTerrainPoint
    tst.w d2
    bne.w .done
    move.w d3,d0
    move.w d4,d1
    addq.w #6,d1
    bsr EnemyTerrainPoint
    bra.w .done
.vertical:
    move.w d3,d0
    move.w d4,d1
    subq.w #6,d0
    bsr EnemyTerrainPoint
    tst.w d2
    bne.w .done
    move.w d3,d0
    move.w d4,d1
    addq.w #6,d0
    bsr EnemyTerrainPoint
    bra.w .done
.diagonal:
    move.w d3,d0
    sub.w d5,d0
    move.w d4,d1
    bsr EnemyTerrainPoint
    tst.w d2
    bne.w .done
    move.w d3,d0
    move.w d4,d1
    sub.w d6,d1
    bsr EnemyTerrainPoint
.done:
    movem.l (sp)+,d0-d1/d3-d7/a0-a5
    rts

; d0/d1 world point -> d2 blocked, all other registers preserved.
EnemyTerrainPoint:
    movem.l d0-d1/d3-d4/a0,-(sp)
    moveq #1,d2
    tst.w d0
    bmi.w .done
    cmp.w #WORLD_W,d0
    bge.w .done
    tst.w d1
    bmi.w .done
    cmp.w #WORLD_H,d1
    bge.w .done
    and.l #$FFFF,d0
    and.l #$FFFF,d1
    lsr.w #3,d0
    lsr.w #3,d1
    mulu.w #WORLD_COLS,d1
    add.l d0,d1
    lea Collision,a0
    moveq #0,d2
    move.b (a0,d1.l),d2
.done:
    movem.l (sp)+,d0-d1/d3-d4/a0
    rts

EnemyGoalDistance:
    movem.l d1,-(sp)
    move.w PlayerX,d0
    sub.w E_X(a3),d0
    bpl.w .x
    neg.w d0
.x:
    move.w PlayerY,d1
    sub.w E_Y(a3),d1
    bpl.w .y
    neg.w d1
.y:
    cmp.w d1,d0
    bge.w .done
    move.w d1,d0
.done:
    movem.l (sp)+,d1
    rts

MoveEnemyVehicle:
    movem.l d0-d7/a0-a5,-(sp)
    bsr EnemyNavigationAddress
    move.w N_ID(a5),d0
    beq.w .initialize
    cmp.w E_ID(a3),d0
    beq.w .initialized
.initialize:
    bsr InitEnemyNavigation
    bsr EnemyNavigationAddress
.initialized:
    move.w NativeStep,d6
.native_tick:
    tst.w N_PATH(a5)
    bpl.w .speed_ready
    move.w E_FLAGS(a3),d0
    and.w #15,d0
    bne.w .speed_ready
    ; Pattern6410 is half a pixel/native tick, pattern6510 one pixel/tick.
    move.w E_CLOCK(a3),d0
    sub.w d6,d0
    addq.w #1,d0
    and.w #1,d0
    bne.w .next_tick
.speed_ready:
    ; Script decoder uses d7 as a bounded jump watchdog.
    move.w d6,-(sp)
    bsr EnemyScriptDirection
    move.w (sp)+,d6
    move.w d0,d7
    tst.w N_PATH(a5)
    bmi.w .seek_distance
    btst #0,N_COMMAND(a5)
    beq.w .choose
    ; Native wait/turn commands retain a stationary hull facing.
    move.w d7,N_HULL(a5)
    subq.b #1,N_LEFT(a5)
    bra.w .next_tick
.seek_distance:
    bsr EnemyGoalDistance
    cmp.w #28,d0
    bls.w .next_tick
.choose:
    tst.b N_WALL(a5)
    beq.w .commit
    addq.w #1,N_AGE(a5)
.commit:
    tst.b N_COMMIT(a5)
    beq.w .reconsider
    subq.b #1,N_COMMIT(a5)
    move.w N_HULL(a5),d3
    move.w d3,d0
    moveq #1,d1
    bsr EnemyProbeDirection
    tst.w d2
    beq.w .step
    clr.b N_COMMIT(a5)
.reconsider:
    tst.b N_WALL(a5)
    bne.w .following
    move.w d7,d0
    moveq #8,d1
    bsr EnemyProbeDirection
    tst.w d2
    beq.w .selected_desired
    addq.l #1,EnemyNavBlocked
    move.w #1,N_MODE(a5)
    clr.w N_AGE(a5)
    bsr EnemyGoalDistance
    move.w d0,N_HITDIST(a5)
    move.w d7,d3
    add.w N_SIDE(a5),d3
    bra.w .search
.following:
    cmp.w #12,N_AGE(a5)
    blt.w .follow_edge
    move.w d7,d0
    moveq #12,d1
    bsr EnemyProbeDirection
    tst.w d2
    bne.w .follow_edge
    tst.w N_PATH(a5)
    bpl.w .leave_wall
    bsr EnemyGoalDistance
    addq.w #8,d0
    cmp.w N_HITDIST(a5),d0
    blt.w .leave_wall
    cmp.w #128,N_AGE(a5)
    blt.w .follow_edge
.leave_wall:
    clr.w N_MODE(a5)
    clr.w N_AGE(a5)
    bra.w .selected_desired
.follow_edge:
    ; Keep the chosen obstacle side consistently, rather than choosing a new
    ; shortest heading each pixel and oscillating against the same wall.
    move.w N_HULL(a5),d3
    move.w N_SIDE(a5),d4
    sub.w d4,d3
.search:
    moveq #7,d5
.direction:
    and.w #7,d3
    move.w d3,d0
    moveq #8,d1
    bsr EnemyProbeDirection
    tst.w d2
    beq.w .selected
    add.w N_SIDE(a5),d3
    dbf d5,.direction
    addq.l #1,EnemyNavBlocked
    cmp.w #64,N_AGE(a5)
    blt.w .next_tick
    neg.w N_SIDE(a5)
    clr.w N_AGE(a5)
    bra.w .next_tick
.selected_desired:
    move.w d7,d3
.selected:
    move.w d3,d0
    moveq #1,d1
    bsr EnemyProbeDirection
    tst.w d2
    bne.w .next_tick
    move.b #7,N_COMMIT(a5)
    cmp.w N_HULL(a5),d3
    beq.w .step
    addq.l #1,EnemyNavTurns
    move.w d3,N_HULL(a5)
.step:
    move.w d3,d0
    lsl.w #2,d0
    lea EnemyMoveVectors,a0
    move.w (a0,d0.w),d1
    add.w d1,E_X(a3)
    move.w 2(a0,d0.w),d1
    add.w d1,E_Y(a3)
    tst.w N_PATH(a5)
    bmi.w .next_tick
    tst.b N_WALL(a5)
    bne.w .next_tick
    subq.b #1,N_LEFT(a5)
.next_tick:
    subq.w #1,d6
    bgt.w .native_tick
    movem.l (sp)+,d0-d7/a0-a5
    rts

EnemyMoveVectors:
    dc.w 0,-1, 1,-1, 1,0, 1,1, 0,1, -1,1, -1,0, -1,-1
    even

; Original route command bytes main:$8FA4..$99C3, shared by native tank types.
NativeEnemyPathCommands:
    dc.b $F9,$98,$F9,$90,$0C,$98,$F9,$90,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $8FA4
    dc.b $89,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $8FB4
    dc.b $FD,$9C,$FD,$94,$0C,$9C,$FD,$94,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $8FC4
    dc.b $F5,$94,$F5,$9C,$0C,$94,$F5,$9C,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $8FD4
    dc.b $F7,$96,$F7,$96,$F7,$96,$F7,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $8FE4
    dc.b $FB,$9A,$FB,$9A,$FB,$9A,$FB,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $8FF4
    dc.b $F3,$92,$F3,$9A,$0C,$92,$F3,$9A,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9004
    dc.b $FF,$9E,$FF,$96,$0C,$9E,$FF,$96,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9014
    dc.b $99,$97,$99,$9B,$0C,$97,$99,$9B,$99,$00,$00,$00,$00,$00,$00,$00 ; ROM $9024
    dc.b $84,$95,$8C,$0D,$95,$8C,$84,$95,$8C,$00,$00,$00,$00,$00,$00,$00 ; ROM $9034
    dc.b $8C,$8C,$9D,$9B,$9D,$9B,$0C,$9B,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9044
    dc.b $86,$86,$97,$C8,$C8,$88,$93,$84,$84,$80,$80,$91,$00,$00,$00,$00 ; ROM $9054
    dc.b $88,$84,$84,$9B,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9064
    dc.b $9B,$9B,$9B,$9B,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9074
    dc.b $97,$97,$97,$97,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9084
    dc.b $44,$F5,$F7,$F5,$F7,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9094
    dc.b $94,$96,$98,$98,$98,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $90A4
    dc.b $98,$98,$98,$98,$98,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $90B4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $90C4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $90D4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $90E4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $90F4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9104
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9114
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9124
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9134
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9144
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9154
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9164
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9174
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9184
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9194
    dc.b $98,$98,$98,$98,$98,$98,$98,$98,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $91A4
    dc.b $9C,$9C,$59,$98,$98,$98,$98,$98,$98,$98,$00,$00,$00,$00,$00,$00 ; ROM $91B4
    dc.b $8C,$8C,$49,$C8,$C8,$59,$80,$59,$84,$4D,$8C,$80,$80,$82,$F9,$00 ; ROM $91C4
    dc.b $8C,$8C,$88,$88,$89,$C0,$C0,$59,$84,$84,$88,$88,$49,$00,$00,$00 ; ROM $91D4
    dc.b $59,$84,$84,$5B,$80,$80,$8C,$8C,$88,$F9,$00,$00,$00,$00,$00,$00 ; ROM $91E4
    dc.b $80,$84,$8D,$8C,$88,$88,$88,$59,$80,$80,$80,$80,$84,$00,$00,$00 ; ROM $91F4
    dc.b $49,$88,$88,$88,$59,$80,$80,$F9,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9204
    dc.b $F9,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9214
    dc.b $59,$80,$80,$F9,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9224
    dc.b $41,$8C,$88,$88,$8B,$80,$80,$49,$88,$8C,$9B,$84,$80,$00,$00,$00 ; ROM $9234
    dc.b $21,$84,$88,$88,$9B,$80,$80,$C8,$F7,$00,$00,$00,$00,$00,$00,$00 ; ROM $9244
    dc.b $2B,$CC,$C8,$C8,$2B,$90,$90,$80,$9C,$5C,$88,$F3,$F3,$F3,$F3,$00 ; ROM $9254
    dc.b $37,$37,$98,$94,$94,$97,$9C,$9C,$95,$00,$00,$00,$00,$00,$00,$00 ; ROM $9264
    dc.b $59,$59,$90,$90,$D8,$D8,$59,$94,$90,$90,$94,$9B,$00,$00,$00,$00 ; ROM $9274
    dc.b $E1,$E1,$C4,$C4,$97,$88,$CC,$CC,$F5,$00,$00,$00,$00,$00,$00,$00 ; ROM $9284
    dc.b $25,$AC,$AC,$88,$88,$55,$90,$90,$94,$00,$00,$00,$00,$00,$00,$00 ; ROM $9294
    dc.b $8C,$8C,$88,$88,$98,$88,$90,$90,$90,$90,$B4,$B4,$00,$00,$00,$00 ; ROM $92A4
    dc.b $8C,$8C,$80,$8B,$89,$8B,$91,$81,$91,$81,$91,$81,$91,$81,$91,$00 ; ROM $92B4
    dc.b $80,$8C,$80,$92,$84,$84,$86,$88,$88,$8A,$9C,$8E,$04,$00,$00,$00 ; ROM $92C4
    dc.b $8A,$88,$84,$84,$90,$84,$84,$8C,$9C,$8E,$06,$00,$00,$00,$00,$00 ; ROM $92D4
    dc.b $88,$8C,$5D,$84,$80,$88,$CC,$CC,$9D,$C4,$C4,$80,$04,$00,$00,$00 ; ROM $92E4
    dc.b $E4,$E4,$59,$88,$88,$59,$80,$80,$80,$80,$8C,$8C,$CC,$F5,$00,$00 ; ROM $92F4
    dc.b $88,$88,$88,$99,$80,$91,$80,$91,$80,$80,$4C,$4C,$F5,$00,$00,$00 ; ROM $9304
    dc.b $84,$84,$99,$84,$84,$84,$FD,$8C,$80,$F9,$00,$00,$00,$00,$00,$00 ; ROM $9314
    dc.b $8A,$4B,$82,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9324
    dc.b $8C,$8A,$88,$49,$80,$49,$82,$43,$84,$00,$00,$00,$00,$00,$00,$00 ; ROM $9334
    dc.b $8C,$9B,$8C,$80,$8C,$97,$8E,$C7,$84,$86,$86,$53,$82,$E4,$E4,$00 ; ROM $9344
    dc.b $84,$84,$46,$84,$42,$4C,$8E,$40,$4E,$8C,$4D,$00,$00,$00,$00,$00 ; ROM $9354
    dc.b $86,$86,$8A,$9D,$C2,$C2,$9B,$86,$86,$9D,$EC,$AC,$9D,$8E,$8E,$01 ; ROM $9364
    dc.b $86,$86,$99,$82,$82,$82,$9B,$8A,$8A,$99,$88,$88,$88,$00,$00,$00 ; ROM $9374
    dc.b $84,$84,$86,$86,$8A,$8A,$99,$80,$80,$80,$80,$99,$8C,$8C,$95,$00 ; ROM $9384
    dc.b $D9,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9394
    dc.b $8A,$8C,$8C,$8C,$8C,$8C,$82,$82,$55,$88,$88,$91,$00,$00,$00,$00 ; ROM $93A4
    dc.b $8A,$9B,$8E,$8E,$8E,$82,$82,$88,$88,$88,$88,$99,$00,$00,$00,$00 ; ROM $93B4
    dc.b $9A,$5A,$5A,$5A,$5A,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $93C4
    dc.b $96,$56,$56,$56,$56,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $93D4
    dc.b $F9,$F9,$F9,$F9,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $93E4
    dc.b $99,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $93F4
    dc.b $84,$84,$84,$89,$99,$89,$99,$89,$99,$89,$99,$89,$89,$99,$99,$00 ; ROM $9404
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9414
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9424
    dc.b $F9,$F9,$F9,$F9,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9434
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9444
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9454
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9464
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9474
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9484
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9494
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $94A4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $94B4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $94C4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $94D4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $94E4
    dc.b $E4,$E4,$44,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $94F4
    dc.b $EC,$EC,$4C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9504
    dc.b $E8,$E8,$28,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9514
    dc.b $E4,$E4,$24,$26,$28,$2A,$EC,$AC,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9524
    dc.b $EC,$EC,$2C,$2A,$28,$26,$E4,$A4,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9534
    dc.b $C8,$66,$C4,$62,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9544
    dc.b $C8,$6A,$CC,$6E,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9554
    dc.b $EA,$4A,$88,$86,$84,$E2,$22,$80,$4E,$00,$00,$00,$00,$00,$00,$00 ; ROM $9564
    dc.b $E6,$46,$88,$8A,$EC,$2E,$8E,$42,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9574
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9584
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9594
    dc.b $E8,$28,$82,$44,$42,$48,$8A,$2C,$CE,$4C,$6A,$48,$46,$E4,$66,$00 ; ROM $95A4
    dc.b $E8,$28,$8E,$4C,$4A,$48,$86,$24,$C2,$44,$66,$48,$4A,$EC,$6A,$00 ; ROM $95B4
    dc.b $99,$99,$99,$99,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $95C4
    dc.b $99,$89,$99,$89,$0C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $95D4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $95E4
    dc.b $95,$85,$94,$84,$94,$85,$9C,$8C,$9D,$8D,$9D,$8D,$00,$00,$00,$00 ; ROM $95F4
    dc.b $98,$88,$98,$88,$94,$84,$99,$8C,$9C,$81,$91,$81,$91,$81,$91,$00 ; ROM $9604
    dc.b $9C,$8C,$9C,$89,$99,$89,$94,$84,$94,$07,$00,$00,$00,$00,$00,$00 ; ROM $9614
    dc.b $99,$89,$98,$88,$98,$88,$98,$88,$F1,$E1,$F1,$E1,$F1,$00,$00,$00 ; ROM $9624
    dc.b $94,$84,$99,$8C,$9C,$8C,$9C,$89,$94,$84,$06,$00,$00,$00,$00,$00 ; ROM $9634
    dc.b $98,$84,$94,$84,$9D,$8D,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9644
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9654
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9664
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9674
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9684
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9694
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $96A4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $96B4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00 ; ROM $96C4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $96D4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $96E4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $96F4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9704
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9714
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9724
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9734
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9744
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9754
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9764
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9774
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9784
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9794
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $97A4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $97B4
    dc.b $F9,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $97C4
    dc.b $98,$98,$98,$98,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $97D4
    dc.b $94,$94,$94,$94,$94,$54,$9C,$9C,$9C,$9C,$9C,$00,$00,$00,$00,$00 ; ROM $97E4
    dc.b $98,$D8,$D8,$94,$94,$9C,$9C,$98,$90,$D0,$D0,$00,$00,$00,$00,$00 ; ROM $97F4
    dc.b $35,$59,$98,$98,$98,$39,$39,$90,$90,$90,$39,$39,$9C,$9C,$00,$00 ; ROM $9804
    dc.b $98,$94,$98,$58,$58,$9C,$98,$98,$9C,$9C,$90,$92,$92,$92,$59,$00 ; ROM $9814
    dc.b $98,$98,$59,$90,$90,$59,$9C,$9C,$98,$9C,$94,$90,$94,$94,$00,$00 ; ROM $9824
    dc.b $94,$55,$94,$55,$94,$59,$9C,$9C,$9C,$9C,$9C,$55,$98,$98,$F1,$00 ; ROM $9834
    dc.b $9C,$9C,$59,$9C,$94,$59,$94,$94,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9844
    dc.b $9C,$56,$9C,$56,$9C,$98,$94,$94,$94,$51,$9C,$9C,$9C,$00,$00,$00 ; ROM $9854
    dc.b $98,$59,$90,$39,$90,$39,$90,$39,$90,$90,$90,$79,$9C,$94,$94,$00 ; ROM $9864
    dc.b $9C,$9A,$96,$96,$90,$90,$59,$98,$98,$9C,$00,$00,$00,$00,$00,$00 ; ROM $9874
    dc.b $9C,$59,$94,$94,$59,$9C,$9C,$59,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9884
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9894
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $98A4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $98B4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $98C4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $98D4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $98E4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $98F4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9904
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9914
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9924
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9934
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9944
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9954
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9964
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9974
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9984
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $9994
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $99A4
    dc.b $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $99B4
    even

; Proposed player centre d0/d1. Solid vehicles stop movement and deliver the
; original class damage. Keep motion-loop registers intact; d2 is the result.
EntitiesBlockPlayer:
    movem.l d0-d1/d3-d7/a0-a5,-(sp)
    moveq #0,d2
    lea Entities,a3
    moveq #ENTITY_COUNT-1,d7
.loop:
    cmp.w #1,E_STATE(a3)
    bne.w .next
    move.w E_CLASS(a3),d3
    tst.w d3
    beq.w .next
    cmp.w #6,d3
    beq.w .next
    cmp.w #7,d3
    beq.w .next
    cmp.w #9,d3
    beq.w .next
    move.w E_SIZE(a3),d4
    lsr.w #1,d4
    add.w #11,d4
    move.w d0,d5
    sub.w E_X(a3),d5
    add.w d4,d5
    add.w d4,d4
    cmp.w d4,d5
    bhi.w .next
    move.w d1,d5
    sub.w E_Y(a3),d5
    lsr.w #1,d4
    add.w d4,d5
    add.w d4,d4
    cmp.w d4,d5
    bhi.w .next
    moveq #64,d0
    cmp.w #3,E_POOL(a3)
    bne.w .hit
    move.w E_FLAGS(a3),d3
    lsr.w #8,d3
    and.w #127,d3
    cmp.w #12,d3
    bge.w .hit
    moveq #32,d0
    cmp.w #4,d3
    blt.w .hit
    moveq #16,d0
    cmp.w #8,d3
    blt.w .hit
    moveq #8,d0
.hit:
    bsr HitPlayer
    moveq #1,d2
    bra.w .done
.next:
    lea E_BYTES(a3),a3
    dbf d7,.loop
.done:
    movem.l (sp)+,d0-d1/d3-d7/a0-a5
    rts

TickEntities:
    movem.l d0-d7/a0-a5,-(sp)
    clr.w EntitiesActive
    lea Entities,a3
    moveq #ENTITY_COUNT-1,d7
.loop:
    tst.w E_STATE(a3)
    beq.w .next
    addq.w #1,EntitiesActive
    move.w NativeStep,d0
    add.w d0,E_CLOCK(a3)
    cmp.w #2,E_STATE(a3)
    bne.w .alive
    subq.w #1,E_TIMER(a3)
    bne.w .next
    clr.w E_STATE(a3)
    bra.w .next
.alive:
    move.w E_Y(a3),d0
    sub.w CamY,d0
    cmp.w #VIEW_H+96,d0
    ble.w .ahead
    clr.w E_STATE(a3)
    bra.w .next
.ahead:
    cmp.w #-64,d0
    blt.w .next
    cmp.w #7,E_CLASS(a3)
    beq.w .pickup
    cmp.w #6,E_CLASS(a3)
    beq.w .mine
    move.w E_X(a3),d0
    move.w E_Y(a3),d1
    bsr AimAtPlayer
    move.w d2,E_DIR(a3)
    cmp.w #3,E_CLASS(a3)
    beq.w .weapon
    cmp.w #8,E_CLASS(a3)
    beq.w .next
    cmp.w #10,E_CLASS(a3)
    beq.w .weapon
    cmp.w #9,E_CLASS(a3)
    bne.w .ground
    add.w #2,E_Y(a3)
    bra.w .weapon
.ground:
    cmp.w #3,E_POOL(a3)
    bne.w .infantry_motion
    bsr MoveEnemyVehicle
    bra.w .weapon
.infantry_motion:
    ; Infantry movement has a separate, native-pose-aware implementation.
    tst.w E_CLASS(a3)
    beq.w .move
    move.w E_CLOCK(a3),d2
    and.w #1,d2
    bne.w .weapon
.move:
    add.w d3,d0
    add.w d4,d1
    tst.w E_CLASS(a3)
    bne.w .stand
    cmp.w #2,NativeStep
    bne.w .stand
    add.w d3,d0
    add.w d4,d1
.stand:
    movem.l d0-d1/d7/a3,-(sp)
    bsr CanStand
    tst.w d2
    movem.l (sp)+,d0-d1/d7/a3
    bne.w .weapon
    move.w d0,E_X(a3)
    move.w d1,E_Y(a3)
.weapon:
    cmp.w #3,E_POOL(a3)
    bne.w .weapon_ready
    bsr EnemyScriptMayFire
    tst.w d0
    beq.w .next
.weapon_ready:
    subq.w #1,E_FIRE(a3)
    bgt.w .next
    move.w #100,E_FIRE(a3)
    tst.w E_CLASS(a3)
    beq.w .shoot
    move.w #72,E_FIRE(a3)
.shoot:
    bsr FireEnemy
    bra.w .next
.pickup:
    move.w E_X(a3),d0
    sub.w PlayerX,d0
    add.w #20,d0
    cmp.w #40,d0
    bhi.w .next
    move.w E_Y(a3),d0
    sub.w PlayerY,d0
    add.w #20,d0
    cmp.w #40,d0
    bhi.w .next
    bsr CollectObject
    clr.w E_STATE(a3)
    bra.w .next
.mine:
    move.w E_X(a3),d0
    sub.w PlayerX,d0
    add.w #18,d0
    cmp.w #36,d0
    bhi.w .next
    move.w E_Y(a3),d0
    sub.w PlayerY,d0
    add.w #18,d0
    cmp.w #36,d0
    bhi.w .next
    moveq #64,d0
    bsr HitPlayer
    bsr KillEntity
.next:
    lea E_BYTES(a3),a3
    dbf d7,.loop
    movem.l (sp)+,d0-d7/a0-a5
    rts

FireEnemy:
    movem.l d0-d7/a0-a5,-(sp)
    lea Bullets,a1
    moveq #BULLET_COUNT-1,d7
.slot:
    tst.w (a1)
    beq.w .found
    lea 16(a1),a1
    dbf d7,.slot
    bra.w .done
.found:
    move.w #1,(a1)
    move.w E_X(a3),2(a1)
    move.w E_Y(a3),4(a1)
    move.w #120,10(a1)
    move.w #2,12(a1)
    tst.w E_CLASS(a3)
    beq.w .bullet_shape
    move.w #3,12(a1)
    cmp.w #9,E_CLASS(a3)
    bne.w .bullet_shape
    move.w #4,12(a1)
.bullet_shape:
    move.w E_DIR(a3),d0
    move.w d0,d1
    add.w #$98,d1
    cmp.w #3,12(a1)
    bne.w .homing_shape
    move.w #$b4,d1
.homing_shape:
    cmp.w #4,12(a1)
    bne.w .set_shape
    move.w d0,d1
    add.w #$b6,d1
.set_shape:
    move.w d1,14(a1)
    lsl.w #2,d0
    lea EnemyShotVectors,a0
    move.w (a0,d0.w),6(a1)
    move.w 2(a0,d0.w),8(a1)
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

CollectObject:
    movem.l d0-d7/a0-a5,-(sp)
    moveq #4,d6
    addq.l #1,ObjectsCollected
    move.w #100,d0
    bsr AddPoints
    move.w E_FLAGS(a3),d0
    lsr.w #8,d0
    and.w #127,d0
    cmp.w #$2d,d0
    beq.w .repair16
    cmp.w #$33,d0
    blt.w .weapon
    cmp.w #$37,d0
    ble.w .repair8
.weapon:
    cmp.w #$3b,d0
    bne.w .power
    clr.w PlayerDamage
    bra.w .done
.power:
    cmp.w #$2f,d0
    bne.w .ammo
    bset #0,CannonPower+1
    bra.w .done
.ammo:
    cmp.w #$30,d0
    bne.w .shield
    addq.w #1,AmmoCounter
    cmp.w #5,AmmoCounter
    blt.w .done
    clr.w AmmoCounter
    moveq #5,d6
    move.w #240,AmmoReserve
    bra.w .done
.shield:
    cmp.w #$31,d0
    bne.w .life
    addq.w #1,ShieldCounter
    cmp.w #3,ShieldCounter
    blt.w .done
    clr.w ShieldCounter
    moveq #5,d6
    move.w #200,Invincible
    bra.w .done
.life:
    cmp.w #$38,d0
    bne.w .pierce
    addq.w #1,LifeCounter
    cmp.w #3,LifeCounter
    blt.w .done
    clr.w LifeCounter
    moveq #5,d6
    cmp.w #9,Lives
    bge.w .done
    addq.w #1,Lives
    bra.w .done
.pierce:
    cmp.w #$3a,d0
    bne.w .screen
    addq.w #1,PierceCounter
    cmp.w #3,PierceCounter
    blt.w .done
    clr.w PierceCounter
    moveq #5,d6
    bset #1,CannonPower+1
    bra.w .done
.screen:
    cmp.w #$39,d0
    bne.w .negative
    bsr ClearVisibleEnemies
    bra.w .done
.negative:
    cmp.w #$3e,d0
    bne.w .done
    clr.w AmmoCounter
    clr.w ShieldCounter
    clr.w LifeCounter
    clr.w PierceCounter
    bra.w .done
.repair16:
    sub.w #16,PlayerDamage
    bra.w .clamp
.repair8:
    subq.w #8,PlayerDamage
.clamp:
    bpl.w .done
    clr.w PlayerDamage
.done:
    move.w d6,d0
    bsr SfxPlay
    movem.l (sp)+,d0-d7/a0-a5
    rts

ClearVisibleEnemies:
    movem.l d0-d7/a0-a5,-(sp)
    lea Entities,a3
    moveq #ENTITY_COUNT-1,d7
.loop:
    cmp.w #1,E_STATE(a3)
    bne.w .next
    cmp.w #7,E_CLASS(a3)
    beq.w .next
    move.w E_Y(a3),d0
    sub.w CamY,d0
    cmp.w #-16,d0
    blt.w .next
    cmp.w #VIEW_H,d0
    bgt.w .next
    bsr KillEntity
.next:
    lea E_BYTES(a3),a3
    dbf d7,.loop
    movem.l (sp)+,d0-d7/a0-a5
    rts

; a3 entity. Death frames retain the native class/palette and pool occupancy.
KillEntity:
    movem.l d0-d7/a0-a5,-(sp)
    addq.w #1,EnemiesKilled
    move.w E_POINTS(a3),d0
    bsr AddPoints
    move.w #2,E_STATE(a3)
    clr.w E_CLOCK(a3)
    move.w #108,E_TIMER(a3)
    moveq #3,d0
    bsr SfxPlay
    tst.w E_CLASS(a3)
    bne.w .other
    move.w E_FLAGS(a3),d0
    lsr.w #8,d0
    and.w #127,d0
    cmp.w #$20,d0
    bne.w .drop
    move.w #6,E_CLASS(a3)
    move.w #$b5,E_SHAPE(a3)
    move.w #1,E_STATE(a3)
    move.w #1,E_HP(a3)
    move.w #-1,E_PAL(a3)
    bra.w .done
.drop:
    cmp.w #$23,d0
    bne.w .done
    move.w #7,E_CLASS(a3)
    move.w E_FLAGS(a3),d0
    and.w #3,d0
    add.w d0,d0
    lea DroppedPickupShapes,a0
    move.w (a0,d0.w),E_SHAPE(a3)
    lea DroppedPickupTypes,a0
    move.w (a0,d0.w),d0
    lsl.w #8,d0
    move.w d0,E_FLAGS(a3)
    move.w #1,E_STATE(a3)
    move.w #-1,E_PAL(a3)
    bra.w .done
.other:
    cmp.w #10,E_CLASS(a3)
    beq.w .small
    cmp.w #3,E_CLASS(a3)
    beq.w .small
    cmp.w #6,E_CLASS(a3)
    beq.w .small
    cmp.w #9,E_CLASS(a3)
    bne.w .done
.small:
    move.w #54,E_TIMER(a3)
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

AddPoints:
    movem.l d0-d1,-(sp)
    and.l #$ffff,d0
    add.l d0,Score
    cmp.l #999999,Score
    bls.w .done
    move.l #999999,Score
.done:
    movem.l (sp)+,d0-d1
    rts

HitPlayer:
    tst.w Invincible
    bne.w .done
    tst.w DeathTimer
    bne.w .done
    cmp.w #1,GameMode
    bne.w .done
    add.w d0,PlayerDamage
    ; Native energy is64; subCPUdamage tables give each projectile's damage.
    cmp.w #64,PlayerDamage
    bge.w .fatal
    move.w #15,Invincible
    rts
.fatal:
    subq.w #1,Lives
    clr.w PlayerDamage
    clr.w DeathAge
    move.w #108,DeathTimer
    movem.l d0-d3/a0,-(sp)
    moveq #3,d0
    bsr SfxPlay
    movem.l (sp)+,d0-d3/a0
.done:
    rts

; d0/d1 centre, d2 kind:0small,1quad,3cannonimpact,4MGimpact.
SpawnExplosion:
    movem.l d0-d7/a0-a5,-(sp)
    lea Explosions,a0
    moveq #EXPLOSION_COUNT-1,d7
.slot:
    tst.w 4(a0)
    beq.w .found
    lea 12(a0),a0
    dbf d7,.slot
    bra.w .done
.found:
    move.w d0,(a0)
    move.w d1,2(a0)
    move.w #54,d3
    cmp.w #1,d2
    bne.w .cannon
    move.w #108,d3
.cannon:
    cmp.w #3,d2
    bne.w .mg
    moveq #27,d3
.mg:
    cmp.w #4,d2
    bne.w .timer
    moveq #8,d3
.timer:
    move.w d3,4(a0)
    clr.w 6(a0)
    move.w d2,8(a0)
    move.w #-1,10(a0)
    addq.l #1,ExplosionEvents
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

TickExplosions:
    lea Explosions,a0
    moveq #EXPLOSION_COUNT-1,d7
    clr.w ExplosionsActive
.slot:
    tst.w 4(a0)
    beq.w .next
    subq.w #1,4(a0)
    move.w NativeStep,d0
    add.w d0,6(a0)
    addq.w #1,ExplosionsActive
.next:
    lea 12(a0),a0
    dbf d7,.slot
    rts

ProjectileCanPass:
    moveq #1,d2
    tst.w d0
    bmi.w .done
    cmp.w #WORLD_W,d0
    bge.w .done
    tst.w d1
    bmi.w .done
    cmp.w #WORLD_H,d1
    bge.w .done
    moveq #0,d3
    move.w d0,d3
    lsr.w #3,d3
    move.w d1,d4
    lsr.w #3,d4
    mulu #WORLD_COLS,d4
    add.l d3,d4
    lea ProjectileCollision,a0
    moveq #0,d2
    move.b (a0,d4.l),d2
.done:
    rts

TickBullets:
    movem.l d0-d7/a0-a5,-(sp)
    lea Bullets,a4
    moveq #BULLET_COUNT-1,d7
.loop:
    tst.w (a4)
    beq.w .next
    subq.w #1,10(a4)
    beq.w .expire
    move.w 6(a4),d0
    add.w d0,2(a4)
    move.w 8(a4),d0
    add.w d0,4(a4)
    move.w 2(a4),d0
    move.w 4(a4),d1
    movem.l d0-d1,-(sp)
    bsr ProjectileCanPass
    tst.w d2
    movem.l (sp)+,d0-d1
    bne.w .terrain_impact
    cmp.w #2,12(a4)
    bge.w .player
    lea Entities,a3
    moveq #ENTITY_COUNT-1,d6
.entity:
    cmp.w #1,E_STATE(a3)
    bne.w .entity_next
    cmp.w #7,E_CLASS(a3)
    beq.w .entity_next
    move.w E_SIZE(a3),d5
    lsr.w #1,d5
    addq.w #3,d5
    move.w 2(a4),d0
    sub.w E_X(a3),d0
    add.w d5,d0
    add.w d5,d5
    cmp.w d5,d0
    bhi.w .entity_next
    move.w 4(a4),d0
    sub.w E_Y(a3),d0
    lsr.w #1,d5
    add.w d5,d0
    add.w d5,d5
    cmp.w d5,d0
    bhi.w .entity_next
.damage:
    moveq #1,d5
    cmp.w #1,12(a4)
    beq.w .apply_damage
    moveq #4,d5
    cmp.w #$e5,14(a4)
    bne.w .apply_damage
.enhanced:
    moveq #8,d5
.apply_damage:
    sub.w d5,E_HP(a3)
    bgt.w .armour
    bsr KillEntity
    cmp.w #$e5,14(a4)
    beq.w .entity_next
    bra.w .impact
.armour:
    moveq #2,d0
    bsr SfxPlay
    bra.w .impact
.entity_next:
    lea E_BYTES(a3),a3
    dbf d6,.entity
    bra.w .next
.player:
    move.w 2(a4),d0
    sub.w PlayerX,d0
    add.w #12,d0
    cmp.w #24,d0
    bhi.w .next
    move.w 4(a4),d0
    sub.w PlayerY,d0
    add.w #12,d0
    cmp.w #24,d0
    bhi.w .next
    moveq #2,d0
    cmp.w #3,12(a4)
    bne.w .homing
    moveq #32,d0
.homing:
    cmp.w #4,12(a4)
    bne.w .hurt
    moveq #16,d0
.hurt:
    bsr HitPlayer
    bra.w .impact
.terrain_impact:
    addq.l #1,BulletsHitTerrain
.impact:
    move.w 2(a4),d0
    move.w 4(a4),d1
    moveq #3,d2
    cmp.w #1,12(a4)
    bne.w .effect
    moveq #4,d2
.effect:
    bsr SpawnExplosion
.expire:
    clr.w (a4)
.next:
    lea 16(a4),a4
    dbf d7,.loop
    movem.l (sp)+,d0-d7/a0-a5
    rts

; Shape IDs retain their native timed frames, per-frame palette and flip.
; d0=shape,d1=palette override(-1native),d2/d3=left/top,d4=clock.
DrawShape:
    movem.l d0-d7/a0-a5,-(sp)
    cmp.w #NATIVE_SHAPE_COUNT,d0
    bcc.w .done
    lsl.w #3,d0
    lea NativeShapeDirectory,a0
    adda.w d0,a0
    move.w 2(a0),d5
    and.w d4,d5
    ; Frame4-byte offset is directly clock&mask, since native mask is /4.
    move.l 4(a0),a0
    adda.w d5,a0
    moveq #0,d0
    move.w (a0),d0
    tst.w d1
    bpl.w .palette
    moveq #0,d1
    move.b 2(a0),d1
.palette:
    moveq #0,d4
    move.b 3(a0),d4
    bsr DrawNativeSprite
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

; d0=first of four shapes,d1=bank,d2/d3=centre,d4=clock.
DrawQuadShape:
    movem.l d0-d7/a0-a5,-(sp)
    lea NativeBodyQuadOffsets,a2
    moveq #3,d7
.part:
    movem.l d0-d4,-(sp)
    add.w (a2)+,d2
    add.w (a2)+,d3
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
    movem.l (sp)+,d0-d4
    addq.w #1,d0
    dbf d7,.part
    movem.l (sp)+,d0-d7/a0-a5
    rts

DrawEntities:
    lea Entities,a3
    moveq #ENTITY_COUNT-1,d7
.loop:
    tst.w E_STATE(a3)
    beq.w .next
    move.w E_X(a3),d2
    move.w E_Y(a3),d3
    move.w E_PAL(a3),d1
    move.w E_CLOCK(a3),d4
    neg.w d4
    cmp.w #2,E_STATE(a3)
    beq.w .death
    cmp.w #3,E_POOL(a3)
    beq.w .tank
    cmp.w #10,E_CLASS(a3)
    beq.w .boss
    move.w E_SHAPE(a3),d0
    tst.w E_CLASS(a3)
    bne.w .air
    ; The ROM uses eight firing directions (80..97), but four walking
    ; directions (6E..79). Show that attack family after a port infantry shot.
    ; The six-PAL-tick pose duration follows the port's attack countdown,
    ; rather than claiming the full native AI attack state has been ported.
    move.w E_FIRE(a3),d5
    cmp.w #94,d5
    ble.w .infantry_walk
    cmp.w #100,d5
    bgt.w .infantry_walk
    sub.w #$70,d0
    add.w d0,d0
    add.w #$80,d0
    add.w E_DIR(a3),d0
    bra.w .small
.infantry_walk:
    ; Native down-facing starting shape plus cardinal facing alternatives.
    subq.w #2,d0
    move.w E_DIR(a3),d5
    lsr.w #1,d5
    add.w d5,d0
    bra.w .small
.air:
    move.w E_FLAGS(a3),d5
    lsr.w #8,d5
    and.w #127,d5
    cmp.w #$14,d5
    bne.w .air_clock
    move.w E_CLOCK(a3),d4
    mulu #3,d4
.air_clock:
    cmp.w #9,E_CLASS(a3)
    bne.w .pickup
    lsl.w #2,d4
.pickup:
    cmp.w #7,E_CLASS(a3)
    bne.w .small
    lsl.w #2,d4
.small:
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
    bra.w .next
.tank:
    move.w E_FLAGS(a3),d5
    lsr.w #8,d5
    and.w #127,d5
    cmp.w #12,d5
    bge.w .vehicle15
    add.w d5,d5
    lea NativeTankBodyShapeBases,a0
    move.w (a0,d5.w),d0
    bsr GetEnemyHullDirection
    lsl.w #2,d6
    add.w d6,d0
    lea NativeTankBodyPalettes,a0
    move.w (a0,d5.w),d1
    bsr DrawQuadShape
    lea NativeTankTurretShapeBases,a0
    move.w (a0,d5.w),d0
    add.w E_DIR(a3),d0
    moveq #-1,d1
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
    bra.w .next
.vehicle15:
    move.w #$e0,d0
    moveq #-1,d1
    bsr DrawQuadShape
    moveq #1,d5
    move.w PlayerX,d0
    sub.w E_X(a3),d0
    cmp.w #8,d0
    ble.w .v15_left
    moveq #0,d5
    bra.w .v15_turret
.v15_left:
    cmp.w #-8,d0
    bge.w .v15_turret
    moveq #2,d5
.v15_turret:
    move.w d5,d0
    add.w #$dd,d0
    lsl.w #2,d5
    lea NativeVehicle15TurretOffsets,a0
    add.w (a0,d5.w),d2
    add.w 2(a0,d5.w),d3
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
    bra.w .next
.boss:
    lea NativeBossPieces,a2
    moveq #13,d6
.piece:
    movem.l d2-d4,-(sp)
    move.w (a2)+,d0
    add.w (a2)+,d2
    add.w (a2)+,d3
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
    movem.l (sp)+,d2-d4
    dbf d6,.piece
    bra.w .next
.death:
    cmp.w #10,E_CLASS(a3)
    beq.w .boss_death
    tst.w E_CLASS(a3)
    bne.w .large_death
    add.w #$80,d4
    move.w #$7e,d0
    btst #0,E_FLAGS(a3)
    beq.w .death_single
    addq.w #1,d0
.death_single:
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
    bra.w .next
.large_death:
    cmp.w #3,E_POOL(a3)
    beq.w .quad_death
    cmp.w #10,E_CLASS(a3)
    beq.w .quad_death
    add.w #$40,d4
    move.w #$bf,d0
    moveq #-1,d1
    bra.w .death_single
.boss_death:
    add.w d4,d4
    add.w #$80,d4
    moveq #-1,d1
    lea NativeBossPieces,a2
    moveq #13,d6
.boss_fire:
    movem.l d2-d4,-(sp)
    addq.l #2,a2
    add.w (a2)+,d2
    add.w (a2)+,d3
    subq.w #8,d2
    subq.w #8,d3
    move.w #$bf,d0
    bsr DrawShape
    movem.l (sp)+,d2-d4
    dbf d6,.boss_fire
    bra.w .next
.quad_death:
    add.w d4,d4
    moveq #$7a,d0
    moveq #-1,d1
    bsr DrawQuadShape
.next:
    lea E_BYTES(a3),a3
    dbf d7,.loop
    rts

DrawBullets:
    lea Bullets,a4
    moveq #BULLET_COUNT-1,d7
.bullet:
    tst.w (a4)
    beq.w .next
    move.w 14(a4),d0
    moveq #-1,d1
    cmp.w #3,12(a4)
    bne.w .bullet_position
    moveq #1,d1
.bullet_position:
    move.w 2(a4),d2
    subq.w #8,d2
    move.w 4(a4),d3
    subq.w #8,d3
    move.l ArcadeTicks,d4
    neg.w d4
    bsr DrawShape
.next:
    lea 16(a4),a4
    dbf d7,.bullet
    rts

DrawExplosions:
    lea Explosions,a4
    moveq #EXPLOSION_COUNT-1,d7
.loop:
    tst.w 4(a4)
    beq.w .next
    move.w (a4),d2
    move.w 2(a4),d3
    moveq #-1,d1
    move.w 6(a4),d4
    neg.w d4
    cmp.w #1,8(a4)
    bne.w .single
    add.w d4,d4
    moveq #$7a,d0
    bsr DrawQuadShape
    bra.w .next
.single:
    move.w #$bf,d0
    cmp.w #3,8(a4)
    bne.w .mg
    lsl.w #2,d4
    add.w #$80,d4
    move.w #$b1,d0
    bra.w .draw
.mg:
    cmp.w #4,8(a4)
    bne.w .small
    addq.w #8,d4
    move.w #$b0,d0
    bra.w .draw
.small:
    add.w #$40,d4
.draw:
    subq.w #8,d2
    subq.w #8,d3
    bsr DrawShape
.next:
    lea 12(a4),a4
    dbf d7,.loop
    rts

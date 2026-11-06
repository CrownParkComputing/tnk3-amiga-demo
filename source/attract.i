; Recorded original-ROM world attract, sampled at50Hz. No gameplay AI runs here.
; DrawNativeSprite consumes d0=code,d1=palette,d2=x,d3=y,d4=flipX, preserving regs.
AttractInit:
    lea AttractPacked,a0
    lea AttractReplayRaw,a1
    bsr UnpackMap
    bra AttractReset

AttractReset:
    clr.w AttractIdleTimer
    clr.w AttractFrameIndex
    clr.l AttractFramePtr
    clr.l AttractTitleBuffer0
    clr.l AttractTitleBuffer1
    clr.w CamX
    clr.w CamY
    clr.w GameMode
    clr.w TitleSelection
    bsr FrontendTouch
    rts

; Caller handles Fire/Start interruption before entering this routine.
; Called once per50Hz game tick (several times when catching up a slow frame).
AttractTick:
    tst.w GameMode
    bne.s .demo
    addq.w #1,AttractIdleTimer
    cmp.w #ATTRACT_WAIT_TICKS,AttractIdleTimer
    blt.s .done
    clr.w AttractFrameIndex
    bsr AttractLoadFrame
    move.w #3,GameMode
    rts
.demo:
    cmp.w #3,GameMode
    bne.s .done
    addq.w #1,AttractFrameIndex
    cmp.w #ATTRACT_FRAME_COUNT,AttractFrameIndex
    blt.s AttractLoadFrame
    addq.w #1,AttractCycles
    bra AttractReset
.done:
    rts

AttractLoadFrame:
    moveq #0,d0
    move.w AttractFrameIndex,d0
    lsl.l #2,d0
    lea AttractFrameOffsets,a0
    move.l (a0,d0.l),d0
    lea AttractReplayRaw,a1
    adda.l d0,a1
    move.l a1,AttractFramePtr
    move.w (a1)+,CamX
    move.w (a1),CamY
    rts

DrawAttract:
    movem.l d0-d7/a0-a5,-(sp)
    move.l AttractFramePtr,a5
    move.l a5,d0
    beq.s .done
    move.w 4(a5),d7
    lea 6(a5),a5
    subq.w #1,d7
    bmi.s .done
.sprite:
    moveq #0,d0
    move.w (a5)+,d0
    moveq #0,d1
    move.w (a5)+,d1
    move.w (a5)+,d2
    ext.l d2
    move.w (a5)+,d3
    ext.l d3
    moveq #0,d4
    move.w (a5)+,d4
    bsr DrawNativeSprite
    dbf d7,.sprite
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

; The static title is written once into each hidden working buffer. Preparing
; the ordinary map cache before this is safe; a camera transition fills it anew.
DrawAttractTitle:
    movem.l d0-d7/a0-a5,-(sp)
    move.l BackBuffer,d0
    cmp.l AttractTitleBuffer0,d0
    beq.s .done
    cmp.l AttractTitleBuffer1,d0
    beq.s .done
    tst.l AttractTitleBuffer0
    bne.s .second
    move.l d0,AttractTitleBuffer0
    bra.s .copy
.second:
    move.l d0,AttractTitleBuffer1
.copy:
    bsr WaitBlitter
    lea AttractReplayRaw+ATTRACT_REPLAY_BYTES,a0
    move.l BackBuffer,a1
    addq.l #4,a1
    move.w #223,d7
.row:
    moveq #PLANES-1,d6
.plane:
    moveq #9,d5
.long:
    move.l (a0)+,(a1)+
    dbf d5,.long
    adda.w #STRIDE-40,a1
    dbf d6,.plane
    dbf d7,.row
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

; Alternating players own independent actor pools, progress, weapons and lives.
; Display caches, clocks, audio and the immutable ROM map remain shared.
PLAYER_STATE_BYTES equ 2560

PlayersBeginGame:
    move.w #1,SessionPlayers
    move.w TwoPlayerOption,d0
    add.w d0,SessionPlayers
    clr.l PlayerFinished
    move.w #-1,TurnPending
    move.w #1,ActivePlayer
    bsr ResetGame
    bsr PlayersSave
    clr.w ActivePlayer
    bsr ResetGame
    bsr PlayersSave
    move.w #1,GameMode
    rts

PlayersSync:
    movem.l d0/a0,-(sp)
    move.w ActivePlayer,d0
    add.w d0,d0
    lea PlayerLives,a0
    move.w Lives,(a0,d0.w)
    add.w d0,d0
    lea PlayerScores,a0
    move.l Score,(a0,d0.w)
    movem.l (sp)+,d0/a0
    rts

PlayersSave:
    bsr PlayersSync
    movem.l d0-d7/a0-a5,-(sp)
    moveq #0,d7
    bra.w PlayersCopy
PlayersLoad:
    movem.l d0-d7/a0-a5,-(sp)
    moveq #1,d7
PlayersCopy:
    move.w ActivePlayer,d0
    mulu #PLAYER_STATE_BYTES,d0
    lea PlayerWorlds,a1
    adda.l d0,a1
    lea PlayerStateRanges,a2
.range:
    move.l (a2)+,d0
    beq.w .done
    move.l d0,a0
    move.w (a2)+,d0
    lsr.w #1,d0
    subq.w #1,d0
    tst.w d7
    bne.w .load
.save:
    move.w (a0)+,(a1)+
    dbf d0,.save
    bra.w .range
.load:
    move.w (a1)+,(a0)+
    dbf d0,.load
    bra.w .range
.done:
    tst.w d7
    beq.w .restore
    ; Both hidden working buffers must be repopulated for the new camera.
    move.w #-10000,CacheA
    move.w #-10000,CacheB
    move.w #-10000,CleanCam
    clr.w DirtyA
    clr.w DirtyB
.restore:
    movem.l (sp)+,d0-d7/a0-a5
    rts

; Return d1=the other available player, or -1 when there is no other turn.
PlayersOther:
    moveq #-1,d1
    cmp.w #2,SessionPlayers
    bne.w .done
    move.w ActivePlayer,d1
    eor.w #1,d1
    move.w d1,d2
    add.w d2,d2
    lea PlayerFinished,a0
    tst.w (a0,d2.w)
    bne.w .none
    lea PlayerLives,a0
    tst.w (a0,d2.w)
    bne.w .done
.none:
    moveq #-1,d1
.done:
    rts

PlayersAfterDeath:
    clr.w DeathAge
    move.w #120,Invincible
    clr.w FireDelay
    clr.w MGDelay
    tst.w Lives
    beq.w .finished
    bsr PlayersSave
    bsr PlayersOther
    tst.w d1
    bmi.w .resume
    move.w d1,ActivePlayer
    bsr PlayersLoad
    bra.w PlayersReady
.resume:
    bra FrontendConsume
.finished:
    moveq #0,d0
    bra.w PlayersFinishRun

; d0=0 game over,1 route complete. Each player gets an independent score entry.
PlayersFinishRun:
    bsr PlayersSave
    move.w ActivePlayer,d1
    add.w d1,d1
    lea PlayerFinished,a0
    move.w #1,(a0,d1.w)
    bsr PlayersOther
    move.w d1,TurnPending
    bra FrontendFinishRun

PlayersScoresContinue:
    tst.w TurnPending
    bmi.w FrontendReturnTitle
    move.w TurnPending,ActivePlayer
    move.w #-1,TurnPending
    bsr PlayersLoad
    bra.w PlayersReady

PlayersReady:
    move.w CamX,PausedCamX
    move.w CamY,PausedCamY
    clr.w CamX
    clr.w CamY
    move.w #150,TurnTimer
    move.w #7,GameMode
    bra FrontendPageEntered

PlayersReadyTick:
    tst.b UIPressed
    bne.w .play
    subq.w #1,TurnTimer
    bne.w .done
.play:
    move.w PausedCamX,CamX
    move.w PausedCamY,CamY
    move.w #1,GameMode
    bsr FrontendTouch
.done:
    rts

PlayersDrawReady:
    lea UIPlayerOne,a0
    tst.w ActivePlayer
    beq.w .name
    lea UIPlayerTwo,a0
.name:
    move.w #96,d1
    move.w #80,d2
    bsr UIBigText
    lea UIReady,a0
    move.w #136,d1
    move.w #120,d2
    bsr UIText
    lea UIReadyHelp,a0
    move.w #64,d1
    move.w #176,d2
    bra UIText

PlayersDrawHUDLabels:
    move.l BackHUD,a1
    lea ScoreHeader,a0
    bsr HudString
    move.l BackHUD,a1
    adda.w #4,a1
    tst.w ActivePlayer
    beq.w .marker
    adda.w #30,a1
.marker:
    lea UIArrow,a0
    bra HudString

PlayersDrawHUD:
    bsr PlayersSync
    move.l BackHUD,a1
    adda.w #7,a1
    moveq #0,d0
    move.w PlayerLives,d0
    moveq #1,d2
    bsr HudNumber
    move.l BackHUD,a1
    adda.w #320,a1
    move.l PlayerScores,d0
    moveq #6,d2
    bsr HudNumber
    move.l HighScores,d0
    cmp.l PlayerScores,d0
    bhs.w .p2_high
    move.l PlayerScores,d0
.p2_high:
    cmp.w #2,SessionPlayers
    bne.w .high
    cmp.l PlayerScores+4,d0
    bhs.w .high
    move.l PlayerScores+4,d0
.high:
    move.l BackHUD,a1
    adda.w #320+17,a1
    moveq #6,d2
    bsr HudNumber
    move.l BackHUD,a1
    adda.w #320+30,a1
    cmp.w #2,SessionPlayers
    bne.w .unused
    move.l PlayerScores+4,d0
    moveq #6,d2
    bsr HudNumber
    move.l BackHUD,a1
    adda.w #37,a1
    moveq #0,d0
    move.w PlayerLives+2,d0
    moveq #1,d2
    bra HudNumber
.unused:
    lea UIUnusedScore,a0
    bra HudString

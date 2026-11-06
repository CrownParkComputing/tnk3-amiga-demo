; Modes:0 title,1 live game,2 result,3 arcade replay,4 options,5 scores,6 initials.
FrontendInit:
    movem.l d0-d7/a0-a6,-(sp)
    lea DefaultHighScores,a0
    lea HighScores,a1
    moveq #19,d0
.defaults:
    move.l (a0)+,(a1)+
    dbf d0,.defaults
    move.w #-1,PendingRank
    move.w #-1,TurnPending
    move.w #-1,UIBackRevision
    move.w #-1,UIFrontRevision
    move.w #1,UIRevision
    bsr LoadPreferences
    movem.l (sp)+,d0-d7/a0-a6
    rts

; Sample button edges once per presented frame, not per catch-up logic tick.
FrontendInput:
    movem.l d0-d7/a0-a3,-(sp)
    move.b UIPrevButtons,d0
    not.b d0
    and.b Buttons,d0
    and.b #$43,d0
    or.b d0,UIPressed
    move.b Buttons,UIPrevButtons
    move.b KeyState+$45,d0
    beq.w .escape_up
    tst.b PrevEscape
    bne.w .escape_store
    move.b #1,EscapePressed
    bra.w .escape_store
.escape_up:
    clr.b PrevEscape
.escape_store:
    move.b d0,PrevEscape
    cmp.w #6,GameMode
    bne.w .done
    lea UIKeyMap,a2
    lea KeyState,a0
    lea NamePrevKeys,a1
.key:
    moveq #0,d0
    move.b (a2)+,d0
    beq.w .backspace
    move.b (a2)+,d1
    tst.b (a0,d0.w)
    beq.w .key
    tst.b (a1,d0.w)
    bne.w .key
    tst.b NameTyped
    bne.w .key
    move.b d1,NameTyped
    bra.w .key
.backspace:
    tst.b $41(a0)
    beq.w .copy_keys
    tst.b $41(a1)
    bne.w .copy_keys
    move.b #1,NameBackspace
.copy_keys:
    moveq #31,d0
.copy:
    move.l (a0)+,(a1)+
    dbf d0,.copy
.done:
    movem.l (sp)+,d0-d7/a0-a3
    rts

FrontendTouch:
    addq.w #1,UIRevision
    bne.w .version
    addq.w #1,UIRevision
.version:
    move.w #-1,BackHUDMode
    move.w #-1,FrontHUDMode
    rts

FrontendMarkDirty:
    move.w #1,PrefsDirty
    bra FrontendTouch

FrontendConsume:
    clr.b UIPressed
    clr.b EscapePressed
    clr.b NameTyped
    clr.b NameBackspace
    rts

FrontendPageEntered:
    move.w InputX,UILastX
    move.w InputY,UILastY
    move.w #12,UIRepeat
    bsr FrontendConsume
    bra FrontendTouch

; d0=1 for a static page,0 for live game/recorded world replay.
FrontendIsPage:
    moveq #1,d0
    cmp.w #1,GameMode
    beq.w .world
    cmp.w #3,GameMode
    bne.w .done
.world:
    moveq #0,d0
.done:
    rts

FrontendNavigation:
    clr.w UINavX
    clr.w UINavY
    move.w InputX,d0
    move.w InputY,d1
    cmp.w UILastX,d0
    bne.w .new
    cmp.w UILastY,d1
    bne.w .new
    or.w d0,d1
    beq.w .done
    tst.w UIRepeat
    beq.w .repeat
    subq.w #1,UIRepeat
    rts
.repeat:
    move.w #4,UIRepeat
    bra.w .emit
.new:
    move.w InputX,UILastX
    move.w InputY,UILastY
    move.w #12,UIRepeat
.emit:
    move.w InputX,UINavX
    move.w InputY,UINavY
.done:
    rts

FrontendBeginGame:
    bsr PlayersBeginGame
    move.w #-1,PendingRank
    bra FrontendPageEntered

FrontendReturnTitle:
    move.w #-1,TurnPending
    bsr AttractReset
    bra FrontendPageEntered

FrontendOpenOptions:
    ; d0=return mode (0 title or1 paused game).
    move.w d0,OptionsReturn
    move.w CamX,PausedCamX
    move.w CamY,PausedCamY
    clr.w CamX
    clr.w CamY
    clr.w OptionSelection
    move.w #4,GameMode
    bra FrontendPageEntered

FrontendCloseOptions:
    tst.w OptionsReturn
    beq.w FrontendReturnTitle
    move.w PausedCamX,CamX
    move.w PausedCamY,CamY
    move.w #1,GameMode
    bra FrontendPageEntered

FrontendShowScores:
    move.w #5,GameMode
    clr.w CamX
    clr.w CamY
    bra FrontendPageEntered

FrontendWatchDemo:
    clr.w AttractFrameIndex
    move.w #ATTRACT_WAIT_TICKS,AttractIdleTimer
    bsr AttractLoadFrame
    move.w #3,GameMode
    bra FrontendPageEntered

; d0=0 game over,1 route complete. Insert only scores strictly above a row.
FrontendFinishRun:
    move.w d0,EndReason
    move.w #-1,PendingRank
    clr.w CamX
    clr.w CamY
    move.l Score,d0
    lea HighScores,a0
    moveq #0,d2
.rank:
    cmp.l (a0),d0
    bhi.w .qualifies
    addq.l #8,a0
    addq.w #1,d2
    cmp.w #10,d2
    blt.w .rank
    move.w #2,GameMode
    move.w #200,ResultTimer
    bra FrontendPageEntered
.qualifies:
    lea HighScores+9*8,a1
    moveq #9,d1
.shift:
    cmp.w d2,d1
    ble.w .insert
    move.l -8(a1),(a1)
    move.l -4(a1),4(a1)
    subq.l #8,a1
    subq.w #1,d1
    bra.w .shift
.insert:
    move.l Score,(a1)
    move.l #$41414100,4(a1)
    move.w d2,PendingRank
    clr.w NameCursor
    move.w #6,GameMode
    lea KeyState,a0
    lea NamePrevKeys,a1
    moveq #31,d0
.keys:
    move.l (a0)+,(a1)+
    dbf d0,.keys
    move.w #1,PrefsDirty
    bra FrontendPageEntered

FrontendTick:
    bsr FrontendNavigation
    cmp.w #3,GameMode
    beq.w .demo
    tst.w GameMode
    beq.w .title
    cmp.w #4,GameMode
    beq.w .options
    cmp.w #5,GameMode
    beq.w .scores
    cmp.w #6,GameMode
    beq.w .entry
    cmp.w #7,GameMode
    beq.w .ready
    ; Result page. All gameplay, including enemy fire, is stopped here.
    tst.b UIPressed
    bne.w .show_scores
    subq.w #1,ResultTimer
    beq.w .show_scores
    bra.w .done
.demo:
    tst.b UIPressed
    bne.w .start
    bsr AttractTick
    bra.w .done
.title:
    move.w InputX,d0
    or.w InputY,d0
    beq.w .title_idle
    clr.w AttractIdleTimer
.title_idle:
    tst.w UINavY
    beq.w .title_confirm
    move.w TitleSelection,d0
    add.w UINavY,d0
    bpl.w .title_high
    moveq #4,d0
.title_high:
    cmp.w #4,d0
    ble.w .title_select
    moveq #0,d0
.title_select:
    move.w d0,TitleSelection
    bsr FrontendTouch
.title_confirm:
    tst.b UIPressed
    beq.w .idle_demo
    clr.w AttractIdleTimer
    move.w TitleSelection,d0
    beq.w .start
    cmp.w #1,d0
    beq.w .show_scores
    cmp.w #2,d0
    beq.w .title_options
    cmp.w #3,d0
    beq.w .watch
    move.w #1,QuitRequested
    bra.w .done
.title_options:
    moveq #0,d0
    bsr FrontendOpenOptions
    bra.w .done
.watch:
    bsr FrontendWatchDemo
    bra.w .done
.idle_demo:
    bsr AttractTick
    bra.w .done
.start:
    bsr FrontendBeginGame
    bra.w .done
.show_scores:
    bsr FrontendShowScores
    bra.w .done
.scores:
    tst.b UIPressed
    bne.w .title_back
    tst.b EscapePressed
    beq.w .done
.title_back:
    bsr PlayersScoresContinue
    bra.w .done
.options:
    tst.b EscapePressed
    bne.w .options_back
    btst #0,UIPressed
    bne.w .options_back
    tst.w UINavY
    beq.w .option_confirm
    move.w OptionSelection,d0
    add.w UINavY,d0
    bpl.w .option_high
    moveq #4,d0
.option_high:
    cmp.w #4,d0
    ble.w .option_selected
    moveq #0,d0
.option_selected:
    move.w d0,OptionSelection
    bsr FrontendTouch
.option_confirm:
    move.b UIPressed,d0
    and.b #$42,d0
    bne.w .toggle
    tst.w UINavX
    beq.w .done
.toggle:
    move.w OptionSelection,d0
    cmp.w #4,d0
    beq.w .options_back
    cmp.w #3,d0
    beq.w .players
    tst.w d0
    bne.w .music
    eor.w #1,ShowFPS
    bsr FrontendFPSReset
    bra.w .option_dirty
.music:
    cmp.w #1,d0
    bne.w .effects
    bsr MusicCycleOption
    bra.w .option_dirty
.effects:
    eor.w #1,SfxMuted
    tst.w SfxMuted
    beq.w .effect_preview
    move.w #$000c,$096(a6)
    clr.w $0c8(a6)
    clr.w $0d8(a6)
    clr.w SfxActive
    bra.w .option_dirty
.effect_preview:
    moveq #4,d0
    bsr SfxPlay
    bra.w .option_dirty
.players:
    eor.w #1,TwoPlayerOption
.option_dirty:
    bsr FrontendMarkDirty
    bra.w .done
.options_back:
    bsr FrontendCloseOptions
    bra.w .done
.entry:
    bsr FrontendEntryTick
    bra.w .done
.ready:
    bsr PlayersReadyTick
.done:
    bra FrontendConsume

FrontendEntryAddress:
    lea HighScores+4,a0
    move.w PendingRank,d0
    lsl.w #3,d0
    adda.w d0,a0
    rts

FrontendEntryTick:
    bsr FrontendEntryAddress
    move.w NameCursor,d1
    tst.b NameTyped
    beq.w .pad
    move.b NameTyped,(a0,d1.w)
    cmp.w #2,d1
    bge.w .typed
    addq.w #1,NameCursor
.typed:
    bsr FrontendMarkDirty
    bra.w .confirm
.pad:
    tst.b NameBackspace
    bne.w .previous
    btst #0,UIPressed
    beq.w .position
.previous:
    tst.w NameCursor
    beq.w .confirm
    subq.w #1,NameCursor
    bsr FrontendTouch
    bra.w .confirm
.position:
    tst.w UINavX
    beq.w .letter
    add.w UINavX,d1
    bpl.w .pos_high
    moveq #2,d1
.pos_high:
    cmp.w #2,d1
    ble.w .pos_ok
    moveq #0,d1
.pos_ok:
    move.w d1,NameCursor
    bsr FrontendTouch
.letter:
    tst.w UINavY
    beq.w .confirm
    moveq #0,d2
    move.b (a0,d1.w),d2
    lea UIAlphabet,a1
    moveq #0,d3
.find:
    cmp.b (a1,d3.w),d2
    beq.w .change
    addq.w #1,d3
    cmp.w #37,d3
    blt.w .find
    moveq #0,d3
.change:
    sub.w UINavY,d3
    bpl.w .char_high
    moveq #36,d3
.char_high:
    cmp.w #36,d3
    ble.w .char_ok
    moveq #0,d3
.char_ok:
    move.b (a1,d3.w),(a0,d1.w)
    bsr FrontendMarkDirty
.confirm:
    tst.b EscapePressed
    bne.w .commit
    btst #6,UIPressed
    bne.w .commit
    btst #1,UIPressed
    beq.w .done
    cmp.w #2,NameCursor
    bge.w .commit
    addq.w #1,NameCursor
    bra FrontendTouch
.commit:
    move.w #1,PrefsDirty
    bra FrontendShowScores
.done:
    rts

FrontendFPSReset:
    movem.l d0-d1,-(sp)
    bsr ReadLogicClock
    move.w d0,FPSLastClock
    move.l FrameCounter,FPSLastFrames
    clr.w FPSReady
    clr.w FPSValue
    movem.l (sp)+,d0-d1
    rts

; Actual published images per elapsed PAL second, never simulation tick rate.
FrontendFPSMeasure:
    tst.w ShowFPS
    beq.w .done
    movem.l d0-d3,-(sp)
    bsr ReadLogicClock
    move.w d0,d2
    sub.w FPSLastClock,d2
    cmp.w #50,d2
    blo.w .restore
    move.w d0,FPSLastClock
    move.l FrameCounter,d0
    move.l d0,d3
    sub.l FPSLastFrames,d0
    move.l d3,FPSLastFrames
    mulu #50,d0
    divu d2,d0
    cmp.w #99,d0
    bls.w .value
    moveq #99,d0
.value:
    move.w d0,FPSValue
    move.w #1,FPSReady
.restore:
    movem.l (sp)+,d0-d3
.done:
    rts

FrontendHUD:
    tst.w ShowFPS
    beq.w .done
    move.l BackHUD,a1
    adda.w #320+34,a1
    cmp.w #1,GameMode
    bne.w .positioned
    suba.w #26,a1
.positioned:
    lea UIFPSWait,a0
    tst.w FPSReady
    beq.w .draw
    lea UIFPSPrefix,a0
    bsr HudString
    move.w FPSValue,d0
    and.l #$ffff,d0
    moveq #2,d2
    bra HudNumber
.draw:
    bsr HudString
.done:
    rts

; d0=start row,d1=row count,d2=planes to clear (1 or PLANES). x is the40-byte
; viewport; untouched guards are outside visible fetching, as with title copy.
UIClear:
    movem.l d0-d7/a0-a2,-(sp)
    mulu #ROW_BYTES,d0
    move.l BackBuffer,a1
    adda.l d0,a1
    addq.l #4,a1
    move.w #ROW_BYTES,d5
    move.w d2,d0
    mulu #STRIDE,d0
    sub.w d0,d5
    move.w d1,d7
    subq.w #1,d7
.row:
    move.w d2,d6
    subq.w #1,d6
.plane:
    rept 10
    clr.l (a1)+
    endr
    adda.w #STRIDE-40,a1
    dbf d6,.plane
    adda.w d5,a1
    dbf d7,.row
    movem.l (sp)+,d0-d7/a0-a2
    rts

; a0=ASCII text,d1=x,d2=y, all positions on an8px grid over a black panel.
UIText:
    movem.l d0-d7/a0-a3,-(sp)
    move.l BackBuffer,a1
    move.w d2,d0
    mulu #ROW_BYTES,d0
    adda.l d0,a1
    move.w d1,d0
    lsr.w #3,d0
    addq.w #4,d0
    adda.w d0,a1
.char:
    cmp.w #320,d1
    bge.w .done
    moveq #0,d0
    move.b (a0)+,d0
    beq.w .done
    sub.w #32,d0
    cmp.w #95,d0
    bhi.w .done
    lsl.w #3,d0
    lea Font,a2
    adda.w d0,a2
    move.b (a2)+,0*ROW_BYTES(a1)
    move.b (a2)+,1*ROW_BYTES(a1)
    move.b (a2)+,2*ROW_BYTES(a1)
    move.b (a2)+,3*ROW_BYTES(a1)
    move.b (a2)+,4*ROW_BYTES(a1)
    move.b (a2)+,5*ROW_BYTES(a1)
    move.b (a2)+,6*ROW_BYTES(a1)
    move.b (a2)+,7*ROW_BYTES(a1)
    addq.l #1,a1
    addq.w #8,d1
    bra.w .char
.done:
    movem.l (sp)+,d0-d7/a0-a3
    rts

UIBigText:
    movem.l d0-d7/a0-a3,-(sp)
    move.l BackBuffer,a1
    move.w d2,d0
    mulu #ROW_BYTES,d0
    adda.l d0,a1
    move.w d1,d0
    lsr.w #3,d0
    addq.w #4,d0
    adda.w d0,a1
.char:
    moveq #0,d0
    move.b (a0)+,d0
    beq.w .done
    sub.w #32,d0
    lsl.w #3,d0
    lea Font,a2
    adda.w d0,a2
    move.l a1,a3
    moveq #7,d7
.row:
    move.b (a2)+,d4
    moveq #0,d5
    moveq #7,d6
.bit:
    lsl.w #2,d5
    lsl.b #1,d4
    bcc.w .zero
    or.w #3,d5
.zero:
    dbf d6,.bit
    move.w d5,(a1)
    move.w d5,ROW_BYTES(a1)
    adda.w #2*ROW_BYTES,a1
    dbf d7,.row
    lea 2(a3),a1
    bra.w .char
.done:
    movem.l (sp)+,d0-d7/a0-a3
    rts

; d0=number,d1=x,d2=y,d3=decimal digits.
UINumber:
    movem.l d0-d7/a0-a3,-(sp)
    lea UIStringBuffer,a0
    lea DecimalPowers,a2
    moveq #6,d4
    sub.w d3,d4
    lsl.w #2,d4
    adda.w d4,a2
    subq.w #1,d3
.digit:
    move.l (a2)+,d4
    moveq #'0',d5
.subtract:
    cmp.l d4,d0
    blo.w .emit
    sub.l d4,d0
    addq.b #1,d5
    bra.w .subtract
.emit:
    move.b d5,(a0)+
    dbf d3,.digit
    clr.b (a0)
    lea UIStringBuffer,a0
    bsr UIText
    movem.l (sp)+,d0-d7/a0-a3
    rts

FrontendDraw:
    movem.l d0-d7/a0-a5,-(sp)
    move.w UIRevision,d0
    cmp.w UIBackRevision,d0
    beq.w .done
    bsr WaitBlitter
    tst.w GameMode
    bne.w .black
    cmp.w #1,UIBackArtwork
    beq.w .title_panel
    clr.l AttractTitleBuffer0
    clr.l AttractTitleBuffer1
    bsr DrawAttractTitle
    move.w #1,UIBackArtwork
.title_panel:
    move.w #104,d0
    move.w #120,d1
    moveq #1,d2
    bsr UIClear
    bsr UIDrawTitle
    bra.w .record
.black:
    moveq #0,d0
    move.w #224,d1
    moveq #1,d2
    cmp.w #2,UIBackArtwork
    beq.w .clear
    moveq #PLANES,d2
.clear:
    bsr UIClear
    move.w #2,UIBackArtwork
    cmp.w #4,GameMode
    beq.w .options
    cmp.w #5,GameMode
    beq.w .scores
    cmp.w #6,GameMode
    beq.w .entry
    cmp.w #7,GameMode
    beq.w .ready
    bsr UIDrawResult
    bra.w .record
.options:
    bsr UIDrawOptions
    bra.w .record
.scores:
    bsr UIDrawScores
    bra.w .record
.entry:
    bsr UIDrawEntry
    bra.w .record
.ready:
    bsr PlayersDrawReady
.record:
    move.w UIRevision,UIBackRevision
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

UIDrawTitle:
    lea TitleMenuPointers,a3
    move.w #112,d2
    moveq #4,d7
.row:
    move.l (a3)+,a0
    move.w #96,d1
    bsr UIText
    add.w #16,d2
    dbf d7,.row
    move.w TitleSelection,d2
    lsl.w #4,d2
    add.w #112,d2
    move.w #80,d1
    lea UIArrow,a0
    bsr UIText
    move.w #48,d1
    move.w #208,d2
    lea UITitleCredit,a0
    bra UIText

UIDrawOptions:
    move.w #136,d1
    moveq #24,d2
    lea UIOptionsHeading,a0
    bsr UIText
    lea OptionPointers,a3
    moveq #64,d2
    moveq #0,d7
.row:
    move.l (a3)+,a0
    move.w #88,d1
    bsr UIText
    cmp.w #4,d7
    beq.w .next
    move.w ShowFPS,d0
    tst.w d7
    beq.w .enabled
    cmp.w #1,d7
    beq.w .music_value
    move.w SfxMuted,d0
    cmp.w #3,d7
    beq.w .players_value
.muted:
    eor.w #1,d0
.enabled:
    lea UIOff,a0
    tst.w d0
    beq.w .value
    lea UIOn,a0
.value:
    move.w #208,d1
    bsr UIText
    bra.w .next
.players_value:
    lea UIOnePlayer,a0
    tst.w TwoPlayerOption
    beq.w .value
    lea UITwoPlayers,a0
    bra.w .value
.music_value:
    lea UIOff,a0
    tst.w MusicMuted
    bne.w .value
    lea UIMusicNative,a0
    tst.w MusicChoice
    beq.w .value
    lea UIMusicIkari,a0
    cmp.w #1,MusicChoice
    beq.w .value
    lea UIMusicGate,a0
    bra.w .value
.next:
    add.w #20,d2
    addq.w #1,d7
    cmp.w #5,d7
    blt.w .row
    move.w OptionSelection,d2
    mulu #20,d2
    add.w #64,d2
    move.w #64,d1
    lea UIArrow,a0
    bsr UIText
    move.w #64,d1
    move.w #176,d2
    lea UIStockProfile,a0
    if PLANES=8
    lea UIFullProfile,a0
    move.w #96,d1
    endif
    bsr UIText
    lea UIPlayersNext,a0
    move.w #56,d1
    move.w #192,d2
    bsr UIText
    move.w #48,d1
    move.w #208,d2
    lea UIOptionsHelp,a0
    bra UIText

UIDrawScores:
    move.w #88,d1
    moveq #16,d2
    lea UIScoresHeading,a0
    bsr UIText
    move.w #48,d1
    moveq #36,d2
    lea UIScoresColumns,a0
    bsr UIText
    lea HighScores,a3
    moveq #56,d2
    moveq #0,d7
.row:
    move.w d7,d0
    addq.w #1,d0
    moveq #48,d1
    moveq #2,d3
    bsr UINumber
    lea 4(a3),a0
    move.w #104,d1
    bsr UIText
    move.l (a3),d0
    move.w #176,d1
    moveq #6,d3
    bsr UINumber
    cmp.w PendingRank,d7
    bne.w .next
    moveq #32,d1
    lea UIArrow,a0
    bsr UIText
.next:
    addq.l #8,a3
    add.w #12,d2
    addq.w #1,d7
    cmp.w #10,d7
    blt.w .row
    move.w #104,d1
    move.w #192,d2
    lea UIScoresHelp,a0
    tst.w TurnPending
    bmi.w .scores_help
    lea UINextPlayerHelp,a0
.scores_help:
    bsr UIText
    moveq #40,d1
    move.w #208,d2
    lea UISaveHint,a0
    bra UIText

UIDrawEntry:
    move.w #104,d1
    moveq #24,d2
    lea UIEntryHeading,a0
    tst.w EndReason
    beq.w .demo_entry_heading
    lea UIVictory,a0
.demo_entry_heading:
    bsr UIText
    lea UIPlayerOne,a0
    tst.w ActivePlayer
    beq.w .player_name
    lea UIPlayerTwo,a0
.player_name:
    move.w #128,d1
    moveq #40,d2
    bsr UIText
    move.l Score,d0
    move.w #136,d1
    moveq #56,d2
    moveq #6,d3
    bsr UINumber
    move.w #88,d1
    moveq #88,d2
    lea UIEntryName,a0
    bsr UIText
    bsr FrontendEntryAddress
    move.l a0,a3
    move.w #120,d1
    move.w #112,d2
    moveq #2,d7
.initial:
    lea UIStringBuffer,a0
    move.b (a3)+,(a0)
    clr.b 1(a0)
    bsr UIBigText
    add.w #32,d1
    dbf d7,.initial
    moveq #0,d0
    move.w NameCursor,d0
    lsl.w #2,d0
    add.l #136*ROW_BYTES+4+120/8,d0
    move.l BackBuffer,a0
    adda.l d0,a0
    move.w #$ffff,(a0)
    move.w #$ffff,ROW_BYTES(a0)
    moveq #40,d1
    move.w #160,d2
    lea UIEntryHelp1,a0
    bsr UIText
    moveq #32,d1
    move.w #176,d2
    lea UIEntryHelp2,a0
    bsr UIText
    moveq #32,d1
    move.w #192,d2
    lea UIEntryHelp3,a0
    bra UIText

UIDrawResult:
    move.w #120,d1
    moveq #56,d2
    lea UIGameOver,a0
    tst.w EndReason
    beq.w .heading
    move.w #104,d1
    lea UIVictory,a0
.heading:
    bsr UIText
    move.w #120,d1
    moveq #96,d2
    lea UIYourScore,a0
    bsr UIText
    move.l Score,d0
    move.w #136,d1
    moveq #120,d2
    moveq #6,d3
    bsr UINumber
    move.w #80,d1
    move.w #176,d2
    lea UIResultHelp,a0
    bra UIText

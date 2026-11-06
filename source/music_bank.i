; Optional external Ikari bank. All DOS/Exec allocation runs with AmigaOS alive.
LoadAlternativeMusic:
    movem.l d0-d7/a0-a6,-(sp)
    move.l DosBase,d0
    beq.w .unavailable
    move.l d0,a6
    lea MusicBankPath,a0
    move.l a0,d1
    move.l #1005,d2
    jsr -30(a6)
    tst.l d0
    beq.w .unavailable
    move.l d0,d6
    move.l d6,d1
    lea MusicBankHeader,a0
    move.l a0,d2
    moveq #64,d3
    jsr -42(a6)
    cmp.l #64,d0
    bne.w .close
    lea MusicBankHeader,a0
    cmp.l #$494b4d31,(a0)
    bne.w .close
    cmp.w #443,8(a0)
    bne.w .close
    cmp.w #6,10(a0)
    bne.w .close
    tst.l 12(a0)
    bne.w .close
    move.l 4(a0),d5
    cmp.l #512,d5
    blo.w .close
    cmp.l #3000000,d5
    bhi.w .close
    move.l d5,d0
    and.l #511,d0
    bne.w .close
    lea 16(a0),a1
    moveq #5,d7
.validate_cue:
    move.l (a1)+,d0
    move.l (a1)+,d1
    tst.l d1
    beq.w .close
    move.l d0,d2
    or.l d1,d2
    and.l #511,d2
    bne.w .close
    add.l d1,d0
    bcs.w .close
    cmp.l d5,d0
    bhi.w .close
    dbf d7,.validate_cue
    move.l 4.w,a6
    move.l d5,d0
    moveq #5,d1
    jsr -198(a6)
    move.l d0,d4
    beq.w .close
    move.l DosBase,a6
    move.l d6,d1
    move.l d4,d2
    move.l d5,d3
    jsr -42(a6)
    cmp.l d5,d0
    bne.w .free
    move.l d4,MusicAltBase
    move.l d5,MusicAltBytes
    bra.w .close
.free:
    move.l 4.w,a6
    move.l d4,a1
    move.l d5,d0
    jsr -210(a6)
.close:
    move.l DosBase,a6
    move.l d6,d1
    jsr -36(a6)
.unavailable:
    tst.l MusicAltBase
    bne.w .done
    tst.w MusicChoice
    beq.w .done
    clr.w MusicChoice
    move.w #1,PrefsDirty
.done:
    movem.l (sp)+,d0-d7/a0-a6
    rts

FreeAlternativeMusic:
    movem.l d0-d1/a1/a6,-(sp)
    move.l MusicAltBase,d0
    beq.w .done
    move.l d0,a1
    move.l MusicAltBytes,d0
    move.l 4.w,a6
    jsr -210(a6)
    clr.l MusicAltBase
.done:
    movem.l (sp)+,d0-d1/a1/a6
    rts

; Return a0=current music source,d0=512-byte blocks. Read-only, no DOS calls.
MusicResolve:
    movem.l d1-d3/a1,-(sp)
    lea MusicData,a0
    move.l #(MusicEnd-MusicData)/512,d0
    tst.w MusicChoice
    beq.w .done
    tst.l MusicAltBase
    beq.w .done
    moveq #0,d1
    move.w GameMode,d2
    cmp.w #1,d2
    beq.w .game
    cmp.w #3,d2
    beq.w .game
    cmp.w #7,d2
    beq.w .game
    cmp.w #4,d2
    bne.w .result
    tst.w OptionsReturn
    bne.w .game
    bra.w .cue
.result:
    cmp.w #2,d2
    beq.w .ending
    cmp.w #6,d2
    bne.w .cue
.ending:
    moveq #5,d1
    tst.w EndReason
    beq.w .cue
    moveq #4,d1
    bra.w .cue
.game:
    moveq #2,d1
    cmp.w #2,MusicChoice
    bne.w .cue
    moveq #3,d1
.cue:
    lsl.w #3,d1
    lea MusicBankHeader+16,a1
    adda.w d1,a1
    move.l MusicAltBase,a0
    adda.l (a1),a0
    move.l 4(a1),d0
    lsr.l #8,d0
    lsr.l #1,d0
.done:
    movem.l (sp)+,d1-d3/a1
    rts

MusicCycleOption:
    move.w MusicChoice,d0
    tst.w MusicMuted
    beq.w .step
    moveq #3,d0
.step:
    moveq #1,d1
    tst.w UINavX
    bpl.w .advance
    moveq #-1,d1
.advance:
    add.w d1,d0
    and.w #3,d0
    tst.l MusicAltBase
    bne.w .apply
    tst.w d0
    beq.w .apply
    cmp.w #3,d0
    bne.w .advance
.apply:
    cmp.w #3,d0
    bne.w .audible
    move.w #1,MusicMuted
    rts
.audible:
    clr.w MusicMuted
    move.w d0,MusicChoice
    rts

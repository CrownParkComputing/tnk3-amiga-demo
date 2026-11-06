; DOS I/O occurs only before hardware takeover or after restoring AmigaOS.
; File: TNK3,version1,option bits,ten8-byte records,32-bit additive checksum.
LoadPreferences:
    move.l 4.w,a6
    lea DosName,a1
    moveq #37,d0
    jsr -552(a6)
    move.l d0,DosBase
    beq.w .done
    move.l d0,a6
    ; A complete temporary file can recover a save interrupted before rename.
    lea ScoreTempPath,a0
    bsr ReadScoreFile
    tst.l d0
    beq.w .primary
    move.w #1,PrefsDirty
    rts
.primary:
    lea ScorePath,a0
    bsr ReadScoreFile
    tst.l d0
    bne.w .done
    lea ScoreBackupPath,a0
    bsr ReadScoreFile
    tst.l d0
    beq.w .done
    move.w #1,PrefsDirty
.done:
    rts

; a0=path; return d0=valid file loaded. Do not change table on invalid data.
ReadScoreFile:
    move.l a0,d1
    move.l #1005,d2
    jsr -30(a6)
    tst.l d0
    beq.w .bad
    move.l d0,d4
    move.l d0,d1
    lea ScoreFileBuffer,a0
    move.l a0,d2
    moveq #93,d3
    jsr -42(a6)
    move.l d0,d5
    move.l d4,d1
    jsr -36(a6)
    cmp.l #92,d5
    bne.w .bad
    bsr ValidateScoreFile
    tst.l d0
    beq.w .bad
    lea ScoreFileBuffer+8,a0
    lea HighScores,a1
    moveq #19,d0
.copy:
    move.l (a0)+,(a1)+
    dbf d0,.copy
    move.w ScoreFileBuffer+6,d0
    and.w #1,d0
    move.w d0,ShowFPS
    move.w ScoreFileBuffer+6,d0
    lsr.w #1,d0
    and.w #1,d0
    move.w d0,MusicMuted
    move.w ScoreFileBuffer+6,d0
    lsr.w #2,d0
    and.w #1,d0
    move.w d0,SfxMuted
    move.w ScoreFileBuffer+6,d0
    lsr.w #3,d0
    and.w #3,d0
    move.w d0,MusicChoice
    move.w ScoreFileBuffer+6,d0
    lsr.w #5,d0
    and.w #1,d0
    move.w d0,TwoPlayerOption
    moveq #1,d0
    rts
.bad:
    moveq #0,d0
    rts

ValidateScoreFile:
    lea ScoreFileBuffer,a0
    cmp.l #$544e4b33,(a0)
    bne.w .bad
    cmp.w #1,4(a0)
    bne.w .bad
    move.w 6(a0),d0
    and.w #$ffc0,d0
    bne.w .bad
    move.w 6(a0),d0
    and.w #$18,d0
    cmp.w #$18,d0
    beq.w .bad
    moveq #0,d0
    moveq #21,d1
.checksum:
    add.l (a0)+,d0
    dbf d1,.checksum
    cmp.l (a0),d0
    bne.w .bad
    lea ScoreFileBuffer+8,a0
    move.l #999999,d2
    moveq #9,d7
.record:
    move.l (a0),d0
    cmp.l d2,d0
    bhi.w .bad
    move.l d0,d2
    tst.b 7(a0)
    bne.w .bad
    lea 4(a0),a1
    moveq #2,d6
.name:
    move.b (a1)+,d0
    cmp.b #' ',d0
    beq.w .next_char
    cmp.b #'0',d0
    blo.w .bad
    cmp.b #'9',d0
    bls.w .next_char
    cmp.b #'A',d0
    blo.w .bad
    cmp.b #'Z',d0
    bhi.w .bad
.next_char:
    dbf d6,.name
    addq.l #8,a0
    dbf d7,.record
    moveq #1,d0
    rts
.bad:
    moveq #0,d0
    rts

SavePreferences:
    movem.l d0-d7/a0-a6,-(sp)
    tst.w PrefsDirty
    beq.w .done
    move.w #-1,SaveStatus
    move.l DosBase,d0
    beq.w .done
    move.l d0,a6
    lea ScoreFileBuffer,a0
    move.l #$544e4b33,(a0)+
    move.w #1,(a0)+
    move.w SfxMuted,d0
    lsl.w #1,d0
    or.w MusicMuted,d0
    lsl.w #1,d0
    or.w ShowFPS,d0
    move.w MusicChoice,d1
    lsl.w #3,d1
    or.w d1,d0
    move.w TwoPlayerOption,d1
    lsl.w #5,d1
    or.w d1,d0
    move.w d0,(a0)+
    lea HighScores,a1
    moveq #19,d0
.table:
    move.l (a1)+,(a0)+
    dbf d0,.table
    lea ScoreFileBuffer,a0
    moveq #0,d0
    moveq #21,d1
.checksum:
    add.l (a0)+,d0
    dbf d1,.checksum
    move.l d0,(a0)
    lea ScoreTempPath,a0
    move.l a0,d1
    move.l #1006,d2
    jsr -30(a6)
    tst.l d0
    beq.w .failed
    move.l d0,d4
    move.l d0,d1
    lea ScoreFileBuffer,a0
    move.l a0,d2
    moveq #92,d3
    jsr -48(a6)
    move.l d0,d5
    move.l d4,d1
    jsr -36(a6)
    tst.l d0
    beq.w .failed
    cmp.l #92,d5
    bne.w .failed
    lea ScoreBackupPath,a0
    move.l a0,d1
    jsr -72(a6)
    lea ScorePath,a0
    lea ScoreBackupPath,a1
    move.l a0,d1
    move.l a1,d2
    jsr -78(a6)
    lea ScoreTempPath,a0
    lea ScorePath,a1
    move.l a0,d1
    move.l a1,d2
    jsr -78(a6)
    tst.l d0
    beq.w .failed
    move.w #1,SaveStatus
    clr.w PrefsDirty
    bra.w .done
.failed:
    ; Leave complete tmp/backup files for the next startup recovery attempt.
    jsr -60(a6)
    tst.l d0
    beq.w .done
    move.l d0,d1
    lea SaveFailedText,a0
    move.l a0,d2
    moveq #SaveFailedEnd-SaveFailedText,d3
    jsr -48(a6)
.done:
    movem.l (sp)+,d0-d7/a0-a6
    rts

ClosePreferences:
    movem.l d0-d1/a1/a6,-(sp)
    move.l DosBase,d0
    beq.w .done
    move.l d0,a1
    move.l 4.w,a6
    jsr -414(a6)
    clr.l DosBase
.done:
    movem.l (sp)+,d0-d1/a1/a6
    rts

; All512 native16x16 sprites with all16 palette banks.
; Sources stay in Fast RAM. A bounded Chip cache supplies blitter source data.
; DrawNativeSprite: d0=tile,d1=palette,d2=leftX,d3=topY,d4=horizontal flip.
; Preserves d0-d7/a0-a5; a6 must remain CUSTOM as in DrawBob.

InitNativeSprites:
    movem.l d0-d7/a0-a5,-(sp)
    lea NativeSpritePacked,a0
    lea NativePairs,a1
    bsr UnpackMap
    lea NativeCacheMap,a0
    move.w #(NATIVE_LOOKUP_WORDS/2)-1,d7
.clear:
    clr.l (a0)+
    dbf d7,.clear
    lea NativeCacheKeys,a0
    move.w #NATIVE_CACHE_SLOTS-1,d7
.keys:
    move.w #$ffff,(a0)+
    dbf d7,.keys
    clr.w NativeCacheNext
    clr.l NativeCacheHits
    clr.l NativeCacheMisses
    movem.l (sp)+,d0-d7/a0-a5
    rts

DrawNativeSprite:
    movem.l d0-d7/a0-a5,-(sp)
    ; Cull before any cache fill. The renderer never stages invisible actors.
    cmp.w #-15,d2
    blt.w .done
    cmp.w #WORLD_W-1,d2
    bgt.w .done
    cmp.w #-15,d3
    blt.w .done
    cmp.w #WORLD_H-1,d3
    bgt.w .done
    move.w d2,d5
    sub.w CamX,d5
    cmp.w #-15,d5
    blt.w .done
    cmp.w #VIEW_W-1,d5
    bgt.w .done
    move.w d3,d5
    sub.w CamY,d5
    cmp.w #-15,d5
    blt.w .done
    cmp.w #VIEW_H-1,d5
    bgt.w .done

    and.w #511,d0
    and.w #15,d1
    lsl.w #8,d1
    add.w d1,d1
    or.w d1,d0
    and.w #1,d4
    beq.s .key
    or.w #$2000,d0
.key:
    move.w d0,d7
    move.w d0,d5
    add.w d5,d5
    lea NativeCacheMap,a0
    moveq #0,d6
    move.w (a0,d5.w),d6
    beq.s .miss
    subq.w #1,d6
    addq.l #1,NativeCacheHits
    bra.w .draw
.miss:
    ; The previous BOB may still read its source slot. Retire it before eviction.
    bsr WaitBlitter
    addq.l #1,NativeCacheMisses
    move.w NativeCacheNext,d6
    addq.w #1,NativeCacheNext
    cmp.w #NATIVE_CACHE_SLOTS,NativeCacheNext
    blt.s .slot
    clr.w NativeCacheNext
.slot:
    move.w d6,d0
    add.w d0,d0
    lea NativeCacheKeys,a1
    move.w (a1,d0.w),d4
    cmp.w #$ffff,d4
    beq.s .fresh
    add.w d4,d4
    clr.w (a0,d4.w)
.fresh:
    move.w d7,(a1,d0.w)
    move.w d6,d4
    addq.w #1,d4
    move.w d4,(a0,d5.w)

    moveq #0,d0
    move.w d6,d0
    lsl.l #8,d0
    lsl.l #NATIVE_SLOT_SHIFT-8,d0
    lea NativeCacheData,a1
    adda.l d0,a1
    moveq #0,d0
    move.w d7,d0
    and.w #511,d0
    lsl.l #7,d0
    lea NativePairs,a0
    adda.l d0,a0
    bsr NativeFillImage
    moveq #0,d0
    move.w d7,d0
    and.w #511,d0
    lsl.l #5,d0
    lea NativeMaskWords,a0
    adda.l d0,a0
    bsr NativeFillMask
.draw:
    move.w d2,d1
    move.w d3,d2
    moveq #0,d0
    move.w d6,d0
    add.w #NATIVE_CACHE_BASE,d0
    bsr DrawBob
.done:
    movem.l (sp)+,d0-d7/a0-a5
    rts

; Build one512-byte8-plane image from128 pair codes. Cache hits skip all this.
; Each lookup gives two output bits, avoiding a per-pixel/plane colour search.
; d7 is the immutable cache key. Return a1 advanced by512; preserve all others.
NativeFillImage:
    movem.l d0-d6/a0/a2-a5,-(sp)
    move.w d7,d0
    and.w #$1e00,d0
    lea NativePairColours,a4
    adda.w d0,a4
    btst #13,d7
    bne.w .flipped
    move.w #15,d6
.normal_row:
    move.l a4,a3
    moveq #PLANES-1,d5
.normal_plane:
    move.l a0,a2
    moveq #0,d0
    moveq #0,d1
    rept 8
    lsl.w #2,d0
    move.b (a2)+,d1
    or.b (a3,d1.w),d0
    endr
    move.w d0,(a1)+
    clr.w (a1)+
    lea 64(a3),a3
    dbf d5,.normal_plane
    addq.l #8,a0
    dbf d6,.normal_row
    bra.w .done
.flipped:
    lea NativeSwapPairs,a5
    move.w #15,d6
.flip_row:
    move.l a4,a3
    moveq #PLANES-1,d5
.flip_plane:
    lea 8(a0),a2
    moveq #0,d0
    moveq #0,d1
    rept 8
    lsl.w #2,d0
    move.b -(a2),d1
    move.b (a5,d1.w),d1
    or.b (a3,d1.w),d0
    endr
    move.w d0,(a1)+
    clr.w (a1)+
    lea 64(a3),a3
    dbf d5,.flip_plane
    addq.l #8,a0
    dbf d6,.flip_row
.done:
    movem.l (sp)+,d0-d6/a0/a2-a5
    rts

; Expand each16px opacity word into all8 source planes with zero shift guards.
NativeFillMask:
    movem.l d0-d6/a0/a2-a5,-(sp)
    btst #13,d7
    bne.s .flipped
    move.w #15,d6
.normal_row:
    move.w (a0)+,d0
    rept PLANES
    move.w d0,(a1)+
    clr.w (a1)+
    endr
    dbf d6,.normal_row
    bra.s .done
.flipped:
    lea NativeReverseBits,a3
    move.w #15,d6
.word:
    moveq #0,d0
    move.b 1(a0),d0
    move.b (a3,d0.w),d1
    lsl.w #8,d1
    moveq #0,d0
    move.b (a0),d0
    move.b (a3,d0.w),d1
    rept PLANES
    move.w d1,(a1)+
    clr.w (a1)+
    endr
    addq.l #2,a0
    dbf d6,.word
.done:
    movem.l (sp)+,d0-d6/a0/a2-a5
    rts

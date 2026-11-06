; Fast RAM; the decompressor supplies every byte of the recorded replay/title.
AttractReplayRaw: ds.b ATTRACT_RAW_BYTES
    even
AttractFramePtr: ds.l 1
AttractTitleBuffer0: ds.l 1
AttractTitleBuffer1: ds.l 1
AttractFrameIndex: ds.w 1
AttractIdleTimer: ds.w 1
AttractCycles: ds.w 1

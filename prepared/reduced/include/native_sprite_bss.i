; Fast RAM. Packed images and masks are decoded once before takeover.
    cnop 0,4
NativePairs: ds.b NATIVE_PAIR_BYTES
NativeMaskWords: ds.b NATIVE_MASK_BYTES
NativeCacheMap: ds.w NATIVE_LOOKUP_WORDS
NativeCacheKeys: ds.w NATIVE_CACHE_SLOTS
NativeCacheNext: ds.w 1
    even
NativeCacheHits: ds.l 1
NativeCacheMisses: ds.l 1

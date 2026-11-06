#!/usr/bin/env python3
"""Check the demo's physical geometry, wave bounds and prepared-asset manifest."""
from pathlib import Path
import hashlib, json, re, struct, sys
from lzss import lzss_decompress

ROOT = Path(__file__).resolve().parents[1]


def main():
    manifest = json.loads((ROOT/'DEMO-CONTENT.json').read_text())
    assert manifest['edition'] == 'demo'
    for path, expected in manifest['files'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest() == expected, path+' changed'
    waves = (ROOT/'source/waves.i').read_text().split('NATIVE_SHAPE_COUNT', 1)[0]
    rows = [list(map(int, x.split(','))) for x in re.findall(r'^\s*dc.w ([\d,\-]+)', waves, re.M)]
    assert len(rows) == manifest['wave_count']
    assert all(0 <= row[0] < 18000 and -128 <= row[2] < 18512 for row in rows)
    for v in ('reduced', 'full'):
        include = (ROOT/f'prepared/{v}/include/display.i').read_text()
        values = {k:int(n) for k,n in re.findall(r'^(\w+) equ (\d+)$', include, re.M)}
        assert values['WORLD_H'] == 18512 and values['WORLD_W'] == 512
        assert values['ROUTE_END_PROGRESS'] == 18000
        cells = (18512//8)*64
        raw = lzss_decompress((ROOT/f'prepared/{v}/assets/map.lz').read_bytes())
        assert len(raw) == cells*4
        ids = struct.unpack('>'+str(cells)+'H', raw[:cells*2])
        tiles = (ROOT/f'prepared/{v}/assets/tiles.bin').read_bytes()
        assert max(ids) < len(tiles)//(8*values['PLANES'])
        assert len(tiles)//(8*values['PLANES']) == manifest['variants'][v]['terrain_tiles']
        replay = lzss_decompress((ROOT/f'prepared/{v}/assets/attract.lz').read_bytes())
        settings = dict(re.findall(r'^(ATTRACT_\w+) equ (\d+)', (ROOT/f'prepared/{v}/include/attract_data.i').read_text(), re.M))
        off = 0
        for _ in range(int(settings['ATTRACT_FRAME_COUNT'])):
            x,y,n = struct.unpack_from('>3H', replay, off)
            assert 0 <= x <= 192 and 0 <= y <= 18512-224
            off += 6
            for _ in range(n):
                tile,bank,ax,ay,flip = struct.unpack_from('>2H2hH', replay, off)
                assert 0 <= ay < 18512 and tile < 512 and bank < 16 and flip < 2
                off += 10
        assert off == int(settings['ATTRACT_REPLAY_BYTES'])
    for path in ROOT.rglob('*'):
        if not path.is_file() or '.git' in path.parts or 'build' in path.parts:
            continue
        assert path.name not in ('campaign_native.npz','map_native.npz','tnk3.zip'), str(path)
        assert path.suffix.lower() not in ('.rom','.pem','.key'), str(path)
    print(f'Demo verified:18,000 route pixels,{len(rows)} waves,18512-row physical map; no later campaign inputs.')


if __name__ == '__main__': main()

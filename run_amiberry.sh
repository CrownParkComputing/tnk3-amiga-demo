#!/usr/bin/env bash
# Launch only this conversion in a new emulator, using the selected edition.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tnk_rom="${AMIGA_KICKSTART:-$HOME/Amiberry/ROMs/kick31.rom}"
tnk_variant=
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rom|--variant)
            if [[ $# -lt 2 ]]; then echo "Missing value for $1" >&2; exit 2; fi
            if [[ "$1" == --rom ]]; then tnk_rom="$2"; else tnk_variant="$2"; fi
            shift 2 ;;
        --) shift; break ;;
        *) break ;;
    esac
done
if [[ -n "$tnk_variant" && "$tnk_variant" != reduced && "$tnk_variant" != full ]]; then
    echo 'Usage: run_amiberry.sh [--variant reduced|full] [--rom /path/kick31.rom] [-- Amiberry options]' >&2
    exit 2
fi
tnk_runtime="$(mktemp -d "${TMPDIR:-/tmp}/tnk3-amiberry-XXXXXXXX")"
trap 'rm -rf -- "$tnk_runtime"' EXIT
python3 - "$here" "$tnk_rom" "$tnk_variant" "$tnk_runtime/game.uae" <<'PY'
import json
from pathlib import Path
import sys
root, rom, variant = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).expanduser().resolve(), sys.argv[3]
manifest_path = root/'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.is_file() else {}
variant = variant or manifest.get('variant', 'reduced')
if variant not in ('reduced', 'full'):
    raise SystemExit(f'Unknown graphics variant: {variant}')
if not rom.is_file():
    raise SystemExit(f'Kickstart ROM is missing: {rom}; use --rom or AMIGA_KICKSTART')
hd = root/'hd'/variant
if not (hd/'tnk3').is_file():
    # Each portable release contains one edition in its own flat hd/ folder.
    if manifest.get('variant') == variant:
        hd = root/'hd'
    else:
        raise SystemExit(f'Missing hd/{variant}/tnk3; build this variant with python3 build.py --variant {variant}')
template = root/f'config/tnk3-{variant}.uae.in'
if not template.is_file():
    template = root/'config/tnk3.uae.in'
text = template.read_text().replace('YOUR_KICKSTART_ROM', str(rom)).replace('YOUR_HD_FOLDER', str(hd))
Path(sys.argv[4]).write_text(text)
PY
amiberry -G -f "$tnk_runtime/game.uae" "$@"

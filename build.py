#!/usr/bin/env python3
"""Build the physically shortened demo from the prepared demo-only assets."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tempfile, zipfile

ROOT = Path(__file__).resolve().parent
NAMES = {'reduced': 'TNKIII-Demo-Stock', 'full': 'TNKIII-Demo-FullColour-16x'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--variant', choices=['reduced', 'full', 'all'], default='all')
    p.add_argument('--rom', type=Path, default=Path(os.environ.get('AMIGA_KICKSTART', str(Path.home()/'Amiberry/ROMs/kick31.rom'))))
    p.add_argument('--no-package', action='store_true')
    p.add_argument('--install-presets', action='store_true')
    args = p.parse_args()
    subprocess.run(['python3', 'tools/check_demo.py'], cwd=ROOT, check=True)
    if not shutil.which('vasmm68k_mot'):
        p.error('Install vasmm68k_mot to assemble the demo')
    variants = ['reduced', 'full'] if args.variant == 'all' else [args.variant]
    rom = args.rom.expanduser().resolve()
    for v in variants:
        build = ROOT/'build'/v; build.mkdir(parents=True, exist_ok=True)
        subprocess.run(['vasmm68k_mot', '-m68020', '-Fhunkexe', '-I', f'prepared/{v}/include',
            '-I', 'source', '-L', str(build/'tnk3.lst'), '-o', str(build/'tnk3'), 'source/tnk3.asm'], cwd=ROOT, check=True)
        hd = ROOT/'hd'/v; (hd/'s').mkdir(parents=True, exist_ok=True)
        shutil.copy2(build/'tnk3', hd/'tnk3')
        shutil.copy2(ROOT/'assets/ikari_music.bin', hd/'ikari_music.bin')
        (hd/'s/startup-sequence').write_text('tnk3\n')
        template = (ROOT/f'config/tnk3-{v}.uae.in').read_text()
        cfg = template.replace('YOUR_KICKSTART_ROM', str(rom)).replace('YOUR_HD_FOLDER', str(hd))
        (build/'TNKIII-Demo.uae').write_text(cfg)
        if args.install_presets:
            presets = Path.home()/'Amiberry/Configurations'; presets.mkdir(parents=True, exist_ok=True)
            (presets/(NAMES[v]+'.uae')).write_text(cfg)
        if args.no_package:
            continue
        destination = ROOT/'downloads'; destination.mkdir(exist_ok=True)
        name = NAMES[v]
        with tempfile.TemporaryDirectory(prefix='tnk3-demo-package-') as td:
            stage = Path(td)/name
            shutil.copytree(hd, stage/'hd', ignore=shutil.ignore_patterns('*.scores*', '.uaefsdb'))
            (stage/'config').mkdir()
            (stage/f'config/tnk3-{v}.uae.in').write_text(template)
            (stage/'config/tnk3.uae.in').write_text(template)
            shutil.copy2(ROOT/'run_amiberry.sh', stage/'run_amiberry.sh')
            shutil.copy2(ROOT/'README.md', stage/'README.md')
            (stage/'ReadMe.txt').write_text('TNK III FIVE-MINUTE ROUTE DEMO\n\n'
                'The shortened terrain and enemy-wave data are the complete demo.\n'
                'Later campaign data is absent. There is no countdown to bypass.\n'
                'Directions move; A/Ctrl cannon; B/Space machine gun; shoulders/Z/C turret.\n'
                'Start pauses into Options. PLAYERS selects one or two alternating players.\n'
                'MUSIC selects TNK III, Ikari Theme, Ikari Gate or OFF on the HD build.\n'
                'Save & Quit retains high scores/options. The DD disk uses TNK III music.\n'
                'Requires A1200/AGA,2MB Chip,8MB Fast and your own Kickstart3.1.\n'
                'Stock CPU: multiplier4. Accelerated full colour: multiplier64,16x stock.\n'
                'Original game/art/music SNK. Amiga conversion WHittyApps.\n')
            exe = (build/'tnk3').read_bytes()
            manifest = dict(edition='demo', variant=v, route_pixels=18000, world_height=18512,
                executable_bytes=len(exe), executable_sha256=hashlib.sha256(exe).hexdigest(),
                stock_cpu_clock_factor=1 if v=='reduced' else 16,
                system_rom_included=False, later_campaign_data_included=False)
            if shutil.which('xdftool'):
                disk = stage/(name+'.adf')
                subprocess.run(['xdftool', str(disk), 'create', '+', 'format', 'TNK3Demo', 'ffs', '+',
                    'boot', 'install', '+', 'makedir', 's', '+', 'write', str(hd/'s/startup-sequence'),
                    's/startup-sequence', '+', 'write', str(build/'tnk3'), 'tnk3', '+', 'write',
                    str(stage/'ReadMe.txt'), 'ReadMe'], check=True, stdout=subprocess.DEVNULL)
                readback = Path(td)/'readback'
                subprocess.run(['xdftool', str(disk), 'read', 'tnk3', str(readback)], check=True, stdout=subprocess.DEVNULL)
                assert readback.read_bytes() == exe
                manifest.update(disk=disk.name, disk_sha256=hashlib.sha256(disk.read_bytes()).hexdigest())
                shutil.copy2(disk, destination/disk.name)
            (stage/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
            with zipfile.ZipFile(destination/(name+'.zip'), 'w', zipfile.ZIP_DEFLATED) as z:
                for f in sorted(stage.rglob('*')):
                    if f.is_file(): z.write(f, f.relative_to(stage.parent))
        print(f'Built {name}: {len(exe):,} bytes')


if __name__ == '__main__': main()

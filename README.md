# TNK III Amiga — five-minute route demo

This playable source demo contains a shortened 18,000-pixel route: roughly five
minutes of continuous forward movement at the normal speed. Combat, exploration
and alternating players can extend play. Reaching the end shows DEMO COMPLETE.

The terrain, collision maps and enemy-wave table are physically shortened.
Later campaign maps and spawn requests are absent from this repository, its
binaries and downloads. There is no demo countdown or full-edition switch.
The repository starts with clean demo-only Git history. The public engine can
be modified; the omitted campaign data cannot be recovered by changing a timer.

Two A1200/AGA builds are included. Both need 2MB Chip,8MB Fast and your own
Kickstart3.1 ROM. The stock build preserves original RGB in seven planes with
stock CPU/blitter timing; the full-colour build uses eight planes and a 16x
68020 emulator preset (`cpu_multiplier=64`, versus stock `4`). The `full` build
argument means full colour; both builds contain the same shortened demo route.

Prebuilt HD ZIPs and bootable DD ADFs are under `downloads/`. The two UAE
configuration templates are in `config/`. Launch the selected HD build with:

```sh
./run_amiberry.sh --rom /path/to/kick31.rom
./run_amiberry.sh --variant full --rom /path/to/kick31.rom
```

Directions move. A/Ctrl fires the cannon, B/Space the machine gun; shoulders or
Z/C rotate the turret. Start pauses into Options. PLAYERS selects one or two
alternating players for the next game; each has separate lives, score and
progress. MUSIC selects TNK III, Ikari Theme, Ikari Gate or OFF on the HD build.
The DD disk uses the built-in TNK III tune. Save & Quit retains scores/options.

Rebuild from the checked-in prepared demo assets with Python3 and
`vasmm68k_mot` on PATH. `xdftool` optionally creates the DD disks:

```sh
python3 build.py --variant all --rom /path/to/kick31.rom
python3 tools/check_demo.py
```

No original arcade ROM archive, full-map decoder/input or system ROM is needed
for assembly or included here. `DEMO-CONTENT.json` records the prepared asset
hashes and physical geometry. Verification evidence is under `verification/`.
The full project and all campaign data live in a separate private repository.
This remains a conversion in development; complete native AI, terrain
destruction, original area music and the full ending remain incomplete.

Original game, artwork and music: SNK. Amiga conversion: WHittyApps.

Primary controller: physical Amiga port2. Port1 remains the mouse. In two-player
alternating mode both players share the port2 controller. Automatic input
switching is disabled in the supplied presets.

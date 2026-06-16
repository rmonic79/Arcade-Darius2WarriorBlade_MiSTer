# Authors and Credits

## Darius2WarriorBlade_MiSTer core

**Author**: Umberto Parisi ([rmonic79](https://github.com/rmonic79))

The original RTL source files for the Darius II (dual screen) / Warrior Blade
specific logic (under `rtl/darius2/` and the project wrapper `Template.sv`)
are copyright Umberto Parisi and distributed under GNU GPL v3 or later.

## Third-party components

This core builds on top of excellent open-source projects. All third-party
sources retain their original copyright and license. The core as a whole
is distributed under **GNU GPL v3 or later** to stay compatible with the
most restrictive upstream (JTFRAME).

| Component | Author | Project | License |
|-----------|--------|---------|---------|
| **FX68K** — M68000 cycle-accurate core | Jorge Cwik | [ijor/fx68k](https://github.com/ijor/fx68k) | GPL-3 |
| **T80** — Z80 (sound CPU) core | Daniel Wallner, MiSTer-devel maintainers | [MiSTer-devel](https://github.com/MiSTer-devel) | BSD-style |
| **JT12** — Yamaha YM2610 / YM2203 FM + SSG + ADPCM | Jose Tejada ([@topapate](https://github.com/jotego)) | [jotego/jt12](https://github.com/jotego/jt12) | GPL-3 |
| **JT5205** — OKI MSM5205 ADPCM decoder | Jose Tejada | [jotego/jt5205](https://github.com/jotego/jt5205) | GPL-3 |
| **JTFRAME** — fractional clock enables and framework helpers | Jose Tejada | [jotego/jtframe](https://github.com/jotego/jtframe) | GPL-3 |
| **TC0140SYT** — Taito main↔sound communication chip | Martin Donlon ([wickerwaka](https://github.com/wickerwaka)) | [wickerwaka/Arcade-TaitoF2_MiSTer](https://github.com/wickerwaka/Arcade-TaitoF2_MiSTer) | GPL-3 |
| **Savestate bus interface** — ssbus port layout (TC0100SCN) | Martin Donlon ([wickerwaka](https://github.com/wickerwaka)) | [wickerwaka/Arcade-TaitoF2_MiSTer](https://github.com/wickerwaka/Arcade-TaitoF2_MiSTer) | GPL-3 |
| **MAME** — reference for TC0100SCN tilemap, TC0110PR palette/priority, memory maps, timing | MAMEDev team | [mamedev/mame](https://github.com/mamedev/mame) | GPL-2+ |
| **sys/ framework** — MiSTer HPS/IO, OSD, video scaler, audio | Sorgelig / MiSTer-devel | [MiSTer-devel/Main_MiSTer](https://github.com/MiSTer-devel/Main_MiSTer) | GPL-3 |
| **SDRAM controller** | Sorgelig (Genesis-style, port 3 added for this core) | [MiSTer-devel](https://github.com/MiSTer-devel) | GPL-3 |

## Reference

- **Darius II / Warrior Blade arcade hardware** (Taito dual-screen board:
  single 68000, 2× TC0100SCN, YM2610). This FPGA core is a
  reimplementation from hardware documentation, MAME source code, and
  observation of real hardware behavior. ROMs are **not** included and must
  be provided by the user.
- **MAME project** — invaluable reference for memory maps, timing, the
  TC0100SCN tilemap chips and TC0110PR palette/priority logic.
  [mamedev/mame](https://github.com/mamedev/mame)
- **Martin Donlon's Taito F2 core** — the F2 hardware analysis and the
  TC0140SYT / savestate infrastructure were a foundational reference for
  composing this core. [wickerwaka/Arcade-TaitoF2_MiSTer](https://github.com/wickerwaka/Arcade-TaitoF2_MiSTer)

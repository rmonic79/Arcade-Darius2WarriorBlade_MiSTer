# Arcade-Darius2WarriorBlade_MiSTer

FPGA core for the Taito **dual-screen** arcade hardware targeting the
[MiSTer FPGA](https://github.com/MiSTer-devel) platform
(Terasic DE10-Nano). The core runs **Darius II** (dual screen), **Sagaia**
and **Warrior Blade — Rastan Saga Episode III**.

The board uses a single 68000 main CPU, a Z80 sound CPU with YM2610, two
TC0100SCN tilemap chips driving two screens side by side, two TC0110PR
palette/priority chips, and a sprite generator.

This core reimplements the hardware in SystemVerilog from MAME references
and hardware observation.

> This repository contains the SystemVerilog source code. The compiled
> bitstream will be released once the author considers it complete. In the
> meantime you can build the core yourself with Quartus (see *Building from
> source*).

## Status

**Current version: 0.8 (Beta)** (2026).

The core runs the games end-to-end and has been tested on real MiSTer
hardware. Expect rough edges while the core is in beta.

**Work in progress for 1.0:**
- Savestate support (ssbus infrastructure in place, to be finalized)
- Audio polish
- OSD polish

**Features**
- M68000 main CPU (FX68K core) — single 68000
- Z80 sound CPU (T80) with Taito TC0140SYT main↔sound communication
- Two TC0100SCN tilemap chips (MAME-accurate): BG0, BG1 with per-row scroll
  and per-column scroll, plus the FG0 text layer
- Two TC0110PR palette / priority chips
- Sprite renderer with priority, flip, buffered sprite RAM
- Audio: YM2610 (FM + SSG + ADPCM-A/B) via JT12, MSM5205 via JT5205
- Dual-screen composition (two 320-pixel panels side by side)
- Graphics and audio data streaming through a multi-port SDRAM controller
- Additional graphics/audio data backed by DDR3
- VBlank-synchronized pause (frame-aligned, no race conditions)
- MiSTer OSD with video and DIP options

**Games supported**
- Darius II (Japan, dual screen)
- Sagaia (World, dual screen)
- Warrior Blade — Rastan Saga Episode III (Japan)

## Hardware emulated

| Component        | Spec                                                |
|------------------|-----------------------------------------------------|
| Main CPU         | M68000 (FX68K)                                       |
| Sound CPU        | Z80 (T80)                                            |
| Sound chip       | Yamaha YM2610 (FM + SSG + ADPCM-A/B, jt12)           |
| ADPCM            | OKI MSM5205 (jt5205)                                 |
| Sound comm       | Taito TC0140SYT                                      |
| Tilemaps         | TC0100SCN ×2 (dual screen, BG0/BG1/FG0)              |
| Palette / prio   | TC0110PR ×2                                          |

## Hardware requirements

- Terasic DE10-Nano
- MiSTer I/O board (recommended)
- SDRAM module (32 MB or 64 MB)
- DDR3 memory (built into DE10-Nano)
- Works on HDMI displays and on CRTs via the analog video output

## Building from source

Requires Quartus Prime 17.0 (free Lite Edition).

```
Open Darius2WarriorBlade.qpf in Quartus → Processing → Start Compilation
```

Output bitstream is generated in `output_files/Darius2WarriorBlade.rbf`.

## Running on MiSTer

This repository ships sources only — there is no prebuilt bitstream.
Build `Darius2WarriorBlade.rbf` from source (see *Building from source*
above) and copy it to `_Arcade/cores/` on the MiSTer SD card. Any data
files the core needs are not included and must be provided by the user.

## Repository layout

```
Arcade-Darius2WarriorBlade_MiSTer/
├── rtl/
│   ├── darius2/   Darius II / Warrior Blade core RTL (TC0100SCN, TC0110PR,
│   │              TC0140SYT, sprite renderer, memory maps, audio, bridges)
│   ├── fx68k/     FX68K M68000 cycle-accurate core
│   ├── t80/       Z80 sound CPU
│   ├── jt12/      YM2610 / YM2203 FM + SSG + ADPCM
│   ├── jt5205/    MSM5205 ADPCM
│   ├── jtframe/   JTFRAME framework helpers
│   ├── pll/       Clock PLL
│   └── sdram.sv   SDRAM controller (Sorgelig)
├── sys/                    MiSTer framework (Sorgelig / MiSTer-devel)
├── logo/                   Pause overlay assets
├── Darius2WarriorBlade.qpf Quartus project
├── Darius2WarriorBlade.qsf Quartus assignments
├── Template.sv             Top-level wrapper
├── Template.sdc            Timing constraints
├── files.qip               HDL file list
└── README.md               This file
```

## Acknowledgements

- **Jose Tejada** ([@jotego](https://github.com/jotego)) for JT12 (YM2610),
  JT5205 (MSM5205) and the JTFRAME framework.
- **Jorge Cwik** ([ijor](https://github.com/ijor)) for the **FX68K**
  cycle-accurate M68000 core.
- **Martin Donlon** ([wickerwaka](https://github.com/wickerwaka)) for the
  Taito F2 core: the TC0140SYT sound-comm chip and the savestate bus
  layout used here come from that work, and his F2 hardware analysis was a
  foundational reference for composing this core.
- The **MAMEDev team** for the invaluable reference on the TC0100SCN
  tilemaps, TC0110PR palette/priority, memory maps and timing.
- **Sorgelig** and the **MiSTer-devel team** for the framework, SDRAM
  controller and Template.

## Support this project

If you enjoy this core and want to support its development:

- [Ko-fi](https://ko-fi.com/ibecerivideoludici) — one-time support
- [Patreon](https://www.patreon.com/IBeceriVideoludici) — monthly support
- [PayPal](https://www.paypal.me/IBeceriVideoludici) — one-time donation

## Follow

- [GitHub](https://github.com/rmonic79)
- [Twitch](https://twitch.tv/ibecerivideoludici) — live streams
- [YouTube](https://www.youtube.com/c/IBeceriVideoludici) — playlists and videos
- [X / Twitter](https://x.com/rmonic79)

## License

The RTL source code in this repository is provided as-is for educational
and preservation purposes under **GNU GPL v3 or later**. ROM data is not
included; users must provide their own.

Original *Darius II* / *Warrior Blade — Rastan Saga Episode III* arcade
hardware © Taito Corporation.

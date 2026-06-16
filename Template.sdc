derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# ============================================================
# Audio subsystem runs at ce_4m (96MHz/24 = 4MHz)
# All internal paths are CE-gated with 24 cycles between active edges.
# Multicycle = 24 for setup, 23 for hold.
# Target everything under darius_audio_z80 module (jt03, T80pa, mixer, ...).
# ============================================================
set_multicycle_path -setup -from [get_registers {*darius_audio_z80*}] -to [get_registers {*darius_audio_z80*}] 24
set_multicycle_path -hold  -from [get_registers {*darius_audio_z80*}] -to [get_registers {*darius_audio_z80*}] 23

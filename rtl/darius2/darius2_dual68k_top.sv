/*  This file is part of Darius2WarriorBlade_MiSTer.

    Darius2WarriorBlade_MiSTer is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Darius2WarriorBlade_MiSTer is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Darius2WarriorBlade_MiSTer.  If not, see <http://www.gnu.org/licenses/>.

    Author: Umberto Parisi (rmonic79)
    Version: 1.0
    Date: 2026

*/

// darius_dual68k_top — Top-level del core Darius.
// Istanzia entrambe le CPU 68000 (main + sub), memory maps, shared/sprite/
// FG/palette RAM, sprite renderer, FG renderer, 3 panel renderer (L/C/R),
// vram arbiter, sdram bridge, audio Z80 subsystem, triple screen composer.

module darius2_dual68k_top
#(
	parameter [1:0] MAIN_CORE_IMPL    = 2'd1,
	parameter [1:0] SUB_CORE_IMPL     = 2'd1,
	parameter       HOLD_SUB_IN_RESET = 1'b0,
	parameter       ENABLE_C00050_NOP = 1'b1,
	parameter       ENABLE_WATCHDOG   = 1'b1,
	parameter       ENABLE_PC080_CTRL = 1'b1,
	parameter       ENABLE_DC0000     = 1'b1,
	parameter       ENABLE_C00060     = 1'b1,
	parameter       ENABLE_C00020     = 1'b1,
	parameter       ENABLE_C00022     = 1'b1,
	parameter       ENABLE_C00024     = 1'b1,
	parameter       ENABLE_C00030     = 1'b1,
	parameter       ENABLE_C00032     = 1'b1,
	parameter       ENABLE_C00034     = 1'b1,
	parameter       ENABLE_D40000     = 1'b1,
	parameter       ENABLE_D40002     = 1'b1,
	parameter       ENABLE_D20000     = 1'b1,
	parameter       ENABLE_D20002     = 1'b1,
	parameter       ENABLE_C0000C     = 1'b1,
	parameter       ENABLE_C00010     = 1'b1,
	parameter       ENABLE_MAIN_PC060HA_PORT = 1'b1,
	parameter       ENABLE_MAIN_PC060HA_COMM = 1'b1,
	parameter       ENABLE_MAIN_D00000 = 1'b1,
	parameter       ENABLE_MAIN_PALETTE = 1'b1,
	parameter       ENABLE_FG_RAM      = 1'b1,
	parameter       ENABLE_MAIN_CTRL  = 1'b1,
	parameter       ENABLE_MAIN_SHARED = 1'b1,
	parameter       ENABLE_MAIN_SPRITE = 1'b1,
	parameter       ENABLE_MAIN_IO    = 1'b1,
	parameter       ENABLE_MAIN_VIDEO = 1'b1,
	parameter       ENABLE_MAIN_PLAYER_IO = 1'b1,
	parameter       ENABLE_SUB_SHARED = 1'b1,
	parameter       ENABLE_SUB_SPRITE = 1'b1,
	parameter       ENABLE_SUB_PALETTE = 1'b1,
	parameter       ENABLE_SUB_IO     = 1'b1,
	parameter       ENABLE_VBLANK_IRQ = 1'b1
)
(
	input  wire        clk,
	input  wire        reset,
	input  wire        pause,
	// Board variant: warriorb.cpp hardware (sempre 2-screen, single 68000).
	//   board_warriorb : 0 = darius2d/sagaia memory map
	//                    1 = warriorb memory map
	//   darius2d: ROM 0x000000-0x0FFFFF, RAM 0x100000-0x10FFFF,
	//             SCN0 0x200000, SCN1 0x240000, PAL0 0x400000, PAL1 0x420000,
	//             SPR 0x600000, IOC 0x800000 (TC0220IOC)
	//   warriorb: ROM 0x000000-0x1FFFFF, RAM 0x200000-0x213FFF,
	//             SCN0 0x300000, SCN1 0x340000, PAL0 0x400000, PAL1 0x420000,
	//             SPR 0x600000, IOC 0x800000 (TC0510NIO)
	input  wire        board_warriorb,
	input  wire  [2:0] clk_sel,      // Main CPU: 000=8MHz, 001=12MHz, 010=16MHz, 011=24MHz, 100=32MHz*, 101=48MHz*
	input  wire  [2:0] sub_clk_sel,   // Sub CPU: 000=8MHz, 001=12MHz, 010=16MHz, 011=24MHz, 100=32MHz*, 101=48MHz*
	input  wire  [1:0] z80_clk_sel,  // Z80: 00=4MHz, 01=8MHz, 10=2MHz, 11=1MHz
	input  wire  [7:0] p1_input,
	input  wire  [7:0] p2_input,
	input  wire  [7:0] system_input,   // MAME SYSTEM port: {00,start2,start1,tilt,service,coin2,coin1}
	input  wire [15:0] dsw_input,
	input  wire [15:0] main_rom_rdata,
	input  wire        main_rom_ready,
	input  wire [15:0] sub_rom_rdata,
	input  wire        sub_rom_ready,
	input  wire [9:0]  render_x,
	input  wire [8:0]  render_y,
	input  wire        hblank_in,  // HBlank from compositor (pulses every line, even during vblank)
	input  wire [31:0] tilerom_data,
	input  wire        tilerom_valid,
	// Debug layer disable (OSD): 1=hide layer
	input  wire        dbg_dis_bg0,
	input  wire        dbg_dis_bg1,
	input  wire        dbg_dis_fg0,
	// SCN rate selector rimosso — SCN ora usa ce_13m fisso (13.33 MHz, MAME-accurate).
	output wire [23:0] main_rom_addr,
	output wire        main_rom_req,
	output wire [23:0] sub_rom_addr,
	output wire        sub_rom_req,
	output wire [23:0] tilerom_addr,
	output wire        tilerom_req,
	output wire        tilerom_is_sprite,
	output wire        tilerom_is_text,
	// (sprite ROM port 3 SDRAM rimossa — sprite ora su DDR3 port 4 interno)
	// Audio ROM download (ioctl → BRAM inside audio module)
	input  wire        ioctl_download,
	input  wire        ioctl_wr,
	input  wire [26:0] ioctl_addr,
	input  wire [15:0] ioctl_dout,
	input  wire [15:0] ioctl_index,
	output wire [23:0] fg_rgb,
	output wire        fg_opaque,
	output wire [15:0] xscroll_l0,
	output wire [15:0] xscroll_l1,
	output wire [15:0] yscroll_l0,
	output wire [15:0] yscroll_l1,
	output wire [15:0] ctrl_l0,
	output wire [15:0] ctrl_l1,
	output wire [23:0] tile_rgb,
	output wire [1:0]  tile_prio,
	output wire        tile_opaque,
	output wire [23:0] sprite_rgb,
	output wire  [1:0] sprite_prio,
	output wire        sprite_opaque,
	// OSD layer offsets
	input  wire signed [9:0] l0_xoff, l0_yoff,
	input  wire signed [9:0] l1_xoff, l1_yoff,
	input  wire signed [9:0] spr_xoff, spr_yoff,
	input  wire signed [9:0] fg_xoff, fg_yoff,
	// OSD layer enable (BG0, BG1, FG0). Default 3'b111 = tutti on.
	input  wire [2:0]        osd_tile_layer_en,
	// Text ROM download for FG BRAM
	input  wire        fg_dl_wr,
	input  wire [13:0] fg_dl_addr,
	input  wire [15:0] fg_dl_data,
	// Compositor pixel clock enable (24 MHz from triple_screen_test)
	input  wire        ce_pix,
	// Audio output
	output wire signed [15:0] audio_l,
	output wire signed [15:0] audio_r,
	// Audio mixer OSD volumes (3-bit each)
	input  wire  [2:0] osd_fm_vol,
	input  wire  [2:0] osd_adpcma_vol,
	input  wire  [2:0] osd_adpcmb_vol,
	input  wire  [2:0] osd_psg_vol,
	// DDRAM HPS interface (audio: ROM Z80 + ADPCM A/B via darius2_ddram)
	input  wire        DDRAM_CLK,
	input  wire        DDRAM_BUSY,
	output wire  [7:0] DDRAM_BURSTCNT,
	output wire [28:0] DDRAM_ADDR,
	input  wire [63:0] DDRAM_DOUT,
	input  wire        DDRAM_DOUT_READY,
	output wire        DDRAM_RD,
	output wire [63:0] DDRAM_DIN,
	output wire  [7:0] DDRAM_BE,
	output wire        DDRAM_WE,
	output wire        ioctl_wait_audio,
	// Debug overlay
	output wire [23:0] dbg_main_pc,
	output wire [23:0] dbg_bus_addr,
	output wire [3:0]  dbg_txn_state,
	output wire        dbg_bus_busy,
	output wire        dbg_dtack_n,
	output wire        dbg_ext_dtack_n,
	output wire [14:0] dbg_scn0_sc,
	output wire        dbg_scn0_sc_seen,
	output wire        dbg_tilerom_req_seen,
	output wire [15:0] dbg_scn0_wr_cnt,
	output wire        dbg_z80_active,
	output wire        dbg_ym_active,
	output wire        dbg_syt_main_act,
	output wire        dbg_syt_z80_act,
	output wire        dbg_audio_nonzero,
	// Main CPU data registers D6/D7 (for DBRA delay-loop diagnosis)
	output wire [31:0] dbg_d6,
	output wire [31:0] dbg_d7,
	// D0 (RAM test count), A0 (RAM test pointer), A1 (secondary pointer — usually area under test)
	output wire [31:0] dbg_d0,
	output wire [31:0] dbg_a0,
	output wire [31:0] dbg_a1,
	// Main RAM diag
	output reg  [15:0] dbg_ram_wr_cnt,
	output reg  [15:0] dbg_ram_rd_val,
	// Sub CPU PC
	output wire [23:0] dbg_sub_pc
);

// Forward declarations for ModelSim compatibility
wire        sel_scn0, sel_scn1;
wire        sel_scn0_ram, sel_scn1_ram;
wire        sel_scn0_ctrl, sel_scn1_ctrl;
wire        sel_pal0, sel_pal1;
wire        scn0_dack_n, scn1_dack_n;
wire        pal0_dack_n, pal1_dack_n;
wire [15:0] scn0_dout, scn1_dout;
wire [15:0] pal0_dout, pal1_dout;
wire        bus_raw_active;

// Forward decl per VRAM read data (Port A read-back chip MAME).
reg  [15:0] scn0_a_rdata, scn1_a_rdata;

// ── Forward declarations (needed by ModelSim) ────────────────────────────
wire [23:0] main_bus_addr;
wire        main_bus_asn;
wire        main_bus_rnw;
wire [1:0]  main_bus_dsn;
wire [15:0] main_bus_dout;
wire [15:0] main_bus_rdata;
wire        main_bus_cs;
wire        main_bus_busy;
wire  [1:0] main_bus_be;

// Sub-CPU rimosso (warriorb.cpp = single 68000). Tied-off i wire residui
// per non rompere referenze sparse nel codice legacy non ancora ripulito.
wire [23:0] sub_bus_addr  = 24'd0;
wire        sub_bus_asn   = 1'b1;
wire        sub_bus_rnw   = 1'b1;
wire [1:0]  sub_bus_dsn   = 2'b11;
wire [15:0] sub_bus_dout  = 16'd0;

// Main RAM
wire [15:0] main_ram_rdata;
wire        main_ram_rd, main_ram_wr;
wire [14:0] main_ram_addr;
wire [15:0] main_ram_wdata;

// Sub RAM tied 0 (modulo u_sub_ram lasciato per evitare rebuild di port-A,
// scrittura dead).

// Shared RAM main↔sub (rimossa). Tied 0 per main_shared_* (sub_shared non
// più referenziato).
wire [15:0] shared_main_rdata = 16'd0;
wire        shared_main_ready = 1'b1;
wire        main_shared_rd, main_shared_wr;
wire  [1:0] main_shared_be;
wire [14:0] main_shared_addr;
wire [15:0] main_shared_wdata;

// Sprite RAM (16 KB, dual-port: Port A=main, Port B=sub tied 0).
wire [15:0] sprite_main_rdata;
wire        sprite_main_ready;
wire        main_sprite_rd, main_sprite_wr;
wire  [1:0] main_sprite_be;
wire [12:0] main_sprite_addr;
wire [15:0] main_sprite_wdata;
// Sub sprite write tied 0 (port B inutilizzata).

// CPUA ctrl
wire        cpua_ctrl_wr;
wire [7:0]  cpua_ctrl_data;
reg  [7:0]  cpua_ctrl_reg;

// TC0140SYT sound comm (active low signals to chip)
wire        syt_cs_n, syt_wr_n, syt_rd_n, syt_a1;
wire  [3:0] syt_main_dout_w;

wire [15:0] main_e100_wdata;
wire        main_d000_rd, main_d000_wr;
wire [14:0] main_d000_addr;
wire [15:0] main_d000_wdata;
wire        main_palette_rd, main_palette_wr;
wire [10:0] main_palette_addr;
wire [15:0] main_palette_wdata;
wire  [1:0] main_ram_be;  // latched by memory map (see u_main_map.ram_be_o below)
wire        main_pc060ha_port_wr;
wire [7:0]  main_pc060ha_port_data;
wire        main_pc060ha_comm_wr;
wire [7:0]  main_pc060ha_comm_data;
reg  [7:0]  main_pc060ha_port_reg;
reg  [7:0]  main_pc060ha_comm_reg;
wire        main_iack;
wire [2:0]  main_ipl_n;
wire        pc060_snd_cs;
wire        pc060_snd_addr;
wire        pc060_snd_wr;
wire        pc060_snd_rd;
wire  [7:0] pc060_snd_wdata;
wire  [7:0] pc060_snd_rdata;
wire        pc060_snd_nmi_n;
wire        pc060_snd_reset;

// --- VBlank-synced pause (frame-aligned, F2 reference pattern) ---
// pause raw asincrono → paused_safe registrato che cambia SOLO al rising edge
// vblank. Sincronizza pause boundary su tutti i moduli (CPU cen, audio cen).
// Necessario per evitare race a metà bus cycle / scanline / DDR3 transaction.
wire vblank_area_top = (render_y >= (board_warriorb ? 9'd240 : 9'd232));
reg  vblank_prev_top;
reg  paused_safe_r;
always @(posedge clk) begin
	if (reset) begin
		vblank_prev_top <= 1'b0;
		paused_safe_r   <= 1'b0;
	end else begin
		vblank_prev_top <= vblank_area_top;
		// Aggiorna paused_safe solo al rising edge vblank (frame boundary)
		if (vblank_area_top && !vblank_prev_top)
			paused_safe_r <= pause;
	end
end
wire paused_safe = paused_safe_r;

// --- VBlank IRQ4 generation (cpp: set_vblank_int irq4_line_hold, both CPUs) ---

generate if (ENABLE_VBLANK_IRQ) begin : gen_vblank_irq
	// 60Hz VBlank from render_y: assert when render_y enters vblank region
	// V_ACTIVE=232 (d2d) o 240 (wb), runtime su board_warriorb
	wire vblank_area = (render_y >= (board_warriorb ? 9'd240 : 9'd232));
	reg  vblank_prev;
	reg  main_irq4_pending;

	always @(posedge clk) begin
		if (reset) begin
			vblank_prev       <= 1'b0;
			main_irq4_pending <= 1'b0;
		end else begin
			vblank_prev <= vblank_area;
			// Rising edge of vblank → assert IRQ4
			if (vblank_area && !vblank_prev) begin
				main_irq4_pending <= 1'b1;
			end
			// Clear on IACK
			if (main_iack) main_irq4_pending <= 1'b0;
		end
	end

	// IRQ4 = level 4 → ipl_n = ~3'd4 = 3'b011
	assign main_ipl_n = main_irq4_pending ? 3'b011 : 3'b111;
end else begin : gen_no_vblank
	assign main_ipl_n = 3'b111;
end
endgenerate

always @(posedge clk) begin
	if (reset)
		cpua_ctrl_reg <= 8'h00;  // Darius 1 pattern: sub CPU HELD in reset, Main releases it by writing $01 to $210000
	else if (cpua_ctrl_wr)
		cpua_ctrl_reg <= cpua_ctrl_data;
end

always @(posedge clk) begin
	if (reset)
		main_pc060ha_port_reg <= 8'h00;
	else if (main_pc060ha_port_wr)
		main_pc060ha_port_reg <= main_pc060ha_port_data;
end

always @(posedge clk) begin
	if (reset)
		main_pc060ha_comm_reg <= 8'h00;
	else if (main_pc060ha_comm_wr)
		main_pc060ha_comm_reg <= main_pc060ha_comm_data;
end

// PC060HA — real protocol handler (jtrastan_pc060 rewrite, single clock)
wire [7:0] pc060ha_main_rdata;

// Main 68K CS: active when accessing C00000-C00003
wire pc060_main_cs = ~main_bus_asn & main_bus_cs &
                     (main_bus_addr >= 24'hC00000) & (main_bus_addr <= 24'hC00003);
wire pc060_main_addr = main_bus_addr[1];  // 0=port (C00000), 1=comm (C00002)
wire pc060_main_wr = pc060_main_cs & ~main_bus_rnw;
wire pc060_main_rd = pc060_main_cs &  main_bus_rnw;

pc060ha_link u_pc060ha (
	.clk(clk),
	.reset(reset),
	// Main 68000 side
	.main_cs(pc060_main_cs),
	.main_addr(pc060_main_addr),
	.main_wr(pc060_main_wr),
	.main_rd(pc060_main_rd),
	.main_wdata(main_bus_dout[7:0]),
	.main_rdata(pc060ha_main_rdata),
	// Sound Z80 side
	.snd_cs(pc060_snd_cs),
	.snd_addr(pc060_snd_addr),
	.snd_wr(pc060_snd_wr),
	.snd_rd(pc060_snd_rd),
	.snd_wdata(pc060_snd_wdata),
	.snd_rdata(pc060_snd_rdata),
	// Control outputs
	.snd_nmi_n(pc060_snd_nmi_n),
	.snd_reset(pc060_snd_reset),
	.dbg_snd_full(),
	.dbg_main_full()
);

// Main CPU clock divider (96MHz / den)
// Default 0 = 12 MHz (Darius 2 originale MAME: XTAL 24MHz/2).
reg [7:0] main_clk_den;
always @(*) case (clk_sel)
	3'd0: main_clk_den = 8'd8;   // 96/8  = 12MHz (original MAME default)
	3'd1: main_clk_den = 8'd12;  // 96/12 = 8MHz  (underclock safe)
	3'd2: main_clk_den = 8'd6;   // 96/6  = 16MHz
	3'd3: main_clk_den = 8'd4;   // 96/4  = 24MHz
	3'd4: main_clk_den = 8'd3;   // 96/3  = 32MHz
	3'd5: main_clk_den = 8'd2;   // 96/2  = 48MHz
	default: main_clk_den = 8'd8;
endcase

// Sub CPU clock divider (96MHz / den)
// Default 0 = 12 MHz (Darius 2 originale MAME).
reg [7:0] sub_clk_den;
always @(*) case (sub_clk_sel)
	3'd0: sub_clk_den = 8'd8;   // 96/8  = 12MHz (original MAME default)
	3'd1: sub_clk_den = 8'd12;  // 96/12 = 8MHz  (underclock safe)
	3'd2: sub_clk_den = 8'd6;   // 96/6  = 16MHz
	3'd3: sub_clk_den = 8'd4;   // 96/4  = 24MHz
	3'd4: sub_clk_den = 8'd3;   // 96/3  = 32MHz
	3'd5: sub_clk_den = 8'd2;   // 96/2  = 48MHz
	default: sub_clk_den = 8'd8;
endcase

// Direct DTACK from SCN/palette chips.
// DACKn: chip not selected → 0, chip selected+busy → 1, chip selected+done → 0.
// When NO external chip is selected, ext_dtack_n must be 1 (inactive) so it
// doesn't interfere with jtframe DTACK for ROM/RAM/etc accesses.
// When any external chip IS selected, OR their DACKn (busy=1 blocks DTACK).
// ext_dtack_n: only the SELECTED chip's DACKn matters.
// Mux instead of OR eliminates risk from non-selected chip DACKn glitches.
wire any_ext_sel = sel_scn0 | sel_scn1 | sel_pal0 | sel_pal1;
// When a real chip is selected, use its DACKn.
// When NO chip is selected (gap address in SCN/PAL range), return 0 = instant DTACK
// so the CPU doesn't hang on unmapped addresses like $35FFFC.
// When outside SCN/PAL range entirely, return 1 (inactive, jtframe handles DTACK).
// SCN/PAL range — warriorb.cpp:
//   d2d : 0x200000-0x26FFFF SCN, 0x400000-0x42000F PAL
//   wb  : 0x300000-0x36FFFF SCN, 0x400000-0x42000F PAL
wire d2d_scnpal_rng = ((main_bus_addr >= 24'h200000) && (main_bus_addr <= 24'h26FFFF)) ||
                      ((main_bus_addr >= 24'h400000) && (main_bus_addr <= 24'h42000F));
wire wb_scnpal_rng  = ((main_bus_addr >= 24'h300000) && (main_bus_addr <= 24'h36FFFF)) ||
                      ((main_bus_addr >= 24'h400000) && (main_bus_addr <= 24'h42000F));
wire scn_pal_range = (board_warriorb ? wb_scnpal_rng : d2d_scnpal_rng) && ~main_bus_asn;
// --- VRAM DTACK generator: 2-cycle delay on Port A reads, 1-cycle on writes ---
// The VRAM BRAM has 1-cycle registered output. Data valid on N+2.
// We assert DTACK on N+1 so CPU samples data on N+2.
reg [2:0] vram_dtack_cnt;
reg scn_ram_active_prev;
wire scn_ram_active = sel_scn0_ram | sel_scn1_ram | sub_sel_scn0_ram;
always @(posedge clk) begin
    if (reset) begin
        vram_dtack_cnt <= 0;
        scn_ram_active_prev <= 0;
    end else begin
        scn_ram_active_prev <= scn_ram_active;
        if (!scn_ram_active_prev && scn_ram_active) begin
            vram_dtack_cnt <= 3'd2;  // start countdown
        end else if (vram_dtack_cnt != 0) begin
            vram_dtack_cnt <= vram_dtack_cnt - 1'd1;
        end
    end
end
// DTACK only after rising edge propagated (prev=1 guarantees at least 1 cycle elapsed
// since activation → BRAM registered rdata is valid). Prevents early DTACK that made
// CPU sample stale data and fail VRAM memtest.
// Back-pressure: se mirror FIFO full, NON asseriamo DTACK → CPU stalla finche'
// FIFO ha spazio (evita scritture VRAM perse silenziosamente sotto stress).
wire vram_dack_n = (scn_ram_active && scn_ram_active_prev && vram_dtack_cnt == 0 && ~mirror_full && ~mirrorx_full) ? 1'b0 : 1'b1;

// DTACK from TC chips for ctrl; from our VRAM logic for RAM range
wire main_ext_dtack_n = scn_ram_active ? vram_dack_n :
                         sel_scn0 ? scn0_dack_n :
                         sel_scn1 ? scn1_dack_n :
                         sel_pal0 ? pal0_dack_n :
                         sel_pal1 ? pal1_dack_n :
                         scn_pal_range ? 1'b0 :  // gap in SCN/PAL range: instant DTACK
                         1'b1;
// Mux read data: SCN0 RAM reads from CPU port, ctrl reads from chip
// Main RAM / Shared / Sprite / I/O → bus_rdata combinational inside memory map (Darius 1 style)
wire any_scn_sel = sel_scn0 | sel_scn1;
wire any_pal_sel = sel_pal0 | sel_pal1;
wire [15:0] main_bus_rdata_composite = sel_scn0_ram ? scn0_a_rdata :
                                        sel_scn1_ram ? scn1_a_rdata :
                                        sel_scn0_ctrl ? scn0_dout :
                                        sel_scn1_ctrl ? scn1_dout :
                                        sel_pal0 ? pal0_dout :
                                        sel_pal1 ? pal1_dout :
                                        main_bus_rdata;

darius2_cpu_node #(
	.CPU_ID(1'b0),
	.CORE_IMPL(MAIN_CORE_IMPL)
) u_main_cpu (
	.clk(clk),
	.reset(reset),
	.soft_reset(1'b0),
	.halt_n(~paused_safe),
	.clk_num(7'd1),
	.clk_den(main_clk_den),
	.ipl_n(main_ipl_n),
	.bus_din(main_bus_rdata_composite),
	.bus_cs(main_bus_cs),
	.bus_busy(main_bus_busy),
	.dev_br(1'b0),
	.bus_addr(main_bus_addr),
	.bus_asn(main_bus_asn),
	.bus_rnw(main_bus_rnw),
	.bus_dsn(main_bus_dsn),
	.bus_dout(main_bus_dout),
	.dbg_pc(dbg_main_pc),
	.dbg_fc(),
	.dbg_dtackn(dbg_dtack_n),
	.dbg_fave(),
	.dbg_fworst(),
	.iack(main_iack),
	.dbg_d6(dbg_d6),
	.dbg_d7(dbg_d7),
	.dbg_d0(dbg_d0),
	.dbg_a0(dbg_a0),
	.dbg_a1(dbg_a1)
);

// Sub-CPU rimossa: warriorb.cpp = single 68000 (no shared RAM, no sub).

darius2_maincpu_map_new u_main_map (
	.clk(clk), .reset(reset),
	.board_warriorb(board_warriorb),
	.bus_addr(main_bus_addr), .bus_asn(main_bus_asn),
	.bus_rnw(main_bus_rnw), .bus_dsn(main_bus_dsn),
	.bus_wdata(main_bus_dout), .bus_rdata(main_bus_rdata),
	.bus_cs(main_bus_cs), .bus_busy(main_bus_busy),
	.bus_be(main_bus_be),
	.rom_addr(main_rom_addr), .rom_req(main_rom_req),
	.rom_rdata(main_rom_rdata), .rom_ready(main_rom_ready),
	.ram_rd(main_ram_rd), .ram_wr(main_ram_wr),
	.ram_be_o(main_ram_be),  // latched byte enable
	.ram_addr_o(main_ram_addr), .ram_wdata(main_ram_wdata),
	.ram_rdata(main_ram_rdata),
	.shared_rd(main_shared_rd), .shared_wr(main_shared_wr),
	.shared_be_o(main_shared_be),
	.shared_addr(main_shared_addr), .shared_wdata(main_shared_wdata),
	.shared_rdata(shared_main_rdata), .shared_ready(shared_main_ready),
	.sprite_rd(main_sprite_rd), .sprite_wr(main_sprite_wr),
	.sprite_be_o(main_sprite_be),
	.sprite_addr(main_sprite_addr), .sprite_wdata(main_sprite_wdata),
	.sprite_rdata(sprite_main_rdata), .sprite_ready(sprite_main_ready),
	.ioc_cs(main_ioc_cs), .ioc_rnw(main_ioc_rnw),
	.ioc_addr1(main_ioc_addr1), .ioc_wdata(main_ioc_wdata),
	.ioc_rdata(main_ioc_rdata),
	.cpua_ctrl_wr(cpua_ctrl_wr), .cpua_ctrl_data(cpua_ctrl_data),
	.cpua_ctrl_q(cpua_ctrl_reg),
	.syt_cs_n(syt_cs_n), .syt_wr_n(syt_wr_n),
	.syt_rd_n(syt_rd_n), .syt_a1(syt_a1),
	.syt_main_dout(syt_main_dout_w),
	.vblank(1'b0),
	.ext_dtack_n(main_ext_dtack_n),
	.dbg_txn_state(dbg_txn_state)
);

// darius2_subcpu_map rimosso (sub-CPU non esiste in warriorb.cpp).

// --- TC0040IOC shared ---
wire        main_ioc_cs, main_ioc_rnw, main_ioc_addr1;
wire [7:0]  main_ioc_wdata, main_ioc_rdata;
tc0040ioc u_tc0040ioc (
	.clk(clk), .reset(reset),
	// TC0220IOC (darius2d) / TC0510NIO (warriorb): direct-mapped a $800000-$80000F.
	.main_cs(main_ioc_cs), .main_rnw(main_ioc_rnw),
	.main_addr_lo(main_bus_addr[3:1]),
	.main_wdata(main_ioc_wdata),
	.main_rdata(main_ioc_rdata),
	.p1_input(p1_input), .p2_input(p2_input),
	.system_input(system_input), .dsw_input(dsw_input)
);

// darius_shared_ram (shared main↔sub) rimossa: warriorb.cpp non ha sub-CPU,
// la mappa CPU non decoda quel range.

// Sprite RAM (16KB dual-port: Port A=main, Port B=sub tied 0).
darius_shared_ram #(
	.ADDR_WIDTH(13)
) u_sprite_ram
(
	.clk(clk),
	.main_rd(main_sprite_rd),
	.main_wr(main_sprite_wr),
	.main_be(main_sprite_be),
	.main_addr(main_sprite_addr),
	.main_wdata(main_sprite_wdata),
	.main_rdata(sprite_main_rdata),
	.main_ready(sprite_main_ready),
	.sub_rd(1'b0),
	.sub_wr(1'b0),
	.sub_be(2'b00),
	.sub_addr(13'd0),
	.sub_wdata(16'd0),
	.sub_rdata(),
	.sub_ready()
);

// Darius 1 legacy removed: FG RAM, FG mirror, FG portb mux (FG is inside TC0100SCN)

darius_local_ram #(
	.ADDR_WIDTH(15)
) u_main_ram (
	.clk(clk),
	.rd(main_ram_rd),
	.wr(main_ram_wr),
	.be(main_ram_be),
	.addr(main_ram_addr),
	.wdata(main_ram_wdata),
	.rdata(main_ram_rdata)
);

// --- Debug: Main RAM write counter + first read value at $0C0000 ---
// Counts every write to main RAM (regardless of address). Captures rdata
// the first time CPU reads from $0C0000 (addr==0) right after reset.
reg ram_rd_captured;
always @(posedge clk) begin
    if (reset) begin
        dbg_ram_wr_cnt  <= 16'd0;
        dbg_ram_rd_val  <= 16'hDEAD;
        ram_rd_captured <= 1'b0;
    end else begin
        if (main_ram_wr) dbg_ram_wr_cnt <= dbg_ram_wr_cnt + 16'd1;
        // Capture read value 2 cycles after rd (BRAM output registered with 1 cycle latency + 1 more for stability)
        // Simplest: capture when main_ram_rd and addr==0 (pulse), then hold
        if (main_ram_rd && main_ram_addr == 15'd0 && !ram_rd_captured) begin
            // Wait 2 cycles after rd to sample rdata, but here we just keep overwriting
            // until the first read completes; grab rdata 2 cycles later via pipe
            ram_rd_captured <= 1'b1;
        end
        if (ram_rd_captured && dbg_ram_rd_val == 16'hDEAD) begin
            dbg_ram_rd_val <= main_ram_rdata;
        end
    end
end

// Darius 1 legacy removed: E100 RAM (not in Darius 2 memory map)
// Darius 1 legacy removed: palette_ram (palette is inside TC0110PR)

// =====================================================================
// 3× TC0100SCN (tilemap controller) + 3× TC0110PR (palette)
// Replaces Darius 1 PC080SN panel_renderer + vram_arbiter + FG renderer
// =====================================================================
// Each TC0100SCN has its own VRAM (32K×16) and tile ROM interface.
// SCN[0] receives CPU writes and fans them out to all 3 (triple_screen_w).
// SCN[1] and SCN[2] have their own independent CPU write ports.
// Each TC0110PR has its own palette RAM (8K×16).

// --- Savestate bus (dummy — no savestate support yet) ---
ssbus_if scn_ssbus[3]();

// --- CPU → TC0100SCN chip selects ---
// From MAME darius2_master_map:
//   $280000-$293FFF → SCN[0] RAM (read + write-through to all 3)
//   $2A0000-$2A000F → SCN[0] ctrl
//   $2C0000-$2D3FFF → SCN[1] RAM
//   $2E0000-$2E000F → SCN[1] ctrl
//   $300000-$313FFF → SCN[2] RAM
//   $320000-$32000F → SCN[2] ctrl
// bus_raw_active: CPU is driving the bus (AS asserted), independent of memory map bus_cs.
// The memory map sets bus_cs=0 for SCN/palette ranges (handled externally), so we
// must NOT use main_bus_cs for the SCN decode.
// CS chip gated on both ASn asserted AND at least one DSn asserted.
// Without DSn check, SCEn↓ edge arrives before UDSn/LDSn are valid → chip
// latches WEL/WEH from de-asserted DSn → write lost (TC0110PR palette memtest).
// jtframe dtack model says DSn can lag ASn by one cycle.
assign bus_raw_active = ~main_bus_asn && (main_bus_dsn != 2'b11);
// SCN chip selects — warriorb.cpp:
//   darius2d  : SCN0 0x200000+ ctrl 0x220000 ; SCN1 0x240000+ ctrl 0x260000
//   warriorb  : SCN0 0x300000+ ctrl 0x320000 ; SCN1 0x340000+ ctrl 0x360000
// Niente SCN2 (esiste solo nel chip 3 di ninjaw).

// darius2d decode
wire d2d_scn0_ram  = (main_bus_addr >= 24'h200000) && (main_bus_addr <= 24'h213FFF);
wire d2d_scn0_ctrl = (main_bus_addr >= 24'h220000) && (main_bus_addr <= 24'h22000F);
wire d2d_scn1_ram  = (main_bus_addr >= 24'h240000) && (main_bus_addr <= 24'h253FFF);
wire d2d_scn1_ctrl = (main_bus_addr >= 24'h260000) && (main_bus_addr <= 24'h26000F);

// warriorb decode
wire wb_scn0_ram  = (main_bus_addr >= 24'h300000) && (main_bus_addr <= 24'h313FFF);
wire wb_scn0_ctrl = (main_bus_addr >= 24'h320000) && (main_bus_addr <= 24'h32000F);
wire wb_scn1_ram  = (main_bus_addr >= 24'h340000) && (main_bus_addr <= 24'h353FFF);
wire wb_scn1_ctrl = (main_bus_addr >= 24'h360000) && (main_bus_addr <= 24'h36000F);

assign sel_scn0_ram  = bus_raw_active && (board_warriorb ? wb_scn0_ram  : d2d_scn0_ram);
assign sel_scn0_ctrl = bus_raw_active && (board_warriorb ? wb_scn0_ctrl : d2d_scn0_ctrl);
assign sel_scn1_ram  = bus_raw_active && (board_warriorb ? wb_scn1_ram  : d2d_scn1_ram);
assign sel_scn1_ctrl = bus_raw_active && (board_warriorb ? wb_scn1_ctrl : d2d_scn1_ctrl);

assign sel_scn0 = sel_scn0_ram | sel_scn0_ctrl;
assign sel_scn1 = sel_scn1_ram | sel_scn1_ctrl;

// TC0140SYT sound comm (MAME ninjaw_master_map):
//   0x220000-0x220001 = master_port_w  (MA1=0)
//   0x220002-0x220003 = master_comm_r/w (MA1=1)
wire sel_syt_main = bus_raw_active && (main_bus_addr[23:2] == 22'h088000);  // 0x220000-0x220003
wire syt_main_a1  = main_bus_addr[1];   // 0=port, 1=comm

// Sub CPU also accesses SCN[0] with write-through ($280000-$293FFF)
wire sub_raw_active = ~sub_bus_asn && (sub_bus_dsn != 2'b11);
wire sub_sel_scn0_ram = sub_raw_active && (sub_bus_addr >= 24'h280000) && (sub_bus_addr <= 24'h293FFF);
// Sub access to palette chips (Ninja Warriors slave map).
wire sub_sel_pal0 = sub_raw_active && (sub_bus_addr >= 24'h340000) && (sub_bus_addr <= 24'h340007);
wire sub_sel_pal1 = sub_raw_active && (sub_bus_addr >= 24'h350000) && (sub_bus_addr <= 24'h350007);
wire sub_any_pal  = sub_sel_pal0 | sub_sel_pal1;

// Main/Sub mux for SCN[0] — Main has priority
wire main_wants_scn0 = sel_scn0;
wire sub_wants_scn0  = sub_sel_scn0_ram;
wire main_has_scn0   = main_wants_scn0;  // Main always wins
wire sub_has_scn0    = sub_wants_scn0 & ~main_wants_scn0;  // Sub only when Main idle

// Write-through: active when EITHER CPU writes to SCN[0] RAM
wire scn0_write_through = (sel_scn0_ram & ~main_bus_rnw) |
                           (sub_has_scn0 & ~sub_bus_rnw);

// Muxed signals to TC0100SCN[0] CPU interface
// VA[17:0] = bus_addr[17:0]: works because chip selects are on 256K boundaries
// $280000[17:0]=0 (RAM, VA[17]=0), $2A0000[17:0]=$20000 (ctrl, VA[17]=1) ✓
wire [17:0] scn0_va   = sub_has_scn0 ? sub_bus_addr[17:0]  : main_bus_addr[17:0];
wire [15:0] scn0_din  = sub_has_scn0 ? sub_bus_dout         : main_bus_dout;
wire [1:0]  scn0_dsn  = sub_has_scn0 ? sub_bus_dsn          : main_bus_dsn;
wire        scn0_rnw  = sub_has_scn0 ? sub_bus_rnw          : main_bus_rnw;
wire scn0_cs   = main_has_scn0 | sub_has_scn0;

// SCN[1] only accessed by Main directly (chip 3 rimosso)
wire [17:0] scn1_va = main_bus_addr[17:0];

// SCN chip selects — CPU accesses VRAM directly via Port A now.
// Chip CS only for CTRL register access ($2A0xxx, $2E0xxx).
wire scn0_cs_n = ~sel_scn0_ctrl;
wire scn1_cs_n = ~sel_scn1_ctrl;

// (DTACK/data signals already forward-declared)

// --- Clock enables ---
// Darius 2 master crystal: 26.686 MHz → TC0100SCN pixel clock = 26.686/2 = 13.343 MHz
// Our system clock: 96 MHz → ce_13m = 96 * 5/36 ≈ 13.33 MHz
// ce_6m = 13.33/2 ≈ 6.67 MHz
wire ce_6m, ce_13m;
jtframe_frac_cen #(.W(2)) u_video_cen (
	.clk(clk),
	.cen_in(1'b1),
	.n(10'd5),
	.m(10'd36),
	.cen({ce_6m, ce_13m}),
	.cenb()
);
// Rate alternativi SCN rimossi (Donlon-legacy). SCN ora usa ce_13m fisso.

// TC0100SCN ce_pixel: fisso a 13.33 MHz (MAME-accurate Darius 2 XTAL 26.686/2).
wire scn_ce_pixel = ce_13m;

// --- IHLD/IVLD generation for TC0100SCN ---
// IHLD: pulse at end of each horizontal line (rising edge triggers hcnt reset in TC0100SCN)
// IVLD: high at the IHLD pulse that starts the first line of the frame
// Generated from the compositor's render_x/render_y counters.
// IHLD: level signal from compositor HBlank.
// HBlank pulses every line (high during hblank, low during active), even during vblank.
// TC0100SCN detects rising edge internally (IHLD & ~prev_ihld) on ce_pixel.
// Using render_x >= 864 was WRONG: during vblank render_x is stuck at 900,
// so IHLD stayed high without pulsing → no vcnt increment → no frame sync.
wire scn_ihld = hblank_in;
wire scn_ivld = (render_y == 9'd0);      // high during first line

// --- SCN VRAM: 3× TRUE DUAL-PORT BRAM (32K×16 each) ---
// Port A = CPU (main bus): CPU reads/writes directly, no dependency on TC0100SCN FSM
// Port B = TC0100SCN chip: read-only for rendering
// This avoids the "memory test fails" bug where CPU read got TC0100SCN's current
// rendering address instead of CPU's target address.

// Port B signals (from TC0100SCN chip) — keep original names, chip drives them
// Fix #37: indirizzo esteso a 16 bit (era 15) per supportare wide mode:
// chip VA è 18-bit, SA è 15-bit + SCE0n/SCE1n per discriminare 2 SRAM.
// Qui unificato in scn*_ram_full_addr[15:0] dove bit[15] = ~SCE0n (1 = extra SRAM).
// BRAM principale 32K word ($00000-$0FFFF), BRAM extra 8K word ($10000-$13FFF).
wire [14:0] scn0_ram_addr, scn1_ram_addr;
wire [15:0] scn0_ram_din,  scn1_ram_din;
reg  [15:0] scn0_ram_dout, scn1_ram_dout;
wire        scn0_we_hi, scn1_we_hi;
wire        scn0_we_lo, scn1_we_lo;
wire        scn0_sce0n, scn1_sce0n;  // 0 = SRAM principale, 1 = extra
// full 16-bit ram addr seen by VRAM: MSB = extra-SRAM selector (1=extra)
// BUG FIX: scn0_sce0n=0 → main (mux selects main when bit15=0).
// Previously `{~scn0_sce0n, ...}` selected EXT for main access. Inverted.
wire [15:0] scn0_ram_full_addr = {scn0_sce0n, scn0_ram_addr};
wire [15:0] scn1_ram_full_addr = {scn1_sce0n, scn1_ram_addr};

// Port A signals (CPU side) — driven directly from CPU bus (skip TC0100SCN)
// VRAM SCN è una sola BRAM fisica, con alias su 3 range ($280000/$2C/$30).
// Per WRITE la BRAM deve ricevere i dati da qualsiasi dei 3 range → include
// tutti e 3 i sel nel cpu_active (altrimenti memtest CUSTOM2/CUSTOM3 fallisce:
// scrittura $2C0000 non arriva, read ritorna 0000).
// NOTA: questo fa sì che i 3 range siano alias della stessa BRAM. Il gioco
// vede 3 schermi con stesso tilemap + scroll separato per chip — design-limit.
wire scn0_cpu_main_active = sel_scn0_ram | sel_scn1_ram;
wire scn0_cpu_sub_active  = sub_sel_scn0_ram & ~scn0_cpu_main_active;
wire scn0_cpu_active      = scn0_cpu_main_active | scn0_cpu_sub_active;

// Fix #37: CPU address esteso a 16 bit. bus_addr[16] distingue SRAM principale (=0)
// da extra ($290000-$293FFF → bus_addr[16]=1). Mappa:
//   CPU $280000-$28FFFF → addr[15:1]=0-$7FFF, bit[16]=0 → BRAM principale
//   CPU $290000-$293FFF → addr[15:1]=0-$1FFF, bit[16]=1 → BRAM extra
// Nota: il range $28000-$293FFF è 40KB word. Nostra BRAM extra è 8K word (copre $290000-$293FFF).
// Forward declaration (ModelSim requires — Quartus accepts either order).
wire main_writethrough_scn0;
wire sub_writethrough_scn0;

wire [15:0] scn0_a_addr_c  = scn0_cpu_sub_active ? sub_bus_addr[16:1] : main_bus_addr[16:1];
wire [15:0] scn0_a_wdata_c = scn0_cpu_sub_active ? sub_bus_dout       : main_bus_dout;
wire [15:0] scn1_a_addr_c  = sub_writethrough_scn0 & ~main_writethrough_scn0
                              ? sub_bus_addr[16:1]  : main_bus_addr[16:1];
wire [15:0] scn1_a_wdata_c = sub_writethrough_scn0 & ~main_writethrough_scn0
                              ? sub_bus_dout        : main_bus_dout;
// Write trigger: gated on DSn asserted (same bug as main RAM — DSn de-assert
// could drop BE to 00 and lose the write). One-shot via trigger latch.
wire scn0_wr_req = scn0_cpu_active &
                   (scn0_cpu_sub_active ? (~sub_bus_rnw  & (sub_bus_dsn  != 2'b11))
                                        : (~main_bus_rnw & (main_bus_dsn != 2'b11)));
// Fix #36: triple_screen_w writethrough (MAME ninjaw_state::tc0100scn_triple_screen_w).
// Per MAME ninjaw.cpp:655-660, scritture CPU a $280000-$293FFF (range SCN0) sono
// replicate SIMULTANEAMENTE sui TC0100SCN. Vale per main E sub.
assign main_writethrough_scn0 = sel_scn0_ram & ~main_bus_rnw & (main_bus_dsn != 2'b11);
assign sub_writethrough_scn0  = sub_sel_scn0_ram & ~sub_bus_rnw & (sub_bus_dsn != 2'b11);
wire scn1_wr_req = (sel_scn1_ram & ~main_bus_rnw & (main_bus_dsn != 2'b11))
                 | main_writethrough_scn0 | sub_writethrough_scn0;

// Latch write-time signals so BE/addr/wdata stay stable until write completes,
// and one-shot the write pulse so it doesn't repeat as DSn bounces.
// Fix #37: addr ora 16 bit (MSB = extra-SRAM selector).
reg  [15:0] scn0_a_addr_l,  scn1_a_addr_l;
reg  [15:0] scn0_a_wdata_l, scn1_a_wdata_l;
reg   [1:0] scn0_a_be_l,    scn1_a_be_l;
reg         scn0_a_wr_l,    scn1_a_wr_l;

// Edge detection sui wr_req per garantire che ogni transizione 0→1 produca
// UNA sola write, indipendentemente da quanto resta alto wr_req.
reg scn0_wr_req_prev = 1'b0, scn1_wr_req_prev = 1'b0;
wire scn0_wr_rising = scn0_wr_req & ~scn0_wr_req_prev;
wire scn1_wr_rising = scn1_wr_req & ~scn1_wr_req_prev;

always @(posedge clk) begin
	// Default: pulse goes low
	scn0_a_wr_l <= 1'b0;
	scn1_a_wr_l <= 1'b0;

	scn0_wr_req_prev <= scn0_wr_req;
	scn1_wr_req_prev <= scn1_wr_req;

	// SCN0 — edge detect uniforme a SCN1 (fix asimmetria pulse).
	if (scn0_wr_rising) begin
		scn0_a_addr_l  <= scn0_a_addr_c;
		scn0_a_wdata_l <= scn0_a_wdata_c;
		scn0_a_be_l    <= scn0_cpu_sub_active ? ~sub_bus_dsn : ~main_bus_dsn;
		scn0_a_wr_l    <= 1'b1;
	end

	// SCN1 (Fix #36: writethrough also from SCN0 main/sub writes)
	if (scn1_wr_rising) begin
		scn1_a_addr_l  <= scn1_a_addr_c;
		scn1_a_wdata_l <= scn1_a_wdata_c;
		scn1_a_be_l    <= sub_writethrough_scn0 & ~main_writethrough_scn0
		                   ? ~sub_bus_dsn : ~main_bus_dsn;
		scn1_a_wr_l    <= 1'b1;
	end
end

// Effective Port A signals driven into BRAM (16-bit addr now):
// - Write path uses latched addr/wdata/be/wr (1-cycle pulse per transaction)
// - Read path uses combinatorial addr (wr=0 means address mux reads-through)
wire [15:0] scn0_a_addr  = scn0_a_wr_l ? scn0_a_addr_l  : scn0_a_addr_c;
wire [15:0] scn0_a_wdata = scn0_a_wdata_l;
wire  [1:0] scn0_a_be    = scn0_a_be_l;
wire        scn0_a_wr    = scn0_a_wr_l;

wire [15:0] scn1_a_addr  = scn1_a_wr_l ? scn1_a_addr_l  : scn1_a_addr_c;
wire [15:0] scn1_a_wdata = scn1_a_wdata_l;
wire  [1:0] scn1_a_be    = scn1_a_be_l;
wire        scn1_a_wr    = scn1_a_wr_l;

// =====================================================================
// Fix #37: VRAM split in principale 32K word (SRAM0) + extra 8K word (SRAM1).
// MAME TC0100SCN wide mode: 0x00000-0x0FFFF = SCE0 (64KB = 32K word),
//                           0x10000-0x13FFF = SCE1 (16KB = 8K word).
// Bit [15] del CPU address o bit [16] del chip ram_addr seleziona quale.
// =====================================================================

// Fix #37 v3: BRAM inferenza in 2 always separati per ogni array (port A + port B).
// Quartus così inferisce true dual-port M10K standard (minimo packing).
// SRAM principale 32K word + SRAM extra 8K word per SCN wide mode.
// CPU (port A) = R/W. Chip rendering (port B) = R only.

// --- SCN MAIN SRAM (condivisa SCN0/SCN1/SCN2) ---
// Primario: Port A = CPU R/W. Port B non usata.
// Mirror:   Port A = CPU write only (no read). Port B = arbiter chip (read).
// Il mirror elimina la race Port A/Port B: nessuna CPU read sul mirror →
// nessuna collisione con il chip read su Port B.
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn0_vram_hi  [0:32767];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn0_vram_lo  [0:32767];
// VRAM dedicata SCN1 (warriorb dual screen): CPU writethrough scrive
// parallelo su scn0 e scn1. Ogni chip ha la sua Port B renderer dedicata.
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn1_vram_hi  [0:32767];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn1_vram_lo  [0:32767];
// Mirror: scrittura gated con FIFO 1-slot per evitare collisioni Port A
// (CPU write) vs Port B (chip read) nello stesso clk stessa addr.
(* ramstyle = "M10K" *) reg [7:0] scn0_vram_mirror_hi [0:32767];
(* ramstyle = "M10K" *) reg [7:0] scn0_vram_mirror_lo [0:32767];
(* ramstyle = "M10K" *) reg [7:0] scn1_vram_mirror_hi [0:32767];
(* ramstyle = "M10K" *) reg [7:0] scn1_vram_mirror_lo [0:32767];
reg [15:0] scn0_a_rdata_main;

// FIFO 2-slot in FF per write mirror (main). Slot 0 = head (pop da qui),
// slot 1 = next (shift su slot 0 quando pop). Push entra nel primo slot libero.
reg [14:0] mirror_wr_addr_q [0:1];
reg [15:0] mirror_wr_data_q [0:1];
reg [1:0]  mirror_wr_be_q   [0:1];
reg [1:0]  mirror_wr_valid;  // [0]=head, [1]=next

// Collisione head con Port B read corrente: 2 chip leggono in parallelo,
// collision se uno dei due tocca l'addr di pop in range main.
wire mirror_head_collision = mirror_wr_valid[0] && (
       (~scn_m0_vram_b_addr[15] && (scn_m0_vram_b_addr[14:0] == mirror_wr_addr_q[0]))
    || (~scn_m1_vram_b_addr[15] && (scn_m1_vram_b_addr[14:0] == mirror_wr_addr_q[0]))
);
wire mirror_do_pop = mirror_wr_valid[0] && ~mirror_head_collision;
wire mirror_full  = &mirror_wr_valid;
wire mirror_push  = scn0_a_wr && ~scn0_a_addr[15] && ~mirror_full;

always @(posedge clk) begin
	// Write al mirror quando pop possibile — entrambi i mirror in parallelo (scn0+scn1)
	if (mirror_do_pop && mirror_wr_be_q[0][1]) begin
		scn0_vram_mirror_hi[mirror_wr_addr_q[0]] <= mirror_wr_data_q[0][15:8];
		scn1_vram_mirror_hi[mirror_wr_addr_q[0]] <= mirror_wr_data_q[0][15:8];
	end
	if (mirror_do_pop && mirror_wr_be_q[0][0]) begin
		scn0_vram_mirror_lo[mirror_wr_addr_q[0]] <= mirror_wr_data_q[0][7:0];
		scn1_vram_mirror_lo[mirror_wr_addr_q[0]] <= mirror_wr_data_q[0][7:0];
	end

	// Gestione slot: 4 casi (pop, push, push+pop, nessuno)
	case ({mirror_push, mirror_do_pop})
		2'b00: ; // nop
		2'b01: begin
			// Solo pop: shift slot 1 → 0
			mirror_wr_addr_q[0] <= mirror_wr_addr_q[1];
			mirror_wr_data_q[0] <= mirror_wr_data_q[1];
			mirror_wr_be_q[0]   <= mirror_wr_be_q[1];
			mirror_wr_valid[0]  <= mirror_wr_valid[1];
			mirror_wr_valid[1]  <= 1'b0;
		end
		2'b10: begin
			// Solo push: slot 0 se libero, altrimenti slot 1
			if (~mirror_wr_valid[0]) begin
				mirror_wr_addr_q[0] <= scn0_a_addr[14:0];
				mirror_wr_data_q[0] <= scn0_a_wdata;
				mirror_wr_be_q[0]   <= scn0_a_be;
				mirror_wr_valid[0]  <= 1'b1;
			end else begin
				mirror_wr_addr_q[1] <= scn0_a_addr[14:0];
				mirror_wr_data_q[1] <= scn0_a_wdata;
				mirror_wr_be_q[1]   <= scn0_a_be;
				mirror_wr_valid[1]  <= 1'b1;
			end
		end
		2'b11: begin
			// Push + pop: shift + push in slot 1
			mirror_wr_addr_q[0] <= mirror_wr_addr_q[1];
			mirror_wr_data_q[0] <= mirror_wr_data_q[1];
			mirror_wr_be_q[0]   <= mirror_wr_be_q[1];
			mirror_wr_valid[0]  <= mirror_wr_valid[1];
			if (mirror_wr_valid[1]) begin
				// Nuova push va in slot 1 (slot 0 ora occupato dallo shift)
				mirror_wr_addr_q[1] <= scn0_a_addr[14:0];
				mirror_wr_data_q[1] <= scn0_a_wdata;
				mirror_wr_be_q[1]   <= scn0_a_be;
				mirror_wr_valid[1]  <= 1'b1;
			end else begin
				// Slot 1 era vuoto, nuova push va in slot 0 (già shiftato libero)
				mirror_wr_addr_q[0] <= scn0_a_addr[14:0];
				mirror_wr_data_q[0] <= scn0_a_wdata;
				mirror_wr_be_q[0]   <= scn0_a_be;
				mirror_wr_valid[0]  <= 1'b1;
				mirror_wr_valid[1]  <= 1'b0;
			end
		end
	endcase

	// VRAM primaria (Port A CPU): write parallelo scn0+scn1, lettura CPU readback da scn0
	if (scn0_a_wr && ~scn0_a_addr[15] && scn0_a_be[1]) begin
		scn0_vram_hi[scn0_a_addr[14:0]] <= scn0_a_wdata[15:8];
		scn1_vram_hi[scn0_a_addr[14:0]] <= scn0_a_wdata[15:8];
	end
	if (scn0_a_wr && ~scn0_a_addr[15] && scn0_a_be[0]) begin
		scn0_vram_lo[scn0_a_addr[14:0]] <= scn0_a_wdata[7:0];
		scn1_vram_lo[scn0_a_addr[14:0]] <= scn0_a_wdata[7:0];
	end

	scn0_a_rdata_main <= {scn0_vram_hi[scn0_a_addr[14:0]], scn0_vram_lo[scn0_a_addr[14:0]]};
end

// --- SCN EXTRA SRAM ---
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn0_vramx_hi [0:8191];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn0_vramx_lo [0:8191];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn1_vramx_hi [0:8191];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] scn1_vramx_lo [0:8191];
// Mirror extra: FIFO 1-slot gate collision (come main). Mirror per chip 0 + 1.
(* ramstyle = "M10K" *) reg [7:0] scn0_vramx_mirror_hi [0:8191];
(* ramstyle = "M10K" *) reg [7:0] scn0_vramx_mirror_lo [0:8191];
(* ramstyle = "M10K" *) reg [7:0] scn1_vramx_mirror_hi [0:8191];
(* ramstyle = "M10K" *) reg [7:0] scn1_vramx_mirror_lo [0:8191];
reg [15:0] scn0_a_rdata_ext;

// FIFO 2-slot in FF per write mirror extra (stesso pattern del main).
reg [12:0] mirrorx_wr_addr_q [0:1];
reg [15:0] mirrorx_wr_data_q [0:1];
reg [1:0]  mirrorx_wr_be_q   [0:1];
reg [1:0]  mirrorx_wr_valid;

wire mirrorx_head_collision = mirrorx_wr_valid[0] && (
       (scn_m0_vram_b_addr[15] && (scn_m0_vram_b_addr[12:0] == mirrorx_wr_addr_q[0]))
    || (scn_m1_vram_b_addr[15] && (scn_m1_vram_b_addr[12:0] == mirrorx_wr_addr_q[0]))
);
wire mirrorx_do_pop = mirrorx_wr_valid[0] && ~mirrorx_head_collision;
wire mirrorx_full   = &mirrorx_wr_valid;
wire mirrorx_push   = scn0_a_wr && scn0_a_addr[15] && ~mirrorx_full;

always @(posedge clk) begin
	if (mirrorx_do_pop && mirrorx_wr_be_q[0][1]) begin
		scn0_vramx_mirror_hi[mirrorx_wr_addr_q[0]] <= mirrorx_wr_data_q[0][15:8];
		scn1_vramx_mirror_hi[mirrorx_wr_addr_q[0]] <= mirrorx_wr_data_q[0][15:8];
	end
	if (mirrorx_do_pop && mirrorx_wr_be_q[0][0]) begin
		scn0_vramx_mirror_lo[mirrorx_wr_addr_q[0]] <= mirrorx_wr_data_q[0][7:0];
		scn1_vramx_mirror_lo[mirrorx_wr_addr_q[0]] <= mirrorx_wr_data_q[0][7:0];
	end

	case ({mirrorx_push, mirrorx_do_pop})
		2'b00: ;
		2'b01: begin
			mirrorx_wr_addr_q[0] <= mirrorx_wr_addr_q[1];
			mirrorx_wr_data_q[0] <= mirrorx_wr_data_q[1];
			mirrorx_wr_be_q[0]   <= mirrorx_wr_be_q[1];
			mirrorx_wr_valid[0]  <= mirrorx_wr_valid[1];
			mirrorx_wr_valid[1]  <= 1'b0;
		end
		2'b10: begin
			if (~mirrorx_wr_valid[0]) begin
				mirrorx_wr_addr_q[0] <= scn0_a_addr[12:0];
				mirrorx_wr_data_q[0] <= scn0_a_wdata;
				mirrorx_wr_be_q[0]   <= scn0_a_be;
				mirrorx_wr_valid[0]  <= 1'b1;
			end else begin
				mirrorx_wr_addr_q[1] <= scn0_a_addr[12:0];
				mirrorx_wr_data_q[1] <= scn0_a_wdata;
				mirrorx_wr_be_q[1]   <= scn0_a_be;
				mirrorx_wr_valid[1]  <= 1'b1;
			end
		end
		2'b11: begin
			mirrorx_wr_addr_q[0] <= mirrorx_wr_addr_q[1];
			mirrorx_wr_data_q[0] <= mirrorx_wr_data_q[1];
			mirrorx_wr_be_q[0]   <= mirrorx_wr_be_q[1];
			mirrorx_wr_valid[0]  <= mirrorx_wr_valid[1];
			if (mirrorx_wr_valid[1]) begin
				mirrorx_wr_addr_q[1] <= scn0_a_addr[12:0];
				mirrorx_wr_data_q[1] <= scn0_a_wdata;
				mirrorx_wr_be_q[1]   <= scn0_a_be;
				mirrorx_wr_valid[1]  <= 1'b1;
			end else begin
				mirrorx_wr_addr_q[0] <= scn0_a_addr[12:0];
				mirrorx_wr_data_q[0] <= scn0_a_wdata;
				mirrorx_wr_be_q[0]   <= scn0_a_be;
				mirrorx_wr_valid[0]  <= 1'b1;
				mirrorx_wr_valid[1]  <= 1'b0;
			end
		end
	endcase

	// VRAMX primaria (Port A CPU readback) — write parallelo scn0+scn1
	if (scn0_a_wr && scn0_a_addr[15] && scn0_a_be[1]) begin
		scn0_vramx_hi[scn0_a_addr[12:0]] <= scn0_a_wdata[15:8];
		scn1_vramx_hi[scn0_a_addr[12:0]] <= scn0_a_wdata[15:8];
	end
	if (scn0_a_wr && scn0_a_addr[15] && scn0_a_be[0]) begin
		scn0_vramx_lo[scn0_a_addr[12:0]] <= scn0_a_wdata[7:0];
		scn1_vramx_lo[scn0_a_addr[12:0]] <= scn0_a_wdata[7:0];
	end

	scn0_a_rdata_ext <= {scn0_vramx_hi[scn0_a_addr[12:0]], scn0_vramx_lo[scn0_a_addr[12:0]]};
end

// Port A CPU read: mux main/ext via addr MSB latched
reg scn0_a_addr_msb_l;
always @(posedge clk) scn0_a_addr_msb_l <= scn0_a_addr[15];
always @(*) scn0_a_rdata = scn0_a_addr_msb_l ? scn0_a_rdata_ext : scn0_a_rdata_main;

// =====================================================================
// VRAM SCN dedicata per chip: scn0 e scn1 hanno la propria VRAM/mirror.
// CPU writethrough scrive in parallelo su entrambi (stesso contenuto).
// Renderer di ogni chip legge dal proprio mirror tramite Port B dedicata.
//
// CPU read SCN1 range → ritorna scn0_a_rdata (entrambe le VRAM identiche).
// =====================================================================

// Ogni chip TC0100SCN ha la sua VRAM/mirror dedicata → cen=1 sempre, Port B
// indipendenti in parallelo. La FSM TC0100SCN ha wait state per 2 cicli BRAM
// latency (emit addr → BRAM registered T+1 → latch chip T+2).
wire scn_m0_cen = 1'b1;
wire scn_m1_cen = 1'b1;
wire scn_m2_cen = 1'b0;  // chip 3 rimosso

// 2 Port B registered read indipendenti, ognuno legge dal proprio mirror.
// MAME chip emette vram_b_addr[15:0] (bit 15 = main/ext selector).
reg [15:0] scn0_pb_dout_main_r, scn0_pb_dout_ext_r;
reg [15:0] scn1_pb_dout_main_r, scn1_pb_dout_ext_r;
always @(posedge clk) begin
	scn0_pb_dout_main_r <= {scn0_vram_mirror_hi [scn_m0_vram_b_addr[14:0]], scn0_vram_mirror_lo [scn_m0_vram_b_addr[14:0]]};
	scn0_pb_dout_ext_r  <= {scn0_vramx_mirror_hi[scn_m0_vram_b_addr[12:0]], scn0_vramx_mirror_lo[scn_m0_vram_b_addr[12:0]]};
	scn1_pb_dout_main_r <= {scn1_vram_mirror_hi [scn_m1_vram_b_addr[14:0]], scn1_vram_mirror_lo [scn_m1_vram_b_addr[14:0]]};
	scn1_pb_dout_ext_r  <= {scn1_vramx_mirror_hi[scn_m1_vram_b_addr[12:0]], scn1_vramx_mirror_lo[scn_m1_vram_b_addr[12:0]]};
end

// Address MSB ritardato 1 clk per allinearsi al dato BRAM registered.
reg scn0_pb_addr_msb_d, scn1_pb_addr_msb_d;
always @(posedge clk) begin
	scn0_pb_addr_msb_d <= scn_m0_vram_b_addr[15];
	scn1_pb_addr_msb_d <= scn_m1_vram_b_addr[15];
end
wire [15:0] scn0_pb_dout = scn0_pb_addr_msb_d ? scn0_pb_dout_ext_r : scn0_pb_dout_main_r;
wire [15:0] scn1_pb_dout = scn1_pb_addr_msb_d ? scn1_pb_dout_ext_r : scn1_pb_dout_main_r;

// Latch per-chip: legge direttamente da pb_dout (registered nel BRAM read).
// Latency totale = 2 cicli (emit addr T → registered T+1 → latch T+2),
// allineata ai wait state FSM tc0100scn_mame (S_*_RS0/RS1 → S_*_RS2).
wire [15:0] scn0_ram_dout_r = scn0_pb_dout;
wire [15:0] scn1_ram_dout_r = scn1_pb_dout;

// Bind SDin di ogni chip al proprio latch.
always @(*) scn0_ram_dout = scn0_ram_dout_r;
always @(*) scn1_ram_dout = scn1_ram_dout_r;

// CPU read SCN1 VRAM: stesso contenuto di SCN0 (writethrough).
always @(*) scn1_a_rdata = scn0_a_rdata;

// --- TC0100SCN tile ROM interface (3 channels → arbiter → SDRAM) ---
wire [20:0] scn0_rom_addr, scn1_rom_addr;
wire [31:0] scn0_rom_data, scn1_rom_data;
wire        scn0_rom_req,  scn1_rom_req;
wire        scn0_rom_ack,  scn1_rom_ack;

// --- TC0100SCN video output → TC0110PR ---
wire [14:0] scn0_sc, scn1_sc;


// --- Sync from SCN[0] (master) ---
wire scn0_hsyn, scn0_vsyn, scn0_hblo, scn0_vblo;

// =====================================================================
// MAME chip TC0100SCN (2× warriorb.cpp) — wire driver per Port A BRAM e
// segnali ausiliari ex-Donlon (tied 0/1'b1 dato che MAME non li espone).
// =====================================================================

// render_x per pannello (moved up da sotto: servono ai chip MAME e agli
// assign hcnt qui sotto. Stessa logica della dichiarazione sotto, ma
// anticipata per sintesi ModelSim-safe).
// Per-panel render_x. warriorb.cpp: 2 panel × 320 = 640 totali.
localparam [9:0] PANEL_W_TOP = 10'd320;
wire [9:0] render_x_panel0 = render_x;
wire [9:0] render_x_panel1 = render_x - PANEL_W_TOP;
wire [9:0] render_x_panel2 = 10'd0;  // unused, chip 3 silenziato

// CPU path: redirigi dout/dack dai chip MAME (CRITICO per CPU reads/DTACK).
assign scn0_dout    = scn_m0_cpu_dout;
assign scn1_dout    = scn_m1_cpu_dout;
assign scn0_dack_n  = scn_m0_cpu_dtack_n;
assign scn1_dack_n  = scn_m1_cpu_dtack_n;

// SC → palette (MAME chip emette SC diretto a render_x).
// In 2-screen mode (warriorb) the 3rd chip output is silenced — the
// chip itself stays synthesized so M10K count is identical, but the
// compositor sees no pixels for panel 2.
assign scn0_sc      = scn_m0_sc;
assign scn1_sc      = scn_m1_sc;

// Tile ROM interface → MAME chip
assign scn0_rom_addr = scn_m0_rom_addr;
assign scn1_rom_addr = scn_m1_rom_addr;
assign scn0_rom_req  = scn_m0_rom_req;
assign scn1_rom_req  = scn_m1_rom_req;

// Port B VRAM addr/we/din: chip MAME non usa SA/SDout/WE legacy; l'arbiter
// Port B è guidato da scn_m*_vram_b_addr (vedi mux scn_pb_addr più sotto).
// Questi wire Donlon sono tied-off a 0: nessun chip li guida più.
assign scn0_ram_addr = 15'd0;
assign scn1_ram_addr = 15'd0;
assign scn0_ram_din  = 16'd0;
assign scn1_ram_din  = 16'd0;
assign scn0_we_hi    = 1'b1;  // active-low WE: 1 = no write
assign scn1_we_hi    = 1'b1;
assign scn0_we_lo    = 1'b1;
assign scn1_we_lo    = 1'b1;
assign scn0_sce0n    = 1'b0;  // main selector (unused with chip MAME)
assign scn1_sce0n    = 1'b0;

// Sync output: TC0110PR li dichiara in port list ma non li usa nel body.
// Tie a costante (verificato in rtl/darius2/tc0110pr.sv).
assign scn0_hsyn = 1'b1;
assign scn0_vsyn = 1'b1;
assign scn0_hblo = 1'b1;
assign scn0_vblo = 1'b1;

// =====================================================================
// MAME-model TC0100SCN instances (3×) — PARALLEL with Donlon for now.
// Not yet wired to output. Used for sintax/resource verification in Step 2.
// In Step 3 Donlon will be disconnected and MAME will drive SC, rom_req, etc.
// =====================================================================

// PARALLELO: tutti e 3 i chip partono insieme su hblank rising.
// Sim Codex (tb_tc0100scn_3chip_schedule_current.sv):
//   cascata done0→go1→done1→go2: all_done=15512 clk (>2.5 linee — OVER BUDGET)
//   parallelo simultaneo:         all_done=5222 clk (dentro 6108 — OK)
// I 3 chip accedono BRAM VRAM separate via phase round-robin a clk pieno,
// nessun conflitto risorse → il go-chain era una precauzione inutile.
reg  prev_hblank_mame;
always @(posedge clk) prev_hblank_mame <= hblank_in;
wire hblank_rise_mame = hblank_in & ~prev_hblank_mame;

wire scn_m0_done, scn_m1_done;
wire scn_m0_active, scn_m1_active;
wire scn_m0_go = hblank_rise_mame;
wire scn_m1_go = hblank_rise_mame;

// MAME chip signals
wire [15:0] scn_m0_cpu_dout, scn_m1_cpu_dout;
wire        scn_m0_cpu_dtack_n, scn_m1_cpu_dtack_n;
wire [15:0] scn_m0_vram_a_addr, scn_m1_vram_a_addr;
wire [15:0] scn_m0_vram_a_wdata, scn_m1_vram_a_wdata;
wire  [1:0] scn_m0_vram_a_we, scn_m1_vram_a_we;
wire [15:0] scn_m0_vram_b_addr, scn_m1_vram_b_addr;
wire [15:0] scn_m2_vram_b_addr = 16'd0;  // arbiter port 2 (chip rimosso) tied 0
wire [20:0] scn_m0_rom_addr, scn_m1_rom_addr;
wire        scn_m0_rom_req, scn_m1_rom_req;
wire [14:0] scn_m0_sc, scn_m1_sc;

// TC0100SCN x_offset runtime override:
//   ninjaw    → 22 (compile-time param wins when input=0)
//   darius2d  → 4 (warriorb set_offsets(4,0))
//   warriorb  → 4
// scn_x_offset_runtime=0 → modulo SCN usa P_X_OFFSET=22 (default 3-screen)
// per entrambi i variant. Stesso behavior, niente shift.
wire signed [15:0] scn_x_offset_runtime = 16'sd0;

// Multiscr_xoffs chip 1: darius2d=0, warriorb=1 (shift orizzontale del 2°
// pannello). Chip 0 sempre 0 (-1 = "no override").
wire signed [15:0] scn1_mscr_runtime = board_warriorb ? 16'sd1 : 16'sd0;

tc0100scn_mame #(.P_X_OFFSET(16'sd22), .P_MULTISCR_XOFFS(16'sd0), .P_MULTISCR_HACK(1'b0)) u_scn_mame_0 (
	.clk(clk), .x_offset_runtime(scn_x_offset_runtime),
	.multiscr_xoffs_runtime(-16'sd1),  // no override
	.tile_code_wide(board_warriorb),  // 2MB tile ROM in warriorb (vs 1MB d2d)
	.board_warriorb(board_warriorb),
	.cen(scn_m0_cen), .cen_fast(1'b1), .reset(reset),
	// BUG FIX: main_bus_addr[17] vale 1 sia per VRAM extra (0x290000-0x293FFF)
	// sia per CTRL (0x2A0000). Il chip usa bit 17 come RAM/CTRL selector
	// → interpretava scritture VRAM extra come scritture CTRL, corrompendo
	// scroll/flip/wide registers. Fix: bit 17 = sel_scn0_ctrl esplicito.
	.cpu_addr({sel_scn0_ctrl, main_bus_addr[16:0]}),
	.cpu_din(main_bus_dout),
	.cpu_dout(scn_m0_cpu_dout),
	.cpu_rnw(main_bus_rnw),
	.cpu_dsn(main_bus_dsn),
	.cpu_cs(sel_scn0),
	.cpu_dtack_n(scn_m0_cpu_dtack_n),
	.vram_a_addr(scn_m0_vram_a_addr),
	.vram_a_wdata(scn_m0_vram_a_wdata),
	.vram_a_we(scn_m0_vram_a_we),
	.vram_a_rdata(scn0_a_rdata),    // CPU readback da Port A BRAM condivisa
	.vram_b_addr(scn_m0_vram_b_addr),
	.vram_b_rdata(scn0_ram_dout_r),  // renderer fetch da mirror Port B
	.rom_addr(scn_m0_rom_addr),
	.rom_data(scn0_rom_data),
	.rom_req(scn_m0_rom_req),
	.rom_ack(scn0_rom_ack),
	.SC(scn_m0_sc),
	.render_x(render_x_panel0), .render_y(render_y), .hblank(hblank_in),
	.go(scn_m0_go), .done(scn_m0_done), .active(scn_m0_active),
	.osd_layer_en(osd_tile_layer_en),
	.bg0_xoff_ext(l0_xoff), .bg0_yoff_ext(l0_yoff),
	.bg1_xoff_ext(l1_xoff), .bg1_yoff_ext(l1_yoff),
	.fg0_xoff_ext(fg_xoff), .fg0_yoff_ext(fg_yoff)
);

tc0100scn_mame #(.P_X_OFFSET(16'sd22), .P_MULTISCR_XOFFS(16'sd2), .P_MULTISCR_HACK(1'b1)) u_scn_mame_1 (
	.clk(clk), .x_offset_runtime(scn_x_offset_runtime),
	.multiscr_xoffs_runtime(scn1_mscr_runtime),
	.tile_code_wide(board_warriorb),
	.board_warriorb(board_warriorb),
	.cen(scn_m1_cen), .cen_fast(1'b1), .reset(reset),
	.cpu_addr({sel_scn1_ctrl, main_bus_addr[16:0]}),
	.cpu_din(main_bus_dout),
	.cpu_dout(scn_m1_cpu_dout),
	.cpu_rnw(main_bus_rnw),
	.cpu_dsn(main_bus_dsn),
	.cpu_cs(sel_scn1),
	.cpu_dtack_n(scn_m1_cpu_dtack_n),
	.vram_a_addr(scn_m1_vram_a_addr),
	.vram_a_wdata(scn_m1_vram_a_wdata),
	.vram_a_we(scn_m1_vram_a_we),
	.vram_a_rdata(scn1_a_rdata),
	.vram_b_addr(scn_m1_vram_b_addr),
	.vram_b_rdata(scn1_ram_dout_r),
	.rom_addr(scn_m1_rom_addr),
	.rom_data(scn1_rom_data),
	.rom_req(scn_m1_rom_req),
	.rom_ack(scn1_rom_ack),
	.SC(scn_m1_sc),
	.render_x(render_x_panel1), .render_y(render_y), .hblank(hblank_in),
	.go(scn_m1_go), .done(scn_m1_done), .active(scn_m1_active),
	.osd_layer_en(osd_tile_layer_en),
	.bg0_xoff_ext(l0_xoff), .bg0_yoff_ext(l0_yoff),
	.bg1_xoff_ext(l1_xoff), .bg1_yoff_ext(l1_yoff),
	.fg0_xoff_ext(fg_xoff), .fg0_yoff_ext(fg_yoff)
);

// u_scn_mame_2 (chip 3 ninjaw) rimosso: warriorb.cpp = 2 chip SCN.

// --- TC0110PR palette instances (3×, one per screen) ---
// Each TC0110PR has its own palette RAM (8K×16).
// CPU access via $340000/$350000/$360000 (4 registers each).
// Video input: SC[14:0] from TC0100SCN, OB[14:0] from sprite renderer.

// Palette chip selects — three variants:
//   darius2d / warriorb : PAL0 0x400000-7 ; PAL1 0x420000-7 (no PAL2)
wire d2dwb_pal0 = (main_bus_addr >= 24'h400000) && (main_bus_addr <= 24'h400007);
wire d2dwb_pal1 = (main_bus_addr >= 24'h420000) && (main_bus_addr <= 24'h420007);

assign sel_pal0 = bus_raw_active && d2dwb_pal0;
assign sel_pal1 = bus_raw_active && d2dwb_pal1;

// Sprite OB output (shared across all 3 screens).
// Driven by darius_sprite_renderer below.
wire [14:0] sprite_ob;

// Palette RAM: 3× 8K×16 (CA[12:0], CDin/CDout[15:0])
wire [12:0] pal0_ca, pal1_ca;
wire [12:0] pal2_ca   = 13'd0;
reg  [15:0] pal0_cdin, pal1_cdin;
wire [15:0] pal2_cdin = 16'd0;
wire [15:0] pal0_cdout, pal1_cdout;
wire [15:0] pal2_cdout = 16'd0;
wire        pal0_wel, pal0_weh, pal1_wel, pal1_weh;
wire        pal2_wel = 1'b1, pal2_weh = 1'b1;

// Palette RAM 0
// Gate WE during ioctl_download to avoid spurious writes before CPU is released.
// Write-through bypass on cdin: if writing this cycle, forward cdout to cdin so
// the CPU readback (TC0110PR Dout<=CDin) sees the value it just wrote instead of
// garbage from the no_rw_check same-cycle W+R collision on M10K.
wire pal0_weh_g = pal0_weh | ioctl_download;
wire pal0_wel_g = pal0_wel | ioctl_download;
// TRUE DUAL-PORT: Port A = chip (write + read-back CDin); Port B = video raw (read only).
// Two separate always blocks per array → Quartus infers true dual-port M10K.
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] pal0_ram_hi [0:4095];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] pal0_ram_lo [0:4095];
// Port A (chip) — write + CDin readback
always @(posedge clk) begin
	if (~pal0_weh_g) pal0_ram_hi[pal0_ca[11:0]] <= pal0_cdout[15:8];
	pal0_cdin[15:8] <= (~pal0_weh_g) ? pal0_cdout[15:8] : pal0_ram_hi[pal0_ca[11:0]];
end
always @(posedge clk) begin
	if (~pal0_wel_g) pal0_ram_lo[pal0_ca[11:0]] <= pal0_cdout[7:0];
	pal0_cdin[7:0]  <= (~pal0_wel_g) ? pal0_cdout[7:0]  : pal0_ram_lo[pal0_ca[11:0]];
end

// Palette RAM 1
wire pal1_weh_g = pal1_weh | ioctl_download;
wire pal1_wel_g = pal1_wel | ioctl_download;
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] pal1_ram_hi [0:4095];
(* ramstyle = "M10K,no_rw_check" *) reg [7:0] pal1_ram_lo [0:4095];
always @(posedge clk) begin
	if (~pal1_weh_g) pal1_ram_hi[pal1_ca[11:0]] <= pal1_cdout[15:8];
	pal1_cdin[15:8] <= (~pal1_weh_g) ? pal1_cdout[15:8] : pal1_ram_hi[pal1_ca[11:0]];
end
always @(posedge clk) begin
	if (~pal1_wel_g) pal1_ram_lo[pal1_ca[11:0]] <= pal1_cdout[7:0];
	pal1_cdin[7:0]  <= (~pal1_wel_g) ? pal1_cdout[7:0]  : pal1_ram_lo[pal1_ca[11:0]];
end

// Palette RAM 2 rimossa (era per chip 3 ninjaw).
// vid_pal_raw2 (linea sotto) leggerà 0 → r2_rgb = nero → mai mostrato
// perché compositor sceglie solo r0/r1 (panel_thr_2 < panel_thr_1 mai vero).

// CPU mux verso TC0110PR: main prioritario, sub serviti se main non accede.
// Ninjaw slave map accede palette $340000-$360007.
wire        pal_use_sub  = ~sel_pal0 && ~sel_pal1 && sub_any_pal;
wire [15:0] pal_din      = pal_use_sub ? sub_bus_dout : main_bus_dout;
wire [1:0]  pal_va       = pal_use_sub ? sub_bus_addr[2:1] : main_bus_addr[2:1];
wire        pal_rwn      = pal_use_sub ? sub_bus_rnw : main_bus_rnw;
wire [1:0]  pal_dsn      = pal_use_sub ? sub_bus_dsn : main_bus_dsn;
wire        pal_any_main = sel_pal0 | sel_pal1;
// SCEn per-chip = NOT(sel_main_pal_x OR sel_sub_pal_x) quando pal_use_sub seleziona
wire        pal0_scen    = ~(sel_pal0 | (pal_use_sub & sub_sel_pal0));
wire        pal1_scen    = ~(sel_pal1 | (pal_use_sub & sub_sel_pal1));

TC0110PR pal0 (
	.clk(clk), .ce_pixel(scn_ce_pixel),
	.Din(pal_din), .Dout(pal0_dout),
	.VA(pal_va), .RWn(pal_rwn),
	.UDSn(pal_dsn[1]), .LDSn(pal_dsn[0]),
	.SCEn(pal0_scen), .DACKn(pal0_dack_n),
	.HSYn(scn0_hsyn), .VSYn(scn0_vsyn),
	.SC(scn0_sc), .OB(sprite_ob),
	.CA(pal0_ca), .CDin(pal0_cdin), .CDout(pal0_cdout),
	.WELn(pal0_wel), .WEHn(pal0_weh)
);

TC0110PR pal1 (
	.clk(clk), .ce_pixel(scn_ce_pixel),
	.Din(pal_din), .Dout(pal1_dout),
	.VA(pal_va), .RWn(pal_rwn),
	.UDSn(pal_dsn[1]), .LDSn(pal_dsn[0]),
	.SCEn(pal1_scen), .DACKn(pal1_dack_n),
	.HSYn(scn0_hsyn), .VSYn(scn0_vsyn),
	.SC(scn1_sc), .OB(sprite_ob),
	.CA(pal1_ca), .CDin(pal1_cdin), .CDout(pal1_cdout),
	.WELn(pal1_wel), .WEHn(pal1_weh)
);

// pal2 (TC0110PR chip 3) rimossa: warriorb.cpp = 2 palette chip.

// --- Line buffer 13MHz→24MHz per TC0100SCN ---
// Il chip gira a ce_13m (320 pixel visibili in 24us). Compositor a ce_pix
// 24MHz. Line buffer ping-pong per disaccoppiare i domini.
// scn0_sc/scn1_sc emessi sincroni dai chip MAME → consumati direttamente dal
// compositor sotto. scn_line_buffer (Donlon-legacy ping-pong 13→24) rimosso.

// --- Palette lookup: BYPASS scn_line_buffer esterno (Donlon-legacy) ---
// Il chip MAME emette SC sincrono a render_x, NON serve ping-pong 13→24.
// Replica la logica sprite_wins del TC0110PR per blending corretto:
//   FG vince sempre
//   Sprite prio 0 vince su BG top (mid in MAME primask) e BG bottom
//   Sprite prio 1 vince solo su BG bottom (sotto BG top/mid)
// SC[14:13] encoding (da tc0100scn_mame.sv):
//   01 = FG, 11 = BG top, 10 = BG bottom, 00 = empty
wire spr_hit = sprite_ob[14];
wire spr_prio_low = sprite_ob[13];

function automatic sprite_wins_fn;
	input [14:0] sc;
	input        hit;
	input        prio_low;
	reg sc_is_fg, sc_is_top, sc_is_bot, sc_empty;
	begin
		sc_is_fg  = (sc[14:13] == 2'b01);
		sc_is_top = (sc[14:13] == 2'b11);
		sc_is_bot = (sc[14:13] == 2'b10);
		sc_empty  = (sc[14:13] == 2'b00);
		sprite_wins_fn = hit && !sc_is_fg &&
		                 (sc_empty || sc_is_bot || (sc_is_top && !prio_low));
	end
endfunction

wire spr_wins0 = sprite_wins_fn(scn0_sc, spr_hit, spr_prio_low);
wire spr_wins1 = sprite_wins_fn(scn1_sc, spr_hit, spr_prio_low);

wire [11:0] vid_pal_idx0 = spr_wins0 ? sprite_ob[11:0] : scn0_sc[11:0];
wire [11:0] vid_pal_idx1 = spr_wins1 ? sprite_ob[11:0] : scn1_sc[11:0];

// Calcolo combinatorio opaque/prio sul pixel CORRENTE (pre-registro).
// Vengono registrati SOTTO insieme a vid_pal_raw per restare in fase con rgb.
wire        r0_opaque_c = spr_wins0 ? 1'b1 : |scn0_sc[3:0];
wire        r1_opaque_c = spr_wins1 ? 1'b1 : |scn1_sc[3:0];
wire [1:0]  r0_prio_c = spr_wins0 ? (spr_prio_low ? 2'b10 : 2'b11) : scn0_sc[14:13];
wire [1:0]  r1_prio_c = spr_wins1 ? (spr_prio_low ? 2'b10 : 2'b11) : scn1_sc[14:13];

// Registro rgb lookup + opaque/prio INSIEME → evita mismatch 1-clock colore vs metadati.
reg [15:0] vid_pal_raw0, vid_pal_raw1;
reg        r0_opaque, r1_opaque;
reg  [1:0] r0_prio,   r1_prio;
always @(posedge clk) begin
	vid_pal_raw0 <= {pal0_ram_hi[vid_pal_idx0], pal0_ram_lo[vid_pal_idx0]};
	vid_pal_raw1 <= {pal1_ram_hi[vid_pal_idx1], pal1_ram_lo[vid_pal_idx1]};
	r0_opaque <= r0_opaque_c;
	r1_opaque <= r1_opaque_c;
	r0_prio   <= r0_prio_c;
	r1_prio   <= r1_prio_c;
end

// 15-bit → 24-bit RGB (xBBBBBGGGGGRRRRR)
wire [4:0] r0_r5 = vid_pal_raw0[4:0],   r0_g5 = vid_pal_raw0[9:5],   r0_b5 = vid_pal_raw0[14:10];
wire [4:0] r1_r5 = vid_pal_raw1[4:0],   r1_g5 = vid_pal_raw1[9:5],   r1_b5 = vid_pal_raw1[14:10];

wire [23:0] r0_rgb = {r0_r5, r0_r5[4:2], r0_g5, r0_g5[4:2], r0_b5, r0_b5[4:2]};
wire [23:0] r1_rgb = {r1_r5, r1_r5[4:2], r1_g5, r1_g5[4:2], r1_b5, r1_b5[4:2]};

// Per-renderer tile ROM interface (for tile_rom_arbiter compatibility).
// Warriorb: tile chip 1 e chip 2 hanno ROM diverse (d24-02/01 vs d24-07/08).
// In SDRAM stanno sequenziali: chip 0 a TILE_BASE..+2MB, chip 1 a +2MB..+4MB.
// Offset 2MB byte (0x200000) al rom_addr di scn1 quando warriorb.
// Darius2d ha tile chip 1 == chip 0 (stesso content), no offset.
wire [23:0] r0_tilerom_addr = {3'd0, scn0_rom_addr};
wire [23:0] r1_tilerom_addr = board_warriorb
                              ? ({3'd0, scn1_rom_addr} + 24'h200000)
                              : {3'd0, scn1_rom_addr};
wire        r0_tilerom_req = scn0_rom_req;
wire        r1_tilerom_req = scn1_rom_req;
wire [31:0] r0_tilerom_data, r1_tilerom_data;
wire        r0_tilerom_valid, r1_tilerom_valid;
assign scn0_rom_data = r0_tilerom_data;
assign scn1_rom_data = r1_tilerom_data;

// ROM ack toggle: registered, toggles when tile_rom_arbiter delivers valid data
reg scn0_rom_ack_r, scn1_rom_ack_r;
always @(posedge clk) begin
	if (reset) begin
		scn0_rom_ack_r <= 1'b0;
		scn1_rom_ack_r <= 1'b0;
	end else begin
		if (r0_tilerom_valid) scn0_rom_ack_r <= scn0_rom_req;
		if (r1_tilerom_valid) scn1_rom_ack_r <= scn1_rom_req;
	end
end
assign scn0_rom_ack = scn0_rom_ack_r;
assign scn1_rom_ack = scn1_rom_ack_r;

// Sprite renderer ROM interface
wire [23:0] sprite_romaddr;
wire        sprite_romreq;
wire [31:0] sprite_romdata;
wire        sprite_romvalid;

// Darius 1 legacy removed: FG palette, FG renderer (FG is inside TC0100SCN)
// Darius 1 legacy removed: sprite palette snooped copy (palette is inside TC0110PR)

// Stub FG outputs (FG is now inside TC0100SCN, output via palette)
assign fg_rgb = 24'd0;
assign fg_opaque = 1'b0;

// GFX ROM arbiter: 3 tile + 1 sprite -> 1 bridge Port0
// hblank threshold = current active width (864 ninjaw / 640 warriorb)
localparam [9:0] HBLANK_THRESHOLD = 10'd640;  // 2 panel × 320
tile_rom_arbiter u_tile_arb (
	.clk(clk), .reset(reset),
	.hblank(render_x >= HBLANK_THRESHOLD),
	.r0_req(r0_tilerom_req), .r0_addr(r0_tilerom_addr),
	.r0_data(r0_tilerom_data), .r0_valid(r0_tilerom_valid),
	.r1_req(r1_tilerom_req), .r1_addr(r1_tilerom_addr),
	.r1_data(r1_tilerom_data), .r1_valid(r1_tilerom_valid),
	// Client 2 scollegato (chip 3 TC0100SCN rimosso, ninjaw-only)
	.r2_req(1'b0), .r2_addr(24'd0),
	.r2_data(), .r2_valid(),
	// Sprite ora va su SDRAM port 3 dedicata (sprite_rom_cache + bridge_spr_*).
	// Client 3 dell'arbiter rimane scollegato per non rubare cicli a tile/FG.
	.r3_req(1'b0), .r3_addr(24'd0),
	.r3_data(), .r3_valid(),
	.r4_req(1'b0), .r4_addr(24'd0),
	.r4_data(), .r4_valid(),
	.tile_req(tilerom_req), .tile_addr(tilerom_addr),
	.tile_is_sprite(tilerom_is_sprite),
	.tile_is_text(tilerom_is_text),
	.tile_data(tilerom_data), .tile_valid(tilerom_valid)
);

// Sprite ROM cache → DDR3 port 4 (path dedicato sprite, libera SDRAM)
wire [27:0] sprite_ddr_rdaddr;
wire [31:0] sprite_ddr_dout;
wire        sprite_ddr_rd_req;
wire        sprite_ddr_rd_ack;

sprite_rom_cache u_spr_cache (
	.clk(clk), .reset(reset),
	.req_addr(sprite_romaddr),
	.req_pulse(sprite_romreq),
	.resp_data(sprite_romdata),
	.resp_valid(sprite_romvalid),
	.ddr_addr(sprite_ddr_rdaddr),
	.ddr_req(sprite_ddr_rd_req),
	.ddr_data(sprite_ddr_dout),
	.ddr_ack(sprite_ddr_rd_ack)
);

// =====================================================================
// Sprite ROM ioctl download → DDR3 (port 4 write via audio_top mux)
// =====================================================================
// Range MRA per variant (warriorb.cpp):
//   darius2d: main 1MB + Z80 128KB → sprite a 0x120000-0x31FFFF (2MB)
//   warriorb: main 2MB + Z80 128KB → sprite a 0x220000-0x61FFFF (4MB)
wire [26:0] sprite_dl_lo = board_warriorb ? 27'h220000 : 27'h120000;
wire [26:0] sprite_dl_sz = board_warriorb ? 27'h400000 : 27'h200000;
wire [26:0] sprite_dl_hi = sprite_dl_lo + sprite_dl_sz;
wire is_sprite_dl = ioctl_download && (ioctl_index == 16'd0)
                     && (ioctl_addr >= sprite_dl_lo) && (ioctl_addr < sprite_dl_hi);
reg  [27:0] spr_dl_waddr;
reg  [15:0] spr_dl_wdata;
reg         spr_dl_we_req;
wire        spr_dl_we_ack;
reg         ioctl_wr_prev_spr;
always @(posedge clk) begin
	ioctl_wr_prev_spr <= ioctl_wr;
	if (ioctl_wr && !ioctl_wr_prev_spr && is_sprite_dl) begin
		spr_dl_waddr <= 28'h0400000 + {1'b0, ioctl_addr - sprite_dl_lo};
		spr_dl_wdata <= ioctl_dout;
		spr_dl_we_req <= ~spr_dl_we_req;
	end
end

// Output mux: select panel based on render_x
// Tile-RGB mux per warriorb.cpp: 2 panel a 320 px (threshold 320).
// Oltre 320 → chip 1 (r1); panel 2 (r2) inutilizzato.
localparam [9:0] PANEL_THR_1 = 10'd320;

assign tile_rgb    = (render_x < PANEL_THR_1) ? r0_rgb    : r1_rgb;
assign tile_prio   = (render_x < PANEL_THR_1) ? r0_prio   : r1_prio;
assign tile_opaque = (render_x < PANEL_THR_1) ? r0_opaque : r1_opaque;


// =====================================================================
// Sprite renderer (palette now in TC0110PR, not snooped copy)
// =====================================================================
wire [10:0] sprite_pal_addr;  // driven by sprite renderer (unused in Darius 2, palette via TC0110PR)
wire [15:0] sprite_pal_data = 16'd0;  // stub — sprite gets color from TC0110PR not from snooped palette

darius_sprite_renderer u_sprite (
	.clk(clk), .reset(reset),
	.render_x(render_x), .render_y(render_y),
	.board_warriorb(board_warriorb),
	.x_offset(10'd0),  // wide-screen: sprites use raw sx, no panel offset needed
	// Sprite RAM writes qualificati (stessa semantica di u_sprite_ram)
	.main_sprite_wr(main_sprite_wr),
	.main_sprite_addr(main_sprite_addr),
	.main_sprite_wdata(main_sprite_wdata),
	.main_sprite_be(main_sprite_be),
	.sub_sprite_wr(1'b0),
	.sub_sprite_addr(13'd0),
	.sub_sprite_wdata(16'd0),
	.sub_sprite_be(2'b00),
	.spriterom_data(sprite_romdata), .spriterom_valid(sprite_romvalid),
	.spriterom_addr(sprite_romaddr), .spriterom_req(sprite_romreq),
	.spr_xoff(spr_xoff + 10'sd1), .spr_yoff(spr_yoff),
	.pal_data(sprite_pal_data), .pal_lookup_addr(sprite_pal_addr),
	.sprite_rgb(sprite_rgb), .sprite_prio(sprite_prio), .sprite_opaque(sprite_opaque),
	.sprite_ob(sprite_ob),
	.dbg_disp_word()
);

// =====================================================================
// Audio subsystem (Darius 2 / Ninja Warriors)
//   Z80 + YM2610 (jt10) + TC0140SYT
//   ROM Z80 128 KB cached da DDRAM, ADPCM A/B da DDRAM via bridge
// =====================================================================
darius2_audio_top u_audio (
	.clk(clk),
	.ddram_clk(DDRAM_CLK),
	.reset(reset),
	.pause(paused_safe),
	// Board variant
	.board_warriorb(board_warriorb),
	// ioctl
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait_audio),
	// Comunicazione main 68000 ↔ TC0140SYT
	.main_din(main_bus_dout[3:0]),  // byte LSB nibble basso (umask 0x00ff)
	.main_dout(syt_main_dout_w),
	// Segnali dal maincpu_map_new (registrati, gestiscono DTACK internamente)
	.main_a1(syt_a1),
	.main_cs_n(syt_cs_n),
	.main_wr_n(syt_wr_n),
	.main_rd_n(syt_rd_n),
	// DDRAM HPS pins
	.DDRAM_BUSY(DDRAM_BUSY),
	.DDRAM_BURSTCNT(DDRAM_BURSTCNT),
	.DDRAM_ADDR(DDRAM_ADDR),
	.DDRAM_DOUT(DDRAM_DOUT),
	.DDRAM_DOUT_READY(DDRAM_DOUT_READY),
	.DDRAM_RD(DDRAM_RD),
	.DDRAM_DIN(DDRAM_DIN),
	.DDRAM_BE(DDRAM_BE),
	.DDRAM_WE(DDRAM_WE),
	// Sprite ROM read/write port (DDR3 port 4)
	.spr_rdaddr(sprite_ddr_rdaddr),
	.spr_dout(sprite_ddr_dout),
	.spr_rd_req(sprite_ddr_rd_req),
	.spr_rd_ack(sprite_ddr_rd_ack),
	.spr_we_addr(spr_dl_waddr),
	.spr_we_data(spr_dl_wdata),
	.spr_we_req(spr_dl_we_req),
	.spr_we_ack(spr_dl_we_ack),
	// Audio out
	.audio_l(audio_l),
	.audio_r(audio_r),
	.osd_fm_vol(osd_fm_vol),
	.osd_adpcma_vol(osd_adpcma_vol),
	.osd_adpcmb_vol(osd_adpcmb_vol),
	.osd_psg_vol(osd_psg_vol),
	// Debug
	.dbg_z80_active(dbg_z80_active),
	.dbg_ym_active(dbg_ym_active),
	.dbg_syt_main_act(dbg_syt_main_act),
	.dbg_syt_z80_act(dbg_syt_z80_act),
	.dbg_audio_nonzero(dbg_audio_nonzero)
);

// =====================================================================
// Debug assignments (placed here so all signals are declared)
// =====================================================================
assign dbg_bus_addr    = main_bus_addr;
assign dbg_bus_busy    = main_bus_busy;
assign dbg_ext_dtack_n = main_ext_dtack_n;

reg [14:0] vid_dbg_sc_latch;
reg        vid_dbg_sc_seen;
reg        vid_dbg_trom_seen;
reg [15:0] vid_dbg_vram_latch;
reg        vid_dbg_vram_seen;
always @(posedge clk) begin
	if (reset) begin
		vid_dbg_sc_latch  <= 15'd0;
		vid_dbg_sc_seen   <= 1'b0;
		vid_dbg_trom_seen <= 1'b0;
		vid_dbg_vram_latch <= 16'd0;
		vid_dbg_vram_seen  <= 1'b0;
	end else begin
		// Latch first SC with non-zero pixel (SC[3:0]!=0 = opaque)
		if (|scn0_sc[3:0]) begin
			vid_dbg_sc_latch <= scn0_sc;
			vid_dbg_sc_seen  <= 1'b1;
		end else if (!vid_dbg_sc_seen && |scn0_sc) begin
			// Fallback: latch any non-zero SC if no opaque pixel seen yet
			vid_dbg_sc_latch <= scn0_sc;
		end
		if (scn0_rom_req) vid_dbg_trom_seen <= 1'b1;
		// Latch first non-zero tile code read from VRAM by TC0100SCN
		if (!vid_dbg_vram_seen && |scn0_ram_dout) begin
			vid_dbg_vram_latch <= scn0_ram_dout;
			vid_dbg_vram_seen  <= 1'b1;
		end
	end
end
// Count SCN0 CPU write events (CS asserted + write)
reg [15:0] vid_dbg_scn0_wr_cnt;
reg        vid_dbg_scn0_cs_prev;
always @(posedge clk) begin
	if (reset) begin
		vid_dbg_scn0_wr_cnt  <= 16'd0;
		vid_dbg_scn0_cs_prev <= 1'b1;
	end else begin
		vid_dbg_scn0_cs_prev <= scn0_cs_n;
		// Count falling edge of SCN0 CS with RW=0 (write)
		if (~scn0_cs_n & vid_dbg_scn0_cs_prev & ~scn0_rnw)
			vid_dbg_scn0_wr_cnt <= vid_dbg_scn0_wr_cnt + 1'd1;
	end
end

// Count vblank IRQ assertions
reg [15:0] vid_dbg_irq_cnt;
reg        vid_dbg_irq_prev;
always @(posedge clk) begin
	if (reset) begin
		vid_dbg_irq_cnt  <= 16'd0;
		vid_dbg_irq_prev <= 1'b0;
	end else begin
		vid_dbg_irq_prev <= gen_vblank_irq.main_irq4_pending;
		if (gen_vblank_irq.main_irq4_pending & ~vid_dbg_irq_prev)
			vid_dbg_irq_cnt <= vid_dbg_irq_cnt + 1'd1;
	end
end

assign dbg_scn0_sc          = vid_dbg_sc_latch;
// CW display: [15:8]=irq_count, [7:0]=iack_count
// If IRQ grows but IACK doesn't = CPU not acknowledging interrupts
reg [7:0] vid_dbg_iack_cnt;
reg       vid_dbg_iack_prev;
always @(posedge clk) begin
	if (reset) begin
		vid_dbg_iack_cnt  <= 8'd0;
		vid_dbg_iack_prev <= 1'b0;
	end else begin
		vid_dbg_iack_prev <= main_iack;
		if (main_iack & ~vid_dbg_iack_prev)
			vid_dbg_iack_cnt <= vid_dbg_iack_cnt + 1'd1;
	end
end
assign dbg_scn0_wr_cnt = {vid_dbg_irq_cnt[7:0], vid_dbg_iack_cnt};
assign dbg_scn0_sc_seen     = vid_dbg_sc_seen;
assign dbg_tilerom_req_seen = vid_dbg_trom_seen;

// dbg_d6/d7 are driven by the main cpu_node instance via its new output ports.
// See u_main_cpu port connections below.

endmodule

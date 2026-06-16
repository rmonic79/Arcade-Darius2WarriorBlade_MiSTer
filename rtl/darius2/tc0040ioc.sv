/*  This file is part of Darius2WarriorBlade_MiSTer.

    GPL-3.0.
    Author: Umberto Parisi (rmonic79)
    Version: 2.0  (warriorb.cpp only — TC0220IOC / TC0510NIO direct-mapped)
*/

// tc0040ioc — I/O controller per warriorb.cpp.
// Wrapper TC0220IOC (darius2d) e TC0510NIO (warriorb): entrambi direct-mapped,
// stessa interfaccia. 8 registri direttamente indirizzati da bus_addr[3:1].
//
// Read map (warriorb.cpp):
//   0x00: DSWA
//   0x01: DSWB
//   0x02: IN0 (player1 + coin/start)
//   0x03: IN1 (player2 joystick)
//   0x04: coin counters (regs[4])
//   0x07: IN2 (buttons + freeze)
// Write a 0x00 = watchdog reset (ignorato), 0x04 = coin counters.

module tc0040ioc
(
	input  wire        clk,
	input  wire        reset,

	// Main CPU access (single 68000)
	input  wire        main_cs,
	input  wire        main_rnw,
	input  wire  [2:0] main_addr_lo,   // bus_addr[3:1] = register index
	input  wire  [7:0] main_wdata,

	// Read data (combinational — same cycle as cs)
	output wire  [7:0] main_rdata,

	// Board inputs
	input  wire  [7:0] p1_input,
	input  wire  [7:0] p2_input,
	input  wire  [7:0] system_input,
	input  wire [15:0] dsw_input
);

// 8 writable register slots
reg [7:0] ioc_regs [0:7];

// Combinational read of selected port
function [7:0] ioc_read_fn;
	input [2:0] port;
	begin
		case (port)
			3'h0: ioc_read_fn = dsw_input[7:0];
			3'h1: ioc_read_fn = dsw_input[15:8];
			3'h2: ioc_read_fn = p1_input;
			3'h3: ioc_read_fn = p2_input;
			3'h4: ioc_read_fn = ioc_regs[4];
			3'h7: ioc_read_fn = system_input;
			default: ioc_read_fn = 8'hFF;
		endcase
	end
endfunction

assign main_rdata = ioc_read_fn(main_addr_lo);

// Direct-mapped writes
always @(posedge clk) begin
	if (reset) begin
		ioc_regs[0] <= 8'd0; ioc_regs[1] <= 8'd0;
		ioc_regs[2] <= 8'd0; ioc_regs[3] <= 8'd0;
		ioc_regs[4] <= 8'd0; ioc_regs[5] <= 8'd0;
		ioc_regs[6] <= 8'd0; ioc_regs[7] <= 8'd0;
	end else if (main_cs & ~main_rnw) begin
		ioc_regs[main_addr_lo] <= main_wdata;
	end
end

endmodule

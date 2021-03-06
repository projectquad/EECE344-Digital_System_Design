/*
 * NAME
 * ----
 *
 *   main.v - SPI slave, switch input, LED display
 *
 * DESCRIPTION
 * -----------
 *
 * This module takes input from input switches (in_sw) and
 * outputs them over the SPI (MISO pin).
 * And the input it receives over the SPI is written to the
 * external LEDs (led_ext).
 *
 * The following SPI settings used by this module:
 *
 *   MSB first
 *   CPOL = 0
 *   CPHA = 0
 *   SS_L (enable on low)
 *
 *  The slave select line (SS_L) is used in a somewhat unique way.
 *  On the cleared (enabled) to set (disabled) transition the
 *  new data is latched in to the register.
 *  This was done because in the other orientation it was impossible
 *  to determine when to initialize the data because ss_l was
 *  the same value when it is sampling/propagating.
 *  
 * AUTHOR
 * ------
 *
 * Jeremiah Mahler <jmmahler@gmail.com>
 *
 */

module main(
	input wire rst_l,
	input wire ss_l,
	input wire sclk,
	input wire mosi,
	output wire miso,
	output wire [7:0] led_ext,
	input wire [7:0] in_sw
	);

	GSR GSR_INST(.GSR(rst_l));

	// N is the last offset of data that is transferred.
	// Currently there are 8-bits (0 - 7).
	// This could be changed to support 16 bits
	// needed.
	parameter N=7;

	// provide user feedback for switch actuation
	wire [N:0] n_in_sw;  // negated version of in_sw, sw closed -> set
	assign n_in_sw = ~(in_sw);

	// read register and next read register
	reg [N:0] r_reg;
	wire [N:0] r_next;
	// write register, for storing received data
	reg [N:0] w_reg;

	// store the received data on the external led's
	assign led_ext = ~(w_reg);  // invert so 0 -> off, 1 -> on

	// ### main SPI control: sample, propagate ###

	assign r_next = {r_reg[N-1:0], mosi_sample};
	assign miso = r_reg[N] & ~(ss_l);

	// SAMPLE
	reg mosi_sample;
	always @(posedge sclk) begin
		mosi_sample <= mosi;
	end

	always @(negedge sclk or negedge rst_l) begin
		if (~rst_l) begin
			r_reg <= 8'b0;
			w_reg <= 8'b0;
		end else begin
			if (ss_l) begin
				// RESET
				// reset when sclk falls while ss_l is high (disabled)
				r_reg <= n_in_sw;  // switch input
				w_reg <= r_next; // update the write register with the last read
				// use r_next (not r_reg) so we don't miss the last mosi (SAMPLE)
			end else begin
				// PROPAGATE
				r_reg <= r_next;
				//w_reg <= w_reg;
			end
		end
	end
endmodule

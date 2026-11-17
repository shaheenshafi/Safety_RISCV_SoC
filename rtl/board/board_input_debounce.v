// -----------------------------------------------------------------------------
// Board input conditioner for one push button or slide switch
//
// 1. Two-flop synchronizer: the input is asynchronous to the SoC clock.
// 2. Debounce: the output level changes only after the synchronized input has
//    been different from it for 2^COUNTER_BITS consecutive clock cycles.
// 3. rise_o is a one-cycle pulse when the debounced level goes from 0 to 1.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module board_input_debounce #(
    parameter integer COUNTER_BITS = 19
) (
    input  wire clk_i,
    input  wire rst_ni,
    input  wire raw_i,
    output reg  level_o,
    output reg  rise_o
);

  (* ASYNC_REG = "TRUE" *) reg [1:0] sync_q;
  reg [COUNTER_BITS-1:0] count_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sync_q  <= 2'b00;
      count_q <= {COUNTER_BITS{1'b0}};
      level_o <= 1'b0;
      rise_o  <= 1'b0;
    end else begin
      sync_q <= {sync_q[0], raw_i};
      rise_o <= 1'b0;

      if (sync_q[1] == level_o) begin
        count_q <= {COUNTER_BITS{1'b0}};
      end else if (&count_q) begin
        level_o <= sync_q[1];
        rise_o  <= sync_q[1];
        count_q <= {COUNTER_BITS{1'b0}};
      end else begin
        count_q <= count_q + 1'b1;
      end
    end
  end

endmodule

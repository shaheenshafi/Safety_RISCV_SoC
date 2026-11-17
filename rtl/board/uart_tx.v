// -----------------------------------------------------------------------------
// UART transmitter, 8 data bits, no parity, 1 stop bit (8N1)
//
// A byte is accepted in a cycle where valid_i and ready_o are both high.
// Each bit is held on tx_o for CLKS_PER_BIT clock cycles.
// Example: 40 MHz / 115200 baud = 347 clock cycles per bit.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module uart_tx #(
    parameter integer CLKS_PER_BIT = 347
) (
    input  wire       clk_i,
    input  wire       rst_ni,

    input  wire [7:0] data_i,
    input  wire       valid_i,
    output wire       ready_o,

    output reg        tx_o
);

  localparam integer COUNT_WIDTH =
      (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;

  reg                   busy_q;
  reg [COUNT_WIDTH-1:0] clk_count_q;
  reg [3:0]             bit_index_q;
  // {stop bit, data[7:0], start bit}; transmitted least-significant bit first.
  reg [9:0]             shift_q;

  assign ready_o = !busy_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      busy_q      <= 1'b0;
      clk_count_q <= {COUNT_WIDTH{1'b0}};
      bit_index_q <= 4'd0;
      shift_q     <= 10'h3FF;
      tx_o        <= 1'b1;
    end else if (!busy_q) begin
      tx_o <= 1'b1;
      if (valid_i) begin
        shift_q     <= {1'b1, data_i, 1'b0};
        busy_q      <= 1'b1;
        clk_count_q <= {COUNT_WIDTH{1'b0}};
        bit_index_q <= 4'd0;
      end
    end else begin
      tx_o <= shift_q[0];
      if (clk_count_q == CLKS_PER_BIT - 1) begin
        clk_count_q <= {COUNT_WIDTH{1'b0}};
        shift_q     <= {1'b1, shift_q[9:1]};
        if (bit_index_q == 4'd9)
          busy_q <= 1'b0;
        else
          bit_index_q <= bit_index_q + 4'd1;
      end else begin
        clk_count_q <= clk_count_q + 1'b1;
      end
    end
  end

endmodule

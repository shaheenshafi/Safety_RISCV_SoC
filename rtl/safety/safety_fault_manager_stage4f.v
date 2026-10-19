`timescale 1ns/1ps

module safety_fault_manager_stage4f (
    input  wire       clk_i,
    input  wire       rst_ni,

    input  wire       dcls_instr_mismatch_i,
    input  wire       dcls_data_mismatch_i,
    input  wire       supervisor_fault_i,

    output reg        fault_latched_o,
    output reg        instr_fault_seen_o,
    output reg        data_fault_seen_o,
    output reg        supervisor_fault_seen_o,
    output reg  [7:0] fault_code_o,
    output wire       safe_state_req_o
);

  localparam [7:0] FAULT_NONE  = 8'h00;
  localparam [7:0] FAULT_INSTR = 8'h01;
  localparam [7:0] FAULT_DATA  = 8'h02;
  localparam [7:0] FAULT_SUPERVISOR = 8'h03;

  // A fault remains latched until reset.
  // Simultaneous fault priority: instruction, then data, then supervisor.
  // for the primary fault code; both diagnostic bits are still recorded.

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fault_latched_o    <= 1'b0;
      instr_fault_seen_o <= 1'b0;
      data_fault_seen_o       <= 1'b0;
      supervisor_fault_seen_o <= 1'b0;
      fault_code_o            <= FAULT_NONE;
    end else begin
      if (dcls_instr_mismatch_i || dcls_data_mismatch_i ||
          supervisor_fault_i) begin
        fault_latched_o <= 1'b1;

        if (dcls_instr_mismatch_i)
          instr_fault_seen_o <= 1'b1;

        if (dcls_data_mismatch_i)
          data_fault_seen_o <= 1'b1;
        if (supervisor_fault_i)
          supervisor_fault_seen_o <= 1'b1;

        if (!fault_latched_o) begin
          if (dcls_instr_mismatch_i)
            fault_code_o <= FAULT_INSTR;
          else if (dcls_data_mismatch_i)
            fault_code_o <= FAULT_DATA;
          else if (supervisor_fault_i)
            fault_code_o <= FAULT_SUPERVISOR;
        end
      end
    end
  end

  assign safe_state_req_o = fault_latched_o;

endmodule

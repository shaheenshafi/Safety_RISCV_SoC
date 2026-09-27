`timescale 1ns/1ps

module safety_riscv_soc_stage2 (
    input wire clk_i,
    input wire rst_ni
);

  // --------------------------------------------------------------------------
  // Core A observation signals
  // --------------------------------------------------------------------------

  wire        core_a_instr_req;
  wire [31:0] core_a_instr_addr;

  wire        core_a_data_req;
  wire        core_a_data_we;
  wire [3:0]  core_a_data_be;
  wire [31:0] core_a_data_addr;
  wire [31:0] core_a_data_wdata;

  // --------------------------------------------------------------------------
  // Core B observation signals
  // --------------------------------------------------------------------------

  wire        core_b_instr_req;
  wire [31:0] core_b_instr_addr;

  wire        core_b_data_req;
  wire        core_b_data_we;
  wire [3:0]  core_b_data_be;
  wire [31:0] core_b_data_addr;
  wire [31:0] core_b_data_wdata;

  // --------------------------------------------------------------------------
  // Core A
  //
  // Response-path fault injection is explicitly disabled in Stage-2.
  // Stage-2 is only responsible for proving two independent redundant
  // Ibex channels execute identically.
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1 core_a (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .core_response_fault_inject_enable_i (1'b0),
      .core_response_fault_inject_target_i (3'b111),
      .core_response_fault_inject_mask_i   (32'b0),

      .instr_req_o  (core_a_instr_req),
      .instr_addr_o (core_a_instr_addr),

      .data_req_o   (core_a_data_req),
      .data_we_o    (core_a_data_we),
      .data_be_o    (core_a_data_be),
      .data_addr_o  (core_a_data_addr),
      .data_wdata_o (core_a_data_wdata),

      // Response observation outputs are not required in Stage-2.
      .instr_rvalid_o (),
      .instr_rdata_o  (),
      .data_rvalid_o  (),
      .data_rdata_o   ()
  );

  // --------------------------------------------------------------------------
  // Core B
  //
  // Response-path fault injection is explicitly disabled in Stage-2.
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1 core_b (
      .clk_i (clk_i),
      .rst_ni(rst_ni),

      .core_response_fault_inject_enable_i (1'b0),
      .core_response_fault_inject_target_i (3'b111),
      .core_response_fault_inject_mask_i   (32'b0),

      .instr_req_o  (core_b_instr_req),
      .instr_addr_o (core_b_instr_addr),

      .data_req_o   (core_b_data_req),
      .data_we_o    (core_b_data_we),
      .data_be_o    (core_b_data_be),
      .data_addr_o  (core_b_data_addr),
      .data_wdata_o (core_b_data_wdata),

      // Response observation outputs are not required in Stage-2.
      .instr_rvalid_o (),
      .instr_rdata_o  (),
      .data_rvalid_o  (),
      .data_rdata_o   ()
  );

endmodule

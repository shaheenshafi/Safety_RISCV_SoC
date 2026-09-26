module safety_riscv_soc_stage2 (
    input clk_i,
    input rst_ni
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
  // Redundant Ibex channel A
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1 core_a (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),

      .instr_req_o    (core_a_instr_req),
      .instr_addr_o   (core_a_instr_addr),

      .data_req_o     (core_a_data_req),
      .data_we_o      (core_a_data_we),
      .data_be_o      (core_a_data_be),
      .data_addr_o    (core_a_data_addr),
      .data_wdata_o   (core_a_data_wdata)
  );

  // --------------------------------------------------------------------------
  // Redundant Ibex channel B
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1 core_b (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),

      .instr_req_o    (core_b_instr_req),
      .instr_addr_o   (core_b_instr_addr),

      .data_req_o     (core_b_data_req),
      .data_we_o      (core_b_data_we),
      .data_be_o      (core_b_data_be),
      .data_addr_o    (core_b_data_addr),
      .data_wdata_o   (core_b_data_wdata)
  );

endmodule

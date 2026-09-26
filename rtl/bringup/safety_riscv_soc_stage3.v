module safety_riscv_soc_stage3 (
    input  wire clk_i,
    input  wire rst_ni,
    input  wire dcls_enable_i,

    output wire dcls_instr_mismatch_o,
    output wire dcls_data_mismatch_o,
    output wire dcls_mismatch_o
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
  // Independent RISC-V execution channel A
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
  // Independent RISC-V execution channel B
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

  // --------------------------------------------------------------------------
  // Our external DCLS comparator
  //
  // This is deliberately NOT Ibex SecureIbex / ibex_lockstep.
  // --------------------------------------------------------------------------

  dcls_comparator u_dcls (
      .compare_en_i             (dcls_enable_i),

      .core_a_instr_req_i       (core_a_instr_req),
      .core_a_instr_addr_i      (core_a_instr_addr),

      .core_b_instr_req_i       (core_b_instr_req),
      .core_b_instr_addr_i      (core_b_instr_addr),

      .core_a_data_req_i        (core_a_data_req),
      .core_a_data_we_i         (core_a_data_we),
      .core_a_data_be_i         (core_a_data_be),
      .core_a_data_addr_i       (core_a_data_addr),
      .core_a_data_wdata_i      (core_a_data_wdata),

      .core_b_data_req_i        (core_b_data_req),
      .core_b_data_we_i         (core_b_data_we),
      .core_b_data_be_i         (core_b_data_be),
      .core_b_data_addr_i       (core_b_data_addr),
      .core_b_data_wdata_i      (core_b_data_wdata),

      .dcls_instr_mismatch_o    (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o     (dcls_data_mismatch_o),
      .dcls_mismatch_o          (dcls_mismatch_o)
  );

endmodule

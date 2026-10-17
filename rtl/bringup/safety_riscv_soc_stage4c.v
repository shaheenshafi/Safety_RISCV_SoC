module safety_riscv_soc_stage4c (
    input  wire       clk_i,
    input  wire       rst_ni,
    input  wire       dcls_enable_i,

    input  wire       fault_inject_enable_i,
    input  wire [1:0] fault_inject_target_i,
    input  wire [31:0] fault_inject_mask_i,

    input wire        core_b_response_fault_inject_enable_i,
    input wire [2:0]  core_b_response_fault_inject_target_i,
    input wire [31:0] core_b_response_fault_inject_mask_i,

    output wire       dcls_instr_mismatch_o,
    output wire       dcls_data_mismatch_o,
    output wire       dcls_mismatch_o,
    output wire       fault_latched_o,
    output wire       instr_fault_seen_o,
    output wire       data_fault_seen_o,
    output wire [7:0] fault_code_o,
    output wire       safe_state_req_o
);

  // --------------------------------------------------------------------------
  // Latched fault-manager request controlling both processor safe-state inputs.
  wire safe_state_req;
  // Core A observation signals
  // --------------------------------------------------------------------------

  wire        core_a_instr_req;
  wire [31:0] core_a_instr_addr;
  wire        core_a_instr_rvalid;
  wire [31:0] core_a_instr_rdata;

  wire        core_a_data_req;
  wire        core_a_data_we;
  wire [3:0]  core_a_data_be;
  wire [31:0] core_a_data_addr;
  wire [31:0] core_a_data_wdata;
  wire        core_a_data_rvalid;
  wire [31:0] core_a_data_rdata;

  // --------------------------------------------------------------------------
  // Core B observation signals
  // --------------------------------------------------------------------------

  wire        core_b_instr_req;
  wire [31:0] core_b_instr_addr;
  wire        core_b_instr_rvalid;
  wire [31:0] core_b_instr_rdata;

  wire        core_b_data_req;
  wire        core_b_data_we;
  wire [3:0]  core_b_data_be;
  wire [31:0] core_b_data_addr;
  wire [31:0] core_b_data_wdata;
  wire        core_b_data_rvalid;
  wire [31:0] core_b_data_rdata;

  // --------------------------------------------------------------------------
  // Fault-injected Core B observation signals
  //
  // Response-path fault injection will be added separately after response
  // comparison has been verified.
  // --------------------------------------------------------------------------

  wire [31:0] core_b_instr_addr_cmp;
  wire [31:0] core_b_data_addr_cmp;
  wire [31:0] core_b_data_wdata_cmp;

  // --------------------------------------------------------------------------
  // Independent RISC-V execution channel A
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1_safe core_a (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .safe_state_i   (safe_state_req),

      .core_response_fault_inject_enable_i (1'b0),
      .core_response_fault_inject_target_i (3'b111),
      .core_response_fault_inject_mask_i   (32'b0),

      .instr_req_o    (core_a_instr_req),
      .instr_addr_o   (core_a_instr_addr),
      .instr_rvalid_o (core_a_instr_rvalid),
      .instr_rdata_o  (core_a_instr_rdata),

      .data_req_o     (core_a_data_req),
      .data_we_o      (core_a_data_we),
      .data_be_o      (core_a_data_be),
      .data_addr_o    (core_a_data_addr),
      .data_wdata_o   (core_a_data_wdata),
      .data_rvalid_o  (core_a_data_rvalid),
      .data_rdata_o   (core_a_data_rdata)
  );

  // --------------------------------------------------------------------------
  // Independent RISC-V execution channel B
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1_safe core_b (
      .clk_i          (clk_i),
      .rst_ni          (rst_ni),
      .safe_state_i    (safe_state_req),

      .core_response_fault_inject_enable_i (core_b_response_fault_inject_enable_i),
      .core_response_fault_inject_target_i (core_b_response_fault_inject_target_i),
      .core_response_fault_inject_mask_i   (core_b_response_fault_inject_mask_i),

      .instr_req_o    (core_b_instr_req),
      .instr_addr_o   (core_b_instr_addr),
      .instr_rvalid_o (core_b_instr_rvalid),
      .instr_rdata_o  (core_b_instr_rdata),

      .data_req_o     (core_b_data_req),
      .data_we_o      (core_b_data_we),
      .data_be_o      (core_b_data_be),
      .data_addr_o    (core_b_data_addr),
      .data_wdata_o   (core_b_data_wdata),
      .data_rvalid_o  (core_b_data_rvalid),
      .data_rdata_o   (core_b_data_rdata)
  );

  // --------------------------------------------------------------------------
  // Controlled fault injection on Core B observation path
  // --------------------------------------------------------------------------

  dcls_fault_injector u_fault_injector (
      .fault_inject_enable_i (fault_inject_enable_i),
      .fault_inject_target_i (fault_inject_target_i),
      .fault_inject_mask_i   (fault_inject_mask_i),

      .instr_addr_i          (core_b_instr_addr),
      .data_addr_i           (core_b_data_addr),
      .data_wdata_i          (core_b_data_wdata),

      .instr_addr_o          (core_b_instr_addr_cmp),
      .data_addr_o           (core_b_data_addr_cmp),
      .data_wdata_o          (core_b_data_wdata_cmp)
  );

  // --------------------------------------------------------------------------
  // Our external DCLS comparator
  //
  // The native Ibex SecureIbex / ibex_lockstep mechanism is not used.
  // --------------------------------------------------------------------------

  dcls_comparator u_dcls (
      .compare_en_i           (dcls_enable_i),

      .core_a_instr_req_i     (core_a_instr_req),
      .core_a_instr_addr_i    (core_a_instr_addr),
      .core_a_instr_rvalid_i  (core_a_instr_rvalid),
      .core_a_instr_rdata_i   (core_a_instr_rdata),

      .core_b_instr_req_i     (core_b_instr_req),
      .core_b_instr_addr_i    (core_b_instr_addr_cmp),
      .core_b_instr_rvalid_i  (core_b_instr_rvalid),
      .core_b_instr_rdata_i   (core_b_instr_rdata),

      .core_a_data_req_i      (core_a_data_req),
      .core_a_data_we_i       (core_a_data_we),
      .core_a_data_be_i       (core_a_data_be),
      .core_a_data_addr_i     (core_a_data_addr),
      .core_a_data_wdata_i    (core_a_data_wdata),
      .core_a_data_rvalid_i   (core_a_data_rvalid),
      .core_a_data_rdata_i    (core_a_data_rdata),

      .core_b_data_req_i      (core_b_data_req),
      .core_b_data_we_i       (core_b_data_we),
      .core_b_data_be_i       (core_b_data_be),
      .core_b_data_addr_i     (core_b_data_addr_cmp),
      .core_b_data_wdata_i    (core_b_data_wdata_cmp),
      .core_b_data_rvalid_i   (core_b_data_rvalid),
      .core_b_data_rdata_i    (core_b_data_rdata),

      .dcls_instr_mismatch_o  (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o   (dcls_data_mismatch_o),
      .dcls_mismatch_o        (dcls_mismatch_o)
  );

  // --------------------------------------------------------------------------
  // Latched fault management and safe-state request
  // --------------------------------------------------------------------------

  safety_fault_manager u_fault_manager (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .dcls_instr_mismatch_i (dcls_instr_mismatch_o),
      .dcls_data_mismatch_i  (dcls_data_mismatch_o),
      .fault_latched_o       (fault_latched_o),
      .instr_fault_seen_o    (instr_fault_seen_o),
      .data_fault_seen_o     (data_fault_seen_o),
      .fault_code_o          (fault_code_o),
      .safe_state_req_o      (safe_state_req)
  );

  assign safe_state_req_o = safe_state_req;

endmodule

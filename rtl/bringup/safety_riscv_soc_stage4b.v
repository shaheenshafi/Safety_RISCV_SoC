module safety_riscv_soc_stage4b (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire        dcls_enable_i,

    input  wire        fault_inject_enable_i,
    input  wire [1:0]  fault_inject_target_i,
    input  wire [31:0] fault_inject_mask_i,

    input  wire        core_b_response_fault_inject_enable_i,
    input  wire [2:0]  core_b_response_fault_inject_target_i,
    input  wire [31:0] core_b_response_fault_inject_mask_i,

    output wire        dcls_instr_mismatch_o,
    output wire        dcls_data_mismatch_o,
    output wire        dcls_mismatch_o,

    output wire        fault_latched_o,
    output wire        instr_fault_seen_o,
    output wire        data_fault_seen_o,
    output wire [7:0]  fault_code_o,
    output wire        safe_state_req_o
);

  // Existing dual-core SoC and DCLS detection remain unchanged.
  safety_riscv_soc_stage3 u_stage3 (
      .clk_i                                  (clk_i),
      .rst_ni                                 (rst_ni),
      .dcls_enable_i                          (dcls_enable_i),

      .fault_inject_enable_i                  (fault_inject_enable_i),
      .fault_inject_target_i                  (fault_inject_target_i),
      .fault_inject_mask_i                    (fault_inject_mask_i),

      .core_b_response_fault_inject_enable_i  (core_b_response_fault_inject_enable_i),
      .core_b_response_fault_inject_target_i  (core_b_response_fault_inject_target_i),
      .core_b_response_fault_inject_mask_i    (core_b_response_fault_inject_mask_i),

      .dcls_instr_mismatch_o                  (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o                   (dcls_data_mismatch_o),
      .dcls_mismatch_o                        (dcls_mismatch_o)
  );

  // Clocked fault management and sticky diagnostic state.
  safety_fault_manager u_safety_fault_manager (
      .clk_i                  (clk_i),
      .rst_ni                 (rst_ni),
      .dcls_instr_mismatch_i  (dcls_instr_mismatch_o),
      .dcls_data_mismatch_i   (dcls_data_mismatch_o),
      .fault_latched_o        (fault_latched_o),
      .instr_fault_seen_o     (instr_fault_seen_o),
      .data_fault_seen_o      (data_fault_seen_o),
      .fault_code_o           (fault_code_o),
      .safe_state_req_o       (safe_state_req_o)
  );

endmodule

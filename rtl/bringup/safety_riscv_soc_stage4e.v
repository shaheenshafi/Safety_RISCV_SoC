module safety_riscv_soc_stage4e (
    input  wire        clk_i,
    input  wire        rst_ni,

    // Fault injection controls remain externally controlled.
    // The active MMIO profile determines whether injection is permitted.
    input  wire [1:0]  fault_inject_target_i,
    input  wire [31:0] fault_inject_mask_i,
    input  wire [2:0]  core_b_response_fault_inject_target_i,
    input  wire [31:0] core_b_response_fault_inject_mask_i,

    // Runtime configuration status.
    output wire [1:0]  selected_profile_o,
    output wire        profile_valid_o,
    output wire        dcls_enable_o,
    output wire        fault_injection_enable_o,

    // Shared-MMIO interlock diagnostics.
    output wire        mmio_interlock_hold_o,
    output wire        mmio_interlock_fault_o,

    // DCLS diagnostics.
    output wire        dcls_instr_mismatch_o,
    output wire        dcls_data_mismatch_o,
    output wire        dcls_mismatch_o,

    // Fault-manager diagnostics and safe state.
    output wire        fault_latched_o,
    output wire        instr_fault_seen_o,
    output wire        data_fault_seen_o,
    output wire [7:0]  fault_code_o,
    output wire        safe_state_req_o
);

  // --------------------------------------------------------------------------
  // Shared safety and MMIO control signals
  // --------------------------------------------------------------------------

  wire safe_state_req;

  wire        mmio_req;
  wire        mmio_gnt;
  wire        mmio_rvalid;
  wire [31:0] mmio_rdata;

  // --------------------------------------------------------------------------
  // Core A raw processor observations
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
  // Core B raw processor observations
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
  // DCLS comparison-path fault injection signals
  //
  // Interlock decisions below use raw processor requests, not these
  // potentially fault-injected comparison values.
  // --------------------------------------------------------------------------

  wire [31:0] core_b_instr_addr_cmp;
  wire [31:0] core_b_data_addr_cmp;
  wire [31:0] core_b_data_wdata_cmp;

  // --------------------------------------------------------------------------
  // MMIO region and request matching
  //
  // The wrapper reserves the complete 0x0020_xxxx region for MMIO.
  // Only the four implemented registers are accepted by this top-level.
  // --------------------------------------------------------------------------

  wire core_a_mmio_region_req;
  wire core_b_mmio_region_req;
  wire core_a_mmio_addr_valid;
  wire mmio_address_match;
  wire mmio_requests_match;
  wire mmio_interlock_fault_internal;

  assign core_a_mmio_region_req =
      core_a_data_req &&
      (core_a_data_addr[31:16] == 16'h0020);

  assign core_b_mmio_region_req =
      core_b_data_req &&
      (core_b_data_addr[31:16] == 16'h0020);

  assign core_a_mmio_addr_valid =
      (core_a_data_addr == 32'h0020_0000) ||
      (core_a_data_addr == 32'h0020_0004) ||
      (core_a_data_addr == 32'h0020_0008) ||
      (core_a_data_addr == 32'h0020_000C);

  assign mmio_address_match =
      (core_a_data_addr == core_b_data_addr);

  // Read write-data payloads are irrelevant. Write payloads must match.
  assign mmio_requests_match =
      core_a_data_req &&
      core_b_data_req &&
      core_a_mmio_region_req &&
      core_b_mmio_region_req &&
      mmio_address_match &&
      core_a_mmio_addr_valid &&
      (core_a_data_we == core_b_data_we) &&
      (core_a_data_be == core_b_data_be) &&
      ((!core_a_data_we) ||
       (core_a_data_wdata == core_b_data_wdata));

  // Fail closed whenever either processor requests the reserved MMIO
  // region without a matching, valid transaction from both processors.
  // This check is independent of the selected DCLS profile.
  assign mmio_interlock_hold_o =
      (core_a_mmio_region_req || core_b_mmio_region_req) &&
      !mmio_requests_match;

  // Report the interlock event to the fault manager. Once safe state is
  // already active, the sticky manager has already recorded its fault.
  assign mmio_interlock_fault_internal =
      mmio_interlock_hold_o && !safe_state_req;

  assign mmio_interlock_fault_o = mmio_interlock_fault_internal;

  // Only an exactly matched, valid transaction reaches the peripheral.
  assign mmio_req = mmio_requests_match && !safe_state_req && !dcls_mismatch_o;

  // --------------------------------------------------------------------------
  // Shared MMIO configuration and fault-status peripheral
  // --------------------------------------------------------------------------

  safety_mmio_config u_mmio_config (
      .clk_i                    (clk_i),
      .rst_ni                   (rst_ni),

      .req_i                    (mmio_req),
      .we_i                     (core_a_data_we),
      .be_i                     (core_a_data_be),
      .addr_i                   (core_a_data_addr),
      .wdata_i                  (core_a_data_wdata),
      .gnt_o                    (mmio_gnt),
      .rvalid_o                 (mmio_rvalid),
      .rdata_o                  (mmio_rdata),

      .safe_state_i             (safe_state_req),

      .fault_latched_i           (fault_latched_o),
      .instr_fault_seen_i        (instr_fault_seen_o),
      .data_fault_seen_i         (data_fault_seen_o),
      .fault_code_i              (fault_code_o),

      .profile_o                 (),
      .injection_authorize_o     (),

      .selected_profile_o        (selected_profile_o),
      .profile_valid_o           (profile_valid_o),
      .dcls_enable_o             (dcls_enable_o),
      .fault_injection_enable_o  (fault_injection_enable_o)
  );

  // --------------------------------------------------------------------------
  // Core A: independent RISC-V execution channel
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1_mmio #(
      .MemInitFile("data/stage4e_mmio.vmem")
  ) core_a (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .safe_state_i   (safe_state_req),
      .mmio_interlock_hold_i (mmio_interlock_hold_o),

      .mmio_gnt_i     (mmio_gnt),
      .mmio_rvalid_i  (mmio_rvalid),
      .mmio_rdata_i   (mmio_rdata),

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
  // Core B: independent redundant execution channel
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1_mmio #(
      .MemInitFile("data/stage4e_mmio.vmem")
  ) core_b (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .safe_state_i   (safe_state_req),
      .mmio_interlock_hold_i (mmio_interlock_hold_o),

      .mmio_gnt_i     (mmio_gnt),
      .mmio_rvalid_i  (mmio_rvalid),
      .mmio_rdata_i   (mmio_rdata),

      .core_response_fault_inject_enable_i (fault_injection_enable_o),
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
  // Controlled Core B observation-path fault injection
  // --------------------------------------------------------------------------

  dcls_fault_injector u_fault_injector (
      .fault_inject_enable_i (fault_injection_enable_o),
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
  // External transaction-level DCLS comparison
  // --------------------------------------------------------------------------

  dcls_comparator u_dcls (
      .compare_en_i           (dcls_enable_o),

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
  // Fault manager
  //
  // The MMIO interlock fault is combined with data divergence so an unsafe
  // shared-peripheral request also triggers the existing sticky data fault
  // response, even when the Basic profile disables DCLS comparison.
  // --------------------------------------------------------------------------

  safety_fault_manager u_fault_manager (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .dcls_instr_mismatch_i (dcls_instr_mismatch_o),
      .dcls_data_mismatch_i  (dcls_data_mismatch_o |
                               mmio_interlock_fault_internal),
      .fault_latched_o       (fault_latched_o),
      .instr_fault_seen_o    (instr_fault_seen_o),
      .data_fault_seen_o     (data_fault_seen_o),
      .fault_code_o          (fault_code_o),
      .safe_state_req_o      (safe_state_req)
  );

  assign safe_state_req_o = safe_state_req;

endmodule

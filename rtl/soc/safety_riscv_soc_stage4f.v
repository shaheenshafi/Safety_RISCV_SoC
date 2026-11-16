module safety_riscv_soc_stage4f #(
    parameter MemInitFile = "data/stage4f_heartbeat.vmem"
) (
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
    output wire        supervisor_fault_seen_o,
    output wire        core_a_double_fault_seen_o,
    output wire        core_b_double_fault_seen_o,
    output wire        mmio_replica_integrity_fault_seen_o,
    output wire [7:0]  fault_code_o,
    output wire        safe_state_req_o,
    output wire        watchdog_early_fault_o,
    output wire        watchdog_timeout_fault_o,
    output wire        progress_timeout_fault_o,
    output wire        supervisor_fault_o,
    output wire [31:0] heartbeat_value_o,
    output wire        heartbeat_update_o
);

  // --------------------------------------------------------------------------
  // Shared safety and MMIO control signals
  // --------------------------------------------------------------------------

  // safe_state_req is the fault manager's sticky request. The effective
  // safe-state signal also includes the combinational configuration-integrity
  // detector so side effects are blocked immediately, before the manager's
  // sticky state is clocked.
  wire safe_state_req;
  wire safe_state_active;
  wire profile_integrity_fault;
  wire config_integrity_fault_seen;
  wire mmio_replica_integrity_fault;
  wire mmio_accept;
  wire dcls_instr_payload_mismatch;
  wire dcls_data_payload_mismatch;
  wire dcls_instr_error_mismatch;
  wire dcls_data_error_mismatch;

  // Registered capture-before-compare data transaction path.
  wire        paired_data_stage_mismatch;
  wire        paired_data_commit_valid;
  wire        paired_data_commit_ready;
  wire        paired_data_bypass;
  wire        paired_data_busy;
  wire        paired_data_path_active;
  wire        paired_data_gnt_a;
  wire        paired_data_gnt_b;
  wire [68:0] paired_data_payload_a;
  wire [68:0] paired_data_payload_b;
  wire [68:0] paired_data_compare_a;
  wire [68:0] paired_data_compare_b;
  wire [68:0] paired_data_commit_payload_a;
  wire [68:0] paired_data_commit_payload_b;

  assign safe_state_active = safe_state_req | profile_integrity_fault;

  // --------------------------------------------------------------------------
  // Common SoC reset conditioning
  //
  // External reset assertion remains asynchronous. Deassertion is synchronised
  // to clk_i and the resulting reset is used by all SoC control logic, RAM
  // response state, and both processor wrappers. Each Ibex wrapper retains its
  // local two-stage reset synchronizer, including asynchronous safe-state
  // assertion. The common release prevents Core A/Core B from independently
  // synchronising an asynchronous board-reset release.
  // --------------------------------------------------------------------------

  (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] soc_reset_release_sync;
  wire soc_rst_ni;

  always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
          soc_reset_release_sync <= 2'b00;
      else
          soc_reset_release_sync <= {soc_reset_release_sync[0], 1'b1};
  end

  assign soc_rst_ni = soc_reset_release_sync[1];

  wire        mmio_req;
  wire        mmio_gnt;
  wire        mmio_rvalid;
  wire [31:0] mmio_rdata;

  // Independent MMIO configuration/response replicas. Both copies receive
  // the same request and fault-manager status, but only a top-level consensus
  // permits either copy to commit state or return a response to the cores.
  wire mmio_gnt_a, mmio_gnt_b;
  wire mmio_rvalid_a, mmio_rvalid_b;
  wire [31:0] mmio_rdata_a, mmio_rdata_b;
  wire [1:0] mmio_profile_a, mmio_profile_b;
  wire mmio_injection_authorize_a, mmio_injection_authorize_b;
  wire mmio_config_integrity_fault_a, mmio_config_integrity_fault_b;
  wire [1:0] mmio_selected_profile_a, mmio_selected_profile_b;
  wire mmio_profile_valid_a, mmio_profile_valid_b;
  wire mmio_dcls_enable_a, mmio_dcls_enable_b;
  wire mmio_fault_injection_enable_a, mmio_fault_injection_enable_b;
  wire [31:0] mmio_heartbeat_a, mmio_heartbeat_b;
  wire mmio_heartbeat_update_a, mmio_heartbeat_update_b;

  // --------------------------------------------------------------------------
  // Core A raw processor observations
  // --------------------------------------------------------------------------

  wire        core_a_instr_req;
  wire [31:0] core_a_instr_addr;
  wire        core_a_instr_rvalid;
  wire [31:0] core_a_instr_rdata;
  wire        core_a_instr_err;

  wire        core_a_data_req;
  wire        core_a_data_we;
  wire [3:0]  core_a_data_be;
  wire [31:0] core_a_data_addr;
  wire [31:0] core_a_data_wdata;
  wire        core_a_data_rvalid;
  wire [31:0] core_a_data_rdata;
  wire        core_a_data_err;
  wire core_a_instr_addr_fault;
  wire core_a_data_addr_fault;
  wire core_a_ibex_double_fault;

  // --------------------------------------------------------------------------
  // Core B raw processor observations
  // --------------------------------------------------------------------------

  wire        core_b_instr_req;
  wire [31:0] core_b_instr_addr;
  wire        core_b_instr_rvalid;
  wire [31:0] core_b_instr_rdata;
  wire        core_b_instr_err;

  wire        core_b_data_req;
  wire        core_b_data_we;
  wire [3:0]  core_b_data_be;
  wire [31:0] core_b_data_addr;
  wire [31:0] core_b_data_wdata;
  wire        core_b_data_rvalid;
  wire [31:0] core_b_data_rdata;
  wire        core_b_data_err;
  wire core_b_instr_addr_fault;
  wire core_b_data_addr_fault;
  wire core_b_ibex_double_fault;

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
  // Only the five implemented registers are accepted by this top-level.
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
      (core_a_data_addr == 32'h0020_000C) ||
      (core_a_data_addr == 32'h0020_0010);

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
      mmio_interlock_hold_o && !safe_state_active;

  assign mmio_interlock_fault_o = mmio_interlock_fault_internal;

  // Only an exactly matched, valid transaction reaches the peripheral.
  // Do not gate this request with the combinational DCLS mismatch output: an
  // MMIO response contributes to the core response observed by DCLS, so that
  // would form a feedback path from MMIO response -> DCLS -> MMIO request.
  // DCLS mismatch still blocks the peripheral's state/response commit through
  // mmio_accept below, and the sticky fault manager asserts safe state at the
  // capturing clock edge.
  assign mmio_req =
      mmio_requests_match &&
      !safe_state_active &&
      !supervisor_fault_o;

  // --------------------------------------------------------------------------
  // Shared MMIO configuration and fault-status peripheral
  // --------------------------------------------------------------------------

  safety_mmio_config_stage4f u_mmio_config (
      .clk_i                    (clk_i),
      .rst_ni                   (soc_rst_ni),

      .req_i                    (mmio_req),
      .we_i                     (core_a_data_we),
      .be_i                     (core_a_data_be),
      .addr_i                   (core_a_data_addr),
      .wdata_i                  (core_a_data_wdata),
      .gnt_o                    (mmio_gnt_a),
      .rvalid_o                 (mmio_rvalid_a),
      .rdata_o                  (mmio_rdata_a),

      .safe_state_i             (safe_state_active | supervisor_fault_o),
      .accept_i                 (mmio_accept),

      .fault_latched_i          (fault_latched_o),
      .instr_fault_seen_i       (instr_fault_seen_o),
      .data_fault_seen_i        (data_fault_seen_o),
      .supervisor_fault_seen_i  (supervisor_fault_seen_o),
      .config_integrity_fault_seen_i (config_integrity_fault_seen),
      .fault_code_i             (fault_code_o),

      .profile_o                (mmio_profile_a),
      .injection_authorize_o    (mmio_injection_authorize_a),
      .config_integrity_fault_o (mmio_config_integrity_fault_a),

      .selected_profile_o       (mmio_selected_profile_a),
      .profile_valid_o          (mmio_profile_valid_a),
      .dcls_enable_o            (mmio_dcls_enable_a),
      .fault_injection_enable_o (mmio_fault_injection_enable_a),
      .heartbeat_value_o        (mmio_heartbeat_a),
      .heartbeat_update_o       (mmio_heartbeat_update_a)
  );

  safety_mmio_config_stage4f u_mmio_config_replica (
      .clk_i                    (clk_i),
      .rst_ni                   (soc_rst_ni),

      .req_i                    (mmio_req),
      .we_i                     (core_a_data_we),
      .be_i                     (core_a_data_be),
      .addr_i                   (core_a_data_addr),
      .wdata_i                  (core_a_data_wdata),
      .gnt_o                    (mmio_gnt_b),
      .rvalid_o                 (mmio_rvalid_b),
      .rdata_o                  (mmio_rdata_b),

      .safe_state_i             (safe_state_active | supervisor_fault_o),
      .accept_i                 (mmio_accept),

      .fault_latched_i          (fault_latched_o),
      .instr_fault_seen_i       (instr_fault_seen_o),
      .data_fault_seen_i        (data_fault_seen_o),
      .supervisor_fault_seen_i  (supervisor_fault_seen_o),
      .config_integrity_fault_seen_i (config_integrity_fault_seen),
      .fault_code_i             (fault_code_o),

      .profile_o                (mmio_profile_b),
      .injection_authorize_o    (mmio_injection_authorize_b),
      .config_integrity_fault_o (mmio_config_integrity_fault_b),

      .selected_profile_o       (mmio_selected_profile_b),
      .profile_valid_o          (mmio_profile_valid_b),
      .dcls_enable_o            (mmio_dcls_enable_b),
      .fault_injection_enable_o (mmio_fault_injection_enable_b),
      .heartbeat_value_o        (mmio_heartbeat_b),
      .heartbeat_update_o       (mmio_heartbeat_update_b)
  );

  // Detect single-replica divergence in transaction handshake, returned data,
  // and state that controls runtime safety policy. Configuration complement
  // faults remain a separate source (0x05) and retain their original priority.
  assign mmio_replica_integrity_fault =
      (mmio_gnt_a != mmio_gnt_b) ||
      (mmio_rvalid_a != mmio_rvalid_b) ||
      (mmio_rvalid_a && mmio_rvalid_b && (mmio_rdata_a != mmio_rdata_b)) ||
      (mmio_profile_a != mmio_profile_b) ||
      (mmio_injection_authorize_a != mmio_injection_authorize_b) ||
      (mmio_heartbeat_a != mmio_heartbeat_b) ||
      (mmio_selected_profile_a != mmio_selected_profile_b) ||
      (mmio_profile_valid_a != mmio_profile_valid_b) ||
      (mmio_dcls_enable_a != mmio_dcls_enable_b) ||
      (mmio_fault_injection_enable_a != mmio_fault_injection_enable_b);

  // No replica commits a write or advances a read response without both
  // grants and a clean comparison. This avoids a one-sided state update if
  // the two grant channels disagree.
  assign mmio_accept = mmio_req && mmio_gnt_a && mmio_gnt_b &&
                       !mmio_replica_integrity_fault &&
                       !profile_integrity_fault &&
                       !dcls_mismatch_o;

  // Only a matched response is exposed to either processor. A mismatch is
  // blocked immediately, then latched by the fault manager on the next edge.
  assign mmio_gnt = mmio_gnt_a && mmio_gnt_b &&
                    !mmio_replica_integrity_fault;
  assign mmio_rvalid = mmio_rvalid_a && mmio_rvalid_b &&
                       !mmio_replica_integrity_fault;
  assign mmio_rdata = mmio_rvalid ? mmio_rdata_a : 32'b0;

  assign profile_integrity_fault =
      mmio_config_integrity_fault_a | mmio_config_integrity_fault_b;
  assign selected_profile_o = mmio_selected_profile_a;
  assign profile_valid_o = mmio_profile_valid_a && mmio_profile_valid_b &&
                           !profile_integrity_fault;
  assign dcls_enable_o = profile_integrity_fault ||
                         mmio_dcls_enable_a || mmio_dcls_enable_b;
  assign fault_injection_enable_o =
      mmio_fault_injection_enable_a && mmio_fault_injection_enable_b &&
      !profile_integrity_fault && !mmio_replica_integrity_fault;
  assign heartbeat_value_o = mmio_heartbeat_a;
  assign heartbeat_update_o = mmio_heartbeat_update_a &&
                              mmio_heartbeat_update_b &&
                              !mmio_replica_integrity_fault;

  // --------------------------------------------------------------------------
  // Core A: independent RISC-V execution channel
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1_mmio #(
      .MemInitFile(MemInitFile),
      .RamDepth(4096),
      .EnableAddressGuard(1'b1),
      .EnablePairedDataPath(1)
  ) core_a (
      .clk_i          (clk_i),
      .rst_ni         (soc_rst_ni),
      .safe_state_i   (safe_state_active),
      .mmio_interlock_hold_i (mmio_interlock_hold_o),
      .memory_side_effect_inhibit_i (safe_state_active | supervisor_fault_o |
                                    dcls_mismatch_o | mmio_replica_integrity_fault),
      .paired_data_path_active_i (paired_data_path_active),
      .paired_data_gnt_i (paired_data_gnt_a),
      .paired_data_commit_valid_i (paired_data_commit_valid),
      .paired_data_commit_payload_i (paired_data_commit_payload_a),

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
      .instr_err_o    (core_a_instr_err),

      .data_req_o     (core_a_data_req),
      .data_we_o      (core_a_data_we),
      .data_be_o      (core_a_data_be),
      .data_addr_o    (core_a_data_addr),
      .data_wdata_o   (core_a_data_wdata),
      .data_rvalid_o  (core_a_data_rvalid),
      .data_rdata_o   (core_a_data_rdata),
      .data_err_o     (core_a_data_err),
      .instr_addr_fault_o (core_a_instr_addr_fault),
      .data_addr_fault_o  (core_a_data_addr_fault),
      .ibex_double_fault_seen_o (core_a_ibex_double_fault)
  );

  // --------------------------------------------------------------------------
  // Core B: independent redundant execution channel
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage1_mmio #(
      .MemInitFile(MemInitFile),
      .RamDepth(4096),
      .EnableAddressGuard(1'b1),
      .EnablePairedDataPath(1)
  ) core_b (
      .clk_i          (clk_i),
      .rst_ni         (soc_rst_ni),
      .safe_state_i   (safe_state_active),
      .mmio_interlock_hold_i (mmio_interlock_hold_o),
      .memory_side_effect_inhibit_i (safe_state_active | supervisor_fault_o |
                                    dcls_mismatch_o | mmio_replica_integrity_fault),
      .paired_data_path_active_i (paired_data_path_active),
      .paired_data_gnt_i (paired_data_gnt_b),
      .paired_data_commit_valid_i (paired_data_commit_valid),
      .paired_data_commit_payload_i (paired_data_commit_payload_b),

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
      .instr_err_o    (core_b_instr_err),

      .data_req_o     (core_b_data_req),
      .data_we_o      (core_b_data_we),
      .data_be_o      (core_b_data_be),
      .data_addr_o    (core_b_data_addr),
      .data_wdata_o   (core_b_data_wdata),
      .data_rvalid_o  (core_b_data_rvalid),
      .data_rdata_o   (core_b_data_rdata),
      .data_err_o     (core_b_data_err),
      .instr_addr_fault_o (core_b_instr_addr_fault),
      .data_addr_fault_o  (core_b_data_addr_fault),
      .ibex_double_fault_seen_o (core_b_ibex_double_fault)
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

  // Data request payload layout:
  // {write-enable, byte-enable, CPU byte address, write data}.
  // Write data is masked for reads because it is not a meaningful read
  // request field. The captured Core B payload remains the original, unmodified
  // processor output; only its comparison signature uses the injector output.
  assign paired_data_payload_a =
      {core_a_data_we, core_a_data_be, core_a_data_addr,
       (core_a_data_we ? core_a_data_wdata : 32'b0)};
  assign paired_data_payload_b =
      {core_b_data_we, core_b_data_be, core_b_data_addr,
       (core_b_data_we ? core_b_data_wdata : 32'b0)};

  assign paired_data_compare_a = paired_data_payload_a;
  assign paired_data_compare_b =
      {core_b_data_we, core_b_data_be, core_b_data_addr_cmp,
       (core_b_data_we ? core_b_data_wdata_cmp : 32'b0)};

  // Stage only non-MMIO requests. Both-MMIO transactions continue through the
  // existing central MMIO interlock and replicated peripheral path. A mixed
  // MMIO/RAM pair presents a valid mismatch to this stage and is rejected.
  assign paired_data_path_active = !paired_data_bypass;

  // Do not retire the capture-stage entry unless both wrappers can accept
  // the same paired transaction on this edge.
  assign paired_data_commit_ready =
      !safe_state_active &&
      !supervisor_fault_o &&
      !dcls_instr_payload_mismatch &&
      !dcls_data_payload_mismatch &&
      !dcls_instr_error_mismatch &&
      !dcls_data_error_mismatch &&
      !mmio_replica_integrity_fault &&
      !mmio_interlock_hold_o;

  dcls_paired_data_capture_stage #(
      .PayloadWidth (69),
      .CompareWidth (69)
  ) u_paired_data_capture_stage (
      .clk_i                   (clk_i),
      .rst_ni                  (soc_rst_ni),
      .stage_enable_i          (dcls_enable_o),
      .flush_i                 (safe_state_active |
                                supervisor_fault_o |
                                dcls_instr_payload_mismatch |
                                dcls_data_payload_mismatch |
                                dcls_instr_error_mismatch |
                                dcls_data_error_mismatch |
                                mmio_replica_integrity_fault |
                                mmio_interlock_hold_o),
      .commit_ready_i          (paired_data_commit_ready),

      .req_a_i                 (core_a_data_req && !core_a_mmio_region_req),
      .req_b_i                 (core_b_data_req && !core_b_mmio_region_req),
      .compare_payload_a_i    (paired_data_compare_a),
      .compare_payload_b_i    (paired_data_compare_b),
      .payload_a_i            (paired_data_payload_a),
      .payload_b_i            (paired_data_payload_b),

      .gnt_a_o                 (paired_data_gnt_a),
      .gnt_b_o                 (paired_data_gnt_b),
      .request_mismatch_o      (),
      .payload_mismatch_o      (),
      .mismatch_o              (paired_data_stage_mismatch),

      .commit_valid_o          (paired_data_commit_valid),
      .commit_payload_a_o      (paired_data_commit_payload_a),
      .commit_payload_b_o      (paired_data_commit_payload_b),

      .bypass_o                (paired_data_bypass),
      .busy_o                  (paired_data_busy),
      .fault_latched_o         ()
  );

  // --------------------------------------------------------------------------
  // External transaction-level DCLS comparison
  // --------------------------------------------------------------------------

  // RAM request comparison is performed by the registered paired capture
  // stage. The existing comparator receives MMIO-only request-valid signals,
  // preserving its original MMIO request and all-response comparison logic.
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

      .core_a_data_req_i      (core_a_mmio_region_req),
      .core_a_data_we_i       (core_a_data_we),
      .core_a_data_be_i       (core_a_data_be),
      .core_a_data_addr_i     (core_a_data_addr),
      .core_a_data_wdata_i    (core_a_data_wdata),
      .core_a_data_rvalid_i   (core_a_data_rvalid),
      .core_a_data_rdata_i    (core_a_data_rdata),

      .core_b_data_req_i      (core_b_mmio_region_req),
      .core_b_data_we_i       (core_b_data_we),
      .core_b_data_be_i       (core_b_data_be),
      .core_b_data_addr_i     (core_b_data_addr_cmp),
      .core_b_data_wdata_i    (core_b_data_wdata_cmp),
      .core_b_data_rvalid_i   (core_b_data_rvalid),
      .core_b_data_rdata_i    (core_b_data_rdata),

      .dcls_instr_mismatch_o  (dcls_instr_payload_mismatch),
      .dcls_data_mismatch_o   (dcls_data_payload_mismatch),
      .dcls_mismatch_o        ()
  );

  // Compare per-core response error status outside the Ibex cores. Error
  // signals are meaningful only when both corresponding responses are valid.
  dcls_response_error_monitor u_dcls_response_error_monitor (
      .compare_en_i             (dcls_enable_o),
      .core_a_instr_rvalid_i    (core_a_instr_rvalid),
      .core_a_instr_err_i       (core_a_instr_err),
      .core_b_instr_rvalid_i    (core_b_instr_rvalid),
      .core_b_instr_err_i       (core_b_instr_err),
      .core_a_data_rvalid_i     (core_a_data_rvalid),
      .core_a_data_err_i        (core_a_data_err),
      .core_b_data_rvalid_i     (core_b_data_rvalid),
      .core_b_data_err_i        (core_b_data_err),
      .instr_error_mismatch_o   (dcls_instr_error_mismatch),
      .data_error_mismatch_o    (dcls_data_error_mismatch)
  );

  // Merge error-status comparison with the existing transaction comparison.
  // These combined signals feed the existing fault manager and interlocks.
  assign dcls_instr_mismatch_o =
      dcls_instr_payload_mismatch | dcls_instr_error_mismatch;
  assign dcls_data_mismatch_o =
      dcls_data_payload_mismatch |
      dcls_data_error_mismatch |
      paired_data_stage_mismatch;
  assign dcls_mismatch_o = dcls_instr_mismatch_o | dcls_data_mismatch_o;

  // --------------------------------------------------------------------------
  // Execution supervisor
  //
  // Heartbeat writes are application-level progress checkpoints; they do not
  // claim per-instruction retirement monitoring. Long timers allow firmware
  // initialization to reach its first checkpoint after Safety is selected.
  // --------------------------------------------------------------------------
  safety_execution_supervisor #(
      .MIN_KICK_CYCLES         (4),
      .MAX_KICK_CYCLES         (256),
      .PROGRESS_TIMEOUT_CYCLES (256)
  ) u_execution_supervisor (
      .clk_i                    (clk_i),
      .rst_ni                   (soc_rst_ni),
      .enable_i                 (profile_valid_o && !safe_state_active),
      .watchdog_kick_i          (heartbeat_update_o),
      .progress_event_i         (heartbeat_update_o),
      .watchdog_early_fault_o   (watchdog_early_fault_o),
      .watchdog_timeout_fault_o (watchdog_timeout_fault_o),
      .progress_timeout_fault_o (progress_timeout_fault_o),
      .supervisor_fault_o       (supervisor_fault_o)
  );

  // --------------------------------------------------------------------------
  // Fault manager
  //
  // The MMIO interlock fault is combined with data divergence so an unsafe
  // shared-peripheral request also triggers the existing sticky data fault
  // response, even when the Basic profile disables DCLS comparison.
  // --------------------------------------------------------------------------

  safety_fault_manager_stage4f u_fault_manager (
      .clk_i                 (clk_i),
      .rst_ni                (soc_rst_ni),
      .dcls_instr_mismatch_i (dcls_instr_mismatch_o |
                               core_a_instr_addr_fault |
                               core_b_instr_addr_fault),
      .dcls_data_mismatch_i  (dcls_data_mismatch_o |
                               core_a_data_addr_fault |
                               core_b_data_addr_fault |
                               mmio_interlock_fault_internal),
      .supervisor_fault_i    (supervisor_fault_o),
      .core_a_double_fault_i (core_a_ibex_double_fault),
      .core_b_double_fault_i (core_b_ibex_double_fault),
      .config_integrity_fault_i (profile_integrity_fault),
      .mmio_replica_integrity_fault_i (mmio_replica_integrity_fault),
      .fault_latched_o       (fault_latched_o),
      .instr_fault_seen_o    (instr_fault_seen_o),
      .data_fault_seen_o       (data_fault_seen_o),
      .supervisor_fault_seen_o (supervisor_fault_seen_o),
      .core_a_double_fault_seen_o (core_a_double_fault_seen_o),
      .core_b_double_fault_seen_o (core_b_double_fault_seen_o),
      .config_integrity_fault_seen_o (config_integrity_fault_seen),
      .mmio_replica_integrity_fault_seen_o
                                (mmio_replica_integrity_fault_seen_o),
      .fault_code_o            (fault_code_o),
      .safe_state_req_o      (safe_state_req)
  );

  assign safe_state_req_o = safe_state_active;

endmodule

`timescale 1ns/1ps

module safety_riscv_soc_stage4f_native_double_fault_tb;

  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;

  wire [1:0] selected_profile_o;
  wire profile_valid_o;
  wire dcls_enable_o;
  wire fault_injection_enable_o;
  wire mmio_interlock_hold_o;
  wire mmio_interlock_fault_o;
  wire dcls_instr_mismatch_o;
  wire dcls_data_mismatch_o;
  wire dcls_mismatch_o;
  wire fault_latched_o;
  wire instr_fault_seen_o;
  wire data_fault_seen_o;
  wire supervisor_fault_seen_o;
  wire core_a_double_fault_seen_o;
  wire core_b_double_fault_seen_o;
  wire mmio_replica_integrity_fault_seen_o;
  wire [7:0] fault_code_o;
  wire safe_state_req_o;
  wire watchdog_early_fault_o;
  wire watchdog_timeout_fault_o;
  wire progress_timeout_fault_o;
  wire supervisor_fault_o;
  wire [31:0] heartbeat_value_o;
  wire heartbeat_update_o;

  reg core_a_native_pulse_seen = 1'b0;
  reg core_b_native_pulse_seen = 1'b0;

  safety_riscv_soc_stage4f #(
      .MemInitFile("data/stage4f_native_double_fault.vmem")
  ) dut (
      .clk_i (clk_i),
      .rst_ni (rst_ni),

      .fault_inject_target_i (2'b00),
      .fault_inject_mask_i (32'b0),
      .core_b_response_fault_inject_target_i (3'b111),
      .core_b_response_fault_inject_mask_i (32'b0),

      .selected_profile_o (selected_profile_o),
      .profile_valid_o (profile_valid_o),
      .dcls_enable_o (dcls_enable_o),
      .fault_injection_enable_o (fault_injection_enable_o),

      .mmio_interlock_hold_o (mmio_interlock_hold_o),
      .mmio_interlock_fault_o (mmio_interlock_fault_o),

      .dcls_instr_mismatch_o (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o (dcls_data_mismatch_o),
      .dcls_mismatch_o (dcls_mismatch_o),

      .fault_latched_o (fault_latched_o),
      .instr_fault_seen_o (instr_fault_seen_o),
      .data_fault_seen_o (data_fault_seen_o),
      .supervisor_fault_seen_o (supervisor_fault_seen_o),
      .core_a_double_fault_seen_o (core_a_double_fault_seen_o),
      .core_b_double_fault_seen_o (core_b_double_fault_seen_o),
      .mmio_replica_integrity_fault_seen_o (mmio_replica_integrity_fault_seen_o),
      .fault_code_o (fault_code_o),
      .safe_state_req_o (safe_state_req_o),

      .watchdog_early_fault_o (watchdog_early_fault_o),
      .watchdog_timeout_fault_o (watchdog_timeout_fault_o),
      .progress_timeout_fault_o (progress_timeout_fault_o),
      .supervisor_fault_o (supervisor_fault_o),
      .heartbeat_value_o (heartbeat_value_o),
      .heartbeat_update_o (heartbeat_update_o)
  );

  always #5 clk_i = ~clk_i;

  // Observe the actual Ibex output pins, not forced wrapper signals.
  always @(posedge dut.core_a.ibex_double_fault_seen_o) begin
    if (rst_ni === 1'b1 && dut.soc_rst_ni === 1'b1 &&
        dut.core_a.core_rst_ni === 1'b1)
      core_a_native_pulse_seen = 1'b1;
  end

  always @(posedge dut.core_b.ibex_double_fault_seen_o) begin
    if (rst_ni === 1'b1 && dut.soc_rst_ni === 1'b1 &&
        dut.core_b.core_rst_ni === 1'b1)
      core_b_native_pulse_seen = 1'b1;
  end

  // Clear only the testbench observation flags on external reset.
  always @(negedge rst_ni) begin
    core_a_native_pulse_seen = 1'b0;
    core_b_native_pulse_seen = 1'b0;
  end

  task automatic check_reset_defaults;
    begin
      if (fault_latched_o !== 1'b0 ||
          fault_code_o !== 8'h00 ||
          safe_state_req_o !== 1'b0 ||
          core_a_double_fault_seen_o !== 1'b0 ||
          core_b_double_fault_seen_o !== 1'b0 ||
          mmio_replica_integrity_fault_seen_o !== 1'b0 ||
          dut.soc_rst_ni !== 1'b0)
        $fatal(1, "External reset did not clear double-fault state");
    end
  endtask

  initial begin
    // Verify the test image is present at the expected reset/vector offsets.
    repeat (4) @(posedge clk_i);
    #1;
    if (dut.core_a.u_ram.u_ram.mem[0] !== 32'h0000_0073 ||
        dut.core_a.u_ram.u_ram.mem[1] !== 32'h0000_006f ||
        dut.core_a.u_ram.u_ram.mem[32] !== 32'h0000_0073 ||
        dut.core_a.u_ram.u_ram.mem[33] !== 32'h0000_006f ||
        dut.core_b.u_ram.u_ram.mem[0] !== 32'h0000_0073 ||
        dut.core_b.u_ram.u_ram.mem[1] !== 32'h0000_006f ||
        dut.core_b.u_ram.u_ram.mem[32] !== 32'h0000_0073 ||
        dut.core_b.u_ram.u_ram.mem[33] !== 32'h0000_006f)
      $fatal(1, "Native ECALL/ECALL image is not loaded at reset vector and trap-vector addresses");

    if (selected_profile_o !== 2'b00 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b0 ||
        fault_latched_o !== 1'b0 ||
        fault_code_o !== 8'h00 ||
        safe_state_req_o !== 1'b0)
      $fatal(1, "Unexpected reset defaults before native double-fault test");

    $display("PASS: Native double-fault image and reset defaults");

    // ----------------------------------------------------------------------
    // Core A: execute the real nested-ECALL stimulus while Core B is held
    // in reset. Core A must assert Ibex's native double_fault_seen_o pulse.
    // ----------------------------------------------------------------------
    force dut.core_b.core_rst_ni = 1'b0;
    rst_ni = 1'b1;
    repeat (4) @(posedge clk_i);
    #1;

    if (dut.core_a.core_rst_ni !== 1'b1 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Failed to isolate Core A for native double-fault test");

    repeat (96) @(posedge clk_i);
    #1;

    if (core_a_native_pulse_seen !== 1'b1 ||
        core_b_native_pulse_seen !== 1'b0 ||
        core_a_double_fault_seen_o !== 1'b1 ||
        core_b_double_fault_seen_o !== 1'b0 ||
        fault_latched_o !== 1'b1 ||
        fault_code_o !== 8'h04 ||
        safe_state_req_o !== 1'b1)
      $fatal(1,
        "Core A native double fault not captured: pulse=%b/%b sticky=%b/%b fault=%b code=%02h safe=%b",
        core_a_native_pulse_seen, core_b_native_pulse_seen,
        core_a_double_fault_seen_o, core_b_double_fault_seen_o,
        fault_latched_o, fault_code_o, safe_state_req_o);

    $display("PASS: Core A genuine Ibex double fault, sticky capture and safe state");

    // Clear the first event only with external reset.
    rst_ni = 1'b0;
    #1;
    check_reset_defaults();
    release dut.core_b.core_rst_ni;
    repeat (2) @(posedge clk_i);
    rst_ni = 1'b1;
    repeat (4) @(posedge clk_i);
    #1;

    if (dut.core_a.core_rst_ni !== 1'b1 ||
        dut.core_b.core_rst_ni !== 1'b1 ||
        core_a_native_pulse_seen !== 1'b0 ||
        core_b_native_pulse_seen !== 1'b0)
      $fatal(1, "Core reset and test observation did not recover for Core B test");

    // ----------------------------------------------------------------------
    // Core B: repeat the real nested-ECALL stimulus with Core A held reset.
    // ----------------------------------------------------------------------
    force dut.core_a.core_rst_ni = 1'b0;
    repeat (96) @(posedge clk_i);
    #1;

    if (core_a_native_pulse_seen !== 1'b0 ||
        core_b_native_pulse_seen !== 1'b1 ||
        core_a_double_fault_seen_o !== 1'b0 ||
        core_b_double_fault_seen_o !== 1'b1 ||
        fault_latched_o !== 1'b1 ||
        fault_code_o !== 8'h04 ||
        safe_state_req_o !== 1'b1)
      $fatal(1,
        "Core B native double fault not captured: pulse=%b/%b sticky=%b/%b fault=%b code=%02h safe=%b",
        core_a_native_pulse_seen, core_b_native_pulse_seen,
        core_a_double_fault_seen_o, core_b_double_fault_seen_o,
        fault_latched_o, fault_code_o, safe_state_req_o);

    $display("PASS: Core B genuine Ibex double fault, sticky capture and safe state");
    $display("");
    $display("====================================================");
    $display("NATIVE IBEX DOUBLE-FAULT GENERATION: PASS");
    $display("Core A real Ibex pulse       : OBSERVED");
    $display("Core B real Ibex pulse       : OBSERVED");
    $display("Independent sticky capture  : VERIFIED");
    $display("Fault code                   : 0x04");
    $display("Safe-state containment       : VERIFIED");
    $display("Stimulus                     : ECALL at reset PC, ECALL at reset mtvec");
    $display("====================================================");
    $finish;
  end

  initial begin
    #20000;
    $fatal(1, "Native Ibex double-fault test timed out");
  end

endmodule

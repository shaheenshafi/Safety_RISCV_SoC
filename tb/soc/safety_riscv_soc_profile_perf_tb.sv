`timescale 1ns/1ps

`include "fw_images.vh"

// -----------------------------------------------------------------------------
// Profile performance comparison
//
// Runs the same battery-monitor workload three times on the same SoC, once in
// each runtime profile (Basic, Safety, Diagnostic), and measures in clock
// cycles:
//   - the time from reset release to the workload PASS marker,
//   - the period of the idle heartbeat loop after the workload.
//
// The profile is requested through the board-control input, exactly as the
// slide switches do on the FPGA board. The comparison Basic vs Safety is the
// execution-time cost of the lockstep comparison path.
// -----------------------------------------------------------------------------
module safety_riscv_soc_profile_perf_tb;

  localparam logic [31:0] SUMMARY_OFFSET = 32'h00003FC0;
  localparam logic [31:0] PASS_MARKER    = 32'h42545053;
  localparam logic [31:0] FAIL_MARKER    = 32'hBAD50001;
  localparam int          IDLE_BEATS     = 16;
  localparam int          TIMEOUT_CYCLES = 400000;

  logic       clk   = 1'b0;
  logic       rst_n = 1'b0;
  logic [7:0] board_ctrl = 8'h00;

  wire [1:0]  selected_profile;
  wire        profile_valid;
  wire        dcls_enable;
  wire        fault_injection_enable;
  wire        fault_latched;
  wire [7:0]  fault_code;
  wire        safe_state_req;
  wire        heartbeat_update;

  always #5 clk = ~clk;

  safety_riscv_soc_stage4f #(
      .MemInitFile (`FW_STAGE5_BATTERY_MONITOR_DEMO)
  ) dut (
      .clk_i                                 (clk),
      .rst_ni                                (rst_n),
      .fault_inject_target_i                 (2'b00),
      .fault_inject_mask_i                   (32'b0),
      .core_b_response_fault_inject_target_i (3'b111),
      .core_b_response_fault_inject_mask_i   (32'b0),
      .exec_stall_inject_i                   (1'b0),
      .board_ctrl_i                          (board_ctrl),
      .log_rd_index_i                        (2'b00),
      .selected_profile_o                    (selected_profile),
      .profile_valid_o                       (profile_valid),
      .dcls_enable_o                         (dcls_enable),
      .fault_injection_enable_o              (fault_injection_enable),
      .fault_latched_o                       (fault_latched),
      .fault_code_o                          (fault_code),
      .safe_state_req_o                      (safe_state_req),
      .heartbeat_update_o                    (heartbeat_update)
  );

  // Simulation-only RAM model initialisation (block RAM output latches
  // power up as zero on the FPGA).
  initial begin
    dut.core_a.u_ram.u_ram.a_rdata_o = '0;
    dut.core_a.u_ram.u_ram.b_rdata_o = '0;
    dut.core_b.u_ram.u_ram.a_rdata_o = '0;
    dut.core_b.u_ram.u_ram.b_rdata_o = '0;
  end

  wire core_a_marker_write;
  wire core_b_marker_write;

  assign core_a_marker_write =
      dut.core_a.u_ram.a_req_i && dut.core_a.u_ram.a_we_i &&
      (dut.core_a.u_ram.a_addr_i == SUMMARY_OFFSET);
  assign core_b_marker_write =
      dut.core_b.u_ram.a_req_i && dut.core_b.u_ram.a_we_i &&
      (dut.core_b.u_ram.a_addr_i == SUMMARY_OFFSET);

  int cycles_to_pass [3];
  int idle_period_x16 [3];
  int heartbeats_to_pass [3];

  task automatic run_profile(input int p, input string name);
    int cycles;
    int beats;
    int idle_start;
    int idle_beats;
    bit passed;

    // Reset with the requested profile on the board-control input.
    rst_n = 1'b0;
    board_ctrl = {6'b0, p[1:0]};
    repeat (8) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    cycles = 0;
    beats = 0;
    passed = 1'b0;

    while (!passed) begin
      @(posedge clk);
      cycles++;
      if (heartbeat_update) beats++;

      if (fault_latched || safe_state_req)
        $fatal(1, "%s: unexpected fault %02h during the workload", name, fault_code);

      if (core_a_marker_write && (dut.core_a.u_ram.a_wdata_i == FAIL_MARKER))
        $fatal(1, "%s: workload reported FAIL", name);

      if (core_a_marker_write && (dut.core_a.u_ram.a_wdata_i == PASS_MARKER)) begin
        if (!core_b_marker_write || (dut.core_b.u_ram.a_wdata_i != PASS_MARKER))
          $fatal(1, "%s: Core B did not write PASS in the same cycle as Core A", name);
        passed = 1'b1;
      end

      if (cycles > TIMEOUT_CYCLES)
        $fatal(1, "%s: workload did not finish", name);
    end

    if (selected_profile !== p[1:0] || profile_valid !== 1'b1)
      $fatal(1, "%s: wrong active profile %b", name, selected_profile);
    if (dcls_enable !== (p != 0))
      $fatal(1, "%s: lockstep comparison enable is %b", name, dcls_enable);
    if (fault_injection_enable !== (p == 2))
      $fatal(1, "%s: fault-injection enable is %b", name, fault_injection_enable);

    cycles_to_pass[p]     = cycles;
    heartbeats_to_pass[p] = beats;

    // Idle heartbeat loop: cycles for IDLE_BEATS heartbeats.
    @(posedge clk);
    while (!heartbeat_update) @(posedge clk);
    idle_start = 0;
    idle_beats = 0;
    while (idle_beats < IDLE_BEATS) begin
      @(posedge clk);
      idle_start++;
      if (heartbeat_update) idle_beats++;
      if (fault_latched)
        $fatal(1, "%s: unexpected fault in the idle loop", name);
      if (idle_start > TIMEOUT_CYCLES)
        $fatal(1, "%s: idle heartbeat stopped", name);
    end
    idle_period_x16[p] = idle_start;

    $display("PROFILE PERFORMANCE: %-10s workload = %0d cycles (%0d heartbeats), idle heartbeat period = %0.2f cycles",
             name, cycles, beats, real'(idle_start) / IDLE_BEATS);
  endtask

  initial begin
    real work_overhead;
    real idle_overhead;

    run_profile(0, "Basic");
    run_profile(1, "Safety");
    run_profile(2, "Diagnostic");

    work_overhead = 100.0 * (cycles_to_pass[1] - cycles_to_pass[0]) / cycles_to_pass[0];
    idle_overhead = 100.0 * (idle_period_x16[1] - idle_period_x16[0]) / idle_period_x16[0];

    if (cycles_to_pass[1] < cycles_to_pass[0])
      $fatal(1, "Safety profile was faster than Basic: measurement is not credible");

    $display("");
    $display("==============================================================");
    $display("PROFILE PERFORMANCE COMPARISON (same workload, same SoC)");
    $display("  Basic      : %0d cycles", cycles_to_pass[0]);
    $display("  Safety     : %0d cycles  (+%0.2f %% vs Basic)", cycles_to_pass[1], work_overhead);
    $display("  Diagnostic : %0d cycles", cycles_to_pass[2]);
    $display("  Idle heartbeat loop, Safety vs Basic: +%0.2f %%", idle_overhead);
    $display("  At 40 MHz: Basic %0.1f us, Safety %0.1f us",
             cycles_to_pass[0] * 0.025, cycles_to_pass[1] * 0.025);
    $display("PROFILE PERFORMANCE TEST: PASS");
    $display("==============================================================");
    $finish;
  end

endmodule

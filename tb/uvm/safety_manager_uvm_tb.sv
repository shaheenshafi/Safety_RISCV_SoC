`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// UVM testbench top for the central safety manager.
//
// Design under test: the three Verilog modules that form the central safety
// manager, connected as they are inside the SoC:
//   execution supervisor -> fault manager -> diagnostic logger
// with supervision disabled once safe state is requested.
//
// Small supervisor windows (4 / 16 / 16 cycles) keep the simulation short;
// the logic is identical to the SoC configuration (4 / 256 / 256).
// -----------------------------------------------------------------------------
module safety_manager_uvm_tb;

  import uvm_pkg::*;
  import safety_manager_pkg::*;

  logic clk = 1'b0;
  always #5 clk = ~clk;

  safety_manager_if sm_if (.clk(clk));

  wire supervisor_enable;
  assign supervisor_enable = sm_if.enable & ~sm_if.safe_state;

  safety_execution_supervisor #(
      .MIN_KICK_CYCLES         (safety_manager_pkg::MIN_KICK_CYCLES),
      .MAX_KICK_CYCLES         (safety_manager_pkg::MAX_KICK_CYCLES),
      .PROGRESS_TIMEOUT_CYCLES (safety_manager_pkg::PROGRESS_TIMEOUT_CYCLES)
  ) u_execution_supervisor (
      .clk_i                    (clk),
      .rst_ni                   (sm_if.rst_n),
      .enable_i                 (supervisor_enable),
      .watchdog_kick_i          (sm_if.kick),
      .progress_event_i         (sm_if.progress),
      .watchdog_early_fault_o   (sm_if.wd_early),
      .watchdog_timeout_fault_o (sm_if.wd_timeout),
      .progress_timeout_fault_o (sm_if.progress_timeout),
      .supervisor_fault_o       (sm_if.supervisor_fault)
  );

  safety_fault_manager_stage4f u_fault_manager (
      .clk_i                               (clk),
      .rst_ni                              (sm_if.rst_n),
      .dcls_instr_mismatch_i               (sm_if.instr_mismatch),
      .dcls_data_mismatch_i                (sm_if.data_mismatch),
      .supervisor_fault_i                  (sm_if.supervisor_fault),
      .core_a_double_fault_i               (sm_if.core_a_double),
      .core_b_double_fault_i               (sm_if.core_b_double),
      .config_integrity_fault_i            (sm_if.config_integrity),
      .mmio_replica_integrity_fault_i      (sm_if.mmio_replica),
      .fault_latched_o                     (sm_if.fault_latched),
      .instr_fault_seen_o                  (sm_if.instr_seen),
      .data_fault_seen_o                   (sm_if.data_seen),
      .supervisor_fault_seen_o             (sm_if.supervisor_seen),
      .core_a_double_fault_seen_o          (sm_if.core_a_double_seen),
      .core_b_double_fault_seen_o          (sm_if.core_b_double_seen),
      .config_integrity_fault_seen_o       (sm_if.config_seen),
      .mmio_replica_integrity_fault_seen_o (sm_if.mmio_replica_seen),
      .fault_code_o                        (sm_if.fault_code),
      .safe_state_req_o                    (sm_if.safe_state)
  );

  safety_diagnostic_logger #(
      .DEPTH_LOG2 (2),
      .TIME_WIDTH (40)
  ) u_diagnostic_logger (
      .clk_i           (clk),
      .rst_ni          (sm_if.rst_n),
      .fault_latched_i (sm_if.fault_latched),
      .fault_code_i    (sm_if.fault_code),
      .profile_i       (sm_if.profile),
      .boot_count_o    (sm_if.boot_count),
      .fault_count_o   (sm_if.fault_count),
      .rd_index_i      (sm_if.rd_index),
      .rd_valid_o      (sm_if.rd_valid),
      .rd_boot_o       (sm_if.rd_boot),
      .rd_code_o       (sm_if.rd_code),
      .rd_profile_o    (sm_if.rd_profile),
      .rd_time_o       (sm_if.rd_time)
  );

  // ---------------------------------------------------------------------------
  // Deliberate design errors for the checker sensitivity test (+MUTATION=n).
  // Each one breaks a connection between two modules of the safety manager,
  // which is the kind of integration error a module-level check cannot see.
  //   1  supervisor fault never reaches the fault manager
  //   2  latched fault never reaches the diagnostic logger / safe-state output
  //   3  fault code output stuck at 01
  // Not used in the normal test.
  // ---------------------------------------------------------------------------
  initial begin
    int mutation;
    if ($value$plusargs("MUTATION=%d", mutation)) begin
      case (mutation)
        1: force sm_if.supervisor_fault = 1'b0;
        2: force sm_if.fault_latched    = 1'b0;
        3: force sm_if.fault_code       = 8'h01;
        default: ;
      endcase
      $display("TESTBENCH: design mutation %0d is active", mutation);
    end
  end

  initial begin
    uvm_config_db #(virtual safety_manager_if)::set(null, "*", "vif", sm_if);
    run_test("safety_manager_full_test");
  end

endmodule

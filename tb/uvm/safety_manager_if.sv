`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Interface between the UVM environment and the central safety manager
// (fault manager + execution supervisor + diagnostic logger).
//
// The driver changes the inputs on the falling clock edge. The monitor samples
// through a clocking block just before each rising edge, so one sample holds
// the inputs the design uses at that edge and the outputs produced by the
// previous edge. This is free of simulation races.
// -----------------------------------------------------------------------------
interface safety_manager_if (input logic clk);

  // Inputs of the design
  logic       rst_n            = 1'b0;
  logic       enable           = 1'b0;
  logic       kick             = 1'b0;
  logic       progress         = 1'b0;
  logic       instr_mismatch   = 1'b0;
  logic       data_mismatch    = 1'b0;
  logic       core_a_double    = 1'b0;
  logic       core_b_double    = 1'b0;
  logic       config_integrity = 1'b0;
  logic       mmio_replica     = 1'b0;
  logic [1:0] profile          = 2'b00;
  logic [1:0] rd_index         = 2'b00;

  // Outputs of the design
  logic       fault_latched;
  logic [7:0] fault_code;
  logic       safe_state;
  logic       instr_seen;
  logic       data_seen;
  logic       supervisor_seen;
  logic       core_a_double_seen;
  logic       core_b_double_seen;
  logic       config_seen;
  logic       mmio_replica_seen;
  logic       wd_early;
  logic       wd_timeout;
  logic       progress_timeout;
  logic       supervisor_fault;
  logic [7:0] boot_count;
  logic [7:0] fault_count;
  logic       rd_valid;
  logic [7:0] rd_boot;
  logic [7:0] rd_code;
  logic [1:0] rd_profile;
  logic [39:0] rd_time;

  clocking mon_cb @(posedge clk);
    input rst_n, enable, kick, progress, instr_mismatch, data_mismatch,
          core_a_double, core_b_double, config_integrity, mmio_replica,
          profile, rd_index;
    input fault_latched, fault_code, safe_state, instr_seen, data_seen,
          supervisor_seen, core_a_double_seen, core_b_double_seen,
          config_seen, mmio_replica_seen, wd_early, wd_timeout,
          progress_timeout, supervisor_fault, boot_count, fault_count,
          rd_valid, rd_boot, rd_code, rd_profile, rd_time;
  endclocking

endinterface

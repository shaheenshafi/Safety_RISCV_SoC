`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// SystemVerilog assertions for the fault manager, attached with 'bind'.
// The Verilog design file is not modified.
//
// FM1  A latched fault stays latched until reset.
// FM2  Any fault input is latched on the next clock edge (1-cycle reaction).
// FM3  The fault code does not change once a fault is latched.
// FM4  A latched fault always has a non-zero fault code.
// FM5  A fault is never latched without a fault input in the previous cycle.
// FM6  The safe-state request equals the latched-fault flag.
// FM7  Fault-code priority: instruction > data > supervisor.
// FM8  With no fault latched, the code and all source flags are zero.
// -----------------------------------------------------------------------------
module sva_fault_manager (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       dcls_instr_mismatch_i,
    input logic       dcls_data_mismatch_i,
    input logic       supervisor_fault_i,
    input logic       core_a_double_fault_i,
    input logic       core_b_double_fault_i,
    input logic       config_integrity_fault_i,
    input logic       mmio_replica_integrity_fault_i,
    input logic       fault_latched_o,
    input logic       instr_fault_seen_o,
    input logic       data_fault_seen_o,
    input logic       supervisor_fault_seen_o,
    input logic [7:0] fault_code_o,
    input logic       safe_state_req_o
);

  logic any_fault_in;
  assign any_fault_in =
      dcls_instr_mismatch_i | dcls_data_mismatch_i | supervisor_fault_i |
      core_a_double_fault_i | core_b_double_fault_i |
      config_integrity_fault_i | mmio_replica_integrity_fault_i;

  a_fm1_sticky: assert property (@(posedge clk_i) disable iff (!rst_ni)
      fault_latched_o |=> fault_latched_o)
    else $error("SVA FM1: latched fault was cleared without reset");

  a_fm2_one_cycle: assert property (@(posedge clk_i) disable iff (!rst_ni)
      any_fault_in |=> fault_latched_o)
    else $error("SVA FM2: fault input was not latched on the next clock edge");

  a_fm3_code_stable: assert property (@(posedge clk_i) disable iff (!rst_ni)
      fault_latched_o |=> $stable(fault_code_o))
    else $error("SVA FM3: fault code changed after the fault was latched");

  a_fm4_code_nonzero: assert property (@(posedge clk_i) disable iff (!rst_ni)
      fault_latched_o |-> (fault_code_o != 8'h00))
    else $error("SVA FM4: latched fault has fault code 00");

  a_fm5_no_spurious: assert property (@(posedge clk_i) disable iff (!rst_ni)
      $rose(fault_latched_o) |-> $past(any_fault_in))
    else $error("SVA FM5: fault latched without a fault input");

  a_fm6_safe_state: assert property (@(posedge clk_i) disable iff (!rst_ni)
      safe_state_req_o == fault_latched_o)
    else $error("SVA FM6: safe-state request differs from latched fault");

  a_fm7a_priority_instr: assert property (@(posedge clk_i) disable iff (!rst_ni)
      ($rose(fault_latched_o) && $past(dcls_instr_mismatch_i))
      |-> (fault_code_o == 8'h01))
    else $error("SVA FM7a: instruction mismatch did not give code 01");

  a_fm7b_priority_data: assert property (@(posedge clk_i) disable iff (!rst_ni)
      ($rose(fault_latched_o) && !$past(dcls_instr_mismatch_i) &&
       $past(dcls_data_mismatch_i))
      |-> (fault_code_o == 8'h02))
    else $error("SVA FM7b: data mismatch did not give code 02");

  a_fm7c_priority_supervisor: assert property (@(posedge clk_i) disable iff (!rst_ni)
      ($rose(fault_latched_o) && !$past(dcls_instr_mismatch_i) &&
       !$past(dcls_data_mismatch_i) && $past(supervisor_fault_i))
      |-> (fault_code_o == 8'h03))
    else $error("SVA FM7c: supervisor fault did not give code 03");

  a_fm8_clean: assert property (@(posedge clk_i) disable iff (!rst_ni)
      !fault_latched_o |-> ((fault_code_o == 8'h00) && !instr_fault_seen_o &&
                            !data_fault_seen_o && !supervisor_fault_seen_o))
    else $error("SVA FM8: code or source flag set without a latched fault");

  // Activity counters: how often each property was really exercised.
  int unsigned n_fault_inputs = 0;
  int unsigned n_latched_cycles = 0;
  int unsigned n_latch_events = 0;

  logic latched_prev = 1'b0;

  always @(posedge clk_i) begin
    latched_prev <= rst_ni & fault_latched_o;
    if (rst_ni) begin
      if (any_fault_in)    n_fault_inputs++;
      if (fault_latched_o) n_latched_cycles++;
      if (fault_latched_o && !latched_prev) n_latch_events++;
    end
  end

  final $display("SVA fault manager: 10 properties; fault-input cycles=%0d, latch events=%0d, latched cycles=%0d",
                 n_fault_inputs, n_latch_events, n_latched_cycles);

endmodule

bind safety_fault_manager_stage4f sva_fault_manager u_sva_fault_manager (
    .clk_i                          (clk_i),
    .rst_ni                         (rst_ni),
    .dcls_instr_mismatch_i          (dcls_instr_mismatch_i),
    .dcls_data_mismatch_i           (dcls_data_mismatch_i),
    .supervisor_fault_i             (supervisor_fault_i),
    .core_a_double_fault_i          (core_a_double_fault_i),
    .core_b_double_fault_i          (core_b_double_fault_i),
    .config_integrity_fault_i       (config_integrity_fault_i),
    .mmio_replica_integrity_fault_i (mmio_replica_integrity_fault_i),
    .fault_latched_o                (fault_latched_o),
    .instr_fault_seen_o             (instr_fault_seen_o),
    .data_fault_seen_o              (data_fault_seen_o),
    .supervisor_fault_seen_o        (supervisor_fault_seen_o),
    .fault_code_o                   (fault_code_o),
    .safe_state_req_o               (safe_state_req_o)
);

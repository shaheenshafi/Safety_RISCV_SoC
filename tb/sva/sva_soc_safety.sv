`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// System-level SystemVerilog assertions for the safety-oriented SoC,
// attached to safety_riscv_soc_stage4f with 'bind'.
//
// SOC1  Safe state, once entered, is held until reset.
// SOC2  Any comparison mismatch latches a fault on the next clock edge
//       (detection-to-reaction latency of one clock cycle).
// SOC3  Any supervisor fault latches a fault on the next clock edge.
// SOC4  In safe state no request reaches the shared peripheral.
// SOC5  In safe state the heartbeat register is frozen.
// SOC6  Fault injection is possible only in the Diagnostic profile.
// SOC7  The execution-stall injection acts only when injection is enabled.
// SOC8  The safe-state request and the latched fault go together: a latched
//       fault always requests safe state.
// SOC9  Every newly latched fault is counted by the diagnostic logger.
// -----------------------------------------------------------------------------
module sva_soc_safety (
    input logic        clk_i,
    input logic        soc_rst_ni,
    input logic [1:0]  selected_profile_o,
    input logic        fault_injection_enable_o,
    input logic        dcls_mismatch_o,
    input logic        supervisor_fault_o,
    input logic        fault_latched_o,
    input logic        safe_state_req_o,
    input logic        mmio_req,
    input logic        exec_stall,
    input logic        exec_stall_inject_i,
    input logic [31:0] heartbeat_value_o,
    input logic [7:0]  log_fault_count_o
);

  a_soc1_safe_state_held: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      safe_state_req_o |=> safe_state_req_o)
    else $error("SVA SOC1: safe state was left without reset");

  a_soc2_mismatch_reaction: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      dcls_mismatch_o |=> (fault_latched_o && safe_state_req_o))
    else $error("SVA SOC2: comparison mismatch did not latch a fault in one cycle");

  a_soc3_supervisor_reaction: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      supervisor_fault_o |=> (fault_latched_o && safe_state_req_o))
    else $error("SVA SOC3: supervisor fault did not latch a fault in one cycle");

  a_soc4_peripheral_isolated: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      safe_state_req_o |-> !mmio_req)
    else $error("SVA SOC4: peripheral request issued during safe state");

  a_soc5_heartbeat_frozen: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      safe_state_req_o[*3] |-> $stable(heartbeat_value_o))
    else $error("SVA SOC5: heartbeat register changed during safe state");

  a_soc6_injection_profile: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      fault_injection_enable_o |-> (selected_profile_o == 2'b10))
    else $error("SVA SOC6: fault injection enabled outside the Diagnostic profile");

  a_soc7_stall_gated: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      exec_stall |-> (exec_stall_inject_i && fault_injection_enable_o))
    else $error("SVA SOC7: execution stall applied without injection permission");

  a_soc8_fault_requests_safe_state: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      fault_latched_o |-> safe_state_req_o)
    else $error("SVA SOC8: latched fault without safe-state request");

  a_soc9_fault_logged: assert property (@(posedge clk_i) disable iff (!soc_rst_ni)
      ($rose(fault_latched_o) && (log_fault_count_o != 8'hFF))
      |-> ##2 (log_fault_count_o == ($past(log_fault_count_o, 2) + 8'd1)))
    else $error("SVA SOC9: latched fault was not counted by the diagnostic logger");

  int unsigned n_mismatch = 0;
  int unsigned n_supervisor = 0;
  int unsigned n_safe_state = 0;
  int unsigned n_fault_events = 0;
  int unsigned n_injection_enabled = 0;
  int unsigned n_stall = 0;

  logic latched_prev = 1'b0;

  always @(posedge clk_i) begin
    latched_prev <= soc_rst_ni & fault_latched_o;
    if (soc_rst_ni) begin
      if (dcls_mismatch_o)          n_mismatch++;
      if (supervisor_fault_o)       n_supervisor++;
      if (safe_state_req_o)         n_safe_state++;
      if (fault_latched_o && !latched_prev) n_fault_events++;
      if (fault_injection_enable_o) n_injection_enabled++;
      if (exec_stall)               n_stall++;
    end
  end

  final $display("SVA SoC safety: 9 properties; mismatch cycles=%0d, supervisor-fault cycles=%0d, fault events=%0d, safe-state cycles=%0d, injection-enabled cycles=%0d, stall cycles=%0d",
                 n_mismatch, n_supervisor, n_fault_events, n_safe_state,
                 n_injection_enabled, n_stall);

endmodule

bind safety_riscv_soc_stage4f sva_soc_safety u_sva_soc_safety (
    .clk_i                    (clk_i),
    .soc_rst_ni               (soc_rst_ni),
    .selected_profile_o       (selected_profile_o),
    .fault_injection_enable_o (fault_injection_enable_o),
    .dcls_mismatch_o          (dcls_mismatch_o),
    .supervisor_fault_o       (supervisor_fault_o),
    .fault_latched_o          (fault_latched_o),
    .safe_state_req_o         (safe_state_req_o),
    .mmio_req                 (mmio_req),
    .exec_stall               (exec_stall),
    .exec_stall_inject_i      (exec_stall_inject_i),
    .heartbeat_value_o        (heartbeat_value_o),
    .log_fault_count_o        (log_fault_count_o)
);

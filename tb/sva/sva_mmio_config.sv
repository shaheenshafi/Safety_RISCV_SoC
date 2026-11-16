`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// SystemVerilog assertions for the runtime configuration register block
// (profiles and fault-injection authorisation), attached with 'bind'.
// Both replicated copies of the block are checked.
//
// MC1  Fault injection is enabled only in the Diagnostic profile, with
//      authorisation, and with intact configuration.
// MC2  Authorisation exists only in the Diagnostic profile.
// MC3  Every profile change clears the authorisation.
// MC4  In safe state the profile, the authorisation and the heartbeat
//      register cannot be changed.
// MC5  The reserved profile value or a failed integrity check is reported as
//      a configuration-integrity fault and forces the comparison ON.
// MC6  The Basic profile disables comparison; Safety and Diagnostic enable it.
// MC7  A heartbeat update is never reported in safe state.
// -----------------------------------------------------------------------------
module sva_mmio_config (
    input logic        clk_i,
    input logic        rst_ni,
    input logic        safe_state_i,
    input logic [1:0]  profile_o,
    input logic        injection_authorize_o,
    input logic        config_integrity_fault_o,
    input logic        profile_valid_o,
    input logic        dcls_enable_o,
    input logic        fault_injection_enable_o,
    input logic [31:0] heartbeat_value_o,
    input logic        heartbeat_update_o
);

  localparam logic [1:0] PROFILE_BASIC      = 2'b00;
  localparam logic [1:0] PROFILE_SAFETY     = 2'b01;
  localparam logic [1:0] PROFILE_DIAGNOSTIC = 2'b10;
  localparam logic [1:0] PROFILE_RESERVED   = 2'b11;

  a_mc1_injection_policy: assert property (@(posedge clk_i) disable iff (!rst_ni)
      fault_injection_enable_o |->
      ((profile_o == PROFILE_DIAGNOSTIC) && injection_authorize_o &&
       !config_integrity_fault_o))
    else $error("SVA MC1: fault injection enabled outside an authorised Diagnostic profile");

  a_mc2_authorise_only_diagnostic: assert property (@(posedge clk_i) disable iff (!rst_ni)
      (injection_authorize_o && !config_integrity_fault_o)
      |-> (profile_o == PROFILE_DIAGNOSTIC))
    else $error("SVA MC2: injection authorised outside the Diagnostic profile");

  a_mc3_change_clears_authorisation: assert property (@(posedge clk_i) disable iff (!rst_ni)
      ((profile_o != $past(profile_o)) && !config_integrity_fault_o)
      |-> !injection_authorize_o)
    else $error("SVA MC3: authorisation survived a profile change");

  a_mc4_locked_in_safe_state: assert property (@(posedge clk_i) disable iff (!rst_ni)
      (safe_state_i && !config_integrity_fault_o) |=>
      ($stable(profile_o) && $stable(injection_authorize_o) &&
       $stable(heartbeat_value_o)))
    else $error("SVA MC4: configuration or heartbeat changed during safe state");

  a_mc5_integrity_forces_comparison: assert property (@(posedge clk_i) disable iff (!rst_ni)
      ((profile_o == PROFILE_RESERVED) || config_integrity_fault_o)
      |-> (config_integrity_fault_o && dcls_enable_o && !profile_valid_o &&
           !fault_injection_enable_o))
    else $error("SVA MC5: invalid configuration not handled safely");

  a_mc6a_basic_no_comparison: assert property (@(posedge clk_i) disable iff (!rst_ni)
      ((profile_o == PROFILE_BASIC) && !config_integrity_fault_o) |-> !dcls_enable_o)
    else $error("SVA MC6a: comparison enabled in the Basic profile");

  a_mc6b_safety_comparison: assert property (@(posedge clk_i) disable iff (!rst_ni)
      (((profile_o == PROFILE_SAFETY) || (profile_o == PROFILE_DIAGNOSTIC)) &&
       !config_integrity_fault_o) |-> dcls_enable_o)
    else $error("SVA MC6b: comparison disabled in the Safety or Diagnostic profile");

  a_mc7_no_heartbeat_in_safe_state: assert property (@(posedge clk_i) disable iff (!rst_ni)
      safe_state_i |-> !heartbeat_update_o)
    else $error("SVA MC7: heartbeat update reported during safe state");

  int unsigned n_basic = 0;
  int unsigned n_safety = 0;
  int unsigned n_diagnostic = 0;
  int unsigned n_injection_enabled = 0;
  int unsigned n_profile_changes = 0;
  int unsigned n_safe_state = 0;
  int unsigned n_integrity_fault = 0;

  logic [1:0] profile_prev = 2'b00;

  always @(posedge clk_i) begin
    profile_prev <= profile_o;
    if (rst_ni) begin
      if (profile_o == PROFILE_BASIC)      n_basic++;
      if (profile_o == PROFILE_SAFETY)     n_safety++;
      if (profile_o == PROFILE_DIAGNOSTIC) n_diagnostic++;
      if (fault_injection_enable_o)        n_injection_enabled++;
      if (profile_o != profile_prev)       n_profile_changes++;
      if (safe_state_i)                    n_safe_state++;
      if (config_integrity_fault_o)        n_integrity_fault++;
    end
  end

  final $display("SVA configuration (%m): 8 properties; cycles Basic=%0d Safety=%0d Diagnostic=%0d, injection enabled=%0d, profile changes=%0d, safe-state cycles=%0d, integrity-fault cycles=%0d",
                 n_basic, n_safety, n_diagnostic, n_injection_enabled,
                 n_profile_changes, n_safe_state, n_integrity_fault);

endmodule

bind safety_mmio_config_stage4f sva_mmio_config u_sva_mmio_config (
    .clk_i                    (clk_i),
    .rst_ni                   (rst_ni),
    .safe_state_i             (safe_state_i),
    .profile_o                (profile_o),
    .injection_authorize_o    (injection_authorize_o),
    .config_integrity_fault_o (config_integrity_fault_o),
    .profile_valid_o          (profile_valid_o),
    .dcls_enable_o            (dcls_enable_o),
    .fault_injection_enable_o (fault_injection_enable_o),
    .heartbeat_value_o        (heartbeat_value_o),
    .heartbeat_update_o       (heartbeat_update_o)
);

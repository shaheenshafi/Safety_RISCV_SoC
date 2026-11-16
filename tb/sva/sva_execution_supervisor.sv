`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// SystemVerilog assertions for the execution supervisor (windowed watchdog
// and progress timeout), attached with 'bind'.
//
// SUP1  Each supervisor fault flag stays set until reset.
// SUP2  The combined fault output is the OR of the three flags.
// SUP3  No watchdog kick for MAX_KICK_CYCLES enabled cycles -> timeout fault.
// SUP4  A kick earlier than MIN_KICK_CYCLES -> early-service fault.
// SUP5  No progress event for PROGRESS_TIMEOUT_CYCLES enabled cycles ->
//       progress-timeout fault.
// SUP6  A supervisor fault is raised only while supervision is enabled.
//
// Note on SUP3 and SUP5: 'disable iff' uses the current reset value, so an
// attempt could start on the very clock edge at which reset is released,
// one cycle before the counters start. The sampled reset is therefore part
// of the sequence, so counting starts with the first cycle out of reset.
// -----------------------------------------------------------------------------
module sva_execution_supervisor #(
    parameter int MIN_KICK_CYCLES         = 4,
    parameter int MAX_KICK_CYCLES         = 16,
    parameter int PROGRESS_TIMEOUT_CYCLES = 16,
    parameter int AGE_WIDTH               = 5
) (
    input logic                 clk_i,
    input logic                 rst_ni,
    input logic                 enable_i,
    input logic                 watchdog_kick_i,
    input logic                 progress_event_i,
    input logic                 watchdog_early_fault_o,
    input logic                 watchdog_timeout_fault_o,
    input logic                 progress_timeout_fault_o,
    input logic                 supervisor_fault_o,
    input logic [AGE_WIDTH-1:0] watchdog_age_q
);

  a_sup1a_sticky: assert property (@(posedge clk_i) disable iff (!rst_ni)
      watchdog_early_fault_o |=> watchdog_early_fault_o)
    else $error("SVA SUP1a: early-service fault was cleared without reset");

  a_sup1b_sticky: assert property (@(posedge clk_i) disable iff (!rst_ni)
      watchdog_timeout_fault_o |=> watchdog_timeout_fault_o)
    else $error("SVA SUP1b: watchdog-timeout fault was cleared without reset");

  a_sup1c_sticky: assert property (@(posedge clk_i) disable iff (!rst_ni)
      progress_timeout_fault_o |=> progress_timeout_fault_o)
    else $error("SVA SUP1c: progress-timeout fault was cleared without reset");

  a_sup2_combined: assert property (@(posedge clk_i) disable iff (!rst_ni)
      supervisor_fault_o == (watchdog_early_fault_o | watchdog_timeout_fault_o |
                             progress_timeout_fault_o))
    else $error("SVA SUP2: combined supervisor fault is not the OR of its sources");

  a_sup3_watchdog_timeout: assert property (@(posedge clk_i) disable iff (!rst_ni)
      (rst_ni && enable_i && !watchdog_kick_i)[*MAX_KICK_CYCLES]
      |=> watchdog_timeout_fault_o)
    else $error("SVA SUP3: missing watchdog kick did not raise a timeout fault");

  a_sup4_early_kick: assert property (@(posedge clk_i) disable iff (!rst_ni)
      (enable_i && watchdog_kick_i && (watchdog_age_q < (MIN_KICK_CYCLES - 1)))
      |=> watchdog_early_fault_o)
    else $error("SVA SUP4: early watchdog kick did not raise an early-service fault");

  a_sup5_progress_timeout: assert property (@(posedge clk_i) disable iff (!rst_ni)
      (rst_ni && enable_i && !progress_event_i)[*PROGRESS_TIMEOUT_CYCLES]
      |=> progress_timeout_fault_o)
    else $error("SVA SUP5: missing progress event did not raise a timeout fault");

  a_sup6_only_when_enabled: assert property (@(posedge clk_i) disable iff (!rst_ni)
      $rose(supervisor_fault_o) |-> $past(enable_i))
    else $error("SVA SUP6: supervisor fault raised while supervision was disabled");

  int unsigned n_kicks = 0;
  int unsigned n_early_kicks = 0;
  int unsigned n_fault_events = 0;

  logic fault_prev = 1'b0;

  always @(posedge clk_i) begin
    fault_prev <= rst_ni & supervisor_fault_o;
    if (rst_ni) begin
      if (enable_i && watchdog_kick_i) n_kicks++;
      if (enable_i && watchdog_kick_i && (watchdog_age_q < (MIN_KICK_CYCLES - 1)))
        n_early_kicks++;
      if (supervisor_fault_o && !fault_prev) n_fault_events++;
    end
  end

  final $display("SVA execution supervisor: 8 properties; kicks=%0d, early kicks=%0d, supervisor fault events=%0d",
                 n_kicks, n_early_kicks, n_fault_events);

endmodule

bind safety_execution_supervisor sva_execution_supervisor #(
    .MIN_KICK_CYCLES         (MIN_KICK_CYCLES),
    .MAX_KICK_CYCLES         (MAX_KICK_CYCLES),
    .PROGRESS_TIMEOUT_CYCLES (PROGRESS_TIMEOUT_CYCLES),
    .AGE_WIDTH               (WATCHDOG_WIDTH)
) u_sva_execution_supervisor (
    .clk_i                    (clk_i),
    .rst_ni                   (rst_ni),
    .enable_i                 (enable_i),
    .watchdog_kick_i          (watchdog_kick_i),
    .progress_event_i         (progress_event_i),
    .watchdog_early_fault_o   (watchdog_early_fault_o),
    .watchdog_timeout_fault_o (watchdog_timeout_fault_o),
    .progress_timeout_fault_o (progress_timeout_fault_o),
    .supervisor_fault_o       (supervisor_fault_o),
    .watchdog_age_q           (watchdog_age_q)
);

`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// SystemVerilog assertions for the diagnostic logger, attached with 'bind'.
//
// LG1  Every newly latched fault adds exactly one record (the fault counter
//      increases by one unless it is saturated).
// LG2  Without a new fault the log is not written.
// LG3  Every reset release increases the boot counter by one (unless
//      saturated); otherwise the boot counter does not change.
// LG4  The system reset does not clear the log: counters never decrease.
// LG5  The number of valid records never exceeds the log depth.
// LG6  The stored record holds the fault code and profile of the fault.
//
// The retained registers have no reset, so these properties are checked
// from the second clock edge of the simulation and also during reset.
// -----------------------------------------------------------------------------
module sva_diagnostic_logger #(
    parameter int DEPTH_LOG2 = 2
) (
    input logic                  clk_i,
    input logic                  rst_ni,
    input logic [7:0]            fault_code_i,
    input logic [1:0]            profile_i,
    input logic                  boot_event,
    input logic                  fault_event,
    input logic [7:0]            boot_count_q,
    input logic [7:0]            fault_count_q,
    input logic [DEPTH_LOG2-1:0] wr_ptr_q,
    input logic [DEPTH_LOG2:0]   valid_count_q,
    input logic [DEPTH_LOG2-1:0] rd_index_i,
    input logic [7:0]            rd_code_o,
    input logic [1:0]            rd_profile_o
);

  // $past() has no defined value before the first clock edge.
  logic started = 1'b0;
  always @(posedge clk_i) started <= 1'b1;

  a_lg1_one_record_per_fault: assert property (@(posedge clk_i) disable iff (!started)
      (fault_event && (fault_count_q != 8'hFF))
      |=> ((fault_count_q == ($past(fault_count_q) + 8'd1)) &&
           (wr_ptr_q != $past(wr_ptr_q))))
    else $error("SVA LG1: a latched fault was not recorded exactly once");

  a_lg2_no_write_without_fault: assert property (@(posedge clk_i) disable iff (!started)
      !fault_event |=> ($stable(fault_count_q) && $stable(wr_ptr_q) &&
                        $stable(valid_count_q)))
    else $error("SVA LG2: the log changed without a new fault");

  a_lg3a_boot_counted: assert property (@(posedge clk_i) disable iff (!started)
      (boot_event && (boot_count_q != 8'hFF))
      |=> (boot_count_q == ($past(boot_count_q) + 8'd1)))
    else $error("SVA LG3a: reset release was not counted");

  a_lg3b_boot_stable: assert property (@(posedge clk_i) disable iff (!started)
      !boot_event |=> $stable(boot_count_q))
    else $error("SVA LG3b: boot counter changed without a reset release");

  a_lg4_retained: assert property (@(posedge clk_i) disable iff (!started)
      (fault_count_q >= $past(fault_count_q)) &&
      (boot_count_q  >= $past(boot_count_q)))
    else $error("SVA LG4: a retained counter decreased");

  a_lg5_depth: assert property (@(posedge clk_i) disable iff (!started)
      valid_count_q <= (1 << DEPTH_LOG2))
    else $error("SVA LG5: more valid records than the log depth");

  a_lg6_record_content: assert property (@(posedge clk_i) disable iff (!started)
      (fault_event ##1 (rd_index_i == '0))
      |-> ((rd_code_o == $past(fault_code_i)) &&
           (rd_profile_o == $past(profile_i))))
    else $error("SVA LG6: newest record does not hold the fault code and profile");

  int unsigned n_boots = 0;
  int unsigned n_faults = 0;
  int unsigned n_reset_cycles = 0;

  always @(posedge clk_i) begin
    if (boot_event)  n_boots++;
    if (fault_event) n_faults++;
    if (!rst_ni)     n_reset_cycles++;
  end

  final $display("SVA diagnostic logger: 7 properties; reset releases=%0d, faults recorded=%0d, clock cycles in reset=%0d",
                 n_boots, n_faults, n_reset_cycles);

endmodule

bind safety_diagnostic_logger sva_diagnostic_logger #(
    .DEPTH_LOG2 (DEPTH_LOG2)
) u_sva_diagnostic_logger (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .fault_code_i  (fault_code_i),
    .profile_i     (profile_i),
    .boot_event    (boot_event),
    .fault_event   (fault_event),
    .boot_count_q  (boot_count_q),
    .fault_count_q (fault_count_q),
    .wr_ptr_q      (wr_ptr_q),
    .valid_count_q (valid_count_q),
    .rd_index_i    (rd_index_i),
    .rd_code_o     (rd_code_o),
    .rd_profile_o  (rd_profile_o)
);

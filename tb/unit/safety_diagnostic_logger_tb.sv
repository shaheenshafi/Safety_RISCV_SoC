`timescale 1ns/1ps

// Unit test for the diagnostic logger.
//
// Checks: empty log after configuration, boot counting, one record per
// fault, record contents (boot number, code, profile, time), retention of
// the records through system reset, most-recent-first read order, and
// overwrite of the oldest record when more than four faults are logged.
module safety_diagnostic_logger_tb;

  logic        clk = 1'b0;
  logic        rst_n = 1'b0;
  logic        fault_latched = 1'b0;
  logic [7:0]  fault_code = 8'h00;
  logic [1:0]  profile = 2'b00;
  logic [1:0]  rd_index = 2'd0;

  wire [7:0]   boot_count;
  wire [7:0]   fault_count;
  wire         rd_valid;
  wire [7:0]   rd_boot;
  wire [7:0]   rd_code;
  wire [1:0]   rd_profile;
  wire [39:0]  rd_time;

  int checks = 0;

  always #5 clk = ~clk;

  safety_diagnostic_logger #(
      .DEPTH_LOG2 (2),
      .TIME_WIDTH (40)
  ) dut (
      .clk_i           (clk),
      .rst_ni          (rst_n),
      .fault_latched_i (fault_latched),
      .fault_code_i    (fault_code),
      .profile_i       (profile),
      .boot_count_o    (boot_count),
      .fault_count_o   (fault_count),
      .rd_index_i      (rd_index),
      .rd_valid_o      (rd_valid),
      .rd_boot_o       (rd_boot),
      .rd_code_o       (rd_code),
      .rd_profile_o    (rd_profile),
      .rd_time_o       (rd_time)
  );

  task automatic check(input bit condition, input string what);
    checks++;
    if (!condition)
      $fatal(1, "CHECK FAILED: %s", what);
  endtask

  // One run: release reset, optionally raise a fault after 'delay' cycles,
  // then assert reset again. The fault stays latched until reset, as it
  // does in the fault manager.
  task automatic run(input bit with_fault, input int delay,
                     input logic [7:0] code, input logic [1:0] prof);
    @(negedge clk);
    rst_n = 1'b1;
    profile = prof;
    repeat (delay) @(negedge clk);
    if (with_fault) begin
      fault_code = code;
      fault_latched = 1'b1;
    end
    repeat (6) @(negedge clk);
    rst_n = 1'b0;
    fault_latched = 1'b0;
    fault_code = 8'h00;
    repeat (3) @(negedge clk);
  endtask

  task automatic expect_record(input logic [1:0] index, input logic [7:0] boot,
                               input logic [7:0] code, input logic [1:0] prof);
    rd_index = index;
    #1;
    check(rd_valid === 1'b1, $sformatf("record %0d valid", index));
    check(rd_boot === boot, $sformatf("record %0d boot = %0d, got %0d", index, boot, rd_boot));
    check(rd_code === code, $sformatf("record %0d code = %02h, got %02h", index, code, rd_code));
    check(rd_profile === prof, $sformatf("record %0d profile", index));
  endtask

  initial begin
    // Empty after configuration.
    repeat (3) @(negedge clk);
    check(boot_count === 8'd0 && fault_count === 8'd0, "counters start at zero");
    rd_index = 2'd0; #1;
    check(rd_valid === 1'b0, "log starts empty");

    // Run 1: no fault.
    run(1'b0, 10, 8'h00, 2'b01);
    check(boot_count === 8'd1, "boot count after run 1");
    check(fault_count === 8'd0, "no fault logged in a fault-free run");

    // Run 2: instruction fault in Diagnostic after 20 cycles.
    run(1'b1, 20, 8'h01, 2'b10);
    check(boot_count === 8'd2, "boot count after run 2");
    check(fault_count === 8'd1, "one record per latched fault");
    expect_record(2'd0, 8'd2, 8'h01, 2'b10);
    check(rd_time >= 40'd19 && rd_time <= 40'd22,
          $sformatf("time stamp close to 20 cycles, got %0d", rd_time));
    rd_index = 2'd1; #1;
    check(rd_valid === 1'b0, "second record not yet valid");

    // Run 3: fault-free. The record of run 2 must survive the resets.
    run(1'b0, 10, 8'h00, 2'b01);
    check(boot_count === 8'd3, "boot count after run 3");
    expect_record(2'd0, 8'd2, 8'h01, 2'b10);

    // Runs 4 to 7: four more faults; the oldest record is overwritten.
    run(1'b1, 12, 8'h02, 2'b10);
    run(1'b1, 12, 8'h03, 2'b01);
    run(1'b1, 12, 8'h05, 2'b00);
    run(1'b1, 12, 8'h06, 2'b10);
    check(boot_count === 8'd7, "boot count after run 7");
    check(fault_count === 8'd5, "five faults counted");

    expect_record(2'd0, 8'd7, 8'h06, 2'b10);
    expect_record(2'd1, 8'd6, 8'h05, 2'b00);
    expect_record(2'd2, 8'd5, 8'h03, 2'b01);
    expect_record(2'd3, 8'd4, 8'h02, 2'b10);

    $display("PASS: safety_diagnostic_logger_tb (%0d checks)", checks);
    $finish;
  end

endmodule

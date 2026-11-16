`timescale 1ns/1ps

module safety_execution_supervisor_tb;

  reg clk;
  reg rst_n;
  reg enable;
  reg watchdog_kick;
  reg progress_event;

  wire watchdog_early_fault;
  wire watchdog_timeout_fault;
  wire progress_timeout_fault;
  wire supervisor_fault;

  integer checks = 0;

  safety_execution_supervisor #(
      .MIN_KICK_CYCLES        (3),
      .MAX_KICK_CYCLES        (6),
      .PROGRESS_TIMEOUT_CYCLES(5)
  ) dut (
      .clk_i                   (clk),
      .rst_ni                  (rst_n),
      .enable_i                (enable),
      .watchdog_kick_i         (watchdog_kick),
      .progress_event_i        (progress_event),
      .watchdog_early_fault_o  (watchdog_early_fault),
      .watchdog_timeout_fault_o(watchdog_timeout_fault),
      .progress_timeout_fault_o(progress_timeout_fault),
      .supervisor_fault_o      (supervisor_fault)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic reset_dut;
    begin
      @(negedge clk);
      rst_n = 1'b0;
      enable = 1'b0;
      watchdog_kick = 1'b0;
      progress_event = 1'b0;

      repeat (2) @(posedge clk);

      @(negedge clk);
      rst_n = 1'b1;
      enable = 1'b0;
      #1;

      if (watchdog_early_fault !== 1'b0 ||
          watchdog_timeout_fault !== 1'b0 ||
          progress_timeout_fault !== 1'b0 ||
          supervisor_fault !== 1'b0)
        $fatal(1, "Reset did not clear all supervisor faults");
    end
  endtask

  task automatic cycle(input logic kick, input logic progress);
    begin
      @(negedge clk);
      enable = 1'b1;
      watchdog_kick = kick;
      progress_event = progress;

      @(posedge clk);
      #1;
      watchdog_kick = 1'b0;
      progress_event = 1'b0;
    end
  endtask

  task automatic disable_one_cycle;
    begin
      @(negedge clk);
      enable = 1'b0;
      watchdog_kick = 1'b0;
      progress_event = 1'b0;

      @(posedge clk);
      #1;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    enable = 1'b0;
    watchdog_kick = 1'b0;
    progress_event = 1'b0;

    // Test 1: kick exactly at the minimum permitted cycle.
    reset_dut();
    cycle(1'b0, 1'b1);
    cycle(1'b0, 1'b1);
    cycle(1'b1, 1'b1);

    if (watchdog_early_fault ||
        watchdog_timeout_fault ||
        progress_timeout_fault ||
        supervisor_fault)
      $fatal(1, "Minimum-boundary watchdog kick failed");
    checks = checks + 1;
    $display("PASS: kick at minimum boundary accepted");

    // Test 2: kick exactly at the maximum permitted cycle.
    reset_dut();
    repeat (5) cycle(1'b0, 1'b1);
    cycle(1'b1, 1'b1);

    if (watchdog_early_fault ||
        watchdog_timeout_fault ||
        progress_timeout_fault ||
        supervisor_fault)
      $fatal(1, "Maximum-boundary watchdog kick failed");
    checks = checks + 1;
    $display("PASS: kick at maximum boundary accepted");

    // Test 3: early kick faults immediately and remains latched disabled.
    reset_dut();
    cycle(1'b1, 1'b1);

    if (!watchdog_early_fault || !supervisor_fault)
      $fatal(1, "Early watchdog service was not detected");

    disable_one_cycle();

    if (!watchdog_early_fault || !supervisor_fault)
      $fatal(1, "Early watchdog fault was not sticky while disabled");
    checks = checks + 1;
    $display("PASS: early-service fault is sticky");

    // Test 4: no watchdog kick by the maximum interval must time out.
    reset_dut();
    repeat (6) cycle(1'b0, 1'b1);

    if (!watchdog_timeout_fault || !supervisor_fault)
      $fatal(1, "Missing watchdog service was not detected");
    if (watchdog_early_fault || progress_timeout_fault)
      $fatal(1, "Unexpected fault during watchdog timeout test");
    checks = checks + 1;
    $display("PASS: watchdog timeout at maximum interval");

    // Test 5: a valid watchdog kick cannot hide a progress timeout.
    reset_dut();
    cycle(1'b0, 1'b0);
    cycle(1'b0, 1'b0);
    cycle(1'b1, 1'b0);
    cycle(1'b0, 1'b0);
    cycle(1'b0, 1'b0);

    if (!progress_timeout_fault || !supervisor_fault)
      $fatal(1, "Execution-progress timeout was not detected");
    if (watchdog_early_fault || watchdog_timeout_fault)
      $fatal(1, "Unexpected watchdog fault during progress timeout test");
    checks = checks + 1;
    $display("PASS: progress timeout independent of watchdog service");

    // Test 6: a progress event on the timeout boundary prevents timeout.
    reset_dut();
    repeat (4) cycle(1'b0, 1'b0);
    cycle(1'b0, 1'b1);

    if (progress_timeout_fault)
      $fatal(1, "Progress event on boundary did not reset progress timer");
    checks = checks + 1;
    $display("PASS: progress event accepted on timeout boundary");

    // Test 7: disabling clears timer phase before supervision resumes.
    reset_dut();
    cycle(1'b0, 1'b0);
    cycle(1'b0, 1'b0);
    disable_one_cycle();
    repeat (4) cycle(1'b0, 1'b0);

    if (watchdog_early_fault ||
        watchdog_timeout_fault ||
        progress_timeout_fault ||
        supervisor_fault)
      $fatal(1, "Disabled interval did not reset timer phase");
    checks = checks + 1;
    $display("PASS: disabling supervision resets timer phase");

    // Test 8: servicing after the deadline cannot clear a timeout.
    reset_dut();
    repeat (6) cycle(1'b0, 1'b1);

    if (!watchdog_timeout_fault)
      $fatal(1, "Watchdog timeout missing before late-service test");

    cycle(1'b1, 1'b1);

    if (!watchdog_timeout_fault || watchdog_early_fault ||
        progress_timeout_fault || !supervisor_fault)
      $fatal(1, "Late watchdog service changed timeout fault state");
    checks = checks + 1;
    $display("PASS: late watchdog kick cannot clear timeout");

    // Test 9: regular progress and valid watchdog service remain fault-free.
    reset_dut();
    cycle(1'b0, 1'b1);
    cycle(1'b0, 1'b1);
    cycle(1'b1, 1'b1);
    repeat (3) cycle(1'b0, 1'b1);
    cycle(1'b1, 1'b1);

    if (watchdog_early_fault ||
        watchdog_timeout_fault ||
        progress_timeout_fault ||
        supervisor_fault)
      $fatal(1, "Valid watchdog service and progress caused a fault");
    checks = checks + 1;
    $display("PASS: sustained progress and valid watchdog service");

    // Test 10: reset clears previously latched faults.
    reset_dut();
    cycle(1'b1, 1'b1);

    if (!watchdog_early_fault)
      $fatal(1, "Could not set early fault for reset test");

    reset_dut();

    if (watchdog_early_fault ||
        watchdog_timeout_fault ||
        progress_timeout_fault ||
        supervisor_fault)
      $fatal(1, "Reset failed to clear sticky faults");
    checks = checks + 1;
    $display("PASS: reset clears sticky faults");

    $display("STAGE 4F SUPERVISOR TEST PASS (%0d checks)", checks);
    $finish;
  end

endmodule

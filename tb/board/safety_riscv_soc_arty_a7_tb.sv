`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Board-level demonstration test
//
// Drives the Arty A7 wrapper exactly as a person would: reset button, slide
// switches and push buttons. It decodes the UART text and checks
//   - live profile switching Basic -> Safety -> Diagnostic from SW1..SW0,
//   - that an injection request is refused in Basic and in Safety,
//   - for each of the five injectable faults in Diagnostic: the injection is
//     applied, the expected fault code is latched and reported, and the
//     fault and safe-state LEDs are on,
//   - recovery by the reset button after every fault.
//
// UART speed, debounce time and status period are shortened by parameters so
// the simulation is fast. The logic is otherwise the FPGA logic.
// -----------------------------------------------------------------------------
module safety_riscv_soc_arty_a7_tb;

  localparam int  UART_CLKS_PER_BIT = 8;
  // One UART bit = 8 cycles of the 40 MHz SoC clock.
  localparam time BIT_TIME = 200ns;

  logic       clk   = 1'b0;   // 100 MHz board oscillator
  logic       reset = 1'b0;   // active low
  logic [3:0] sw    = 4'b0000;
  logic [3:0] btn   = 4'b0000;

  wire [3:0] led;
  wire [3:0] led_r;
  wire [3:0] led_g;
  wire [3:0] led_b;
  wire       uart_tx;

  always #5 clk = ~clk;

  safety_riscv_soc_arty_a7 #(
      .UART_CLKS_PER_BIT  (UART_CLKS_PER_BIT),
      .DEBOUNCE_BITS      (4),
      .STATUS_PERIOD_BITS (13),
      .HEARTBEAT_LED_BIT  (2)
  ) dut (
      .clk     (clk),
      .reset   (reset),
      .sw      (sw),
      .btn     (btn),
      .led     (led),
      .led_r   (led_r),
      .led_g   (led_g),
      .led_b   (led_b),
      .uart_tx (uart_tx)
  );

  // Simulation-only RAM model initialisation: a Xilinx block RAM output
  // latch powers up as zero; the generic model leaves it unknown.
  initial begin
    dut.u_safety_riscv_soc.core_a.u_ram.u_ram.a_rdata_o = '0;
    dut.u_safety_riscv_soc.core_a.u_ram.u_ram.b_rdata_o = '0;
    dut.u_safety_riscv_soc.core_b.u_ram.u_ram.a_rdata_o = '0;
    dut.u_safety_riscv_soc.core_b.u_ram.u_ram.b_rdata_o = '0;
  end

  // ---------------------------------------------------------------------------
  // UART receiver and line classifier
  // ---------------------------------------------------------------------------
  string line = "";
  string last_stat = "";
  string last_inj  = "";
  string last_flt  = "";
  int    n_boot = 0;
  int    n_stat = 0;
  int    n_inj  = 0;
  int    n_flt  = 0;

  function automatic bit contains(input string s, input string sub);
    int n;
    int m;
    n = s.len();
    m = sub.len();
    for (int i = 0; i + m <= n; i++) begin
      if (s.substr(i, i + m - 1) == sub)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  task automatic handle_line(input string s);
    $display("[%0t] UART: %s", $time, s);
    if (contains(s, "[BOOT]")) n_boot++;
    if (contains(s, "[STAT]")) begin last_stat = s; n_stat++; end
    if (contains(s, "[INJ ]")) begin last_inj  = s; n_inj++;  end
    if (contains(s, "[FLT ]")) begin last_flt  = s; n_flt++;  end
  endtask

  initial begin : uart_receiver
    logic [7:0] ch;
    forever begin
      @(negedge uart_tx);
      #(BIT_TIME / 2);                 // middle of the start bit
      for (int i = 0; i < 8; i++) begin
        #(BIT_TIME);
        ch[i] = uart_tx;
      end
      #(BIT_TIME);                     // middle of the stop bit
      if (ch == 8'h0A) begin
        if (line.len() > 0)
          handle_line(line);
        line = "";
      end else if (ch != 8'h0D) begin
        line = $sformatf("%s%c", line, ch);
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Board operations
  // ---------------------------------------------------------------------------
  localparam logic [1:0] PROFILE_BASIC      = 2'b00;
  localparam logic [1:0] PROFILE_SAFETY     = 2'b01;
  localparam logic [1:0] PROFILE_DIAGNOSTIC = 2'b10;

  task automatic press_reset;
    reset = 1'b0;
    repeat (40) @(posedge clk);
    reset = 1'b1;
  endtask

  task automatic press_button(input int index);
    btn[index] = 1'b1;
    repeat (200) @(posedge clk);
    btn[index] = 1'b0;
  endtask

  // Wait for a status line that contains all three texts.
  task automatic wait_status(input string a, input string b, input string c,
                             input string what);
    int waited;
    last_stat = "";
    waited = 0;
    while (!(contains(last_stat, a) && contains(last_stat, b) &&
             contains(last_stat, c))) begin
      @(posedge clk);
      waited++;
      if (waited > 1000000)
        $fatal(1, "%s: status not reported. Last status: %s", what, last_stat);
    end
  endtask

  task automatic wait_boot(input string what);
    int boot_before;
    int waited;
    boot_before = n_boot;
    press_reset();
    waited = 0;
    while (n_boot == boot_before) begin
      @(posedge clk);
      waited++;
      if (waited > 400000)
        $fatal(1, "%s: no boot banner on the UART", what);
    end
  endtask

  // An injection request in a profile that does not permit injection must
  // be reported as not applied and must not cause a fault.
  task automatic expect_refused(input string name);
    int inj_before;
    int flt_before;
    int waited;

    inj_before = n_inj;
    flt_before = n_flt;
    sw[3] = 1'b1;
    repeat (200) @(posedge clk);
    press_button(0);

    waited = 0;
    while (n_inj == inj_before) begin
      @(posedge clk);
      waited++;
      if (waited > 400000)
        $fatal(1, "%s: injection request was not reported", name);
    end

    if (!contains(last_inj, "APPLIED=0"))
      $fatal(1, "%s: injection should have been refused: %s", name, last_inj);

    wait_status("FAULT=00", "SAFE=0", "[STAT]", name);

    if (n_flt != flt_before || led[2] !== 1'b0 || led[3] !== 1'b0)
      $fatal(1, "%s: a fault was raised although injection is not permitted", name);

    sw[3] = 1'b0;
    $display("PASS: %s -> %s", name, last_inj);
  endtask

  // One fault in the Diagnostic profile, starting from a reset.
  task automatic run_fault(input int    button,
                           input logic  variant,
                           input string expected_code,
                           input string name);
    int flt_before;
    int waited;

    $display("");
    $display("---- Fault: %s (BTN%0d, SW2 = %b) ----", name, button, variant);

    btn = 4'b0000;
    sw  = {1'b0, variant, PROFILE_DIAGNOSTIC};
    wait_boot(name);
    wait_status("PROFILE=2", "INJ_EN=1", "FAULT=00", name);

    if (led[1] !== 1'b1 || led[2] !== 1'b0 || led[3] !== 1'b0)
      $fatal(1, "%s: LEDs wrong before injection: led=%b", name, led);

    flt_before = n_flt;
    sw[3] = 1'b1;
    repeat (200) @(posedge clk);
    press_button(button);

    waited = 0;
    while (n_flt == flt_before) begin
      @(posedge clk);
      waited++;
      if (waited > 800000)
        $fatal(1, "%s: no fault reported after injection. Last INJ line: %s", name, last_inj);
    end

    if (!contains(last_inj, "APPLIED=1"))
      $fatal(1, "%s: injection was not applied: %s", name, last_inj);

    if (!contains(last_flt, {"CODE=", expected_code}) ||
        !contains(last_flt, "SAFE_STATE=1"))
      $fatal(1, "%s: unexpected fault report: %s", name, last_flt);

    if (led[2] !== 1'b1 || led[3] !== 1'b1)
      $fatal(1, "%s: fault/safe-state LEDs not on: led=%b", name, led);

    $display("PASS: %s -> %s", name, last_flt);
  endtask

  initial begin
    // ------------------------------------------------------------------
    // Part 1: live profile switching from the switches, no reset between.
    // ------------------------------------------------------------------
    $display("");
    $display("---- Runtime profile selection from SW1..SW0 ----");
    sw = {2'b00, PROFILE_BASIC};
    wait_boot("Basic profile");
    wait_status("PROFILE=0", "DCLS=0", "INJ_EN=0", "Basic profile");
    if (led[1] !== 1'b0)
      $fatal(1, "Basic profile: DCLS LED should be off");
    $display("PASS: Basic profile -> %s", last_stat);
    expect_refused("Injection request in Basic profile");

    sw[1:0] = PROFILE_SAFETY;
    wait_status("PROFILE=1", "DCLS=1", "INJ_EN=0", "Safety profile");
    if (led[1] !== 1'b1)
      $fatal(1, "Safety profile: DCLS LED should be on");
    $display("PASS: Safety profile -> %s", last_stat);
    expect_refused("Injection request in Safety profile");

    sw[1:0] = PROFILE_DIAGNOSTIC;
    wait_status("PROFILE=2", "DCLS=1", "INJ_EN=1", "Diagnostic profile");
    wait_status("FAULT=00", "SAFE=0", "PROFILE=2", "Diagnostic profile");
    $display("PASS: Diagnostic profile -> %s", last_stat);

    // ------------------------------------------------------------------
    // Part 2: the five injectable faults, each followed by a reset.
    // ------------------------------------------------------------------
    run_fault(0, 1'b0, "01", "Tier 2 instruction-word fault on Core B");
    run_fault(1, 1'b0, "02", "Tier 2 read-data fault on Core B");
    run_fault(2, 1'b0, "01", "Tier 1 instruction-address fault at the comparator");
    run_fault(2, 1'b1, "02", "Tier 1 data-address fault at the comparator");
    run_fault(3, 1'b0, "03", "Execution stall (processor hang) caught by the watchdog");

    // Final recovery check.
    sw = {2'b00, PROFILE_SAFETY};
    wait_boot("Final recovery");
    wait_status("PROFILE=1", "FAULT=00", "SAFE=0", "Final recovery");

    $display("");
    $display("==============================================");
    $display("BOARD DEMONSTRATION TEST: PASS");
    $display("Runtime profiles selected by switch  : 3");
    $display("Injection refused outside Diagnostic : 2");
    $display("Faults injected by button            : 5");
    $display("Faults detected and reported on UART : 5");
    $display("Recovery by RESET button             : VERIFIED");
    $display("==============================================");
    $finish;
  end

endmodule

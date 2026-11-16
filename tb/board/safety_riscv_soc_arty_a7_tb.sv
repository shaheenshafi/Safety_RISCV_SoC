`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// Board-level demonstration test
//
// Drives the Arty A7 wrapper exactly as a person would: reset button, slide
// switches and push button. It decodes the UART text and checks, for each of
// the four selectable faults, that
//   - the firmware reaches the Diagnostic profile with injection authorised,
//   - the injection is applied,
//   - the expected fault code is latched and reported,
//   - the fault and safe-state LEDs are on.
//
// UART speed, debounce time and status period are shortened by parameters so
// the simulation is fast. The logic is otherwise the FPGA logic.
// -----------------------------------------------------------------------------
module safety_riscv_soc_arty_a7_tb;

  localparam int  UART_CLKS_PER_BIT = 8;
  // One UART bit = 8 cycles of the 50 MHz SoC clock.
  localparam time BIT_TIME = 160ns;

  logic       clk   = 1'b0;   // 100 MHz board oscillator
  logic       reset = 1'b0;   // active low
  logic [3:0] sw    = 4'b0000;
  logic [1:0] btn   = 2'b00;

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
  task automatic press_reset;
    reset = 1'b0;
    repeat (40) @(posedge clk);
    reset = 1'b1;
  endtask

  task automatic run_case(input logic [2:0] select,
                          input string       expected_code,
                          input string       name);
    int boot_before;
    int flt_before;
    int waited;

    $display("");
    $display("---- Case: %s (SW2..SW0 = %b) ----", name, select);

    sw  = 4'b0000;
    btn = 2'b00;
    boot_before = n_boot;
    last_stat   = "";
    press_reset();

    // 1. Boot banner after MMCM lock and reset release.
    waited = 0;
    while (n_boot == boot_before) begin
      @(posedge clk);
      waited++;
      if (waited > 400000)
        $fatal(1, "%s: no boot banner on the UART", name);
    end

    // 2. Firmware has selected Diagnostic and authorised injection.
    waited = 0;
    while (!(contains(last_stat, "PROFILE=2") &&
             contains(last_stat, "DCLS=1") &&
             contains(last_stat, "INJ_EN=1") &&
             contains(last_stat, "FAULT=00"))) begin
      @(posedge clk);
      waited++;
      if (waited > 800000)
        $fatal(1, "%s: Diagnostic profile with injection enabled not reported. Last status: %s",
               name, last_stat);
    end

    if (led[1] !== 1'b1 || led[2] !== 1'b0 || led[3] !== 1'b0)
      $fatal(1, "%s: LEDs wrong before injection: led=%b", name, led);

    // 3. Select the fault, arm, and press BTN0.
    flt_before = n_flt;
    sw = {1'b1, select};
    repeat (200) @(posedge clk);
    btn[0] = 1'b1;
    repeat (200) @(posedge clk);
    btn[0] = 1'b0;

    // 4. Fault report.
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
    run_case(3'b000, "01", "Tier 2 instruction-word fault on Core B");
    run_case(3'b001, "02", "Tier 2 read-data fault on Core B");
    run_case(3'b010, "01", "Tier 1 instruction-address fault at the comparator");
    run_case(3'b011, "02", "Tier 1 data-address fault at the comparator");
    run_case(3'b100, "01", "Tier 2 instruction-word fault, multi-bit mask");

    $display("");
    $display("==============================================");
    $display("BOARD DEMONSTRATION TEST: PASS");
    $display("Faults injected by switch and button : 5");
    $display("Faults detected and reported on UART : 5");
    $display("Recovery by RESET button             : VERIFIED");
    $display("==============================================");
    $finish;
  end

endmodule

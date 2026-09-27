`timescale 1ns/1ps

module safety_riscv_soc_stage3f_tb;

  // ==========================================================================
  // Clock and reset
  // ==========================================================================

  reg clk_i;
  reg rst_ni;

  // ==========================================================================
  // DCLS control
  // ==========================================================================

  reg dcls_enable_i;

  // ==========================================================================
  // Tier-1 observation-path fault injection
  // Disabled in this experiment.
  // ==========================================================================

  reg        fault_inject_enable_i;
  reg [1:0]  fault_inject_target_i;
  reg [31:0] fault_inject_mask_i;

  // ==========================================================================
  // Tier-2 Core-B response-path fault injection
  //
  // 3'b000 = INSTR_RDATA
  // 3'b001 = DATA_RDATA
  // ==========================================================================

  reg        core_b_response_fault_inject_enable_i;
  reg [2:0]  core_b_response_fault_inject_target_i;
  reg [31:0] core_b_response_fault_inject_mask_i;

  // ==========================================================================
  // DCLS outputs
  // ==========================================================================

  wire dcls_instr_mismatch_o;
  wire dcls_data_mismatch_o;
  wire dcls_mismatch_o;

  // ==========================================================================
  // Clock-cycle counter
  // ==========================================================================

  integer cycle_counter;

  // ==========================================================================
  // Fault/detection timing
  // ==========================================================================

  time fault_activation_time;
  time dcls_detection_time;

  integer fault_activation_cycle;
  integer dcls_detection_cycle;
  integer dcls_detection_latency_cycles;

  time dcls_detection_latency_ns;

  // ==========================================================================
  // Captured fault information
  // ==========================================================================

  reg [31:0] original_instruction;
  reg [31:0] injected_mask;
  reg [31:0] corrupted_instruction;

  reg fault_activation_seen;
  reg dcls_detection_seen;

  // ==========================================================================
  // Downstream execution evidence
  // ==========================================================================

  reg core_a_write_seen;
  reg core_b_write_seen;

  reg core_b_address_divergence_seen;

  reg [31:0] core_a_write_address;
  reg [31:0] core_b_write_address;

  reg [31:0] core_a_write_data;
  reg [31:0] core_b_write_data;

  // ==========================================================================
  // DUT
  // ==========================================================================

  safety_riscv_soc_stage3 dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),

      .dcls_enable_i(dcls_enable_i),

      // Tier-1 injection disabled.
      .fault_inject_enable_i(fault_inject_enable_i),
      .fault_inject_target_i(fault_inject_target_i),
      .fault_inject_mask_i(fault_inject_mask_i),

      // Tier-2 Core-B response injection.
      .core_b_response_fault_inject_enable_i(
          core_b_response_fault_inject_enable_i
      ),
      .core_b_response_fault_inject_target_i(
          core_b_response_fault_inject_target_i
      ),
      .core_b_response_fault_inject_mask_i(
          core_b_response_fault_inject_mask_i
      ),

      // DCLS outputs.
      .dcls_instr_mismatch_o(dcls_instr_mismatch_o),
      .dcls_data_mismatch_o(dcls_data_mismatch_o),
      .dcls_mismatch_o(dcls_mismatch_o)
  );

  // ==========================================================================
  // Clock generation
  // 10 ns period = 100 MHz
  // ==========================================================================

  initial begin
    clk_i = 1'b0;

    forever begin
      #5 clk_i = ~clk_i;
    end
  end

  // ==========================================================================
  // Cycle counter
  // ==========================================================================

  always @(posedge clk_i) begin
    cycle_counter = cycle_counter + 1;
  end

  // ==========================================================================
  // Tier-2 fault injection
  //
  // We deliberately target the first instruction:
  //
  //     LUI x1, 0x100
  //     0x001000B7
  //
  // Injecting 0x00001000 produces:
  //
  //     0x001010B7
  //
  // which changes Core B's write base address from:
  //
  //     0x00100000
  //
  // to:
  //
  //     0x00101000
  // ==========================================================================

  always @(negedge clk_i) begin

    if (rst_ni &&
        !fault_activation_seen &&
        !core_b_response_fault_inject_enable_i &&
        dut.core_b_instr_rvalid &&
        dut.core_b_instr_rdata === 32'h001000B7) begin

      // Capture the original instruction.
      original_instruction = dut.core_b_instr_rdata;

      // Single controlled instruction-response fault.
      injected_mask = 32'h00001000;

      // Calculate expected corrupted instruction.
      corrupted_instruction =
          original_instruction ^ injected_mask;

      // Record fault activation timing.
      fault_activation_time = $time;
      fault_activation_cycle = cycle_counter;

      fault_activation_seen = 1'b1;

      // Activate Core-B response fault injector.
      core_b_response_fault_inject_enable_i <= 1'b1;
      core_b_response_fault_inject_target_i <= 3'b000;
      core_b_response_fault_inject_mask_i   <= injected_mask;

      $display("--------------------------------------------------");
      $display(
        "[%0t] FAULT ACTIVATION",
        $time
      );
      $display(
        "Cycle                 : %0d",
        fault_activation_cycle
      );
      $display(
        "Original instruction  : 0x%08h",
        original_instruction
      );
      $display(
        "Injection mask        : 0x%08h",
        injected_mask
      );
      $display(
        "Expected corrupted    : 0x%08h",
        corrupted_instruction
      );
      $display("--------------------------------------------------");

    end

  end

  // ==========================================================================
  // Disable the injector after one response interval
  // ==========================================================================

  always @(posedge clk_i) begin

    if (core_b_response_fault_inject_enable_i) begin

      #1;

      core_b_response_fault_inject_enable_i = 1'b0;

      $display(
        "[%0t] Core-B response fault injector disabled after fault window",
        $time
      );

    end

  end

  // ==========================================================================
  // DCLS detection monitor
  //
  // Since the comparator is combinational, this event records when the
  // mismatch output first asserts.
  // ==========================================================================

  always @(posedge dcls_instr_mismatch_o) begin

    if (fault_activation_seen &&
        !dcls_detection_seen) begin

      dcls_detection_time = $time;
      dcls_detection_cycle = cycle_counter;

      dcls_detection_latency_ns =
          dcls_detection_time - fault_activation_time;

      dcls_detection_latency_cycles =
          dcls_detection_cycle - fault_activation_cycle;

      dcls_detection_seen = 1'b1;

      $display("--------------------------------------------------");
      $display(
        "[%0t] DCLS INSTRUCTION MISMATCH DETECTED",
        $time
      );
      $display(
        "Detection cycle       : %0d",
        dcls_detection_cycle
      );
      $display(
        "Detection latency     : %0d ns",
        dcls_detection_latency_ns
      );
      $display(
        "Detection latency     : %0d clock cycles",
        dcls_detection_latency_cycles
      );
      $display("--------------------------------------------------");

    end

  end

  // ==========================================================================
  // Core-A transaction monitor
  // ==========================================================================

  always @(posedge clk_i) begin

    #1;

    if (rst_ni &&
        dut.core_a_data_req &&
        dut.core_a_data_we &&
        !core_a_write_seen) begin

      core_a_write_seen = 1'b1;

      core_a_write_address = dut.core_a_data_addr;
      core_a_write_data    = dut.core_a_data_wdata;

      $display(
        "[%0t] CORE A WRITE: addr=0x%08h data=0x%08h",
        $time,
        core_a_write_address,
        core_a_write_data
      );

    end

  end

  // ==========================================================================
  // Core-B transaction monitor
  // ==========================================================================

  always @(posedge clk_i) begin

    #1;

    if (rst_ni &&
        dut.core_b_data_req &&
        dut.core_b_data_we &&
        !core_b_write_seen) begin

      core_b_write_seen = 1'b1;

      core_b_write_address = dut.core_b_data_addr;
      core_b_write_data    = dut.core_b_data_wdata;

      $display(
        "[%0t] CORE B WRITE: addr=0x%08h data=0x%08h",
        $time,
        core_b_write_address,
        core_b_write_data
      );

      if (core_b_write_address == 32'h00101000) begin

        core_b_address_divergence_seen = 1'b1;

        $display(
          "[%0t] CORE B ADDRESS DIVERGENCE CONFIRMED",
          $time
        );

      end

    end

  end

  // ==========================================================================
  // Main test sequence
  // ==========================================================================

  initial begin

    // ------------------------------------------------------------------------
    // Initial conditions
    // ------------------------------------------------------------------------

    rst_ni = 1'b0;

    dcls_enable_i = 1'b0;

    // Tier-1 disabled.
    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = 2'b11;
    fault_inject_mask_i   = 32'b0;

    // Tier-2 disabled.
    core_b_response_fault_inject_enable_i = 1'b0;
    core_b_response_fault_inject_target_i = 3'b000;
    core_b_response_fault_inject_mask_i   = 32'b0;

    cycle_counter = 0;

    fault_activation_time = 0;
    dcls_detection_time = 0;

    fault_activation_cycle = 0;
    dcls_detection_cycle = 0;
    dcls_detection_latency_cycles = 0;

    dcls_detection_latency_ns = 0;

    original_instruction = 32'b0;
    injected_mask = 32'b0;
    corrupted_instruction = 32'b0;

    fault_activation_seen = 1'b0;
    dcls_detection_seen = 1'b0;

    core_a_write_seen = 1'b0;
    core_b_write_seen = 1'b0;
    core_b_address_divergence_seen = 1'b0;

    core_a_write_address = 32'b0;
    core_b_write_address = 32'b0;

    core_a_write_data = 32'b0;
    core_b_write_data = 32'b0;

    // ------------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------------

    #20;

    rst_ni = 1'b1;
    dcls_enable_i = 1'b1;

    $display("==================================================");
    $display("STAGE3F DCLS DETECTION LATENCY EXPERIMENT");
    $display("==================================================");
    $display("[%0t] DCLS enabled", $time);
    $display(
      "[%0t] Waiting for Core-B instruction response",
      $time
    );

    // ------------------------------------------------------------------------
    // Wait for all required evidence.
    // ------------------------------------------------------------------------

    fork

      begin

        wait (
          fault_activation_seen &&
          dcls_detection_seen &&
          core_a_write_seen &&
          core_b_write_seen &&
          core_b_address_divergence_seen
        );

        // --------------------------------------------------------------
        // Validate Core A
        // --------------------------------------------------------------

        if (core_a_write_address !== 32'h00100000) begin

          $display(
            "[%0t] FAIL: Core A address = 0x%08h",
            $time,
            core_a_write_address
          );

          $fatal(1);

        end

        if (core_a_write_data !== 32'h0000002A) begin

          $display(
            "[%0t] FAIL: Core A data = 0x%08h",
            $time,
            core_a_write_data
          );

          $fatal(1);

        end

        // --------------------------------------------------------------
        // Validate Core B
        // --------------------------------------------------------------

        if (core_b_write_address !== 32'h00101000) begin

          $display(
            "[%0t] FAIL: Core B address = 0x%08h",
            $time,
            core_b_write_address
          );

          $fatal(1);

        end

        if (core_b_write_data !== 32'h0000002A) begin

          $display(
            "[%0t] FAIL: Core B data = 0x%08h",
            $time,
            core_b_write_data
          );

          $fatal(1);

        end

        // --------------------------------------------------------------
        // Validate DCLS
        // --------------------------------------------------------------

        if (!dcls_detection_seen) begin

          $display(
            "[%0t] FAIL: DCLS did not detect instruction mismatch",
            $time
          );

          $fatal(1);

        end

        if (dcls_mismatch_o !== 1'b1) begin

          $display(
            "[%0t] FAIL: DCLS overall mismatch not asserted",
            $time
          );

          $fatal(1);

        end

        // --------------------------------------------------------------
        // Final report
        // --------------------------------------------------------------

        $display("");
        $display("==================================================");
        $display("STAGE3F DCLS LATENCY MEASUREMENT PASS");
        $display("==================================================");
        $display(
          "Original instruction      : 0x%08h",
          original_instruction
        );
        $display(
          "Injected mask             : 0x%08h",
          injected_mask
        );
        $display(
          "Corrupted instruction     : 0x%08h",
          corrupted_instruction
        );
        $display(
          "Fault activation time     : %0t ns",
          fault_activation_time
        );
        $display(
          "DCLS detection time       : %0t ns",
          dcls_detection_time
        );
        $display(
          "DCLS assertion latency    : %0d ns",
          dcls_detection_latency_ns
        );
        $display(
          "DCLS assertion latency    : %0d clock cycles",
          dcls_detection_latency_cycles
        );
        $display(
          "Core A transaction        : 0x%08h / 0x%08h",
          core_a_write_address,
          core_a_write_data
        );
        $display(
          "Core B transaction        : 0x%08h / 0x%08h",
          core_b_write_address,
          core_b_write_data
        );
        $display(
          "Execution divergence      : CONFIRMED"
        );
        $display(
          "DCLS instruction detect   : CONFIRMED"
        );
        $display("==================================================");

        $finish;

      end

      begin

        // Timeout after 200 clock cycles.
        repeat (200) @(posedge clk_i);

        $display("");
        $display("==================================================");
        $display("STAGE3F DCLS LATENCY EXPERIMENT FAIL");
        $display("==================================================");
        $display(
          "fault_activation_seen        = %0d",
          fault_activation_seen
        );
        $display(
          "dcls_detection_seen          = %0d",
          dcls_detection_seen
        );
        $display(
          "core_a_write_seen            = %0d",
          core_a_write_seen
        );
        $display(
          "core_b_write_seen            = %0d",
          core_b_write_seen
        );
        $display(
          "core_b_address_divergence    = %0d",
          core_b_address_divergence_seen
        );
        $display("==================================================");

        $fatal(1);

      end

    join_any

    disable fork;

  end

endmodule

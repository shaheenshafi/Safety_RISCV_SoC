`timescale 1ns/1ps

module safety_riscv_soc_stage3_tb;

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
  //
  // 2'b00 = DATA_WDATA
  // 2'b01 = DATA_ADDR
  // 2'b10 = INSTR_ADDR
  // 2'b11 = RESERVED
  // ==========================================================================

  reg        fault_inject_enable_i;
  reg [1:0]  fault_inject_target_i;
  reg [31:0] fault_inject_mask_i;

  // ==========================================================================
  // Tier-2 Core-B response-path fault injection
  //
  // 3'b000 = INSTR_RDATA
  // 3'b001 = DATA_RDATA
  // others = RESERVED
  //
  // Disabled for this regression.
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
  // Test status
  // ==========================================================================

  integer phase;

  reg normal_transaction_seen;
  reg injected_transaction_seen;

  // ==========================================================================
  // DUT
  // ==========================================================================

  safety_riscv_soc_stage3 dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),

      .dcls_enable_i(dcls_enable_i),

      // Tier-1 observation-path injection
      .fault_inject_enable_i(fault_inject_enable_i),
      .fault_inject_target_i(fault_inject_target_i),
      .fault_inject_mask_i(fault_inject_mask_i),

      // Tier-2 Core-B response-path injection
      .core_b_response_fault_inject_enable_i(
          core_b_response_fault_inject_enable_i
      ),
      .core_b_response_fault_inject_target_i(
          core_b_response_fault_inject_target_i
      ),
      .core_b_response_fault_inject_mask_i(
          core_b_response_fault_inject_mask_i
      ),

      // DCLS outputs
      .dcls_instr_mismatch_o(dcls_instr_mismatch_o),
      .dcls_data_mismatch_o(dcls_data_mismatch_o),
      .dcls_mismatch_o(dcls_mismatch_o)
  );

  // ==========================================================================
  // Clock
  // ==========================================================================

  initial begin
    clk_i = 1'b0;

    forever begin
      #5 clk_i = ~clk_i;
    end
  end

  // ==========================================================================
  // Transaction monitor
  //
  // This continuously watches the actual Core-A data-write transaction.
  // Therefore we cannot accidentally miss the one-cycle write as happened
  // with the previous testbench.
  // ==========================================================================

  always @(posedge clk_i) begin

    // Small delay allows combinational signals and DCLS outputs to settle.
    #1;

    if (rst_ni) begin

      // ----------------------------------------------------------------------
      // Phase 1: normal redundant execution
      // ----------------------------------------------------------------------

      if ((phase == 1) &&
          dut.core_a_data_req &&
          dut.core_a_data_we &&
          !normal_transaction_seen) begin

        $display(
          "[%0t] NORMAL WRITE: A=0x%08h B=0x%08h B_cmp=0x%08h DCLS=%0d",
          $time,
          dut.core_a_data_wdata,
          dut.core_b_data_wdata,
          dut.core_b_data_wdata_cmp,
          dcls_mismatch_o
        );

        // Core A must generate 42.
        if (dut.core_a_data_wdata !== 32'h0000002A) begin
          $display(
            "[%0t] PHASE 1 FAIL: Core A expected 42",
            $time
          );
          $fatal(1);
        end

        // Core B must independently generate 42.
        if (dut.core_b_data_wdata !== 32'h0000002A) begin
          $display(
            "[%0t] PHASE 1 FAIL: Core B expected 42",
            $time
          );
          $fatal(1);
        end

        // With no injected fault, comparison path must also be 42.
        if (dut.core_b_data_wdata_cmp !== 32'h0000002A) begin
          $display(
            "[%0t] PHASE 1 FAIL: Core B comparison value expected 42",
            $time
          );
          $fatal(1);
        end

        // No divergence must be detected.
        if (dcls_mismatch_o !== 1'b0) begin
          $display(
            "[%0t] PHASE 1 FAIL: unexpected DCLS mismatch",
            $time
          );
          $fatal(1);
        end

        normal_transaction_seen = 1'b1;

        $display(
          "[%0t] PHASE 1 PASS: normal redundant write verified",
          $time
        );
      end

      // ----------------------------------------------------------------------
      // Phase 2: Tier-1 observation-path fault injection
      // ----------------------------------------------------------------------

      if ((phase == 2) &&
          dut.core_a_data_req &&
          dut.core_a_data_we &&
          !injected_transaction_seen) begin

        $display(
          "[%0t] INJECTED WRITE: A=0x%08h B_actual=0x%08h B_cmp=0x%08h DCLS_DATA=%0d DCLS=%0d",
          $time,
          dut.core_a_data_wdata,
          dut.core_b_data_wdata,
          dut.core_b_data_wdata_cmp,
          dcls_data_mismatch_o,
          dcls_mismatch_o
        );

        // Actual Core A execution remains correct.
        if (dut.core_a_data_wdata !== 32'h0000002A) begin
          $display(
            "[%0t] PHASE 2 FAIL: Core A expected 42",
            $time
          );
          $fatal(1);
        end

        // Actual Core B execution also remains correct.
        // Only its observation path is being corrupted.
        if (dut.core_b_data_wdata !== 32'h0000002A) begin
          $display(
            "[%0t] PHASE 2 FAIL: Core B actual value expected 42",
            $time
          );
          $fatal(1);
        end

        // 0x2A XOR 0x01 = 0x2B.
        if (dut.core_b_data_wdata_cmp !== 32'h0000002B) begin
          $display(
            "[%0t] PHASE 2 FAIL: expected B comparison value 0x2B",
            $time
          );
          $fatal(1);
        end

        // DCLS must detect the injected divergence.
        if (dcls_data_mismatch_o !== 1'b1) begin
          $display(
            "[%0t] PHASE 2 FAIL: DCLS data mismatch not detected",
            $time
          );
          $fatal(1);
        end

        if (dcls_mismatch_o !== 1'b1) begin
          $display(
            "[%0t] PHASE 2 FAIL: overall DCLS mismatch not detected",
            $time
          );
          $fatal(1);
        end

        injected_transaction_seen = 1'b1;

        $display(
          "[%0t] PHASE 2 PASS: injected observation-path fault detected",
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

    // Tier-1 disabled initially.
    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = 2'b11;
    fault_inject_mask_i   = 32'b0;

    // Tier-2 disabled.
    core_b_response_fault_inject_enable_i = 1'b0;
    core_b_response_fault_inject_target_i = 3'b111;
    core_b_response_fault_inject_mask_i   = 32'b0;

    phase = 0;

    normal_transaction_seen   = 1'b0;
    injected_transaction_seen = 1'b0;

    // ------------------------------------------------------------------------
    // Initial reset
    // ------------------------------------------------------------------------

    #20;

    // ------------------------------------------------------------------------
    // Phase 1: normal execution
    // ------------------------------------------------------------------------

    rst_ni = 1'b1;
    dcls_enable_i = 1'b1;

    phase = 1;

    $display("[%0t] Phase 1: normal redundant execution", $time);

    // Wait until the actual write transaction has been observed.
    wait (normal_transaction_seen == 1'b1);

    $display(
      "[%0t] Phase 1 complete: resetting SoC for injected-fault run",
      $time
    );

    // ------------------------------------------------------------------------
    // Reset before Phase 2
    // ------------------------------------------------------------------------

    phase = 0;

    rst_ni = 1'b0;

    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = 2'b11;
    fault_inject_mask_i   = 32'b0;

    core_b_response_fault_inject_enable_i = 1'b0;
    core_b_response_fault_inject_target_i = 3'b111;
    core_b_response_fault_inject_mask_i   = 32'b0;

    #20;

    // ------------------------------------------------------------------------
    // Phase 2: observation-path DATA_WDATA fault
    // ------------------------------------------------------------------------

    rst_ni = 1'b1;
    dcls_enable_i = 1'b1;

    phase = 2;

    fault_inject_enable_i = 1'b1;
    fault_inject_target_i = 2'b00;       // DATA_WDATA
    fault_inject_mask_i   = 32'h00000001;

    // Tier-2 remains disabled.
    core_b_response_fault_inject_enable_i = 1'b0;
    core_b_response_fault_inject_target_i = 3'b111;
    core_b_response_fault_inject_mask_i   = 32'b0;

    $display(
      "[%0t] Phase 2: DATA_WDATA fault injection enabled, mask = 0x%08h",
      $time,
      fault_inject_mask_i
    );

    // Wait for the actual injected transaction.
    wait (injected_transaction_seen == 1'b1);

    // ------------------------------------------------------------------------
    // Final result
    // ------------------------------------------------------------------------

    $display("==============================================");
    $display("STAGE3C END-TO-END FAULT INJECTION PASS");
    $display("Normal transaction        : PASS");
    $display("Injected transaction      : PASS");
    $display("DCLS data mismatch        : DETECTED");
    $display("DCLS overall mismatch     : DETECTED");
    $display("==============================================");

    $finish;
  end

endmodule

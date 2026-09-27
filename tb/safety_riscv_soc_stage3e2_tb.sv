`timescale 1ns/1ps

module safety_riscv_soc_stage3e2_tb;

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
  // Disabled for this experiment.
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
  // Test status flags
  // ==========================================================================

  reg fault_injection_seen;
  reg instruction_mismatch_seen;

  reg core_a_write_seen;
  reg core_b_write_seen;

  reg core_b_data_address_divergence_seen;

  // ==========================================================================
  // DUT
  // ==========================================================================

  safety_riscv_soc_stage3 dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),

      .dcls_enable_i(dcls_enable_i),

      // Tier-1 fault injection disabled.
      .fault_inject_enable_i(fault_inject_enable_i),
      .fault_inject_target_i(fault_inject_target_i),
      .fault_inject_mask_i(fault_inject_mask_i),

      // Tier-2 Core-B response fault injection.
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
  // ==========================================================================

  initial begin
    clk_i = 1'b0;

    forever begin
      #5 clk_i = ~clk_i;
    end
  end

  // ==========================================================================
  // Tier-2 fault activation
  //
  // The injector is activated only when Core B presents the original first
  // instruction response:
  //
  //     0x001000B7 = LUI x1, 0x100
  //
  // The injection remains active until the following rising edge, allowing
  // Core B to consume the corrupted instruction response.
  // ==========================================================================

  always @(negedge clk_i) begin

    if (rst_ni &&
        !fault_injection_seen &&
        !core_b_response_fault_inject_enable_i &&
        dut.core_b_instr_rvalid &&
        dut.core_b_instr_rdata === 32'h001000B7) begin

      core_b_response_fault_inject_enable_i <= 1'b1;
      core_b_response_fault_inject_target_i <= 3'b000;
      core_b_response_fault_inject_mask_i   <= 32'h00001000;

      $display(
        "[%0t] TIER-2 FAULT ARMED: Core B INSTR_RDATA = 0x%08h, mask = 0x%08h",
        $time,
        dut.core_b_instr_rdata,
        32'h00001000
      );

    end
    else if (core_b_response_fault_inject_enable_i) begin

      core_b_response_fault_inject_enable_i <= 1'b0;
      fault_injection_seen <= 1'b1;

      $display(
        "[%0t] TIER-2 FAULT APPLIED: corrupted Core-B instruction response",
        $time
      );

    end

  end

  // ==========================================================================
  // Main transaction/DCLS monitor
  // ==========================================================================

  always @(posedge clk_i) begin

    #1;

    if (rst_ni) begin

      // ----------------------------------------------------------------------
      // Instruction-response mismatch
      // ----------------------------------------------------------------------

      if (dcls_instr_mismatch_o) begin

        if (!instruction_mismatch_seen) begin

          instruction_mismatch_seen = 1'b1;

          $display(
            "[%0t] DCLS INSTRUCTION MISMATCH DETECTED",
            $time
          );

          $display(
            "[%0t] Core B instruction response observed by SoC = 0x%08h",
            $time,
            dut.core_b_instr_rdata
          );

        end

      end

      // ----------------------------------------------------------------------
      // Core-A write
      // ----------------------------------------------------------------------

      if (dut.core_a_data_req &&
          dut.core_a_data_we) begin

        if (!core_a_write_seen) begin

          core_a_write_seen = 1'b1;

          $display(
            "[%0t] CORE A WRITE: addr=0x%08h data=0x%08h",
            $time,
            dut.core_a_data_addr,
            dut.core_a_data_wdata
          );

        end

      end

      // ----------------------------------------------------------------------
      // Core-B write
      // ----------------------------------------------------------------------

      if (dut.core_b_data_req &&
          dut.core_b_data_we) begin

        if (!core_b_write_seen) begin

          core_b_write_seen = 1'b1;

          $display(
            "[%0t] CORE B WRITE: addr=0x%08h data=0x%08h",
            $time,
            dut.core_b_data_addr,
            dut.core_b_data_wdata
          );

        end

        // Expected result of corrupted LUI:
        //
        // Core A base = 0x00100000
        // Core B base = 0x00101000
        //
        // Both cores should still write 42.

        if (dut.core_b_data_addr == 32'h00101000) begin

          core_b_data_address_divergence_seen = 1'b1;

          $display(
            "[%0t] CORE B ADDRESS DIVERGENCE CONFIRMED: 0x%08h",
            $time,
            dut.core_b_data_addr
          );

        end

      end

    end

  end

  // ==========================================================================
  // Test sequence
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

    // Tier-2 initially disabled.
    core_b_response_fault_inject_enable_i = 1'b0;
    core_b_response_fault_inject_target_i = 3'b000;
    core_b_response_fault_inject_mask_i   = 32'b0;

    fault_injection_seen = 1'b0;
    instruction_mismatch_seen = 1'b0;

    core_a_write_seen = 1'b0;
    core_b_write_seen = 1'b0;
    core_b_data_address_divergence_seen = 1'b0;

    // ------------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------------

    #20;

    rst_ni = 1'b1;
    dcls_enable_i = 1'b1;

    $display("==============================================");
    $display("STAGE3E-2 TIER-2 RESPONSE FAULT EXPERIMENT");
    $display("==============================================");
    $display("[%0t] DCLS enabled", $time);
    $display("[%0t] Waiting for Core-B first instruction response", $time);

    // ------------------------------------------------------------------------
    // Wait until all expected evidence is collected.
    // ------------------------------------------------------------------------

    fork

      begin

        wait (
          fault_injection_seen &&
          instruction_mismatch_seen &&
          core_a_write_seen &&
          core_b_write_seen &&
          core_b_data_address_divergence_seen
        );

        // --------------------------------------------------------------
        // Validate Core-A transaction.
        // --------------------------------------------------------------

        if (dut.core_a_data_wdata !== 32'h0000002A) begin

          $display(
            "[%0t] FAIL: Core A write data is not 42",
            $time
          );

          $fatal(1);

        end

        if (dut.core_a_data_addr !== 32'h00100000 &&
            dut.core_a_data_addr !== 32'h00100000) begin

          $display(
            "[%0t] FAIL: unexpected Core A write address 0x%08h",
            $time,
            dut.core_a_data_addr
          );

          $fatal(1);

        end

        // --------------------------------------------------------------
        // Validate Core-B transaction.
        // --------------------------------------------------------------

        if (dut.core_b_data_wdata !== 32'h0000002A) begin

          $display(
            "[%0t] FAIL: Core B write data is not 42",
            $time
          );

          $fatal(1);

        end

        if (dut.core_b_data_addr !== 32'h00101000) begin

          $display(
            "[%0t] FAIL: expected Core B address 0x00101000, got 0x%08h",
            $time,
            dut.core_b_data_addr
          );

          $fatal(1);

        end

        // --------------------------------------------------------------
        // DCLS overall mismatch must have been generated.
        // --------------------------------------------------------------

        if (!instruction_mismatch_seen) begin

          $display(
            "[%0t] FAIL: instruction-response mismatch was not detected",
            $time
          );

          $fatal(1);

        end

        $display("==============================================");
        $display("STAGE3E-2 TIER-2 FAULT INJECTION PASS");
        $display("==============================================");
        $display("Fault location       : Core-B instruction response");
        $display("Original instruction : 0x001000B7");
        $display("Injected mask        : 0x00001000");
        $display("Corrupted instruction: 0x001010B7");
        $display("DCLS instruction     : DETECTED");
        $display("Core A write         : 0x00100000 / 42");
        $display("Core B write         : 0x00101000 / 42");
        $display("Execution divergence : CONFIRMED");
        $display("==============================================");

        $finish;

      end

      begin

        // 200 clock-cycle timeout.
        repeat (200) @(posedge clk_i);

        $display("==============================================");
        $display("STAGE3E-2 TIER-2 FAULT INJECTION FAIL");
        $display("==============================================");
        $display("fault_injection_seen              = %0d",
                 fault_injection_seen);
        $display("instruction_mismatch_seen         = %0d",
                 instruction_mismatch_seen);
        $display("core_a_write_seen                  = %0d",
                 core_a_write_seen);
        $display("core_b_write_seen                  = %0d",
                 core_b_write_seen);
        $display("core_b_address_divergence_seen    = %0d",
                 core_b_data_address_divergence_seen);
        $display("==============================================");

        $fatal(1);

      end

    join_any

    disable fork;

  end

endmodule

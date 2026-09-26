`timescale 1ns/1ps

module safety_riscv_soc_stage3_tb;

  localparam [1:0] TARGET_DATA_WDATA = 2'b00;

  logic        clk;
  logic        rst_ni;
  logic        dcls_enable_i;

  logic        fault_inject_enable_i;
  logic [1:0]  fault_inject_target_i;
  logic [31:0] fault_inject_mask_i;

  wire         dcls_instr_mismatch_o;
  wire         dcls_data_mismatch_o;
  wire         dcls_mismatch_o;

  integer phase;
  integer normal_write_seen;
  integer injected_write_seen;

  // --------------------------------------------------------------------------
  // Clock
  // --------------------------------------------------------------------------

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // --------------------------------------------------------------------------
  // DUT
  // --------------------------------------------------------------------------

  safety_riscv_soc_stage3 dut (
      .clk_i                   (clk),
      .rst_ni                  (rst_ni),
      .dcls_enable_i            (dcls_enable_i),

      .fault_inject_enable_i   (fault_inject_enable_i),
      .fault_inject_target_i   (fault_inject_target_i),
      .fault_inject_mask_i     (fault_inject_mask_i),

      .dcls_instr_mismatch_o   (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o    (dcls_data_mismatch_o),
      .dcls_mismatch_o         (dcls_mismatch_o)
  );

  // --------------------------------------------------------------------------
  // Test sequence
  // --------------------------------------------------------------------------

  initial begin
    phase               = 1;
    normal_write_seen   = 0;
    injected_write_seen = 0;

    rst_ni                 = 1'b0;
    dcls_enable_i          = 1'b0;

    fault_inject_enable_i  = 1'b0;
    fault_inject_target_i  = TARGET_DATA_WDATA;
    fault_inject_mask_i    = 32'h00000000;

    // Initial reset.
    repeat (10) @(posedge clk);

    rst_ni        = 1'b1;
    dcls_enable_i = 1'b1;

    $display("[%0t] Phase 1: normal redundant execution", $time);

    // Wait for the first normal transaction to be verified.
    wait (normal_write_seen == 1);

    $display("[%0t] Phase 1 complete: resetting SoC for injected-fault run",
             $time);

    // ------------------------------------------------------------------------
    // Phase 2 preparation
    // ------------------------------------------------------------------------

    phase = 2;

    rst_ni                = 1'b0;
    dcls_enable_i         = 1'b0;

    fault_inject_enable_i = 1'b1;
    fault_inject_target_i = TARGET_DATA_WDATA;
    fault_inject_mask_i   = 32'h00000001;

    // Reset before the second execution.
    repeat (10) @(posedge clk);

    rst_ni        = 1'b1;
    dcls_enable_i = 1'b1;

    $display("[%0t] Phase 2: DATA_WDATA fault injection enabled, mask = 0x%08x",
             $time, fault_inject_mask_i);

    // Wait for the injected transaction to be verified.
    wait (injected_write_seen == 1);

    $display("==============================================");
    $display("STAGE3C END-TO-END FAULT INJECTION PASS");
    $display("Normal transaction        : PASS");
    $display("Injected transaction      : PASS");
    $display("DCLS data mismatch        : DETECTED");
    $display("DCLS overall mismatch     : DETECTED");
    $display("==============================================");

    $finish;
  end

  // --------------------------------------------------------------------------
  // Self-checking monitor
  // --------------------------------------------------------------------------

  always @(posedge clk) begin

    if (rst_ni &&
        dut.core_a_data_req &&
        dut.core_a_data_we &&
        dut.core_b_data_req &&
        dut.core_b_data_we) begin

      if (phase == 1) begin

        $display("[%0t] NORMAL WRITE: A=0x%08x B=0x%08x B_cmp=0x%08x DCLS=%b",
                 $time,
                 dut.core_a_data_wdata,
                 dut.core_b_data_wdata,
                 dut.core_b_data_wdata_cmp,
                 dcls_mismatch_o);

        if ((dut.core_a_data_wdata == 32'd42) &&
            (dut.core_b_data_wdata == 32'd42) &&
            (dut.core_b_data_wdata_cmp == 32'd42) &&
            !dcls_mismatch_o) begin

          normal_write_seen = 1;

          $display("[%0t] PHASE 1 PASS: normal redundant write verified",
                   $time);

        end
        else begin

          $display("[%0t] PHASE 1 FAIL", $time);
          $finish;
        end
      end

      else if (phase == 2) begin

        $display("[%0t] INJECTED WRITE: A=0x%08x B_actual=0x%08x B_cmp=0x%08x DCLS_DATA=%b DCLS=%b",
                 $time,
                 dut.core_a_data_wdata,
                 dut.core_b_data_wdata,
                 dut.core_b_data_wdata_cmp,
                 dcls_data_mismatch_o,
                 dcls_mismatch_o);

        if ((dut.core_a_data_wdata == 32'd42) &&
            (dut.core_b_data_wdata == 32'd42) &&
            (dut.core_b_data_wdata_cmp == 32'd43) &&
            dcls_data_mismatch_o &&
            dcls_mismatch_o) begin

          injected_write_seen = 1;

          $display("[%0t] PHASE 2 PASS: injected observation-path fault detected",
                   $time);

        end
        else begin

          $display("[%0t] PHASE 2 FAIL", $time);
          $finish;
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Global timeout
  // --------------------------------------------------------------------------

  initial begin
    #500000;

    $display("[%0t] STAGE3C FAIL: simulation timeout", $time);
    $finish;
  end

endmodule

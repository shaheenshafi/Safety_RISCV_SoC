`timescale 1ns/1ps

module safety_riscv_soc_stage3_tb;

  logic clk;
  logic rst_ni;
  logic dcls_enable_i;

  logic core_a_pass;
  logic core_b_pass;

  integer cycles_checked;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_ni      = 1'b0;
    dcls_enable_i = 1'b0;

    repeat (10) @(posedge clk);

    rst_ni        = 1'b1;
    dcls_enable_i = 1'b1;

    $display("[%0t] Reset released", $time);
    $display("[%0t] DCLS comparison enabled", $time);
  end

  safety_riscv_soc_stage3 dut (
      .clk_i                   (clk),
      .rst_ni                  (rst_ni),
      .dcls_enable_i           (dcls_enable_i),

      .dcls_instr_mismatch_o   (),
      .dcls_data_mismatch_o    (),
      .dcls_mismatch_o         ()
  );

  initial begin
    core_a_pass    = 1'b0;
    core_b_pass    = 1'b0;
    cycles_checked = 0;
  end

  always @(posedge clk) begin
    if (rst_ni && dcls_enable_i) begin

      cycles_checked = cycles_checked + 1;

      // ----------------------------------------------------------------------
      // DCLS must remain clean during normal redundant execution.
      // ----------------------------------------------------------------------

      if (dut.dcls_mismatch_o !== 1'b0) begin
        $display("");
        $display("STAGE3 FAIL: Unexpected DCLS mismatch");
        $display("  instr_mismatch = %b",
                 dut.dcls_instr_mismatch_o);
        $display("  data_mismatch  = %b",
                 dut.dcls_data_mismatch_o);
        $display("  overall        = %b",
                 dut.dcls_mismatch_o);
        $finish;
      end

      // ----------------------------------------------------------------------
      // Verify that Core A still produces the expected result.
      // ----------------------------------------------------------------------

      if (dut.core_a.data_req_o &&
          dut.core_a.data_we_o &&
          dut.core_a.data_wdata_o == 32'd42 &&
          !core_a_pass) begin

        core_a_pass = 1'b1;

        $display("[%0t] CORE A PASS: expected write value 42 observed",
                 $time);
      end

      // ----------------------------------------------------------------------
      // Verify that Core B still produces the expected result.
      // ----------------------------------------------------------------------

      if (dut.core_b.data_req_o &&
          dut.core_b.data_we_o &&
          dut.core_b.data_wdata_o == 32'd42 &&
          !core_b_pass) begin

        core_b_pass = 1'b1;

        $display("[%0t] CORE B PASS: expected write value 42 observed",
                 $time);
      end

      // ----------------------------------------------------------------------
      // Overall Stage-3 normal-operation pass.
      // ----------------------------------------------------------------------

      if (core_a_pass && core_b_pass) begin

        $display("");
        $display("====================================================");
        $display("STAGE3 DCLS INTEGRATION PASS");
        $display("====================================================");
        $display("Cycles checked : %0d", cycles_checked);
        $display("DCLS mismatch  : %b", dut.dcls_mismatch_o);
        $display("Core A result  : 42");
        $display("Core B result  : 42");
        $display("====================================================");

        $finish;
      end
    end
  end

  initial begin
    #200000;

    $display("");
    $display("====================================================");
    $display("STAGE3 FAIL: Verification timeout");
    $display("====================================================");
    $display("Cycles checked : %0d", cycles_checked);
    $display("Core A pass    : %b", core_a_pass);
    $display("Core B pass    : %b", core_b_pass);
    $display("DCLS mismatch  : %b", dut.dcls_mismatch_o);
    $display("====================================================");

    $finish;
  end

endmodule

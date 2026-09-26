`timescale 1ns/1ps

module safety_riscv_soc_stage2_tb;

  logic clk;
  logic rst_ni;

  logic core_a_pass;
  logic core_b_pass;

  integer cycles_checked;
  integer instruction_requests;
  integer data_writes;
  integer mismatch_count;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_ni = 1'b0;

    repeat (10) @(posedge clk);

    rst_ni = 1'b1;
    $display("[%0t] Reset released", $time);
  end

  safety_riscv_soc_stage2 dut (
      .clk_i  (clk),
      .rst_ni (rst_ni)
  );

  initial begin
    core_a_pass          = 1'b0;
    core_b_pass          = 1'b0;
    cycles_checked       = 0;
    instruction_requests = 0;
    data_writes          = 0;
    mismatch_count       = 0;
  end

  always @(posedge clk) begin
    if (rst_ni) begin

      cycles_checked = cycles_checked + 1;

      // ----------------------------------------------------------------------
      // Instruction-port equivalence
      // ----------------------------------------------------------------------

      if (dut.core_a_instr_req !==
          dut.core_b_instr_req) begin

        mismatch_count = mismatch_count + 1;

        $display("[%0t] STAGE2 FAIL: Instruction request mismatch",
                 $time);

        $display("           Core A: req=%b addr=0x%08h",
                 dut.core_a_instr_req,
                 dut.core_a_instr_addr);

        $display("           Core B: req=%b addr=0x%08h",
                 dut.core_b_instr_req,
                 dut.core_b_instr_addr);

        $finish;
      end

      if (dut.core_a_instr_req) begin

        instruction_requests = instruction_requests + 1;

        if (dut.core_a_instr_addr !==
            dut.core_b_instr_addr) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Instruction address mismatch",
                   $time);

          $display("           Core A: addr=0x%08h",
                   dut.core_a_instr_addr);

          $display("           Core B: addr=0x%08h",
                   dut.core_b_instr_addr);

          $finish;
        end
      end

      // ----------------------------------------------------------------------
      // Data-port control equivalence
      // ----------------------------------------------------------------------

      if (dut.core_a_data_req !==
          dut.core_b_data_req) begin

        mismatch_count = mismatch_count + 1;

        $display("[%0t] STAGE2 FAIL: Data request mismatch",
                 $time);

        $display("           Core A: req=%b",
                 dut.core_a_data_req);

        $display("           Core B: req=%b",
                 dut.core_b_data_req);

        $finish;
      end

      if (dut.core_a_data_req) begin

        if (dut.core_a_data_we !==
            dut.core_b_data_we) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Read/write control mismatch",
                   $time);

          $finish;
        end

        if (dut.core_a_data_be !==
            dut.core_b_data_be) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Byte-enable mismatch",
                   $time);

          $display("           Core A: be=0x%01h",
                   dut.core_a_data_be);

          $display("           Core B: be=0x%01h",
                   dut.core_b_data_be);

          $finish;
        end

        if (dut.core_a_data_addr !==
            dut.core_b_data_addr) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Data address mismatch",
                   $time);

          $display("           Core A: addr=0x%08h",
                   dut.core_a_data_addr);

          $display("           Core B: addr=0x%08h",
                   dut.core_b_data_addr);

          $finish;
        end

        if (dut.core_a_data_we &&
            (dut.core_a_data_wdata !==
             dut.core_b_data_wdata)) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Write-data mismatch",
                   $time);

          $display("           Core A: data=0x%08h",
                   dut.core_a_data_wdata);

          $display("           Core B: data=0x%08h",
                   dut.core_b_data_wdata);

          $finish;
        end

        if (dut.core_a_data_we) begin
          data_writes = data_writes + 1;
        end
      end

      // ----------------------------------------------------------------------
      // Final expected-result checks
      // ----------------------------------------------------------------------

      if (dut.core_a_data_req &&
          dut.core_a_data_we &&
          dut.core_a_data_wdata == 32'd42 &&
          !core_a_pass) begin

        core_a_pass = 1'b1;

        $display("[%0t] CORE A PASS: expected write value 42 observed",
                 $time);
      end

      if (dut.core_b_data_req &&
          dut.core_b_data_we &&
          dut.core_b_data_wdata == 32'd42 &&
          !core_b_pass) begin

        core_b_pass = 1'b1;

        $display("[%0t] CORE B PASS: expected write value 42 observed",
                 $time);
      end

      if (core_a_pass && core_b_pass) begin

        $display("");
        $display("====================================================");
        $display("STAGE2 REDUNDANT-CORE VERIFICATION PASS");
        $display("====================================================");
        $display("Cycles checked       : %0d", cycles_checked);
        $display("Instruction requests : %0d", instruction_requests);
        $display("Data writes          : %0d", data_writes);
        $display("Transaction mismatch : %0d", mismatch_count);
        $display("Core A result        : 42");
        $display("Core B result        : 42");
        $display("====================================================");

        $finish;
      end
    end
  end

  initial begin
    #200000;

    $display("");
    $display("====================================================");
    $display("STAGE2 FAIL: Verification timeout");
    $display("====================================================");
    $display("Cycles checked       : %0d", cycles_checked);
    $display("Instruction requests : %0d", instruction_requests);
    $display("Data writes          : %0d", data_writes);
    $display("Transaction mismatch : %0d", mismatch_count);
    $display("Core A pass          : %b", core_a_pass);
    $display("Core B pass          : %b", core_b_pass);
    $display("====================================================");

    $finish;
  end

endmodule

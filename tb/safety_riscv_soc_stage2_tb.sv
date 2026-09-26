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
      .clk_i(clk),
      .rst_ni(rst_ni)
  );

  initial begin
    core_a_pass        = 1'b0;
    core_b_pass        = 1'b0;
    cycles_checked     = 0;
    instruction_requests = 0;
    data_writes        = 0;
    mismatch_count     = 0;
  end

  always @(posedge clk) begin
    if (rst_ni) begin

      cycles_checked = cycles_checked + 1;

      // ------------------------------------------------------------
      // Instruction-port equivalence
      // ------------------------------------------------------------

      if (dut.core_a.u_ram.b_req_i !==
          dut.core_b.u_ram.b_req_i) begin

        mismatch_count = mismatch_count + 1;

        $display("[%0t] STAGE2 FAIL: Instruction request mismatch",
                 $time);

        $display("           Core A: req=%b addr=0x%08h",
                 dut.core_a.u_ram.b_req_i,
                 dut.core_a.u_ram.b_addr_i);

        $display("           Core B: req=%b addr=0x%08h",
                 dut.core_b.u_ram.b_req_i,
                 dut.core_b.u_ram.b_addr_i);

        $finish;
      end

      if (dut.core_a.u_ram.b_req_i) begin

        instruction_requests = instruction_requests + 1;

        if (dut.core_a.u_ram.b_addr_i !==
            dut.core_b.u_ram.b_addr_i) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Instruction address mismatch",
                   $time);

          $display("           Core A: addr=0x%08h",
                   dut.core_a.u_ram.b_addr_i);

          $display("           Core B: addr=0x%08h",
                   dut.core_b.u_ram.b_addr_i);

          $finish;
        end
      end

      // ------------------------------------------------------------
      // Data-port control equivalence
      // ------------------------------------------------------------

      if (dut.core_a.u_ram.a_req_i !==
          dut.core_b.u_ram.a_req_i) begin

        mismatch_count = mismatch_count + 1;

        $display("[%0t] STAGE2 FAIL: Data request mismatch",
                 $time);

        $display("           Core A: req=%b",
                 dut.core_a.u_ram.a_req_i);

        $display("           Core B: req=%b",
                 dut.core_b.u_ram.a_req_i);

        $finish;
      end

      if (dut.core_a.u_ram.a_req_i) begin

        if (dut.core_a.u_ram.a_we_i !==
            dut.core_b.u_ram.a_we_i) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Read/write control mismatch",
                   $time);

          $finish;
        end

        if (dut.core_a.u_ram.a_be_i !==
            dut.core_b.u_ram.a_be_i) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Byte-enable mismatch",
                   $time);

          $display("           Core A: be=0x%01h",
                   dut.core_a.u_ram.a_be_i);

          $display("           Core B: be=0x%01h",
                   dut.core_b.u_ram.a_be_i);

          $finish;
        end

        if (dut.core_a.u_ram.a_addr_i !==
            dut.core_b.u_ram.a_addr_i) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Data address mismatch",
                   $time);

          $display("           Core A: addr=0x%08h",
                   dut.core_a.u_ram.a_addr_i);

          $display("           Core B: addr=0x%08h",
                   dut.core_b.u_ram.a_addr_i);

          $finish;
        end

        if (dut.core_a.u_ram.a_we_i &&
            (dut.core_a.u_ram.a_wdata_i !==
             dut.core_b.u_ram.a_wdata_i)) begin

          mismatch_count = mismatch_count + 1;

          $display("[%0t] STAGE2 FAIL: Write-data mismatch",
                   $time);

          $display("           Core A: data=0x%08h",
                   dut.core_a.u_ram.a_wdata_i);

          $display("           Core B: data=0x%08h",
                   dut.core_b.u_ram.a_wdata_i);

          $finish;
        end

        if (dut.core_a.u_ram.a_we_i) begin
          data_writes = data_writes + 1;
        end
      end

      // ------------------------------------------------------------
      // Final expected-result checks
      // ------------------------------------------------------------

      if (dut.core_a.u_ram.a_req_i &&
          dut.core_a.u_ram.a_we_i &&
          dut.core_a.u_ram.a_wdata_i == 32'd42 &&
          !core_a_pass) begin

        core_a_pass = 1'b1;

        $display("[%0t] CORE A PASS: expected write value 42 observed",
                 $time);
      end

      if (dut.core_b.u_ram.a_req_i &&
          dut.core_b.u_ram.a_we_i &&
          dut.core_b.u_ram.a_wdata_i == 32'd42 &&
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

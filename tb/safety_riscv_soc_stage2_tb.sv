`timescale 1ns/1ps

module safety_riscv_soc_stage2_tb;

  logic clk;
  logic rst_ni;

  logic core_a_pass;
  logic core_b_pass;

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
    core_a_pass = 1'b0;
    core_b_pass = 1'b0;
  end

  always @(posedge clk) begin

    if (rst_ni &&
        dut.core_a.u_ram.a_req_i &&
        dut.core_a.u_ram.a_we_i &&
        dut.core_a.u_ram.a_wdata_i == 32'd42 &&
        !core_a_pass) begin

      core_a_pass = 1'b1;

      $display("[%0t] CORE A PASS: RAM write data = %0d",
               $time,
               dut.core_a.u_ram.a_wdata_i);
    end

    if (rst_ni &&
        dut.core_b.u_ram.a_req_i &&
        dut.core_b.u_ram.a_we_i &&
        dut.core_b.u_ram.a_wdata_i == 32'd42 &&
        !core_b_pass) begin

      core_b_pass = 1'b1;

      $display("[%0t] CORE B PASS: RAM write data = %0d",
               $time,
               dut.core_b.u_ram.a_wdata_i);
    end

    if ((core_a_pass ||
         (dut.core_a.u_ram.a_req_i &&
          dut.core_a.u_ram.a_we_i &&
          dut.core_a.u_ram.a_wdata_i == 32'd42)) &&
        (core_b_pass ||
         (dut.core_b.u_ram.a_req_i &&
          dut.core_b.u_ram.a_we_i &&
          dut.core_b.u_ram.a_wdata_i == 32'd42))) begin

      $display("[%0t] STAGE2 PASS: Both redundant Ibex channels produced the expected result",
               $time);

      $finish;
    end
  end

  initial begin
    #200000;

    $display("[%0t] STAGE2 FAIL: Both redundant channels did not complete",
             $time);

    $finish;
  end

endmodule

`timescale 1ns/1ps

module dcls_comparator_tb;

  logic        compare_en_i;

  logic        core_a_instr_req_i;
  logic [31:0] core_a_instr_addr_i;
  logic        core_a_instr_rvalid_i;
  logic [31:0] core_a_instr_rdata_i;

  logic        core_b_instr_req_i;
  logic [31:0] core_b_instr_addr_i;
  logic        core_b_instr_rvalid_i;
  logic [31:0] core_b_instr_rdata_i;

  logic        core_a_data_req_i;
  logic        core_a_data_we_i;
  logic [3:0]  core_a_data_be_i;
  logic [31:0] core_a_data_addr_i;
  logic [31:0] core_a_data_wdata_i;
  logic        core_a_data_rvalid_i;
  logic [31:0] core_a_data_rdata_i;

  logic        core_b_data_req_i;
  logic        core_b_data_we_i;
  logic [3:0]  core_b_data_be_i;
  logic [31:0] core_b_data_addr_i;
  logic [31:0] core_b_data_wdata_i;
  logic        core_b_data_rvalid_i;
  logic [31:0] core_b_data_rdata_i;

  wire dcls_instr_mismatch_o;
  wire dcls_data_mismatch_o;
  wire dcls_mismatch_o;

  dcls_comparator dut (
      .compare_en_i            (compare_en_i),

      .core_a_instr_req_i      (core_a_instr_req_i),
      .core_a_instr_addr_i     (core_a_instr_addr_i),
      .core_a_instr_rvalid_i   (core_a_instr_rvalid_i),
      .core_a_instr_rdata_i    (core_a_instr_rdata_i),

      .core_b_instr_req_i      (core_b_instr_req_i),
      .core_b_instr_addr_i     (core_b_instr_addr_i),
      .core_b_instr_rvalid_i   (core_b_instr_rvalid_i),
      .core_b_instr_rdata_i    (core_b_instr_rdata_i),

      .core_a_data_req_i       (core_a_data_req_i),
      .core_a_data_we_i        (core_a_data_we_i),
      .core_a_data_be_i        (core_a_data_be_i),
      .core_a_data_addr_i      (core_a_data_addr_i),
      .core_a_data_wdata_i     (core_a_data_wdata_i),
      .core_a_data_rvalid_i    (core_a_data_rvalid_i),
      .core_a_data_rdata_i     (core_a_data_rdata_i),

      .core_b_data_req_i       (core_b_data_req_i),
      .core_b_data_we_i        (core_b_data_we_i),
      .core_b_data_be_i        (core_b_data_be_i),
      .core_b_data_addr_i      (core_b_data_addr_i),
      .core_b_data_wdata_i     (core_b_data_wdata_i),
      .core_b_data_rvalid_i    (core_b_data_rvalid_i),
      .core_b_data_rdata_i     (core_b_data_rdata_i),

      .dcls_instr_mismatch_o   (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o    (dcls_data_mismatch_o),
      .dcls_mismatch_o         (dcls_mismatch_o)
  );

  task automatic expect_no_mismatch(input string test_name);
    begin
      #1;

      if (dcls_mismatch_o !== 1'b0) begin
        $display("FAIL: %s", test_name);
        $display("      instr_mismatch=%b data_mismatch=%b",
                 dcls_instr_mismatch_o,
                 dcls_data_mismatch_o);
        $finish;
      end

      $display("PASS: %s", test_name);
    end
  endtask

  task automatic expect_mismatch(
      input string test_name,
      input        expect_instr,
      input        expect_data
  );
    begin
      #1;

      if ((dcls_mismatch_o !== 1'b1) ||
          (dcls_instr_mismatch_o !== expect_instr) ||
          (dcls_data_mismatch_o !== expect_data)) begin

        $display("FAIL: %s", test_name);

        $display("      expected: overall=%b instr=%b data=%b",
                 1'b1, expect_instr, expect_data);

        $display("      actual  : overall=%b instr=%b data=%b",
                 dcls_mismatch_o,
                 dcls_instr_mismatch_o,
                 dcls_data_mismatch_o);

        $finish;
      end

      $display("PASS: %s", test_name);
    end
  endtask

  initial begin

    // ------------------------------------------------------------------------
    // Initial state
    // ------------------------------------------------------------------------

    compare_en_i = 1'b1;

    core_a_instr_req_i    = 1'b0;
    core_a_instr_addr_i   = 32'h0;
    core_a_instr_rvalid_i = 1'b0;
    core_a_instr_rdata_i  = 32'h0;

    core_b_instr_req_i    = 1'b0;
    core_b_instr_addr_i   = 32'h0;
    core_b_instr_rvalid_i = 1'b0;
    core_b_instr_rdata_i  = 32'h0;

    core_a_data_req_i     = 1'b0;
    core_a_data_we_i      = 1'b0;
    core_a_data_be_i      = 4'h0;
    core_a_data_addr_i    = 32'h0;
    core_a_data_wdata_i   = 32'h0;
    core_a_data_rvalid_i  = 1'b0;
    core_a_data_rdata_i   = 32'h0;

    core_b_data_req_i     = 1'b0;
    core_b_data_we_i      = 1'b0;
    core_b_data_be_i      = 4'h0;
    core_b_data_addr_i    = 32'h0;
    core_b_data_wdata_i   = 32'h0;
    core_b_data_rvalid_i  = 1'b0;
    core_b_data_rdata_i   = 32'h0;

    expect_no_mismatch("both channels inactive");

    // ------------------------------------------------------------------------
    // Instruction: identical active request
    // ------------------------------------------------------------------------

    core_a_instr_req_i  = 1'b1;
    core_b_instr_req_i  = 1'b1;
    core_a_instr_addr_i = 32'h00100080;
    core_b_instr_addr_i = 32'h00100080;

    expect_no_mismatch("identical instruction request");

    // ------------------------------------------------------------------------
    // Instruction: address mismatch
    // ------------------------------------------------------------------------

    core_b_instr_addr_i = 32'h00100084;

    expect_mismatch("instruction address mismatch", 1'b1, 1'b0);

    core_b_instr_addr_i = 32'h00100080;

    // ------------------------------------------------------------------------
    // Instruction: request mismatch
    // ------------------------------------------------------------------------

    core_b_instr_req_i = 1'b0;

    expect_mismatch("instruction request mismatch", 1'b1, 1'b0);

    core_b_instr_req_i = 1'b1;

    // ------------------------------------------------------------------------
    // Instruction response: identical valid response
    // ------------------------------------------------------------------------

    core_a_instr_rvalid_i = 1'b1;
    core_b_instr_rvalid_i = 1'b1;

    core_a_instr_rdata_i = 32'h02A00113;
    core_b_instr_rdata_i = 32'h02A00113;

    expect_no_mismatch("identical instruction response");

    // ------------------------------------------------------------------------
    // Instruction response: valid mismatch
    // ------------------------------------------------------------------------

    core_b_instr_rvalid_i = 1'b0;

    expect_mismatch("instruction response-valid mismatch", 1'b1, 1'b0);

    core_b_instr_rvalid_i = 1'b1;

    // ------------------------------------------------------------------------
    // Instruction response: data mismatch
    // ------------------------------------------------------------------------

    core_b_instr_rdata_i = 32'h02B00113;

    expect_mismatch("instruction response-data mismatch", 1'b1, 1'b0);

    core_b_instr_rdata_i = 32'h02A00113;

    // ------------------------------------------------------------------------
    // Instruction response: response data ignored without valid
    // ------------------------------------------------------------------------

    core_a_instr_rvalid_i = 1'b0;
    core_b_instr_rvalid_i = 1'b0;

    core_a_instr_rdata_i = 32'hAAAAAAAA;
    core_b_instr_rdata_i = 32'h55555555;

    expect_no_mismatch("instruction response data ignored when invalid");

    // ------------------------------------------------------------------------
    // End instruction-side tests and return instruction interface to inactive
    // state before beginning data-side tests.
    // ------------------------------------------------------------------------

    core_a_instr_req_i    = 1'b0;
    core_b_instr_req_i    = 1'b0;
    core_a_instr_addr_i   = 32'h0;
    core_b_instr_addr_i   = 32'h0;

    core_a_instr_rvalid_i = 1'b0;
    core_b_instr_rvalid_i = 1'b0;
    core_a_instr_rdata_i  = 32'h0;
    core_b_instr_rdata_i  = 32'h0;

    // ------------------------------------------------------------------------
    // Data: identical write
    // ------------------------------------------------------------------------

    core_a_data_req_i   = 1'b1;
    core_b_data_req_i   = 1'b1;

    core_a_data_we_i    = 1'b1;
    core_b_data_we_i    = 1'b1;

    core_a_data_be_i    = 4'b1111;
    core_b_data_be_i    = 4'b1111;

    core_a_data_addr_i  = 32'h00100000;
    core_b_data_addr_i  = 32'h00100000;

    core_a_data_wdata_i = 32'd42;
    core_b_data_wdata_i = 32'd42;

    expect_no_mismatch("identical data write");

    // ------------------------------------------------------------------------
    // Data: request mismatch
    // ------------------------------------------------------------------------

    core_b_data_req_i = 1'b0;

    expect_mismatch("data request mismatch", 1'b0, 1'b1);

    core_b_data_req_i = 1'b1;

    // ------------------------------------------------------------------------
    // Data: write-enable mismatch
    // ------------------------------------------------------------------------

    core_b_data_we_i = 1'b0;

    expect_mismatch("data write-enable mismatch", 1'b0, 1'b1);

    core_b_data_we_i = 1'b1;

    // ------------------------------------------------------------------------
    // Data: byte-enable mismatch
    // ------------------------------------------------------------------------

    core_b_data_be_i = 4'b0011;

    expect_mismatch("data byte-enable mismatch", 1'b0, 1'b1);

    core_b_data_be_i = 4'b1111;

    // ------------------------------------------------------------------------
    // Data: address mismatch
    // ------------------------------------------------------------------------

    core_b_data_addr_i = 32'h00100004;

    expect_mismatch("data address mismatch", 1'b0, 1'b1);

    core_b_data_addr_i = 32'h00100000;

    // ------------------------------------------------------------------------
    // Data: write-data mismatch
    // ------------------------------------------------------------------------

    core_b_data_wdata_i = 32'd43;

    expect_mismatch("data write-data mismatch", 1'b0, 1'b1);

    core_b_data_wdata_i = 32'd42;

    // ------------------------------------------------------------------------
    // Data: identical read response
    // ------------------------------------------------------------------------

    core_a_data_we_i = 1'b0;
    core_b_data_we_i = 1'b0;

    core_a_data_rvalid_i = 1'b1;
    core_b_data_rvalid_i = 1'b1;

    core_a_data_rdata_i = 32'h12345678;
    core_b_data_rdata_i = 32'h12345678;

    expect_no_mismatch("identical data read response");

    // ------------------------------------------------------------------------
    // Data: response-valid mismatch
    // ------------------------------------------------------------------------

    core_b_data_rvalid_i = 1'b0;

    expect_mismatch("data response-valid mismatch", 1'b0, 1'b1);

    core_b_data_rvalid_i = 1'b1;

    // ------------------------------------------------------------------------
    // Data: response-data mismatch
    // ------------------------------------------------------------------------

    core_b_data_rdata_i = 32'h87654321;

    expect_mismatch("data response-data mismatch", 1'b0, 1'b1);

    core_b_data_rdata_i = 32'h12345678;

    // ------------------------------------------------------------------------
    // Data: read write-data is irrelevant when response is valid
    // ------------------------------------------------------------------------

    core_a_data_wdata_i = 32'hAAAAAAAA;
    core_b_data_wdata_i = 32'h55555555;

    expect_no_mismatch("identical read response with irrelevant write data");

    // ------------------------------------------------------------------------
    // Data: response data ignored when invalid
    // ------------------------------------------------------------------------

    core_a_data_rvalid_i = 1'b0;
    core_b_data_rvalid_i = 1'b0;

    core_a_data_rdata_i = 32'hAAAAAAAA;
    core_b_data_rdata_i = 32'h55555555;

    expect_no_mismatch("data response data ignored when invalid");

    // ------------------------------------------------------------------------
    // Disabled comparison
    // ------------------------------------------------------------------------

    core_b_instr_addr_i   = 32'hDEADBEEF;
    core_b_instr_rvalid_i = 1'b0;
    core_b_instr_rdata_i  = 32'hDEADBEEF;

    core_b_data_addr_i    = 32'hCAFEBABE;
    core_b_data_rvalid_i  = 1'b0;
    core_b_data_rdata_i   = 32'hCAFEBABE;

    compare_en_i = 1'b0;

    expect_no_mismatch("comparison disabled");

    // ------------------------------------------------------------------------
    // Final result
    // ------------------------------------------------------------------------

    $display("");
    $display("==============================================");
    $display("DCLS COMPARATOR STAGE-3D PASS");
    $display("==============================================");

    $finish;
  end

endmodule

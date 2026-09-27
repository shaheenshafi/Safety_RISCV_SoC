`timescale 1ns/1ps

module core_response_fault_injector_tb;

  logic        fault_inject_enable_i;
  logic [2:0]  fault_inject_target_i;
  logic [31:0] fault_inject_mask_i;

  logic [31:0] instr_rdata_i;
  logic [31:0] data_rdata_i;

  wire [31:0] instr_rdata_o;
  wire [31:0] data_rdata_o;

  localparam [2:0] TARGET_INSTR_RDATA = 3'b000;
  localparam [2:0] TARGET_DATA_RDATA  = 3'b001;
  localparam [2:0] TARGET_RESERVED    = 3'b111;

  core_response_fault_injector dut (
      .fault_inject_enable_i (fault_inject_enable_i),
      .fault_inject_target_i (fault_inject_target_i),
      .fault_inject_mask_i   (fault_inject_mask_i),

      .instr_rdata_i         (instr_rdata_i),
      .data_rdata_i          (data_rdata_i),

      .instr_rdata_o         (instr_rdata_o),
      .data_rdata_o          (data_rdata_o)
  );

  task automatic check_values(
      input string test_name,
      input [31:0] expected_instr,
      input [31:0] expected_data
  );
    begin
      #1;

      if ((instr_rdata_o !== expected_instr) ||
          (data_rdata_o  !== expected_data)) begin

        $display("FAIL: %s", test_name);
        $display("  Expected: instr=0x%08h data=0x%08h",
                 expected_instr,
                 expected_data);
        $display("  Actual  : instr=0x%08h data=0x%08h",
                 instr_rdata_o,
                 data_rdata_o);
        $finish;
      end

      $display("PASS: %s", test_name);
    end
  endtask

  initial begin

    // ------------------------------------------------------------------------
    // Baseline
    // ------------------------------------------------------------------------

    instr_rdata_i = 32'h02A00113;
    data_rdata_i  = 32'h12345678;

    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = TARGET_RESERVED;
    fault_inject_mask_i   = 32'hFFFFFFFF;

    check_values(
        "injection disabled",
        instr_rdata_i,
        data_rdata_i
    );

    // ------------------------------------------------------------------------
    // Instruction response: single-bit injection
    // ------------------------------------------------------------------------

    fault_inject_enable_i = 1'b1;
    fault_inject_target_i = TARGET_INSTR_RDATA;
    fault_inject_mask_i   = 32'h00000001;

    check_values(
        "INSTR_RDATA single-bit injection",
        32'h02A00112,
        data_rdata_i
    );

    // ------------------------------------------------------------------------
    // Data response: single-bit injection
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_DATA_RDATA;
    fault_inject_mask_i   = 32'h00000001;

    check_values(
        "DATA_RDATA single-bit injection",
        instr_rdata_i,
        32'h12345679
    );

    // ------------------------------------------------------------------------
    // Data response: multi-bit injection
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_DATA_RDATA;
    fault_inject_mask_i   = 32'h0000000F;

    check_values(
        "DATA_RDATA multi-bit injection",
        instr_rdata_i,
        32'h12345677
    );

    // ------------------------------------------------------------------------
    // Reserved target
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_RESERVED;
    fault_inject_mask_i   = 32'hFFFFFFFF;

    check_values(
        "reserved target",
        instr_rdata_i,
        data_rdata_i
    );

    // ------------------------------------------------------------------------
    // Disable after injection
    // ------------------------------------------------------------------------

    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = TARGET_INSTR_RDATA;
    fault_inject_mask_i   = 32'hFFFFFFFF;

    check_values(
        "disabled after injection",
        instr_rdata_i,
        data_rdata_i
    );

    $display("");
    $display("==============================================");
    $display("CORE RESPONSE FAULT INJECTOR PASS");
    $display("==============================================");

    $finish;
  end

endmodule

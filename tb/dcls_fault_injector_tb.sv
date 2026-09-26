`timescale 1ns/1ps

module dcls_fault_injector_tb;

  logic        fault_inject_enable_i;
  logic [1:0]  fault_inject_target_i;
  logic [31:0] fault_inject_mask_i;

  logic [31:0] instr_addr_i;
  logic [31:0] data_addr_i;
  logic [31:0] data_wdata_i;

  wire [31:0] instr_addr_o;
  wire [31:0] data_addr_o;
  wire [31:0] data_wdata_o;

  localparam [1:0] TARGET_DATA_WDATA = 2'b00;
  localparam [1:0] TARGET_DATA_ADDR  = 2'b01;
  localparam [1:0] TARGET_INSTR_ADDR = 2'b10;
  localparam [1:0] TARGET_RESERVED   = 2'b11;

  dcls_fault_injector dut (
      .fault_inject_enable_i (fault_inject_enable_i),
      .fault_inject_target_i (fault_inject_target_i),
      .fault_inject_mask_i   (fault_inject_mask_i),

      .instr_addr_i          (instr_addr_i),
      .data_addr_i           (data_addr_i),
      .data_wdata_i          (data_wdata_i),

      .instr_addr_o          (instr_addr_o),
      .data_addr_o           (data_addr_o),
      .data_wdata_o          (data_wdata_o)
  );

  task automatic check_values(
      input string test_name,
      input [31:0] expected_instr,
      input [31:0] expected_data_addr,
      input [31:0] expected_data_wdata
  );
    begin
      #1;

      if ((instr_addr_o   !== expected_instr) ||
          (data_addr_o    !== expected_data_addr) ||
          (data_wdata_o  !== expected_data_wdata)) begin

        $display("FAIL: %s", test_name);
        $display("  Expected: instr=0x%08h data_addr=0x%08h data_wdata=0x%08h",
                 expected_instr,
                 expected_data_addr,
                 expected_data_wdata);
        $display("  Actual  : instr=0x%08h data_addr=0x%08h data_wdata=0x%08h",
                 instr_addr_o,
                 data_addr_o,
                 data_wdata_o);
        $finish;
      end

      $display("PASS: %s", test_name);
    end
  endtask

  initial begin

    // ------------------------------------------------------------------------
    // Baseline values
    // ------------------------------------------------------------------------

    instr_addr_i  = 32'h00100080;
    data_addr_i   = 32'h00100000;
    data_wdata_i  = 32'h0000002A;

    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = TARGET_RESERVED;
    fault_inject_mask_i   = 32'hFFFFFFFF;

    check_values(
        "injection disabled",
        instr_addr_i,
        data_addr_i,
        data_wdata_i
    );

    // ------------------------------------------------------------------------
    // DATA_WDATA injection
    // 0x2A XOR 0x01 = 0x2B
    // ------------------------------------------------------------------------

    fault_inject_enable_i = 1'b1;
    fault_inject_target_i = TARGET_DATA_WDATA;
    fault_inject_mask_i   = 32'h00000001;

    check_values(
        "DATA_WDATA single-bit injection",
        instr_addr_i,
        data_addr_i,
        32'h0000002B
    );

    // ------------------------------------------------------------------------
    // DATA_ADDR injection
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_DATA_ADDR;
    fault_inject_mask_i   = 32'h00000004;

    check_values(
        "DATA_ADDR single-bit injection",
        instr_addr_i,
        32'h00100004,
        data_wdata_i
    );

    // ------------------------------------------------------------------------
    // INSTR_ADDR injection
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_INSTR_ADDR;
    fault_inject_mask_i   = 32'h00000004;

    check_values(
        "INSTR_ADDR single-bit injection",
        32'h00100084,
        data_addr_i,
        data_wdata_i
    );

    // ------------------------------------------------------------------------
    // Multi-bit DATA_WDATA injection
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_DATA_WDATA;
    fault_inject_mask_i   = 32'h0000000F;

    check_values(
        "DATA_WDATA multi-bit injection",
        instr_addr_i,
        data_addr_i,
        32'h00000025
    );

    // ------------------------------------------------------------------------
    // Reserved target must not alter anything
    // ------------------------------------------------------------------------

    fault_inject_target_i = TARGET_RESERVED;
    fault_inject_mask_i   = 32'hFFFFFFFF;

    check_values(
        "reserved target",
        instr_addr_i,
        data_addr_i,
        data_wdata_i
    );

    // ------------------------------------------------------------------------
    // Disable injection after having a target selected
    // ------------------------------------------------------------------------

    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = TARGET_INSTR_ADDR;
    fault_inject_mask_i   = 32'hFFFFFFFF;

    check_values(
        "disabled after injection",
        instr_addr_i,
        data_addr_i,
        data_wdata_i
    );

    $display("");
    $display("==============================================");
    $display("DCLS FAULT INJECTOR PASS");
    $display("==============================================");

    $finish;
  end

endmodule

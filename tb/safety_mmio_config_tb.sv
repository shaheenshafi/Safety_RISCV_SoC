
`timescale 1ns/1ps

module safety_mmio_config_tb;

  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;

  reg req_i = 1'b0;
  reg we_i = 1'b0;
  reg [3:0] be_i = 4'b1111;
  reg [31:0] addr_i = 32'b0;
  reg [31:0] wdata_i = 32'b0;
  wire gnt_o;
  wire rvalid_o;
  wire [31:0] rdata_o;

  reg safe_state_i = 1'b0;

  reg fault_latched_i = 1'b0;
  reg instr_fault_seen_i = 1'b0;
  reg data_fault_seen_i = 1'b0;
  reg [7:0] fault_code_i = 8'b0;

  wire [1:0] profile_o;
  wire injection_authorize_o;
  wire [1:0] selected_profile_o;
  wire profile_valid_o;
  wire dcls_enable_o;
  wire fault_injection_enable_o;

  localparam [31:0] REG_PROFILE_CTRL = 32'h0020_0000;
  localparam [31:0] REG_INJECTION_AUTH = 32'h0020_0004;
  localparam [31:0] REG_PROFILE_STATUS = 32'h0020_0008;
  localparam [31:0] REG_FAULT_STATUS = 32'h0020_000C;

  safety_mmio_config dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .req_i(req_i),
      .we_i(we_i),
      .be_i(be_i),
      .addr_i(addr_i),
      .wdata_i(wdata_i),
      .gnt_o(gnt_o),
      .rvalid_o(rvalid_o),
      .rdata_o(rdata_o),
      .safe_state_i(safe_state_i),
      .fault_latched_i(fault_latched_i),
      .instr_fault_seen_i(instr_fault_seen_i),
      .data_fault_seen_i(data_fault_seen_i),
      .fault_code_i(fault_code_i),
      .profile_o(profile_o),
      .injection_authorize_o(injection_authorize_o),
      .selected_profile_o(selected_profile_o),
      .profile_valid_o(profile_valid_o),
      .dcls_enable_o(dcls_enable_o),
      .fault_injection_enable_o(fault_injection_enable_o)
  );

  always #5 clk_i = ~clk_i;

  task automatic write_reg(input [31:0] addr, input [31:0] data);
    begin
      @(negedge clk_i);
      req_i = 1'b1;
      we_i = 1'b1;
      addr_i = addr;
      wdata_i = data;
      be_i = 4'b1111;
      #1;
      if (gnt_o !== 1'b1)
        $fatal(1, "Write not granted at %08h", addr);
      @(posedge clk_i);
      #1;
      req_i = 1'b0;
      we_i = 1'b0;
    end
  endtask

  task automatic write_reg_be(
    input [31:0] addr,
    input [31:0] data,
    input [3:0] byte_enable
  );
    begin
      @(negedge clk_i);
      req_i = 1'b1;
      we_i = 1'b1;
      addr_i = addr;
      wdata_i = data;
      be_i = byte_enable;
      #1;
      if (gnt_o !== 1'b1)
        $fatal(1, "Byte-enable write not granted at %08h", addr);
      @(posedge clk_i);
      #1;
      req_i = 1'b0;
      we_i = 1'b0;
      be_i = 4'b1111;
    end
  endtask

  task automatic read_reg(input [31:0] addr, output [31:0] data);
    begin
      @(negedge clk_i);
      req_i = 1'b1;
      we_i = 1'b0;
      addr_i = addr;
      #1;
      if (gnt_o !== 1'b1)
        $fatal(1, "Read not granted at %08h", addr);
      @(posedge clk_i);
      #1;
      if (rvalid_o !== 1'b1)
        $fatal(1, "Read response missing at %08h", addr);
      data = rdata_o;
      req_i = 1'b0;
    end
  endtask

  reg [31:0] read_value;

  initial begin
    repeat (2) @(posedge clk_i);
    #1;
    rst_ni = 1'b1;

    if (profile_o !== 2'b00 ||
        injection_authorize_o !== 1'b0)
      $fatal(1, "Reset defaults incorrect");
    $display("PASS: Reset defaults to Basic with injection unauthorized");

    write_reg(REG_PROFILE_CTRL, 32'h1);
    if (profile_o !== 2'b01 || !dcls_enable_o ||
        fault_injection_enable_o)
      $fatal(1, "Safety profile configuration failed");
    $display("PASS: Safety profile enables DCLS and disables injection");

    write_reg(REG_PROFILE_CTRL, 32'h2);
    if (profile_o !== 2'b10 || !dcls_enable_o ||
        fault_injection_enable_o)
      $fatal(1, "Diagnostic profile without authorization failed");
    $display("PASS: Diagnostic profile requires authorization");

    write_reg(REG_INJECTION_AUTH, 32'h1);
    if (!fault_injection_enable_o)
      $fatal(1, "Authorized Diagnostic profile did not enable injection");
    $display("PASS: Explicit authorization enables diagnostic injection");

    read_reg(REG_PROFILE_CTRL, read_value);
    if (read_value !== 32'h2)
      $fatal(1, "PROFILE_CTRL readback incorrect: %08h", read_value);
    $display("PASS: Profile register readback");

    read_reg(REG_PROFILE_STATUS, read_value);
    if (read_value[1:0] !== 2'b10 ||
        read_value[2] !== 1'b1 ||
        read_value[3] !== 1'b1 ||
        read_value[4] !== 1'b1)
      $fatal(1, "PROFILE_STATUS readback incorrect: %08h", read_value);
    $display("PASS: Profile status bit fields");

    fault_latched_i = 1'b1;
    instr_fault_seen_i = 1'b1;
    data_fault_seen_i = 1'b1;
    fault_code_i = 8'h01;

    read_reg(REG_FAULT_STATUS, read_value);
    if (read_value !== 32'h0000_0107)
      $fatal(1, "FAULT_STATUS readback incorrect: %08h", read_value);
    $display("PASS: Fault status readback");

    safe_state_i = 1'b1;
    write_reg(REG_PROFILE_CTRL, 32'h0);
    write_reg(REG_INJECTION_AUTH, 32'h0);

    if (profile_o !== 2'b10 || injection_authorize_o !== 1'b1)
      $fatal(1, "Configuration changed during safe state");
    if (!fault_latched_i)
      $fatal(1, "Test fault input unexpectedly changed");
    $display("PASS: Configuration writes blocked during safe state");

    // Reserved profile must disable both DCLS and injection.
    safe_state_i = 1'b0;
    write_reg(REG_PROFILE_CTRL, 32'h3);
    if (profile_valid_o !== 1'b0 ||
        dcls_enable_o !== 1'b0 ||
        fault_injection_enable_o !== 1'b0)
      $fatal(1, "Reserved profile policy failed");
    $display("PASS: Reserved profile disables DCLS and injection");

    // Authorization remains stored but is effective only in Diagnostic.
    write_reg(REG_PROFILE_CTRL, 32'h1);
    if (profile_o !== 2'b01 ||
        injection_authorize_o !== 1'b1 ||
        !dcls_enable_o ||
        fault_injection_enable_o)
      $fatal(1, "Safety profile did not suppress authorized injection");
    $display("PASS: Safety profile suppresses injection without clearing authorization");

    write_reg(REG_PROFILE_CTRL, 32'h2);
    if (profile_o !== 2'b10 ||
        injection_authorize_o !== 1'b1 ||
        !dcls_enable_o ||
        !fault_injection_enable_o)
      $fatal(1, "Diagnostic profile did not restore authorized injection");
    $display("PASS: Diagnostic profile restores explicitly authorized injection");

    // Writes without byte lane 0 must not modify low-byte configuration.
    write_reg_be(REG_PROFILE_CTRL, 32'h0, 4'b0010);
    if (profile_o !== 2'b10)
      $fatal(1, "Profile changed when byte-enable bit 0 was clear");
    $display("PASS: Profile write respects byte-enable bit 0");

    // Profile changes must not alter the independent, read-only fault status.
    read_reg(REG_FAULT_STATUS, read_value);
    if (read_value !== 32'h0000_0107)
      $fatal(1, "Fault status changed after profile writes: %08h", read_value);
    $display("PASS: Fault status remains unchanged across profile changes");

    // Unknown addresses must not be granted.
    @(negedge clk_i);
    req_i = 1'b1;
    addr_i = 32'h0020_0010;
    #1;
    if (gnt_o !== 1'b0)
      $fatal(1, "Invalid address was granted");
    req_i = 1'b0;

    $display("");
    $display("STANDALONE MMIO CONFIG TEST PASS");
    $finish;
  end

endmodule

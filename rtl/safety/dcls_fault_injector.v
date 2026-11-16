`timescale 1ns/1ps

module dcls_fault_injector (
    input  wire        fault_inject_enable_i,
    input  wire [1:0]  fault_inject_target_i,
    input  wire [31:0] fault_inject_mask_i,

    input  wire [31:0] instr_addr_i,
    input  wire [31:0] data_addr_i,
    input  wire [31:0] data_wdata_i,

    output wire [31:0] instr_addr_o,
    output wire [31:0] data_addr_o,
    output wire [31:0] data_wdata_o
);

  localparam [1:0] TARGET_DATA_WDATA = 2'b00;
  localparam [1:0] TARGET_DATA_ADDR  = 2'b01;
  localparam [1:0] TARGET_INSTR_ADDR = 2'b10;

  assign instr_addr_o =
      (fault_inject_enable_i &&
       (fault_inject_target_i == TARGET_INSTR_ADDR))
          ? (instr_addr_i ^ fault_inject_mask_i)
          : instr_addr_i;

  assign data_addr_o =
      (fault_inject_enable_i &&
       (fault_inject_target_i == TARGET_DATA_ADDR))
          ? (data_addr_i ^ fault_inject_mask_i)
          : data_addr_i;

  assign data_wdata_o =
      (fault_inject_enable_i &&
       (fault_inject_target_i == TARGET_DATA_WDATA))
          ? (data_wdata_i ^ fault_inject_mask_i)
          : data_wdata_i;

endmodule

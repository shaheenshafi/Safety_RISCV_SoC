`timescale 1ns/1ps

module core_response_fault_injector (
    input wire        fault_inject_enable_i,
    input wire [2:0]  fault_inject_target_i,
    input wire [31:0] fault_inject_mask_i,

    input wire [31:0] instr_rdata_i,
    input wire [31:0] data_rdata_i,

    output wire [31:0] instr_rdata_o,
    output wire [31:0] data_rdata_o
);

  localparam [2:0] TARGET_INSTR_RDATA = 3'b000;
  localparam [2:0] TARGET_DATA_RDATA  = 3'b001;

  assign instr_rdata_o =
      (fault_inject_enable_i &&
       (fault_inject_target_i == TARGET_INSTR_RDATA))
          ? (instr_rdata_i ^ fault_inject_mask_i)
          : instr_rdata_i;

  assign data_rdata_o =
      (fault_inject_enable_i &&
       (fault_inject_target_i == TARGET_DATA_RDATA))
          ? (data_rdata_i ^ fault_inject_mask_i)
          : data_rdata_i;

endmodule

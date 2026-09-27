`timescale 1ns/1ps

module dcls_comparator (
    input wire        compare_en_i,

    // --------------------------------------------------------------------------
    // Core A instruction observations
    // --------------------------------------------------------------------------
    input wire        core_a_instr_req_i,
    input wire [31:0] core_a_instr_addr_i,
    input wire        core_a_instr_rvalid_i,
    input wire [31:0] core_a_instr_rdata_i,

    // --------------------------------------------------------------------------
    // Core B instruction observations
    // --------------------------------------------------------------------------
    input wire        core_b_instr_req_i,
    input wire [31:0] core_b_instr_addr_i,
    input wire        core_b_instr_rvalid_i,
    input wire [31:0] core_b_instr_rdata_i,

    // --------------------------------------------------------------------------
    // Core A data observations
    // --------------------------------------------------------------------------
    input wire        core_a_data_req_i,
    input wire        core_a_data_we_i,
    input wire [3:0]  core_a_data_be_i,
    input wire [31:0] core_a_data_addr_i,
    input wire [31:0] core_a_data_wdata_i,
    input wire        core_a_data_rvalid_i,
    input wire [31:0] core_a_data_rdata_i,

    // --------------------------------------------------------------------------
    // Core B data observations
    // --------------------------------------------------------------------------
    input wire        core_b_data_req_i,
    input wire        core_b_data_we_i,
    input wire [3:0]  core_b_data_be_i,
    input wire [31:0] core_b_data_addr_i,
    input wire [31:0] core_b_data_wdata_i,
    input wire        core_b_data_rvalid_i,
    input wire [31:0] core_b_data_rdata_i,

    // --------------------------------------------------------------------------
    // DCLS mismatch outputs
    // --------------------------------------------------------------------------
    output wire        dcls_instr_mismatch_o,
    output wire        dcls_data_mismatch_o,
    output wire        dcls_mismatch_o
);

  wire instr_req_mismatch;
  wire instr_addr_mismatch;
  wire instr_rvalid_mismatch;
  wire instr_rdata_mismatch;

  wire data_req_mismatch;
  wire data_we_mismatch;
  wire data_be_mismatch;
  wire data_addr_mismatch;
  wire data_wdata_mismatch;
  wire data_rvalid_mismatch;
  wire data_rdata_mismatch;

  // --------------------------------------------------------------------------
  // Instruction-side comparison
  // --------------------------------------------------------------------------

  assign instr_req_mismatch =
      core_a_instr_req_i != core_b_instr_req_i;

  assign instr_addr_mismatch =
      core_a_instr_req_i &&
      core_b_instr_req_i &&
      (core_a_instr_addr_i != core_b_instr_addr_i);

  assign instr_rvalid_mismatch =
      core_a_instr_rvalid_i != core_b_instr_rvalid_i;

  assign instr_rdata_mismatch =
      core_a_instr_rvalid_i &&
      core_b_instr_rvalid_i &&
      (core_a_instr_rdata_i != core_b_instr_rdata_i);

  assign dcls_instr_mismatch_o =
      compare_en_i &&
      (instr_req_mismatch ||
       instr_addr_mismatch ||
       instr_rvalid_mismatch ||
       instr_rdata_mismatch);

  // --------------------------------------------------------------------------
  // Data-side comparison
  // --------------------------------------------------------------------------

  assign data_req_mismatch =
      core_a_data_req_i != core_b_data_req_i;

  assign data_we_mismatch =
      core_a_data_req_i &&
      core_b_data_req_i &&
      (core_a_data_we_i != core_b_data_we_i);

  assign data_be_mismatch =
      core_a_data_req_i &&
      core_b_data_req_i &&
      (core_a_data_be_i != core_b_data_be_i);

  assign data_addr_mismatch =
      core_a_data_req_i &&
      core_b_data_req_i &&
      (core_a_data_addr_i != core_b_data_addr_i);

  assign data_wdata_mismatch =
      core_a_data_req_i &&
      core_b_data_req_i &&
      core_a_data_we_i &&
      core_b_data_we_i &&
      (core_a_data_wdata_i != core_b_data_wdata_i);

  assign data_rvalid_mismatch =
      core_a_data_rvalid_i != core_b_data_rvalid_i;

  assign data_rdata_mismatch =
      core_a_data_rvalid_i &&
      core_b_data_rvalid_i &&
      (core_a_data_rdata_i != core_b_data_rdata_i);

  assign dcls_data_mismatch_o =
      compare_en_i &&
      (data_req_mismatch ||
       data_we_mismatch ||
       data_be_mismatch ||
       data_addr_mismatch ||
       data_wdata_mismatch ||
       data_rvalid_mismatch ||
       data_rdata_mismatch);

  // --------------------------------------------------------------------------
  // Overall DCLS mismatch
  // --------------------------------------------------------------------------

  assign dcls_mismatch_o =
      dcls_instr_mismatch_o ||
      dcls_data_mismatch_o;

endmodule

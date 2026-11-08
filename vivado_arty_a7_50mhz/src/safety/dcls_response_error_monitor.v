`timescale 1ns/1ps

// External comparison of response error status for the two processor channels.
// This is external SoC safety logic; it does not use Ibex internal protection.
module dcls_response_error_monitor (
    input  wire compare_en_i,

    input  wire core_a_instr_rvalid_i,
    input  wire core_a_instr_err_i,
    input  wire core_b_instr_rvalid_i,
    input  wire core_b_instr_err_i,

    input  wire core_a_data_rvalid_i,
    input  wire core_a_data_err_i,
    input  wire core_b_data_rvalid_i,
    input  wire core_b_data_err_i,

    output wire instr_error_mismatch_o,
    output wire data_error_mismatch_o
);

  // Error is meaningful only with a valid response. The existing transaction
  // comparator independently detects response-valid disagreement.
  assign instr_error_mismatch_o =
      compare_en_i &&
      core_a_instr_rvalid_i && core_b_instr_rvalid_i &&
      (core_a_instr_err_i != core_b_instr_err_i);

  assign data_error_mismatch_o =
      compare_en_i &&
      core_a_data_rvalid_i && core_b_data_rvalid_i &&
      (core_a_data_err_i != core_b_data_err_i);

endmodule

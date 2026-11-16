`timescale 1ns/1ps
module dcls_response_error_monitor_tb;
  logic compare_en_i;
  logic core_a_instr_rvalid_i, core_a_instr_err_i;
  logic core_b_instr_rvalid_i, core_b_instr_err_i;
  logic core_a_data_rvalid_i, core_a_data_err_i;
  logic core_b_data_rvalid_i, core_b_data_err_i;
  wire instr_error_mismatch_o, data_error_mismatch_o;

  dcls_response_error_monitor dut (.*);

  task automatic expect_state(input string name,
                              input logic expected_instr,
                              input logic expected_data);
    begin
      #1;
      if (instr_error_mismatch_o !== expected_instr ||
          data_error_mismatch_o !== expected_data) begin
        $display("FAIL: %s", name);
        $display("Expected instr=%b data=%b; actual instr=%b data=%b",
                 expected_instr, expected_data,
                 instr_error_mismatch_o, data_error_mismatch_o);
        $fatal(1, "Response-error monitor failed: %s", name);
      end
      $display("PASS: %s", name);
    end
  endtask

  initial begin
    compare_en_i=1;
    core_a_instr_rvalid_i=0; core_a_instr_err_i=0;
    core_b_instr_rvalid_i=0; core_b_instr_err_i=0;
    core_a_data_rvalid_i=0; core_a_data_err_i=0;
    core_b_data_rvalid_i=0; core_b_data_err_i=0;
    expect_state("inactive responses",0,0);

    core_a_instr_rvalid_i=1; core_b_instr_rvalid_i=1;
    expect_state("matching instruction response status",0,0);
    core_b_instr_err_i=1;
    expect_state("instruction response-error mismatch",1,0);
    core_a_instr_rvalid_i=0; core_b_instr_rvalid_i=0;
    expect_state("instruction error ignored without valid response",0,0);

    core_a_data_rvalid_i=1; core_b_data_rvalid_i=1;
    expect_state("matching data response status",0,0);
    core_b_data_err_i=1;
    expect_state("data response-error mismatch",0,1);
    core_a_data_rvalid_i=0; core_b_data_rvalid_i=0;
    expect_state("data error ignored without valid response",0,0);

    compare_en_i=0;
    core_a_instr_rvalid_i=1; core_b_instr_rvalid_i=1;
    core_a_instr_err_i=1; core_b_instr_err_i=0;
    core_a_data_rvalid_i=1; core_b_data_rvalid_i=1;
    core_a_data_err_i=1; core_b_data_err_i=0;
    expect_state("comparison disabled",0,0);

    $display("");
    $display("DCLS RESPONSE-ERROR MONITOR: PASS");
    $finish;
  end
endmodule

`timescale 1ns/1ps

module safety_fault_manager_tb;

  logic clk_i;
  logic rst_ni;
  logic dcls_instr_mismatch_i;
  logic dcls_data_mismatch_i;

  wire fault_latched_o;
  wire instr_fault_seen_o;
  wire data_fault_seen_o;
  wire [7:0] fault_code_o;
  wire safe_state_req_o;

  safety_fault_manager dut (
      .clk_i                 (clk_i),
      .rst_ni                (rst_ni),
      .dcls_instr_mismatch_i (dcls_instr_mismatch_i),
      .dcls_data_mismatch_i  (dcls_data_mismatch_i),
      .fault_latched_o       (fault_latched_o),
      .instr_fault_seen_o    (instr_fault_seen_o),
      .data_fault_seen_o     (data_fault_seen_o),
      .fault_code_o          (fault_code_o),
      .safe_state_req_o      (safe_state_req_o)
  );

  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  task automatic check_state(
      input string test_name,
      input logic expected_fault,
      input logic expected_instr_seen,
      input logic expected_data_seen,
      input logic [7:0] expected_code,
      input logic expected_safe_state
  );
    begin
      if ((fault_latched_o    !== expected_fault)       ||
          (instr_fault_seen_o !== expected_instr_seen)  ||
          (data_fault_seen_o  !== expected_data_seen)   ||
          (fault_code_o       !== expected_code)        ||
          (safe_state_req_o   !== expected_safe_state)) begin
        $display("FAIL: %s", test_name);
        $display("  expected fault=%b instr=%b data=%b code=%h safe=%b",
                 expected_fault, expected_instr_seen, expected_data_seen,
                 expected_code, expected_safe_state);
        $display("  actual   fault=%b instr=%b data=%b code=%h safe=%b",
                 fault_latched_o, instr_fault_seen_o, data_fault_seen_o,
                 fault_code_o, safe_state_req_o);
        $fatal(1, "Safety Fault Manager test failed");
      end

      $display("PASS: %s", test_name);
    end
  endtask

  task automatic apply_reset;
    begin
      rst_ni = 1'b0;
      dcls_instr_mismatch_i = 1'b0;
      dcls_data_mismatch_i = 1'b0;
      #1;
      check_state("asynchronous reset clears state",
                  1'b0, 1'b0, 1'b0, 8'h00, 1'b0);
      @(posedge clk_i);
      #1;
      rst_ni = 1'b1;
      @(negedge clk_i);
    end
  endtask

  initial begin
    rst_ni = 1'b1;
    dcls_instr_mismatch_i = 1'b0;
    dcls_data_mismatch_i = 1'b0;

    apply_reset();
    check_state("idle after reset",
                1'b0, 1'b0, 1'b0, 8'h00, 1'b0);

    // Instruction fault: latch code and request safe state.
    dcls_instr_mismatch_i = 1'b1;
    @(posedge clk_i);
    #1;
    check_state("instruction mismatch latches fault",
                1'b1, 1'b1, 1'b0, 8'h01, 1'b1);

    // Clear the input; latched fault must remain.
    @(negedge clk_i);
    dcls_instr_mismatch_i = 1'b0;
    @(posedge clk_i);
    #1;
    check_state("instruction fault remains latched",
                1'b1, 1'b1, 1'b0, 8'h01, 1'b1);

    // A later data fault is recorded but does not overwrite the first code.
    @(negedge clk_i);
    dcls_data_mismatch_i = 1'b1;
    @(posedge clk_i);
    #1;
    check_state("later data fault recorded without code overwrite",
                1'b1, 1'b1, 1'b1, 8'h01, 1'b1);

    apply_reset();

    // Data-only fault.
    dcls_data_mismatch_i = 1'b1;
    @(posedge clk_i);
    #1;
    check_state("data mismatch latches data code",
                1'b1, 1'b0, 1'b1, 8'h02, 1'b1);

    apply_reset();

    // Simultaneous fault categories: both diagnostics, instruction priority.
    dcls_instr_mismatch_i = 1'b1;
    dcls_data_mismatch_i = 1'b1;
    @(posedge clk_i);
    #1;
    check_state("simultaneous mismatches record both categories",
                1'b1, 1'b1, 1'b1, 8'h01, 1'b1);

    // Verify recovery through reset and a new independent data fault.
    apply_reset();
    dcls_instr_mismatch_i = 1'b0;
    dcls_data_mismatch_i = 1'b1;
    @(posedge clk_i);
    #1;
    check_state("new fault sequence works after reset",
                1'b1, 1'b0, 1'b1, 8'h02, 1'b1);

    $display("");
    $display("==============================================");
    $display("SAFETY FAULT MANAGER STAGE-4A PASS");
    $display("==============================================");
    $finish;
  end

endmodule

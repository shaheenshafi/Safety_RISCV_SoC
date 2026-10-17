
`timescale 1ns/1ps

module safety_riscv_soc_stage4b_tb;

  reg clk_i;
  reg rst_ni;
  reg dcls_enable_i;

  reg fault_inject_enable_i;
  reg [1:0] fault_inject_target_i;
  reg [31:0] fault_inject_mask_i;

  reg core_b_response_fault_inject_enable_i;
  reg [2:0] core_b_response_fault_inject_target_i;
  reg [31:0] core_b_response_fault_inject_mask_i;

  wire dcls_instr_mismatch_o;
  wire dcls_data_mismatch_o;
  wire dcls_mismatch_o;

  wire fault_latched_o;
  wire instr_fault_seen_o;
  wire data_fault_seen_o;
  wire [7:0] fault_code_o;
  wire safe_state_req_o;

  integer cycle_counter;

  reg fault_activation_seen;
  reg dcls_detection_seen;
  reg core_a_write_seen;
  reg core_b_write_seen;
  reg core_b_address_divergence_seen;
  reg manager_fault_seen;

  reg [31:0] original_instruction;
  reg [31:0] injected_mask;
  reg [31:0] corrupted_instruction;

  reg [31:0] core_a_write_address;
  reg [31:0] core_a_write_data;
  reg [31:0] core_b_write_address;
  reg [31:0] core_b_write_data;

  safety_riscv_soc_stage4b dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .dcls_enable_i(dcls_enable_i),

      .fault_inject_enable_i(fault_inject_enable_i),
      .fault_inject_target_i(fault_inject_target_i),
      .fault_inject_mask_i(fault_inject_mask_i),

      .core_b_response_fault_inject_enable_i(
          core_b_response_fault_inject_enable_i),
      .core_b_response_fault_inject_target_i(
          core_b_response_fault_inject_target_i),
      .core_b_response_fault_inject_mask_i(
          core_b_response_fault_inject_mask_i),

      .dcls_instr_mismatch_o(dcls_instr_mismatch_o),
      .dcls_data_mismatch_o(dcls_data_mismatch_o),
      .dcls_mismatch_o(dcls_mismatch_o),

      .fault_latched_o(fault_latched_o),
      .instr_fault_seen_o(instr_fault_seen_o),
      .data_fault_seen_o(data_fault_seen_o),
      .fault_code_o(fault_code_o),
      .safe_state_req_o(safe_state_req_o)
  );

  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  always @(negedge clk_i) begin
    if (rst_ni &&
        !fault_activation_seen &&
        dut.u_stage3.core_b_instr_rvalid &&
        dut.u_stage3.core_b_instr_rdata == 32'h001000B7) begin

      original_instruction =
          dut.u_stage3.core_b_instr_rdata;
      injected_mask = 32'h00001000;
      corrupted_instruction =
          original_instruction ^ injected_mask;

      core_b_response_fault_inject_target_i = 3'b000;
      core_b_response_fault_inject_mask_i = injected_mask;
      core_b_response_fault_inject_enable_i = 1'b1;
      fault_activation_seen = 1'b1;

      $display(
          "[%0t] Injecting instruction fault: %08h -> %08h",
          $time, original_instruction, corrupted_instruction
      );
    end
  end

  always @(posedge clk_i) begin
    if (rst_ni) begin
      cycle_counter <= cycle_counter + 1;

      if (dcls_instr_mismatch_o && !dcls_detection_seen) begin
        dcls_detection_seen <= 1'b1;
        $display("[%0t] DCLS instruction mismatch detected", $time);
      end

      if (core_b_response_fault_inject_enable_i)
        core_b_response_fault_inject_enable_i <= 1'b0;

      #1;

      if (dut.u_stage3.core_a_data_req &&
          dut.u_stage3.core_a_data_we) begin
        core_a_write_address =
            dut.u_stage3.core_a_data_addr;
        core_a_write_data =
            dut.u_stage3.core_a_data_wdata;

        if (core_a_write_address == 32'h00100000 &&
            core_a_write_data == 32'h0000002A) begin
          core_a_write_seen = 1'b1;
          $display(
              "[%0t] Core A write: addr=%08h data=%08h",
              $time, core_a_write_address, core_a_write_data
          );
        end
      end

      if (dut.u_stage3.core_b_data_req &&
          dut.u_stage3.core_b_data_we) begin
        core_b_write_address =
            dut.u_stage3.core_b_data_addr;
        core_b_write_data =
            dut.u_stage3.core_b_data_wdata;

        if (core_b_write_address == 32'h00101000 &&
            core_b_write_data == 32'h0000002A) begin
          core_b_write_seen = 1'b1;
          core_b_address_divergence_seen = 1'b1;
          $display(
              "[%0t] Core B write: addr=%08h data=%08h",
              $time, core_b_write_address, core_b_write_data
          );
        end
      end

      if (rst_ni && fault_latched_o)
        manager_fault_seen = 1'b1;
    end
  end

  initial begin
    rst_ni = 1'b0;
    dcls_enable_i = 1'b0;

    fault_inject_enable_i = 1'b0;
    fault_inject_target_i = 2'b00;
    fault_inject_mask_i = 32'b0;

    core_b_response_fault_inject_enable_i = 1'b0;
    core_b_response_fault_inject_target_i = 3'b000;
    core_b_response_fault_inject_mask_i = 32'b0;

    cycle_counter = 0;
    fault_activation_seen = 1'b0;
    dcls_detection_seen = 1'b0;
    core_a_write_seen = 1'b0;
    core_b_write_seen = 1'b0;
    core_b_address_divergence_seen = 1'b0;
    manager_fault_seen = 1'b0;

    original_instruction = 32'b0;
    injected_mask = 32'b0;
    corrupted_instruction = 32'b0;
    core_a_write_address = 32'b0;
    core_a_write_data = 32'b0;
    core_b_write_address = 32'b0;
    core_b_write_data = 32'b0;

    repeat (2) @(posedge clk_i);
    #1;
    rst_ni = 1'b1;
    dcls_enable_i = 1'b1;

    fork
      begin
        wait (fault_activation_seen &&
              dcls_detection_seen &&
              core_a_write_seen &&
              core_b_write_seen &&
              core_b_address_divergence_seen &&
              manager_fault_seen);

        @(negedge clk_i);
        #1;

        if (original_instruction !== 32'h001000B7)
          $fatal(1, "Unexpected original instruction: %08h",
                 original_instruction);

        if (corrupted_instruction !== 32'h001010B7)
          $fatal(1, "Unexpected corrupted instruction: %08h",
                 corrupted_instruction);

        if (core_a_write_address !== 32'h00100000 ||
            core_a_write_data !== 32'h0000002A)
          $fatal(1, "Core A transaction incorrect");

        if (core_b_write_address !== 32'h00101000 ||
            core_b_write_data !== 32'h0000002A)
          $fatal(1, "Core B divergence transaction incorrect");

        if (fault_latched_o !== 1'b1)
          $fatal(1, "Fault manager did not latch the fault");

        if (instr_fault_seen_o !== 1'b1)
          $fatal(1, "Instruction diagnostic bit not set");

        if (data_fault_seen_o !== 1'b0)
          $fatal(1, "Unexpected data diagnostic bit set");

        if (fault_code_o !== 8'h01)
          $fatal(1, "Expected instruction fault code 0x01, got %02h",
                 fault_code_o);

        if (safe_state_req_o !== 1'b1)
          $fatal(1, "Safe-state request not asserted");

        // Observe the mismatch and manager state over three cycles.
        repeat (3) begin
          @(posedge clk_i);
          #1;
          $display(
              "[%0t] DCLS=%b instr=%b data=%b latched=%b code=0x%02h",
              $time,
              dcls_mismatch_o,
              dcls_instr_mismatch_o,
              dcls_data_mismatch_o,
              fault_latched_o,
              fault_code_o
          );
        end

        // Require the transient DCLS mismatch to have cleared.
        if (dcls_mismatch_o !== 1'b0)
          $fatal(1, "DCLS mismatch did not clear");

        // The manager must retain the fault after mismatch clears.
        if (fault_latched_o !== 1'b1 ||
            instr_fault_seen_o !== 1'b1 ||
            fault_code_o !== 8'h01 ||
            safe_state_req_o !== 1'b1)
          $fatal(1, "Fault state was not retained after mismatch cleared");

        // Reset must clear the manager's sticky state.
        rst_ni = 1'b0;
        #1;

        if (fault_latched_o !== 1'b0 ||
            instr_fault_seen_o !== 1'b0 ||
            data_fault_seen_o !== 1'b0 ||
            fault_code_o !== 8'h00 ||
            safe_state_req_o !== 1'b0)
          $fatal(1, "Manager state did not clear on reset");

        $display("");
        $display("==============================================");
        $display("STAGE4B FAULT MANAGER INTEGRATION PASS");
        $display("Core-B execution divergence : CONFIRMED");
        $display("DCLS instruction detection  : CONFIRMED");
        $display("Fault latch and code        : CONFIRMED");
        $display("Safe-state request          : CONFIRMED");
        $display("Sticky state and reset      : CONFIRMED");
        $display("==============================================");
        $finish;
      end

      begin
        repeat (200) @(posedge clk_i);
        $fatal(
            1,
            "Timeout: activation=%0d detection=%0d CoreA=%0d CoreB=%0d divergence=%0d manager=%0d",
            fault_activation_seen,
            dcls_detection_seen,
            core_a_write_seen,
            core_b_write_seen,
            core_b_address_divergence_seen,
            manager_fault_seen
        );
      end
    join_any

    disable fork;
  end

endmodule

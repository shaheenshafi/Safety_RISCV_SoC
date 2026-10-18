
`timescale 1ns/1ps

module safety_riscv_soc_stage4d_tb;

  reg clk_i;
  reg rst_ni;

  reg [1:0] profile_i;
  reg injection_authorize_i;

  reg [1:0] fault_inject_target_i;
  reg [31:0] fault_inject_mask_i;

  reg [2:0] core_b_response_fault_inject_target_i;
  reg [31:0] core_b_response_fault_inject_mask_i;

  wire [1:0] selected_profile_o;
  wire profile_valid_o;
  wire dcls_enable_o;
  wire fault_injection_enable_o;

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
  reg manager_fault_seen;
  reg safe_state_seen;
  reg core_a_ram_write_blocked_seen;
  reg core_b_ram_write_blocked_seen;
  reg core_b_divergent_ram_write_seen;

  reg [31:0] original_instruction;
  reg [31:0] injected_mask;
  reg [31:0] corrupted_instruction;

  reg [31:0] core_a_write_address;
  reg [31:0] core_a_write_data;
  reg [31:0] core_b_write_address;
  reg [31:0] core_b_write_data;

  safety_riscv_soc_stage4d dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .profile_i(profile_i),
      .injection_authorize_i(injection_authorize_i),

      .fault_inject_target_i(fault_inject_target_i),
      .fault_inject_mask_i(fault_inject_mask_i),

      .core_b_response_fault_inject_target_i(
          core_b_response_fault_inject_target_i),
      .core_b_response_fault_inject_mask_i(
          core_b_response_fault_inject_mask_i),

      .selected_profile_o(selected_profile_o),
      .profile_valid_o(profile_valid_o),
      .dcls_enable_o(dcls_enable_o),
      .fault_injection_enable_o(fault_injection_enable_o),

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
        dut.core_b_instr_rvalid &&
        dut.core_b_instr_rdata == 32'h001000B7) begin

      original_instruction =
          dut.core_b_instr_rdata;
      injected_mask = 32'h00001000;
      corrupted_instruction =
          original_instruction ^ injected_mask;

      core_b_response_fault_inject_target_i = 3'b000;
      core_b_response_fault_inject_mask_i = injected_mask;
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


      if (dut.core_b.u_ram.a_req_i &&
          dut.core_b.u_ram.a_we_i &&
          dut.core_b.u_ram.a_addr_i == 32'h00001000 &&
          dut.core_b.u_ram.a_wdata_i == 32'h0000002A)
        core_b_divergent_ram_write_seen = 1'b1;

      #1;
      if (fault_latched_o &&
          !dut.core_a.core_rst_ni &&
          !dut.core_b.core_rst_ni) begin
        safe_state_seen = 1'b1;
      end

      if (fault_latched_o && !dut.core_a.ram_data_we)
        core_a_ram_write_blocked_seen = 1'b1;

      if (fault_latched_o && !dut.core_b.ram_data_we)
        core_b_ram_write_blocked_seen = 1'b1;



      if (dut.core_a_data_req &&
          dut.core_a_data_we) begin
        core_a_write_address =
            dut.core_a_data_addr;
        core_a_write_data =
            dut.core_a_data_wdata;

        if (core_a_write_address == 32'h00100000 &&
            core_a_write_data == 32'h0000002A) begin
          core_a_write_seen = 1'b1;
          $display(
              "[%0t] Core A write: addr=%08h data=%08h",
              $time, core_a_write_address, core_a_write_data
          );
        end
      end

      if (dut.core_b_data_req &&
          dut.core_b_data_we) begin
        core_b_write_address =
            dut.core_b_data_addr;
        core_b_write_data =
            dut.core_b_data_wdata;

        if (core_b_write_address == 32'h00101000 &&
            core_b_write_data == 32'h0000002A) begin
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
    profile_i = 2'b10; // Diagnostic profile
    injection_authorize_i = 1'b1;

    fault_inject_target_i = 2'b00;
    fault_inject_mask_i = 32'b0;

    core_b_response_fault_inject_target_i = 3'b000;
    core_b_response_fault_inject_mask_i = 32'b0;

    cycle_counter = 0;
    fault_activation_seen = 1'b0;
    dcls_detection_seen = 1'b0;
    core_a_write_seen = 1'b0;
    manager_fault_seen = 1'b0;
    safe_state_seen = 1'b0;
    core_a_ram_write_blocked_seen = 1'b0;
    core_b_ram_write_blocked_seen = 1'b0;
    core_b_divergent_ram_write_seen = 1'b0;

    original_instruction = 32'b0;
    injected_mask = 32'b0;
    corrupted_instruction = 32'b0;
    core_a_write_address = 32'b0;
    core_a_write_data = 32'b0;
    core_b_write_address = 32'b0;
    core_b_write_data = 32'b0;

    // Check integrated profile policy while the processors remain in reset.
    profile_i = 2'b00; // Basic
    injection_authorize_i = 1'b0;
    #1;
    if (selected_profile_o !== 2'b00 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b0 ||
        fault_injection_enable_o !== 1'b0)
      $fatal(1, "Basic profile policy failed");
    $display("PASS: Basic profile disables DCLS and injection");

    profile_i = 2'b01; // Safety
    injection_authorize_i = 1'b1;
    #1;
    if (selected_profile_o !== 2'b01 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b1 ||
        fault_injection_enable_o !== 1'b0)
      $fatal(1, "Safety profile policy failed");
    $display("PASS: Safety profile enables DCLS but disables injection");

    profile_i = 2'b10; // Diagnostic, unauthorized
    injection_authorize_i = 1'b0;
    #1;
    if (selected_profile_o !== 2'b10 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b1 ||
        fault_injection_enable_o !== 1'b0)
      $fatal(1, "Unauthorized Diagnostic profile policy failed");
    $display("PASS: Diagnostic profile requires explicit authorization");

    injection_authorize_i = 1'b1;
    #1;
    if (dcls_enable_o !== 1'b1 ||
        fault_injection_enable_o !== 1'b1)
      $fatal(1, "Authorized Diagnostic profile policy failed");
    $display("PASS: Authorized Diagnostic profile enables injection");

    profile_i = 2'b11; // Reserved
    #1;
    if (selected_profile_o !== 2'b11 ||
        profile_valid_o !== 1'b0 ||
        dcls_enable_o !== 1'b0 ||
        fault_injection_enable_o !== 1'b0)
      $fatal(1, "Reserved profile policy failed");
    $display("PASS: Reserved profile disables DCLS and injection");

    // Start the existing fault-injection scenario in authorized Diagnostic mode.
    profile_i = 2'b10;
    injection_authorize_i = 1'b1;

    repeat (2) @(posedge clk_i);
    #1;
    rst_ni = 1'b1;

    fork
      begin
        wait (fault_activation_seen &&
              dcls_detection_seen &&
              manager_fault_seen &&
              safe_state_seen &&
              core_a_ram_write_blocked_seen &&
              core_b_ram_write_blocked_seen);

        @(negedge clk_i);
        #1;

        if (original_instruction !== 32'h001000B7)
          $fatal(1, "Unexpected original instruction: %08h",
                 original_instruction);

        if (corrupted_instruction !== 32'h001010B7)
          $fatal(1, "Unexpected corrupted instruction: %08h",
                 corrupted_instruction);



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

        if (safe_state_req_o !== 1'b1 ||
            dut.core_a.core_rst_ni !== 1'b0 ||
            dut.core_b.core_rst_ni !== 1'b0)
          $fatal(1, "Both processors did not enter safe state");

        if (core_b_divergent_ram_write_seen)
          $fatal(1, "Divergent Core B write reached RAM interface");

        if (dut.core_a.ram_data_we !== 1'b0 ||
            dut.core_b.ram_data_we !== 1'b0)
          $fatal(1, "RAM write enable was not suppressed");

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

        // A profile change must not clear the already-latched fault.
        profile_i = 2'b00; // Switch to Basic after fault detection.
        injection_authorize_i = 1'b0;
        #1;

        if (selected_profile_o !== 2'b00 ||
            profile_valid_o !== 1'b1 ||
            dcls_enable_o !== 1'b0 ||
            fault_injection_enable_o !== 1'b0)
          $fatal(1, "Basic profile policy failed after fault");

        if (fault_latched_o !== 1'b1 ||
            fault_code_o !== 8'h01 ||
            safe_state_req_o !== 1'b1 ||
            dut.core_a.core_rst_ni !== 1'b0 ||
            dut.core_b.core_rst_ni !== 1'b0 ||
            dut.core_a.ram_data_we !== 1'b0 ||
            dut.core_b.ram_data_we !== 1'b0)
          $fatal(1, "Profile change released latched safe state");

        $display("PASS: Fault latch and safe state persist after switching to Basic");

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
        $display("STAGE4D RUNTIME PROFILE CONTROL PASS");
        $display("Runtime profile policy      : CONFIRMED");
        $display("Diagnostic authorization    : CONFIRMED");
        $display("DCLS instruction detection  : CONFIRMED");
        $display("Fault latch and code        : CONFIRMED");
        $display("Safe-state and processor resets : CONFIRMED");
        $display("Profile-change fault persistence : CONFIRMED");
        $display("Sticky state and reset      : CONFIRMED");
        $display("==============================================");
        $finish;
      end

      begin
        repeat (200) @(posedge clk_i);
        $fatal(
            1,
            "Timeout: activation=%0d detection=%0d manager=%0d safe_state=%0d CoreA_write=%0d CoreA_gate=%0d CoreB_gate=%0d",
            fault_activation_seen,
            dcls_detection_seen,
            manager_fault_seen,
            safe_state_seen,
            core_a_write_seen,
            core_a_ram_write_blocked_seen,
            core_b_ram_write_blocked_seen
        );
      end
    join_any

    disable fork;
  end

endmodule

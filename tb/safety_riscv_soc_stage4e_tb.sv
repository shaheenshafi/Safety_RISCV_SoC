`timescale 1ns/1ps

module safety_riscv_soc_stage4e_tb;

  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;

  reg [1:0] fault_inject_target_i = 2'b00;
  reg [31:0] fault_inject_mask_i = 32'b0;
  reg [2:0] core_b_response_fault_inject_target_i = 3'b000;
  reg [31:0] core_b_response_fault_inject_mask_i = 32'b0;

  wire [1:0] selected_profile_o;
  wire profile_valid_o;
  wire dcls_enable_o;
  wire fault_injection_enable_o;

  wire mmio_interlock_hold_o;
  wire mmio_interlock_fault_o;

  wire dcls_instr_mismatch_o;
  wire dcls_data_mismatch_o;
  wire dcls_mismatch_o;

  wire fault_latched_o;
  wire instr_fault_seen_o;
  wire data_fault_seen_o;
  wire [7:0] fault_code_o;
  wire safe_state_req_o;

  localparam [31:0] RESULT_RAM_ADDR = 32'h00001000;
  localparam [31:0] SUCCESS_MARKER  = 32'h0000600D;
  localparam integer EXPECTED_MMIO_TRANSACTIONS = 9;

  integer mmio_accept_count = 0;

  reg core_a_success_seen = 1'b0;
  reg core_b_success_seen = 1'b0;
  reg interlock_fault_seen = 1'b0;
  reg dcls_mismatch_seen = 1'b0;

  safety_riscv_soc_stage4e dut (
      .clk_i (clk_i),
      .rst_ni (rst_ni),

      .fault_inject_target_i (fault_inject_target_i),
      .fault_inject_mask_i (fault_inject_mask_i),
      .core_b_response_fault_inject_target_i (
          core_b_response_fault_inject_target_i),
      .core_b_response_fault_inject_mask_i (
          core_b_response_fault_inject_mask_i),

      .selected_profile_o (selected_profile_o),
      .profile_valid_o (profile_valid_o),
      .dcls_enable_o (dcls_enable_o),
      .fault_injection_enable_o (fault_injection_enable_o),

      .mmio_interlock_hold_o (mmio_interlock_hold_o),
      .mmio_interlock_fault_o (mmio_interlock_fault_o),

      .dcls_instr_mismatch_o (dcls_instr_mismatch_o),
      .dcls_data_mismatch_o (dcls_data_mismatch_o),
      .dcls_mismatch_o (dcls_mismatch_o),

      .fault_latched_o (fault_latched_o),
      .instr_fault_seen_o (instr_fault_seen_o),
      .data_fault_seen_o (data_fault_seen_o),
      .fault_code_o (fault_code_o),
      .safe_state_req_o (safe_state_req_o)
  );

  always #5 clk_i = ~clk_i;

  // Observe the shared MMIO acceptance and the local RAM result writes.
  always @(posedge clk_i) begin
    if (rst_ni) begin
      if (dut.mmio_gnt) begin
        mmio_accept_count = mmio_accept_count + 1;
        $display(
            "[%0t] MMIO accepted #%0d: addr=%08h we=%b wdata=%08h",
            $time,
            mmio_accept_count,
            dut.core_a_data_addr,
            dut.core_a_data_we,
            dut.core_a_data_wdata
        );
      end

      if (mmio_interlock_fault_o)
        interlock_fault_seen = 1'b1;

      if (dcls_mismatch_o)
        dcls_mismatch_seen = 1'b1;

      if (dut.core_a.u_ram.a_req_i &&
          dut.core_a.u_ram.a_we_i &&
          dut.core_a.u_ram.a_addr_i == RESULT_RAM_ADDR &&
          dut.core_a.u_ram.a_wdata_i == SUCCESS_MARKER) begin
        core_a_success_seen = 1'b1;
        $display("[%0t] Core A wrote Stage 4E success marker", $time);
      end

      if (dut.core_b.u_ram.a_req_i &&
          dut.core_b.u_ram.a_we_i &&
          dut.core_b.u_ram.a_addr_i == RESULT_RAM_ADDR &&
          dut.core_b.u_ram.a_wdata_i == SUCCESS_MARKER) begin
        core_b_success_seen = 1'b1;
        $display("[%0t] Core B wrote Stage 4E success marker", $time);
      end
    end
  end

  initial begin
    repeat (4) @(posedge clk_i);
    #1;

    if (selected_profile_o !== 2'b00 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b0 ||
        fault_injection_enable_o !== 1'b0)
      $fatal(1, "Stage 4E reset profile policy failed");

    $display("PASS: Stage 4E MMIO profile reset defaults");

    rst_ni = 1'b1;
    if (!$test$plusargs("fault_test") && !$test$plusargs("interlock_test")) $display("Starting dual-core MMIO firmware integration test");

    if (!$test$plusargs("fault_test") && !$test$plusargs("interlock_test")) begin
    fork
      begin
        wait (core_a_success_seen && core_b_success_seen);
        @(negedge clk_i);
        #1;

        if (mmio_accept_count != EXPECTED_MMIO_TRANSACTIONS)
          $fatal(
              1,
              "Expected %0d MMIO transactions, observed %0d",
              EXPECTED_MMIO_TRANSACTIONS,
              mmio_accept_count
          );

        if (selected_profile_o !== 2'b10 ||
            profile_valid_o !== 1'b1 ||
            dcls_enable_o !== 1'b1 ||
            fault_injection_enable_o !== 1'b1)
          $fatal(
              1,
              "Final Diagnostic profile/authorization incorrect: profile=%b valid=%b dcls=%b injection=%b",
              selected_profile_o,
              profile_valid_o,
              dcls_enable_o,
              fault_injection_enable_o
          );

        if (fault_latched_o !== 1'b0 ||
            safe_state_req_o !== 1'b0 ||
            fault_code_o !== 8'h00)
          $fatal(
              1,
              "Unexpected fault/safe state: latched=%b safe=%b code=%02h",
              fault_latched_o,
              safe_state_req_o,
              fault_code_o
          );

        if (interlock_fault_seen || dcls_mismatch_seen)
          $fatal(
              1,
              "Unexpected interlock/DCLS event: interlock=%b dcls=%b",
              interlock_fault_seen,
              dcls_mismatch_seen
          );

        $display("");
        $display("==============================================");
        $display("STAGE 4E MMIO FIRMWARE INTEGRATION PASS");
        $display("Accepted MMIO transactions : %0d", mmio_accept_count);
        $display("Core A success marker      : CONFIRMED");
        $display("Core B success marker      : CONFIRMED");
        $display("Final profile              : DIAGNOSTIC");
        $display("Injection authorization    : ENABLED");
        $display("DCLS/interlock faults      : NONE");
        $display("==============================================");

        $finish;
      end

      begin
        repeat (1000) @(posedge clk_i);
        $fatal(
            1,
            "Timeout: CoreA_success=%b CoreB_success=%b MMIO_count=%0d fault=%b code=%02h",
            core_a_success_seen,
            core_b_success_seen,
            mmio_accept_count,
            fault_latched_o,
            fault_code_o
        );
      end
    join_any

    disable fork;
    end
  end


  // Opt-in negative-path test:
  // Run the same simulation with +fault_test to corrupt Core B instruction
  // response data after Diagnostic injection authorization becomes effective.
  initial begin
    if ($test$plusargs("fault_test")) begin
      #1;
      core_b_response_fault_inject_target_i = 3'b000; // instruction rdata
      core_b_response_fault_inject_mask_i   = 32'h0000_0001;

      $display("Starting controlled Stage 4E instruction-response fault test");

      wait (rst_ni === 1'b1);
      wait (fault_injection_enable_o === 1'b1);
      #1;

      if (selected_profile_o !== 2'b10 || dcls_enable_o !== 1'b1)
        $fatal(1, "Fault injection enabled outside authorized Diagnostic policy");

      $display("PASS: Diagnostic profile and injection authorization confirmed");

      fork
        begin
          wait (fault_latched_o === 1'b1);
          #1;

          if (instr_fault_seen_o !== 1'b1 ||
              fault_code_o !== 8'h01 ||
              safe_state_req_o !== 1'b1)
            $fatal(
                1,
                "Expected instruction fault and safe state: instr_seen=%b code=%02h safe=%b",
                instr_fault_seen_o,
                fault_code_o,
                safe_state_req_o
            );

          repeat (3) @(posedge clk_i);
          #1;

          if (fault_latched_o !== 1'b1 ||
              fault_code_o !== 8'h01 ||
              safe_state_req_o !== 1'b1)
            $fatal(1, "Instruction fault did not remain latched in safe state");

          $display("");
          $display("==============================================");
          $display("STAGE 4E CONTROLLED FAULT-INJECTION PASS");
          $display("Injected target            : Core B instruction rdata");
          $display("Expected fault code        : 0x01");
          $display("Fault latch                : CONFIRMED");
          $display("Safe state                 : CONFIRMED");
          $display("Fault persistence          : CONFIRMED");
          $display("==============================================");

          $finish;
        end

        begin
          repeat (1000) @(posedge clk_i);
          $fatal(
              1,
              "Fault-injection timeout: profile=%b injection=%b latched=%b instr_seen=%b code=%02h",
              selected_profile_o,
              fault_injection_enable_o,
              fault_latched_o,
              instr_fault_seen_o,
              fault_code_o
          );
        end
      join_any
      disable fork;
    end
  end


  // Opt-in negative-path test for the shared MMIO request interlock.
  initial begin
    if ($test$plusargs("interlock_test")) begin
      // Inject an observation-path address disagreement before firmware starts.
      // Core A's first MMIO access is to 0x00200008; report Core B at 0x0020000C.
      force dut.core_b_data_addr = 32'h0020_000C;

      $display("Starting controlled Stage 4E MMIO interlock fault test");

      fork
        begin
          wait (rst_ni === 1'b1);
          wait (fault_latched_o === 1'b1);
          #1;

          if (mmio_accept_count != 0)
            $fatal(1, "MMIO transaction was accepted despite request disagreement: count=%0d",
                   mmio_accept_count);

          if (interlock_fault_seen !== 1'b1)
            $fatal(1, "Expected MMIO interlock fault was not observed");

          if (data_fault_seen_o !== 1'b1 ||
              fault_code_o !== 8'h02 ||
              fault_latched_o !== 1'b1 ||
              safe_state_req_o !== 1'b1)
            $fatal(
                1,
                "Expected data fault and safe state: data_seen=%b latched=%b code=%02h safe=%b",
                data_fault_seen_o,
                fault_latched_o,
                fault_code_o,
                safe_state_req_o
            );

          repeat (3) @(posedge clk_i);
          #1;

          if (fault_latched_o !== 1'b1 ||
              fault_code_o !== 8'h02 ||
              safe_state_req_o !== 1'b1 ||
              mmio_accept_count != 0)
            $fatal(1, "Interlock fault persistence or transaction blocking failed");

          $display("");
          $display("==============================================");
          $display("STAGE 4E MMIO INTERLOCK TEST PASS");
          $display("MMIO transaction accepted   : NO");
          $display("Interlock fault observed    : YES");
          $display("Data fault code             : 0x02");
          $display("Fault latch                 : CONFIRMED");
          $display("Safe state                  : CONFIRMED");
          $display("Fault persistence           : CONFIRMED");
          $display("==============================================");

          $finish;
        end

        begin
          repeat (1000) @(posedge clk_i);
          $fatal(
              1,
              "Interlock test timeout: accepted=%0d hold=%b interlock_fault=%b latched=%b data_seen=%b code=%02h",
              mmio_accept_count,
              mmio_interlock_hold_o,
              mmio_interlock_fault_o,
              fault_latched_o,
              data_fault_seen_o,
              fault_code_o
          );
        end
      join_any
      disable fork;
    end
  end

endmodule

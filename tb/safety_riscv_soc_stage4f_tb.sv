`timescale 1ns/1ps

module safety_riscv_soc_stage4f_tb;

  reg clk_i = 1'b0;
  reg rst_ni = 1'b0;

  reg [1:0]  fault_inject_target_i = 2'b00;
  reg [31:0] fault_inject_mask_i = 32'b0;
  reg [2:0]  core_b_response_fault_inject_target_i = 3'b000;
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
  wire supervisor_fault_seen_o;
  wire [7:0] fault_code_o;
  wire safe_state_req_o;

  wire watchdog_early_fault_o;
  wire watchdog_timeout_fault_o;
  wire progress_timeout_fault_o;
  wire supervisor_fault_o;
  wire [31:0] heartbeat_value_o;
  wire heartbeat_update_o;

  localparam [31:0] RESULT_RAM_ADDR = 32'h00001000;
  localparam [31:0] SUCCESS_MARKER  = 32'h0000600D;

  integer heartbeat_update_count = 0;
  reg core_a_success_seen = 1'b0;
  reg core_b_success_seen = 1'b0;
  reg interlock_fault_seen = 1'b0;
  reg dcls_mismatch_seen = 1'b0;

  safety_riscv_soc_stage4f dut (
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
      .supervisor_fault_seen_o (supervisor_fault_seen_o),
      .fault_code_o (fault_code_o),
      .safe_state_req_o (safe_state_req_o),

      .watchdog_early_fault_o (watchdog_early_fault_o),
      .watchdog_timeout_fault_o (watchdog_timeout_fault_o),
      .progress_timeout_fault_o (progress_timeout_fault_o),
      .supervisor_fault_o (supervisor_fault_o),
      .heartbeat_value_o (heartbeat_value_o),
      .heartbeat_update_o (heartbeat_update_o)
  );

  always #5 clk_i = ~clk_i;

  // Observe accepted firmware heartbeats, success markers and safety events.
  always @(posedge clk_i) begin
    if (rst_ni) begin
      if (heartbeat_update_o) begin
        heartbeat_update_count = heartbeat_update_count + 1;
        $display("[%0t] Heartbeat #%0d, sequence=%08h",
                 $time, heartbeat_update_count, heartbeat_value_o);
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
        $display("[%0t] Core A wrote Stage 4F success marker", $time);
      end

      if (dut.core_b.u_ram.a_req_i &&
          dut.core_b.u_ram.a_we_i &&
          dut.core_b.u_ram.a_addr_i == RESULT_RAM_ADDR &&
          dut.core_b.u_ram.a_wdata_i == SUCCESS_MARKER) begin
        core_b_success_seen = 1'b1;
        $display("[%0t] Core B wrote Stage 4F success marker", $time);
      end
    end
  end

  initial begin
    repeat (4) @(posedge clk_i);
    #1;

    if (selected_profile_o !== 2'b00 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b0 ||
        fault_injection_enable_o !== 1'b0 ||
        fault_latched_o !== 1'b0 ||
        safe_state_req_o !== 1'b0)
      $fatal(1, "Stage 4F reset defaults or initial safe state incorrect");

    $display("PASS: Stage 4F reset profile and fault-manager defaults");

    rst_ni = 1'b1;

    if ($test$plusargs("supervisor_timeout_test")) begin
      $display("Starting controlled Stage 4F heartbeat-loss test");

      fork
        begin
          wait (dcls_enable_o === 1'b1);
          #1;

          if (selected_profile_o !== 2'b01 ||
              profile_valid_o !== 1'b1 ||
              fault_injection_enable_o !== 1'b0)
            $fatal(1, "Firmware did not select valid Safety profile");

          // Testbench-only fault stimulus: suppress the heartbeat observation
          // at the SoC output, leaving firmware and MMIO writes running.
          force dut.heartbeat_update_o = 1'b0;
          $display("[%0t] Heartbeat observation suppressed by testbench",
                   $time);

          wait (fault_latched_o === 1'b1);
          #1;

          if (fault_code_o !== 8'h03 ||
              supervisor_fault_seen_o !== 1'b1 ||
              supervisor_fault_o !== 1'b1 ||
              safe_state_req_o !== 1'b1)
            $fatal(
                1,
                "Expected supervisor fault code 03 and safe state: latched=%b supervisor_seen=%b supervisor_fault=%b code=%02h safe=%b",
                fault_latched_o, supervisor_fault_seen_o,
                supervisor_fault_o, fault_code_o, safe_state_req_o);

          if (watchdog_early_fault_o !== 1'b0 ||
              (watchdog_timeout_fault_o !== 1'b1 &&
               progress_timeout_fault_o !== 1'b1))
            $fatal(
                1,
                "Heartbeat-loss test did not demonstrate a timeout: early=%b watchdog_timeout=%b progress_timeout=%b",
                watchdog_early_fault_o, watchdog_timeout_fault_o,
                progress_timeout_fault_o);

          repeat (3) @(posedge clk_i);
          #1;

          if (fault_latched_o !== 1'b1 ||
              fault_code_o !== 8'h03 ||
              supervisor_fault_seen_o !== 1'b1 ||
              safe_state_req_o !== 1'b1)
            $fatal(1, "Supervisor fault did not remain latched in safe state");

          $display("");
          $display("==============================================");
          $display("STAGE 4F CONTROLLED HEARTBEAT-LOSS PASS");
          $display("Supervisor fault code      : 0x03");
          $display("Timeout detection          : CONFIRMED");
          $display("Sticky fault and safe state: CONFIRMED");
          $display("==============================================");
          $finish;
        end

        begin
          repeat (1200) @(posedge clk_i);
          $fatal(
              1,
              "Heartbeat-loss test timeout: profile=%b latched=%b supervisor_seen=%b code=%02h safe=%b",
              selected_profile_o, fault_latched_o,
              supervisor_fault_seen_o, fault_code_o, safe_state_req_o);
        end
      join_any
      disable fork;

    end else begin
      $display("Starting Stage 4F dual-core heartbeat integration test");

      fork
        begin
          wait (heartbeat_update_count >= 6 &&
                core_a_success_seen &&
                core_b_success_seen);
          @(negedge clk_i);
          #1;

          if (selected_profile_o !== 2'b01 ||
              profile_valid_o !== 1'b1 ||
              dcls_enable_o !== 1'b1 ||
              fault_injection_enable_o !== 1'b0)
            $fatal(
                1,
                "Expected valid Safety profile: profile=%b valid=%b dcls=%b injection=%b",
                selected_profile_o, profile_valid_o,
                dcls_enable_o, fault_injection_enable_o);

          if (fault_latched_o !== 1'b0 ||
              safe_state_req_o !== 1'b0 ||
              fault_code_o !== 8'h00 ||
              supervisor_fault_o !== 1'b0 ||
              watchdog_early_fault_o !== 1'b0 ||
              watchdog_timeout_fault_o !== 1'b0 ||
              progress_timeout_fault_o !== 1'b0)
            $fatal(
                1,
                "Unexpected safety fault during heartbeat operation: latched=%b safe=%b code=%02h supervisor=%b",
                fault_latched_o, safe_state_req_o, fault_code_o,
                supervisor_fault_o);

          if (interlock_fault_seen || dcls_mismatch_seen)
            $fatal(
                1,
                "Unexpected interlock/DCLS event: interlock=%b dcls=%b",
                interlock_fault_seen, dcls_mismatch_seen);

          if (heartbeat_value_o == 32'b0)
            $fatal(1, "Heartbeat sequence register was never updated");

          $display("");
          $display("==============================================");
          $display("STAGE 4F HEARTBEAT INTEGRATION PASS");
          $display("Accepted heartbeat updates : %0d",
                   heartbeat_update_count);
          $display("Core A success marker      : CONFIRMED");
          $display("Core B success marker      : CONFIRMED");
          $display("Runtime profile            : SAFETY");
          $display("Supervisor fault           : NONE");
          $display("DCLS/interlock faults      : NONE");
          $display("==============================================");
          $finish;
        end

        begin
          repeat (2000) @(posedge clk_i);
          $fatal(
              1,
              "Stage 4F integration timeout: heartbeats=%0d CoreA_success=%b CoreB_success=%b fault=%b code=%02h",
              heartbeat_update_count, core_a_success_seen,
              core_b_success_seen, fault_latched_o, fault_code_o);
        end
      join_any
      disable fork;
    end
  end

endmodule

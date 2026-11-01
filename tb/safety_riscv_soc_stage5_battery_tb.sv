`timescale 1ns/1ps

module safety_riscv_soc_stage5_battery_tb;

  reg clk_i = 0;
  reg rst_ni = 0;

  reg [1:0] fault_inject_target_i = 0;
  reg [31:0] fault_inject_mask_i = 0;
  reg [2:0] core_b_response_fault_inject_target_i = 0;
  reg [31:0] core_b_response_fault_inject_mask_i = 0;

  wire [1:0] selected_profile_o;
  wire profile_valid_o, dcls_enable_o, fault_injection_enable_o;
  wire mmio_interlock_hold_o, mmio_interlock_fault_o;
  wire dcls_mismatch_o, dcls_instr_mismatch_o, dcls_data_mismatch_o;
  wire fault_latched_o, safe_state_req_o, supervisor_fault_o;
  wire instr_fault_seen_o, data_fault_seen_o;
  wire supervisor_fault_seen_o;
  wire [7:0] fault_code_o;
  wire watchdog_early_fault_o, watchdog_timeout_fault_o;
  wire progress_timeout_fault_o;
  wire [31:0] heartbeat_value_o;
  wire heartbeat_update_o;

  localparam [31:0] RESULTS_OFFSET = 32'h00000968;
  localparam [31:0] RESULTS_END    = 32'h000009D8;
  localparam [31:0] SUMMARY_OFFSET = 32'h00003FC0;

  localparam [31:0] RUNNING_MARKER = 32'h42545231;
  localparam [31:0] PASS_MARKER    = 32'h42545053;
  localparam [31:0] FAIL_MARKER    = 32'hBAD50001;
  localparam [31:0] SAFETY_STATUS  = 32'h0000000D;

  integer cycle_count = 0;
  integer heartbeat_count = 0;
  integer last_heartbeat_cycle = 0;
  integer interval;
  reg [31:0] last_heartbeat = 0;

  reg core_a_running_seen = 0;
  reg core_b_running_seen = 0;
  reg core_a_pass_seen = 0;
  reg core_b_pass_seen = 0;

  integer core_a_result_word_count = 0;
  integer core_b_result_word_count = 0;

  reg [13:0] core_a_sequence_seen = 0;
  reg [13:0] core_a_flags_seen = 0;
  reg [13:0] core_b_sequence_seen = 0;
  reg [13:0] core_b_flags_seen = 0;

  reg [31:0] core_a_summary [0:8];
  reg [31:0] core_b_summary [0:8];
  reg [8:0] core_a_summary_seen = 0;
  reg [8:0] core_b_summary_seen = 0;

  integer i;
  integer a_result_offset;
  integer b_result_offset;
  integer a_result_index;
  integer b_result_index;
  integer a_summary_index;
  integer b_summary_index;

  function automatic [31:0] expected_flags(input integer index);
    begin
      case (index)
        0: expected_flags = 32'h00;
        1: expected_flags = 32'h01;
        2: expected_flags = 32'h02;
        3: expected_flags = 32'h04;
        4: expected_flags = 32'h08;
        5: expected_flags = 32'h10;
        6: expected_flags = 32'h20;
        7: expected_flags = 32'h25;
        8, 9, 10, 11, 12, 13:
           expected_flags = 32'h00;
        default: expected_flags = 32'hFFFFFFFF;
      endcase
    end
  endfunction

  safety_riscv_soc_stage4f #(
      .MemInitFile("data/stage5_battery_monitor.vmem")
  ) dut (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
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
      .mmio_interlock_hold_o(mmio_interlock_hold_o),
      .mmio_interlock_fault_o(mmio_interlock_fault_o),
      .dcls_instr_mismatch_o(dcls_instr_mismatch_o),
      .dcls_data_mismatch_o(dcls_data_mismatch_o),
      .dcls_mismatch_o(dcls_mismatch_o),
      .fault_latched_o(fault_latched_o),
      .instr_fault_seen_o(instr_fault_seen_o),
      .data_fault_seen_o(data_fault_seen_o),
      .supervisor_fault_seen_o(supervisor_fault_seen_o),
      .fault_code_o(fault_code_o),
      .safe_state_req_o(safe_state_req_o),
      .watchdog_early_fault_o(watchdog_early_fault_o),
      .watchdog_timeout_fault_o(watchdog_timeout_fault_o),
      .progress_timeout_fault_o(progress_timeout_fault_o),
      .supervisor_fault_o(supervisor_fault_o),
      .heartbeat_value_o(heartbeat_value_o),
      .heartbeat_update_o(heartbeat_update_o)
  );

  always #5 clk_i = ~clk_i;

  always @(posedge clk_i) begin
    if (rst_ni) begin
      cycle_count = cycle_count + 1;

      /* Verify the redundant heartbeat MMIO transaction. */
      if (heartbeat_update_o) begin
        if (!dut.core_a.data_req || !dut.core_b.data_req ||
            !dut.core_a.data_we || !dut.core_b.data_we ||
            dut.core_a.data_addr != 32'h00200010 ||
            dut.core_b.data_addr != 32'h00200010 ||
            dut.core_a.data_be != 4'hF ||
            dut.core_b.data_be != 4'hF ||
            dut.core_a.data_wdata != dut.core_b.data_wdata)
          $fatal(1, "Heartbeat MMIO transactions did not match");

        if (heartbeat_count == 0) begin
          if (cycle_count > 256 ||
              dut.core_a.data_wdata != 32'h00000001)
            $fatal(1, "First heartbeat was late or incorrect");
        end else begin
          interval = cycle_count - last_heartbeat_cycle;

          if (interval < 4 || interval > 256)
            $fatal(1, "Heartbeat interval outside window: %0d",
                   interval);

          if (dut.core_a.data_wdata != last_heartbeat + 1)
            $fatal(1, "Heartbeat sequence discontinuity");
        end

        last_heartbeat = dut.core_a.data_wdata;
        last_heartbeat_cycle = cycle_count;
        heartbeat_count = heartbeat_count + 1;
      end

      /* Monitor Core A application RAM writes. */
      if (dut.core_a.u_ram.a_req_i && dut.core_a.u_ram.a_we_i) begin

        if (dut.core_a.u_ram.a_addr_i == SUMMARY_OFFSET &&
            dut.core_a.u_ram.a_wdata_i == RUNNING_MARKER)
          core_a_running_seen = 1;

        if (dut.core_a.u_ram.a_addr_i == SUMMARY_OFFSET &&
            dut.core_a.u_ram.a_wdata_i == FAIL_MARKER)
          $fatal(1, "Core A battery application reported failure");

        if (dut.core_a.u_ram.a_addr_i >= SUMMARY_OFFSET &&
            dut.core_a.u_ram.a_addr_i < SUMMARY_OFFSET + 36) begin
          a_summary_index =
              (dut.core_a.u_ram.a_addr_i - SUMMARY_OFFSET) >> 2;

          core_a_summary[a_summary_index] =
              dut.core_a.u_ram.a_wdata_i;
          core_a_summary_seen[a_summary_index] = 1'b1;

          if (a_summary_index == 0 &&
              dut.core_a.u_ram.a_wdata_i == PASS_MARKER)
            core_a_pass_seen = 1;
        end

        if (core_a_running_seen &&
            dut.core_a.u_ram.a_addr_i >= RESULTS_OFFSET &&
            dut.core_a.u_ram.a_addr_i < RESULTS_END) begin

          a_result_offset =
              dut.core_a.u_ram.a_addr_i - RESULTS_OFFSET;
          a_result_index = a_result_offset >> 3;

          if ((a_result_offset % 8) == 0) begin
            if (dut.core_a.u_ram.a_wdata_i !=
                a_result_index + 1)
              $fatal(1, "Core A sequence mismatch at sample %0d",
                     a_result_index + 1);

            core_a_sequence_seen[a_result_index] = 1'b1;

          end else if ((a_result_offset % 8) == 4) begin
            if (dut.core_a.u_ram.a_wdata_i !=
                expected_flags(a_result_index))
              $fatal(1, "Core A flags mismatch at sample %0d",
                     a_result_index + 1);

            core_a_flags_seen[a_result_index] = 1'b1;

          end else begin
            $fatal(1, "Core A unexpected result address offset");
          end

          core_a_result_word_count =
              core_a_result_word_count + 1;
        end
      end

      /* Monitor Core B application RAM writes. */
      if (dut.core_b.u_ram.a_req_i && dut.core_b.u_ram.a_we_i) begin

        if (dut.core_b.u_ram.a_addr_i == SUMMARY_OFFSET &&
            dut.core_b.u_ram.a_wdata_i == RUNNING_MARKER)
          core_b_running_seen = 1;

        if (dut.core_b.u_ram.a_addr_i == SUMMARY_OFFSET &&
            dut.core_b.u_ram.a_wdata_i == FAIL_MARKER)
          $fatal(1, "Core B battery application reported failure");

        if (dut.core_b.u_ram.a_addr_i >= SUMMARY_OFFSET &&
            dut.core_b.u_ram.a_addr_i < SUMMARY_OFFSET + 36) begin
          b_summary_index =
              (dut.core_b.u_ram.a_addr_i - SUMMARY_OFFSET) >> 2;

          core_b_summary[b_summary_index] =
              dut.core_b.u_ram.a_wdata_i;
          core_b_summary_seen[b_summary_index] = 1'b1;

          if (b_summary_index == 0 &&
              dut.core_b.u_ram.a_wdata_i == PASS_MARKER)
            core_b_pass_seen = 1;
        end

        if (core_b_running_seen &&
            dut.core_b.u_ram.a_addr_i >= RESULTS_OFFSET &&
            dut.core_b.u_ram.a_addr_i < RESULTS_END) begin

          b_result_offset =
              dut.core_b.u_ram.a_addr_i - RESULTS_OFFSET;
          b_result_index = b_result_offset >> 3;

          if ((b_result_offset % 8) == 0) begin
            if (dut.core_b.u_ram.a_wdata_i !=
                b_result_index + 1)
              $fatal(1, "Core B sequence mismatch at sample %0d",
                     b_result_index + 1);

            core_b_sequence_seen[b_result_index] = 1'b1;

          end else if ((b_result_offset % 8) == 4) begin
            if (dut.core_b.u_ram.a_wdata_i !=
                expected_flags(b_result_index))
              $fatal(1, "Core B flags mismatch at sample %0d",
                     b_result_index + 1);

            core_b_flags_seen[b_result_index] = 1'b1;

          end else begin
            $fatal(1, "Core B unexpected result address offset");
          end

          core_b_result_word_count =
              core_b_result_word_count + 1;
        end
      end

      /* No unexpected safety-system event is permitted. */
      if (fault_latched_o || safe_state_req_o ||
          instr_fault_seen_o || data_fault_seen_o ||
          supervisor_fault_seen_o ||
          supervisor_fault_o || watchdog_early_fault_o ||
          watchdog_timeout_fault_o || progress_timeout_fault_o ||
          mmio_interlock_fault_o || dcls_mismatch_o) begin

        $display("DEBUG heartbeat: count=%0d last_cycle=%0d last_value=%08h",
                 heartbeat_count, last_heartbeat_cycle, last_heartbeat);

        $display("DEBUG Core A: fetch_addr=%08h req=%b we=%b addr=%08h wdata=%08h pass=%b summary_seen=%03h",
                 dut.core_a.instr_addr_o, dut.core_a.data_req,
                 dut.core_a.data_we, dut.core_a.data_addr,
                 dut.core_a.data_wdata, core_a_pass_seen,
                 core_a_summary_seen);

        $display("DEBUG Core B: fetch_addr=%08h req=%b we=%b addr=%08h wdata=%08h pass=%b summary_seen=%03h",
                 dut.core_b.instr_addr_o, dut.core_b.data_req,
                 dut.core_b.data_we, dut.core_b.data_addr,
                 dut.core_b.data_wdata, core_b_pass_seen,
                 core_b_summary_seen);

        $fatal(1,
          "Unexpected safety event: code=%02h cycle=%0d profile=%b valid=%b heartbeat_count=%0d heartbeat_update=%b latched=%b safe=%b instr_seen=%b data_seen=%b supervisor_seen=%b supervisor_fault=%b watchdog_early=%b watchdog_timeout=%b progress_timeout=%b mmio_hold=%b mmio_fault=%b dcls_mismatch=%b",
          fault_code_o, cycle_count,
          selected_profile_o, profile_valid_o,
          heartbeat_count, heartbeat_update_o,
          fault_latched_o, safe_state_req_o,
          instr_fault_seen_o, data_fault_seen_o,
          supervisor_fault_seen_o, supervisor_fault_o,
          watchdog_early_fault_o, watchdog_timeout_fault_o,
          progress_timeout_fault_o, mmio_interlock_hold_o,
          mmio_interlock_fault_o, dcls_mismatch_o);
      end
    end
  end

  initial begin
    for (i = 0; i < 9; i = i + 1) begin
      core_a_summary[i] = 0;
      core_b_summary[i] = 0;
    end

    $display("Starting Stage5 battery dual-core integration test");

    repeat (4) @(posedge clk_i);
    #1;

    if (selected_profile_o != 2'b00 ||
        profile_valid_o != 1'b1 ||
        fault_latched_o != 1'b0)
      $fatal(1, "Unexpected reset state");

    rst_ni = 1;

    /* Allow the complete workload and idle heartbeat loop to execute. */
    repeat (6000) @(posedge clk_i);
    #1;

    if (selected_profile_o != 2'b01 ||
        profile_valid_o != 1'b1 ||
        dcls_enable_o != 1'b1 ||
        fault_injection_enable_o != 1'b0)
      $fatal(1, "Safety profile policy verification failed");

    if (!core_a_running_seen || !core_b_running_seen ||
        !core_a_pass_seen || !core_b_pass_seen)
      $fatal(1, "Battery application markers missing");

    if (core_a_result_word_count != 28 ||
        core_b_result_word_count != 28 ||
        core_a_sequence_seen != 14'h3FFF ||
        core_a_flags_seen != 14'h3FFF ||
        core_b_sequence_seen != 14'h3FFF ||
        core_b_flags_seen != 14'h3FFF)
      $fatal(1, "Incomplete per-sample result writes");

    if (core_a_summary_seen != 9'h1FF ||
        core_b_summary_seen != 9'h1FF)
      $fatal(1, "Incomplete summary writes");

    /* Validate Core A summary. */
    if (core_a_summary[0] != PASS_MARKER ||
        core_a_summary[1] != SAFETY_STATUS ||
        core_a_summary[2] != 14 ||
        core_a_summary[3] != 32'h0000003F ||
        core_a_summary[5] != 0 ||
        core_a_summary[6] != 0 ||
        core_a_summary[7] != 18 ||
        core_a_summary[8] != 18)
      $fatal(1, "Core A summary validation failed");

    /* Validate Core B summary. */
    if (core_b_summary[0] != PASS_MARKER ||
        core_b_summary[1] != SAFETY_STATUS ||
        core_b_summary[2] != 14 ||
        core_b_summary[3] != 32'h0000003F ||
        core_b_summary[5] != 0 ||
        core_b_summary[6] != 0 ||
        core_b_summary[7] != 18 ||
        core_b_summary[8] != 18)
      $fatal(1, "Core B summary validation failed");

    if (core_a_summary[4] != core_b_summary[4])
      $fatal(1, "Core A/B result checksums differ");

    if (heartbeat_count < 18 ||
        heartbeat_value_o != last_heartbeat)
      $fatal(1, "Insufficient or inconsistent heartbeat activity");

    $display("");
    $display("STAGE5 BATTERY DUAL-CORE INTEGRATION: PASS");
    $display("Safety profile                 : CONFIRMED");
    $display("Core A sample records           : 14/14");
    $display("Core B sample records           : 14/14");
    $display("Core A result words             : %0d",
             core_a_result_word_count);
    $display("Core B result words             : %0d",
             core_b_result_word_count);
    $display("Aggregate diagnostic mask      : %08h",
             core_a_summary[3]);
    $display("Core A/B checksums              : MATCH");
    $display("Accepted heartbeat updates     : %0d", heartbeat_count);
    $display("Final heartbeat sequence      : %08h", heartbeat_value_o);
    $display("Cycles observed                : %0d", cycle_count);
    $display("DCLS enabled                   : %b", dcls_enable_o);
    $display("Safety fault                   : NONE");
    $display("==============================================");

    $finish;
  end

endmodule

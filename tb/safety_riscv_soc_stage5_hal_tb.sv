`timescale 1ns/1ps

module safety_riscv_soc_stage5_hal_tb;

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

  integer cycle_count = 0;
  integer heartbeat_count = 0;
  integer last_heartbeat_cycle = 0;
  integer interval;
  reg [31:0] last_heartbeat = 0;

  reg core_a_status_seen = 0;
  reg core_b_status_seen = 0;
  reg core_a_pass_seen = 0;
  reg core_b_pass_seen = 0;

  localparam [31:0] RESULT_OFFSET = 32'h00003FC0;
  localparam [31:0] PASS_MARKER = 32'h50415353;
  localparam [31:0] SAFETY_STATUS = 32'h0000000D;

  safety_riscv_soc_stage4f #(
      .MemInitFile("data/stage5_hal_test.vmem")
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

      if (dut.core_a.u_ram.a_req_i && dut.core_a.u_ram.a_we_i) begin
        if (dut.core_a.u_ram.a_addr_i == RESULT_OFFSET &&
            dut.core_a.u_ram.a_wdata_i == PASS_MARKER)
          core_a_pass_seen = 1;

        if (dut.core_a.u_ram.a_addr_i == RESULT_OFFSET + 4) begin
          if (dut.core_a.u_ram.a_wdata_i != SAFETY_STATUS)
            $fatal(1, "Core A incorrect Safety status marker");
          core_a_status_seen = 1;
        end
      end

      if (dut.core_b.u_ram.a_req_i && dut.core_b.u_ram.a_we_i) begin
        if (dut.core_b.u_ram.a_addr_i == RESULT_OFFSET &&
            dut.core_b.u_ram.a_wdata_i == PASS_MARKER)
          core_b_pass_seen = 1;

        if (dut.core_b.u_ram.a_addr_i == RESULT_OFFSET + 4) begin
          if (dut.core_b.u_ram.a_wdata_i != SAFETY_STATUS)
            $fatal(1, "Core B incorrect Safety status marker");
          core_b_status_seen = 1;
        end
      end

      if (fault_latched_o || safe_state_req_o ||
          instr_fault_seen_o || data_fault_seen_o ||
          supervisor_fault_seen_o ||
          supervisor_fault_o || watchdog_early_fault_o ||
          watchdog_timeout_fault_o || progress_timeout_fault_o ||
          mmio_interlock_fault_o || dcls_mismatch_o)
        $fatal(1, "Unexpected safety event: code=%02h cycle=%0d",
               fault_code_o, cycle_count);
    end
  end

  initial begin
    $display("Starting Stage5 HAL dual-core integration test");

    repeat (4) @(posedge clk_i);
    #1;

    if (selected_profile_o != 2'b00 ||
        profile_valid_o != 1'b1 ||
        fault_latched_o != 1'b0)
      $fatal(1, "Unexpected reset state");

    rst_ni = 1;

    repeat (1200) @(posedge clk_i);
    #1;

    if (selected_profile_o != 2'b01 ||
        profile_valid_o != 1'b1 ||
        dcls_enable_o != 1'b1 ||
        fault_injection_enable_o != 1'b0)
      $fatal(1, "Safety profile policy verification failed");

    if (!core_a_status_seen || !core_b_status_seen ||
        !core_a_pass_seen || !core_b_pass_seen)
      $fatal(1, "HAL firmware result markers missing");

    if (heartbeat_count < 5 ||
        heartbeat_value_o != last_heartbeat)
      $fatal(1, "Insufficient or inconsistent heartbeat activity");

    $display("");
    $display("STAGE5 HAL DUAL-CORE INTEGRATION: PASS");
    $display("Safety profile              : CONFIRMED");
    $display("Core A firmware marker      : CONFIRMED");
    $display("Core B firmware marker      : CONFIRMED");
    $display("Accepted heartbeat updates  : %0d", heartbeat_count);
    $display("Final heartbeat sequence   : %08h", heartbeat_value_o);
    $display("Cycles observed             : %0d", cycle_count);
    $display("DCLS enabled                : %b", dcls_enable_o);
    $display("Safety fault                : NONE");
    $display("========================================");

    $finish;
  end

endmodule

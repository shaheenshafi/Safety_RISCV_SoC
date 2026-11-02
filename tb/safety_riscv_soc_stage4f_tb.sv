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

  reg [31:0] supervisor_ram_a_before;
  reg [31:0] supervisor_ram_b_before;
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


  // Testbench helper: issue a matched MMIO write through both cores.
  task automatic profile_policy_mmio_write;
    input [31:0] addr;
    input [31:0] wdata;
    input [3:0] byte_enable;
    begin
      @(negedge clk_i);

      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b1;
      force dut.core_a.data_be    = byte_enable;
      force dut.core_a.data_addr  = addr;
      force dut.core_a.data_wdata = wdata;

      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b1;
      force dut.core_b.data_be    = byte_enable;
      force dut.core_b.data_addr  = addr;
      force dut.core_b.data_wdata = wdata;

      #1;

      if (dut.mmio_req !== 1'b1 ||
          dut.mmio_gnt !== 1'b1 ||
          mmio_interlock_hold_o !== 1'b0)
        $fatal(1, "Matched MMIO write rejected: addr=%08h", addr);

      @(posedge clk_i);
      #1;

      if (dut.mmio_rvalid !== 1'b1)
        $fatal(1, "MMIO response missing: addr=%08h", addr);

      release dut.core_a.data_req;
      release dut.core_a.data_we;
      release dut.core_a.data_be;
      release dut.core_a.data_addr;
      release dut.core_a.data_wdata;

      release dut.core_b.data_req;
      release dut.core_b.data_we;
      release dut.core_b.data_be;
      release dut.core_b.data_addr;
      release dut.core_b.data_wdata;
    end
  endtask

  initial begin
    repeat (4) @(posedge clk_i);
    #1;

    if (selected_profile_o !== 2'b00 ||
        profile_valid_o !== 1'b1 ||
        dcls_enable_o !== 1'b0 ||
        fault_injection_enable_o !== 1'b0 ||
        fault_latched_o !== 1'b0 ||
        safe_state_req_o !== 1'b0 ||
        dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Stage 4F reset defaults or initial safe state incorrect");

    $display("PASS: Stage 4F reset profile and fault-manager defaults");

    rst_ni = 1'b1;
    #1;

    if (dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Core reset released asynchronously");

    @(posedge clk_i);
    #1;
    if (dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Core reset released before the second rising edge");

    @(posedge clk_i);
    #1;
    if (dut.core_a.core_rst_ni !== 1'b1 ||
        dut.core_b.core_rst_ni !== 1'b1)
      $fatal(1, "Core reset did not release after two rising edges");

    $display("PASS: Core reset asserts asynchronously and releases after two rising edges");

    if ($test$plusargs("profile_policy_test")) begin
      $display("Starting Stage 4F profile-policy integration test");

      // Hold both processors in reset to isolate the MMIO peripheral.
      force dut.core_a.core_rst_ni = 1'b0;
      force dut.core_b.core_rst_ni = 1'b0;
      #1;

      if (dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "Failed to hold both cores in reset");

      // Basic profile is the reset default.
      if (selected_profile_o !== 2'b00 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b0 ||
          fault_injection_enable_o !== 1'b0 ||
          dut.u_execution_supervisor.enable_i !== 1'b1)
        $fatal(1, "Basic profile policy incorrect");

      $display("PASS: Basic profile and supervisor enable");

      // Safety profile.
      profile_policy_mmio_write(32'h0020_0000, 32'h1, 4'hF);

      if (selected_profile_o !== 2'b01 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b1 ||
          fault_injection_enable_o !== 1'b0 ||
          dut.u_execution_supervisor.enable_i !== 1'b1)
        $fatal(1, "Safety profile policy incorrect");

      $display("PASS: Safety profile");

      // Reserved profile must not replace the selected Safety profile.
      profile_policy_mmio_write(32'h0020_0000, 32'h3, 4'hF);

      if (selected_profile_o !== 2'b01 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b1)
        $fatal(1, "Reserved profile write was not rejected");

      $display("PASS: Reserved profile rejection");

      // Diagnostic profile, initially without injection authorisation.
      profile_policy_mmio_write(32'h0020_0000, 32'h2, 4'hF);

      if (selected_profile_o !== 2'b10 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b1 ||
          fault_injection_enable_o !== 1'b0 ||
          dut.u_execution_supervisor.enable_i !== 1'b1)
        $fatal(1, "Diagnostic profile policy incorrect");

      profile_policy_mmio_write(32'h0020_0004, 32'h1, 4'h1);

      if (fault_injection_enable_o !== 1'b1)
        $fatal(1, "Diagnostic injection authorisation failed");

      profile_policy_mmio_write(32'h0020_0004, 32'h0, 4'h1);

      if (fault_injection_enable_o !== 1'b0)
        $fatal(1, "Diagnostic injection revocation failed");

      $display("PASS: Diagnostic profile and injection authorisation");

      // Return to Basic. Supervision must remain active.
      profile_policy_mmio_write(32'h0020_0000, 32'h0, 4'hF);

      if (selected_profile_o !== 2'b00 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b0 ||
          fault_injection_enable_o !== 1'b0 ||
          dut.u_execution_supervisor.enable_i !== 1'b1)
        $fatal(1, "Basic profile transition or supervisor enable failed");

      $display("PASS: Supervisor remains enabled in Basic profile");

      // Two changed heartbeat values, separated by a valid interval.
      profile_policy_mmio_write(32'h0020_0010, 32'h1, 4'hF);

      if (heartbeat_value_o !== 32'h1)
        $fatal(1, "First heartbeat was not registered");

      repeat (8) @(posedge clk_i);

      profile_policy_mmio_write(32'h0020_0010, 32'h2, 4'hF);

      if (heartbeat_value_o !== 32'h2 ||
          supervisor_fault_o !== 1'b0 ||
          watchdog_early_fault_o !== 1'b0 ||
          watchdog_timeout_fault_o !== 1'b0 ||
          progress_timeout_fault_o !== 1'b0)
        $fatal(1, "Basic heartbeat servicing failed");

      $display("PASS: Basic heartbeat servicing");

      // No further progress: expect supervisor timeout and safe state.
      repeat (270) @(posedge clk_i);
      #1;

      if (fault_latched_o !== 1'b1 ||
          fault_code_o !== 8'h03 ||
          supervisor_fault_seen_o !== 1'b1 ||
          supervisor_fault_o !== 1'b1 ||
          safe_state_req_o !== 1'b1 ||
          watchdog_early_fault_o !== 1'b0 ||
          (watchdog_timeout_fault_o !== 1'b1 &&
           progress_timeout_fault_o !== 1'b1))
        $fatal(1, "Basic-profile timeout handling failed");

      $display("");
      $display("==============================================");
      $display("STAGE 4F PROFILE POLICY INTEGRATION PASS");
      $display("Profile policies              : CONFIRMED");
      $display("Reserved profile rejection    : CONFIRMED");
      $display("Injection authorisation       : CONFIRMED");
      $display("Basic heartbeat servicing     : CONFIRMED");
      $display("Basic timeout and safe state   : CONFIRMED");
      $display("Supervisor fault code          : 0x03");
      $display("==============================================");
      $finish;

    end else if ($test$plusargs("address_guard_test")) begin
      $display("Starting Stage 4G RAM address-guard test");
      wait (dcls_enable_o === 1'b1 &&
            core_a_success_seen && core_b_success_seen);

      // Last valid word: check decode without allowing a clocked write.
      @(negedge clk_i);
      #1;
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b1;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h0010_3FFC;
      force dut.core_a.data_wdata = 32'h1357_9BDF;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b1;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h0010_3FFC;
      force dut.core_b.data_wdata = 32'h1357_9BDF;
      #1;

      if (dut.core_a.data_addr_fault_o !== 1'b0 ||
          dut.core_b.data_addr_fault_o !== 1'b0 ||
          dut.core_a.u_ram.a_req_i !== 1'b1 ||
          dut.core_b.u_ram.a_req_i !== 1'b1)
        $fatal(1, "Last valid RAM word was incorrectly blocked");

      release dut.core_a.data_req;
      release dut.core_a.data_we;
      release dut.core_a.data_be;
      release dut.core_a.data_addr;
      release dut.core_a.data_wdata;
      release dut.core_b.data_req;
      release dut.core_b.data_we;
      release dut.core_b.data_be;
      release dut.core_b.data_addr;
      release dut.core_b.data_wdata;

      // Probe below the RAM base. Release before the next rising edge so
      // this checks the decode without latching a fault.
      @(negedge clk_i);
      #1;
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b1;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h000F_FFFC;
      force dut.core_a.data_wdata = 32'h2468_ACE0;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b1;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h000F_FFFC;
      force dut.core_b.data_wdata = 32'h2468_ACE0;
      #1;

      if (dut.core_a.data_addr_fault_o !== 1'b1 ||
          dut.core_b.data_addr_fault_o !== 1'b1 ||
          dut.core_a.data_gnt !== 1'b1 ||
          dut.core_b.data_gnt !== 1'b1 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0 ||
          dut.core_a.u_ram.a_we_i !== 1'b0 ||
          dut.core_b.u_ram.a_we_i !== 1'b0)
        $fatal(1, "Below-base RAM access was not rejected safely");

      release dut.core_a.data_req;
      release dut.core_a.data_we;
      release dut.core_a.data_be;
      release dut.core_a.data_addr;
      release dut.core_a.data_wdata;
      release dut.core_b.data_req;
      release dut.core_b.data_we;
      release dut.core_b.data_be;
      release dut.core_b.data_addr;
      release dut.core_b.data_wdata;

      // First word beyond RAM would alias word zero without the guard.
      @(negedge clk_i);
      #1;
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b1;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h0010_4000;
      force dut.core_a.data_wdata = 32'hDEAD_BEEF;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b1;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h0010_4000;
      force dut.core_b.data_wdata = 32'hDEAD_BEEF;
      #1;

      if (dut.core_a.data_addr_fault_o !== 1'b1 ||
          dut.core_b.data_addr_fault_o !== 1'b1 ||
          dut.core_a.data_gnt !== 1'b1 ||
          dut.core_b.data_gnt !== 1'b1 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0 ||
          dut.core_a.u_ram.a_we_i !== 1'b0 ||
          dut.core_b.u_ram.a_we_i !== 1'b0)
        $fatal(1, "Out-of-range RAM write was not rejected safely");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          data_fault_seen_o !== 1'b1 ||
          fault_code_o !== 8'h02 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Out-of-range access did not latch data fault 0x02");

      if (dut.core_a.data_rvalid !== 1'b1 ||
          dut.core_a.data_err !== 1'b1 ||
          dut.core_b.data_rvalid !== 1'b1 ||
          dut.core_b.data_err !== 1'b1)
        $fatal(1, "Out-of-range access lacked registered bus-error response");

      release dut.core_a.data_req;
      release dut.core_a.data_we;
      release dut.core_a.data_be;
      release dut.core_a.data_addr;
      release dut.core_a.data_wdata;
      release dut.core_b.data_req;
      release dut.core_b.data_we;
      release dut.core_b.data_be;
      release dut.core_b.data_addr;
      release dut.core_b.data_wdata;

      $display("STAGE 4G RAM ADDRESS-GUARD PASS");
      $display("Boundary decode, blocked write, bus error and safe state confirmed");
      $finish;

    end else if ($test$plusargs("dcls_store_inhibit_test")) begin
      $display("Starting Stage 4G DCLS store-inhibit test");
      wait (dcls_enable_o === 1'b1 &&
            core_a_success_seen && core_b_success_seen);
      @(negedge clk_i);
      #1;

      // Same valid store address, but different write payloads.
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b1;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h0010_1000;
      force dut.core_a.data_wdata = 32'hDEAD_BEEF;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b1;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h0010_1000;
      force dut.core_b.data_wdata = 32'hBAD0_C0DE;
      #1;

      if (dcls_data_mismatch_o !== 1'b1 ||
          dcls_mismatch_o !== 1'b1 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0 ||
          dut.core_a.u_ram.a_we_i !== 1'b0 ||
          dut.core_b.u_ram.a_we_i !== 1'b0)
        $fatal(1, "DCLS mismatch failed to inhibit both RAM write paths");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          data_fault_seen_o !== 1'b1 ||
          fault_code_o !== 8'h02 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "DCLS store mismatch did not latch data fault 0x02");

      release dut.core_a.data_req;
      release dut.core_a.data_we;
      release dut.core_a.data_be;
      release dut.core_a.data_addr;
      release dut.core_a.data_wdata;
      release dut.core_b.data_req;
      release dut.core_b.data_we;
      release dut.core_b.data_be;
      release dut.core_b.data_addr;
      release dut.core_b.data_wdata;

      #1;
      if (dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "Safety fault did not assert both core resets");

      // External reset clears the sticky fault while keeping both cores reset.
      @(negedge clk_i);
      rst_ni = 1'b0;
      #1;

      if (fault_latched_o !== 1'b0 ||
          safe_state_req_o !== 1'b0 ||
          dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "External reset failed to clear fault while holding cores reset");

      repeat (2) @(posedge clk_i);
      #1;

      rst_ni = 1'b1;
      #1;
      if (dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "Core reset released immediately after fault reset");

      @(posedge clk_i);
      #1;
      if (dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "Core reset released before the second recovery edge");

      @(posedge clk_i);
      #1;
      if (dut.core_a.core_rst_ni !== 1'b1 ||
          dut.core_b.core_rst_ni !== 1'b1)
        $fatal(1, "Both cores did not recover after external reset");

      $display("PASS: Latched fault reset and synchronized core recovery");
      $display("STAGE 4G DCLS STORE-INHIBIT PASS");
      $display("Both RAM requests were inhibited before the clock edge");
      $display("Sticky data fault and safe state confirmed");
      $finish;

    end else if ($test$plusargs("instruction_guard_test")) begin
      $display("Starting Stage 4G instruction address-guard test");
      wait (dcls_enable_o === 1'b1 &&
            core_a_success_seen && core_b_success_seen &&
            heartbeat_update_count >= 2);
      wait (!dut.core_a.data_req && !dut.core_b.data_req);

      @(negedge clk_i);
      #1;
      force dut.core_a.instr_req  = 1'b1;
      force dut.core_a.instr_addr = 32'h0010_4000;
      force dut.core_b.instr_req  = 1'b1;
      force dut.core_b.instr_addr = 32'h0010_4000;
      #1;

      if (dut.core_a.instr_addr_fault_o !== 1'b1 ||
          dut.core_b.instr_addr_fault_o !== 1'b1 ||
          dut.core_a.instr_gnt !== 1'b1 ||
          dut.core_b.instr_gnt !== 1'b1 ||
          dut.core_a.u_ram.b_req_i !== 1'b0 ||
          dut.core_b.u_ram.b_req_i !== 1'b0)
        $fatal(1, "Out-of-range instruction fetch was not blocked");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          instr_fault_seen_o !== 1'b1 ||
          data_fault_seen_o !== 1'b0 ||
          fault_code_o !== 8'h01 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Invalid instruction fetch did not latch fault 0x01");

      if (dut.core_a.instr_rvalid !== 1'b1 ||
          dut.core_a.instr_err !== 1'b1 ||
          dut.core_b.instr_rvalid !== 1'b1 ||
          dut.core_b.instr_err !== 1'b1)
        $fatal(1, "Invalid instruction fetch lacked registered bus-error response");

      release dut.core_a.instr_req;
      release dut.core_a.instr_addr;
      release dut.core_b.instr_req;
      release dut.core_b.instr_addr;

      $display("STAGE 4G INSTRUCTION ADDRESS-GUARD PASS");
      $display("Blocked fetch, bus-error response and safe state confirmed");
      $finish;

    end else if ($test$plusargs("supervisor_ram_containment_test")) begin
      $display("Starting supervisor-to-RAM containment test");

      fork
        begin
          wait (dcls_enable_o === 1'b1);
          #1;

          if (selected_profile_o !== 2'b01 ||
              profile_valid_o !== 1'b1 ||
              fault_injection_enable_o !== 1'b0)
            $fatal(1, "Firmware did not select valid Safety profile");

          // Suppress application heartbeat observation to trigger timeout.
          force dut.heartbeat_update_o = 1'b0;

          wait (supervisor_fault_o === 1'b1);
          #1;

          if (fault_latched_o !== 1'b0 ||
              safe_state_req_o !== 1'b0)
            $fatal(1, "Expected supervisor-to-fault-manager capture interval");

          // Present identical valid RAM writes from both processors.
          // CPU address 0x00102000 is inside the 16 KiB RAM region.
          @(negedge clk_i);

          // Snapshot the actual generic RAM words before the test write.
          // 0x00102000 - 0x00100000 = 0x2000 bytes = word index 2048.
          supervisor_ram_a_before =
              dut.core_a.u_ram.u_ram.mem[2048];
          supervisor_ram_b_before =
              dut.core_b.u_ram.u_ram.mem[2048];

          force dut.core_a.data_req   = 1'b1;
          force dut.core_a.data_we    = 1'b1;
          force dut.core_a.data_be    = 4'hF;
          force dut.core_a.data_addr  = 32'h0010_2000;
          force dut.core_a.data_wdata = 32'hA55A_3CC3;

          force dut.core_b.data_req   = 1'b1;
          force dut.core_b.data_we    = 1'b1;
          force dut.core_b.data_be    = 4'hF;
          force dut.core_b.data_addr  = 32'h0010_2000;
          force dut.core_b.data_wdata = 32'hA55A_3CC3;

          #1;

          // Check the decoded RAM index after the test addresses are driven.
          if (dut.core_a.u_ram.a_addr_idx !== 12'd2048 ||
              dut.core_b.u_ram.a_addr_idx !== 12'd2048)
            $fatal(
                1,
                "Unexpected RAM word index: Core A=%0d Core B=%0d",
                dut.core_a.u_ram.a_addr_idx,
                dut.core_b.u_ram.a_addr_idx);

          if (dcls_mismatch_o !== 1'b0 ||
              mmio_interlock_hold_o !== 1'b0 ||
              dut.core_a.data_addr_fault_o !== 1'b0 ||
              dut.core_b.data_addr_fault_o !== 1'b0)
            $fatal(1, "RAM test stimulus was not a valid matched transaction");

          // Verify both RAM interfaces are inhibited before the sampling edge.
          if (dut.core_a.data_gnt !== 1'b0 ||
              dut.core_b.data_gnt !== 1'b0 ||
              dut.core_a.u_ram.a_req_i !== 1'b0 ||
              dut.core_a.u_ram.a_we_i !== 1'b0 ||
              dut.core_b.u_ram.a_req_i !== 1'b0 ||
              dut.core_b.u_ram.a_we_i !== 1'b0)
            $fatal(
                1,
                "SUPERVISOR RAM CONTAINMENT FAILURE: A req/we=%b/%b B req/we=%b/%b",
                dut.core_a.u_ram.a_req_i,
                dut.core_a.u_ram.a_we_i,
                dut.core_b.u_ram.a_req_i,
                dut.core_b.u_ram.a_we_i);

          $display("[%0t] Matched RAM writes blocked on both cores",
                   $time);

          @(posedge clk_i);
          #1;

          // Confirm neither underlying RAM array accepted the write.
          if (dut.core_a.u_ram.u_ram.mem[2048] !==
                  supervisor_ram_a_before ||
              dut.core_b.u_ram.u_ram.mem[2048] !==
                  supervisor_ram_b_before)
            $fatal(1, "Supervisor fault containment changed RAM contents");

          if (fault_latched_o !== 1'b1 ||
              supervisor_fault_seen_o !== 1'b1 ||
              fault_code_o !== 8'h03 ||
              safe_state_req_o !== 1'b1)
            $fatal(1, "Supervisor fault was not correctly latched");

          release dut.core_a.data_req;
          release dut.core_a.data_we;
          release dut.core_a.data_be;
          release dut.core_a.data_addr;
          release dut.core_a.data_wdata;

          release dut.core_b.data_req;
          release dut.core_b.data_we;
          release dut.core_b.data_be;
          release dut.core_b.data_addr;
          release dut.core_b.data_wdata;

          $display("");
          $display("SUPERVISOR-TO-RAM CONTAINMENT PASS");
          $display("Core A RAM write           : BLOCKED");
          $display("Core B RAM write           : BLOCKED");
          $display("Supervisor fault code     : 0x03");
          $display("Sticky fault and safe state: CONFIRMED");
          $finish;
        end

        begin
          repeat (1200) @(posedge clk_i);
          $fatal(1, "Supervisor RAM containment test timed out");
        end
      join_any
      disable fork;

    end else if ($test$plusargs("supervisor_mmio_containment_test")) begin
      $display("Starting supervisor-to-MMIO containment test");

      fork
        begin
          wait (dcls_enable_o === 1'b1);
          #1;

          if (selected_profile_o !== 2'b01 ||
              profile_valid_o !== 1'b1 ||
              fault_injection_enable_o !== 1'b0)
            $fatal(1, "Firmware did not select valid Safety profile");

          if (dut.u_mmio_config.injection_authorize_o !== 1'b0)
            $fatal(1, "Injection authorisation was not initially zero");

          // Suppress only the supervisor's heartbeat observation.
          // Firmware and MMIO traffic continue operating.
          force dut.heartbeat_update_o = 1'b0;

          // Wait for the registered supervisor fault to become visible.
          wait (supervisor_fault_o === 1'b1);
          #1;

          if (fault_latched_o !== 1'b0 ||
              safe_state_req_o !== 1'b0)
            $fatal(1, "Expected supervisor-to-fault-manager capture interval");

          // Present an exactly matched, valid write before the next
          // rising edge, when the fault manager will capture the fault.
          @(negedge clk_i);

          force dut.core_a.data_req   = 1'b1;
          force dut.core_a.data_we    = 1'b1;
          force dut.core_a.data_be    = 4'hF;
          force dut.core_a.data_addr  = 32'h0020_0004;
          force dut.core_a.data_wdata = 32'h0000_0001;

          force dut.core_b.data_req   = 1'b1;
          force dut.core_b.data_we    = 1'b1;
          force dut.core_b.data_be    = 4'hF;
          force dut.core_b.data_addr  = 32'h0020_0004;
          force dut.core_b.data_wdata = 32'h0000_0001;

          #1;

          if (supervisor_fault_o !== 1'b1 ||
              mmio_interlock_hold_o !== 1'b0 ||
              dcls_mismatch_o !== 1'b0 ||
              dut.u_mmio_config.address_valid !== 1'b1)
            $fatal(1, "Test transaction was not a valid matched MMIO write");

          if (dut.mmio_req !== 1'b0 ||
              dut.mmio_gnt !== 1'b0 ||
              dut.u_mmio_config.safe_state_i !== 1'b1)
            $fatal(1, "Supervisor fault failed to suppress MMIO request/grant");

          $display("[%0t] Matched MMIO write presented during containment interval",
                   $time);

          @(posedge clk_i);
          #1;

          // The MMIO register must not change, even though the fault manager
          // captures the supervisor fault on this same rising edge.
          if (dut.u_mmio_config.injection_authorize_o !== 1'b0)
            $fatal(
                1,
                "SUPERVISOR MMIO CONTAINMENT FAILURE: injection_authorize=%b",
                dut.u_mmio_config.injection_authorize_o);

          if (fault_latched_o !== 1'b1 ||
              supervisor_fault_seen_o !== 1'b1 ||
              fault_code_o !== 8'h03 ||
              safe_state_req_o !== 1'b1)
            $fatal(1, "Supervisor fault was not correctly latched");

          release dut.core_a.data_req;
          release dut.core_a.data_we;
          release dut.core_a.data_be;
          release dut.core_a.data_addr;
          release dut.core_a.data_wdata;

          release dut.core_b.data_req;
          release dut.core_b.data_we;
          release dut.core_b.data_be;
          release dut.core_b.data_addr;
          release dut.core_b.data_wdata;

          $display("");
          $display("SUPERVISOR-TO-MMIO CONTAINMENT PASS");
          $display("MMIO injection authorisation : BLOCKED");
          $display("Supervisor fault code        : 0x03");
          $display("Sticky fault and safe state  : CONFIRMED");
          $finish;
        end

        begin
          repeat (1200) @(posedge clk_i);
          $fatal(1, "Supervisor MMIO containment test timed out");
        end
      join_any
      disable fork;

    end else if ($test$plusargs("supervisor_timeout_test")) begin
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

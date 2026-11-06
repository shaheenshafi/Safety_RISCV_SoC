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
  wire core_a_double_fault_seen_o;
  wire core_b_double_fault_seen_o;
  wire mmio_replica_integrity_fault_seen_o;
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
      .core_a_double_fault_seen_o (core_a_double_fault_seen_o),
      .core_b_double_fault_seen_o (core_b_double_fault_seen_o),
      .mmio_replica_integrity_fault_seen_o
          (mmio_replica_integrity_fault_seen_o),
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

  // Testbench helper: perform a matched MMIO read through both cores.
  task automatic profile_policy_mmio_read;
    input [31:0] addr;
    output [31:0] returned_data;
    begin
      @(negedge clk_i);

      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b0;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = addr;
      force dut.core_a.data_wdata = 32'b0;

      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b0;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = addr;
      force dut.core_b.data_wdata = 32'b0;

      #1;
      if (dut.mmio_req !== 1'b1 ||
          dut.mmio_gnt !== 1'b1 ||
          dut.mmio_replica_integrity_fault !== 1'b0)
        $fatal(1, "Matched MMIO read rejected: addr=%08h", addr);

      @(posedge clk_i);
      #1;
      if (dut.mmio_rvalid !== 1'b1)
        $fatal(1, "Matched MMIO read response missing: addr=%08h", addr);
      returned_data = dut.mmio_rdata;

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
        core_a_double_fault_seen_o !== 1'b0 ||
        core_b_double_fault_seen_o !== 1'b0 ||
        dut.soc_rst_ni !== 1'b0 ||
        dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Stage 4F reset defaults or initial safe state incorrect");

    $display("PASS: Stage 4F reset profile and fault-manager defaults");

    rst_ni = 1'b1;
    #1;

    if (dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Core reset released asynchronously");

    // The common SoC reset synchronizer requires two rising edges to release.
    @(posedge clk_i);
    #1;
    if (dut.soc_rst_ni !== 1'b0 ||
        dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "SoC reset released before the second rising edge");

    @(posedge clk_i);
    #1;
    if (dut.soc_rst_ni !== 1'b1 ||
        dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "SoC reset did not release after two edges or core reset released early");

    // Each processor wrapper retains its local two-stage reset synchronizer.
    @(posedge clk_i);
    #1;
    if (dut.core_a.core_rst_ni !== 1'b0 ||
        dut.core_b.core_rst_ni !== 1'b0)
      $fatal(1, "Core reset released before its second local synchronizer edge");

    @(posedge clk_i);
    #1;
    if (dut.core_a.core_rst_ni !== 1'b1 ||
        dut.core_b.core_rst_ni !== 1'b1)
      $fatal(1, "Both core resets did not release after common four-edge sequence");

    $display("PASS: common SoC reset release and matched two-stage core reset release");

    if ($test$plusargs("ibex_data_stability_test")) begin : run_ibex_data_stability
      integer wait_cycles;
      integer hold_cycles;
      reg [31:0] held_addr;
      reg [31:0] held_wdata;
      reg [3:0]  held_be;
      reg        paired_ram_store_found;

      $display("Starting real-Ibex data request stability/backpressure test");

      // Wait for a real RAM store presented by both running Ibex instances.
      // The test does not force the core request or payload signals.
      wait_cycles = 0;
      paired_ram_store_found = 1'b0;

      while ((wait_cycles < 20000) && !paired_ram_store_found) begin
        @(negedge clk_i);
        #1;
        wait_cycles = wait_cycles + 1;

        if (dcls_enable_o === 1'b1 &&
            dut.core_a.data_req === 1'b1 &&
            dut.core_b.data_req === 1'b1 &&
            dut.core_a.data_we === 1'b1 &&
            dut.core_b.data_we === 1'b1 &&
            dut.core_a.data_addr >= 32'h0010_0000 &&
            dut.core_a.data_addr <  32'h0010_4000 &&
            dut.core_b.data_addr >= 32'h0010_0000 &&
            dut.core_b.data_addr <  32'h0010_4000 &&
            dut.core_a.data_addr === dut.core_b.data_addr &&
            dut.core_a.data_wdata === dut.core_b.data_wdata &&
            dut.core_a.data_be === dut.core_b.data_be &&
            dut.paired_data_busy === 1'b1 &&
            dut.paired_data_commit_valid === 1'b1 &&
            dut.core_a.data_gnt === 1'b1 &&
            dut.core_b.data_gnt === 1'b1 &&
            dut.core_a.ram_data_req === 1'b1 &&
            dut.core_b.ram_data_req === 1'b1) begin
          paired_ram_store_found = 1'b1;
        end
      end

      if (!paired_ram_store_found)
        $fatal(1,
            "Timed out waiting for a matched real-Ibex RAM store (cycles=%0d profile=%b A_req=%b B_req=%b A_addr=%08h B_addr=%08h)",
            wait_cycles, selected_profile_o,
            dut.core_a.data_req, dut.core_b.data_req,
            dut.core_a.data_addr, dut.core_b.data_addr);

      held_addr  = dut.core_a.data_addr;
      held_wdata = dut.core_a.data_wdata;
      held_be    = dut.core_a.data_be;

      if (dut.core_a.data_we !== 1'b1 ||
          dut.core_b.data_we !== 1'b1 ||
          dut.core_a.data_addr !== held_addr ||
          dut.core_b.data_addr !== held_addr ||
          dut.core_a.data_wdata !== held_wdata ||
          dut.core_b.data_wdata !== held_wdata ||
          dut.core_a.data_be !== held_be ||
          dut.core_b.data_be !== held_be)
        $fatal(1, "The two real-Ibex store requests were not identical at capture");

      if (dut.paired_data_commit_payload_a[68] !== 1'b1 ||
          dut.paired_data_commit_payload_b[68] !== 1'b1 ||
          dut.paired_data_commit_payload_a[67:64] !== held_be ||
          dut.paired_data_commit_payload_b[67:64] !== held_be ||
          dut.paired_data_commit_payload_a[63:32] !== held_addr ||
          dut.paired_data_commit_payload_b[63:32] !== held_addr ||
          dut.paired_data_commit_payload_a[31:0] !== held_wdata ||
          dut.paired_data_commit_payload_b[31:0] !== held_wdata)
        $fatal(1, "Paired capture registers do not hold the original matched Ibex store payloads");

      $display("[%0t] Matched real-Ibex RAM store captured: addr=%08h data=%08h be=%h",
               $time, held_addr, held_wdata, held_be);

      // Apply backpressure at the capture-stage downstream-ready input.
      // This preserves the captured transaction without accepting its grants
      // or committing either local RAM port.
      force dut.paired_data_commit_ready = 1'b0;
      #1;

      if (dut.core_a.data_req !== 1'b1 ||
          dut.core_b.data_req !== 1'b1 ||
          dut.paired_data_busy !== 1'b1 ||
          dut.paired_data_commit_valid !== 1'b0 ||
          dut.core_a.data_gnt !== 1'b0 ||
          dut.core_b.data_gnt !== 1'b0 ||
          dut.core_a.ram_data_req !== 1'b0 ||
          dut.core_b.ram_data_req !== 1'b0 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0)
        $fatal(1, "Backpressure did not hold both real-Ibex RAM requests without granting them");

      // Hold the requests across multiple active clock edges. The complete
      // address, write data, byte enables, write direction and request-valid
      // indication must remain unchanged in each core throughout the stall.
      for (hold_cycles = 0; hold_cycles < 3; hold_cycles = hold_cycles + 1) begin
        @(posedge clk_i);
        #1;

        if (dut.core_a.data_req !== 1'b1 ||
            dut.core_b.data_req !== 1'b1 ||
            dut.core_a.data_we !== 1'b1 ||
            dut.core_b.data_we !== 1'b1 ||
            dut.core_a.data_addr !== held_addr ||
            dut.core_b.data_addr !== held_addr ||
            dut.core_a.data_wdata !== held_wdata ||
            dut.core_b.data_wdata !== held_wdata ||
            dut.core_a.data_be !== held_be ||
            dut.core_b.data_be !== held_be ||
            dut.paired_data_busy !== 1'b1 ||
            dut.paired_data_commit_valid !== 1'b0 ||
            dut.core_a.data_gnt !== 1'b0 ||
            dut.core_b.data_gnt !== 1'b0 ||
            dut.core_a.ram_data_req !== 1'b0 ||
            dut.core_b.ram_data_req !== 1'b0 ||
            dut.core_a.u_ram.a_req_i !== 1'b0 ||
            dut.core_b.u_ram.a_req_i !== 1'b0)
          $fatal(1,
              "Ibex data request/payload changed or RAM access escaped during stall cycle %0d: A(req=%b we=%b addr=%08h data=%08h be=%h gnt=%b ram_req=%b) B(req=%b we=%b addr=%08h data=%08h be=%h gnt=%b ram_req=%b)",
              hold_cycles + 1,
              dut.core_a.data_req, dut.core_a.data_we,
              dut.core_a.data_addr, dut.core_a.data_wdata,
              dut.core_a.data_be, dut.core_a.data_gnt,
              dut.core_a.ram_data_req,
              dut.core_b.data_req, dut.core_b.data_we,
              dut.core_b.data_addr, dut.core_b.data_wdata,
              dut.core_b.data_be, dut.core_b.data_gnt,
              dut.core_b.ram_data_req);
      end

      $display("PASS: both Ibex request payloads remained stable for %0d stalled cycles",
               hold_cycles);
      $display("PASS: no RAM request/grant occurred while backpressure was active");

      // Remove only the testbench backpressure. The already-captured request
      // must become grantable without another capture cycle.
      @(negedge clk_i);
      release dut.paired_data_commit_ready;
      #1;

      if (dut.paired_data_busy !== 1'b1 ||
          dut.paired_data_commit_valid !== 1'b1 ||
          dut.core_a.data_req !== 1'b1 ||
          dut.core_b.data_req !== 1'b1 ||
          dut.core_a.data_addr !== held_addr ||
          dut.core_b.data_addr !== held_addr ||
          dut.core_a.data_wdata !== held_wdata ||
          dut.core_b.data_wdata !== held_wdata ||
          dut.core_a.data_be !== held_be ||
          dut.core_b.data_be !== held_be ||
          dut.core_a.data_gnt !== 1'b1 ||
          dut.core_b.data_gnt !== 1'b1 ||
          dut.core_a.ram_data_req !== 1'b1 ||
          dut.core_b.ram_data_req !== 1'b1 ||
          dut.core_a.u_ram.a_req_i !== 1'b1 ||
          dut.core_b.u_ram.a_req_i !== 1'b1 ||
          dut.core_a.u_ram.a_we_i !== 1'b1 ||
          dut.core_b.u_ram.a_we_i !== 1'b1 ||
          // The wrapper translates the CPU byte address to a RAM-local
          // byte offset before driving the dual-port RAM address pins.
          dut.core_a.u_ram.a_addr_i !== (held_addr - 32'h0010_0000) ||
          dut.core_b.u_ram.a_addr_i !== (held_addr - 32'h0010_0000) ||
          dut.core_a.u_ram.a_wdata_i !== held_wdata ||
          dut.core_b.u_ram.a_wdata_i !== held_wdata) begin
        $display(
            "Resume diagnostics: commit_ready=%b A(req=%b gnt=%b ram_req=%b we=%b ram_we=%b ram_addr=%08h exp_addr=%08h wdata=%08h) B(req=%b gnt=%b ram_req=%b we=%b ram_we=%b ram_addr=%08h exp_addr=%08h wdata=%08h)",
            dut.paired_data_commit_ready,
            dut.core_a.data_req, dut.core_a.data_gnt,
            dut.core_a.ram_data_req, dut.core_a.data_we,
            dut.core_a.u_ram.a_we_i, dut.core_a.u_ram.a_addr_i,
            (held_addr - 32'h0010_0000), dut.core_a.u_ram.a_wdata_i,
            dut.core_b.data_req, dut.core_b.data_gnt,
            dut.core_b.ram_data_req, dut.core_b.data_we,
            dut.core_b.u_ram.a_we_i, dut.core_b.u_ram.a_addr_i,
            (held_addr - 32'h0010_0000), dut.core_b.u_ram.a_wdata_i);
        $fatal(1, "Matched RAM store did not resume normally at both RAM ports after backpressure release");
      end

      // The next active edge is the paired RAM write handshake. Check the
      // system remains free of DCLS/interlock/supervisor faults afterwards.
      @(posedge clk_i);
      #1;

      if (dut.paired_data_busy !== 1'b0 ||
          dut.paired_data_commit_valid !== 1'b0 ||
          fault_latched_o !== 1'b0 ||
          safe_state_req_o !== 1'b0 ||
          dcls_mismatch_o !== 1'b0 ||
          mmio_interlock_fault_o !== 1'b0)
        $fatal(1, "Normal matched store generated an unexpected safety fault");

      $display("PASS: both RAM write ports accepted the original matched store after release");
      $display("===============================================");
      $display("IBEX DATA REQUEST STABILITY TEST: PASS");
      $display("Observed RAM address     : %08h", held_addr);
      $display("Observed RAM write data  : %08h", held_wdata);
      $display("Observed byte enables    : %h", held_be);
      $display("Backpressure duration    : %0d clock cycles", hold_cycles);
      $display("Core A/B RAM write ports : matched request accepted");
      $display("===============================================");
      $finish;

    end else if ($test$plusargs("dcls_data_response_error_integration_test")) begin
      $display("Starting external DCLS data response-error integration test");

      // Both data channels report a valid response with identical payload.
      // Only the response-error observation differs between the cores.
      wait (dcls_enable_o === 1'b1);
      @(negedge clk_i);

      force dut.core_a_data_rvalid = 1'b1;
      force dut.core_b_data_rvalid = 1'b1;
      force dut.core_a_data_rdata = 32'h12345678;
      force dut.core_b_data_rdata = 32'h12345678;
      force dut.core_a_data_err = 1'b0;
      force dut.core_b_data_err = 1'b1;
      #1;

      if (dut.dcls_data_error_mismatch !== 1'b1 ||
          dcls_data_mismatch_o !== 1'b1 ||
          dcls_instr_mismatch_o !== 1'b0 ||
          dcls_mismatch_o !== 1'b1)
        $fatal(1, "Data response-error mismatch was not detected by external DCLS");

      if (dut.core_a.memory_side_effect_inhibit_i !== 1'b1 ||
          dut.core_b.memory_side_effect_inhibit_i !== 1'b1)
        $fatal(1, "Data response-error mismatch did not inhibit both side-effect paths");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          data_fault_seen_o !== 1'b1 ||
          instr_fault_seen_o !== 1'b0 ||
          fault_code_o !== 8'h02 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Data response-error mismatch did not latch fault 0x02 and request safe state");

      $display("PASS: data response-error disagreement detected");
      $display("PASS: mismatch inhibits both processor side-effect paths");
      $display("PASS: fault code 0x02 latched and safe state requested");
      $display("EXTERNAL DCLS DATA RESPONSE-ERROR INTEGRATION: PASS");
      $finish;

    end else if ($test$plusargs("dcls_response_error_integration_test")) begin
      $display("Starting external DCLS response-error integration test");

      // Wait until firmware selects Safety so the external DCLS monitor is on.
      wait (dcls_enable_o === 1'b1);
      @(negedge clk_i);

      // Both channels report a valid instruction response with identical data.
      // Only the error-status observation differs.
      force dut.core_a_instr_rvalid = 1'b1;
      force dut.core_b_instr_rvalid = 1'b1;
      force dut.core_a_instr_rdata = 32'h00000013;
      force dut.core_b_instr_rdata = 32'h00000013;
      force dut.core_a_instr_err = 1'b0;
      force dut.core_b_instr_err = 1'b1;
      #1;

      if (dut.dcls_instr_error_mismatch !== 1'b1 ||
          dcls_instr_mismatch_o !== 1'b1 ||
          dcls_data_mismatch_o !== 1'b0 ||
          dcls_mismatch_o !== 1'b1)
        $fatal(1, "Instruction response-error mismatch was not detected by external DCLS");

      if (dut.core_a.memory_side_effect_inhibit_i !== 1'b1 ||
          dut.core_b.memory_side_effect_inhibit_i !== 1'b1)
        $fatal(1, "Response-error mismatch did not inhibit both side-effect paths");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          instr_fault_seen_o !== 1'b1 ||
          fault_code_o !== 8'h01 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Instruction response-error mismatch did not latch fault 0x01 and request safe state");

      $display("PASS: instruction response-error disagreement detected");
      $display("PASS: mismatch inhibits both processor side-effect paths");
      $display("PASS: fault code 0x01 latched and safe state requested");
      $display("EXTERNAL DCLS RESPONSE-ERROR INTEGRATION: PASS");
      $finish;

    end else if ($test$plusargs("ibex_double_fault_test")) begin
      $display("Starting native Ibex double-fault integration test");

      // Keep both processors quiescent. The test forces the wrapper output
      // boundary to validate SoC capture/containment; it does not claim to
      // generate a genuine internal Ibex double-fault condition.
      force dut.core_a.core_rst_ni = 1'b0;
      force dut.core_b.core_rst_ni = 1'b0;

      // Core A: inject a one-cycle event and verify sticky capture.
      @(negedge clk_i);
      force dut.core_a.ibex_double_fault_seen_o = 1'b1;
      @(posedge clk_i);
      #1;
      release dut.core_a.ibex_double_fault_seen_o;
      #1;

      if (core_a_double_fault_seen_o !== 1'b1 ||
          core_b_double_fault_seen_o !== 1'b0 ||
          fault_latched_o !== 1'b1 ||
          fault_code_o !== 8'h04 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Core A double-fault event was not captured/contained");

      repeat (2) @(posedge clk_i);
      #1;
      if (core_a_double_fault_seen_o !== 1'b1 ||
          fault_latched_o !== 1'b1 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Core A double-fault sticky capture did not persist");

      $display("PASS: Core A event, sticky capture and safe-state containment");

      // External reset is the only operation that clears the sticky evidence.
      rst_ni = 1'b0;
      #1;
      if (dut.soc_rst_ni !== 1'b0 ||
          core_a_double_fault_seen_o !== 1'b0 ||
          core_b_double_fault_seen_o !== 1'b0 ||
          fault_latched_o !== 1'b0 ||
          fault_code_o !== 8'h00 ||
          safe_state_req_o !== 1'b0)
        $fatal(1, "External reset did not clear double-fault state");

      repeat (2) @(posedge clk_i);
      rst_ni = 1'b1;
      repeat (2) @(posedge clk_i);
      #1;
      if (dut.soc_rst_ni !== 1'b1 ||
          core_a_double_fault_seen_o !== 1'b0 ||
          core_b_double_fault_seen_o !== 1'b0 ||
          fault_latched_o !== 1'b0)
        $fatal(1, "Double-fault state did not remain clear after reset release");

      // Core B: repeat after reset to verify the second independent channel.
      @(negedge clk_i);
      force dut.core_b.ibex_double_fault_seen_o = 1'b1;
      @(posedge clk_i);
      #1;
      release dut.core_b.ibex_double_fault_seen_o;
      #1;

      if (core_a_double_fault_seen_o !== 1'b0 ||
          core_b_double_fault_seen_o !== 1'b1 ||
          fault_latched_o !== 1'b1 ||
          fault_code_o !== 8'h04 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Core B double-fault event was not captured/contained");

      $display("PASS: Core B event, sticky capture and safe-state containment");
      $display("");
      $display("===============================================");
      $display("IBEX DOUBLE-FAULT INTEGRATION: PASS");
      $display("Core A sticky event      : VERIFIED");
      $display("Core B sticky event      : VERIFIED");
      $display("Fault code               : 0x04");
      $display("Safe-state containment   : VERIFIED");
      $display("Capture test boundary    : Wrapper output (forced)");
      $display("===============================================");
      $finish;

    end else if ($test$plusargs("mmio_replica_integrity_test")) begin
      reg [31:0] read_value;
      $display("Starting replicated MMIO response-integrity test");

      force dut.core_a.core_rst_ni = 1'b0;
      force dut.core_b.core_rst_ni = 1'b0;
      #1;

      if (dut.mmio_replica_integrity_fault !== 1'b0 ||
          fault_latched_o !== 1'b0 ||
          safe_state_req_o !== 1'b0)
        $fatal(1, "MMIO replica integrity reset defaults incorrect");

      // First prove normal mirrored writes and reads remain coherent.
      profile_policy_mmio_write(32'h0020_0000, 32'h1, 4'hF);
      if (dut.mmio_profile_a !== 2'b01 ||
          dut.mmio_profile_b !== 2'b01 ||
          dut.mmio_heartbeat_a !== dut.mmio_heartbeat_b ||
          dut.mmio_replica_integrity_fault !== 1'b0)
        $fatal(1, "Replicated MMIO profile state did not remain identical");

      profile_policy_mmio_read(32'h0020_0000, read_value);
      if (read_value !== 32'h0000_0001 ||
          dut.mmio_rvalid_a !== 1'b1 ||
          dut.mmio_rvalid_b !== 1'b1 ||
          dut.mmio_rdata_a !== dut.mmio_rdata_b)
        $fatal(1, "Normal replicated MMIO read did not return matching data");
      $display("PASS: normal mirrored MMIO write and read");

      // Inject a one-sided response-data corruption after both copies have
      // produced a valid response. The cores must see neither response.
      @(negedge clk_i);
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b0;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h0020_0000;
      force dut.core_a.data_wdata = 32'b0;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b0;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h0020_0000;
      force dut.core_b.data_wdata = 32'b0;
      #1;
      if (dut.mmio_gnt !== 1'b1)
        $fatal(1, "MMIO read request was not granted before fault injection");
      @(posedge clk_i);
      #1;
      if (dut.mmio_rvalid_a !== 1'b1 || dut.mmio_rvalid_b !== 1'b1)
        $fatal(1, "Both MMIO replicas did not produce the expected response");

      force dut.u_mmio_config_replica.rdata_o = dut.mmio_rdata_a ^ 32'h0000_0001;
      #1;
      if (dut.mmio_replica_integrity_fault !== 1'b1 ||
          dut.mmio_rvalid !== 1'b0 ||
          dut.mmio_rdata !== 32'b0)
        $fatal(1, "Corrupted MMIO response was not detected and blocked");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          mmio_replica_integrity_fault_seen_o !== 1'b1 ||
          fault_code_o !== 8'h06 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "MMIO response-integrity fault 0x06 was not latched");

      release dut.u_mmio_config_replica.rdata_o;
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
      $display("PASS: response-data corruption detected and both core responses suppressed");

      // Reset and repeat with a response-valid disagreement.
      rst_ni = 1'b0;
      #1;
      if (fault_latched_o !== 1'b0 || fault_code_o !== 8'h00)
        $fatal(1, "Reset did not clear the MMIO data-response fault");
      repeat (2) @(posedge clk_i);
      rst_ni = 1'b1;
      repeat (4) @(posedge clk_i);
      #1;

      @(negedge clk_i);
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b0;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h0020_0000;
      force dut.core_a.data_wdata = 32'b0;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b0;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h0020_0000;
      force dut.core_b.data_wdata = 32'b0;
      #1;
      @(posedge clk_i);
      #1;
      if (dut.mmio_rvalid_a !== 1'b1 || dut.mmio_rvalid_b !== 1'b1)
        $fatal(1, "Both MMIO replicas did not produce valid responses");
      force dut.u_mmio_config_replica.rvalid_o = 1'b0;
      #1;
      if (dut.mmio_replica_integrity_fault !== 1'b1 ||
          dut.mmio_rvalid !== 1'b0 || dut.mmio_rdata !== 32'b0)
        $fatal(1, "MMIO response-valid disagreement was not detected and blocked");
      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 || fault_code_o !== 8'h06 ||
          mmio_replica_integrity_fault_seen_o !== 1'b1 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "MMIO response-valid fault 0x06 was not latched");
      release dut.u_mmio_config_replica.rvalid_o;
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
      $display("PASS: response-valid disagreement detected and both core responses suppressed");

      // Reset, then emulate a grant disagreement during a write. The consensus
      // accept signal must prevent either register bank from committing.
      rst_ni = 1'b0;
      #1;
      if (fault_latched_o !== 1'b0 || fault_code_o !== 8'h00)
        $fatal(1, "Reset did not clear the MMIO response-valid fault");
      repeat (2) @(posedge clk_i);
      rst_ni = 1'b1;
      repeat (4) @(posedge clk_i);
      #1;

      @(negedge clk_i);
      force dut.core_a.data_req   = 1'b1;
      force dut.core_a.data_we    = 1'b1;
      force dut.core_a.data_be    = 4'hF;
      force dut.core_a.data_addr  = 32'h0020_0000;
      force dut.core_a.data_wdata = 32'h1;
      force dut.core_b.data_req   = 1'b1;
      force dut.core_b.data_we    = 1'b1;
      force dut.core_b.data_be    = 4'hF;
      force dut.core_b.data_addr  = 32'h0020_0000;
      force dut.core_b.data_wdata = 32'h1;
      force dut.u_mmio_config_replica.gnt_o = 1'b0;
      #1;
      if (dut.mmio_replica_integrity_fault !== 1'b1 ||
          dut.mmio_accept !== 1'b0 ||
          dut.mmio_gnt !== 1'b0)
        $fatal(1, "MMIO grant disagreement was not contained before acceptance");
      @(posedge clk_i);
      #1;
      if (dut.mmio_profile_a !== 2'b00 ||
          dut.mmio_profile_b !== 2'b00 ||
          fault_latched_o !== 1'b1 ||
          fault_code_o !== 8'h06 ||
          mmio_replica_integrity_fault_seen_o !== 1'b1 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Grant disagreement allowed a partial commit or missed fault 0x06");

      release dut.u_mmio_config_replica.gnt_o;
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

      release dut.core_a.core_rst_ni;
      release dut.core_b.core_rst_ni;
      $display("PASS: grant disagreement prevented both replica state commits");
      $display("");
      $display("===============================================");
      $display("STAGE 4F MMIO REPLICA INTEGRITY: PASS");
      $display("Replicated state consistency : VERIFIED");
      $display("Response-data fault blocking : VERIFIED");
      $display("Grant-consensus commit gate  : VERIFIED");
      $display("Fault code                  : 0x06");
      $display("===============================================");
      $finish;

    end else if ($test$plusargs("profile_integrity_test")) begin
      $display("Starting Stage 4F configuration-integrity test");

      // Keep both processors quiescent while exercising the shared MMIO
      // configuration peripheral through the existing matched-write helper.
      force dut.core_a.core_rst_ni = 1'b0;
      force dut.core_b.core_rst_ni = 1'b0;
      #1;

      if (dut.profile_integrity_fault !== 1'b0 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b0 ||
          fault_latched_o !== 1'b0)
        $fatal(1, "Configuration integrity reset defaults incorrect");

      // Select Safety, then emulate a single-bit upset in the primary profile
      // copy that would otherwise change Safety (01) into Basic (00).
      profile_policy_mmio_write(32'h0020_0000, 32'h1, 4'hF);
      if (selected_profile_o !== 2'b01 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b1 ||
          dut.profile_integrity_fault !== 1'b0)
        $fatal(1, "Safety profile did not establish a valid redundant encoding");

      force dut.u_mmio_config.profile_o = 2'b00;
      #1;
      if (dut.profile_integrity_fault !== 1'b1 ||
          profile_valid_o !== 1'b0 ||
          dcls_enable_o !== 1'b1 ||
          fault_injection_enable_o !== 1'b0 ||
          safe_state_req_o !== 1'b1 ||
          dut.core_a.memory_side_effect_inhibit_i !== 1'b1 ||
          dut.core_b.memory_side_effect_inhibit_i !== 1'b1)
        $fatal(1, "Profile corruption did not fail safely and retain DCLS");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          fault_code_o !== 8'h05 ||
          dut.config_integrity_fault_seen !== 1'b1 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Profile integrity fault was not latched as code 0x05");

      release dut.u_mmio_config.profile_o;
      #1;
      if (safe_state_req_o !== 1'b1 || fault_latched_o !== 1'b1)
        $fatal(1, "Configuration fault did not remain sticky after upset removal");

      $display("PASS: single-bit profile corruption detected; DCLS forced on and safe state asserted");

      // External reset is required to clear the sticky configuration fault.
      rst_ni = 1'b0;
      #1;
      if (dut.soc_rst_ni !== 1'b0 ||
          fault_latched_o !== 1'b0 ||
          fault_code_o !== 8'h00 ||
          safe_state_req_o !== 1'b0)
        $fatal(1, "External reset did not clear configuration-integrity fault");

      repeat (2) @(posedge clk_i);
      rst_ni = 1'b1;
      repeat (2) @(posedge clk_i);
      #1;
      if (selected_profile_o !== 2'b00 ||
          profile_valid_o !== 1'b1 ||
          dcls_enable_o !== 1'b0 ||
          dut.profile_integrity_fault !== 1'b0 ||
          dut.config_integrity_fault_seen !== 1'b0 ||
          safe_state_req_o !== 1'b0)
        $fatal(1, "Configuration integrity did not return to reset defaults");

      $display("PASS: external reset clears configuration-integrity evidence");

      // Verify authorization is cleared automatically when leaving Diagnostic.
      profile_policy_mmio_write(32'h0020_0000, 32'h2, 4'hF);
      profile_policy_mmio_write(32'h0020_0004, 32'h1, 4'h1);
      if (fault_injection_enable_o !== 1'b1)
        $fatal(1, "Diagnostic injection authorization setup failed");

      profile_policy_mmio_write(32'h0020_0000, 32'h1, 4'hF);
      if (dut.u_mmio_config.injection_authorize_o !== 1'b0 ||
          dut.u_mmio_config.injection_authorize_complement_q !== 1'b1 ||
          fault_injection_enable_o !== 1'b0 ||
          dut.profile_integrity_fault !== 1'b0)
        $fatal(1, "Diagnostic authorization was not cleared on profile exit");

      $display("PASS: injection authorization automatically revoked on Diagnostic exit");

      // A single-bit upset that tries to enable injection while Diagnostic is
      // active must be detected; injection remains disabled and the SoC fails safe.
      profile_policy_mmio_write(32'h0020_0000, 32'h2, 4'hF);
      if (dut.u_mmio_config.injection_authorize_o !== 1'b0 ||
          fault_injection_enable_o !== 1'b0)
        $fatal(1, "Diagnostic entry did not start with injection disabled");

      force dut.u_mmio_config.injection_authorize_o = 1'b1;
      #1;
      if (dut.profile_integrity_fault !== 1'b1 ||
          fault_injection_enable_o !== 1'b0 ||
          dcls_enable_o !== 1'b1 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Injection-authorization corruption was not blocked immediately");

      @(posedge clk_i);
      #1;
      if (fault_latched_o !== 1'b1 ||
          fault_code_o !== 8'h05 ||
          dut.config_integrity_fault_seen !== 1'b1 ||
          safe_state_req_o !== 1'b1)
        $fatal(1, "Injection-authorization integrity fault was not latched");

      release dut.u_mmio_config.injection_authorize_o;
      release dut.core_a.core_rst_ni;
      release dut.core_b.core_rst_ni;

      $display("PASS: injection-authorization corruption detected and injection inhibited");
      $display("");
      $display("================================================");
      $display("STAGE 4F CONFIGURATION-INTEGRITY TEST: PASS");
      $display("Complementary profile storage : VERIFIED");
      $display("Complementary auth storage    : VERIFIED");
      $display("Fail-safe DCLS policy         : VERIFIED");
      $display("Configuration fault code     : 0x05");
      $display("Automatic auth revocation     : VERIFIED");
      $display("================================================");
      $finish;

    end else if ($test$plusargs("profile_policy_test")) begin
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
          dut.core_a.data_addr_in_ram !== 1'b1 ||
          dut.core_b.data_addr_in_ram !== 1'b1 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0)
        $fatal(1, "Last valid RAM word was incorrectly decoded or committed before paired capture");

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

      if (dut.core_a.data_addr_in_ram !== 1'b0 ||
          dut.core_b.data_addr_in_ram !== 1'b0 ||
          dut.core_a.data_gnt !== 1'b0 ||
          dut.core_b.data_gnt !== 1'b0 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0 ||
          dut.core_a.u_ram.a_we_i !== 1'b0 ||
          dut.core_b.u_ram.a_we_i !== 1'b0)
        $fatal(1, "Below-base RAM address decode or pre-capture isolation failed");

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

      if (dut.core_a.data_addr_in_ram !== 1'b0 ||
          dut.core_b.data_addr_in_ram !== 1'b0 ||
          dut.core_a.data_addr_fault_o !== 1'b0 ||
          dut.core_b.data_addr_fault_o !== 1'b0 ||
          dut.core_a.data_gnt !== 1'b0 ||
          dut.core_b.data_gnt !== 1'b0 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0 ||
          dut.core_a.u_ram.a_we_i !== 1'b0 ||
          dut.core_b.u_ram.a_we_i !== 1'b0)
        $fatal(1, "Out-of-range RAM address was not isolated before paired capture");

      // First edge captures the invalid request. The paired stage then
      // grants the matching request; address-error capture occurs on the
      // following edge, with no access forwarded to either RAM.
      @(posedge clk_i);
      #1;
      if (dut.core_a.data_gnt !== 1'b1 ||
          dut.core_b.data_gnt !== 1'b1 ||
          dut.core_a.data_addr_fault_o !== 1'b1 ||
          dut.core_b.data_addr_fault_o !== 1'b1 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0)
        $fatal(1, "Out-of-range paired request was not granted as an error response");

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
      // The pair is captured at this edge. The registered comparison then
      // rejects the mismatched write data before either RAM sees a commit.
      @(posedge clk_i);
      #1;

      if (dcls_data_mismatch_o !== 1'b1 ||
          dcls_mismatch_o !== 1'b1 ||
          dut.paired_data_commit_valid !== 1'b0 ||
          dut.core_a.data_gnt !== 1'b0 ||
          dut.core_b.data_gnt !== 1'b0 ||
          dut.core_a.u_ram.a_req_i !== 1'b0 ||
          dut.core_b.u_ram.a_req_i !== 1'b0 ||
          dut.core_a.u_ram.a_we_i !== 1'b0 ||
          dut.core_b.u_ram.a_we_i !== 1'b0)
        $fatal(1, "Registered DCLS mismatch failed to inhibit both RAM write paths");

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
      if (dut.soc_rst_ni !== 1'b0 ||
          dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "SoC/core reset released immediately after external reset");

      @(posedge clk_i);
      #1;
      if (dut.soc_rst_ni !== 1'b0 ||
          dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "SoC reset released before its second recovery edge");

      @(posedge clk_i);
      #1;
      if (dut.soc_rst_ni !== 1'b1 ||
          dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "SoC reset did not release after two edges or cores released early");

      @(posedge clk_i);
      #1;
      if (dut.core_a.core_rst_ni !== 1'b0 ||
          dut.core_b.core_rst_ni !== 1'b0)
        $fatal(1, "Core reset released before its second local recovery edge");

      @(posedge clk_i);
      #1;
      if (dut.core_a.core_rst_ni !== 1'b1 ||
          dut.core_b.core_rst_ni !== 1'b1)
        $fatal(1, "Both cores did not recover after common external reset");

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
          if (dut.core_a.data_addr !== 32'h0010_2000 ||
              dut.core_b.data_addr !== 32'h0010_2000 ||
              dut.core_a.data_addr_in_ram !== 1'b1 ||
              dut.core_b.data_addr_in_ram !== 1'b1)
            $fatal(1, "Supervisor RAM containment stimulus did not decode as a valid RAM address");

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

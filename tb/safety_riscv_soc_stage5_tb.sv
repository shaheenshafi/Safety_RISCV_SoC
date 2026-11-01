`timescale 1ns/1ps

module safety_riscv_soc_stage5_tb;

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

  wire dcls_instr_mismatch_o;
  wire dcls_data_mismatch_o;
  wire dcls_mismatch_o;

  wire instr_fault_seen_o;
  wire data_fault_seen_o;
  wire supervisor_fault_seen_o;

  wire watchdog_early_fault_o;
  wire watchdog_timeout_fault_o;
  wire progress_timeout_fault_o;

  wire [31:0] heartbeat_value_o;
  wire heartbeat_update_o;

  wire fault_latched_o;
  wire [7:0] fault_code_o;
  wire safe_state_req_o;
  wire supervisor_fault_o;
  wire mmio_interlock_fault_o;

  localparam [31:0] RESULT_RAM_OFFSET = 32'h00003FC0;
  localparam [31:0] EXPECTED_RESULT   = 32'h0000000C;

  reg core_a_result_seen = 1'b0;
  reg core_b_result_seen = 1'b0;

  integer cycle_count = 0;

  // Ibex illegal-decode and exception-handling observations.
  integer core_a_illegal_decode_count = 0;
  integer core_b_illegal_decode_count = 0;
  integer core_a_illegal_exception_count = 0;
  integer core_b_illegal_exception_count = 0;

  safety_riscv_soc_stage4f #(
      .MemInitFile("data/stage5_smoke_bss_boot80.vmem")
  ) dut (
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

  // Observe the actual writes entering each independent RAM.
  always @(posedge clk_i) begin
    if (rst_ni) begin
      cycle_count = cycle_count + 1;

      // Capture the exact CPU address responsible for a guard fault.
      if (dut.core_a.data_addr_fault_o) begin
        $display(
            "[%0t] CORE A DATA ADDRESS FAULT: addr=%08h req=%b we=%b gnt=%b in_ram=%b mmio=%b ram_addr=%08h PC=%08h",
            $time,
            dut.core_a.data_addr,
            dut.core_a.data_req,
            dut.core_a.data_we,
            dut.core_a.data_gnt,
            dut.core_a.data_addr_in_ram,
            dut.core_a.data_is_mmio,
            dut.core_a.ram_data_addr,
            dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.pc_id_i
        );
      end

      if (dut.core_b.data_addr_fault_o) begin
        $display(
            "[%0t] CORE B DATA ADDRESS FAULT: addr=%08h req=%b we=%b gnt=%b in_ram=%b mmio=%b ram_addr=%08h PC=%08h",
            $time,
            dut.core_b.data_addr,
            dut.core_b.data_req,
            dut.core_b.data_we,
            dut.core_b.data_gnt,
            dut.core_b.data_addr_in_ram,
            dut.core_b.data_is_mmio,
            dut.core_b.ram_data_addr,
            dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.pc_id_i
        );
      end

      if (dut.core_a.u_ram.a_req_i &&
          dut.core_a.u_ram.a_we_i &&
          dut.core_a.u_ram.a_addr_i == RESULT_RAM_OFFSET) begin

        if (dut.core_a.u_ram.a_wdata_i !== EXPECTED_RESULT)
          $fatal(1,
              "Core A incorrect result: %08h",
              dut.core_a.u_ram.a_wdata_i);

        core_a_result_seen = 1'b1;
        $display("[%0t] PASS: Core A wrote result %08h",
                 $time, dut.core_a.u_ram.a_wdata_i);
      end

      if (dut.core_b.u_ram.a_req_i &&
          dut.core_b.u_ram.a_we_i &&
          dut.core_b.u_ram.a_addr_i == RESULT_RAM_OFFSET) begin

        if (dut.core_b.u_ram.a_wdata_i !== EXPECTED_RESULT)
          $fatal(1,
              "Core B incorrect result: %08h",
              dut.core_b.u_ram.a_wdata_i);

        core_b_result_seen = 1'b1;
        $display("[%0t] PASS: Core B wrote result %08h",
                 $time, dut.core_b.u_ram.a_wdata_i);
      end

      if (fault_latched_o ||
          safe_state_req_o ||
          supervisor_fault_o ||
          mmio_interlock_fault_o ||
          dcls_mismatch_o)
        $fatal(1,
            "Unexpected safety event: fault=%b code=%02h safe=%b supervisor=%b interlock=%b dcls=%b",
            fault_latched_o, fault_code_o, safe_state_req_o,
            supervisor_fault_o, mmio_interlock_fault_o,
            dcls_mismatch_o);
    end
  end

  // Observe Ibex controller events at the falling edge.
  // This avoids sampling combinational controller outputs at a rising edge.
  always @(negedge clk_i) begin
    if (rst_ni) begin

      // Core A: illegal instruction decode candidate.
      if (dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.illegal_insn_d) begin
        core_a_illegal_decode_count =
            core_a_illegal_decode_count + 1;

        $display(
            "[%0t] Core A illegal decode: PC=%08h",
            $time,
            dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.pc_id_i
        );
      end

      // Core B: illegal instruction decode candidate.
      if (dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.illegal_insn_d) begin
        core_b_illegal_decode_count =
            core_b_illegal_decode_count + 1;

        $display(
            "[%0t] Core B illegal decode: PC=%08h",
            $time,
            dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.pc_id_i
        );
      end

      // Core A: registered illegal request reaches exception handling.
      if (dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.csr_save_cause_o &&
          dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.exc_req_q &&
          dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.illegal_insn_q) begin

        core_a_illegal_exception_count =
            core_a_illegal_exception_count + 1;

        $display(
            "[%0t] Core A ILLEGAL EXCEPTION HANDLING: PC=%08h cause=%h",
            $time,
            dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.pc_id_i,
            dut.core_a.u_ibex.u_ibex_core.id_stage_i.controller_i.exc_cause_o
        );
      end

      // Core B: registered illegal request reaches exception handling.
      if (dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.csr_save_cause_o &&
          dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.exc_req_q &&
          dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.illegal_insn_q) begin

        core_b_illegal_exception_count =
            core_b_illegal_exception_count + 1;

        $display(
            "[%0t] Core B ILLEGAL EXCEPTION HANDLING: PC=%08h cause=%h",
            $time,
            dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.pc_id_i,
            dut.core_b.u_ibex.u_ibex_core.id_stage_i.controller_i.exc_cause_o
        );
      end
    end
  end

  initial begin
    $display("Starting Stage 5 C firmware smoke test");

    // Allow external reset to initialize the SoC.
    repeat (4) @(posedge clk_i);
    #1;

    if (selected_profile_o !== 2'b00 ||
        profile_valid_o !== 1'b1 ||
        fault_latched_o !== 1'b0 ||
        safe_state_req_o !== 1'b0)
      $fatal(1, "Unexpected SoC reset or safety status");

    $display("PASS: SoC reset and Basic profile defaults");

    // Release external reset. The SoC synchronizes core reset release.
    rst_ni = 1'b1;

    // Wait for both independent firmware executions.
    // Bounded polling loop: compatible with Verilator.
    // Allow the monitor process to update result flags after each clock.
    while (!(core_a_result_seen && core_b_result_seen) &&
           cycle_count < 200) begin
      @(posedge clk_i);
      #1;
    end

    if (!core_a_result_seen || !core_b_result_seen)
      $fatal(1,
          "Timeout: Core A result=%b Core B result=%b cycles=%0d",
          core_a_result_seen, core_b_result_seen, cycle_count);

    #1;

    if (!core_a_result_seen || !core_b_result_seen)
      $fatal(1, "Both core results were not observed");

    if (fault_latched_o !== 1'b0 ||
        safe_state_req_o !== 1'b0 ||
        supervisor_fault_o !== 1'b0 ||
        mmio_interlock_fault_o !== 1'b0 ||
        dcls_mismatch_o !== 1'b0)
      $fatal(1, "Safety fault detected after firmware execution");

    if (core_a_illegal_decode_count != 0 ||
        core_b_illegal_decode_count != 0 ||
        core_a_illegal_exception_count != 0 ||
        core_b_illegal_exception_count != 0)
      $fatal(1, "Unexpected Ibex illegal-instruction event detected");

    $display("");
    $display("==========================================");
    $display("STAGE 5 C FIRMWARE SMOKE TEST: PASS");
    $display("==========================================");
    $display("Core A result       : 0x0000000C");
    $display("Core B result       : 0x0000000C");
    $display("CPU result address  : 0x00103FC0");
    $display("RAM offset          : 0x00003FC0");
    $display("Selected profile    : %02b (Basic)",
             selected_profile_o);
    $display("DCLS enabled        : %b", dcls_enable_o);
    $display("Fault latched       : %b", fault_latched_o);
    $display("Safe state          : %b", safe_state_req_o);
    $display("Cycles observed     : %0d", cycle_count);

    $display("Core A illegal decodes     : %0d",
             core_a_illegal_decode_count);
    $display("Core B illegal decodes     : %0d",
             core_b_illegal_decode_count);
    $display("Core A illegal exceptions  : %0d",
             core_a_illegal_exception_count);
    $display("Core B illegal exceptions  : %0d",
             core_b_illegal_exception_count);
    $display("==========================================");

    $finish;
  end

endmodule

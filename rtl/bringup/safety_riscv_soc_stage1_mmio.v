module safety_riscv_soc_stage1_mmio #(
    parameter MemInitFile = "data/stage1_smoke.vmem"
) (
    input  wire       clk_i,
    input  wire       rst_ni,
    input  wire       safe_state_i,
    // Hold both cores when a shared-MMIO transaction is unmatched.
    input  wire       mmio_interlock_hold_i,

    // External MMIO response interface for the data bus
    input  wire        mmio_gnt_i,
    input  wire        mmio_rvalid_i,
    input  wire [31:0] mmio_rdata_i,

    // ------------------------------------------------------------------------
    // Controlled processor-response fault injection
    //
    // This path is disabled for normal Stage-1/Stage-2 operation.
    // Stage-3 may enable it for Core B to inject faults before the response
    // reaches the Ibex core.
    // ------------------------------------------------------------------------
    input  wire       core_response_fault_inject_enable_i,
    input  wire [2:0] core_response_fault_inject_target_i,
    input  wire [31:0] core_response_fault_inject_mask_i,

    // ------------------------------------------------------------------------
    // Observable processor-output signals
    //
    // These signals are exposed for redundant-channel verification and the
    // external DCLS safety mechanism.
    // ------------------------------------------------------------------------
    output wire        instr_req_o,
    output wire [31:0] instr_addr_o,
    output wire        instr_rvalid_o,
    output wire [31:0] instr_rdata_o,

    output wire        data_req_o,
    output wire        data_we_o,
    output wire [3:0]  data_be_o,
    output wire [31:0] data_addr_o,
    output wire [31:0] data_wdata_o,
    output wire        data_rvalid_o,
    output wire [31:0] data_rdata_o
);

  // Hold the processor in reset whenever safe state is active.
  wire core_rst_ni;
  assign core_rst_ni = rst_ni & ~safe_state_i;

  // --------------------------------------------------------------------------
  // Ibex instruction interface
  // --------------------------------------------------------------------------

  wire        instr_req;
  wire        instr_gnt;
  wire        instr_rvalid;
  wire [31:0] instr_addr;
  wire [31:0] instr_rdata;
  wire        instr_err;

  // --------------------------------------------------------------------------
  // Ibex data interface
  // --------------------------------------------------------------------------

  wire        data_req;
  wire        data_gnt;
  wire        data_rvalid;
  wire        data_we;
  wire [3:0]  data_be;
  wire [31:0] data_addr;
  wire [31:0] data_wdata;
  wire [31:0] data_rdata;
  wire        data_err;

  // RAM and MMIO response selection signals.
  wire        ram_data_rvalid;
  wire [31:0] ram_data_rdata;
  wire        data_is_mmio;
  wire        selected_data_rvalid;
  wire [31:0] selected_data_rdata;

  // --------------------------------------------------------------------------
  // Fault-injected response signals
  // --------------------------------------------------------------------------

  wire [31:0] instr_rdata_to_ibex;
  wire [31:0] data_rdata_to_ibex;

  // --------------------------------------------------------------------------
  // RAM address mapping
  //
  // Ibex boots at 0x0010_0000.
  // Stage-1 RAM begins at offset 0x0000_0000.
  // --------------------------------------------------------------------------

  wire [31:0] ram_instr_addr;
  wire [31:0] ram_data_addr;
  wire ram_data_we;
  assign ram_data_we = data_we & ~safe_state_i;

  assign ram_instr_addr = instr_addr - 32'h0010_0000;
  assign ram_data_addr  = data_addr  - 32'h0010_0000;

  // Reserve the entire 0x0020_xxxx region for MMIO.
  // The Stage 4E top-level interlock validates the four implemented
  // registers and blocks invalid accesses from falling through to RAM.
  assign data_is_mmio = (data_addr[31:16] == 16'h0020);

  // Select the response from the addressed target.
  // Select the target that is returning a response this cycle.
  // The top-level interlock must prevent simultaneous RAM and MMIO responses.
  assign selected_data_rvalid = ram_data_rvalid | mmio_rvalid_i;
  assign selected_data_rdata =
      mmio_rvalid_i ? mmio_rdata_i : ram_data_rdata;

  // Route the selected target response to the Ibex data interface.
  assign data_rvalid = selected_data_rvalid;
  assign data_rdata  = selected_data_rdata;

  // --------------------------------------------------------------------------
  // Core response fault injector
  //
  // RAM produces the raw response.
  // The injector optionally corrupts that response.
  // The resulting response is what Ibex actually receives.
  // --------------------------------------------------------------------------

  core_response_fault_injector u_core_response_fault_injector (
      .fault_inject_enable_i (core_response_fault_inject_enable_i),
      .fault_inject_target_i (core_response_fault_inject_target_i),
      .fault_inject_mask_i   (core_response_fault_inject_mask_i),

      .instr_rdata_i         (instr_rdata),
      .data_rdata_i          (data_rdata),

      .instr_rdata_o         (instr_rdata_to_ibex),
      .data_rdata_o          (data_rdata_to_ibex)
  );

  // --------------------------------------------------------------------------
  // Ibex CPU
  // --------------------------------------------------------------------------

  ibex_top #(
      .DmBaseAddr      (32'h0010_0000),
      .DmAddrMask      (32'h0000_0003),
      .DmHaltAddr      (32'h0010_0000),
      .DmExceptionAddr (32'h0010_0000)
  ) u_ibex (
      .clk_i                   (clk_i),
      .rst_ni                  (core_rst_ni),

      .test_en_i               (1'b0),

      // I-Cache RAM configuration
      .ram_cfg_icache_tag_i    (),
      .ram_cfg_icache_tag_o    (),
      .ram_cfg_icache_data_i   (),
      .ram_cfg_icache_data_o   (),

      // CHERIoT disabled
      .cheriot_enable_i        (4'b1010),

      // Fetch and performance counter access enabled
      .fetch_enable_i          (4'b0101),
      .mcounteren_writable_i   (4'b0101),

      // Scan reset
      .scan_rst_ni             (1'b1),

      // Single hart
      .hart_id_i               (32'b0),

      // Boot address
      .boot_addr_i             (32'h0010_0000),

      .trvk_heap_base_addr_i   (32'b0),

      // ----------------------------------------------------------------------
      // Instruction interface
      // ----------------------------------------------------------------------

      .instr_req_o             (instr_req),
      .instr_gnt_i             (instr_gnt),
      .instr_rvalid_i          (instr_rvalid),
      .instr_addr_o            (instr_addr),
      .instr_rdata_i           (instr_rdata_to_ibex),
      .instr_rdata_intg_i      (7'b0),
      .instr_err_i             (instr_err),

      // ----------------------------------------------------------------------
      // Data interface
      // ----------------------------------------------------------------------

      .data_req_o              (data_req),
      .data_gnt_i              (data_gnt),
      .data_rvalid_i           (data_rvalid),
      .data_we_o               (data_we),
      .data_be_o               (data_be),
      .data_addr_o             (data_addr),
      .data_wdata_o            (data_wdata),
      .data_wdata_intg_o       (),
      .data_tag_o              (),
      .data_rdata_i            (data_rdata_to_ibex),
      .data_rdata_intg_i       (7'b0),
      .data_tag_i              (1'b0),
      .data_err_i              (data_err),

      // ----------------------------------------------------------------------
      // TRVK disabled
      // ----------------------------------------------------------------------

      .trvk_revbm_req_o        (),
      .trvk_revbm_gnt_i        (1'b0),
      .trvk_revbm_rvalid_i     (1'b0),
      .trvk_revbm_addr_o       (),
      .trvk_revbm_rdata_i      (32'b0),
      .trvk_revbm_rdata_intg_i (7'b0),
      .trvk_revbm_err_i        (1'b0),

      // ----------------------------------------------------------------------
      // Interrupts disabled
      // ----------------------------------------------------------------------

      .irq_software_i          (1'b0),
      .irq_timer_i             (1'b0),
      .irq_external_i          (1'b0),
      .irq_fast_i              (15'b0),
      .irq_nm_i                (1'b0),

      // ----------------------------------------------------------------------
      // Instruction scrambling disabled
      // ----------------------------------------------------------------------

      .scramble_key_valid_i    (1'b0),
      .scramble_key_i          (),
      .scramble_nonce_i        (),
      .scramble_req_o          (),

      // ----------------------------------------------------------------------
      // Debug disabled
      // ----------------------------------------------------------------------

      .debug_req_i             (1'b0),

      // ----------------------------------------------------------------------
      // Diagnostic / safety outputs
      // ----------------------------------------------------------------------

      .crash_dump_o            (),
      .double_fault_seen_o     (),
      .alert_minor_o           (),
      .alert_major_internal_o  (),
      .alert_major_bus_o       (),
      .core_sleep_o            (),

      // Native Ibex lockstep interface not used
      .lockstep_cmp_en_o       (),

      // Shadow outputs not used
      .data_req_shadow_o        (),
      .data_we_shadow_o         (),
      .data_be_shadow_o         (),
      .data_addr_shadow_o        (),
      .data_wdata_shadow_o       (),
      .data_wdata_intg_shadow_o  (),
      .instr_req_shadow_o        (),
      .instr_addr_shadow_o       ()
  );

  // --------------------------------------------------------------------------
  // Dual-port RAM
  //
  // 262144 words x 4 bytes = 1 MiB
  //
  // Port A = data
  // Port B = instruction
  // --------------------------------------------------------------------------

  ram_2p #(
      .Depth       (262144),
      .BExtraDelay (0),
      .MemInitFile (MemInitFile)
  ) u_ram (
      .clk_i       (clk_i),
      .rst_ni      (rst_ni),

      // Port A: Data
      .a_req_i     (data_req && !data_is_mmio && !mmio_interlock_hold_i),
      .a_we_i      (ram_data_we && !data_is_mmio && !mmio_interlock_hold_i),
      .a_be_i      (data_be),
      .a_addr_i    (ram_data_addr),
      .a_wdata_i   (data_wdata),
      .a_rvalid_o  (ram_data_rvalid),
      .a_rdata_o   (ram_data_rdata),

      // Port B: Instruction
      .b_req_i     (instr_req),
      .b_we_i      (1'b0),
      .b_be_i      (4'b0000),
      .b_addr_i    (ram_instr_addr),
      .b_wdata_i   (32'b0),
      .b_rvalid_o  (instr_rvalid),
      .b_rdata_o   (instr_rdata)
  );

  // --------------------------------------------------------------------------
  // Simple memory handshake
  // --------------------------------------------------------------------------

  assign instr_gnt = instr_req;
  assign data_gnt =
      data_req && !mmio_interlock_hold_i &&
      (data_is_mmio ? mmio_gnt_i : 1'b1);

  assign instr_err = 1'b0;
  assign data_err  = 1'b0;

  // --------------------------------------------------------------------------
  // External observation interface
  //
  // For response data, expose exactly what Ibex receives. Therefore the
  // DCLS monitor observes the same response path that drives the processor.
  // --------------------------------------------------------------------------

  assign instr_req_o    = instr_req;
  assign instr_addr_o   = instr_addr;
  assign instr_rvalid_o = instr_rvalid;
  assign instr_rdata_o  = instr_rdata_to_ibex;

  assign data_req_o     = data_req;
  assign data_we_o      = data_we;
  assign data_be_o      = data_be;
  assign data_addr_o    = data_addr;
  assign data_wdata_o   = data_wdata;
  assign data_rvalid_o  = data_rvalid;
  assign data_rdata_o   = data_rdata_to_ibex;

endmodule

module verilog_ibex_wrapper (
    input clk_i,
    input rst_ni
);

  wire        instr_req;
  wire        instr_gnt;
  wire        instr_rvalid;
  wire [31:0] instr_addr;
  wire [31:0] instr_rdata;
  wire        instr_err;

  wire        data_req;
  wire        data_gnt;
  wire        data_rvalid;
  wire        data_we;
  wire [3:0]  data_be;
  wire [31:0] data_addr;
  wire [31:0] data_wdata;
  wire [31:0] data_rdata;
  wire        data_err;

  /*
   * Strict-Verilog wrapper around the SystemVerilog Ibex top-level.
   *
   * This is a language-boundary / integration bring-up wrapper.
   * The dissertation safety architecture will be added above this
   * interface later.
   */

  ibex_top u_ibex (
      .clk_i                   (clk_i),
      .rst_ni                  (rst_ni),

      .test_en_i               (1'b0),

      .ram_cfg_icache_tag_i    (),
      .ram_cfg_icache_tag_o    (),
      .ram_cfg_icache_data_i   (),
      .ram_cfg_icache_data_o   (),

      .cheriot_enable_i        (4'b0000),

      .fetch_enable_i          (4'b1111),
      .mcounteren_writable_i   (4'b1111),

      .scan_rst_ni             (rst_ni),

      .hart_id_i               (32'b0),
      .boot_addr_i             (32'h00100000),

      .trvk_heap_base_addr_i   (32'b0),

      .instr_req_o             (instr_req),
      .instr_gnt_i             (instr_gnt),
      .instr_rvalid_i          (instr_rvalid),
      .instr_addr_o            (instr_addr),
      .instr_rdata_i           (instr_rdata),
      .instr_rdata_intg_i      (7'b0),
      .instr_err_i             (instr_err),

      .data_req_o              (data_req),
      .data_gnt_i              (data_gnt),
      .data_rvalid_i           (data_rvalid),
      .data_we_o               (data_we),
      .data_be_o               (data_be),
      .data_addr_o             (data_addr),
      .data_wdata_o            (data_wdata),
      .data_wdata_intg_o       (),
      .data_tag_o              (),
      .data_rdata_i            (data_rdata),
      .data_rdata_intg_i       (7'b0),
      .data_tag_i              (1'b0),
      .data_err_i              (data_err),

      .trvk_revbm_req_o        (),
      .trvk_revbm_gnt_i        (1'b0),
      .trvk_revbm_rvalid_i     (1'b0),
      .trvk_revbm_addr_o       (),
      .trvk_revbm_rdata_i      (32'b0),
      .trvk_revbm_rdata_intg_i (7'b0),
      .trvk_revbm_err_i        (1'b0),

      .irq_software_i          (1'b0),
      .irq_timer_i             (1'b0),
      .irq_external_i          (1'b0),
      .irq_fast_i              (15'b0),
      .irq_nm_i                (1'b0),

      .scramble_key_valid_i    (1'b0),
      .scramble_key_i          (),
      .scramble_nonce_i        (),
      .scramble_req_o          (),

      .debug_req_i             (1'b0),
      .crash_dump_o            (),
      .double_fault_seen_o     (),

      .alert_minor_o           (),
      .alert_major_internal_o  (),
      .alert_major_bus_o       (),
      .core_sleep_o            (),
      .lockstep_cmp_en_o       (),

      .data_req_shadow_o      (),
      .data_we_shadow_o       (),
      .data_be_shadow_o        (),
      .data_addr_shadow_o      (),
      .data_wdata_shadow_o     (),
      .data_wdata_intg_shadow_o(),

      .instr_req_shadow_o      (),
      .instr_addr_shadow_o     ()
  );

endmodule

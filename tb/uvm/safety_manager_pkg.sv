`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// UVM environment for the central safety manager
// (fault manager + execution supervisor + diagnostic logger).
//
//   sequence  -> sequencer -> driver  -> interface -> design
//                                         interface -> monitor -> scoreboard
//                                                      scoreboard -> coverage
//
// One sequence item describes the design inputs for one clock cycle.
// The scoreboard contains a cycle-accurate reference model written
// independently from the Verilog; every clock cycle it compares all design
// outputs with the model. The coverage collector records which situations
// were exercised.
// -----------------------------------------------------------------------------
package safety_manager_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Supervisor windows used by the testbench instance of the design.
  parameter int MIN_KICK_CYCLES         = 4;
  parameter int MAX_KICK_CYCLES         = 16;
  parameter int PROGRESS_TIMEOUT_CYCLES = 16;
  parameter int LOG_DEPTH               = 4;

  // ===========================================================================
  // Sequence item: one clock cycle
  // ===========================================================================
  class sm_item extends uvm_sequence_item;
    `uvm_object_utils(sm_item)

    // Design inputs
    rand bit       rst_n;
    rand bit       enable;
    rand bit       kick;
    rand bit       progress;
    rand bit       instr_mismatch;
    rand bit       data_mismatch;
    rand bit       core_a_double;
    rand bit       core_b_double;
    rand bit       config_integrity;
    rand bit       mmio_replica;
    rand bit [1:0] profile;
    rand bit [1:0] rd_index;

    // Design outputs (filled in by the monitor)
    bit        fault_latched;
    bit [7:0]  fault_code;
    bit        safe_state;
    bit        instr_seen;
    bit        data_seen;
    bit        supervisor_seen;
    bit        core_a_double_seen;
    bit        core_b_double_seen;
    bit        config_seen;
    bit        mmio_replica_seen;
    bit        wd_early;
    bit        wd_timeout;
    bit        progress_timeout;
    bit        supervisor_fault;
    bit [7:0]  boot_count;
    bit [7:0]  fault_count;
    bit        rd_valid;
    bit [7:0]  rd_boot;
    bit [7:0]  rd_code;
    bit [1:0]  rd_profile;
    bit [39:0] rd_time;

    // Annotations added by the scoreboard for the coverage collector
    int        model_wd_age;
    bit        model_enable;

    // Random cycles are mostly quiet: faults and resets are rare events.
    constraint c_reset   { rst_n            dist {1 := 400, 0 := 1}; }
    constraint c_enable  { enable           dist {1 := 30,  0 := 1}; }
    constraint c_kick    { kick             dist {0 := 6,   1 := 1}; }
    constraint c_prog    { progress         dist {0 := 4,   1 := 1}; }
    constraint c_instr   { instr_mismatch   dist {0 := 150, 1 := 1}; }
    constraint c_data    { data_mismatch    dist {0 := 150, 1 := 1}; }
    constraint c_dbl_a   { core_a_double    dist {0 := 300, 1 := 1}; }
    constraint c_dbl_b   { core_b_double    dist {0 := 300, 1 := 1}; }
    constraint c_cfg     { config_integrity dist {0 := 300, 1 := 1}; }
    constraint c_mmio    { mmio_replica     dist {0 := 300, 1 := 1}; }
    constraint c_profile { profile inside {[0:2]}; }

    function new(string name = "sm_item");
      super.new(name);
    endfunction

    // A quiet cycle out of reset.
    function void set_idle();
      rst_n = 1'b1; enable = 1'b1; kick = 1'b0; progress = 1'b0;
      instr_mismatch = 1'b0; data_mismatch = 1'b0;
      core_a_double = 1'b0; core_b_double = 1'b0;
      config_integrity = 1'b0; mmio_replica = 1'b0;
    endfunction

    function int unsigned fault_input_count();
      return instr_mismatch + data_mismatch + core_a_double + core_b_double +
             config_integrity + mmio_replica;
    endfunction
  endclass

  typedef uvm_sequencer #(sm_item) sm_sequencer;

  // ===========================================================================
  // Driver: applies one item per clock cycle on the falling edge
  // ===========================================================================
  class sm_driver extends uvm_driver #(sm_item);
    `uvm_component_utils(sm_driver)

    virtual safety_manager_if vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual safety_manager_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
      sm_item item;
      forever begin
        seq_item_port.get_next_item(item);
        @(negedge vif.clk);
        vif.rst_n            = item.rst_n;
        vif.enable           = item.enable;
        vif.kick             = item.kick;
        vif.progress         = item.progress;
        vif.instr_mismatch   = item.instr_mismatch;
        vif.data_mismatch    = item.data_mismatch;
        vif.core_a_double    = item.core_a_double;
        vif.core_b_double    = item.core_b_double;
        vif.config_integrity = item.config_integrity;
        vif.mmio_replica     = item.mmio_replica;
        vif.profile          = item.profile;
        vif.rd_index         = item.rd_index;
        seq_item_port.item_done();
      end
    endtask
  endclass

  // ===========================================================================
  // Monitor: one observed item per clock cycle
  // ===========================================================================
  class sm_monitor extends uvm_monitor;
    `uvm_component_utils(sm_monitor)

    virtual safety_manager_if vif;
    uvm_analysis_port #(sm_item) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db #(virtual safety_manager_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
      sm_item t;
      forever begin
        @(vif.mon_cb);
        t = sm_item::type_id::create("t");
        t.rst_n              = vif.mon_cb.rst_n;
        t.enable             = vif.mon_cb.enable;
        t.kick               = vif.mon_cb.kick;
        t.progress           = vif.mon_cb.progress;
        t.instr_mismatch     = vif.mon_cb.instr_mismatch;
        t.data_mismatch      = vif.mon_cb.data_mismatch;
        t.core_a_double      = vif.mon_cb.core_a_double;
        t.core_b_double      = vif.mon_cb.core_b_double;
        t.config_integrity   = vif.mon_cb.config_integrity;
        t.mmio_replica       = vif.mon_cb.mmio_replica;
        t.profile            = vif.mon_cb.profile;
        t.rd_index           = vif.mon_cb.rd_index;
        t.fault_latched      = vif.mon_cb.fault_latched;
        t.fault_code         = vif.mon_cb.fault_code;
        t.safe_state         = vif.mon_cb.safe_state;
        t.instr_seen         = vif.mon_cb.instr_seen;
        t.data_seen          = vif.mon_cb.data_seen;
        t.supervisor_seen    = vif.mon_cb.supervisor_seen;
        t.core_a_double_seen = vif.mon_cb.core_a_double_seen;
        t.core_b_double_seen = vif.mon_cb.core_b_double_seen;
        t.config_seen        = vif.mon_cb.config_seen;
        t.mmio_replica_seen  = vif.mon_cb.mmio_replica_seen;
        t.wd_early           = vif.mon_cb.wd_early;
        t.wd_timeout         = vif.mon_cb.wd_timeout;
        t.progress_timeout   = vif.mon_cb.progress_timeout;
        t.supervisor_fault   = vif.mon_cb.supervisor_fault;
        t.boot_count         = vif.mon_cb.boot_count;
        t.fault_count        = vif.mon_cb.fault_count;
        t.rd_valid           = vif.mon_cb.rd_valid;
        t.rd_boot            = vif.mon_cb.rd_boot;
        t.rd_code            = vif.mon_cb.rd_code;
        t.rd_profile         = vif.mon_cb.rd_profile;
        t.rd_time            = vif.mon_cb.rd_time;
        ap.write(t);
      end
    endtask
  endclass

  // ===========================================================================
  // Scoreboard with cycle-accurate reference model
  // ===========================================================================
  class sm_scoreboard extends uvm_component;
    `uvm_component_utils(sm_scoreboard)

    uvm_analysis_imp #(sm_item, sm_scoreboard) imp;
    uvm_analysis_port #(sm_item) annotated_ap;

    // ---- Reference model state: reset by the system reset ----
    bit        m_latched;
    bit [7:0]  m_code;
    bit        m_instr_seen, m_data_seen, m_sup_seen;
    bit        m_dbl_a_seen, m_dbl_b_seen, m_cfg_seen, m_mmio_seen;
    bit        m_early, m_wd_timeout, m_prog_timeout;
    int        m_wd_age, m_prog_age;
    bit        m_started, m_booted, m_fault_seen;
    bit [39:0] m_time;

    // ---- Reference model state: retained through reset (logger) ----
    bit [7:0]  m_boot_count;
    bit [7:0]  m_fault_count;
    int        m_wr_ptr;
    int        m_valid_count;
    bit [7:0]  m_log_boot    [LOG_DEPTH];
    bit [7:0]  m_log_code    [LOG_DEPTH];
    bit [1:0]  m_log_profile [LOG_DEPTH];
    bit [39:0] m_log_time    [LOG_DEPTH];

    int unsigned n_cycles;
    int unsigned n_compares;
    int unsigned n_mismatches;
    int unsigned n_faults_latched;
    int unsigned n_resets;
    bit          prev_rst_n;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      imp = new("imp", this);
      annotated_ap = new("annotated_ap", this);
    endfunction

    function void reset_model();
      m_latched = 0; m_code = 8'h00;
      m_instr_seen = 0; m_data_seen = 0; m_sup_seen = 0;
      m_dbl_a_seen = 0; m_dbl_b_seen = 0; m_cfg_seen = 0; m_mmio_seen = 0;
      m_early = 0; m_wd_timeout = 0; m_prog_timeout = 0;
      m_wd_age = 0; m_prog_age = 0;
      m_started = 0; m_booted = 0; m_fault_seen = 0;
      m_time = 40'd0;
    endfunction

    function void check_value(string name, logic [39:0] got, logic [39:0] exp);
      n_compares++;
      if (got !== exp) begin
        n_mismatches++;
        `uvm_error("SCB", $sformatf("%s: design = %0h, reference model = %0h (cycle %0d)",
                                    name, got, exp, n_cycles))
      end
    endfunction

    function void compare_outputs(sm_item t);
      bit m_sup_fault;
      int rd_addr;

      m_sup_fault = m_early | m_wd_timeout | m_prog_timeout;
      rd_addr = (m_wr_ptr + 2 * LOG_DEPTH - 1 - t.rd_index) % LOG_DEPTH;

      check_value("fault_latched",      t.fault_latched,      m_latched);
      check_value("fault_code",         t.fault_code,         m_code);
      check_value("safe_state",         t.safe_state,         m_latched);
      check_value("instr_seen",         t.instr_seen,         m_instr_seen);
      check_value("data_seen",          t.data_seen,          m_data_seen);
      check_value("supervisor_seen",    t.supervisor_seen,    m_sup_seen);
      check_value("core_a_double_seen", t.core_a_double_seen, m_dbl_a_seen);
      check_value("core_b_double_seen", t.core_b_double_seen, m_dbl_b_seen);
      check_value("config_seen",        t.config_seen,        m_cfg_seen);
      check_value("mmio_replica_seen",  t.mmio_replica_seen,  m_mmio_seen);
      check_value("wd_early",           t.wd_early,           m_early);
      check_value("wd_timeout",         t.wd_timeout,         m_wd_timeout);
      check_value("progress_timeout",   t.progress_timeout,   m_prog_timeout);
      check_value("supervisor_fault",   t.supervisor_fault,   m_sup_fault);
      check_value("boot_count",         t.boot_count,         m_boot_count);
      check_value("fault_count",        t.fault_count,        m_fault_count);
      check_value("rd_valid",           t.rd_valid,           (t.rd_index < m_valid_count));
      check_value("rd_boot",            t.rd_boot,            m_log_boot[rd_addr]);
      check_value("rd_code",            t.rd_code,            m_log_code[rd_addr]);
      check_value("rd_profile",         t.rd_profile,         m_log_profile[rd_addr]);
      check_value("rd_time",            t.rd_time,            m_log_time[rd_addr]);
    endfunction

    // Advance the model by one clock edge using the inputs of this cycle.
    // All decisions use the state before the edge, as registers do.
    function void update(sm_item t);
      bit sup_fault, any_fault, enable_eff;
      bit boot_event, fault_event;
      bit n_early, n_wd_timeout, n_prog_timeout;
      int n_wd_age, n_prog_age;

      sup_fault  = m_early | m_wd_timeout | m_prog_timeout;
      enable_eff = t.enable & ~m_latched;

      // ---- Diagnostic logger ----
      boot_event  = m_started & ~m_booted;
      fault_event = m_started & m_latched & ~m_fault_seen;

      if (fault_event) begin
        m_log_boot[m_wr_ptr]    = m_boot_count;
        m_log_code[m_wr_ptr]    = m_code;
        m_log_profile[m_wr_ptr] = t.profile;
        m_log_time[m_wr_ptr]    = m_time;
        m_wr_ptr = (m_wr_ptr + 1) % LOG_DEPTH;
        if (m_valid_count < LOG_DEPTH) m_valid_count++;
        if (m_fault_count != 8'hFF)    m_fault_count++;
      end
      if (boot_event && (m_boot_count != 8'hFF)) m_boot_count++;

      m_booted     = m_started;
      m_started    = 1'b1;
      m_fault_seen = m_latched;
      if (m_time != {40{1'b1}}) m_time++;

      // ---- Execution supervisor ----
      n_early = m_early; n_wd_timeout = m_wd_timeout; n_prog_timeout = m_prog_timeout;
      n_wd_age = m_wd_age; n_prog_age = m_prog_age;

      if (!enable_eff) begin
        n_wd_age = 0;
        n_prog_age = 0;
      end else begin
        if (t.kick) begin
          if (m_wd_age < MIN_KICK_CYCLES - 1) begin
            n_early = 1'b1;
            n_wd_age = m_wd_age + 1;
          end else if (m_wd_age >= MAX_KICK_CYCLES) begin
            n_wd_timeout = 1'b1;
            n_wd_age = MAX_KICK_CYCLES;
          end else begin
            n_wd_age = 0;
          end
        end else if (m_wd_age >= MAX_KICK_CYCLES - 1) begin
          n_wd_timeout = 1'b1;
          n_wd_age = MAX_KICK_CYCLES;
        end else begin
          n_wd_age = m_wd_age + 1;
        end

        if (t.progress) begin
          n_prog_age = 0;
        end else if (m_prog_age >= PROGRESS_TIMEOUT_CYCLES - 1) begin
          n_prog_timeout = 1'b1;
          n_prog_age = PROGRESS_TIMEOUT_CYCLES;
        end else begin
          n_prog_age = m_prog_age + 1;
        end
      end

      // ---- Fault manager ----
      any_fault = t.instr_mismatch | t.data_mismatch | sup_fault |
                  t.core_a_double | t.core_b_double |
                  t.config_integrity | t.mmio_replica;

      if (any_fault) begin
        if (!m_latched) begin
          n_faults_latched++;
          if (t.instr_mismatch)                          m_code = 8'h01;
          else if (t.data_mismatch)                      m_code = 8'h02;
          else if (sup_fault)                            m_code = 8'h03;
          else if (t.core_a_double || t.core_b_double)   m_code = 8'h04;
          else if (t.config_integrity)                   m_code = 8'h05;
          else                                           m_code = 8'h06;
        end
        m_latched = 1'b1;
        if (t.instr_mismatch)   m_instr_seen = 1'b1;
        if (t.data_mismatch)    m_data_seen  = 1'b1;
        if (sup_fault)          m_sup_seen   = 1'b1;
        if (t.core_a_double)    m_dbl_a_seen = 1'b1;
        if (t.core_b_double)    m_dbl_b_seen = 1'b1;
        if (t.config_integrity) m_cfg_seen   = 1'b1;
        if (t.mmio_replica)     m_mmio_seen  = 1'b1;
      end

      m_early = n_early; m_wd_timeout = n_wd_timeout; m_prog_timeout = n_prog_timeout;
      m_wd_age = n_wd_age; m_prog_age = n_prog_age;
    endfunction

    function void write(sm_item t);
      n_cycles++;

      if (!t.rst_n) begin
        if (prev_rst_n) n_resets++;
        reset_model();
      end
      prev_rst_n = t.rst_n;

      compare_outputs(t);

      // Annotate for coverage with the model state before this edge.
      t.model_wd_age = m_wd_age;
      t.model_enable = t.rst_n & t.enable & ~m_latched;
      annotated_ap.write(t);

      if (t.rst_n)
        update(t);
    endfunction

    function void report_phase(uvm_phase phase);
      `uvm_info("SCB", $sformatf(
          "SCOREBOARD: cycles=%0d compares=%0d mismatches=%0d faults latched=%0d resets=%0d",
          n_cycles, n_compares, n_mismatches, n_faults_latched, n_resets), UVM_NONE)
      if (n_compares == 0)
        `uvm_error("SCB", "scoreboard performed no comparison")
    endfunction
  endclass

  // ===========================================================================
  // Functional coverage
  // ===========================================================================
  class sm_coverage extends uvm_subscriber #(sm_item);
    `uvm_component_utils(sm_coverage)

    sm_item prev;

    // Sampled values
    bit [7:0] cv_code;
    bit [1:0] cv_profile;
    int       cv_sources;
    int       cv_sup_kind;      // 0 early, 1 watchdog timeout, 2 progress timeout
    int       cv_kick_age;
    int       cv_valid_records;
    bit       cv_overflow;
    bit [1:0] cv_rd_index;
    bit       cv_rd_valid;
    int       cv_event;         // see cg_events

    // Which fault was latched first, in which profile, from how many sources.
    covergroup cg_fault;
      cp_code: coverpoint cv_code {
        bins instruction_mismatch = {8'h01};
        bins data_mismatch        = {8'h02};
        bins supervisor           = {8'h03};
        bins core_double_fault    = {8'h04};
        bins config_integrity     = {8'h05};
        bins mmio_replica         = {8'h06};
      }
      cp_profile: coverpoint cv_profile {
        bins basic      = {2'b00};
        bins safety     = {2'b01};
        bins diagnostic = {2'b10};
      }
      cp_sources: coverpoint cv_sources {
        bins single   = {1};
        bins two      = {2};
        bins three_up = {[3:7]};
      }
      x_code_profile: cross cp_code, cp_profile;
    endgroup

    // Which supervisor mechanism reacted.
    covergroup cg_supervisor;
      cp_kind: coverpoint cv_sup_kind {
        bins early_service    = {0};
        bins watchdog_timeout = {1};
        bins progress_timeout = {2};
      }
    endgroup

    // Where in the watchdog window a kick arrived.
    covergroup cg_kick;
      cp_age: coverpoint cv_kick_age {
        bins too_early      = {[0:MIN_KICK_CYCLES-2]};
        bins window_start   = {MIN_KICK_CYCLES-1};
        bins window_middle  = {[MIN_KICK_CYCLES:MAX_KICK_CYCLES-2]};
        bins window_end     = {MAX_KICK_CYCLES-1};
      }
    endgroup

    // Diagnostic log fill level and read-out.
    covergroup cg_log;
      cp_records: coverpoint cv_valid_records {
        bins empty = {0};
        bins one   = {1};
        bins two   = {2};
        bins three = {3};
        bins full  = {4};
      }
      cp_overflow: coverpoint cv_overflow {
        bins oldest_overwritten = {1};
      }
      cp_rd_index: coverpoint cv_rd_index;
      cp_rd_valid: coverpoint cv_rd_valid;
      x_read: cross cp_rd_index, cp_rd_valid;
    endgroup

    // Sequences of events that matter for a safety mechanism.
    covergroup cg_events;
      cp_event: coverpoint cv_event {
        bins reset_while_fault_latched   = {0};   // recovery by reset
        bins second_fault_while_latched  = {1};   // first code must be kept
        bins fault_with_supervision_off  = {2};
        bins fault_input_during_reset    = {3};   // must be ignored
        bins kick_with_supervision_off   = {4};   // must be ignored
        bins fault_in_first_cycle        = {5};   // right after reset release
      }
    endgroup

    function new(string name, uvm_component parent);
      super.new(name, parent);
      cg_fault      = new();
      cg_supervisor = new();
      cg_kick       = new();
      cg_log        = new();
      cg_events     = new();
    endfunction

    function void write(sm_item t);
      if (prev != null) begin
        // A fault was latched by the previous clock edge.
        if (t.rst_n && prev.rst_n && t.fault_latched && !prev.fault_latched) begin
          cv_code    = t.fault_code;
          cv_profile = prev.profile;
          cv_sources = prev.fault_input_count() + prev.supervisor_fault;
          cg_fault.sample();
          if (!prev.enable) begin cv_event = 2; cg_events.sample(); end
        end

        if (t.rst_n && prev.rst_n) begin
          if (t.wd_early && !prev.wd_early) begin
            cv_sup_kind = 0; cg_supervisor.sample();
          end
          if (t.wd_timeout && !prev.wd_timeout) begin
            cv_sup_kind = 1; cg_supervisor.sample();
          end
          if (t.progress_timeout && !prev.progress_timeout) begin
            cv_sup_kind = 2; cg_supervisor.sample();
          end
        end

        if (!t.rst_n && prev.rst_n && prev.fault_latched) begin
          cv_event = 0; cg_events.sample();
        end
        if (t.rst_n && !prev.rst_n && (t.fault_input_count() != 0)) begin
          cv_event = 5; cg_events.sample();
        end
      end

      if (t.rst_n && t.fault_latched && (t.fault_input_count() != 0)) begin
        cv_event = 1; cg_events.sample();
      end
      if (!t.rst_n && (t.fault_input_count() != 0)) begin
        cv_event = 3; cg_events.sample();
      end
      if (t.rst_n && t.kick && !t.model_enable) begin
        cv_event = 4; cg_events.sample();
      end

      if (t.model_enable && t.kick && (t.model_wd_age < MAX_KICK_CYCLES)) begin
        cv_kick_age = t.model_wd_age;
        cg_kick.sample();
      end

      cv_valid_records = (t.fault_count > LOG_DEPTH) ? LOG_DEPTH : t.fault_count;
      cv_overflow      = (t.fault_count > LOG_DEPTH);
      cv_rd_index      = t.rd_index;
      cv_rd_valid      = t.rd_valid;
      cg_log.sample();

      prev = t;
    endfunction

    function void report_phase(uvm_phase phase);
      real total;
      total = (cg_fault.get_coverage() + cg_supervisor.get_coverage() +
               cg_kick.get_coverage() + cg_log.get_coverage() +
               cg_events.get_coverage()) / 5.0;
      `uvm_info("COV", $sformatf(
          "FUNCTIONAL COVERAGE: fault=%0.1f%% supervisor=%0.1f%% kick=%0.1f%% log=%0.1f%% events=%0.1f%% average=%0.1f%%",
          cg_fault.get_coverage(), cg_supervisor.get_coverage(),
          cg_kick.get_coverage(), cg_log.get_coverage(),
          cg_events.get_coverage(), total), UVM_NONE)

      // Detail per coverage point (text report; the HTML report generator
      // of Vivado needs a simulator licence tier that is not available).
      `uvm_info("COV", $sformatf(
          "COVERAGE DETAIL fault: code=%0.1f%% profile=%0.1f%% sources=%0.1f%% code-x-profile=%0.1f%%",
          cg_fault.cp_code.get_coverage(), cg_fault.cp_profile.get_coverage(),
          cg_fault.cp_sources.get_coverage(),
          cg_fault.x_code_profile.get_coverage()), UVM_NONE)
      `uvm_info("COV", $sformatf(
          "COVERAGE DETAIL supervisor: mechanism=%0.1f%%  kick: window-position=%0.1f%%  events: sequence=%0.1f%%",
          cg_supervisor.cp_kind.get_coverage(), cg_kick.cp_age.get_coverage(),
          cg_events.cp_event.get_coverage()), UVM_NONE)
      `uvm_info("COV", $sformatf(
          "COVERAGE DETAIL log: records=%0.1f%% overflow=%0.1f%% read-index=%0.1f%% read-valid=%0.1f%% index-x-valid=%0.1f%%",
          cg_log.cp_records.get_coverage(), cg_log.cp_overflow.get_coverage(),
          cg_log.cp_rd_index.get_coverage(), cg_log.cp_rd_valid.get_coverage(),
          cg_log.x_read.get_coverage()), UVM_NONE)
    endfunction
  endclass

  // ===========================================================================
  // Agent and environment
  // ===========================================================================
  class sm_agent extends uvm_agent;
    `uvm_component_utils(sm_agent)

    sm_sequencer sequencer;
    sm_driver    driver;
    sm_monitor   monitor;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sequencer = sm_sequencer::type_id::create("sequencer", this);
      driver    = sm_driver::type_id::create("driver", this);
      monitor   = sm_monitor::type_id::create("monitor", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class sm_env extends uvm_env;
    `uvm_component_utils(sm_env)

    sm_agent      agent;
    sm_scoreboard scoreboard;
    sm_coverage   coverage;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent      = sm_agent::type_id::create("agent", this);
      scoreboard = sm_scoreboard::type_id::create("scoreboard", this);
      coverage   = sm_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      agent.monitor.ap.connect(scoreboard.imp);
      scoreboard.annotated_ap.connect(coverage.analysis_export);
    endfunction
  endclass

  // ===========================================================================
  // Sequences
  // ===========================================================================
  class sm_base_seq extends uvm_sequence #(sm_item);
    `uvm_object_utils(sm_base_seq)

    bit [1:0] profile  = 2'b01;
    bit [1:0] rd_index = 2'b00;
    int       cycle    = 0;      // cycles since reset release, for kick timing
    bit       service  = 1'b1;   // kick and report progress every 8 cycles

    function new(string name = "sm_base_seq");
      super.new(name);
    endfunction

    // Send one cycle. The six fault inputs are passed as one vector:
    // bit 0 instr, 1 data, 2 core A, 3 core B, 4 config, 5 mmio replica.
    task send(bit rst_n, bit enable, bit kick, bit progress, bit [5:0] faults);
      sm_item item;
      item = sm_item::type_id::create("item");
      start_item(item);
      item.rst_n            = rst_n;
      item.enable           = enable;
      item.kick             = kick;
      item.progress         = progress;
      item.instr_mismatch   = faults[0];
      item.data_mismatch    = faults[1];
      item.core_a_double    = faults[2];
      item.core_b_double    = faults[3];
      item.config_integrity = faults[4];
      item.mmio_replica     = faults[5];
      item.profile          = profile;
      item.rd_index         = rd_index;
      finish_item(item);
    endtask

    task do_reset(int cycles = 2);
      repeat (cycles) send(0, 1, 0, 0, 6'b0);
      cycle = 0;
    endtask

    // Healthy operation: supervision on, serviced inside the window.
    task run_healthy(int cycles, bit [5:0] faults_in_last_cycle = 6'b0);
      for (int i = 0; i < cycles; i++) begin
        bit k;
        k = service && ((cycle % 8) == 7);
        send(1, 1, k, k, (i == cycles - 1) ? faults_in_last_cycle : 6'b0);
        cycle++;
      end
    endtask

    // Read all four log records.
    task read_log();
      for (int i = 0; i < 4; i++) begin
        rd_index = i[1:0];
        run_healthy(1);
      end
      rd_index = 2'b00;
    endtask
  endclass

  // Each fault source alone, in each profile; reset recovery after each.
  class sm_single_fault_seq extends sm_base_seq;
    `uvm_object_utils(sm_single_fault_seq)
    function new(string name = "sm_single_fault_seq"); super.new(name); endfunction

    task body();
      for (int p = 0; p < 3; p++) begin
        for (int s = 0; s < 6; s++) begin
          bit [5:0] f;
          f = 6'b0;
          f[s] = 1'b1;
          profile = p[1:0];
          do_reset();
          run_healthy(10 + s, f);
          run_healthy(6);
          read_log();
        end
      end
    endtask
  endclass

  // Several sources in the same cycle (code priority), and further faults
  // after the first one (the first code must be kept).
  class sm_priority_seq extends sm_base_seq;
    `uvm_object_utils(sm_priority_seq)
    function new(string name = "sm_priority_seq"); super.new(name); endfunction

    task body();
      bit [5:0] combos [8] = '{6'b000011, 6'b000110, 6'b111111, 6'b110000,
                               6'b001100, 6'b100010, 6'b011101, 6'b101000};
      for (int i = 0; i < 8; i++) begin
        profile = (i % 3);
        do_reset();
        run_healthy(9, combos[i]);
        run_healthy(3);
        // A different fault while the first is latched.
        run_healthy(1, 6'b000001);
        run_healthy(1, 6'b100000);
        run_healthy(4);
      end
    endtask
  endclass

  // Supervisor: kicks at every position of the window, early kick,
  // watchdog timeout, progress timeout, supervision switched off.
  class sm_supervisor_seq extends sm_base_seq;
    `uvm_object_utils(sm_supervisor_seq)
    function new(string name = "sm_supervisor_seq"); super.new(name); endfunction

    task body();
      service = 1'b0;

      // Kick after 'gap' quiet cycles, three times, for every gap.
      for (int gap = 0; gap <= MAX_KICK_CYCLES; gap++) begin
        for (int p = 0; p < 3; p++) begin
          profile = p[1:0];
          do_reset();
          repeat (3) begin
            repeat (gap) send(1, 1, 0, 1, 6'b0);
            send(1, 1, 1, 1, 6'b0);
          end
          repeat (4) send(1, 1, 0, 1, 6'b0);
        end
      end

      // Watchdog serviced, but no progress reported: progress timeout.
      for (int p = 0; p < 3; p++) begin
        profile = p[1:0];
        do_reset();
        for (int i = 0; i < 40; i++)
          send(1, 1, ((i % 8) == 7), 0, 6'b0);
      end

      // Supervision off: no kick is needed and kicks are ignored.
      do_reset();
      for (int i = 0; i < 40; i++)
        send(1, 0, ((i % 3) == 0), 0, 6'b0);
      // A fault while supervision is off is still latched.
      send(1, 0, 0, 0, 6'b000010);
      repeat (4) send(1, 0, 0, 0, 6'b0);

      service = 1'b1;
    endtask
  endclass

  // Reset corner cases and the diagnostic log through many runs.
  class sm_log_reset_seq extends sm_base_seq;
    `uvm_object_utils(sm_log_reset_seq)
    function new(string name = "sm_log_reset_seq"); super.new(name); endfunction

    task body();
      // Fault inputs during reset are ignored.
      repeat (3) send(0, 1, 1, 0, 6'b000011);
      cycle = 0;
      run_healthy(5);

      // Fault in the first cycle after reset release.
      do_reset();
      run_healthy(1, 6'b000100);
      run_healthy(5);
      read_log();

      // Fault-free runs do not add records.
      repeat (3) begin
        do_reset(1);
        run_healthy(12);
      end
      read_log();

      // Seven more faults: the four-record log overflows.
      for (int i = 0; i < 7; i++) begin
        bit [5:0] f;
        f = 6'b0;
        f[i % 6] = 1'b1;
        profile = (i % 3);
        do_reset();
        run_healthy(8 + 3 * i, f);
        run_healthy(3);
        read_log();
      end
    endtask
  endclass

  // Constrained-random cycles.
  class sm_random_seq extends sm_base_seq;
    `uvm_object_utils(sm_random_seq)

    int unsigned n_free_cycles     = 6000;
    int unsigned n_serviced_cycles = 14000;

    function new(string name = "sm_random_seq"); super.new(name); endfunction

    task body();
      sm_item item;
      bit     svc;

      // Phase 1: every input random, including kicks. Exercises the
      // supervisor at random positions of its window.
      do_reset();
      repeat (n_free_cycles) begin
        item = sm_item::type_id::create("item");
        start_item(item);
        if (!item.randomize())
          `uvm_fatal("RAND", "randomization failed")
        finish_item(item);
      end

      // Phase 2: the supervisor is serviced correctly, so the system stays
      // healthy until a random fault arrives; resets are frequent, so many
      // random fault / profile / reset combinations are produced.
      do_reset();
      repeat (n_serviced_cycles) begin
        svc = ((cycle % 8) == 7);
        item = sm_item::type_id::create("item");
        start_item(item);
        item.c_reset.constraint_mode(0);
        if (!item.randomize() with {
              enable   == 1'b1;
              kick     == svc;
              progress == svc;
              rst_n dist {1 := 40, 0 := 1};
            })
          `uvm_fatal("RAND", "randomization failed")
        finish_item(item);
        if (item.rst_n) cycle++;
        else            cycle = 0;
      end
    endtask
  endclass

  // ===========================================================================
  // Test
  // ===========================================================================
  class safety_manager_full_test extends uvm_test;
    `uvm_component_utils(safety_manager_full_test)

    sm_env env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = sm_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
      sm_single_fault_seq single_seq;
      sm_priority_seq     priority_seq;
      sm_supervisor_seq   supervisor_seq;
      sm_log_reset_seq    log_seq;
      sm_random_seq       random_seq;
      sm_base_seq         final_seq;

      phase.raise_objection(this);

      single_seq     = sm_single_fault_seq::type_id::create("single_seq");
      priority_seq   = sm_priority_seq::type_id::create("priority_seq");
      supervisor_seq = sm_supervisor_seq::type_id::create("supervisor_seq");
      log_seq        = sm_log_reset_seq::type_id::create("log_seq");
      random_seq     = sm_random_seq::type_id::create("random_seq");
      final_seq      = sm_base_seq::type_id::create("final_seq");

      `uvm_info("TEST", "directed: single fault sources", UVM_NONE)
      single_seq.start(env.agent.sequencer);
      `uvm_info("TEST", "directed: simultaneous faults and code priority", UVM_NONE)
      priority_seq.start(env.agent.sequencer);
      `uvm_info("TEST", "directed: execution supervisor", UVM_NONE)
      supervisor_seq.start(env.agent.sequencer);
      `uvm_info("TEST", "directed: reset corner cases and diagnostic log", UVM_NONE)
      log_seq.start(env.agent.sequencer);
      `uvm_info("TEST", "constrained random", UVM_NONE)
      random_seq.start(env.agent.sequencer);

      // Let the last driven cycle be observed and checked.
      repeat (4) @(posedge env.agent.driver.vif.clk);

      phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
      uvm_report_server server;
      int errors;
      server = uvm_report_server::get_server();
      errors = server.get_severity_count(UVM_ERROR) +
               server.get_severity_count(UVM_FATAL);
      if (errors == 0)
        `uvm_info("TEST", "UVM SAFETY MANAGER TEST: PASS", UVM_NONE)
      else
        `uvm_info("TEST", $sformatf("UVM SAFETY MANAGER TEST: FAIL (%0d errors)", errors), UVM_NONE)
    endfunction
  endclass

  // ===========================================================================
  // Checker sensitivity (mutation) test
  //
  // The testbench top deliberately breaks one connection of the design
  // (+MUTATION=n). This test passes only if the scoreboard reports the
  // resulting wrong behaviour. It answers the question "would the
  // verification environment notice a real bug?".
  // ===========================================================================
  class sm_scb_error_catcher extends uvm_report_catcher;
    int unsigned n_caught = 0;

    function new(string name = "sm_scb_error_catcher");
      super.new(name);
    endfunction

    function action_e catch();
      if ((get_severity() == UVM_ERROR) && (get_id() == "SCB")) begin
        n_caught++;
        // Show the first three as information, hide the rest.
        if (n_caught > 3)
          return CAUGHT;
        set_severity(UVM_INFO);
      end
      return THROW;
    endfunction
  endclass

  class safety_manager_mutation_test extends uvm_test;
    `uvm_component_utils(safety_manager_mutation_test)

    sm_env               env;
    sm_scb_error_catcher catcher;
    int                  mutation = 0;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = sm_env::type_id::create("env", this);
      catcher = new("catcher");
      uvm_report_cb::add(null, catcher);
      void'($value$plusargs("MUTATION=%d", mutation));
    endfunction

    task run_phase(uvm_phase phase);
      sm_single_fault_seq single_seq;
      sm_supervisor_seq   supervisor_seq;

      phase.raise_objection(this);
      single_seq     = sm_single_fault_seq::type_id::create("single_seq");
      supervisor_seq = sm_supervisor_seq::type_id::create("supervisor_seq");
      single_seq.start(env.agent.sequencer);
      supervisor_seq.start(env.agent.sequencer);
      repeat (4) @(posedge env.agent.driver.vif.clk);
      phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
      if (mutation == 0)
        `uvm_error("MUT", "no mutation selected: use +MUTATION=1, 2 or 3")
      else if (catcher.n_caught == 0)
        `uvm_error("MUT", $sformatf("MUTATION %0d WAS NOT DETECTED by the scoreboard", mutation))
      else
        `uvm_info("MUT", $sformatf(
            "MUTATION %0d DETECTED: scoreboard reported %0d mismatches. CHECKER SENSITIVITY TEST: PASS",
            mutation, catcher.n_caught), UVM_NONE)
    endfunction
  endclass

endpackage

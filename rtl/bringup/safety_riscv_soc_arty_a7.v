// -----------------------------------------------------------------------------
// Arty A7-100T board wrapper for the Stage 5 safety-oriented RISC-V SoC
//
// Target:
//   FPGA : XC7A100T-1CSG324
//   Board: Digilent Arty A7-100T
//   Clock: 100 MHz
//
// Firmware:
//   data/stage5_battery_monitor.vmem
//
// LED mapping:
//   LED0: Application heartbeat activity (toggle)
//   LED1: DCLS enabled
//   LED2: Fault latched
//   LED3: Safe-state request
//
// Fault injection is tied inactive for the initial physical prototype.
// -----------------------------------------------------------------------------

module safety_riscv_soc_arty_a7 (
    input  wire       clk,
    input  wire       reset,
    output wire [3:0] led
);

    wire [1:0]  selected_profile;
    wire        profile_valid;
    wire        dcls_enable;
    wire        fault_injection_enable;

    wire        mmio_interlock_hold;
    wire        mmio_interlock_fault;

    wire        dcls_instr_mismatch;
    wire        dcls_data_mismatch;
    wire        dcls_mismatch;

    wire        fault_latched;
    wire        instr_fault_seen;
    wire        data_fault_seen;
    wire        supervisor_fault_seen;
    wire        mmio_replica_integrity_fault_seen;
    wire [7:0]  fault_code;

    wire        safe_state_req;
    wire        watchdog_early_fault;
    wire        watchdog_timeout_fault;
    wire        progress_timeout_fault;
    wire        supervisor_fault;

    wire [31:0] heartbeat_value;
    wire        heartbeat_update;

    reg heartbeat_led;

    // Toggle the heartbeat LED on each accepted application checkpoint.
    always @(posedge clk or negedge reset) begin
        if (!reset)
            heartbeat_led <= 1'b0;
        else if (heartbeat_update)
            heartbeat_led <= ~heartbeat_led;
    end

    assign led[0] = heartbeat_led;
    assign led[1] = dcls_enable;
    assign led[2] = fault_latched;
    assign led[3] = safe_state_req;

    safety_riscv_soc_stage4f #(
        .MemInitFile("data/stage5_battery_monitor.vmem")
    ) u_safety_riscv_soc (
        .clk_i                              (clk),
        .rst_ni                             (reset),

        .fault_inject_target_i              (2'b00),
        .fault_inject_mask_i                (32'b0),
        .core_b_response_fault_inject_target_i (3'b111),
        .core_b_response_fault_inject_mask_i   (32'b0),

        .selected_profile_o                 (selected_profile),
        .profile_valid_o                    (profile_valid),
        .dcls_enable_o                       (dcls_enable),
        .fault_injection_enable_o            (fault_injection_enable),

        .mmio_interlock_hold_o              (mmio_interlock_hold),
        .mmio_interlock_fault_o              (mmio_interlock_fault),

        .dcls_instr_mismatch_o               (dcls_instr_mismatch),
        .dcls_data_mismatch_o                (dcls_data_mismatch),
        .dcls_mismatch_o                     (dcls_mismatch),

        .fault_latched_o                    (fault_latched),
        .instr_fault_seen_o                 (instr_fault_seen),
        .data_fault_seen_o                  (data_fault_seen),
        .supervisor_fault_seen_o            (supervisor_fault_seen),
        .core_a_double_fault_seen_o         (),
        .core_b_double_fault_seen_o         (),
        .mmio_replica_integrity_fault_seen_o (mmio_replica_integrity_fault_seen),
        .fault_code_o                       (fault_code),

        .safe_state_req_o                   (safe_state_req),
        .watchdog_early_fault_o             (watchdog_early_fault),
        .watchdog_timeout_fault_o           (watchdog_timeout_fault),
        .progress_timeout_fault_o           (progress_timeout_fault),
        .supervisor_fault_o                 (supervisor_fault),

        .heartbeat_value_o                 (heartbeat_value),
        .heartbeat_update_o                 (heartbeat_update)
    );

endmodule

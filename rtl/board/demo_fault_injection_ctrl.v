// -----------------------------------------------------------------------------
// Board-level manual fault-injection control
//
// Turns one arming switch and four push buttons into the inputs of the fault
// injectors that already exist inside the SoC. It adds no injection path of
// its own: the SoC applies an injection only when its runtime profile permits
// it (Diagnostic profile with explicit authorisation).
//
// trigger_i[0]  fault 0, Tier 2: flip a bit in the instruction word delivered
//               to Core B
// trigger_i[1]  fault 1, Tier 2: flip a bit in the read data delivered to
//               Core B
// trigger_i[2]  Tier 1: flip a bit in a Core B signal as seen by the
//               comparison logic only (Core B itself is not disturbed)
//                 variant_i = 0 -> fault 2, instruction address
//                 variant_i = 1 -> fault 3, data address
// trigger_i[3]  fault 4, execution stall: both cores stop executing
//               (emulated processor hang); expected reaction is a watchdog
//               timeout
//
// arm_i must be high for a trigger to be accepted. Once accepted and
// permitted, the fault stays applied until reset, so it is certain to meet
// the next matching bus transaction.
//
// latency_o counts clock cycles from the moment the fault is applied until
// the fault manager latches a fault: a hardware measurement of the
// injection-to-detection latency.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module demo_fault_injection_ctrl #(
    parameter [31:0] FAULT_MASK = 32'h0000_1000
) (
    input  wire        clk_i,
    input  wire        rst_ni,

    // Conditioned board inputs
    input  wire        arm_i,
    input  wire        variant_i,
    input  wire [3:0]  trigger_i,

    // SoC status
    input  wire        injection_permitted_i,
    input  wire        fault_latched_i,

    // To the SoC fault-injection ports
    output wire [1:0]  tier1_target_o,
    output wire [31:0] tier1_mask_o,
    output wire [2:0]  tier2_target_o,
    output wire [31:0] tier2_mask_o,
    output wire        exec_stall_o,

    // To the status reporter and indicators
    output reg         inject_event_o,
    output reg         inject_active_o,
    output reg  [2:0]  inject_select_o,
    output reg  [15:0] latency_o
);

  // Fault identifiers reported on the UART.
  localparam [2:0] FAULT_T2_INSTR_WORD = 3'd0;
  localparam [2:0] FAULT_T2_READ_DATA  = 3'd1;
  localparam [2:0] FAULT_T1_INSTR_ADDR = 3'd2;
  localparam [2:0] FAULT_T1_DATA_ADDR  = 3'd3;
  localparam [2:0] FAULT_EXEC_STALL    = 3'd4;

  // Encodings of the existing injector modules.
  localparam [1:0] TIER1_DATA_ADDR   = 2'b01;
  localparam [1:0] TIER1_INSTR_ADDR  = 2'b10;
  localparam [2:0] TIER2_INSTR_RDATA = 3'b000;
  localparam [2:0] TIER2_DATA_RDATA  = 3'b001;
  localparam [2:0] TIER2_NONE        = 3'b111;

  // Requested fault for the button being pressed (lowest button wins).
  reg [2:0] requested_fault;

  always @(*) begin
    if (trigger_i[0])
      requested_fault = FAULT_T2_INSTR_WORD;
    else if (trigger_i[1])
      requested_fault = FAULT_T2_READ_DATA;
    else if (trigger_i[2])
      requested_fault = variant_i ? FAULT_T1_DATA_ADDR : FAULT_T1_INSTR_ADDR;
    else
      requested_fault = FAULT_EXEC_STALL;
  end

  wire tier2_active;
  wire tier1_active;

  assign tier2_active = inject_active_o &&
      ((inject_select_o == FAULT_T2_INSTR_WORD) ||
       (inject_select_o == FAULT_T2_READ_DATA));

  assign tier1_active = inject_active_o &&
      ((inject_select_o == FAULT_T1_INSTR_ADDR) ||
       (inject_select_o == FAULT_T1_DATA_ADDR));

  assign tier2_target_o =
      !tier2_active ? TIER2_NONE :
      (inject_select_o == FAULT_T2_READ_DATA) ? TIER2_DATA_RDATA
                                              : TIER2_INSTR_RDATA;
  assign tier2_mask_o = tier2_active ? FAULT_MASK : 32'b0;

  assign tier1_target_o =
      (inject_select_o == FAULT_T1_DATA_ADDR) ? TIER1_DATA_ADDR
                                              : TIER1_INSTR_ADDR;
  assign tier1_mask_o = tier1_active ? FAULT_MASK : 32'b0;

  assign exec_stall_o =
      inject_active_o && (inject_select_o == FAULT_EXEC_STALL);

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      inject_event_o  <= 1'b0;
      inject_active_o <= 1'b0;
      inject_select_o <= 3'd0;
      latency_o       <= 16'd0;
    end else begin
      inject_event_o <= 1'b0;

      // Accept one trigger per reset cycle, and none after a fault.
      if ((|trigger_i) && arm_i && !inject_active_o && !fault_latched_i) begin
        inject_event_o  <= 1'b1;
        inject_select_o <= requested_fault;
        // The request is reported either way; it is applied only when the
        // SoC profile permits fault injection.
        inject_active_o <= injection_permitted_i;
      end

      if (inject_active_o && !fault_latched_i && (latency_o != 16'hFFFF))
        latency_o <= latency_o + 16'd1;
    end
  end

endmodule

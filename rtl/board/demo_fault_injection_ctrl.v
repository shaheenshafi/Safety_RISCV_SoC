// -----------------------------------------------------------------------------
// Board-level manual fault-injection control
//
// Turns the slide switches and one push button into the target/mask inputs of
// the two fault injectors that already exist inside the SoC. It adds no new
// injection path: the SoC still applies an injection only when its runtime
// profile permits it (Diagnostic profile with explicit authorisation).
//
// select_i[1:0] chooses the fault:
//   00  Tier 2: flip a bit in the instruction word delivered to Core B
//   01  Tier 2: flip a bit in the read data delivered to Core B
//   10  Tier 1: flip a bit in Core B's instruction address as seen by the
//               comparator (Core B itself is not disturbed)
//   11  Tier 1: flip a bit in Core B's data address as seen by the comparator
// select_i[2] chooses the mask: 0 = single bit, 1 = several bits.
//
// arm_i must be high for the trigger to be accepted. Once accepted and
// permitted, the fault stays applied until reset, so it is certain to meet
// the next matching bus transaction.
//
// latency_o counts clock cycles from the moment the fault is applied until
// the fault manager latches a fault. It is a hardware measurement of
// injection-to-detection latency.
//
// RTL language: Verilog
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module demo_fault_injection_ctrl #(
    parameter [31:0] SINGLE_BIT_MASK = 32'h0000_1000,
    parameter [31:0] MULTI_BIT_MASK  = 32'h0010_1010
) (
    input  wire        clk_i,
    input  wire        rst_ni,

    // Conditioned board inputs
    input  wire        arm_i,
    input  wire [2:0]  select_i,
    input  wire        trigger_i,

    // SoC status
    input  wire        injection_permitted_i,
    input  wire        fault_latched_i,

    // To the SoC fault-injection ports
    output wire [1:0]  tier1_target_o,
    output wire [31:0] tier1_mask_o,
    output wire [2:0]  tier2_target_o,
    output wire [31:0] tier2_mask_o,

    // To the status reporter and indicators
    output reg         inject_event_o,
    output reg         inject_active_o,
    output reg  [2:0]  inject_select_o,
    output reg  [15:0] latency_o
);

  // Encodings of the existing injector modules.
  localparam [1:0] TIER1_DATA_ADDR   = 2'b01;
  localparam [1:0] TIER1_INSTR_ADDR  = 2'b10;
  localparam [2:0] TIER2_INSTR_RDATA = 3'b000;
  localparam [2:0] TIER2_DATA_RDATA  = 3'b001;
  localparam [2:0] TIER2_NONE        = 3'b111;

  wire        use_tier1;
  wire [31:0] active_mask;

  assign use_tier1   = inject_select_o[1];
  assign active_mask = inject_select_o[2] ? MULTI_BIT_MASK : SINGLE_BIT_MASK;

  assign tier1_target_o =
      inject_select_o[0] ? TIER1_DATA_ADDR : TIER1_INSTR_ADDR;
  assign tier1_mask_o =
      (inject_active_o && use_tier1) ? active_mask : 32'b0;

  assign tier2_target_o =
      (inject_active_o && !use_tier1)
          ? (inject_select_o[0] ? TIER2_DATA_RDATA : TIER2_INSTR_RDATA)
          : TIER2_NONE;
  assign tier2_mask_o =
      (inject_active_o && !use_tier1) ? active_mask : 32'b0;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      inject_event_o  <= 1'b0;
      inject_active_o <= 1'b0;
      inject_select_o <= 3'b000;
      latency_o       <= 16'd0;
    end else begin
      inject_event_o <= 1'b0;

      // Accept one trigger per reset cycle, and none after a fault.
      if (trigger_i && arm_i && !inject_active_o && !fault_latched_i) begin
        inject_event_o  <= 1'b1;
        inject_select_o <= select_i;
        // The request is reported either way; it is applied only when the
        // SoC profile permits fault injection.
        inject_active_o <= injection_permitted_i;
      end

      if (inject_active_o && !fault_latched_i && (latency_o != 16'hFFFF))
        latency_o <= latency_o + 16'd1;
    end
  end

endmodule

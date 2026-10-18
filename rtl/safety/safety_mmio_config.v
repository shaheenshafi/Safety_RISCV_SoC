
`timescale 1ns/1ps

module safety_mmio_config (
    input  wire        clk_i,
    input  wire        rst_ni,

    // Simple data-bus request/response interface
    input  wire        req_i,
    input  wire        we_i,
    input  wire [3:0]  be_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    output wire        gnt_o,
    output reg         rvalid_o,
    output reg  [31:0] rdata_o,

    // Configuration writes are blocked during safe state
    input  wire        safe_state_i,

    // Fault-manager status inputs (read-only)
    input  wire        fault_latched_i,
    input  wire        instr_fault_seen_i,
    input  wire        data_fault_seen_i,
    input  wire [7:0]  fault_code_i,

    // Configuration outputs
    output reg  [1:0]  profile_o,
    output reg         injection_authorize_o,

    // Derived policy outputs
    output wire [1:0]  selected_profile_o,
    output wire        profile_valid_o,
    output wire        dcls_enable_o,
    output wire        fault_injection_enable_o
);

  // MMIO base address: 0x0020_0000
  localparam [31:0] REG_PROFILE_CTRL = 32'h0020_0000;
  localparam [31:0] REG_INJECTION_AUTH = 32'h0020_0004;
  localparam [31:0] REG_PROFILE_STATUS = 32'h0020_0008;
  localparam [31:0] REG_FAULT_STATUS = 32'h0020_000C;

  localparam [1:0] PROFILE_BASIC = 2'b00;
  localparam [1:0] PROFILE_SAFETY = 2'b01;
  localparam [1:0] PROFILE_DIAGNOSTIC = 2'b10;
  localparam [1:0] PROFILE_RESERVED = 2'b11;

  // Accept only accesses to the four defined registers.
  wire address_valid;
  assign address_valid =
      (addr_i == REG_PROFILE_CTRL) ||
      (addr_i == REG_INJECTION_AUTH) ||
      (addr_i == REG_PROFILE_STATUS) ||
      (addr_i == REG_FAULT_STATUS);

  assign gnt_o = req_i && address_valid;

  // Profile policy matches the Stage 4D controller.
  assign selected_profile_o = profile_o;
  assign profile_valid_o = (profile_o != PROFILE_RESERVED);

  assign dcls_enable_o =
      profile_valid_o &&
      ((profile_o == PROFILE_SAFETY) ||
       (profile_o == PROFILE_DIAGNOSTIC));

  assign fault_injection_enable_o =
      profile_valid_o &&
      (profile_o == PROFILE_DIAGNOSTIC) &&
      injection_authorize_o;

  // One-cycle registered response for accepted requests.
  // Reads return register contents; writes return zero.
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      profile_o <= PROFILE_BASIC;
      injection_authorize_o <= 1'b0;
      rvalid_o <= 1'b0;
      rdata_o <= 32'b0;
    end else begin
      rvalid_o <= gnt_o;

      if (gnt_o) begin
        if (we_i) begin
          // Byte-enable bit 0 controls the low-byte configuration fields.
          if (!safe_state_i && be_i[0]) begin
            if (addr_i == REG_PROFILE_CTRL)
              profile_o <= wdata_i[1:0];

            if (addr_i == REG_INJECTION_AUTH)
              injection_authorize_o <= wdata_i[0];
          end

          rdata_o <= 32'b0;
        end else begin
          case (addr_i)
            REG_PROFILE_CTRL:
              rdata_o <= {30'b0, profile_o};

            REG_INJECTION_AUTH:
              rdata_o <= {31'b0, injection_authorize_o};

            REG_PROFILE_STATUS:
              rdata_o <= {
                27'b0,
                fault_injection_enable_o,
                dcls_enable_o,
                profile_valid_o,
                selected_profile_o
              };

            REG_FAULT_STATUS:
              rdata_o <= {
                16'b0,
                fault_code_i,
                5'b0,
                data_fault_seen_i,
                instr_fault_seen_i,
                fault_latched_i
              };

            default:
              rdata_o <= 32'b0;
          endcase
        end
      end
    end
  end

endmodule

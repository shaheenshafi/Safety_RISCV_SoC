`timescale 1ns/1ps

module safety_mmio_config_stage4f (
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

    // Configuration writes are blocked during safe state or an integrity fault.
    input  wire        safe_state_i,

    // Top-level consensus: both replicated peripherals must agree to accept
    // the transaction before either copy changes state or returns a response.
    input  wire        accept_i,

    // Fault-manager status inputs (read-only)
    input  wire        fault_latched_i,
    input  wire        instr_fault_seen_i,
    input  wire        data_fault_seen_i,
    input  wire        supervisor_fault_seen_i,
    input  wire        config_integrity_fault_seen_i,
    input  wire [7:0]  fault_code_i,

    // Configuration outputs
    output reg  [1:0]  profile_o,
    output reg         injection_authorize_o,
    output wire        config_integrity_fault_o,

    // Derived policy outputs
    output wire [1:0]  selected_profile_o,
    output wire        profile_valid_o,
    output wire        dcls_enable_o,
    output wire        fault_injection_enable_o,
    output reg  [31:0] heartbeat_value_o,
    output wire        heartbeat_update_o
);

  // MMIO base address: 0x0020_0000
  localparam [31:0] REG_PROFILE_CTRL = 32'h0020_0000;
  localparam [31:0] REG_INJECTION_AUTH = 32'h0020_0004;
  localparam [31:0] REG_PROFILE_STATUS = 32'h0020_0008;
  localparam [31:0] REG_FAULT_STATUS = 32'h0020_000C;
  localparam [31:0] REG_HEARTBEAT = 32'h0020_0010;

  localparam [1:0] PROFILE_BASIC = 2'b00;
  localparam [1:0] PROFILE_SAFETY = 2'b01;
  localparam [1:0] PROFILE_DIAGNOSTIC = 2'b10;
  localparam [1:0] PROFILE_RESERVED = 2'b11;

  // Each safety-critical configuration value is stored with its complement.
  // A single-bit upset in either copy is detected by the combinational checks.
  // This is error detection, not correction, and does not claim protection
  // against common-mode corruption of both copies.
  reg [1:0] profile_complement_q;
  reg       injection_authorize_complement_q;

  wire profile_integrity_ok;
  wire injection_authorize_integrity_ok;

  assign profile_integrity_ok = (profile_complement_q == ~profile_o);
  assign injection_authorize_integrity_ok =
      (injection_authorize_complement_q == ~injection_authorize_o);

  assign config_integrity_fault_o =
      !(profile_integrity_ok && injection_authorize_integrity_ok) ||
      (profile_o == PROFILE_RESERVED);

  // Accept only accesses to the five defined registers.
  wire address_valid;
  assign address_valid =
      (addr_i == REG_PROFILE_CTRL) ||
      (addr_i == REG_INJECTION_AUTH) ||
      (addr_i == REG_PROFILE_STATUS) ||
      (addr_i == REG_FAULT_STATUS) ||
      (addr_i == REG_HEARTBEAT);

  assign gnt_o = req_i && address_valid;

  // A new heartbeat counts as progress only for an accepted, full-word
  // write with a changed sequence value and no active safe state/config fault.
  assign heartbeat_update_o =
      gnt_o && accept_i && we_i && (be_i == 4'hF) && !safe_state_i &&
      !config_integrity_fault_o &&
      (addr_i == REG_HEARTBEAT) &&
      (wdata_i != heartbeat_value_o);

  // Integrity failure invalidates the selected profile. DCLS is forced ON
  // while the fault is present so a corrupted value cannot silently disable
  // comparison before the fault manager latches the configuration fault.
  assign selected_profile_o = profile_o;
  assign profile_valid_o =
      !config_integrity_fault_o && (profile_o != PROFILE_RESERVED);

  assign dcls_enable_o =
      config_integrity_fault_o ||
      (profile_valid_o &&
       ((profile_o == PROFILE_SAFETY) ||
        (profile_o == PROFILE_DIAGNOSTIC)));

  assign fault_injection_enable_o =
      !config_integrity_fault_o &&
      profile_valid_o &&
      (profile_o == PROFILE_DIAGNOSTIC) &&
      injection_authorize_o;

  // One-cycle registered response for accepted requests.
  // Reads return register contents; writes return zero.
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      profile_o <= PROFILE_BASIC;
      profile_complement_q <= ~PROFILE_BASIC;
      injection_authorize_o <= 1'b0;
      injection_authorize_complement_q <= 1'b1;
      heartbeat_value_o <= 32'b0;
      rvalid_o <= 1'b0;
      rdata_o <= 32'b0;
    end else begin
      rvalid_o <= gnt_o && accept_i;

      if (gnt_o && accept_i) begin
        if (we_i) begin
          // Writes are rejected during safe state or an integrity fault.
          if (!safe_state_i && !config_integrity_fault_o && be_i[0]) begin
            if ((addr_i == REG_PROFILE_CTRL) &&
                (wdata_i[1:0] != PROFILE_RESERVED)) begin
              profile_o <= wdata_i[1:0];
              profile_complement_q <= ~wdata_i[1:0];

              // Authorization is valid only within a continuous Diagnostic
              // session. Clear it on every profile transition, including
              // leaving Diagnostic, so it cannot survive mode changes.
              if (wdata_i[1:0] != profile_o) begin
                injection_authorize_o <= 1'b0;
                injection_authorize_complement_q <= 1'b1;
              end
            end

            // Fault injection may be authorized only after Diagnostic mode
            // has been selected. The authorization copy is updated together.
            if ((addr_i == REG_INJECTION_AUTH) &&
                (profile_o == PROFILE_DIAGNOSTIC)) begin
              injection_authorize_o <= wdata_i[0];
              injection_authorize_complement_q <= ~wdata_i[0];
            end

            if (addr_i == REG_HEARTBEAT && be_i == 4'hF)
              heartbeat_value_o <= wdata_i;
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
                25'b0,
                config_integrity_fault_seen_i,
                config_integrity_fault_o,
                fault_injection_enable_o,
                dcls_enable_o,
                profile_valid_o,
                selected_profile_o
              };

            REG_FAULT_STATUS:
              rdata_o <= {
                16'b0,
                fault_code_i,
                3'b0,
                config_integrity_fault_seen_i,
                supervisor_fault_seen_i,
                data_fault_seen_i,
                instr_fault_seen_i,
                fault_latched_i
              };

            REG_HEARTBEAT:
              rdata_o <= heartbeat_value_o;

            default:
              rdata_o <= 32'b0;
          endcase
        end
      end
    end
  end

endmodule

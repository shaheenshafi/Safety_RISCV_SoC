// -----------------------------------------------------------------------------
// Board status reporter (UART text)
//
// GENERATED FILE - edit scripts/gen/gen_status_reporter.py, not this file.
//
// Observes the SoC status outputs and prints one text line per event:
//   <CR><LF>[BOOT] SAFETY RISC-V SOC / ARTY A7-100T<CR><LF>
//   [STAT] PROFILE={profile:1} DCLS={dcls:1} INJ_EN={injen:1} HB={hb:8} FAULT={code:2} SAFE={safe:1}<CR><LF>
//   [INJ ] FAULT_ID={sel:1} APPLIED={active:1}<CR><LF>
//   [FLT ] CODE={code:2} LATENCY={lat:4} CYCLES SAFE_STATE={safe:1}<CR><LF>
//   [LOG ] BOOTS={boots:2} FAULTS={nflt:2}<CR><LF>
//   [LOG ] ENTRY={lidx:1} BOOT={lboot:2} CODE={lcode:2} PROFILE={lprof:1} TIME={ltime:10}<CR><LF>
// Fields are hexadecimal. The reporter only observes; it drives nothing back
// into the SoC, so it cannot affect the safety mechanisms.
//
// Events and priority: boot banner, diagnostic log, injection request, fault,
// status. After the boot banner the retained diagnostic log is printed: one
// summary line, then one line per stored record, most recent first.
// A status line is printed after boot, on request, and periodically every
// 2^STATUS_PERIOD_BITS clock cycles.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module demo_status_reporter #(
    parameter integer STATUS_PERIOD_BITS = 27
) (
    input  wire        clk_i,
    input  wire        rst_ni,

    input  wire        status_request_i,
    input  wire        inject_event_i,

    input  wire [1:0]  profile_i,
    input  wire        dcls_enable_i,
    input  wire        injection_enable_i,
    input  wire        fault_latched_i,
    input  wire [7:0]  fault_code_i,
    input  wire        safe_state_i,
    input  wire [31:0] heartbeat_i,
    input  wire [2:0]  inject_select_i,
    input  wire        inject_active_i,
    input  wire [15:0] latency_i,

    // Diagnostic log read port (record 0 = most recent)
    output wire [1:0]  log_rd_index_o,
    input  wire [7:0]  log_boot_count_i,
    input  wire [7:0]  log_fault_count_i,
    input  wire        log_rd_valid_i,
    input  wire [7:0]  log_rd_boot_i,
    input  wire [7:0]  log_rd_code_i,
    input  wire [1:0]  log_rd_profile_i,
    input  wire [39:0] log_rd_time_i,

    output wire [7:0]  tx_data_o,
    output wire        tx_valid_o,
    input  wire        tx_ready_i
);

  localparam [2:0] MSG_BOOT   = 3'd0;
  localparam [2:0] MSG_STATUS = 3'd1;
  localparam [2:0] MSG_INJECT = 3'd2;
  localparam [2:0] MSG_FAULT  = 3'd3;
  localparam [2:0] MSG_LOGHDR = 3'd4;
  localparam [2:0] MSG_LOGENT = 3'd5;

  // Hexadecimal digit to ASCII.
  function [7:0] hex_ascii;
    input [3:0] nibble;
    begin
      if (nibble < 4'd10)
        hex_ascii = 8'h30 + {4'b0000, nibble};
      else
        hex_ascii = 8'h37 + {4'b0000, nibble};
    end
  endfunction

  reg                          sending_q;
  reg [2:0]                    msg_q;
  reg [6-1:0]                    idx_q;

  reg                          pend_boot_q;
  reg                          pend_inject_q;
  reg                          pend_fault_q;
  reg                          pend_status_q;
  reg                          fault_seen_q;

  // Diagnostic log print-out after boot:
  // step 0 = summary line, steps 1..4 = records 0..3.
  reg                          pend_log_q;
  reg [2:0]                    log_step_q;
  reg [STATUS_PERIOD_BITS-1:0] period_q;

  // Values captured when a message starts, so one line is self-consistent.
  reg [1:0]  snap_profile_q;
  reg        snap_dcls_q;
  reg        snap_injen_q;
  reg [31:0] snap_hb_q;
  reg [7:0]  snap_code_q;
  reg        snap_safe_q;
  reg [2:0]  snap_sel_q;
  reg        snap_active_q;
  reg [15:0] snap_lat_q;
  reg [7:0]  snap_boots_q;
  reg [7:0]  snap_nflt_q;
  reg [1:0]  snap_lidx_q;
  reg [7:0]  snap_lboot_q;
  reg [7:0]  snap_lcode_q;
  reg [1:0]  snap_lprof_q;
  reg [39:0] snap_ltime_q;

  // Record requested from the logger: step 1 reads record 0, and so on.
  wire [2:0] log_record;
  assign log_record     = log_step_q - 3'd1;
  assign log_rd_index_o = log_record[1:0];

  reg [7:0] char_c;
  reg       last_c;

  // Character table: {message, index} -> character, and end-of-message flag.
  always @(*) begin
    char_c = 8'h20;
    last_c = 1'b0;
    case ({msg_q, idx_q})
      // MSG_BOOT
      {3'd0, 6'd0}: char_c = 8'h0D;
      {3'd0, 6'd1}: char_c = 8'h0A;
      {3'd0, 6'd2}: char_c = 8'h5B;
      {3'd0, 6'd3}: char_c = 8'h42;
      {3'd0, 6'd4}: char_c = 8'h4F;
      {3'd0, 6'd5}: char_c = 8'h4F;
      {3'd0, 6'd6}: char_c = 8'h54;
      {3'd0, 6'd7}: char_c = 8'h5D;
      {3'd0, 6'd8}: char_c = 8'h20;
      {3'd0, 6'd9}: char_c = 8'h53;
      {3'd0, 6'd10}: char_c = 8'h41;
      {3'd0, 6'd11}: char_c = 8'h46;
      {3'd0, 6'd12}: char_c = 8'h45;
      {3'd0, 6'd13}: char_c = 8'h54;
      {3'd0, 6'd14}: char_c = 8'h59;
      {3'd0, 6'd15}: char_c = 8'h20;
      {3'd0, 6'd16}: char_c = 8'h52;
      {3'd0, 6'd17}: char_c = 8'h49;
      {3'd0, 6'd18}: char_c = 8'h53;
      {3'd0, 6'd19}: char_c = 8'h43;
      {3'd0, 6'd20}: char_c = 8'h2D;
      {3'd0, 6'd21}: char_c = 8'h56;
      {3'd0, 6'd22}: char_c = 8'h20;
      {3'd0, 6'd23}: char_c = 8'h53;
      {3'd0, 6'd24}: char_c = 8'h4F;
      {3'd0, 6'd25}: char_c = 8'h43;
      {3'd0, 6'd26}: char_c = 8'h20;
      {3'd0, 6'd27}: char_c = 8'h2F;
      {3'd0, 6'd28}: char_c = 8'h20;
      {3'd0, 6'd29}: char_c = 8'h41;
      {3'd0, 6'd30}: char_c = 8'h52;
      {3'd0, 6'd31}: char_c = 8'h54;
      {3'd0, 6'd32}: char_c = 8'h59;
      {3'd0, 6'd33}: char_c = 8'h20;
      {3'd0, 6'd34}: char_c = 8'h41;
      {3'd0, 6'd35}: char_c = 8'h37;
      {3'd0, 6'd36}: char_c = 8'h2D;
      {3'd0, 6'd37}: char_c = 8'h31;
      {3'd0, 6'd38}: char_c = 8'h30;
      {3'd0, 6'd39}: char_c = 8'h30;
      {3'd0, 6'd40}: char_c = 8'h54;
      {3'd0, 6'd41}: char_c = 8'h0D;
      {3'd0, 6'd42}: begin char_c = 8'h0A; last_c = 1'b1; end
      // MSG_STATUS
      {3'd1, 6'd0}: char_c = 8'h5B;
      {3'd1, 6'd1}: char_c = 8'h53;
      {3'd1, 6'd2}: char_c = 8'h54;
      {3'd1, 6'd3}: char_c = 8'h41;
      {3'd1, 6'd4}: char_c = 8'h54;
      {3'd1, 6'd5}: char_c = 8'h5D;
      {3'd1, 6'd6}: char_c = 8'h20;
      {3'd1, 6'd7}: char_c = 8'h50;
      {3'd1, 6'd8}: char_c = 8'h52;
      {3'd1, 6'd9}: char_c = 8'h4F;
      {3'd1, 6'd10}: char_c = 8'h46;
      {3'd1, 6'd11}: char_c = 8'h49;
      {3'd1, 6'd12}: char_c = 8'h4C;
      {3'd1, 6'd13}: char_c = 8'h45;
      {3'd1, 6'd14}: char_c = 8'h3D;
      {3'd1, 6'd15}: char_c = hex_ascii({2'b00, snap_profile_q[1:0]});
      {3'd1, 6'd16}: char_c = 8'h20;
      {3'd1, 6'd17}: char_c = 8'h44;
      {3'd1, 6'd18}: char_c = 8'h43;
      {3'd1, 6'd19}: char_c = 8'h4C;
      {3'd1, 6'd20}: char_c = 8'h53;
      {3'd1, 6'd21}: char_c = 8'h3D;
      {3'd1, 6'd22}: char_c = hex_ascii({3'b000, snap_dcls_q});
      {3'd1, 6'd23}: char_c = 8'h20;
      {3'd1, 6'd24}: char_c = 8'h49;
      {3'd1, 6'd25}: char_c = 8'h4E;
      {3'd1, 6'd26}: char_c = 8'h4A;
      {3'd1, 6'd27}: char_c = 8'h5F;
      {3'd1, 6'd28}: char_c = 8'h45;
      {3'd1, 6'd29}: char_c = 8'h4E;
      {3'd1, 6'd30}: char_c = 8'h3D;
      {3'd1, 6'd31}: char_c = hex_ascii({3'b000, snap_injen_q});
      {3'd1, 6'd32}: char_c = 8'h20;
      {3'd1, 6'd33}: char_c = 8'h48;
      {3'd1, 6'd34}: char_c = 8'h42;
      {3'd1, 6'd35}: char_c = 8'h3D;
      {3'd1, 6'd36}: char_c = hex_ascii(snap_hb_q[31:28]);
      {3'd1, 6'd37}: char_c = hex_ascii(snap_hb_q[27:24]);
      {3'd1, 6'd38}: char_c = hex_ascii(snap_hb_q[23:20]);
      {3'd1, 6'd39}: char_c = hex_ascii(snap_hb_q[19:16]);
      {3'd1, 6'd40}: char_c = hex_ascii(snap_hb_q[15:12]);
      {3'd1, 6'd41}: char_c = hex_ascii(snap_hb_q[11:8]);
      {3'd1, 6'd42}: char_c = hex_ascii(snap_hb_q[7:4]);
      {3'd1, 6'd43}: char_c = hex_ascii(snap_hb_q[3:0]);
      {3'd1, 6'd44}: char_c = 8'h20;
      {3'd1, 6'd45}: char_c = 8'h46;
      {3'd1, 6'd46}: char_c = 8'h41;
      {3'd1, 6'd47}: char_c = 8'h55;
      {3'd1, 6'd48}: char_c = 8'h4C;
      {3'd1, 6'd49}: char_c = 8'h54;
      {3'd1, 6'd50}: char_c = 8'h3D;
      {3'd1, 6'd51}: char_c = hex_ascii(snap_code_q[7:4]);
      {3'd1, 6'd52}: char_c = hex_ascii(snap_code_q[3:0]);
      {3'd1, 6'd53}: char_c = 8'h20;
      {3'd1, 6'd54}: char_c = 8'h53;
      {3'd1, 6'd55}: char_c = 8'h41;
      {3'd1, 6'd56}: char_c = 8'h46;
      {3'd1, 6'd57}: char_c = 8'h45;
      {3'd1, 6'd58}: char_c = 8'h3D;
      {3'd1, 6'd59}: char_c = hex_ascii({3'b000, snap_safe_q});
      {3'd1, 6'd60}: char_c = 8'h0D;
      {3'd1, 6'd61}: begin char_c = 8'h0A; last_c = 1'b1; end
      // MSG_INJECT
      {3'd2, 6'd0}: char_c = 8'h5B;
      {3'd2, 6'd1}: char_c = 8'h49;
      {3'd2, 6'd2}: char_c = 8'h4E;
      {3'd2, 6'd3}: char_c = 8'h4A;
      {3'd2, 6'd4}: char_c = 8'h20;
      {3'd2, 6'd5}: char_c = 8'h5D;
      {3'd2, 6'd6}: char_c = 8'h20;
      {3'd2, 6'd7}: char_c = 8'h46;
      {3'd2, 6'd8}: char_c = 8'h41;
      {3'd2, 6'd9}: char_c = 8'h55;
      {3'd2, 6'd10}: char_c = 8'h4C;
      {3'd2, 6'd11}: char_c = 8'h54;
      {3'd2, 6'd12}: char_c = 8'h5F;
      {3'd2, 6'd13}: char_c = 8'h49;
      {3'd2, 6'd14}: char_c = 8'h44;
      {3'd2, 6'd15}: char_c = 8'h3D;
      {3'd2, 6'd16}: char_c = hex_ascii({1'b0, snap_sel_q[2:0]});
      {3'd2, 6'd17}: char_c = 8'h20;
      {3'd2, 6'd18}: char_c = 8'h41;
      {3'd2, 6'd19}: char_c = 8'h50;
      {3'd2, 6'd20}: char_c = 8'h50;
      {3'd2, 6'd21}: char_c = 8'h4C;
      {3'd2, 6'd22}: char_c = 8'h49;
      {3'd2, 6'd23}: char_c = 8'h45;
      {3'd2, 6'd24}: char_c = 8'h44;
      {3'd2, 6'd25}: char_c = 8'h3D;
      {3'd2, 6'd26}: char_c = hex_ascii({3'b000, snap_active_q});
      {3'd2, 6'd27}: char_c = 8'h0D;
      {3'd2, 6'd28}: begin char_c = 8'h0A; last_c = 1'b1; end
      // MSG_FAULT
      {3'd3, 6'd0}: char_c = 8'h5B;
      {3'd3, 6'd1}: char_c = 8'h46;
      {3'd3, 6'd2}: char_c = 8'h4C;
      {3'd3, 6'd3}: char_c = 8'h54;
      {3'd3, 6'd4}: char_c = 8'h20;
      {3'd3, 6'd5}: char_c = 8'h5D;
      {3'd3, 6'd6}: char_c = 8'h20;
      {3'd3, 6'd7}: char_c = 8'h43;
      {3'd3, 6'd8}: char_c = 8'h4F;
      {3'd3, 6'd9}: char_c = 8'h44;
      {3'd3, 6'd10}: char_c = 8'h45;
      {3'd3, 6'd11}: char_c = 8'h3D;
      {3'd3, 6'd12}: char_c = hex_ascii(snap_code_q[7:4]);
      {3'd3, 6'd13}: char_c = hex_ascii(snap_code_q[3:0]);
      {3'd3, 6'd14}: char_c = 8'h20;
      {3'd3, 6'd15}: char_c = 8'h4C;
      {3'd3, 6'd16}: char_c = 8'h41;
      {3'd3, 6'd17}: char_c = 8'h54;
      {3'd3, 6'd18}: char_c = 8'h45;
      {3'd3, 6'd19}: char_c = 8'h4E;
      {3'd3, 6'd20}: char_c = 8'h43;
      {3'd3, 6'd21}: char_c = 8'h59;
      {3'd3, 6'd22}: char_c = 8'h3D;
      {3'd3, 6'd23}: char_c = hex_ascii(snap_lat_q[15:12]);
      {3'd3, 6'd24}: char_c = hex_ascii(snap_lat_q[11:8]);
      {3'd3, 6'd25}: char_c = hex_ascii(snap_lat_q[7:4]);
      {3'd3, 6'd26}: char_c = hex_ascii(snap_lat_q[3:0]);
      {3'd3, 6'd27}: char_c = 8'h20;
      {3'd3, 6'd28}: char_c = 8'h43;
      {3'd3, 6'd29}: char_c = 8'h59;
      {3'd3, 6'd30}: char_c = 8'h43;
      {3'd3, 6'd31}: char_c = 8'h4C;
      {3'd3, 6'd32}: char_c = 8'h45;
      {3'd3, 6'd33}: char_c = 8'h53;
      {3'd3, 6'd34}: char_c = 8'h20;
      {3'd3, 6'd35}: char_c = 8'h53;
      {3'd3, 6'd36}: char_c = 8'h41;
      {3'd3, 6'd37}: char_c = 8'h46;
      {3'd3, 6'd38}: char_c = 8'h45;
      {3'd3, 6'd39}: char_c = 8'h5F;
      {3'd3, 6'd40}: char_c = 8'h53;
      {3'd3, 6'd41}: char_c = 8'h54;
      {3'd3, 6'd42}: char_c = 8'h41;
      {3'd3, 6'd43}: char_c = 8'h54;
      {3'd3, 6'd44}: char_c = 8'h45;
      {3'd3, 6'd45}: char_c = 8'h3D;
      {3'd3, 6'd46}: char_c = hex_ascii({3'b000, snap_safe_q});
      {3'd3, 6'd47}: char_c = 8'h0D;
      {3'd3, 6'd48}: begin char_c = 8'h0A; last_c = 1'b1; end
      // MSG_LOGHDR
      {3'd4, 6'd0}: char_c = 8'h5B;
      {3'd4, 6'd1}: char_c = 8'h4C;
      {3'd4, 6'd2}: char_c = 8'h4F;
      {3'd4, 6'd3}: char_c = 8'h47;
      {3'd4, 6'd4}: char_c = 8'h20;
      {3'd4, 6'd5}: char_c = 8'h5D;
      {3'd4, 6'd6}: char_c = 8'h20;
      {3'd4, 6'd7}: char_c = 8'h42;
      {3'd4, 6'd8}: char_c = 8'h4F;
      {3'd4, 6'd9}: char_c = 8'h4F;
      {3'd4, 6'd10}: char_c = 8'h54;
      {3'd4, 6'd11}: char_c = 8'h53;
      {3'd4, 6'd12}: char_c = 8'h3D;
      {3'd4, 6'd13}: char_c = hex_ascii(snap_boots_q[7:4]);
      {3'd4, 6'd14}: char_c = hex_ascii(snap_boots_q[3:0]);
      {3'd4, 6'd15}: char_c = 8'h20;
      {3'd4, 6'd16}: char_c = 8'h46;
      {3'd4, 6'd17}: char_c = 8'h41;
      {3'd4, 6'd18}: char_c = 8'h55;
      {3'd4, 6'd19}: char_c = 8'h4C;
      {3'd4, 6'd20}: char_c = 8'h54;
      {3'd4, 6'd21}: char_c = 8'h53;
      {3'd4, 6'd22}: char_c = 8'h3D;
      {3'd4, 6'd23}: char_c = hex_ascii(snap_nflt_q[7:4]);
      {3'd4, 6'd24}: char_c = hex_ascii(snap_nflt_q[3:0]);
      {3'd4, 6'd25}: char_c = 8'h0D;
      {3'd4, 6'd26}: begin char_c = 8'h0A; last_c = 1'b1; end
      // MSG_LOGENT
      {3'd5, 6'd0}: char_c = 8'h5B;
      {3'd5, 6'd1}: char_c = 8'h4C;
      {3'd5, 6'd2}: char_c = 8'h4F;
      {3'd5, 6'd3}: char_c = 8'h47;
      {3'd5, 6'd4}: char_c = 8'h20;
      {3'd5, 6'd5}: char_c = 8'h5D;
      {3'd5, 6'd6}: char_c = 8'h20;
      {3'd5, 6'd7}: char_c = 8'h45;
      {3'd5, 6'd8}: char_c = 8'h4E;
      {3'd5, 6'd9}: char_c = 8'h54;
      {3'd5, 6'd10}: char_c = 8'h52;
      {3'd5, 6'd11}: char_c = 8'h59;
      {3'd5, 6'd12}: char_c = 8'h3D;
      {3'd5, 6'd13}: char_c = hex_ascii({2'b00, snap_lidx_q[1:0]});
      {3'd5, 6'd14}: char_c = 8'h20;
      {3'd5, 6'd15}: char_c = 8'h42;
      {3'd5, 6'd16}: char_c = 8'h4F;
      {3'd5, 6'd17}: char_c = 8'h4F;
      {3'd5, 6'd18}: char_c = 8'h54;
      {3'd5, 6'd19}: char_c = 8'h3D;
      {3'd5, 6'd20}: char_c = hex_ascii(snap_lboot_q[7:4]);
      {3'd5, 6'd21}: char_c = hex_ascii(snap_lboot_q[3:0]);
      {3'd5, 6'd22}: char_c = 8'h20;
      {3'd5, 6'd23}: char_c = 8'h43;
      {3'd5, 6'd24}: char_c = 8'h4F;
      {3'd5, 6'd25}: char_c = 8'h44;
      {3'd5, 6'd26}: char_c = 8'h45;
      {3'd5, 6'd27}: char_c = 8'h3D;
      {3'd5, 6'd28}: char_c = hex_ascii(snap_lcode_q[7:4]);
      {3'd5, 6'd29}: char_c = hex_ascii(snap_lcode_q[3:0]);
      {3'd5, 6'd30}: char_c = 8'h20;
      {3'd5, 6'd31}: char_c = 8'h50;
      {3'd5, 6'd32}: char_c = 8'h52;
      {3'd5, 6'd33}: char_c = 8'h4F;
      {3'd5, 6'd34}: char_c = 8'h46;
      {3'd5, 6'd35}: char_c = 8'h49;
      {3'd5, 6'd36}: char_c = 8'h4C;
      {3'd5, 6'd37}: char_c = 8'h45;
      {3'd5, 6'd38}: char_c = 8'h3D;
      {3'd5, 6'd39}: char_c = hex_ascii({2'b00, snap_lprof_q[1:0]});
      {3'd5, 6'd40}: char_c = 8'h20;
      {3'd5, 6'd41}: char_c = 8'h54;
      {3'd5, 6'd42}: char_c = 8'h49;
      {3'd5, 6'd43}: char_c = 8'h4D;
      {3'd5, 6'd44}: char_c = 8'h45;
      {3'd5, 6'd45}: char_c = 8'h3D;
      {3'd5, 6'd46}: char_c = hex_ascii(snap_ltime_q[39:36]);
      {3'd5, 6'd47}: char_c = hex_ascii(snap_ltime_q[35:32]);
      {3'd5, 6'd48}: char_c = hex_ascii(snap_ltime_q[31:28]);
      {3'd5, 6'd49}: char_c = hex_ascii(snap_ltime_q[27:24]);
      {3'd5, 6'd50}: char_c = hex_ascii(snap_ltime_q[23:20]);
      {3'd5, 6'd51}: char_c = hex_ascii(snap_ltime_q[19:16]);
      {3'd5, 6'd52}: char_c = hex_ascii(snap_ltime_q[15:12]);
      {3'd5, 6'd53}: char_c = hex_ascii(snap_ltime_q[11:8]);
      {3'd5, 6'd54}: char_c = hex_ascii(snap_ltime_q[7:4]);
      {3'd5, 6'd55}: char_c = hex_ascii(snap_ltime_q[3:0]);
      {3'd5, 6'd56}: char_c = 8'h0D;
      {3'd5, 6'd57}: begin char_c = 8'h0A; last_c = 1'b1; end
      default: begin char_c = 8'h0A; last_c = 1'b1; end
    endcase
  end

  assign tx_data_o  = char_c;
  assign tx_valid_o = sending_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sending_q     <= 1'b0;
      msg_q         <= MSG_BOOT;
      idx_q         <= {6{1'b0}};
      pend_boot_q   <= 1'b1;
      pend_inject_q <= 1'b0;
      pend_fault_q  <= 1'b0;
      pend_status_q <= 1'b1;
      fault_seen_q  <= 1'b0;
      period_q      <= {STATUS_PERIOD_BITS{1'b0}};
      snap_profile_q <= 2'b00;
      snap_dcls_q    <= 1'b0;
      snap_injen_q   <= 1'b0;
      snap_hb_q      <= 32'b0;
      snap_code_q    <= 8'b0;
      snap_safe_q    <= 1'b0;
      snap_sel_q     <= 3'b0;
      snap_active_q  <= 1'b0;
      snap_lat_q     <= 16'b0;
      pend_log_q     <= 1'b1;
      log_step_q     <= 3'd0;
      snap_boots_q   <= 8'b0;
      snap_nflt_q    <= 8'b0;
      snap_lidx_q    <= 2'b0;
      snap_lboot_q   <= 8'b0;
      snap_lcode_q   <= 8'b0;
      snap_lprof_q   <= 2'b0;
      snap_ltime_q   <= 40'b0;
    end else begin
      period_q     <= period_q + 1'b1;
      fault_seen_q <= fault_latched_i;

      if (!sending_q) begin
        if (!pend_boot_q && pend_log_q && (log_step_q != 3'd0) &&
            !log_rd_valid_i) begin
          // No further stored record: the log print-out is complete.
          pend_log_q <= 1'b0;
        end else if (pend_boot_q || pend_log_q || pend_inject_q ||
                     pend_fault_q || pend_status_q) begin
          sending_q <= 1'b1;
          idx_q     <= {6{1'b0}};

          snap_profile_q <= profile_i;
          snap_dcls_q    <= dcls_enable_i;
          snap_injen_q   <= injection_enable_i;
          snap_hb_q      <= heartbeat_i;
          snap_code_q    <= fault_code_i;
          snap_safe_q    <= safe_state_i;
          snap_sel_q     <= inject_select_i;
          snap_active_q  <= inject_active_i;
          snap_lat_q     <= latency_i;
          snap_boots_q   <= log_boot_count_i;
          snap_nflt_q    <= log_fault_count_i;
          snap_lidx_q    <= log_record[1:0];
          snap_lboot_q   <= log_rd_boot_i;
          snap_lcode_q   <= log_rd_code_i;
          snap_lprof_q   <= log_rd_profile_i;
          snap_ltime_q   <= log_rd_time_i;

          if (pend_boot_q) begin
            msg_q       <= MSG_BOOT;
            pend_boot_q <= 1'b0;
          end else if (pend_log_q) begin
            if (log_step_q == 3'd0)
              msg_q <= MSG_LOGHDR;
            else
              msg_q <= MSG_LOGENT;

            // After the fourth record the print-out is complete.
            if (log_step_q == 3'd4)
              pend_log_q <= 1'b0;
            else
              log_step_q <= log_step_q + 3'd1;
          end else if (pend_inject_q) begin
            msg_q         <= MSG_INJECT;
            pend_inject_q <= 1'b0;
          end else if (pend_fault_q) begin
            msg_q        <= MSG_FAULT;
            pend_fault_q <= 1'b0;
          end else begin
            msg_q         <= MSG_STATUS;
            pend_status_q <= 1'b0;
          end
        end
      end else if (tx_ready_i) begin
        // The UART accepts the current character in this cycle.
        if (last_c)
          sending_q <= 1'b0;
        else
          idx_q <= idx_q + 1'b1;
      end

      // New events are recorded last so they are never lost when they
      // coincide with the start of a message.
      if (inject_event_i)
        pend_inject_q <= 1'b1;
      if (fault_latched_i && !fault_seen_q)
        pend_fault_q <= 1'b1;
      if (status_request_i || (&period_q))
        pend_status_q <= 1'b1;
    end
  end

endmodule

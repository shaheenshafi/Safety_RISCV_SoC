#!/usr/bin/env python3
"""Generate rtl/board/demo_status_reporter.v.

The reporter prints fixed text lines with hexadecimal fields over the UART.
Writing the character table by hand is error-prone, so it is generated from
the message templates below. Re-run after changing a template:

    python3 scripts/gen/gen_status_reporter.py

Template syntax: {name:N} inserts N hexadecimal digits of the snapshot
signal 'name', most significant digit first.
"""
import os
import re

MESSAGES = [
    ("MSG_BOOT",   "\r\n[BOOT] SAFETY RISC-V SOC / ARTY A7-100T\r\n"),
    ("MSG_STATUS", "[STAT] PROFILE={profile:1} DCLS={dcls:1} INJ_EN={injen:1} "
                   "HB={hb:8} FAULT={code:2} SAFE={safe:1}\r\n"),
    ("MSG_INJECT", "[INJ ] FAULT_ID={sel:1} APPLIED={active:1}\r\n"),
    ("MSG_FAULT",  "[FLT ] CODE={code:2} LATENCY={lat:4} CYCLES SAFE_STATE={safe:1}\r\n"),
]

# Snapshot signal name -> (register name, width in bits)
FIELDS = {
    "profile": ("snap_profile_q", 2),
    "dcls":    ("snap_dcls_q", 1),
    "injen":   ("snap_injen_q", 1),
    "hb":      ("snap_hb_q", 32),
    "code":    ("snap_code_q", 8),
    "safe":    ("snap_safe_q", 1),
    "sel":     ("snap_sel_q", 3),
    "active":  ("snap_active_q", 1),
    "lat":     ("snap_lat_q", 16),
}


def nibble_expr(reg, width, digit, digits):
    """Verilog expression for hex digit 'digit' (0 = most significant)."""
    lo = 4 * (digits - 1 - digit)
    hi = lo + 3
    if width == 1:
        return "{3'b000, %s}" % reg
    if hi < width:
        return "%s[%d:%d]" % (reg, hi, lo)
    pad = hi - (width - 1)
    return "{%d'b%s, %s[%d:%d]}" % (pad, "0" * pad, reg, width - 1, lo)


def expand(template):
    """Return a list of ('const', byte) or ('hex', expr) per character."""
    out = []
    pos = 0
    for m in re.finditer(r"\{(\w+):(\d+)\}", template):
        for ch in template[pos:m.start()]:
            out.append(("const", ord(ch)))
        reg, width = FIELDS[m.group(1)]
        digits = int(m.group(2))
        assert 4 * digits >= width, m.group(0)
        for d in range(digits):
            out.append(("hex", nibble_expr(reg, width, d, digits)))
        pos = m.end()
    for ch in template[pos:]:
        out.append(("const", ord(ch)))
    return out


def main():
    tables = [(name, expand(t)) for name, t in MESSAGES]
    longest = max(len(t) for _, t in tables)
    idx_w = max(1, (longest - 1).bit_length())

    rows = []
    for m, (name, chars) in enumerate(tables):
        rows.append("      // %s" % name)
        for i, (kind, val) in enumerate(chars):
            last = (i == len(chars) - 1)
            rhs = ("8'h%02X" % val) if kind == "const" else ("hex_ascii(%s)" % val)
            if last:
                rows.append("      {2'd%d, %d'd%d}: begin char_c = %s; last_c = 1'b1; end"
                            % (m, idx_w, i, rhs))
            else:
                rows.append("      {2'd%d, %d'd%d}: char_c = %s;" % (m, idx_w, i, rhs))
    table = "\n".join(rows)

    doc = "\n".join("//   %s" % t.replace("\r\n", "<CR><LF>") for _, t in MESSAGES)

    text = TEMPLATE.replace("@TABLE@", table).replace("@IDXW@", str(idx_w)).replace("@DOC@", doc)
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.normpath(os.path.join(here, "..", "..", "rtl", "board", "demo_status_reporter.v"))
    with open(out, "w") as f:
        f.write(text)
    print("wrote %s (%d messages, longest %d characters)" % (out, len(tables), longest))


TEMPLATE = r"""// -----------------------------------------------------------------------------
// Board status reporter (UART text)
//
// GENERATED FILE - edit scripts/gen/gen_status_reporter.py, not this file.
//
// Observes the SoC status outputs and prints one text line per event:
@DOC@
// Fields are hexadecimal. The reporter only observes; it drives nothing back
// into the SoC, so it cannot affect the safety mechanisms.
//
// Events and priority: boot banner, injection request, fault, status.
// A status line is printed after boot, on request, and periodically every
// 2^STATUS_PERIOD_BITS clock cycles.
//
// RTL language: Verilog
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

    output wire [7:0]  tx_data_o,
    output wire        tx_valid_o,
    input  wire        tx_ready_i
);

  localparam [1:0] MSG_BOOT   = 2'd0;
  localparam [1:0] MSG_STATUS = 2'd1;
  localparam [1:0] MSG_INJECT = 2'd2;
  localparam [1:0] MSG_FAULT  = 2'd3;

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
  reg [1:0]                    msg_q;
  reg [@IDXW@-1:0]                    idx_q;

  reg                          pend_boot_q;
  reg                          pend_inject_q;
  reg                          pend_fault_q;
  reg                          pend_status_q;
  reg                          fault_seen_q;
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

  reg [7:0] char_c;
  reg       last_c;

  // Character table: {message, index} -> character, and end-of-message flag.
  always @(*) begin
    char_c = 8'h20;
    last_c = 1'b0;
    case ({msg_q, idx_q})
@TABLE@
      default: begin char_c = 8'h0A; last_c = 1'b1; end
    endcase
  end

  assign tx_data_o  = char_c;
  assign tx_valid_o = sending_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sending_q     <= 1'b0;
      msg_q         <= MSG_BOOT;
      idx_q         <= {@IDXW@{1'b0}};
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
    end else begin
      period_q     <= period_q + 1'b1;
      fault_seen_q <= fault_latched_i;

      if (!sending_q) begin
        if (pend_boot_q || pend_inject_q || pend_fault_q || pend_status_q) begin
          sending_q <= 1'b1;
          idx_q     <= {@IDXW@{1'b0}};

          snap_profile_q <= profile_i;
          snap_dcls_q    <= dcls_enable_i;
          snap_injen_q   <= injection_enable_i;
          snap_hb_q      <= heartbeat_i;
          snap_code_q    <= fault_code_i;
          snap_safe_q    <= safe_state_i;
          snap_sel_q     <= inject_select_i;
          snap_active_q  <= inject_active_i;
          snap_lat_q     <= latency_i;

          if (pend_boot_q) begin
            msg_q       <= MSG_BOOT;
            pend_boot_q <= 1'b0;
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
"""

if __name__ == "__main__":
    main()

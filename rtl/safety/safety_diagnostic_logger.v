// -----------------------------------------------------------------------------
// Diagnostic logger
//
// Keeps a record of the most recent faults so that the cause of a safe-state
// entry can still be read after the system has been reset and restarted.
//
// For every fault latched by the fault manager one record is stored:
//   boot     number of the run in which the fault occurred (reset releases
//            since the FPGA was configured)
//   code     fault code from the fault manager
//   profile  runtime profile that was active
//   time     clock cycles from reset release to fault detection
//
// The log holds the last 2^DEPTH_LOG2 records; the oldest is overwritten.
// Record 0 on the read port is always the most recent one.
//
// Retention: the log registers have NO reset. They start at zero when the
// FPGA is configured (register initial values) and keep their contents
// through the system reset, which is what makes the log useful. Only the
// run-time counter and the edge detectors use the system reset.
//
// The logger only observes. It drives nothing back into the safety logic.
//
// Limitation: the retained registers are qualified by reset-domain flip-flops.
// A fault that is latched in the same clock cycle in which the reset button
// is pressed may not be recorded.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module safety_diagnostic_logger #(
    parameter integer DEPTH_LOG2 = 2,
    parameter integer TIME_WIDTH = 40
) (
    input  wire                  clk_i,
    input  wire                  rst_ni,

    // Observed safety status
    input  wire                  fault_latched_i,
    input  wire [7:0]            fault_code_i,
    input  wire [1:0]            profile_i,

    // Summary counters (saturate at 255)
    output wire [7:0]            boot_count_o,
    output wire [7:0]            fault_count_o,

    // Read port: record 0 is the most recent
    input  wire [DEPTH_LOG2-1:0] rd_index_i,
    output wire                  rd_valid_o,
    output wire [7:0]            rd_boot_o,
    output wire [7:0]            rd_code_o,
    output wire [1:0]            rd_profile_o,
    output wire [TIME_WIDTH-1:0] rd_time_o
);

  localparam integer DEPTH = (1 << DEPTH_LOG2);

  // --------------------------------------------------------------------------
  // Reset-domain state: restarts with every system reset
  // --------------------------------------------------------------------------
  reg                  started_q;
  reg                  booted_q;
  reg                  fault_seen_q;
  reg [TIME_WIDTH-1:0] time_q;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      started_q    <= 1'b0;
      booted_q     <= 1'b0;
      fault_seen_q <= 1'b0;
      time_q       <= {TIME_WIDTH{1'b0}};
    end else begin
      started_q    <= 1'b1;
      booted_q     <= started_q;
      fault_seen_q <= fault_latched_i;

      if (!(&time_q))
        time_q <= time_q + 1'b1;
    end
  end

  wire boot_event;
  wire fault_event;

  assign boot_event  = started_q && !booted_q;
  assign fault_event = started_q && fault_latched_i && !fault_seen_q;

  // --------------------------------------------------------------------------
  // Retained state: no reset, zero at FPGA configuration
  // --------------------------------------------------------------------------
  reg [7:0]            boot_count_q  = 8'd0;
  reg [7:0]            fault_count_q = 8'd0;
  reg [DEPTH_LOG2-1:0] wr_ptr_q      = {DEPTH_LOG2{1'b0}};
  reg [DEPTH_LOG2:0]   valid_count_q = {(DEPTH_LOG2+1){1'b0}};

  reg [7:0]            log_boot_q    [0:DEPTH-1];
  reg [7:0]            log_code_q    [0:DEPTH-1];
  reg [1:0]            log_profile_q [0:DEPTH-1];
  reg [TIME_WIDTH-1:0] log_time_q    [0:DEPTH-1];

  integer i;

  initial begin
    for (i = 0; i < DEPTH; i = i + 1) begin
      log_boot_q[i]    = 8'd0;
      log_code_q[i]    = 8'd0;
      log_profile_q[i] = 2'd0;
      log_time_q[i]    = {TIME_WIDTH{1'b0}};
    end
  end

  always @(posedge clk_i) begin
    if (boot_event && (boot_count_q != 8'hFF))
      boot_count_q <= boot_count_q + 8'd1;

    if (fault_event) begin
      log_boot_q[wr_ptr_q]    <= boot_count_q;
      log_code_q[wr_ptr_q]    <= fault_code_i;
      log_profile_q[wr_ptr_q] <= profile_i;
      log_time_q[wr_ptr_q]    <= time_q;

      wr_ptr_q <= wr_ptr_q + 1'b1;

      if (!valid_count_q[DEPTH_LOG2])
        valid_count_q <= valid_count_q + 1'b1;

      if (fault_count_q != 8'hFF)
        fault_count_q <= fault_count_q + 8'd1;
    end
  end

  // --------------------------------------------------------------------------
  // Read port
  // --------------------------------------------------------------------------
  wire [DEPTH_LOG2-1:0] rd_addr;

  // The most recent record is one position behind the write pointer.
  assign rd_addr = wr_ptr_q - {{(DEPTH_LOG2-1){1'b0}}, 1'b1} - rd_index_i;

  assign boot_count_o  = boot_count_q;
  assign fault_count_o = fault_count_q;

  assign rd_valid_o   = ({1'b0, rd_index_i} < valid_count_q);
  assign rd_boot_o    = log_boot_q[rd_addr];
  assign rd_code_o    = log_code_q[rd_addr];
  assign rd_profile_o = log_profile_q[rd_addr];
  assign rd_time_o    = log_time_q[rd_addr];

endmodule

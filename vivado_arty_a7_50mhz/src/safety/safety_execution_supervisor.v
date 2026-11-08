`timescale 1ns/1ps

// Standalone execution supervisor for Stage 4F.
//
// The watchdog is windowed:
//   - A kick before MIN_KICK_CYCLES is an early-service fault.
//   - A kick within the permitted window restarts the watchdog age.
//   - Missing a kick by MAX_KICK_CYCLES is a timeout fault.
//
// progress_event_i is an explicit forward-progress observation input.
// Its source and meaning must be established by the integrating design.
//
// Fault outputs are sticky until reset. Disabling supervision clears the
// timer counters but does not clear previously detected faults.
module safety_execution_supervisor #(
    parameter integer MIN_KICK_CYCLES        = 4,
    parameter integer MAX_KICK_CYCLES        = 16,
    parameter integer PROGRESS_TIMEOUT_CYCLES = 16
) (
    input  wire clk_i,
    input  wire rst_ni,
    input  wire enable_i,

    input  wire watchdog_kick_i,
    input  wire progress_event_i,

    output reg  watchdog_early_fault_o,
    output reg  watchdog_timeout_fault_o,
    output reg  progress_timeout_fault_o,
    output wire supervisor_fault_o
);

  localparam integer WATCHDOG_WIDTH =
      (MAX_KICK_CYCLES > 1) ? $clog2(MAX_KICK_CYCLES + 1) : 1;

  localparam integer PROGRESS_WIDTH =
      (PROGRESS_TIMEOUT_CYCLES > 1)
          ? $clog2(PROGRESS_TIMEOUT_CYCLES + 1) : 1;

  localparam [WATCHDOG_WIDTH-1:0] MIN_KICK_THRESHOLD =
      WATCHDOG_WIDTH'(MIN_KICK_CYCLES - 1);
  localparam [WATCHDOG_WIDTH-1:0] MAX_KICK_THRESHOLD =
      WATCHDOG_WIDTH'(MAX_KICK_CYCLES - 1);
  localparam [WATCHDOG_WIDTH-1:0] MAX_KICK_VALUE =
      WATCHDOG_WIDTH'(MAX_KICK_CYCLES);

  localparam [PROGRESS_WIDTH-1:0] PROGRESS_TIMEOUT_THRESHOLD =
      PROGRESS_WIDTH'(PROGRESS_TIMEOUT_CYCLES - 1);
  localparam [PROGRESS_WIDTH-1:0] PROGRESS_TIMEOUT_VALUE =
      PROGRESS_WIDTH'(PROGRESS_TIMEOUT_CYCLES);

  reg [WATCHDOG_WIDTH-1:0] watchdog_age_q;
  reg [PROGRESS_WIDTH-1:0] progress_age_q;

  assign supervisor_fault_o =
      watchdog_early_fault_o |
      watchdog_timeout_fault_o |
      progress_timeout_fault_o;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      watchdog_age_q          <= {WATCHDOG_WIDTH{1'b0}};
      progress_age_q          <= {PROGRESS_WIDTH{1'b0}};
      watchdog_early_fault_o  <= 1'b0;
      watchdog_timeout_fault_o <= 1'b0;
      progress_timeout_fault_o <= 1'b0;
    end else if (!enable_i) begin
      // Re-arm timing when supervision is disabled. Fault history is sticky.
      watchdog_age_q <= {WATCHDOG_WIDTH{1'b0}};
      progress_age_q <= {PROGRESS_WIDTH{1'b0}};
    end else begin
      // The current active clock edge represents the next elapsed cycle.
      // A kick is valid when that elapsed interval is within [MIN, MAX].
      if (watchdog_kick_i) begin
        if (watchdog_age_q < MIN_KICK_THRESHOLD) begin
          watchdog_early_fault_o <= 1'b1;
          watchdog_age_q <= watchdog_age_q + 1'b1;
        end else if (watchdog_age_q >= MAX_KICK_VALUE) begin
          watchdog_timeout_fault_o <= 1'b1;
          watchdog_age_q <= MAX_KICK_VALUE;
        end else begin
          // Valid watchdog service.
          watchdog_age_q <= {WATCHDOG_WIDTH{1'b0}};
        end
      end else if (watchdog_age_q >= MAX_KICK_THRESHOLD) begin
        // No kick arrived by the maximum permitted interval.
        watchdog_timeout_fault_o <= 1'b1;
        watchdog_age_q <= MAX_KICK_VALUE;
      end else begin
        watchdog_age_q <= watchdog_age_q + 1'b1;
      end

      // Progress supervision is independent of watchdog servicing.
      if (progress_event_i) begin
        progress_age_q <= {PROGRESS_WIDTH{1'b0}};
      end else if (progress_age_q >= PROGRESS_TIMEOUT_THRESHOLD) begin
        progress_timeout_fault_o <= 1'b1;
        progress_age_q <= PROGRESS_TIMEOUT_VALUE;
      end else begin
        progress_age_q <= progress_age_q + 1'b1;
      end
    end
  end

endmodule

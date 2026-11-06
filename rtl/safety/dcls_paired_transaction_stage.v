`timescale 1ns/1ps

// Paired request admission and registered transaction staging.
//
// This block is intended for an active redundant-comparison path. The caller
// supplies comparison signatures that encode exactly the fields relevant to
// the selected interface. In particular, a data-channel signature can mask
// write data for reads, while an instruction signature can contain only the
// instruction address.
//
// payload_a_i/payload_b_i are the ORIGINAL payloads that must be delivered to
// the two downstream channels. compare_payload_b_i may be an observation-path
// value (for example, the output of a fault injector); it is never stored as
// the downstream Core B payload.
//
// A pair is accepted only when both requests are present, the comparison
// signatures match, and the paired FIFO can accept the entry. Both grants are
// asserted together and correspond to the FIFO push at the active clock edge.
// A queued entry is already comparison-qualified. Later request mismatches do
// not combinationally gate its downstream valid; the system should flush the
// queue when its registered fault/safe-state policy becomes active.

module dcls_paired_transaction_stage #(
    parameter integer PayloadWidth  = 69,
    parameter integer CompareWidth  = 69,
    parameter integer Depth         = 2
) (
    input  wire                         clk_i,
    input  wire                         rst_ni,
    input  wire                         flush_i,

    input  wire                         req_a_i,
    input  wire                         req_b_i,
    input  wire [CompareWidth-1:0]      compare_payload_a_i,
    input  wire [CompareWidth-1:0]      compare_payload_b_i,
    input  wire [PayloadWidth-1:0]      payload_a_i,
    input  wire [PayloadWidth-1:0]      payload_b_i,
    output wire                         gnt_a_o,
    output wire                         gnt_b_o,

    output wire                         request_mismatch_o,
    output wire                         payload_mismatch_o,
    output wire                         mismatch_o,

    output wire                         txn_valid_o,
    input  wire                         txn_ready_i,
    output wire [PayloadWidth-1:0]      txn_payload_a_o,
    output wire [PayloadWidth-1:0]      txn_payload_b_o,

    output wire                         full_o,
    output wire                         empty_o,
    output wire [((Depth < 1) ? 1 : $clog2(Depth+1))-1:0] level_o
);

    wire pair_present;
    wire pair_match;
    wire fifo_push_ready;
    wire fifo_push_accepted;

    assign request_mismatch_o = req_a_i ^ req_b_i;
    assign payload_mismatch_o = req_a_i && req_b_i &&
                                (compare_payload_a_i != compare_payload_b_i);
    assign mismatch_o = request_mismatch_o | payload_mismatch_o;

    assign pair_present = req_a_i && req_b_i;
    assign pair_match = pair_present && !payload_mismatch_o &&
                        !flush_i && fifo_push_ready;

    dcls_paired_transaction_fifo #(
        .PayloadWidth (PayloadWidth),
        .Depth        (Depth)
    ) u_paired_fifo (
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        .flush_i           (flush_i),
        .push_i            (pair_match),
        .payload_a_i       (payload_a_i),
        .payload_b_i       (payload_b_i),
        .push_ready_o      (fifo_push_ready),
        .push_accepted_o   (fifo_push_accepted),
        .out_valid_o       (txn_valid_o),
        .out_ready_i       (txn_ready_i),
        .payload_a_o       (txn_payload_a_o),
        .payload_b_o       (txn_payload_b_o),
        .full_o            (full_o),
        .empty_o           (empty_o),
        .level_o           (level_o)
    );

    // Both processor interfaces observe the same admission decision.
    // fifo_push_accepted includes capacity and flush checks.
    assign gnt_a_o = fifo_push_accepted;
    assign gnt_b_o = fifo_push_accepted;

endmodule

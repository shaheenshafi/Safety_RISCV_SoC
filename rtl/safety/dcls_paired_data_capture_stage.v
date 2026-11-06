`timescale 1ns/1ps

// One-entry, capture-before-compare stage for a paired DCLS data channel.
//
// Cycle protocol when stage_enable_i is asserted:
//   1. In IDLE, capture both live requests and their comparison signatures.
//      No processor grant and no RAM commit occur in this cycle.
//   2. In CHECK, compare the registered signatures. If they match, assert
//      both grants and commit_valid_o together. The downstream RAM samples
//      the registered payloads on that rising edge.
//   3. A mismatch or external flush blocks the commit and puts the stage in
//      a fail-closed state until reset.
//
// The upstream Ibex requests and payloads must remain stable while grant is
// low. The verification environment must check this protocol assumption.
//
// When stage_enable_i is low and the stage is idle, bypass_o selects the
// existing direct/basic-profile path. A pending transaction is never bypassed
// if stage_enable_i changes while the stage is in CHECK.

module dcls_paired_data_capture_stage #(
    parameter integer PayloadWidth = 69,
    parameter integer CompareWidth = 69
) (
    input  wire                        clk_i,
    input  wire                        rst_ni,
    input  wire                        stage_enable_i,
    input  wire                        flush_i,
    // Downstream admission. A captured transaction remains pending until
    // this is asserted and the paired grant/commit edge can really occur.
    input  wire                        commit_ready_i,

    input  wire                        req_a_i,
    input  wire                        req_b_i,
    input  wire [CompareWidth-1:0]     compare_payload_a_i,
    input  wire [CompareWidth-1:0]     compare_payload_b_i,
    input  wire [PayloadWidth-1:0]     payload_a_i,
    input  wire [PayloadWidth-1:0]     payload_b_i,

    output wire                        gnt_a_o,
    output wire                        gnt_b_o,
    output wire                        request_mismatch_o,
    output wire                        payload_mismatch_o,
    output wire                        mismatch_o,

    output wire                        commit_valid_o,
    output wire [PayloadWidth-1:0]     commit_payload_a_o,
    output wire [PayloadWidth-1:0]     commit_payload_b_o,

    output wire                        bypass_o,
    output wire                        busy_o,
    output wire                        fault_latched_o
);

    localparam [1:0] ST_IDLE  = 2'b00;
    localparam [1:0] ST_CHECK = 2'b01;
    localparam [1:0] ST_FAULT = 2'b10;

    reg [1:0] state_q;
    reg       fault_q;

    reg [CompareWidth-1:0] compare_payload_a_q;
    reg [CompareWidth-1:0] compare_payload_b_q;
    reg [PayloadWidth-1:0] payload_a_q;
    reg [PayloadWidth-1:0] payload_b_q;

    wire request_valid_mismatch;
    wire pending_request_lost;
    wire registered_payload_mismatch;
    wire registered_payload_changed;
    wire mismatch_event;

    assign request_valid_mismatch =
        (stage_enable_i || (state_q != ST_IDLE)) &&
        (req_a_i != req_b_i);

    // A captured request is not allowed to disappear before its grant edge.
    assign pending_request_lost =
        (state_q == ST_CHECK) && !(req_a_i && req_b_i);

    assign registered_payload_mismatch =
        (state_q == ST_CHECK) &&
        (compare_payload_a_q != compare_payload_b_q);

    // Fail closed if either live processor request payload changes between
    // capture and the actual grant/commit edge. payload_* inputs are sanitized
    // by the SoC so read write-data bits are treated as don't-care.
    assign registered_payload_changed =
        (state_q == ST_CHECK) &&
        ((payload_a_i != payload_a_q) ||
         (payload_b_i != payload_b_q));

    assign request_mismatch_o =
        request_valid_mismatch || pending_request_lost;

    assign payload_mismatch_o =
        registered_payload_mismatch || registered_payload_changed;

    assign mismatch_event = request_mismatch_o || payload_mismatch_o;
    assign mismatch_o = fault_q || mismatch_event;

    // Grants and RAM commit are the same handshake edge. Payloads presented
    // to RAM are the captured values, not the live processor wires.
    assign commit_valid_o =
        (state_q == ST_CHECK) &&
        !mismatch_event &&
        !flush_i &&
        !fault_q &&
        commit_ready_i;

    assign gnt_a_o = commit_valid_o;
    assign gnt_b_o = commit_valid_o;

    assign commit_payload_a_o = payload_a_q;
    assign commit_payload_b_o = payload_b_q;

    assign bypass_o =
        (state_q == ST_IDLE) &&
        !stage_enable_i &&
        !flush_i &&
        !fault_q;

    assign busy_o = (state_q == ST_CHECK);
    assign fault_latched_o = fault_q;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q             <= ST_IDLE;
            fault_q             <= 1'b0;
            compare_payload_a_q <= {CompareWidth{1'b0}};
            compare_payload_b_q <= {CompareWidth{1'b0}};
            payload_a_q         <= {PayloadWidth{1'b0}};
            payload_b_q         <= {PayloadWidth{1'b0}};
        end else if (mismatch_event) begin
            state_q <= ST_FAULT;
            fault_q <= 1'b1;
        end else if (flush_i) begin
            // External safety faults also fail the stage closed, but are not
            // misreported as a DCLS data mismatch by this module.
            state_q <= ST_FAULT;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (stage_enable_i && req_a_i && req_b_i) begin
                        compare_payload_a_q <= compare_payload_a_i;
                        compare_payload_b_q <= compare_payload_b_i;
                        payload_a_q         <= payload_a_i;
                        payload_b_q         <= payload_b_i;
                        state_q             <= ST_CHECK;
                    end
                end

                ST_CHECK: begin
                    if (commit_valid_o) begin
                        state_q <= ST_IDLE;
                    end
                end

                ST_FAULT: begin
                    state_q <= ST_FAULT;
                end

                default: begin
                    state_q <= ST_FAULT;
                end
            endcase
        end
    end

endmodule

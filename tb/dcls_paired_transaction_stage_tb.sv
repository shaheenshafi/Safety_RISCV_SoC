`timescale 1ns/1ps

module dcls_paired_transaction_stage_tb;
    localparam integer PAYLOAD_WIDTH = 16;
    localparam integer COMPARE_WIDTH = 8;
    localparam integer DEPTH = 2;
    localparam integer LEVEL_WIDTH = $clog2(DEPTH+1);
    localparam [LEVEL_WIDTH-1:0] LEVEL_ZERO = 0;
    localparam [LEVEL_WIDTH-1:0] LEVEL_ONE = 1;
    localparam [LEVEL_WIDTH-1:0] DEPTH_LEVEL = DEPTH[LEVEL_WIDTH-1:0];

    logic clk_i = 1'b0;
    logic rst_ni = 1'b0;
    logic flush_i = 1'b0;
    logic req_a_i = 1'b0;
    logic req_b_i = 1'b0;
    logic [COMPARE_WIDTH-1:0] compare_payload_a_i = '0;
    logic [COMPARE_WIDTH-1:0] compare_payload_b_i = '0;
    logic [PAYLOAD_WIDTH-1:0] payload_a_i = '0;
    logic [PAYLOAD_WIDTH-1:0] payload_b_i = '0;
    wire gnt_a_o;
    wire gnt_b_o;
    wire request_mismatch_o;
    wire payload_mismatch_o;
    wire mismatch_o;
    wire txn_valid_o;
    logic txn_ready_i = 1'b0;
    wire [PAYLOAD_WIDTH-1:0] txn_payload_a_o;
    wire [PAYLOAD_WIDTH-1:0] txn_payload_b_o;
    wire full_o;
    wire empty_o;
    wire [LEVEL_WIDTH-1:0] level_o;

    always #5 clk_i <= ~clk_i;

    dcls_paired_transaction_stage #(
        .PayloadWidth (PAYLOAD_WIDTH),
        .CompareWidth (COMPARE_WIDTH),
        .Depth        (DEPTH)
    ) dut (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),
        .flush_i               (flush_i),
        .req_a_i               (req_a_i),
        .req_b_i               (req_b_i),
        .compare_payload_a_i   (compare_payload_a_i),
        .compare_payload_b_i   (compare_payload_b_i),
        .payload_a_i           (payload_a_i),
        .payload_b_i           (payload_b_i),
        .gnt_a_o               (gnt_a_o),
        .gnt_b_o               (gnt_b_o),
        .request_mismatch_o    (request_mismatch_o),
        .payload_mismatch_o    (payload_mismatch_o),
        .mismatch_o            (mismatch_o),
        .txn_valid_o           (txn_valid_o),
        .txn_ready_i           (txn_ready_i),
        .txn_payload_a_o       (txn_payload_a_o),
        .txn_payload_b_o       (txn_payload_b_o),
        .full_o                (full_o),
        .empty_o               (empty_o),
        .level_o               (level_o)
    );

    task automatic clear_requests;
        begin
            req_a_i = 1'b0;
            req_b_i = 1'b0;
            compare_payload_a_i = '0;
            compare_payload_b_i = '0;
            payload_a_i = '0;
            payload_b_i = '0;
        end
    endtask

    task automatic drive_matched(input logic [COMPARE_WIDTH-1:0] cmp,
                                 input logic [PAYLOAD_WIDTH-1:0] raw_a,
                                 input logic [PAYLOAD_WIDTH-1:0] raw_b);
        begin
            @(negedge clk_i);
            req_a_i = 1'b1;
            req_b_i = 1'b1;
            compare_payload_a_i = cmp;
            compare_payload_b_i = cmp;
            payload_a_i = raw_a;
            payload_b_i = raw_b;
            #1;
        end
    endtask

    task automatic accept_current_pair;
        begin
            if (!gnt_a_o || !gnt_b_o || mismatch_o)
                $fatal(1, "Expected both grants for a matched pair");
            @(posedge clk_i);
            #1;
            clear_requests();
        end
    endtask

    task automatic expect_head(input logic [PAYLOAD_WIDTH-1:0] a,
                               input logic [PAYLOAD_WIDTH-1:0] b,
                               input string label_text);
        begin
            if (!txn_valid_o || txn_payload_a_o !== a || txn_payload_b_o !== b)
                $fatal(1, "%s: expected valid A=%h B=%h, got valid=%b A=%h B=%h",
                       label_text, a, b, txn_valid_o,
                       txn_payload_a_o, txn_payload_b_o);
        end
    endtask

    initial begin
        // Reset and idle.
        repeat (2) @(posedge clk_i);
        @(negedge clk_i);
        rst_ni = 1'b1;
        #1;
        if (!empty_o || txn_valid_o || mismatch_o || gnt_a_o || gnt_b_o ||
            level_o != LEVEL_ZERO)
            $fatal(1, "Reset/idle check failed");

        // A matching comparison signature accepts both requests together.
        // Raw payloads intentionally differ: the comparison signature may be
        // fault-injected/normalized, but the original payloads are what get queued.
        drive_matched(8'h11, 16'hA101, 16'hB101);
        accept_current_pair();
        if (level_o != LEVEL_ONE)
            $fatal(1, "Matched pair was not queued");
        expect_head(16'hA101, 16'hB101, "raw payload preservation");

        // Downstream consumes the queued transaction.
        @(negedge clk_i);
        txn_ready_i = 1'b1;
        @(posedge clk_i);
        #1;
        txn_ready_i = 1'b0;
        if (!empty_o || txn_valid_o)
            $fatal(1, "Downstream transaction was not removed");

        // Request-valid disagreement must be detected and neither side granted.
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b0;
        #1;
        if (!request_mismatch_o || payload_mismatch_o || !mismatch_o ||
            gnt_a_o || gnt_b_o)
            $fatal(1, "Request-valid mismatch was not safely rejected");
        @(posedge clk_i);
        #1;
        clear_requests();
        if (!empty_o)
            $fatal(1, "Request mismatch unexpectedly enqueued a transaction");

        // Payload mismatch must be detected and neither side granted.
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 8'h21;
        compare_payload_b_i = 8'h22;
        payload_a_i = 16'hA202;
        payload_b_i = 16'hB202;
        #1;
        if (request_mismatch_o || !payload_mismatch_o || !mismatch_o ||
            gnt_a_o || gnt_b_o)
            $fatal(1, "Payload mismatch was not safely rejected");
        @(posedge clk_i);
        #1;
        clear_requests();
        if (!empty_o)
            $fatal(1, "Payload mismatch unexpectedly enqueued a transaction");

        // Fill the queue with two matched transactions.
        drive_matched(8'h31, 16'hA301, 16'hB301);
        accept_current_pair();
        drive_matched(8'h32, 16'hA302, 16'hB302);
        accept_current_pair();
        if (!full_o || level_o != DEPTH_LEVEL)
            $fatal(1, "Queue did not become full");
        expect_head(16'hA301, 16'hB301, "full queue head");

        // Full queue backpressures a new matched request if downstream stalls.
        drive_matched(8'h33, 16'hA303, 16'hB303);
        if (mismatch_o || gnt_a_o || gnt_b_o)
            $fatal(1, "Full queue failed to backpressure matched request");

        // When downstream is ready, dequeue and enqueue can occur together.
        txn_ready_i = 1'b1;
        #1;
        if (!gnt_a_o || !gnt_b_o)
            $fatal(1, "Full queue did not permit simultaneous drain/refill");
        @(posedge clk_i);
        #1;
        clear_requests();
        txn_ready_i = 1'b0;
        if (!full_o || level_o != DEPTH_LEVEL)
            $fatal(1, "Occupancy changed during simultaneous drain/refill");
        expect_head(16'hA302, 16'hB302, "second entry after refill");

        // Drain second and replacement entries in order.
        @(negedge clk_i);
        txn_ready_i = 1'b1;
        @(posedge clk_i);
        #1;
        txn_ready_i = 1'b0;
        expect_head(16'hA303, 16'hB303, "replacement entry");
        @(negedge clk_i);
        txn_ready_i = 1'b1;
        @(posedge clk_i);
        #1;
        txn_ready_i = 1'b0;
        if (!empty_o || txn_valid_o)
            $fatal(1, "Queue did not drain completely");

        // Flush masks a queued transaction immediately and clears it on edge.
        drive_matched(8'h44, 16'hA404, 16'hB404);
        accept_current_pair();
        expect_head(16'hA404, 16'hB404, "pre-flush entry");
        @(negedge clk_i);
        flush_i = 1'b1;
        #1;
        if (txn_valid_o || gnt_a_o || gnt_b_o)
            $fatal(1, "Flush did not suppress transaction visibility/admission");
        @(posedge clk_i);
        #1;
        flush_i = 1'b0;
        if (!empty_o || txn_valid_o)
            $fatal(1, "Flush did not clear queued transaction");

        // Fault-containment policy: a transaction admitted in an earlier cycle
        // is already authorized. It may complete on the edge that captures a
        // newly observed mismatch. The mismatch rejects new admissions. Once
        // the registered safe-state/flush request becomes active after that
        // edge, remaining queued entries are masked and then discarded.
        drive_matched(8'h51, 16'hA501, 16'hB501);
        accept_current_pair();
        drive_matched(8'h52, 16'hA502, 16'hB502);
        accept_current_pair();
        if (!full_o || level_o != DEPTH_LEVEL)
            $fatal(1, "Fault-policy setup did not fill queue");

        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b0;
        txn_ready_i = 1'b1;
        #1;
        if (!request_mismatch_o || !mismatch_o || gnt_a_o || gnt_b_o ||
            !txn_valid_o || txn_payload_a_o !== 16'hA501 ||
            txn_payload_b_o !== 16'hB501)
            $fatal(1, "Mismatch did not block admission while preserving prior authorized head");

        @(posedge clk_i);
        #1;
        txn_ready_i = 1'b0;
        if (level_o != LEVEL_ONE || txn_payload_a_o !== 16'hA502 ||
            txn_payload_b_o !== 16'hB502)
            $fatal(1, "Previously authorized head did not complete exactly once");

        // Model the fault manager's registered safe-state request becoming
        // active after the mismatch-capture edge.
        flush_i = 1'b1;
        #1;
        if (txn_valid_o || gnt_a_o || gnt_b_o)
            $fatal(1, "Registered fault flush did not mask remaining queued work");
        @(posedge clk_i);
        #1;
        flush_i = 1'b0;
        clear_requests();
        if (!empty_o || txn_valid_o || level_o != LEVEL_ZERO)
            $fatal(1, "Registered fault flush did not discard remaining transaction");

        $display("DCLS PAIRED TRANSACTION STAGE PASS");
        $display("Matched admission, paired grants, mismatch rejection, backpressure,");
        $display("simultaneous drain/refill, raw payload preservation and flush verified");
        $display("Previously authorized completion and post-fault queue flush verified");
        $finish;
    end
endmodule

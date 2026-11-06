`timescale 1ns/1ps

module dcls_paired_transaction_fifo_tb;
    localparam integer WIDTH = 16;
    localparam integer DEPTH = 2;
    localparam integer LEVEL_WIDTH = $clog2(DEPTH+1);
    localparam [LEVEL_WIDTH-1:0] LEVEL_ZERO = 0;
    localparam [LEVEL_WIDTH-1:0] LEVEL_ONE = 1;
    localparam [LEVEL_WIDTH-1:0] DEPTH_LEVEL = DEPTH[LEVEL_WIDTH-1:0];

    logic clk_i = 1'b0;
    logic rst_ni = 1'b0;
    logic flush_i = 1'b0;
    logic push_i = 1'b0;
    logic [WIDTH-1:0] payload_a_i = '0;
    logic [WIDTH-1:0] payload_b_i = '0;
    wire push_ready_o;
    wire push_accepted_o;
    wire out_valid_o;
    logic out_ready_i = 1'b0;
    wire [WIDTH-1:0] payload_a_o;
    wire [WIDTH-1:0] payload_b_o;
    wire full_o;
    wire empty_o;
    wire [LEVEL_WIDTH-1:0] level_o;

    always #5 clk_i <= ~clk_i;

    dcls_paired_transaction_fifo #(
        .PayloadWidth(WIDTH),
        .Depth(DEPTH)
    ) dut (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .push_i(push_i),
        .payload_a_i(payload_a_i),
        .payload_b_i(payload_b_i),
        .push_ready_o(push_ready_o),
        .push_accepted_o(push_accepted_o),
        .out_valid_o(out_valid_o),
        .out_ready_i(out_ready_i),
        .payload_a_o(payload_a_o),
        .payload_b_o(payload_b_o),
        .full_o(full_o),
        .empty_o(empty_o),
        .level_o(level_o)
    );

    task automatic drive_push(input logic [WIDTH-1:0] a,
                              input logic [WIDTH-1:0] b);
        begin
            @(negedge clk_i);
            push_i = 1'b1;
            payload_a_i = a;
            payload_b_i = b;
            #1;
        end
    endtask

    task automatic finish_edge;
        begin
            @(posedge clk_i);
            #1;
            push_i = 1'b0;
        end
    endtask

    task automatic expect_head(input logic [WIDTH-1:0] a,
                               input logic [WIDTH-1:0] b,
                               input string label_text);
        begin
            if (!out_valid_o || payload_a_o !== a || payload_b_o !== b) begin
                $error("%s: expected valid A=%h B=%h, got valid=%b A=%h B=%h",
                       label_text, a, b, out_valid_o, payload_a_o, payload_b_o);
                $fatal(1);
            end
        end
    endtask

    initial begin
        // Reset and empty-state checks.
        repeat (2) @(posedge clk_i);
        @(negedge clk_i);
        rst_ni = 1'b1;
        #1;
        if (!empty_o || full_o || out_valid_o || level_o != LEVEL_ZERO || !push_ready_o)
            $fatal(1, "Reset/empty-state check failed");

        // First paired entry.
        drive_push(16'hA101, 16'hB101);
        if (!push_accepted_o) $fatal(1, "First push was not accepted");
        finish_edge();
        if (level_o != LEVEL_ONE || empty_o || full_o)
            $fatal(1, "Occupancy after first push is incorrect");
        expect_head(16'hA101, 16'hB101, "first entry");

        // Second entry fills the FIFO.
        drive_push(16'hA202, 16'hB202);
        if (!push_accepted_o) $fatal(1, "Second push was not accepted");
        finish_edge();
        if (!full_o || level_o != DEPTH_LEVEL)
            $fatal(1, "FIFO did not report full at depth");
        expect_head(16'hA101, 16'hB101, "head while full");

        // A third entry must stall while the FIFO is full and not draining.
        drive_push(16'hA303, 16'hB303);
        if (push_ready_o || push_accepted_o)
            $fatal(1, "Full FIFO accepted a push without a simultaneous pop");
        push_i = 1'b0;
        @(posedge clk_i);
        #1;
        expect_head(16'hA101, 16'hB101, "head after rejected push");

        // Full FIFO can pop and accept a replacement on the same edge.
        @(negedge clk_i);
        out_ready_i = 1'b1;
        push_i = 1'b1;
        payload_a_i = 16'hA303;
        payload_b_i = 16'hB303;
        #1;
        if (!push_ready_o || !push_accepted_o || !out_valid_o)
            $fatal(1, "Simultaneous pop/push was not enabled when full");
        @(posedge clk_i);
        #1;
        push_i = 1'b0;
        out_ready_i = 1'b0;
        if (level_o != DEPTH_LEVEL)
            $fatal(1, "Occupancy changed during simultaneous pop/push");
        expect_head(16'hA202, 16'hB202, "second entry after replacement");

        // Drain the remaining entries in FIFO order.
        @(negedge clk_i);
        out_ready_i = 1'b1;
        @(posedge clk_i);
        #1;
        out_ready_i = 1'b0;
        expect_head(16'hA303, 16'hB303, "replacement entry");

        @(negedge clk_i);
        out_ready_i = 1'b1;
        @(posedge clk_i);
        #1;
        out_ready_i = 1'b0;
        if (!empty_o || out_valid_o || level_o != LEVEL_ZERO)
            $fatal(1, "FIFO did not become empty after draining");

        // Flush immediately masks output and clears queued entries at the edge.
        drive_push(16'hA404, 16'hB404);
        if (!push_accepted_o) $fatal(1, "Flush test setup push failed");
        finish_edge();
        expect_head(16'hA404, 16'hB404, "pre-flush entry");
        @(negedge clk_i);
        flush_i = 1'b1;
        #1;
        if (out_valid_o || push_ready_o || push_accepted_o)
            $fatal(1, "Flush did not immediately block visible FIFO activity");
        @(posedge clk_i);
        #1;
        flush_i = 1'b0;
        if (!empty_o || out_valid_o || level_o != LEVEL_ZERO)
            $fatal(1, "Flush did not clear FIFO state");

        $display("DCLS PAIRED TRANSACTION FIFO PASS");
        $display("Reset, ordering, full stall, simultaneous drain/refill and flush verified");
        $finish;
    end
endmodule

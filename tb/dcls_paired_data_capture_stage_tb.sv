`timescale 1ns/1ps

module dcls_paired_data_capture_stage_tb;
    localparam integer PAYLOAD_WIDTH = 69;
    localparam integer COMPARE_WIDTH = 69;

    logic clk_i = 1'b0;
    logic rst_ni = 1'b0;
    logic stage_enable_i = 1'b0;
    logic flush_i = 1'b0;
    logic commit_ready_i = 1'b1;
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
    wire commit_valid_o;
    wire [PAYLOAD_WIDTH-1:0] commit_payload_a_o;
    wire [PAYLOAD_WIDTH-1:0] commit_payload_b_o;
    wire bypass_o;
    wire busy_o;
    wire fault_latched_o;

    integer commit_count = 0;

    always #5 clk_i <= ~clk_i;

    dcls_paired_data_capture_stage #(
        .PayloadWidth (PAYLOAD_WIDTH),
        .CompareWidth (COMPARE_WIDTH)
    ) dut (
        .clk_i                  (clk_i),
        .rst_ni                 (rst_ni),
        .stage_enable_i         (stage_enable_i),
        .flush_i                (flush_i),
        .commit_ready_i         (commit_ready_i),
        .req_a_i                (req_a_i),
        .req_b_i                (req_b_i),
        .compare_payload_a_i    (compare_payload_a_i),
        .compare_payload_b_i    (compare_payload_b_i),
        .payload_a_i            (payload_a_i),
        .payload_b_i            (payload_b_i),
        .gnt_a_o                (gnt_a_o),
        .gnt_b_o                (gnt_b_o),
        .request_mismatch_o     (request_mismatch_o),
        .payload_mismatch_o     (payload_mismatch_o),
        .mismatch_o             (mismatch_o),
        .commit_valid_o         (commit_valid_o),
        .commit_payload_a_o     (commit_payload_a_o),
        .commit_payload_b_o     (commit_payload_b_o),
        .bypass_o               (bypass_o),
        .busy_o                 (busy_o),
        .fault_latched_o        (fault_latched_o)
    );

    always @(posedge clk_i) begin
    // A committed transaction must still correspond to the live
    // processor requests and payloads at the grant-acceptance edge.
    if (commit_valid_o) begin

        if (req_a_i !== 1'b1 ||
            req_b_i !== 1'b1 ||
            payload_a_i !== commit_payload_a_o ||
            payload_b_i !== commit_payload_b_o) begin

            $fatal(
                1,
                "DATA TRANSACTION STABILITY FAILURE: req_a=%b req_b=%b payload_a=%h committed_a=%h payload_b=%h committed_b=%h",
                req_a_i,
                req_b_i,
                payload_a_i,
                commit_payload_a_o,
                payload_b_i,
                commit_payload_b_o
            );
        end

        commit_count <= commit_count + 1;
    end
end

    task automatic reset_stage;
        begin
            @(negedge clk_i);
            rst_ni = 1'b0;
            stage_enable_i = 1'b0;
            flush_i = 1'b0;
            commit_ready_i = 1'b1;
            req_a_i = 1'b0;
            req_b_i = 1'b0;
            compare_payload_a_i = '0;
            compare_payload_b_i = '0;
            payload_a_i = '0;
            payload_b_i = '0;
            repeat (2) @(posedge clk_i);
            @(negedge clk_i);
            rst_ni = 1'b1;
            #1;
        end
    endtask

    initial begin
        reset_stage();

        // Basic-profile path is selected only while the stage is idle.
        if (!bypass_o || gnt_a_o || gnt_b_o || commit_valid_o)
            $fatal(1, "Basic-profile bypass indication failed");

        // Matched request: first edge captures only; second phase grants and
        // commits the registered payloads together.
        @(negedge clk_i);
        stage_enable_i = 1'b1;
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 69'h1_1234_5678_9ABC_DEF01;
        compare_payload_b_i = 69'h1_1234_5678_9ABC_DEF01;
        payload_a_i = 69'h0_1111_2222_3333_4444;
        payload_b_i = 69'h0_1111_2222_3333_4444;
        #1;
        if (gnt_a_o || gnt_b_o || commit_valid_o || busy_o)
            $fatal(1, "Request was granted before registered comparison");

        @(posedge clk_i);
        #1;
        if (!busy_o || !gnt_a_o || !gnt_b_o || !commit_valid_o)
            $fatal(1, "Matched registered transaction was not authorized");
        if (commit_payload_a_o !== 69'h0_1111_2222_3333_4444 ||
            commit_payload_b_o !== 69'h0_1111_2222_3333_4444)
            $fatal(1, "Committed payload did not come from capture registers");

        @(posedge clk_i);
        #1;
        if (busy_o || gnt_a_o || gnt_b_o || commit_valid_o || commit_count != 1)
            $fatal(1, "Matched transaction did not complete exactly once");

        // Payload mismatch is detected from the registered comparison
        // signatures. It must block both grants and the RAM commit.
        reset_stage();
        stage_enable_i = 1'b1;
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 69'h0000_0000_0000_00001;
        compare_payload_b_i = 69'h0000_0000_0000_00002;
        payload_a_i = 69'h0000_0000_0000_00011;
        payload_b_i = 69'h0000_0000_0000_00022;
        @(posedge clk_i);
        #1;
        if (!payload_mismatch_o || !mismatch_o ||
            gnt_a_o || gnt_b_o || commit_valid_o)
            $fatal(1, "Registered payload mismatch was not contained");
        @(posedge clk_i);
        #1;
        if (!fault_latched_o || gnt_a_o || gnt_b_o || commit_valid_o ||
            commit_count != 1)
            $fatal(1, "Payload mismatch did not latch fault without commit");

        // Request-valid disagreement is detected before capture and cannot
        // grant either processor.
        reset_stage();
        stage_enable_i = 1'b1;
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b0;
        #1;
        if (!request_mismatch_o || !mismatch_o ||
            gnt_a_o || gnt_b_o || commit_valid_o)
            $fatal(1, "Request-valid mismatch was not detected");
        @(posedge clk_i);
        #1;
        if (!fault_latched_o || gnt_a_o || gnt_b_o || commit_valid_o)
            $fatal(1, "Request-valid mismatch did not fail closed");

        // External flush while a matched request is captured must suppress
        // the otherwise eligible commit.
        reset_stage();
        stage_enable_i = 1'b1;
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 69'h123;
        compare_payload_b_i = 69'h123;
        payload_a_i = 69'h456;
        payload_b_i = 69'h456;
        @(posedge clk_i);
        #1;
        if (!commit_valid_o)
            $fatal(1, "Matched request was not ready before flush test");
        flush_i = 1'b1;
        #1;
        if (gnt_a_o || gnt_b_o || commit_valid_o)
            $fatal(1, "External flush did not immediately suppress commit");
        @(posedge clk_i);
        #1;
        if (commit_count != 1 || fault_latched_o)
            $fatal(1, "External flush caused a commit or false DCLS fault");

        // Disabling DCLS during a pending transaction must not bypass the
        // captured request; that transaction completes through the stage.
        reset_stage();
        stage_enable_i = 1'b1;
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 69'h789;
        compare_payload_b_i = 69'h789;
        payload_a_i = 69'hABC;
        payload_b_i = 69'hABC;
        @(posedge clk_i);
        #1;
        stage_enable_i = 1'b0;
        if (bypass_o || !commit_valid_o || !gnt_a_o || !gnt_b_o)
            $fatal(1, "Pending transaction incorrectly switched to bypass");
        @(posedge clk_i);
        #1;
        if (!bypass_o || busy_o || commit_count != 2)
            $fatal(1, "Stage did not return to Basic-profile bypass after drain");

        // Downstream backpressure must hold the captured transaction in
        // CHECK without granting either core or committing the RAM payload.
        reset_stage();
        stage_enable_i = 1'b1;
        commit_ready_i = 1'b0;
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 69'h111;
        compare_payload_b_i = 69'h111;
        payload_a_i = 69'h222;
        payload_b_i = 69'h222;
        @(posedge clk_i);
        #1;
        if (!busy_o || commit_valid_o || gnt_a_o || gnt_b_o ||
            fault_latched_o)
            $fatal(1, "Downstream backpressure did not retain the captured transaction");

        repeat (2) begin
            @(posedge clk_i);
            #1;
            if (!busy_o || commit_valid_o || gnt_a_o || gnt_b_o ||
                payload_a_i !== commit_payload_a_o ||
                payload_b_i !== commit_payload_b_o)
                $fatal(1, "Captured transaction was not held during downstream backpressure");
        end

        @(negedge clk_i);
        commit_ready_i = 1'b1;
        #1;
        if (!busy_o || !commit_valid_o || !gnt_a_o || !gnt_b_o)
            $fatal(1, "Captured transaction did not resume when downstream became ready");
        @(posedge clk_i);
        #1;
        if (busy_o || commit_valid_o || commit_count != 3)
            $fatal(1, "Backpressured transaction did not commit exactly once");

        // Independently perturb one live payload after capture. The stage
        // must detect the violation and suppress the pending commit.
        reset_stage();
        stage_enable_i = 1'b1;
        @(negedge clk_i);
        req_a_i = 1'b1;
        req_b_i = 1'b1;
        compare_payload_a_i = 69'h333;
        compare_payload_b_i = 69'h333;
        payload_a_i = 69'h444;
        payload_b_i = 69'h444;
        @(posedge clk_i);
        #1;
        if (!busy_o || !commit_valid_o)
            $fatal(1, "Stability-fault test failed to capture a matched transaction");
        @(negedge clk_i);
        payload_a_i = 69'h445;
        #1;
        if (!payload_mismatch_o || !mismatch_o ||
            commit_valid_o || gnt_a_o || gnt_b_o)
            $fatal(1, "Live payload change was not detected before paired commit");
        @(posedge clk_i);
        #1;
        if (!fault_latched_o || commit_valid_o || gnt_a_o || gnt_b_o ||
            commit_count != 3)
            $fatal(1, "Payload-stability violation did not fail closed");

        $display("DCLS PAIRED DATA CAPTURE STAGE PASS");
        $display("Capture-before-compare, paired grants, registered payload commit,");
        $display("mismatch rejection, request-valid fault, flush and profile transition verified");
        $finish;
    end
endmodule

`timescale 1ns/1ps

// Paired transaction FIFO for a redundant two-channel safety architecture.
//
// This block stores two already-qualified payloads as one lockstep transaction.
// Request comparison and fault reporting are intentionally outside this module.
// A push is accepted only when space is available (or a pop occurs concurrently).
// A queued transaction is presented at the output until out_ready_i is asserted.
//
// flush_i masks the output immediately and clears all queued entries at the next
// rising edge. It must be driven by the system's safety-abort/flush policy.
// Payload storage is not reset; out_valid_o is reset, so stale payloads are inert.

module dcls_paired_transaction_fifo #(
    parameter integer PayloadWidth = 72,
    parameter integer Depth = 2
) (
    input  wire                     clk_i,
    input  wire                     rst_ni,
    input  wire                     flush_i,

    input  wire                     push_i,
    input  wire [PayloadWidth-1:0]  payload_a_i,
    input  wire [PayloadWidth-1:0]  payload_b_i,
    output wire                     push_ready_o,
    output wire                     push_accepted_o,

    output wire                     out_valid_o,
    input  wire                     out_ready_i,
    output wire [PayloadWidth-1:0]  payload_a_o,
    output wire [PayloadWidth-1:0]  payload_b_o,

    output wire                     full_o,
    output wire                     empty_o,
    output wire [((Depth < 1) ? 1 : $clog2(Depth+1))-1:0] level_o
);

    localparam integer PtrWidth = (Depth <= 1) ? 1 : $clog2(Depth);
    localparam integer CountWidth = (Depth < 1) ? 1 : $clog2(Depth+1);

    // Explicit part-selects size integer parameters to the counter/pointer widths.
    localparam integer LAST_PTR_INTEGER = Depth - 1;
    localparam [PtrWidth-1:0] LAST_PTR = LAST_PTR_INTEGER[PtrWidth-1:0];
    localparam [CountWidth-1:0] DEPTH_COUNT = Depth[CountWidth-1:0];

    reg [PayloadWidth-1:0] payload_a_mem [0:Depth-1];
    reg [PayloadWidth-1:0] payload_b_mem [0:Depth-1];
    reg [PtrWidth-1:0] read_ptr_q;
    reg [PtrWidth-1:0] write_ptr_q;
    reg [CountWidth-1:0] count_q;

    wire pop_fire;
    wire push_fire;

    assign empty_o = (count_q == {CountWidth{1'b0}});
    assign full_o  = (count_q == DEPTH_COUNT);

    // Mask the head immediately when a safety flush is requested.
    assign out_valid_o = !empty_o && !flush_i;
    assign pop_fire = out_valid_o && out_ready_i;

    // Permit a push into a full FIFO when its current head is popped on the
    // same edge. This provides simultaneous drain/refill operation.
    assign push_ready_o = !flush_i && (!full_o || pop_fire);
    assign push_fire = push_i && push_ready_o;
    assign push_accepted_o = push_fire;

    assign payload_a_o = payload_a_mem[read_ptr_q];
    assign payload_b_o = payload_b_mem[read_ptr_q];
    assign level_o = count_q;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            read_ptr_q  <= {PtrWidth{1'b0}};
            write_ptr_q <= {PtrWidth{1'b0}};
            count_q     <= {CountWidth{1'b0}};
        end else if (flush_i) begin
            read_ptr_q  <= {PtrWidth{1'b0}};
            write_ptr_q <= {PtrWidth{1'b0}};
            count_q     <= {CountWidth{1'b0}};
        end else begin
            if (push_fire) begin
                payload_a_mem[write_ptr_q] <= payload_a_i;
                payload_b_mem[write_ptr_q] <= payload_b_i;
                if (write_ptr_q == LAST_PTR)
                    write_ptr_q <= {PtrWidth{1'b0}};
                else
                    write_ptr_q <= write_ptr_q + 1'b1;
            end

            if (pop_fire) begin
                if (read_ptr_q == LAST_PTR)
                    read_ptr_q <= {PtrWidth{1'b0}};
                else
                    read_ptr_q <= read_ptr_q + 1'b1;
            end

            case ({push_fire, pop_fire})
                2'b10: count_q <= count_q + 1'b1;
                2'b01: count_q <= count_q - 1'b1;
                default: count_q <= count_q;
            endcase
        end
    end

endmodule

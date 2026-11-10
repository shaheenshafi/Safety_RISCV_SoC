// -----------------------------------------------------------------------------
// Arty A7-100T clock generator
//
// Physical input : 100 MHz onboard oscillator (E3)
// Generated clock: 50 MHz
// Clock primitive : Artix-7 MMCME2_BASE
//
// MMCM configuration:
//   FIN = 100 MHz
//   DIVCLK_DIVIDE = 1
//   CLKFBOUT_MULT_F = 10
//   CLKOUT0_DIVIDE_F = 20
//   FVCO = 1000 MHz
//   FOUT = 50 MHz
//
// Reset:
//   reset_n is active-low.
//   MMCM reset is asserted while external reset is active.
//   Generated-domain reset asserts asynchronously on external reset
//   or loss of MMCM lock, and deasserts synchronously.
//
// RTL language: Verilog
// -----------------------------------------------------------------------------

module arty_a7_clock_50mhz (
    input  wire clk_100mhz,
    input  wire reset_n,
    output wire clk_50mhz,
    output wire reset_50mhz_n
);

    wire clk_100mhz_buf;
    wire clk_feedback_unbuf;
    wire clk_feedback_buf;
    wire clk_50mhz_unbuf;
    wire mmcm_locked;

    // Buffer the physical board oscillator input.
    IBUF u_clock_input_ibuf (
        .I(clk_100mhz),
        .O(clk_100mhz_buf)
    );

    // Generate a 50 MHz clock from the physical 100 MHz oscillator.
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F   (10.0),
        .CLKFBOUT_PHASE    (0.0),
        .CLKIN1_PERIOD     (10.0),
        .DIVCLK_DIVIDE     (1),
        .CLKOUT0_DIVIDE_F  (20.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE     (0.0),
        .STARTUP_WAIT      ("FALSE")
    ) u_system_mmcm (
        .CLKIN1   (clk_100mhz_buf),
        .CLKFBIN  (clk_feedback_buf),
        .RST      (~reset_n),
        .PWRDWN   (1'b0),
        .CLKFBOUT (clk_feedback_unbuf),
        .CLKOUT0  (clk_50mhz_unbuf),
        .LOCKED   (mmcm_locked)
    );

    // Global feedback and generated-clock distribution.
    BUFG u_mmcm_feedback_bufg (
        .I(clk_feedback_unbuf),
        .O(clk_feedback_buf)
    );

    BUFG u_system_clock_bufg (
        .I(clk_50mhz_unbuf),
        .O(clk_50mhz)
    );

    // Asynchronously assert reset on external reset or loss of MMCM lock.
    // Deassert reset synchronously to the generated 50 MHz clock.
    wire reset_async_n;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;

    assign reset_async_n = reset_n & mmcm_locked;

    always @(posedge clk_50mhz or negedge reset_async_n) begin
        if (!reset_async_n)
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    assign reset_50mhz_n = reset_sync[1];

endmodule

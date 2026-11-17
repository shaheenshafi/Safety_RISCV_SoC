// -----------------------------------------------------------------------------
// Arty A7-100T clock generator
//
// Physical input : 100 MHz onboard oscillator (E3)
// Generated clock: 40 MHz system clock
// Clock primitive : Artix-7 MMCME2_BASE
//
// MMCM configuration:
//   FIN = 100 MHz
//   DIVCLK_DIVIDE = 1
//   CLKFBOUT_MULT_F = 10
//   CLKOUT0_DIVIDE_F = 25
//   FVCO = 1000 MHz
//   FOUT = 40 MHz
//
// The system clock was 50 MHz in earlier builds. The longest path of the
// dual-core design (decode -> ALU -> branch -> cross-core comparison -> data
// grant) needs about 20 ns, so 50 MHz was met by only 0.03 to 0.25 ns.
// 40 MHz gives a robust margin.
//
// Reset:
//   reset_n is active-low.
//   MMCM reset is asserted while external reset is active.
//   Generated-domain reset asserts asynchronously on external reset
//   or loss of MMCM lock, and deasserts synchronously.
// -----------------------------------------------------------------------------

module arty_a7_clock_gen (
    input  wire clk_100mhz,
    input  wire reset_n,
    output wire clk_sys,
    output wire reset_sys_n
);

    wire clk_100mhz_buf;
    wire clk_feedback_unbuf;
    wire clk_feedback_buf;
    wire clk_sys_unbuf;
    wire mmcm_locked;

    // Buffer the physical board oscillator input.
    IBUF u_clock_input_ibuf (
        .I(clk_100mhz),
        .O(clk_100mhz_buf)
    );

    // Generate the 40 MHz system clock from the physical 100 MHz oscillator.
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F   (10.0),
        .CLKFBOUT_PHASE    (0.0),
        .CLKIN1_PERIOD     (10.0),
        .DIVCLK_DIVIDE     (1),
        .CLKOUT0_DIVIDE_F  (25.0),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE     (0.0),
        .STARTUP_WAIT      ("FALSE")
    ) u_system_mmcm (
        .CLKIN1   (clk_100mhz_buf),
        .CLKFBIN  (clk_feedback_buf),
        .RST      (~reset_n),
        .PWRDWN   (1'b0),
        .CLKFBOUT (clk_feedback_unbuf),
        .CLKOUT0  (clk_sys_unbuf),
        .LOCKED   (mmcm_locked)
    );

    // Global feedback and generated-clock distribution.
    BUFG u_mmcm_feedback_bufg (
        .I(clk_feedback_unbuf),
        .O(clk_feedback_buf)
    );

    BUFG u_system_clock_bufg (
        .I(clk_sys_unbuf),
        .O(clk_sys)
    );

    // Asynchronously assert reset on external reset or loss of MMCM lock.
    // Deassert reset synchronously to the generated system clock.
    wire reset_async_n;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;

    assign reset_async_n = reset_n & mmcm_locked;

    always @(posedge clk_sys or negedge reset_async_n) begin
        if (!reset_async_n)
            reset_sync <= 2'b00;
        else
            reset_sync <= {reset_sync[0], 1'b1};
    end

    assign reset_sys_n = reset_sync[1];

endmodule

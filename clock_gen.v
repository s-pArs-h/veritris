`timescale 1ns / 1ps

// 25 MHz pixel clock from the 100 MHz board clock, using the MMCM.
//
// The earlier design divided the clock with fabric flip-flops. A clock made
// that way is not on a global clock buffer, has extra skew, and confuses
// timing analysis; the MMCM output goes through a BUFG like any real clock.
// 25.000 MHz is within the tolerance monitors accept for 640x480 @ 60 Hz
// (nominally 25.175 MHz).
//
// With SIM defined the input clock is passed straight through and the
// testbench drives it at 25 MHz.
module clock_gen (
    input  wire clk_100,
    output wire clk_25,
    output wire locked
);
`ifdef SIM
    assign clk_25 = clk_100;
    assign locked = 1'b1;
`else
    wire clk_mmcm, clk_fb, clk_fb_buf;
    MMCME2_BASE #(
        .CLKIN1_PERIOD    (10.0),
        .CLKFBOUT_MULT_F  (10.0),      // VCO = 1000 MHz
        .CLKOUT0_DIVIDE_F (40.0)       // 25 MHz
    ) u_mmcm (
        .CLKIN1(clk_100), .CLKFBIN(clk_fb_buf), .CLKFBOUT(clk_fb),
        .CLKOUT0(clk_mmcm), .LOCKED(locked), .PWRDWN(1'b0), .RST(1'b0),
        .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(), .CLKOUT2(), .CLKOUT2B(),
        .CLKOUT3(), .CLKOUT3B(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .CLKFBOUTB()
    );
    BUFG u_bufg_fb  (.I(clk_fb),   .O(clk_fb_buf));
    BUFG u_bufg_clk (.I(clk_mmcm), .O(clk_25));
`endif
endmodule

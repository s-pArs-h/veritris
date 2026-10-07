`timescale 1ns / 1ps

// Veritris top level for the Digilent Nexys A7.
//
//   BTNC        reset (also restarts after game over)
//   BTNL/BTNR   move left / right
//   BTNU        rotate; any of L/R/U starts the game
//   VGA         640x480 @ 60 Hz
//   7-segment   lines cleared (BCD score)
module nexys_tetris_top #(
    parameter [26:0] GRAVITY_TICKS = 27'd25_000_000,   // one row per second at 25 MHz
    parameter [19:0] DEBOUNCE      = 20'd1_000_000     // 40 ms
) (
    input  wire       CLK100MHZ,
    input  wire       BTNC, BTNL, BTNR, BTNU,
    output wire       VGA_HS, VGA_VS,
    output wire [3:0] VGA_R, VGA_G, VGA_B,
    output wire [7:0] AN,
    output wire [6:0] SEG,
    output wire       DP
);
    wire clk_25, locked, rst;
    clock_gen  u_clk (.clk_100(CLK100MHZ), .clk_25(clk_25), .locked(locked));
    reset_sync u_rst (.clk(clk_25), .rst_in(BTNC || !locked), .rst_out(rst));

    wire p_l, p_r, p_u;
    debouncer #(.COUNT(DEBOUNCE)) dL (.clk(clk_25), .btn_in(BTNL), .btn_pulse(p_l));
    debouncer #(.COUNT(DEBOUNCE)) dR (.clk(clk_25), .btn_in(BTNR), .btn_pulse(p_r));
    debouncer #(.COUNT(DEBOUNCE)) dU (.clk(clk_25), .btn_in(BTNU), .btn_pulse(p_u));

    // gravity: one tick every GRAVITY_TICKS cycles
    reg [26:0] grav_cnt;
    always @(posedge clk_25 or posedge rst) begin
        if (rst) grav_cnt <= 27'd0;
        else     grav_cnt <= (grav_cnt == GRAVITY_TICKS - 1'b1) ? 27'd0 : grav_cnt + 1'b1;
    end
    wire gravity_tick = (grav_cnt == GRAVITY_TICKS - 1'b1);

    wire        video_on, video_on_d;
    wire [9:0]  x_pix, y_pix;
    vga_controller v1 (
        .clk_25(clk_25), .reset(rst),
        .hsync(VGA_HS), .vsync(VGA_VS),
        .video_on(video_on), .video_on_d(video_on_d),
        .x_loc(x_pix), .y_loc(y_pix)
    );

    wire [11:0] engine_rgb;
    wire [15:0] current_score;
    tetris_engine engine (
        .clk(clk_25), .reset(rst),
        .btn_l(p_l), .btn_r(p_r), .btn_u(p_u),
        .gravity_tick(gravity_tick),
        .x_loc(x_pix), .y_loc(y_pix),
        .video_on(video_on),
        .rgb_out(engine_rgb),
        .score(current_score)
    );

    seven_seg_driver display (
        .clk(clk_25), .reset(rst),
        .score(current_score),
        .AN(AN), .SEG(SEG)
    );

    // 12-bit colour to the board's 4-bit-per-channel resistor DAC
    assign VGA_R = video_on_d ? engine_rgb[11:8] : 4'h0;
    assign VGA_G = video_on_d ? engine_rgb[7:4]  : 4'h0;
    assign VGA_B = video_on_d ? engine_rgb[3:0]  : 4'h0;
    assign DP    = 1'b1;                            // decimal points off
endmodule

`timescale 1ns / 1ps

// 640x480 @ 60 Hz VGA timing from a 25 MHz pixel clock.
//
// x_loc, y_loc and video_on describe the pixel the renderer is working on
// this cycle. The renderer registers its colour, so the pixel reaches the
// pins one cycle later; hsync, vsync and video_on_d are registered here so
// they arrive on that same cycle (and are glitch-free on the output pins).
module vga_controller (
    input  wire       clk_25,
    input  wire       reset,        // active high
    output reg        hsync,        // active low
    output reg        vsync,        // active low
    output wire       video_on,     // current pixel is visible
    output reg        video_on_d,   // video_on aligned with the renderer output
    output wire [9:0] x_loc,        // 0..799
    output wire [9:0] y_loc         // 0..524
);
    parameter H_ACTIVE = 640, H_FRONT = 16, H_SYNC = 96, H_BACK = 48;
    parameter V_ACTIVE = 480, V_FRONT = 10, V_SYNC = 2,  V_BACK = 33;
    localparam H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;   // 800
    localparam V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;   // 525

    reg [9:0] h_count = 10'd0;
    reg [9:0] v_count = 10'd0;

    always @(posedge clk_25 or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;
            v_count <= (v_count == V_TOTAL - 1) ? 10'd0 : v_count + 1'b1;
        end else begin
            h_count <= h_count + 1'b1;
        end
    end

    assign video_on = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign x_loc    = h_count;
    assign y_loc    = v_count;

    always @(posedge clk_25 or posedge reset) begin
        if (reset) begin
            hsync      <= 1'b1;
            vsync      <= 1'b1;
            video_on_d <= 1'b0;
        end else begin
            hsync      <= ~((h_count >= H_ACTIVE + H_FRONT) && (h_count < H_ACTIVE + H_FRONT + H_SYNC));
            vsync      <= ~((v_count >= V_ACTIVE + V_FRONT) && (v_count < V_ACTIVE + V_FRONT + V_SYNC));
            video_on_d <= video_on;
        end
    end
endmodule

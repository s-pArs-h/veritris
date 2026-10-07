`timescale 1ns / 1ps

// Shows the 4-digit BCD score on the rightmost four digits of the Nexys A7
// seven-segment display, with leading zeros blanked. Digits are multiplexed;
// with a 25 MHz clock each digit is lit for 2^14 cycles (0.66 ms), so the
// whole display refreshes at about 380 Hz. Anodes and segments are active
// low; SEG[0] is segment A and SEG[6] is segment G.
module seven_seg_driver #(
    parameter REFRESH_BITS = 16
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] score,        // four BCD digits
    output reg  [7:0]  AN,
    output reg  [6:0]  SEG
);
    reg [REFRESH_BITS-1:0] refresh;
    always @(posedge clk or posedge reset) begin
        if (reset) refresh <= {REFRESH_BITS{1'b0}};
        else       refresh <= refresh + 1'b1;
    end

    wire [1:0] digit = refresh[REFRESH_BITS-1 -: 2];

    reg [3:0] bcd;
    reg       blank;
    always @(*) begin
        case (digit)
            2'd0:    bcd = score[3:0];
            2'd1:    bcd = score[7:4];
            2'd2:    bcd = score[11:8];
            default: bcd = score[15:12];
        endcase
        blank = (digit == 2'd3 && score[15:12] == 4'd0) ||
                (digit == 2'd2 && score[15:8]  == 8'd0) ||
                (digit == 2'd1 && score[15:4]  == 12'd0);
    end

    // registered outputs, so the pins never see decoder glitches
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            AN  <= 8'hFF;
            SEG <= 7'h7F;
        end else begin
            AN <= ~(8'b0000_0001 << digit);
            if (blank) SEG <= 7'b1111111;
            else case (bcd)            //   gfedcba
                4'd0:    SEG <= 7'b1000000;
                4'd1:    SEG <= 7'b1111001;
                4'd2:    SEG <= 7'b0100100;
                4'd3:    SEG <= 7'b0110000;
                4'd4:    SEG <= 7'b0011001;
                4'd5:    SEG <= 7'b0010010;
                4'd6:    SEG <= 7'b0000010;
                4'd7:    SEG <= 7'b1111000;
                4'd8:    SEG <= 7'b0000000;
                4'd9:    SEG <= 7'b0010000;
                default: SEG <= 7'b1111111;
            endcase
        end
    end
endmodule

`timescale 1ns / 1ps

// Reset synchroniser: asserts immediately (asynchronously) and releases
// synchronously to clk, so every flip-flop leaves reset on the same edge.
module reset_sync (
    input  wire clk,
    input  wire rst_in,     // active high, asynchronous (button, MMCM not locked)
    output wire rst_out     // active high, synchronous release
);
    reg [1:0] r = 2'b11;
    always @(posedge clk or posedge rst_in) begin
        if (rst_in) r <= 2'b11;
        else        r <= {r[0], 1'b0};
    end
    assign rst_out = r[1];
endmodule

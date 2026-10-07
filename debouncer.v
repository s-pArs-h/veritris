`timescale 1ns / 1ps

// Push-button conditioner: two-flop synchroniser (the button is asynchronous
// to the clock), debounce counter, then a one-cycle pulse on each press.
module debouncer #(
    parameter [19:0] COUNT = 20'd1_000_000     // 40 ms at 25 MHz
) (
    input  wire clk,
    input  wire btn_in,
    output reg  btn_pulse = 1'b0
);
    reg [1:0]  sync     = 2'b00;
    reg [19:0] count    = 20'd0;
    reg        btn_reg  = 1'b0;
    reg        btn_prev = 1'b0;

    always @(posedge clk) begin
        sync <= {sync[0], btn_in};

        // accept a new level only after it has been stable for COUNT cycles
        if (sync[1] == btn_reg) begin
            count <= 20'd0;
        end else begin
            count <= count + 1'b1;
            if (count == COUNT) btn_reg <= sync[1];
        end

        btn_prev  <= btn_reg;
        btn_pulse <= btn_reg && !btn_prev;
    end
endmodule

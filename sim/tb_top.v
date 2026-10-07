`timescale 1ns / 1ps

// Veritris system testbench (Icarus Verilog, compile with -DSIM).
//
//   1. VGA timing: hsync every 800 pixels with a 96-pixel pulse, vsync every
//      525 lines with a 2-line pulse.
//   2. Game flow: a button press starts the game, pieces fall under gravity,
//      land, and with no input the stack reaches the top: game over.
//   3. Line clear: after a restart, the bottom row is filled behind the
//      engine's back; when the next piece lands the row must be cleared,
//      the rows above shift down, and the score (and 7-segment digit 0)
//      must show 1.
module tb_top;
    reg clk = 0;
    reg btnc = 1, btnl = 0, btnr = 0, btnu = 0;
    wire hs, vs, dp;
    wire [3:0] r, g, b;
    wire [7:0] an;
    wire [6:0] seg;
    always #20 clk = ~clk;          // 25 MHz (SIM passes it straight through)

    nexys_tetris_top #(.GRAVITY_TICKS(27'd300), .DEBOUNCE(20'd8)) dut (
        .CLK100MHZ(clk), .BTNC(btnc), .BTNL(btnl), .BTNR(btnr), .BTNU(btnu),
        .VGA_HS(hs), .VGA_VS(vs), .VGA_R(r), .VGA_G(g), .VGA_B(b),
        .AN(an), .SEG(seg), .DP(dp)
    );

    integer errors = 0;
    task check(input cond, input [8*64-1:0] msg);
        if (!cond) begin
            $display("FAIL: %0s", msg);
            errors = errors + 1;
        end
    endtask

    // ---------------- VGA timing monitor ----------------
    integer cyc = 0, h_fall = -1, h_period = 0, h_low = 0, h_fall_prev = 0;
    integer v_fall = -1, v_period = 0, v_low_start = 0, v_low = 0;
    reg hs_q = 1, vs_q = 1;
    always @(posedge clk) begin
        cyc = cyc + 1;
        if (hs_q && !hs) begin
            if (h_fall >= 0) h_period = cyc - h_fall;
            h_fall = cyc;
        end
        if (!hs_q && hs) h_low = cyc - h_fall;
        if (vs_q && !vs) begin
            if (v_fall >= 0) v_period = cyc - v_fall;
            v_fall = cyc;
        end
        if (!vs_q && vs) v_low = cyc - v_fall;
        hs_q = hs;
        vs_q = vs;
    end

    // hold a button long enough to pass the debouncer, then release it
    task press(input integer which);   // 0 = left, 1 = right, 2 = up
        begin
            if (which == 0) btnl = 1; else if (which == 1) btnr = 1; else btnu = 1;
            repeat (40) @(posedge clk);
            btnl = 0; btnr = 0; btnu = 0;
            repeat (40) @(posedge clk);
        end
    endtask

    integer c, t;
    reg seen_land;
    initial begin
        repeat (10) @(posedge clk);
        btnc = 0;

        // 1. two full frames for the timing monitor
        repeat (2 * 800 * 525 + 10) @(posedge clk);
        check(h_period == 800, "hsync period is not 800 pixels");
        check(h_low == 96,     "hsync pulse is not 96 pixels");
        check(v_period == 800 * 525, "vsync period is not 525 lines");
        check(v_low == 2 * 800, "vsync pulse is not 2 lines");
        $display("VGA: hsync period %0d, pulse %0d; vsync period %0d lines, pulse %0d lines",
                 h_period, h_low, v_period / 800, v_low / 800);

        // 2. start, let gravity run with no input until game over
        check(dut.engine.state == 0, "not on the start screen after reset");
        press(2);
        check(dut.engine.state != 0, "button press did not start the game");
        seen_land = 0;
        for (t = 0; t < 400000 && dut.engine.state != 7; t = t + 1) begin
            @(posedge clk);
            if (dut.engine.state == 4) seen_land = 1;
        end
        check(seen_land, "no piece ever landed");
        check(dut.engine.state == 7, "game never ended with the stack at the top");
        check(dut.engine.score == 0, "score changed without a line clear");
        $display("Game flow: start -> pieces land -> game over after %0d cycles", t);

        // 3. restart, fill the bottom row, let the next piece land
        btnc = 1; repeat (5) @(posedge clk); btnc = 0; repeat (5) @(posedge clk);
        press(0);
        wait (dut.engine.state == 2);                 // WAIT: a piece is falling
        @(negedge clk);
        for (c = 0; c < 10; c = c + 1) dut.engine.grid[190 + c] = 3'd1;
        dut.engine.grid[180] = 3'd5;                  // marker one row up
        wait (dut.engine.state == 6);                 // LINE_SHIFT: full row found
        wait (dut.engine.state == 1);                 // back to SPAWN
        @(negedge clk);
        check(dut.engine.score == 1, "score did not become 1 after clearing a row");
        check(dut.engine.grid[190] == 3'd5, "rows above did not shift down");
        // 7-segment: wait until digit 0 is selected, expect a '1'
        wait (an == 8'b1111_1110);
        @(posedge clk); @(posedge clk);
        check(seg == 7'b1111001, "7-segment digit 0 does not show 1");
        $display("Line clear: score = %0d, display digit 0 = %b", dut.engine.score, seg);

        if (errors == 0) $display("PASS: all Veritris checks passed");
        else             $display("FAIL: %0d check(s) failed", errors);
        $finish;
    end
endmodule

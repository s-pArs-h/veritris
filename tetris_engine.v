module tetris_engine (
    input clk, reset,
    input btn_l, btn_r, btn_u,
    input gravity_tick,
    input [9:0] x_loc, y_loc,
    input video_on,
    output reg [11:0] rgb_out, // Explicitly 12-bit RGB
    output reg [15:0] score
);
    parameter X_START = 220, Y_START = 40;   // board origin; cells are 20 x 20 px

    (* ram_style = "registers" *) reg [2:0] grid [0:199]; // 1D Array for stability
    
    reg signed [31:0] curr_x, curr_y; 
    reg [1:0] rot_state; 
    
    parameter START_SCREEN=0, SPAWN=1, WAIT=2, CHECK=3, LAND=4, LINE_CHECK=5, LINE_SHIFT=6, GAME_OVER=7;
    reg [2:0] state;

    reg signed [31:0] test_x, test_y;
    reg [1:0] test_rot;
    reg is_downward_move; 
    reg [4:0] scan_row;

    reg [7:0] lfsr;
    reg [2:0] piece_type;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [7:0] lfsr_mod7 = lfsr % 8'd7;     // next piece type, 0..6 (top bits always 0)
    /* verilator lint_on UNUSEDSIGNAL */

    always @(posedge clk or posedge reset) begin
        if (reset) lfsr <= 8'hAA; 
        else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    // 16-Bit Shape Masks
    function [15:0] get_mask;
        input [2:0] p_type;
        input [1:0] r_state;
        begin
            case (p_type)
                3'd0: get_mask = (r_state==0 || r_state==2) ? 16'h0F00 : 16'h2222; // I
                3'd1: get_mask = 16'h0660; // O
                3'd2: begin // T
                    case (r_state)
                        2'd0: get_mask = 16'h0E40; 2'd1: get_mask = 16'h4C40;
                        2'd2: get_mask = 16'h4E00; 2'd3: get_mask = 16'h4640;
                    endcase
                end
                3'd3: get_mask = (r_state==0 || r_state==2) ? 16'h06C0 : 16'h4620; // S
                3'd4: get_mask = (r_state==0 || r_state==2) ? 16'h0C60 : 16'h2640; // Z
                3'd5: begin // J
                    case (r_state)
                        2'd0: get_mask = 16'h0E80; 2'd1: get_mask = 16'hC440;
                        2'd2: get_mask = 16'h2E00; 2'd3: get_mask = 16'h4460;
                    endcase
                end
                3'd6: begin // L
                    case (r_state)
                        2'd0: get_mask = 16'h0E20; 2'd1: get_mask = 16'h44C0;
                        2'd2: get_mask = 16'h8E00; 2'd3: get_mask = 16'h6440;
                    endcase
                end
                default: get_mask = 16'h0660;
            endcase
        end
    endfunction

    // 12-Bit RGB Decoder
    function [11:0] get_rgb;
        input [2:0] id;
        begin
            case(id)
                3'd1: get_rgb = 12'h0FF; // Cyan (I)
                3'd2: get_rgb = 12'hFF0; // Yellow (O)
                3'd3: get_rgb = 12'hB0F; // Purple (T)
                3'd4: get_rgb = 12'h0F0; // Green (S)
                3'd5: get_rgb = 12'hF00; // Red (Z)
                3'd6: get_rgb = 12'h04F; // Blue (J)
                3'd7: get_rgb = 12'hF80; // Orange (L)
                default: get_rgb = 12'h000;
            endcase
        end
    endfunction

    wire [15:0] test_mask = get_mask(piece_type, test_rot);
    wire [15:0] active_mask = get_mask(piece_type, rot_state);
    wire [2:0] piece_id = piece_type + 1; 

    // Collision Logic
    reg [15:0] collision_vector;
    integer i, j, chk_x, chk_y; 

    always @(*) begin
        for (j = 0; j < 4; j = j + 1) begin
            for (i = 0; i < 4; i = i + 1) begin
                chk_x = test_x + i;
                chk_y = test_y + j;
                if (chk_x < 0 || chk_x > 9 || chk_y > 19) begin
                    collision_vector[15 - (j*4 + i)] = 1'b1;
                end else if (chk_y >= 0) begin
                    collision_vector[15 - (j*4 + i)] = (grid[chk_y * 10 + chk_x] != 3'b000);
                end else begin
                    collision_vector[15 - (j*4 + i)] = 1'b0;
                end
            end
        end
    end

    wire collision = |(test_mask & collision_vector);

    wire row_is_full = (grid[scan_row*10 + 0] != 0) && (grid[scan_row*10 + 1] != 0) && 
                       (grid[scan_row*10 + 2] != 0) && (grid[scan_row*10 + 3] != 0) && 
                       (grid[scan_row*10 + 4] != 0) && (grid[scan_row*10 + 5] != 0) && 
                       (grid[scan_row*10 + 6] != 0) && (grid[scan_row*10 + 7] != 0) && 
                       (grid[scan_row*10 + 8] != 0) && (grid[scan_row*10 + 9] != 0);

    // FSM
    integer r, c;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= START_SCREEN; score <= 0;
            for (c = 0; c < 200; c = c + 1) grid[c] <= 3'b000;
        end else begin
            case (state)
                START_SCREEN: if (btn_l || btn_r || btn_u) state <= SPAWN;

                SPAWN: begin
                    curr_x <= 3; curr_y <= -2; 
                    rot_state <= 0; test_rot <= 0; 
                    piece_type <= lfsr_mod7[2:0]; state <= WAIT;
                end
                
                WAIT: begin
                    if (gravity_tick) begin
                        test_x <= curr_x; test_y <= curr_y + 1; test_rot <= rot_state;
                        is_downward_move <= 1'b1; state <= CHECK;
                    end else if (btn_l) begin
                        test_x <= curr_x - 1; test_y <= curr_y; test_rot <= rot_state;
                        is_downward_move <= 1'b0; state <= CHECK;
                    end else if (btn_r) begin
                        test_x <= curr_x + 1; test_y <= curr_y; test_rot <= rot_state;
                        is_downward_move <= 1'b0; state <= CHECK;
                    end else if (btn_u) begin
                        test_x <= curr_x; test_y <= curr_y; test_rot <= rot_state + 1;
                        is_downward_move <= 1'b0; state <= CHECK;
                    end 
                end

                CHECK: begin
                    if (collision) begin
                        if (is_downward_move) begin
                            if (curr_y < 0) state <= GAME_OVER; else state <= LAND;
                        end else state <= WAIT; 
                    end else begin
                        curr_x <= test_x; curr_y <= test_y; rot_state <= test_rot;
                        state <= WAIT;
                    end
                end

                LAND: begin
                    for (r = 0; r < 20; r = r + 1) begin
                        for (c = 0; c < 10; c = c + 1) begin
                            // cell (r, c) inside the piece's 4x4 box?
                            if (c - curr_x >= 0 && c - curr_x < 4 && r - curr_y >= 0 && r - curr_y < 4) begin
                                if (active_mask[15 - ((r - curr_y)*4 + (c - curr_x))]) grid[r * 10 + c] <= piece_id;
                            end
                        end
                    end
                    scan_row <= 19; state <= LINE_CHECK;
                end

                LINE_CHECK: begin
                    if (row_is_full) state <= LINE_SHIFT;
                    else if (scan_row == 0) state <= SPAWN; 
                    else scan_row <= scan_row - 1; 
                end

                LINE_SHIFT: begin
                    if (score[3:0] == 9) begin
                        score[3:0] <= 0;
                        if (score[7:4] == 9) begin
                            score[7:4] <= 0; score[11:8] <= score[11:8] + 1;
                        end else score[7:4] <= score[7:4] + 1;
                    end else score[3:0] <= score[3:0] + 1;

                    for (r = 19; r > 0; r = r - 1) begin
                        if (r <= scan_row) begin
                            for (c = 0; c < 10; c = c + 1) grid[r * 10 + c] <= grid[(r-1) * 10 + c];
                        end
                    end
                    for (c = 0; c < 10; c = c + 1) grid[0 * 10 + c] <= 3'b000;
                    state <= LINE_CHECK; 
                end

                GAME_OVER: state <= GAME_OVER;
            endcase
        end
    end

    wire valid_display = (x_loc >= X_START) && (x_loc < X_START + 200) && 
                         (y_loc >= Y_START) && (y_loc < Y_START + 400);
    
    wire [9:0] x_offset = x_loc - X_START;
    wire [9:0] y_offset = y_loc - Y_START;
    
    wire signed [31:0] sgx = (x_offset >= 180) ? 9 : (x_offset >= 160) ? 8 :
                             (x_offset >= 140) ? 7 : (x_offset >= 120) ? 6 :
                             (x_offset >= 100) ? 5 : (x_offset >= 80)  ? 4 :
                             (x_offset >= 60)  ? 3 : (x_offset >= 40)  ? 2 :
                             (x_offset >= 20)  ? 1 : 0;

    wire signed [31:0] sgy = (y_offset >= 380) ? 19 : (y_offset >= 360) ? 18 :
                             (y_offset >= 340) ? 17 : (y_offset >= 320) ? 16 :
                             (y_offset >= 300) ? 15 : (y_offset >= 280) ? 14 :
                             (y_offset >= 260) ? 13 : (y_offset >= 240) ? 12 :
                             (y_offset >= 220) ? 11 : (y_offset >= 200) ? 10 :
                             (y_offset >= 180) ?  9 : (y_offset >= 160) ?  8 :
                             (y_offset >= 140) ?  7 : (y_offset >= 120) ?  6 :
                             (y_offset >= 100) ?  5 : (y_offset >=  80) ?  4 :
                             (y_offset >=  60) ?  3 : (y_offset >=  40) ?  2 :
                             (y_offset >=  20) ?  1 : 0;
                             
    wire signed [31:0] diff_x = sgx - curr_x;
    wire signed [31:0] diff_y = sgy - curr_y;

    wire in_active_window = (diff_x >= 0 && diff_x < 4 && diff_y >= 0 && diff_y < 4);
    wire is_active_pixel = in_active_window ? active_mask[15 - (diff_y*4 + diff_x)] : 1'b0;

    always @(posedge clk) begin
        if (!video_on) 
            rgb_out <= 12'h000;
        else if (valid_display) begin
            if (is_active_pixel && state != GAME_OVER && state != START_SCREEN) 
                rgb_out <= get_rgb(piece_id);
            else if (grid[sgy * 10 + sgx] != 3'b000) 
                rgb_out <= (state == GAME_OVER) ? 12'hF00 : get_rgb(grid[sgy * 10 + sgx]); 
            else 
                rgb_out <= 12'h222; // Dark Grey board
        end 
        else begin
            if (state == START_SCREEN) rgb_out <= 12'h080; // Dark Green to start
            else if (state == GAME_OVER) rgb_out <= 12'hF00; // Red Game Over
            else rgb_out <= 12'h248; // Blue Border
        end
    end
endmodule

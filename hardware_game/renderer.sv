// `default_nettype none

/*
 * Rail Rush - Renderer
 *
 * Generates RGB pixel color for each (row, col) position based on
 * the current game state. Draws (in priority order):
 *
 *   1. HUD (top bar with lives indicator)
 *   2. Player character (red body + skin-tone head)
 *   3. Obstacles (orange barriers, yellow wires, blue trains)
 *   4. Coins (gold squares)
 *   5. Lane rails and cross-ties (scrolling ground effect)
 *   6. Track background
 *   7. Dark background / skyline
 *
 * During GAME_OVER, displays:
 *   - "GAME OVER" in large text (3x scale)
 *   - Score in decimal (2x scale)
 *   - Restart instructions (2x scale)
 *
 * During HIT_PAUSE, the player blinks (invincibility frames).
 */
module renderer
  (input  logic [9:0] row, col,
   input  logic blank,
   // Game state
   input  logic game_active, game_over, invincible,
   input  logic [1:0] lives,
   input  logic [15:0] score,
   // Player
   input  logic player_active, player_head_active,
   input  logic is_sliding,
   // Obstacles
   input  logic obstacle_pixel,
   input  logic [1:0] obstacle_pixel_type,
   // Coins
   input  logic coin_pixel,
   // Scrolling ground
   input  logic [9:0] scroll_offset,
   // Frame counter for animation
   input  logic [7:0] frame_counter,
   // Output
   output logic [7:0] red, green, blue);

  // ---- Color Constants ----
  // Background
  localparam [7:0] BG_R = 8'h0D, BG_G = 8'h0D, BG_B = 8'h1A;
  // Track
  localparam [7:0] TK_R = 8'h25, TK_G = 8'h25, TK_B = 8'h45;
  // Rails
  localparam [7:0] RL_R = 8'h5A, RL_G = 8'h5A, RL_B = 8'h7A;
  // Cross-ties
  localparam [7:0] CT_R = 8'h3A, CT_G = 8'h3A, CT_B = 8'h5A;
  // Player body
  localparam [7:0] PB_R = 8'hE7, PB_G = 8'h4C, PB_B = 8'h3C;
  // Player head
  localparam [7:0] PH_R = 8'hFD, PH_G = 8'hBF, PH_B = 8'h6F;
  // Barrier (orange)
  localparam [7:0] OB_R = 8'hE6, OB_G = 8'h7E, OB_B = 8'h22;
  // Wire (yellow)
  localparam [7:0] OW_R = 8'hF1, OW_G = 8'hC4, OW_B = 8'h0F;
  // Train (blue)
  localparam [7:0] OT_R = 8'h34, OT_G = 8'h98, OT_B = 8'hDB;
  // Coin (gold)
  localparam [7:0] CN_R = 8'hFF, CN_G = 8'hD7, CN_B = 8'h00;
  // Lives (red)
  localparam [7:0] LV_R = 8'hFF, LV_G = 8'h47, LV_B = 8'h57;

  // ============================================================
  //  Font ROM: 8x8 bitmap, 27 characters
  // ============================================================
  // Code | Char    Code | Char    Code | Char
  //  0   | Space    10  | '9'      20  | P
  //  1   | '0'      11  | A        21  | R
  //  2   | '1'      12  | B        22  | S
  //  3   | '2'      13  | C        23  | T
  //  4   | '3'      14  | E        24  | U
  //  5   | '4'      15  | G        25  | V
  //  6   | '5'      16  | H        26  | ':'
  //  7   | '6'      17  | M
  //  8   | '7'      18  | N
  //  9   | '8'      19  | O

  function [7:0] font_rom(input [4:0] ch, input [2:0] r);
    logic [63:0] d;
    case (ch)
      5'd0:  d = 64'h0000000000000000; // Space
      5'd1:  d = 64'h708898A8C8887000; // 0
      5'd2:  d = 64'h2060202020207000; // 1
      5'd3:  d = 64'h708808304080F800; // 2
      5'd4:  d = 64'h7088083008887000; // 3
      5'd5:  d = 64'h18284888F8080800; // 4
      5'd6:  d = 64'hF880F00808887000; // 5
      5'd7:  d = 64'h304080F088887000; // 6
      5'd8:  d = 64'hF808102040404000; // 7
      5'd9:  d = 64'h7088887088887000; // 8
      5'd10: d = 64'h7088887808106000; // 9
      5'd11: d = 64'h20508888F8888800; // A
      5'd12: d = 64'hF08888F08888F000; // B
      5'd13: d = 64'h7088808080887000; // C
      5'd14: d = 64'hF88080F08080F800; // E
      5'd15: d = 64'h708880B888887800; // G
      5'd16: d = 64'h888888F888888800; // H
      5'd17: d = 64'h88D8A8A888888800; // M
      5'd18: d = 64'h88C8A89888888800; // N
      5'd19: d = 64'h7088888888887000; // O
      5'd20: d = 64'hF08888F080808000; // P
      5'd21: d = 64'hF08888F0A0908800; // R
      5'd22: d = 64'h7088807008887000; // S
      5'd23: d = 64'hF820202020202000; // T
      5'd24: d = 64'h8888888888887000; // U
      5'd25: d = 64'h8888888850502000; // V
      5'd26: d = 64'h0030300030300000; // :
      default: d = 64'h0000000000000000;
    endcase
    case (r)
      3'd0: font_rom = d[63:56];
      3'd1: font_rom = d[55:48];
      3'd2: font_rom = d[47:40];
      3'd3: font_rom = d[39:32];
      3'd4: font_rom = d[31:24];
      3'd5: font_rom = d[23:16];
      3'd6: font_rom = d[15:8];
      3'd7: font_rom = d[7:0];
    endcase
  endfunction

  // Divide-by-3 for 3x font scaling (maps 0-23 to 0-7)
  function [2:0] div3(input [4:0] v);
    if      (v >= 5'd21) div3 = 3'd7;
    else if (v >= 5'd18) div3 = 3'd6;
    else if (v >= 5'd15) div3 = 3'd5;
    else if (v >= 5'd12) div3 = 3'd4;
    else if (v >= 5'd9)  div3 = 3'd3;
    else if (v >= 5'd6)  div3 = 3'd2;
    else if (v >= 5'd3)  div3 = 3'd1;
    else                  div3 = 3'd0;
  endfunction

  // ============================================================
  //  Binary-to-Decimal: 16-bit score -> 5 BCD digits
  // ============================================================
  logic [3:0] sc_d4, sc_d3, sc_d2, sc_d1, sc_d0;
  logic [15:0] sc_r4, sc_r3, sc_r2, sc_r1;

  always_comb begin
    // Ten-thousands (score / 10000)
    if      (score >= 16'd60000) begin sc_d4=4'd6; sc_r4=score-16'd60000; end
    else if (score >= 16'd50000) begin sc_d4=4'd5; sc_r4=score-16'd50000; end
    else if (score >= 16'd40000) begin sc_d4=4'd4; sc_r4=score-16'd40000; end
    else if (score >= 16'd30000) begin sc_d4=4'd3; sc_r4=score-16'd30000; end
    else if (score >= 16'd20000) begin sc_d4=4'd2; sc_r4=score-16'd20000; end
    else if (score >= 16'd10000) begin sc_d4=4'd1; sc_r4=score-16'd10000; end
    else                         begin sc_d4=4'd0; sc_r4=score;            end

    // Thousands
    if      (sc_r4 >= 16'd9000) begin sc_d3=4'd9; sc_r3=sc_r4-16'd9000; end
    else if (sc_r4 >= 16'd8000) begin sc_d3=4'd8; sc_r3=sc_r4-16'd8000; end
    else if (sc_r4 >= 16'd7000) begin sc_d3=4'd7; sc_r3=sc_r4-16'd7000; end
    else if (sc_r4 >= 16'd6000) begin sc_d3=4'd6; sc_r3=sc_r4-16'd6000; end
    else if (sc_r4 >= 16'd5000) begin sc_d3=4'd5; sc_r3=sc_r4-16'd5000; end
    else if (sc_r4 >= 16'd4000) begin sc_d3=4'd4; sc_r3=sc_r4-16'd4000; end
    else if (sc_r4 >= 16'd3000) begin sc_d3=4'd3; sc_r3=sc_r4-16'd3000; end
    else if (sc_r4 >= 16'd2000) begin sc_d3=4'd2; sc_r3=sc_r4-16'd2000; end
    else if (sc_r4 >= 16'd1000) begin sc_d3=4'd1; sc_r3=sc_r4-16'd1000; end
    else                         begin sc_d3=4'd0; sc_r3=sc_r4;           end

    // Hundreds
    if      (sc_r3 >= 16'd900) begin sc_d2=4'd9; sc_r2=sc_r3-16'd900; end
    else if (sc_r3 >= 16'd800) begin sc_d2=4'd8; sc_r2=sc_r3-16'd800; end
    else if (sc_r3 >= 16'd700) begin sc_d2=4'd7; sc_r2=sc_r3-16'd700; end
    else if (sc_r3 >= 16'd600) begin sc_d2=4'd6; sc_r2=sc_r3-16'd600; end
    else if (sc_r3 >= 16'd500) begin sc_d2=4'd5; sc_r2=sc_r3-16'd500; end
    else if (sc_r3 >= 16'd400) begin sc_d2=4'd4; sc_r2=sc_r3-16'd400; end
    else if (sc_r3 >= 16'd300) begin sc_d2=4'd3; sc_r2=sc_r3-16'd300; end
    else if (sc_r3 >= 16'd200) begin sc_d2=4'd2; sc_r2=sc_r3-16'd200; end
    else if (sc_r3 >= 16'd100) begin sc_d2=4'd1; sc_r2=sc_r3-16'd100; end
    else                        begin sc_d2=4'd0; sc_r2=sc_r3;          end

    // Tens
    if      (sc_r2 >= 16'd90) begin sc_d1=4'd9; sc_r1=sc_r2-16'd90; end
    else if (sc_r2 >= 16'd80) begin sc_d1=4'd8; sc_r1=sc_r2-16'd80; end
    else if (sc_r2 >= 16'd70) begin sc_d1=4'd7; sc_r1=sc_r2-16'd70; end
    else if (sc_r2 >= 16'd60) begin sc_d1=4'd6; sc_r1=sc_r2-16'd60; end
    else if (sc_r2 >= 16'd50) begin sc_d1=4'd5; sc_r1=sc_r2-16'd50; end
    else if (sc_r2 >= 16'd40) begin sc_d1=4'd4; sc_r1=sc_r2-16'd40; end
    else if (sc_r2 >= 16'd30) begin sc_d1=4'd3; sc_r1=sc_r2-16'd30; end
    else if (sc_r2 >= 16'd20) begin sc_d1=4'd2; sc_r1=sc_r2-16'd20; end
    else if (sc_r2 >= 16'd10) begin sc_d1=4'd1; sc_r1=sc_r2-16'd10; end
    else                       begin sc_d1=4'd0; sc_r1=sc_r2;         end

    // Ones
    sc_d0 = sc_r1[3:0];
  end

  // ============================================================
  //  Game Over Text Layout
  // ============================================================
  // Line 1: "GAME OVER"              3x scale, 32px cells, 9 chars
  // Line 2: "SCORE: XXXXX"           2x scale, 16px cells, 12 chars
  // Line 3: "PRESS BTN 0 TO RESTART" 2x scale, 16px cells, 22 chars

  localparam [9:0] L1_Y = 10'd200, L1_X = 10'd256; // 9*32=288, centered
  localparam [9:0] L2_Y = 10'd270, L2_X = 10'd304;  // 12*16=192, centered
  localparam [9:0] L3_Y = 10'd330, L3_X = 10'd224;  // 22*16=352, centered

  // ---- Line 1: "GAME OVER" (3x scale, 32px cells) ----
  logic [9:0] l1_dx, l1_dy;
  logic [4:0] l1_cidx, l1_sub_x, l1_sub_y;
  logic [4:0] l1_code;
  logic [2:0] l1_px, l1_py;
  logic       l1_hit;

  assign l1_dx    = col - L1_X;
  assign l1_dy    = row - L1_Y;
  assign l1_cidx  = l1_dx[9:5];   // divide by 32
  assign l1_sub_x = l1_dx[4:0];   // mod 32
  assign l1_sub_y = l1_dy[4:0];   // mod 32
  assign l1_px    = div3(l1_sub_x);
  assign l1_py    = div3(l1_sub_y);
  assign l1_hit   = (row >= L1_Y) && (row < L1_Y + 10'd32) &&
                    (col >= L1_X) && (col < L1_X + 10'd288) &&
                    (l1_sub_x < 5'd24) && (l1_sub_y < 5'd24);

  always_comb begin
    case (l1_cidx[3:0])
      4'd0: l1_code = 5'd15; // G
      4'd1: l1_code = 5'd11; // A
      4'd2: l1_code = 5'd17; // M
      4'd3: l1_code = 5'd14; // E
      4'd4: l1_code = 5'd0;  // (space)
      4'd5: l1_code = 5'd19; // O
      4'd6: l1_code = 5'd25; // V
      4'd7: l1_code = 5'd14; // E
      4'd8: l1_code = 5'd21; // R
      default: l1_code = 5'd0;
    endcase
  end

  // ---- Line 2: "SCORE: XXXXX" (2x scale, 16px cells) ----
  logic [9:0] l2_dx, l2_dy;
  logic [4:0] l2_cidx;
  logic [4:0] l2_code;
  logic [2:0] l2_px, l2_py;
  logic       l2_hit;

  assign l2_dx   = col - L2_X;
  assign l2_dy   = row - L2_Y;
  assign l2_cidx = l2_dx[8:4];    // divide by 16
  assign l2_px   = l2_dx[3:1];    // (mod 16) / 2
  assign l2_py   = l2_dy[3:1];
  assign l2_hit  = (row >= L2_Y) && (row < L2_Y + 10'd16) &&
                   (col >= L2_X) && (col < L2_X + 10'd192);

  always_comb begin
    case (l2_cidx[3:0])
      4'd0:  l2_code = 5'd22;                 // S
      4'd1:  l2_code = 5'd13;                 // C
      4'd2:  l2_code = 5'd19;                 // O
      4'd3:  l2_code = 5'd21;                 // R
      4'd4:  l2_code = 5'd14;                 // E
      4'd5:  l2_code = 5'd26;                 // :
      4'd6:  l2_code = 5'd0;                  // (space)
      4'd7:  l2_code = {1'b0, sc_d4} + 5'd1;  // ten-thousands
      4'd8:  l2_code = {1'b0, sc_d3} + 5'd1;  // thousands
      4'd9:  l2_code = {1'b0, sc_d2} + 5'd1;  // hundreds
      4'd10: l2_code = {1'b0, sc_d1} + 5'd1;  // tens
      4'd11: l2_code = {1'b0, sc_d0} + 5'd1;  // ones
      default: l2_code = 5'd0;
    endcase
  end

  // ---- Line 3: "PRESS BTN 0 TO RESTART" (2x scale, 16px cells) ----
  logic [9:0] l3_dx, l3_dy;
  logic [4:0] l3_cidx;
  logic [4:0] l3_code;
  logic [2:0] l3_px, l3_py;
  logic       l3_hit;

  assign l3_dx   = col - L3_X;
  assign l3_dy   = row - L3_Y;
  assign l3_cidx = l3_dx[8:4];    // divide by 16
  assign l3_px   = l3_dx[3:1];
  assign l3_py   = l3_dy[3:1];
  assign l3_hit  = (row >= L3_Y) && (row < L3_Y + 10'd16) &&
                   (col >= L3_X) && (col < L3_X + 10'd352);

  always_comb begin
    case (l3_cidx)
      5'd0:  l3_code = 5'd20; // P
      5'd1:  l3_code = 5'd21; // R
      5'd2:  l3_code = 5'd14; // E
      5'd3:  l3_code = 5'd22; // S
      5'd4:  l3_code = 5'd22; // S
      5'd5:  l3_code = 5'd0;  // (space)
      5'd6:  l3_code = 5'd12; // B
      5'd7:  l3_code = 5'd23; // T
      5'd8:  l3_code = 5'd18; // N
      5'd9:  l3_code = 5'd0;  // (space)
      5'd10: l3_code = 5'd1;  // 0
      5'd11: l3_code = 5'd0;  // (space)
      5'd12: l3_code = 5'd23; // T
      5'd13: l3_code = 5'd19; // O
      5'd14: l3_code = 5'd0;  // (space)
      5'd15: l3_code = 5'd21; // R
      5'd16: l3_code = 5'd14; // E
      5'd17: l3_code = 5'd22; // S
      5'd18: l3_code = 5'd23; // T
      5'd19: l3_code = 5'd11; // A
      5'd20: l3_code = 5'd21; // R
      5'd21: l3_code = 5'd23; // T
      default: l3_code = 5'd0;
    endcase
  end

  // ---- Mux the active text line into a single font lookup ----
  logic [4:0] txt_code;
  logic [2:0] txt_px, txt_py;
  logic [1:0] txt_line;   // 0=none, 1/2/3 = line number
  logic       txt_active;

  always_comb begin
    txt_code   = 5'd0;
    txt_px     = 3'd0;
    txt_py     = 3'd0;
    txt_line   = 2'd0;
    txt_active = 1'b0;
    if (l1_hit) begin
      txt_active = 1'b1; txt_line = 2'd1;
      txt_code = l1_code; txt_px = l1_px; txt_py = l1_py;
    end else if (l2_hit) begin
      txt_active = 1'b1; txt_line = 2'd2;
      txt_code = l2_code; txt_px = l2_px; txt_py = l2_py;
    end else if (l3_hit) begin
      txt_active = 1'b1; txt_line = 2'd3;
      txt_code = l3_code; txt_px = l3_px; txt_py = l3_py;
    end
  end

  // Single font ROM lookup (shared by all 3 lines)
  logic [7:0] txt_font_row;
  logic       txt_font_bit;
  assign txt_font_row = font_rom(txt_code, txt_py);
  assign txt_font_bit = txt_font_row[3'd7 - txt_px];

  // Final text pixel: active AND font bit is set
  logic go_text_on;
  assign go_text_on = txt_active & txt_font_bit;

  // ============================================================
  //  3D Perspective Computation
  // ============================================================
  // Vanishing point: objects converge to (VP_X, VP_Y) at the horizon.
  // Max depth = 599 - 88 = 511 ≈ 512 = 2^9, so all scaling uses shifts.
  localparam [9:0] VP_X = 10'd400;   // Vanishing point X (center)
  localparam [9:0] VP_Y = 10'd88;    // Vanishing point Y (horizon line)

  // Depth at current scanline (0 at horizon, ~511 at screen bottom)
  logic [9:0] p_depth;
  logic in_perspective;
  assign in_perspective = (row >= VP_Y);
  assign p_depth = in_perspective ? (row - VP_Y) : 10'd0;

  // Track half-width: 320/512 * depth ≈ (d>>1) + (d>>3)
  logic [9:0] p_track_hw;
  assign p_track_hw = (p_depth >> 1) + (p_depth >> 3);

  // Track edge positions (converge to VP_X at horizon)
  logic [9:0] p_track_left, p_track_right;
  assign p_track_left  = VP_X - p_track_hw;
  assign p_track_right = VP_X + p_track_hw;

  // Is pixel inside the perspective track area?
  logic in_p_track;
  assign in_p_track = in_perspective && (col >= p_track_left) && (col <= p_track_right);

  // Lane divider positions: ±128/512 * depth = ±(d>>2)
  logic [9:0] p_div01, p_div12;
  assign p_div01 = VP_X - (p_depth >> 2);
  assign p_div12 = VP_X + (p_depth >> 2);

  // Track edge highlight lines (2px at each border)
  logic is_p_edge;
  assign is_p_edge = in_perspective && p_track_hw > 10'd8 && (
    (col >= p_track_left && col < p_track_left + 10'd2) ||
    (col > p_track_right - 10'd2 && col <= p_track_right));

  // Lane divider lines (2px wide, dashed via depth[4:0] pattern)
  logic is_p_divider;
  logic [4:0] p_div_dash;
  assign p_div_dash = p_depth[4:0];
  assign is_p_divider = in_p_track && (p_div_dash < 5'd16) && p_depth > 10'd8 && (
    (col >= p_div01 && col <= p_div01 + 10'd1) ||
    (col >= p_div12 && col <= p_div12 + 10'd1));

  // Cross-ties (horizontal stripes on track that scroll with movement)
  logic is_p_tie;
  logic [4:0] p_tie_pat;
  assign p_tie_pat = p_depth[4:0] + scroll_offset[4:0];
  assign is_p_tie = in_p_track && (p_tie_pat < 5'd3);

  // ---- Depth-based colors (lighter at bottom, darker at horizon) ----
  logic [7:0] ground_r, ground_g, ground_b;
  assign ground_r = 8'h10 + {1'b0, p_depth[8:2]};   // 16..143
  assign ground_g = 8'h10 + {1'b0, p_depth[8:2]};
  assign ground_b = 8'h25 + {1'b0, p_depth[8:2]};   // 37..164

  logic [7:0] edge_r, edge_g, edge_b;
  assign edge_r = 8'h50 + {1'b0, p_depth[8:2]};     // 80..207
  assign edge_g = 8'h50 + {1'b0, p_depth[8:2]};
  assign edge_b = 8'h65 + {1'b0, p_depth[8:2]};     // 101..228

  logic [7:0] div_clr_r, div_clr_g, div_clr_b;
  assign div_clr_r = 8'h35 + {1'b0, p_depth[8:2]};  // 53..180
  assign div_clr_g = 8'h35 + {1'b0, p_depth[8:2]};
  assign div_clr_b = 8'h48 + {1'b0, p_depth[8:2]};  // 72..199

  logic [7:0] tie_r, tie_g, tie_b;
  assign tie_r = ground_r + 8'h15;                    // 37..164
  assign tie_g = ground_g + 8'h15;
  assign tie_b = ground_b + 8'h10;                    // 47..180

  logic [7:0] wall_r, wall_g, wall_b;
  assign wall_r = 8'h08 + {2'b0, p_depth[8:3]};     // 8..71
  assign wall_g = 8'h08 + {2'b0, p_depth[8:3]};
  assign wall_b = 8'h12 + {2'b0, p_depth[8:3]};     // 18..81

  logic [7:0] sky_r, sky_g, sky_b;
  assign sky_r = 8'h05 + {2'b0, row[6:1]};           // 5..48
  assign sky_g = 8'h08 + {2'b0, row[6:1]};           // 8..51
  assign sky_b = 8'h25 + {1'b0, row[6:0]};           // 37..124

  // ---- HUD: Lives indicator ----
  logic is_hud;
  logic is_life_pixel;
  assign is_hud = (row < 10'd30);

  always_comb begin
    is_life_pixel = 1'b0;
    if (row >= 10'd8 && row <= 10'd22) begin
      if (col >= 10'd10 && col <= 10'd24 && lives >= 2'd1)
        is_life_pixel = 1'b1;
      if (col >= 10'd30 && col <= 10'd44 && lives >= 2'd2)
        is_life_pixel = 1'b1;
      if (col >= 10'd50 && col <= 10'd64 && lives >= 2'd3)
        is_life_pixel = 1'b1;
    end
  end

  // ---- Player visibility (blink during invincibility) ----
  logic player_visible;
  assign player_visible = !invincible || frame_counter[2];

  // ---- Obstacle color selection ----
  logic [7:0] obs_r, obs_g, obs_b;
  always_comb begin
    case (obstacle_pixel_type)
      2'd0:    begin obs_r = OB_R; obs_g = OB_G; obs_b = OB_B; end
      2'd1:    begin obs_r = OW_R; obs_g = OW_G; obs_b = OW_B; end
      2'd2:    begin obs_r = OT_R; obs_g = OT_G; obs_b = OT_B; end
      default: begin obs_r = OB_R; obs_g = OB_G; obs_b = OB_B; end
    endcase
  end

  // ---- Building silhouettes above horizon ----
  logic [9:0] bld_height;
  always_comb begin
    case (col[6:4])
      3'd0: bld_height = 10'd18;
      3'd1: bld_height = 10'd38;
      3'd2: bld_height = 10'd25;
      3'd3: bld_height = 10'd48;
      3'd4: bld_height = 10'd20;
      3'd5: bld_height = 10'd42;
      3'd6: bld_height = 10'd30;
      3'd7: bld_height = 10'd52;
    endcase
  end

  logic is_building, is_window;
  assign is_building = !in_perspective &&
                       (col < 10'd320 || col > 10'd480) &&
                       (row >= VP_Y - bld_height) &&
                       (col[3:0] != 4'd0);
  assign is_window = is_building &&
                     (col[2:1] == 2'b01) && (row[2:1] == 2'b01);

  // ============================================================
  //  Main Color Mux (priority-based, 3D perspective)
  // ============================================================
  always_comb begin
    if (blank) begin
      red = 8'h00; green = 8'h00; blue = 8'h00;

    end else if (game_over) begin
      // Game Over screen: dark background with text (unchanged)
      if (go_text_on) begin
        case (txt_line)
          2'd1:    begin red=8'hFF; green=8'h55; blue=8'h55; end // GAME OVER: red
          2'd2:    begin red=8'hFF; green=8'hFF; blue=8'hFF; end // SCORE: white
          2'd3:    begin red=8'hAA; green=8'hAA; blue=8'hAA; end // Instructions: gray
          default: begin red=8'h00; green=8'h00; blue=8'h00; end
        endcase
      end else begin
        red = 8'h12; green = 8'h00; blue = 8'h08;
      end

    end else if (is_life_pixel) begin
      red = LV_R; green = LV_G; blue = LV_B;

    end else if (is_hud && col < 10'd80) begin
      red = 8'h15; green = 8'h15; blue = 8'h28;

    end else if (player_active && player_visible) begin
      if (player_head_active && !is_sliding)
        begin red = PH_R; green = PH_G; blue = PH_B; end
      else
        begin red = PB_R; green = PB_G; blue = PB_B; end

    end else if (obstacle_pixel && game_active) begin
      red = obs_r; green = obs_g; blue = obs_b;

    end else if (coin_pixel && game_active) begin
      red = CN_R; green = CN_G; blue = CN_B;

    end else if (in_perspective) begin
      // Below horizon: 3D track with converging perspective
      if (is_p_edge) begin
        red = edge_r; green = edge_g; blue = edge_b;
      end else if (is_p_divider) begin
        red = div_clr_r; green = div_clr_g; blue = div_clr_b;
      end else if (is_p_tie && game_active) begin
        red = tie_r; green = tie_g; blue = tie_b;
      end else if (in_p_track) begin
        red = ground_r; green = ground_g; blue = ground_b;
      end else begin
        // Side walls
        red = wall_r; green = wall_g; blue = wall_b;
      end

    end else begin
      // Above horizon: sky with building silhouettes
      if (is_window) begin
        red = 8'h55; green = 8'h50; blue = 8'h18; // Lit window (warm yellow)
      end else if (is_building) begin
        red = 8'h0F; green = 8'h0F; blue = 8'h1A; // Dark building
      end else begin
        red = sky_r; green = sky_g; blue = sky_b;   // Sky gradient
      end
    end
  end

endmodule: renderer

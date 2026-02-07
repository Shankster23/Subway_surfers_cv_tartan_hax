// `default_nettype none

/*
 * Rail Rush - Top-Level Chip Interface
 *
 * Wires all game modules onto the FPGA. This module:
 *   - Generates 40 MHz and 200 MHz clocks from the 100 MHz input
 *   - Produces VGA timing signals (800x600 @ 60 Hz)
 *   - Instantiates all game logic (player, obstacles, coins, FSM)
 *   - Renders pixels and outputs via HDMI
 *   - Displays score on the seven-segment displays
 *
 * Input Mapping:
 *   BTN[0] = Reset
 *   BTN[1] = Move Left  (edge-detected)
 *   BTN[2] = Move Right (edge-detected)
 *   BTN[3] = Start Game / Jump (edge-detected)
 *   SW[0]  = Slide (hold)
 *
 * The game plays on a 3-lane track. Avoid obstacles by jumping (BTN[3]),
 * sliding (SW[0]), or dodging to another lane (BTN[1]/BTN[2]).
 * Collect coins for bonus points. Survive as long as possible!
 */
module ChipInterface (
    input  logic        CLOCK_100,
    input  logic [ 3:0] BTN,
    input  logic [15:0] SW,
    output logic [ 3:0] D2_AN, D1_AN,
    output logic [ 7:0] D2_SEG, D1_SEG,
    output logic        hdmi_clk_n, hdmi_clk_p,
    output logic [ 2:0] hdmi_tx_p, hdmi_tx_n
);

  // ===========================================================
  //  Clock Generation
  // ===========================================================
  logic clk_40MHz, clk_200MHz;
  logic locked, reset;

  assign reset = BTN[0];

  clock_gen clk_gen (
    .clk_in1(CLOCK_100),
    .reset(reset),
    .clk_out1(clk_40MHz),
    .clk_out2(clk_200MHz),
    .locked(locked)
  );

  // ===========================================================
  //  VGA Timing
  // ===========================================================
  logic HS, VS, blank;
  logic [9:0] row, col;

  vga disp (
    .clock_40MHz(clk_40MHz), .reset(reset),
    .HS(HS), .VS(VS), .blank(blank),
    .row(row), .col(col)
  );

  // ===========================================================
  //  Frame Done Generation (one pulse per frame)
  // ===========================================================
  logic frame_raw, frame_prev, frame_done;
  assign frame_raw = (row == 10'd599) & (col == 10'd799);

  always_ff @(posedge clk_40MHz or posedge reset) begin
    if (reset) frame_prev <= 1'b0;
    else       frame_prev <= frame_raw;
  end
  assign frame_done = frame_raw & ~frame_prev;

  // ===========================================================
  //  Frame Counter (for animations)
  // ===========================================================
  logic [7:0] frame_counter;
  always_ff @(posedge clk_40MHz or posedge reset) begin
    if (reset)           frame_counter <= 8'd0;
    else if (frame_done) frame_counter <= frame_counter + 8'd1;
  end

  // ===========================================================
  //  Button Edge Detection
  // ===========================================================
  logic [3:0] btn_prev;
  logic [3:0] btn_edge;

  always_ff @(posedge clk_40MHz or posedge reset) begin
    if (reset) btn_prev <= 4'd0;
    else       btn_prev <= BTN;
  end
  assign btn_edge = BTN & ~btn_prev;

  logic move_left_pulse, move_right_pulse, jump_pulse, start_pulse;
  logic slide_hold;

  assign move_left_pulse  = btn_edge[1];
  assign move_right_pulse = btn_edge[2];
  assign jump_pulse       = btn_edge[3] & game_active;
  assign start_pulse      = btn_edge[3] & ~game_active;
  assign slide_hold       = SW[0];

  // ===========================================================
  //  LFSR (Pseudo-Random Number Generator)
  // ===========================================================
  logic [15:0] lfsr_val;

  lfsr prng (
    .clock(clk_40MHz), .reset(reset),
    .enable(1'b1),
    .val(lfsr_val)
  );

  // ===========================================================
  //  Game FSM
  // ===========================================================
  logic game_active, game_over, invincible;
  logic [1:0]  lives;
  logic [15:0] score;
  logic [3:0]  speed;
  logic [9:0]  scroll_offset;
  logic obstacle_hit, coin_collected;

  rail_rush_fsm fsm (
    .clock(clk_40MHz), .reset(reset), .frame_done(frame_done),
    .start_btn(start_pulse),
    .obstacle_hit(obstacle_hit),
    .coin_collected(coin_collected),
    .game_active(game_active),
    .game_over(game_over),
    .lives(lives),
    .score(score),
    .speed(speed),
    .invincible(invincible),
    .scroll_offset(scroll_offset)
  );

  // ===========================================================
  //  Player
  // ===========================================================
  logic [1:0] player_lane;
  logic [9:0] player_x, player_y;
  logic player_active, player_head_active;
  logic is_jumping, is_sliding;
  logic jump_clear, slide_clear;

  player player_inst (
    .clock(clk_40MHz), .reset(reset), .frame_done(frame_done),
    .move_left_pulse(move_left_pulse),
    .move_right_pulse(move_right_pulse),
    .jump_pulse(jump_pulse),
    .slide_hold(slide_hold),
    .game_active(game_active),
    .row(row), .col(col),
    .lane(player_lane),
    .player_x(player_x),
    .player_y(player_y),
    .player_active(player_active),
    .player_head_active(player_head_active),
    .is_jumping(is_jumping),
    .is_sliding(is_sliding),
    .jump_clear(jump_clear),
    .slide_clear(slide_clear)
  );

  // ===========================================================
  //  Obstacle Manager
  // ===========================================================
  logic obstacle_pixel;
  logic [1:0] obstacle_pixel_type;

  obstacle_manager obs_mgr (
    .clock(clk_40MHz), .reset(reset), .frame_done(frame_done),
    .game_active(game_active),
    .lfsr_val(lfsr_val),
    .speed(speed),
    .player_lane(player_lane),
    .jump_clear(jump_clear),
    .slide_clear(slide_clear),
    .row(row), .col(col),
    .obstacle_pixel(obstacle_pixel),
    .obstacle_pixel_type(obstacle_pixel_type),
    .hit(obstacle_hit)
  );

  // ===========================================================
  //  Coin Manager
  // ===========================================================
  logic coin_pixel;

  coin_manager coin_mgr (
    .clock(clk_40MHz), .reset(reset), .frame_done(frame_done),
    .game_active(game_active),
    .lfsr_val(lfsr_val),
    .speed(speed),
    .player_lane(player_lane),
    .player_y(player_y),
    .row(row), .col(col),
    .coin_pixel(coin_pixel),
    .coin_collected(coin_collected)
  );

  // ===========================================================
  //  Renderer
  // ===========================================================
  logic [7:0] red, green, blue;

  renderer render_inst (
    .row(row), .col(col), .blank(blank),
    .game_active(game_active),
    .game_over(game_over),
    .invincible(invincible),
    .lives(lives),
    .score(score),
    .player_active(player_active),
    .player_head_active(player_head_active),
    .is_sliding(is_sliding),
    .obstacle_pixel(obstacle_pixel),
    .obstacle_pixel_type(obstacle_pixel_type),
    .coin_pixel(coin_pixel),
    .scroll_offset(scroll_offset),
    .frame_counter(frame_counter),
    .red(red), .green(green), .blue(blue)
  );

  // ===========================================================
  //  Seven-Segment Display (Score in hex)
  // ===========================================================
  EightSevenSegmentDisplays sev_seg_disp (
    .reset(reset), .CLOCK_100(CLOCK_100),
    .dec_points(8'b0), .blank(8'b1110_0000),
    .D2_AN(D2_AN), .D1_AN(D1_AN),
    .D2_SEG(D2_SEG), .D1_SEG(D1_SEG),
    // D2 display: lives on HEX4
    .HEX7(4'd0),
    .HEX6(4'd0),
    .HEX5(4'd0),
    .HEX4({2'b0, lives}),
    // D1 display: score (hex)
    .HEX3(score[15:12]),
    .HEX2(score[11:8]),
    .HEX1(score[7:4]),
    .HEX0(score[3:0])
  );

  // ===========================================================
  //  VGA to HDMI Converter
  // ===========================================================
  hdmi_tx vga_to_hdmi (
    .pix_clk(clk_40MHz),
    .pix_clkx5(clk_200MHz),
    .pix_clk_locked(locked),
    .rst(reset),
    .red(red),
    .green(green),
    .blue(blue),
    .hsync(HS),
    .vsync(VS),
    .vde(~blank),
    .TMDS_CLK_P(hdmi_clk_p),
    .TMDS_CLK_N(hdmi_clk_n),
    .TMDS_DATA_P(hdmi_tx_p),
    .TMDS_DATA_N(hdmi_tx_n)
  );

endmodule: ChipInterface

// `default_nettype none

/*
 * Rail Rush - Player Module
 *
 * Controls the player character running on 3 parallel rails (lanes).
 * The player can:
 *   - Move left/right between lanes (edge-detected single pulses)
 *   - Jump to clear ground-level barriers (24-frame arc)
 *   - Slide to pass under overhead wires (hold to stay low)
 *
 * Lane positions are 256 pixels apart for clean arithmetic:
 *   Lane 0: x = 144    Lane 1: x = 400    Lane 2: x = 656
 *
 * Jump physics (no multiply needed):
 *   - 12 frames up:   offset increases by 6/frame -> peak = 72px
 *   - 12 frames down: offset decreases by 6/frame -> lands at 0
 *
 * The module also generates pixel-active signals for rendering.
 */
module player
  (input  logic clock, reset, frame_done,
   input  logic move_left_pulse, move_right_pulse,
   input  logic jump_pulse, slide_hold,
   input  logic game_active,
   input  logic [9:0] row, col,
   output logic [1:0] lane,
   output logic [9:0] player_x, player_y,
   output logic player_active,
   output logic player_head_active,
   output logic is_jumping, is_sliding,
   output logic jump_clear, slide_clear);

  // ---- Constants ----
  localparam [9:0] LANE0_X      = 10'd144;
  localparam [9:0] LANE1_X      = 10'd400;
  localparam [9:0] LANE2_X      = 10'd656;
  localparam [9:0] FEET_Y       = 10'd480;
  localparam [9:0] PLAYER_W     = 10'd40;
  localparam [9:0] PLAYER_H     = 10'd50;
  localparam [9:0] SLIDE_H      = 10'd25;
  localparam [9:0] HEAD_H       = 10'd12;
  localparam [4:0] JUMP_DUR     = 5'd24;
  localparam [9:0] JUMP_STEP    = 10'd6;

  // ---- State Registers ----
  logic [4:0] jump_counter;
  logic [9:0] jump_offset;

  // ---- Input Latches ----
  // Button edge pulses last only 1 clock cycle. frame_done also lasts 1 cycle.
  // These almost never coincide, so we latch button presses and consume them
  // at the next frame_done. Set-priority: if a press arrives on the same
  // cycle as frame_done, the press is captured (consumed next frame).
  logic left_pending, right_pending, jump_pending;

  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      left_pending <= 1'b0;
    else if (move_left_pulse)
      left_pending <= 1'b1;
    else if (frame_done)
      left_pending <= 1'b0;
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      right_pending <= 1'b0;
    else if (move_right_pulse)
      right_pending <= 1'b1;
    else if (frame_done)
      right_pending <= 1'b0;
  end

  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      jump_pending <= 1'b0;
    else if (jump_pulse)
      jump_pending <= 1'b1;
    else if (frame_done)
      jump_pending <= 1'b0;
  end

  // ---- Lane Movement (instant snap) ----
  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      lane <= 2'd1;  // Start in center lane
    else if (frame_done && game_active) begin
      if (left_pending && lane > 2'd0)
        lane <= lane - 2'd1;
      else if (right_pending && lane < 2'd2)
        lane <= lane + 2'd1;
    end
  end

  // ---- Jump Logic ----
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      jump_counter <= 5'd0;
      jump_offset  <= 10'd0;
    end else if (frame_done && game_active) begin
      if (jump_counter > 5'd0) begin
        jump_counter <= jump_counter - 5'd1;
        if (jump_counter > 5'd12)
          jump_offset <= jump_offset + JUMP_STEP;
        else
          jump_offset <= (jump_offset >= JUMP_STEP) ?
                         jump_offset - JUMP_STEP : 10'd0;
      end else if (jump_pending && !is_sliding) begin
        jump_counter <= JUMP_DUR;
        jump_offset  <= 10'd0;
      end
    end
  end

  // ---- Slide Logic ----
  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      is_sliding <= 1'b0;
    else if (frame_done && game_active)
      is_sliding <= slide_hold && !is_jumping;
  end

  // ---- Derived Outputs ----
  assign is_jumping  = (jump_counter > 5'd0);
  assign jump_clear  = (jump_offset >= 10'd35);
  assign slide_clear = is_sliding;

  // Player X: snap to lane center
  always_comb begin
    case (lane)
      2'd0:    player_x = LANE0_X;
      2'd1:    player_x = LANE1_X;
      2'd2:    player_x = LANE2_X;
      default: player_x = LANE1_X;
    endcase
  end

  // Player Y: feet position minus jump offset
  assign player_y = FEET_Y - jump_offset;

  // ---- Pixel Rendering ----
  logic [9:0] draw_h, draw_top, half_w;
  assign draw_h   = is_sliding ? SLIDE_H : PLAYER_H;
  assign draw_top  = player_y - draw_h;
  assign half_w    = PLAYER_W >> 1;  // 20

  logic in_x, in_y, in_head_y;

  assign in_x = (col >= player_x - half_w) && (col < player_x + half_w);
  assign in_y = (row >= draw_top) && (row < player_y);
  assign in_head_y = (row >= draw_top) && (row < draw_top + HEAD_H);

  assign player_active      = in_x & in_y & game_active;
  assign player_head_active = in_x & in_head_y & game_active;

endmodule: player

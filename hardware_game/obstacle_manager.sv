// `default_nettype none

/*
 * Rail Rush - Obstacle Manager
 *
 * Manages a pool of 4 obstacle slots. Each obstacle has:
 *   - active: whether this slot is in use
 *   - lane:   which of the 3 lanes (0/1/2)
 *   - otype:  BARRIER (jump over), WIRE (slide under), TRAIN (dodge)
 *   - y_pos:  vertical position scrolling from top (0) to bottom (600+)
 *   - checked: whether collision has already been evaluated for this pass
 *
 * Spawning uses the LFSR value to randomize lane, type, and spawn interval.
 * Obstacles move downward by `speed` pixels each frame.
 * Collision is checked in a narrow band near the player's feet.
 *
 * Also generates pixel-active signals for rendering each obstacle type.
 */
module obstacle_manager
  (input  logic clock, reset, frame_done, game_active,
   input  logic [15:0] lfsr_val,
   input  logic [3:0]  speed,
   input  logic [1:0]  player_lane,
   input  logic        jump_clear, slide_clear,
   input  logic [9:0]  row, col,
   output logic        obstacle_pixel,
   output logic [1:0]  obstacle_pixel_type,
   output logic        hit);

  // ---- Constants ----
  localparam NUM_OBS = 4;

  // Obstacle types
  localparam [1:0] BARRIER = 2'd0;
  localparam [1:0] WIRE    = 2'd1;
  localparam [1:0] TRAIN   = 2'd2;

  // Obstacle dimensions (pixels)
  localparam [9:0] OBS_HALF_W      = 10'd40;
  localparam [9:0] BARRIER_HEIGHT  = 10'd30;
  localparam [9:0] WIRE_HEIGHT     = 10'd15;
  localparam [9:0] TRAIN_HEIGHT    = 10'd100;

  // Lane centers
  localparam [9:0] LANE0_X = 10'd144;
  localparam [9:0] LANE1_X = 10'd400;
  localparam [9:0] LANE2_X = 10'd656;

  // Collision zone (y range where we check for hits)
  localparam [9:0] COLLISION_Y_MIN = 10'd440;
  localparam [9:0] COLLISION_Y_MAX = 10'd490;

  // Deactivation threshold
  localparam [9:0] DEACTIVATE_Y = 10'd620;

  // ---- Per-slot State ----
  logic [3:0]  active;
  logic [1:0]  obs_lane  [4];
  logic [1:0]  obs_type  [4];
  logic [9:0]  obs_y     [4];
  logic [3:0]  checked;

  // ---- Spawn Timer ----
  logic [7:0] spawn_timer;

  // ---- Lane Center Lookup ----
  function automatic [9:0] get_lane_x(input [1:0] l);
    case (l)
      2'd0:    get_lane_x = LANE0_X;
      2'd1:    get_lane_x = LANE1_X;
      2'd2:    get_lane_x = LANE2_X;
      default: get_lane_x = LANE1_X;
    endcase
  endfunction

  // ---- Obstacle Height Lookup ----
  function automatic [9:0] get_height(input [1:0] t);
    case (t)
      BARRIER: get_height = BARRIER_HEIGHT;
      WIRE:    get_height = WIRE_HEIGHT;
      TRAIN:   get_height = TRAIN_HEIGHT;
      default: get_height = BARRIER_HEIGHT;
    endcase
  endfunction

  // ---- Find First Free Slot ----
  logic [1:0] free_slot;
  logic       has_free;

  always_comb begin
    has_free  = 1'b0;
    free_slot = 2'd0;
    if (!active[0])      begin has_free = 1'b1; free_slot = 2'd0; end
    else if (!active[1]) begin has_free = 1'b1; free_slot = 2'd1; end
    else if (!active[2]) begin has_free = 1'b1; free_slot = 2'd2; end
    else if (!active[3]) begin has_free = 1'b1; free_slot = 2'd3; end
  end

  // ---- Spawn Parameters from LFSR ----
  logic [1:0] spawn_lane, spawn_type;

  always_comb begin
    case (lfsr_val[1:0])
      2'b00:   spawn_lane = 2'd0;
      2'b01:   spawn_lane = 2'd1;
      2'b10:   spawn_lane = 2'd2;
      2'b11:   spawn_lane = 2'd1;  // Center lane more common
    endcase
    case (lfsr_val[3:2])
      2'b00:   spawn_type = BARRIER;
      2'b01:   spawn_type = WIRE;
      2'b10:   spawn_type = TRAIN;
      2'b11:   spawn_type = BARRIER; // Barriers more common
    endcase
  end

  // Spawn interval: 40 + lfsr[9:4] (range 40-103 frames)
  logic [7:0] next_spawn_interval;
  assign next_spawn_interval = 8'd40 + {2'b0, lfsr_val[9:4]};

  // ---- Collision Detection (combinational, checked flag prevents repeats) ----
  logic [3:0] collision_detected;
  logic [3:0] in_collision_zone;
  logic       any_collision;
  assign any_collision = |collision_detected;
  assign hit = any_collision;

  always_comb begin
    collision_detected = 4'd0;
    in_collision_zone  = 4'd0;
    for (int i = 0; i < NUM_OBS; i++) begin
      if (active[i] && !checked[i] &&
          obs_y[i] >= COLLISION_Y_MIN && obs_y[i] <= COLLISION_Y_MAX) begin
        in_collision_zone[i] = 1'b1;
        if (obs_lane[i] == player_lane) begin
          case (obs_type[i])
            BARRIER: collision_detected[i] = !jump_clear;
            WIRE:    collision_detected[i] = !slide_clear;
            TRAIN:   collision_detected[i] = 1'b1;
            default: collision_detected[i] = 1'b1;
          endcase
        end
      end
    end
  end

  // ---- Sequential Logic: Movement, Spawning, Checked Flags ----
  integer k;
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      active      <= 4'd0;
      checked     <= 4'd0;
      spawn_timer <= 8'd60;
      for (k = 0; k < NUM_OBS; k = k + 1) begin
        obs_lane[k] <= 2'd0;
        obs_type[k] <= 2'd0;
        obs_y[k]    <= 10'd0;
      end
    end else if (frame_done && game_active) begin

      // --- Move active obstacles and mark checked ---
      for (k = 0; k < NUM_OBS; k = k + 1) begin
        if (active[k]) begin
          obs_y[k] <= obs_y[k] + {6'd0, speed};

          // Mark as checked only when an actual collision is detected.
          // Obstacles in other lanes remain dangerous so the player can
          // still be hit if they dodge INTO an obstacle's lane.
          if (collision_detected[k])
            checked[k] <= 1'b1;

          // Deactivate if past bottom of screen
          if (obs_y[k] >= DEACTIVATE_Y) begin
            active[k]  <= 1'b0;
            checked[k] <= 1'b0;
          end
        end
      end

      // --- Spawn timer ---
      if (spawn_timer > 8'd0) begin
        spawn_timer <= spawn_timer - 8'd1;
      end else if (has_free) begin
        // Activate a new obstacle
        active[free_slot]   <= 1'b1;
        obs_lane[free_slot] <= spawn_lane;
        obs_type[free_slot] <= spawn_type;
        obs_y[free_slot]    <= 10'd0;
        checked[free_slot]  <= 1'b0;
        spawn_timer         <= next_spawn_interval;
      end

    end
  end

  // ---- Pixel Rendering (combinational) ----
  logic [9:0] obs_cx [4];
  logic [9:0] obs_h  [4];
  logic [3:0] pixel_hit;

  always_comb begin
    for (int i = 0; i < NUM_OBS; i++) begin
      obs_cx[i] = get_lane_x(obs_lane[i]);
      obs_h[i]  = get_height(obs_type[i]);
    end
  end

  always_comb begin
    pixel_hit = 4'd0;
    for (int i = 0; i < NUM_OBS; i++) begin
      if (active[i] &&
          col >= (obs_cx[i] - OBS_HALF_W) && col < (obs_cx[i] + OBS_HALF_W) &&
          row >= obs_y[i] && row < (obs_y[i] + obs_h[i]))
        pixel_hit[i] = 1'b1;
    end
  end

  assign obstacle_pixel = |pixel_hit;

  // Type of the rendered pixel (priority: slot 0 > 1 > 2 > 3)
  always_comb begin
    obstacle_pixel_type = 2'd0;
    if (pixel_hit[3]) obstacle_pixel_type = obs_type[3];
    if (pixel_hit[2]) obstacle_pixel_type = obs_type[2];
    if (pixel_hit[1]) obstacle_pixel_type = obs_type[1];
    if (pixel_hit[0]) obstacle_pixel_type = obs_type[0];
  end

endmodule: obstacle_manager

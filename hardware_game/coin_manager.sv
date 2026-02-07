// `default_nettype none

/*
 * Rail Rush - Coin Manager
 *
 * Manages a pool of 4 coin slots. Coins spawn at the top of the screen
 * and scroll downward like obstacles. When the player is in the same
 * lane and close vertically, the coin is collected (one-frame pulse).
 *
 * Each collected coin is worth 50 points (handled by the FSM).
 *
 * Coins are rendered as 14x14 pixel squares centered in their lane.
 */
module coin_manager
  (input  logic clock, reset, frame_done, game_active,
   input  logic [15:0] lfsr_val,
   input  logic [3:0]  speed,
   input  logic [1:0]  player_lane,
   input  logic [9:0]  player_y,
   input  logic [9:0]  row, col,
   output logic        coin_pixel,
   output logic        coin_collected);

  // ---- Constants ----
  localparam NUM_COINS = 4;
  localparam [9:0] COIN_HALF  = 10'd7;   // 14x14 coin
  localparam [9:0] COLLECT_RANGE = 10'd35;
  localparam [9:0] DEACTIVATE_Y = 10'd620;

  // Lane centers
  localparam [9:0] LANE0_X = 10'd144;
  localparam [9:0] LANE1_X = 10'd400;
  localparam [9:0] LANE2_X = 10'd656;

  // ---- Per-slot State ----
  logic [3:0]  active;
  logic [1:0]  coin_lane [4];
  logic [9:0]  coin_y    [4];

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

  // Spawn lane from LFSR (different bits than obstacle_manager)
  logic [1:0] spawn_lane;
  always_comb begin
    case (lfsr_val[5:4])
      2'b00:   spawn_lane = 2'd0;
      2'b01:   spawn_lane = 2'd1;
      2'b10:   spawn_lane = 2'd2;
      2'b11:   spawn_lane = 2'd0;
    endcase
  end

  // Spawn interval: 55 + lfsr[15:10] (range 55-118 frames)
  logic [7:0] next_spawn_interval;
  assign next_spawn_interval = 8'd55 + {2'b0, lfsr_val[15:10]};

  // ---- Collection Detection (combinational) ----
  logic [3:0] collected;
  always_comb begin
    collected = 4'd0;
    for (int i = 0; i < NUM_COINS; i++) begin
      if (active[i] && coin_lane[i] == player_lane &&
          coin_y[i] >= (player_y - COLLECT_RANGE) &&
          coin_y[i] <= (player_y + 10'd10))
        collected[i] = 1'b1;
    end
  end
  assign coin_collected = |collected;

  // ---- Sequential Logic: Movement, Spawning, Collection ----
  integer k;
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      active      <= 4'd0;
      spawn_timer <= 8'd30;
      for (k = 0; k < NUM_COINS; k = k + 1) begin
        coin_lane[k] <= 2'd0;
        coin_y[k]    <= 10'd0;
      end
    end else if (frame_done && game_active) begin

      // --- Move active coins downward ---
      for (k = 0; k < NUM_COINS; k = k + 1) begin
        if (active[k]) begin
          coin_y[k] <= coin_y[k] + {6'd0, speed};
          // Deactivate if collected or past screen
          if (collected[k] || coin_y[k] >= DEACTIVATE_Y)
            active[k] <= 1'b0;
        end
      end

      // --- Spawn timer ---
      if (spawn_timer > 8'd0) begin
        spawn_timer <= spawn_timer - 8'd1;
      end else if (has_free) begin
        active[free_slot]    <= 1'b1;
        coin_lane[free_slot] <= spawn_lane;
        coin_y[free_slot]    <= 10'd0;
        spawn_timer          <= next_spawn_interval;
      end

    end
  end

  // ---- 3D Perspective for Pixel Rendering ----
  localparam [9:0] VP_X = 10'd400;
  localparam [9:0] VP_Y = 10'd88;

  logic [9:0] p_depth;
  assign p_depth = (row >= VP_Y) ? (row - VP_Y) : 10'd0;

  // Perspective coin half-width: ≈9/512 * depth → ~7px at player y
  logic [9:0] p_coin_hw;
  assign p_coin_hw = (p_depth >> 6) + (p_depth >> 8);

  // Perspective lane centre at current scanline
  function automatic [9:0] persp_lane_x(input [1:0] l, input [9:0] d);
    case (l)
      2'd0:    persp_lane_x = VP_X - (d >> 1);
      2'd1:    persp_lane_x = VP_X;
      2'd2:    persp_lane_x = VP_X + (d >> 1);
      default: persp_lane_x = VP_X;
    endcase
  endfunction

  // ---- Pixel Rendering (combinational, perspective-adjusted) ----
  logic [9:0] coin_cx    [4];
  logic [9:0] coin_depth [4];
  logic [9:0] coin_ph    [4];   // perspective height
  logic [3:0] pixel_hit;

  // Coin height scales with depth at coin's y position: ≈20/512*d → ~15 at d=392
  always_comb begin
    for (int i = 0; i < NUM_COINS; i++) begin
      coin_cx[i]    = persp_lane_x(coin_lane[i], p_depth);
      coin_depth[i] = (coin_y[i] >= VP_Y) ? (coin_y[i] - VP_Y) : 10'd0;
      coin_ph[i]    = (coin_depth[i] >> 5) + (coin_depth[i] >> 7);
    end
  end

  always_comb begin
    pixel_hit = 4'd0;
    for (int i = 0; i < NUM_COINS; i++) begin
      if (active[i] && row >= VP_Y && p_coin_hw > 10'd0 &&
          coin_ph[i] > 10'd0 &&
          col >= (coin_cx[i] - p_coin_hw) && col < (coin_cx[i] + p_coin_hw) &&
          row >= coin_y[i] && row < (coin_y[i] + coin_ph[i]))
        pixel_hit[i] = 1'b1;
    end
  end

  assign coin_pixel = |pixel_hit;

endmodule: coin_manager

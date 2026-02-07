// `default_nettype none

/*
 * Rail Rush - Game State Machine
 *
 * Controls the overall game flow and scoring:
 *   IDLE       -> Waiting for start button
 *   PLAYING    -> Active gameplay, obstacles scroll, score increments
 *   HIT_PAUSE  -> Brief invincibility after taking damage (30 frames)
 *   GAME_OVER  -> All lives lost, waiting for restart
 *
 * Manages:
 *   - Lives (start with 3, decrement on hit)
 *   - Score (increments by speed each frame + 50 per coin)
 *   - Speed (increases every 600 frames, capped at 8)
 *   - Hit cooldown (prevents double-hits from same obstacle)
 */
module rail_rush_fsm
  (input  logic clock, reset, frame_done,
   input  logic start_btn, obstacle_hit, coin_collected,
   output logic game_active, game_over,
   output logic [1:0]  lives,
   output logic [15:0] score,
   output logic [3:0]  speed,
   output logic        invincible,
   output logic [9:0]  scroll_offset);

  // ---- States ----
  enum logic [1:0] {IDLE, PLAYING, HIT_PAUSE, GAMEOVER} curr_state, next_state;

  // ---- Counters ----
  logic [7:0]  hit_cooldown;
  logic [9:0]  speed_timer;

  // ---- State Register ----
  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      curr_state <= IDLE;
    else
      curr_state <= next_state;
  end

  // ---- Next State Logic ----
  // IMPORTANT: The PLAYING->HIT_PAUSE/GAMEOVER transition must be gated by
  // frame_done so that the state transition and lives decrement in the
  // sequential block happen atomically on the same clock edge. Without this,
  // the FSM races ahead to HIT_PAUSE between frames, and the lives decrement
  // (which checks curr_state == PLAYING) never fires.
  always_comb begin
    next_state = curr_state;
    case (curr_state)
      IDLE: begin
        if (start_btn)
          next_state = PLAYING;
      end
      PLAYING: begin
        if (frame_done && obstacle_hit && hit_cooldown == 8'd0) begin
          if (lives <= 2'd1)
            next_state = GAMEOVER;
          else
            next_state = HIT_PAUSE;
        end
      end
      HIT_PAUSE: begin
        if (frame_done && hit_cooldown <= 8'd1)
          next_state = PLAYING;
      end
      GAMEOVER: begin
        if (start_btn)
          next_state = IDLE;
      end
    endcase
  end

  // ---- Output Logic ----
  assign game_active = (curr_state == PLAYING) || (curr_state == HIT_PAUSE);
  assign game_over   = (curr_state == GAMEOVER);
  assign invincible  = (curr_state == HIT_PAUSE) || (hit_cooldown > 8'd0);

  // ---- Sequential Game Logic ----
  always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
      lives         <= 2'd3;
      score         <= 16'd0;
      speed         <= 4'd3;
      hit_cooldown  <= 8'd0;
      speed_timer   <= 10'd0;
      scroll_offset <= 10'd0;
    end else begin

      // --- Reset game state when transitioning GAMEOVER -> IDLE ---
      if (curr_state == GAMEOVER && next_state == IDLE) begin
        lives         <= 2'd3;
        score         <= 16'd0;
        speed         <= 4'd3;
        hit_cooldown  <= 8'd0;
        speed_timer   <= 10'd0;
        scroll_offset <= 10'd0;
      end

      // --- Active gameplay updates on frame_done ---
      else if (frame_done && game_active) begin

        // Score: +speed each frame
        if (coin_collected)
          score <= score + 16'd50 + {12'd0, speed};
        else
          score <= score + {12'd0, speed};

        // Scroll offset for ground animation
        scroll_offset <= scroll_offset + {6'd0, speed};

        // Speed increase timer
        if (speed_timer >= 10'd600) begin
          speed_timer <= 10'd0;
          if (speed < 4'd8)
            speed <= speed + 4'd1;
        end else begin
          speed_timer <= speed_timer + 10'd1;
        end

        // Hit cooldown countdown
        if (hit_cooldown > 8'd0)
          hit_cooldown <= hit_cooldown - 8'd1;

        // Taking damage (only in PLAYING, not during HIT_PAUSE)
        if (curr_state == PLAYING && obstacle_hit && hit_cooldown == 8'd0) begin
          lives        <= lives - 2'd1;
          hit_cooldown <= 8'd30;
        end

      end
    end
  end

endmodule: rail_rush_fsm

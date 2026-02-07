# Rail Rush - Hardware Implementation

A 3-lane endless runner game implemented in synthesizable SystemVerilog, targeting
an FPGA with VGA/HDMI output. Inspired by Rail Rush / Subway Surfers.

## Game Overview

The player runs forward on 3 parallel rail tracks. Obstacles scroll from the top
of the screen toward the player at the bottom. The player must dodge, jump, or
slide to avoid them, while collecting coins for bonus points.

- **3 lives** - lose one each time you hit an obstacle
- **Score** increases each frame and on coin collection
- **Speed** gradually increases every ~10 seconds (caps at 8)
- **Game Over** when all lives are lost; press Start to retry

## Controls (FPGA Inputs)

| Input   | Function                                        |
|---------|-------------------------------------------------|
| BTN[0]  | **Reset** - resets the entire system             |
| BTN[1]  | **Move Left** - shift one lane to the left       |
| BTN[2]  | **Move Right** - shift one lane to the right     |
| BTN[3]  | **Start / Jump** - starts game from menu; jumps during play |
| SW[0]   | **Slide** - hold to slide under wire obstacles   |

## Display

- **Resolution**: 800 x 600 @ 60 Hz (40 MHz pixel clock)
- **Output**: HDMI via TMDS encoding + OSERDESE2 serialization (no IP cores needed)
- **Seven-Segment**: Left display shows lives, right display shows score (hex)

## Obstacle Types

| Type     | Appearance | How to Avoid     |
|----------|-----------|-------------------|
| Barrier  | Orange, 80x30px  | Jump over it (BTN[3])  |
| Wire     | Yellow, 80x15px  | Slide under it (SW[0]) |
| Train    | Blue, 80x100px   | Dodge to another lane  |

## File Descriptions

### Core Game Modules

| File | Description |
|------|-------------|
| `rail_rush_top.sv` | **Top-level chip interface**. Instantiates all modules, generates clocks, handles button edge detection, and wires everything to the HDMI output and seven-segment displays. This is the synthesis top-level. |
| `rail_rush_fsm.sv` | **Game state machine**. Manages the game states (IDLE, PLAYING, HIT_PAUSE, GAME_OVER), tracks lives, score, speed, and scroll offset. Handles hit cooldown for invincibility frames. |
| `player.sv` | **Player controller**. Manages the player's lane position, jump arc (24-frame parabolic motion via +6/-6 per frame), and slide state. Also generates pixel-active signals for the player's body and head regions. |
| `obstacle_manager.sv` | **Obstacle pool** (4 slots). Handles spawning (LFSR-randomized lane, type, and interval), downward scrolling, deactivation, collision detection, and per-pixel rendering flags. Each obstacle is checked once as it passes through the player's collision zone. |
| `coin_manager.sv` | **Coin pool** (4 slots). Spawns coins at random lanes/intervals, scrolls them downward, detects collection when overlapping with the player, and generates pixel flags for rendering. |
| `renderer.sv` | **Pixel color generator**. For each (row, col), determines the RGB output using a priority-based color mux: HUD > Player > Obstacles > Coins > Rails > Track > Background. Includes scrolling ground ties, city skyline, and visual effects for game over / invincibility. |
| `lfsr.sv` | **16-bit Linear Feedback Shift Register**. Generates pseudo-random numbers using the polynomial x^16 + x^14 + x^13 + x^11 + 1 (period 65535). Runs every clock cycle for good randomness when sampled at frame rate. |

### Reused Modules (from lab4 Pong)

| File | Description |
|------|-------------|
| `vgatiming.sv` | **VGA timing generator**. Produces horizontal/vertical sync, blanking, and (row, col) coordinates for 800x600 @ 60 Hz. Uses counters and comparators from the library. |
| `library.sv` | **Primitive library**. Contains synthesizable building blocks: Counter, Register, Comparator, MagComp, Adder, Subtractor, Mux2to1, RangeCheck, OffsetCheck, and more. Used by the VGA timing module. |
| `seven_segment.sv` | **Seven-segment display driver**. Multiplexes 8 BCD/hex digits across the two 4-digit displays on the FPGA board. Includes digit decoding and anode scanning at ~250 Hz. |

### Clock & HDMI Modules (replace Vivado IP cores)

These modules use Xilinx 7-series primitives directly — no IP core generation required:

| File | Description |
|------|-------------|
| `clock_gen.sv` | **Clock generator**. Wraps the MMCME2_BASE primitive with BUFG global clock buffers. Converts the 100 MHz board oscillator into a 40 MHz pixel clock and a 200 MHz serializer clock. Drop-in replacement for the `clk_wiz_0` IP core. |
| `hdmi_tx.sv` | **HDMI transmitter**. Implements DVI-mode HDMI output: 3 TMDS 8b/10b encoders (with DC balance) for R/G/B, plus 4 OSERDESE2 master/slave 10:1 DDR serializers and OBUFDS differential output buffers for the 3 data channels and clock channel. Drop-in replacement for the `hdmi_tx_0` IP core. |

## Architecture

```
                    CLOCK_100
                       |
                  [clock_gen]       (MMCME2_BASE + BUFG)
                   /        \
             clk_40MHz    clk_200MHz
                 |              |
              [vga] ----+      |
              row,col   |      |
                 |      |      |
    +---------+--+--+---+--+   |
    |         |     |      |   |
 [player] [obs_mgr] [coin_mgr] |
    |         |     |      |   |
    +---[renderer]--+      |   |
         RGB               |   |
          |                |   |
       [hdmi_tx]  ---------+   |   (TMDS + OSERDESE2 + OBUFDS)
          |                    |
      HDMI output              |
                               |
    [rail_rush_fsm] <-- frame_done, hits, coins
         |
    lives, score, speed
         |
    [seven_segment] --> D1, D2
```

## Design Decisions

1. **No division or variable multiplication**: Jump physics use fixed +6/-6 per frame instead of parabolic equations. Lane positions are 256px apart (not used for shift arithmetic in this version, but could be).

2. **Collision model**: Each obstacle is checked exactly once as it passes through a narrow Y-band near the player (y=440..490). A `checked` flag prevents re-triggering. The FSM adds a 30-frame hit cooldown for invincibility.

3. **LFSR randomness**: A single 16-bit LFSR runs at 40 MHz. Different bit slices are used by the obstacle and coin managers to select lane, type, and spawn interval, providing uncorrelated randomness.

4. **Pixel rendering**: All pixel checks are combinational and run in parallel. Each module outputs a `_pixel` flag; the renderer prioritizes them to produce the final color. This avoids frame buffers and RAM.

5. **Scrolling effect**: Cross-ties on the track use `(row + scroll_offset) % 32` (implemented as bit truncation since 32 is a power of 2) to create the illusion of forward motion.

## Building

**No IP core generation required.** All modules are pure RTL + Xilinx 7-series primitives.

1. Create a new Vivado project targeting your FPGA (e.g., `xc7s50csga324-1` for Boolean board)
2. Add all `.sv` files from this directory as design sources
3. Add `boolean.xdc` as a constraint file (ensure the `create_clock` constraint is active)
4. Set `ChipInterface` as the top module
5. Run synthesis, implementation, and bitstream generation
6. Program the FPGA and play!

> **Note:** The `clock_gen.sv` and `hdmi_tx.sv` modules use Xilinx 7-series primitives
> (MMCME2_BASE, BUFG, OSERDESE2, OBUFDS). These are recognized natively by Vivado and
> require no IP catalog configuration. The design is self-contained in the `.sv` files.

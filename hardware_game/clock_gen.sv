// `default_nettype none

/*
 * Clock Generator - Replaces clk_wiz_0 IP core
 *
 * Directly instantiates the Xilinx 7-series MMCME2_BASE primitive
 * to generate the required clocks from the 100 MHz board oscillator.
 *
 * MMCM Configuration:
 *   VCO = 100 MHz * 10 / 1 = 1000 MHz
 *   clk_out1 = 1000 / 25 = 40 MHz   (VGA pixel clock)
 *   clk_out2 = 1000 / 5  = 200 MHz  (HDMI 5x serializer clock)
 *
 * Port names match the clk_wiz_0 IP for easy substitution.
 * No IP generation required -- Vivado knows these primitives natively.
 */
module clock_gen (
  input  logic clk_in1,     // 100 MHz board clock
  input  logic reset,       // Active-high reset
  output logic clk_out1,    // 40 MHz pixel clock
  output logic clk_out2,    // 200 MHz serializer clock
  output logic locked       // PLL locked indicator
);

  logic clkfb, clkfb_buf;
  logic clk0_unbuf, clk1_unbuf;

  MMCME2_BASE #(
    .BANDWIDTH       ("OPTIMIZED"),
    .CLKFBOUT_MULT_F (10.0),       // VCO = 100 * 10 = 1000 MHz
    .CLKFBOUT_PHASE  (0.0),
    .CLKIN1_PERIOD   (10.0),       // 100 MHz = 10 ns period
    .CLKOUT0_DIVIDE_F(25.0),       // 1000 / 25 = 40 MHz
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE   (0.0),
    .CLKOUT1_DIVIDE  (5),          // 1000 / 5 = 200 MHz
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE   (0.0),
    .DIVCLK_DIVIDE   (1),
    .REF_JITTER1     (0.01),
    .STARTUP_WAIT    ("FALSE")
  ) mmcm_inst (
    .CLKOUT0   (clk0_unbuf),
    .CLKOUT0B  (),
    .CLKOUT1   (clk1_unbuf),
    .CLKOUT1B  (),
    .CLKOUT2   (),
    .CLKOUT2B  (),
    .CLKOUT3   (),
    .CLKOUT3B  (),
    .CLKOUT4   (),
    .CLKOUT5   (),
    .CLKOUT6   (),
    .CLKFBOUT  (clkfb),
    .CLKFBOUTB (),
    .LOCKED    (locked),
    .CLKIN1    (clk_in1),
    .PWRDWN    (1'b0),
    .RST       (reset),
    .CLKFBIN   (clkfb_buf)
  );

  // Global clock buffers for each output
  BUFG bufg_fb  (.I(clkfb),      .O(clkfb_buf));
  BUFG bufg_pix (.I(clk0_unbuf), .O(clk_out1));
  BUFG bufg_ser (.I(clk1_unbuf), .O(clk_out2));

endmodule: clock_gen

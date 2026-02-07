// `default_nettype none

/*
 * HDMI Transmitter - Replaces hdmi_tx_0 IP core
 *
 * Implements DVI-mode HDMI output using only Xilinx 7-series primitives:
 *   - TMDS 8b/10b encoding (3 channels: R, G, B)
 *   - 10:1 DDR serialization via OSERDESE2 master/slave pairs
 *   - Differential output via OBUFDS
 *
 * The blue channel (channel 0) carries hsync/vsync during blanking.
 * Green and red channels carry CTL=0 during blanking.
 * The clock channel sends a fixed 0000011111 pattern.
 *
 * Port names match the hdmi_tx_0 IP for easy substitution.
 * No IP generation required.
 */

// ============================================================
//  TMDS 8b/10b Encoder (DVI 1.0 Specification)
// ============================================================
module tmds_encoder (
  input  logic       clk,
  input  logic       rst,
  input  logic [7:0] din,
  input  logic       c0,
  input  logic       c1,
  input  logic       de,
  output logic [9:0] q_out
);

  // --- Count ones in input data ---
  logic [3:0] n1_din;
  assign n1_din = din[0] + din[1] + din[2] + din[3] +
                  din[4] + din[5] + din[6] + din[7];

  // --- Stage 1: Transition minimization (XOR or XNOR) ---
  logic use_xnor;
  assign use_xnor = (n1_din > 4'd4) || (n1_din == 4'd4 && !din[0]);

  logic [8:0] q_m;
  always_comb begin
    q_m[0] = din[0];
    if (use_xnor) begin
      q_m[1] = q_m[0] ~^ din[1];
      q_m[2] = q_m[1] ~^ din[2];
      q_m[3] = q_m[2] ~^ din[3];
      q_m[4] = q_m[3] ~^ din[4];
      q_m[5] = q_m[4] ~^ din[5];
      q_m[6] = q_m[5] ~^ din[6];
      q_m[7] = q_m[6] ~^ din[7];
      q_m[8] = 1'b0;
    end else begin
      q_m[1] = q_m[0] ^ din[1];
      q_m[2] = q_m[1] ^ din[2];
      q_m[3] = q_m[2] ^ din[3];
      q_m[4] = q_m[3] ^ din[4];
      q_m[5] = q_m[4] ^ din[5];
      q_m[6] = q_m[5] ^ din[6];
      q_m[7] = q_m[6] ^ din[7];
      q_m[8] = 1'b1;
    end
  end

  // --- Count ones/zeros in q_m[7:0] ---
  logic [3:0] n1_qm;
  assign n1_qm = q_m[0] + q_m[1] + q_m[2] + q_m[3] +
                 q_m[4] + q_m[5] + q_m[6] + q_m[7];

  // Signed intermediates for DC balance arithmetic
  logic signed [4:0] n1s, n0s, two_qm8, neg_two_nqm8;
  assign n1s = {1'b0, n1_qm};               // ones count as signed (0..8)
  assign n0s = 5'sd8 - n1s;                  // zeros count as signed
  assign two_qm8 = q_m[8] ? 5'sd2 : 5'sd0;  // 2 * q_m[8]
  assign neg_two_nqm8 = q_m[8] ? 5'sd0 : -5'sd2; // -2 * (1 - q_m[8])

  // --- Stage 2: DC balance with running disparity counter ---
  logic signed [4:0] cnt;

  always_ff @(posedge clk) begin
    if (rst) begin
      q_out <= 10'd0;
      cnt   <= 5'sd0;
    end else if (!de) begin
      // Blanking: send control tokens, reset DC balance
      cnt <= 5'sd0;
      case ({c1, c0})
        2'b00:   q_out <= 10'b1101010100;
        2'b01:   q_out <= 10'b0010101011;
        2'b10:   q_out <= 10'b0101010100;
        default: q_out <= 10'b1010101011;
      endcase
    end else begin
      // Active video: encode with DC balance
      if (cnt == 5'sd0 || n1_qm == 4'd4) begin
        // Balanced or zero disparity
        q_out[9]   <= ~q_m[8];
        q_out[8]   <=  q_m[8];
        q_out[7:0] <= q_m[8] ? q_m[7:0] : ~q_m[7:0];
        if (!q_m[8])
          cnt <= cnt + (n0s - n1s);
        else
          cnt <= cnt + (n1s - n0s);
      end
      else if ((cnt > 5'sd0 && n1_qm > 4'd4) ||
               (cnt < 5'sd0 && n1_qm < 4'd4)) begin
        // Need to reduce disparity: invert data
        q_out[9]   <= 1'b1;
        q_out[8]   <= q_m[8];
        q_out[7:0] <= ~q_m[7:0];
        cnt <= cnt + two_qm8 + (n0s - n1s);
      end
      else begin
        // Default: pass data through
        q_out[9]   <= 1'b0;
        q_out[8]   <= q_m[8];
        q_out[7:0] <= q_m[7:0];
        cnt <= cnt + neg_two_nqm8 + (n1s - n0s);
      end
    end
  end

endmodule: tmds_encoder

// ============================================================
//  10:1 DDR Serializer (OSERDESE2 master/slave + OBUFDS)
// ============================================================
module serializer_10to1 (
  input  logic       clk_fast,   // 5x pixel clock (200 MHz)
  input  logic       clk_slow,   // 1x pixel clock (40 MHz)
  input  logic       rst,
  input  logic [9:0] data_in,    // 10-bit parallel data
  output logic       serial_p,   // TMDS+ output
  output logic       serial_n    // TMDS- output
);

  logic serial_out;
  logic cascade1, cascade2;

  OSERDESE2 #(
    .DATA_RATE_OQ ("DDR"),
    .DATA_RATE_TQ ("SDR"),
    .DATA_WIDTH   (10),
    .SERDES_MODE  ("MASTER"),
    .TRISTATE_WIDTH(1),
    .TBYTE_CTL    ("FALSE"),
    .TBYTE_SRC    ("FALSE")
  ) oserdes_master (
    .CLK      (clk_fast),
    .CLKDIV   (clk_slow),
    .D1       (data_in[0]),
    .D2       (data_in[1]),
    .D3       (data_in[2]),
    .D4       (data_in[3]),
    .D5       (data_in[4]),
    .D6       (data_in[5]),
    .D7       (data_in[6]),
    .D8       (data_in[7]),
    .OCE      (1'b1),
    .OFB      (),
    .OQ       (serial_out),
    .RST      (rst),
    .SHIFTIN1 (cascade1),
    .SHIFTIN2 (cascade2),
    .SHIFTOUT1(),
    .SHIFTOUT2(),
    .T1       (1'b0),
    .T2       (1'b0),
    .T3       (1'b0),
    .T4       (1'b0),
    .TBYTEIN  (1'b0),
    .TCE      (1'b0),
    .TBYTEOUT (),
    .TFB      (),
    .TQ       ()
  );

  OSERDESE2 #(
    .DATA_RATE_OQ ("DDR"),
    .DATA_RATE_TQ ("SDR"),
    .DATA_WIDTH   (10),
    .SERDES_MODE  ("SLAVE"),
    .TRISTATE_WIDTH(1),
    .TBYTE_CTL    ("FALSE"),
    .TBYTE_SRC    ("FALSE")
  ) oserdes_slave (
    .CLK      (clk_fast),
    .CLKDIV   (clk_slow),
    .D1       (1'b0),
    .D2       (1'b0),
    .D3       (data_in[8]),
    .D4       (data_in[9]),
    .D5       (1'b0),
    .D6       (1'b0),
    .D7       (1'b0),
    .D8       (1'b0),
    .OCE      (1'b1),
    .OFB      (),
    .OQ       (),
    .RST      (rst),
    .SHIFTIN1 (1'b0),
    .SHIFTIN2 (1'b0),
    .SHIFTOUT1(cascade1),
    .SHIFTOUT2(cascade2),
    .T1       (1'b0),
    .T2       (1'b0),
    .T3       (1'b0),
    .T4       (1'b0),
    .TBYTEIN  (1'b0),
    .TCE      (1'b0),
    .TBYTEOUT (),
    .TFB      (),
    .TQ       ()
  );

  OBUFDS obuf_inst (
    .I  (serial_out),
    .O  (serial_p),
    .OB (serial_n)
  );

endmodule: serializer_10to1

// ============================================================
//  HDMI Transmitter Top-Level
// ============================================================
module hdmi_tx (
  input  logic       pix_clk,        // 40 MHz pixel clock
  input  logic       pix_clkx5,      // 200 MHz serializer clock
  input  logic       pix_clk_locked, // MMCM locked signal
  input  logic       rst,            // Active-high reset
  input  logic [7:0] red,
  input  logic [7:0] green,
  input  logic [7:0] blue,
  input  logic       hsync,
  input  logic       vsync,
  input  logic       vde,            // Video Data Enable (active region)
  output logic       TMDS_CLK_P,
  output logic       TMDS_CLK_N,
  output logic [2:0] TMDS_DATA_P,
  output logic [2:0] TMDS_DATA_N
);

  // Serializer reset: active when user reset OR clocks not stable
  logic ser_rst;
  assign ser_rst = rst | ~pix_clk_locked;

  // --- TMDS Encoding ---
  // Channel 0 (Blue):  carries hsync, vsync during blanking
  // Channel 1 (Green): CTL = 0 during blanking
  // Channel 2 (Red):   CTL = 0 during blanking
  logic [9:0] tmds_blue, tmds_green, tmds_red;

  tmds_encoder enc_blue (
    .clk(pix_clk), .rst(ser_rst),
    .din(blue), .c0(hsync), .c1(vsync), .de(vde),
    .q_out(tmds_blue)
  );

  tmds_encoder enc_green (
    .clk(pix_clk), .rst(ser_rst),
    .din(green), .c0(1'b0), .c1(1'b0), .de(vde),
    .q_out(tmds_green)
  );

  tmds_encoder enc_red (
    .clk(pix_clk), .rst(ser_rst),
    .din(red), .c0(1'b0), .c1(1'b0), .de(vde),
    .q_out(tmds_red)
  );

  // --- Clock channel: fixed 0000011111 pattern ---
  // 5 low bits followed by 5 high bits = pixel clock frequency
  localparam [9:0] TMDS_CLK_PATTERN = 10'b0000011111;

  // --- 10:1 Serialization ---
  // Data channels
  serializer_10to1 ser_blue (
    .clk_fast(pix_clkx5), .clk_slow(pix_clk), .rst(ser_rst),
    .data_in(tmds_blue),
    .serial_p(TMDS_DATA_P[0]), .serial_n(TMDS_DATA_N[0])
  );

  serializer_10to1 ser_green (
    .clk_fast(pix_clkx5), .clk_slow(pix_clk), .rst(ser_rst),
    .data_in(tmds_green),
    .serial_p(TMDS_DATA_P[1]), .serial_n(TMDS_DATA_N[1])
  );

  serializer_10to1 ser_red (
    .clk_fast(pix_clkx5), .clk_slow(pix_clk), .rst(ser_rst),
    .data_in(tmds_red),
    .serial_p(TMDS_DATA_P[2]), .serial_n(TMDS_DATA_N[2])
  );

  // Clock channel
  serializer_10to1 ser_clk (
    .clk_fast(pix_clkx5), .clk_slow(pix_clk), .rst(ser_rst),
    .data_in(TMDS_CLK_PATTERN),
    .serial_p(TMDS_CLK_P), .serial_n(TMDS_CLK_N)
  );

endmodule: hdmi_tx

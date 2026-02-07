// Required in every 18-240 file, but commented out to prevent synthesis issues
// `default_nettype none

/*
 * This module should be interfaced with a combinational 7-Segment Display
 * module in order to display 8 BCD values upon the Boolean board. It is
 * intended to abstract away the sequential logic required to use the
 * 7-Segment Displays present on the Boolean Board for 18-240 students.
 *
 * Date:   1/27/25
 * Author: Rudy Sorensen (rsorense)
 * 4 Feb 2025, WAN: Modified significantly for Lab 2
 */
 
module EightSevenSegmentDisplays
  (input  logic [3:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
   input  logic       CLOCK_100, reset,
   input  logic [7:0] dec_points,
   input  logic [7:0] blank,
   output logic [3:0] D2_AN, D1_AN,
   output logic [7:0] D2_SEG, D1_SEG);

  logic [7:0] segments7, segments6, segments5, segments4, 
              segments3, segments2, segments1, segments0;

   SevenSegmentDisplay ssd(.num7(HEX7), 
                           .num6(HEX6), 
                           .num5(HEX5), 
                           .num4(HEX4), 
                           .num3(HEX3), 
                           .num2(HEX2), 
                           .num1(HEX1), 
                           .num0(HEX0),
                           .blank,
                           .dec_points,
                           .HEX7(segments7), 
                           .HEX6(segments6), 
                           .HEX5(segments5), 
                           .HEX4(segments4), 
                           .HEX3(segments3), 
                           .HEX2(segments2), 
                           .HEX1(segments1), 
                           .HEX0(segments0)
                          );

  logic cycle_cnt_clr;
  logic index_cnt_en;
  logic [1:0] anode_index;
  logic [3:0] anode_index_onecold;
  logic [16:0] cycle_cnt;
  /*
   * This counter reset value should be calculated by hand using the frequency
   * of your source clock to achieve the target frequency of 250Hz to 10KHz.
   *
   * The lower limit to the frequency comes from the fact that the human eye
   * de-saturates after around 20ms, while the upper limit is derived from the
   * need for the display to be on for at least 100us so that the value can
   * actually be perceived.
   *
   * Since the Boolean board has a 100MHz clock, we will count to 100,000. This
   * means that each segment will be lit for 1ms and flashed again 3ms later
   * because we are cycling through 4 values for each segment.
   */

  localparam CNT_LIMIT = 17'd100_000;

  assign cycle_cnt_clr = cycle_cnt == CNT_LIMIT;
  assign index_cnt_en = cycle_cnt_clr;

  SSDCounter #(17) cycle_cntr (
    .CLOCK_100,
    .reset,
    .clr(cycle_cnt_clr),
    .cnt(cycle_cnt),
    .en(1'b1)
    );

  SSDCounter #(2) index_cntr (
    .CLOCK_100,
    .reset,
    .clr(1'b0),
    .cnt(anode_index),
    .en(index_cnt_en)
    );

  OneColdDecoder #(4) anode_decode (
    .sel(anode_index),
    .out(anode_index_onecold)
    );

  always_comb begin
    D1_AN = anode_index_onecold;
    D2_AN = anode_index_onecold;

    case (anode_index)
      2'd0: begin
        D2_SEG = segments0;
        D1_SEG = segments4;
      end
      2'd1: begin
        D2_SEG = segments1;
        D1_SEG = segments5;
      end
      2'd2: begin
        D2_SEG = segments2;
        D1_SEG = segments6;
      end
      2'd3: begin
        D2_SEG = segments3;
        D1_SEG = segments7;
      end
    endcase

  end
 
endmodule : EightSevenSegmentDisplays
 
module OneColdDecoder #(
  parameter NUM_OUTPUTS = 4
  ) (
  input  logic [$clog2(NUM_OUTPUTS)-1:0] sel,
  output logic [NUM_OUTPUTS-1:0] out
  );

  always_comb begin
    out = {NUM_OUTPUTS{1'b1}};
    out[sel] = 1'b0;
  end

endmodule : OneColdDecoder

module SSDCounter #(
  parameter WIDTH = 8
  ) (
  input  logic CLOCK_100,
  input  logic reset,
  input  logic clr,
  input  logic en,
  output logic [WIDTH-1:0] cnt
  );

  always_ff @(posedge CLOCK_100, posedge reset) begin
    if (reset)
      cnt <= '0;
    else if (clr)
      cnt <= '0;
    else if (en)
      cnt <= cnt + 1'b1;
  end

endmodule : SSDCounter
 
/*
 *  This is essentially the SevenSegmentDisplay from HW2. There are
 *  two differences.  Firstly, it correctly decodes hexadecimal values
 *  and not just BCD values.  Secondly, the dec_points input allows
 *  the decimal points on the 8 displays to be illuminated.
 */
module SevenSegmentDisplay
  (input logic [3:0] num7, num6, num5, num4, num3, num2, num1, num0,
   input logic [7:0] blank,
   input logic [7:0] dec_points,
   output logic [7:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);

   logic [6:0] seg7, seg6, seg5, seg4, seg3, seg2, seg1, seg0;

   HextoSevenSegment digit0(.hex(num0), .segment(seg0));
   HextoSevenSegment digit1(.hex(num1), .segment(seg1));
   HextoSevenSegment digit2(.hex(num2), .segment(seg2));
   HextoSevenSegment digit3(.hex(num3), .segment(seg3));
   HextoSevenSegment digit4(.hex(num4), .segment(seg4));
   HextoSevenSegment digit5(.hex(num5), .segment(seg5));
   HextoSevenSegment digit6(.hex(num6), .segment(seg6));
   HextoSevenSegment digit7(.hex(num7), .segment(seg7));

   assign HEX0 = (blank[0]) ? '1 : {~dec_points[0], seg0};
   assign HEX1 = (blank[1]) ? '1 : {~dec_points[1], seg1};
   assign HEX2 = (blank[2]) ? '1 : {~dec_points[2], seg2};
   assign HEX3 = (blank[3]) ? '1 : {~dec_points[3], seg3};
   assign HEX4 = (blank[4]) ? '1 : {~dec_points[4], seg4};
   assign HEX5 = (blank[5]) ? '1 : {~dec_points[5], seg5};
   assign HEX6 = (blank[6]) ? '1 : {~dec_points[6], seg6};
   assign HEX7 = (blank[7]) ? '1 : {~dec_points[7], seg7};
   
endmodule: SevenSegmentDisplay

/*
 * Very similar to the BCDtoSevenSegment module from HW2, but
 * now with hex support!
 */
module HextoSevenSegment
  (input  logic [3:0] hex,
   output logic [6:0] segment);

  always_comb
    unique case (hex)
      4'h0: segment = 7'b1000000;
      4'h1: segment = 7'b1111001;
      4'h2: segment = 7'b0100100;
      4'h3: segment = 7'b0110000;
      4'h4: segment = 7'b0011001;
      4'h5: segment = 7'b0010010;
      4'h6: segment = 7'b0000010;
      4'h7: segment = 7'b1111000;
      4'h8: segment = 7'b0000000; 
      4'h9: segment = 7'b0011000;
      4'hA: segment = 7'b0001000;
      4'hB: segment = 7'b0000011;
      4'hC: segment = 7'b1000110;
      4'hD: segment = 7'b0100001;
      4'hE: segment = 7'b0000110;
      4'hF: segment = 7'b0001110;
    endcase

endmodule : HextoSevenSegment

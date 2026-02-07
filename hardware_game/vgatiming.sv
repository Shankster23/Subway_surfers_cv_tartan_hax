// `default_nettype none

`define DATA_WIDTH 11

/*
This module produces our vga timing signals, so that we know which (row, col)
pair to display to at a given clock cycle. We use a bunch of counters to keep
track of the number of clock cycles that are passing and to keep track of the
number of lines that have occured. We produce our outputs based on this.
*/
module vga
  (input logic clock_40MHz, reset,
   output logic HS, VS, blank,
   output logic [9:0] row, col);

  logic [`DATA_WIDTH  - 1:0] counter1_out, counter2_out;
  logic offset1_out, offset2_out;
  logic clear_counters;
  logic [10:0] tmp_row, tmp_col;
  
  // Counts number of clocks in 1 line
  Counter #(`DATA_WIDTH) counter1 (
                         .clock(clock_40MHz), 
                         .en(1'b1), 
                         .clear(reset | comp1_out),
                         .load(1'b0), 
                         .up(1'b1),
                         .D('0),
                         .Q(counter1_out));

  // Counts number of lines
  Counter #(`DATA_WIDTH) counter2 (
                         .clock(clock_40MHz), 
                         .en(comp1_out), 
                         .clear(reset | (comp2_out & comp1_out)),
                         .load(1'b0), 
                         .up(1'b1),
                         .D('0),
                         .Q(counter2_out));
  
  // Resets counter1
  Comparator #(`DATA_WIDTH) comp1 (
                            .A(counter1_out),
                            .B(11'd1055),
                            .AeqB(comp1_out));
  
  // Resets counter2
  Comparator #(`DATA_WIDTH) comp2 (
                            .A(counter2_out),
                            .B(11'd627),
                            .AeqB(comp2_out));
  
  // Check if enough lines have passed for VS
  MagComp #(`DATA_WIDTH) magcomp1 (
                         .A(counter2_out),
                         .B(11'd3),
                         .AgtB(VS),
                         .AeqB(),
                         .AltB());
  
  // Check if enough clocks have passed for HS
  MagComp #(`DATA_WIDTH) magcomp2 (
                         .A(counter1_out),
                         .B(11'd127),
                         .AgtB(HS),
                         .AeqB(),
                         .AltB());
  
  // Check if we are in T-disp for VS
  OffsetCheck #(`DATA_WIDTH) offset1 (
                             .delta(11'd599),
                             .low(11'd27),
                             .val(counter2_out),
                             .is_between(offset1_out));
  
  // Check if we are in T-disp for HS
  OffsetCheck #(`DATA_WIDTH) offset2 (
                             .delta(11'd799),
                             .low(11'd216),
                             .val(counter1_out),
                             .is_between(offset2_out));
    
  assign blank = ~(offset1_out & offset2_out);
  assign tmp_row = counter2_out - 11'd27;
  assign tmp_col = counter1_out - 11'd216;
  assign row = tmp_row[9:0];
  assign col = tmp_col[9:0];
                      
endmodule: vga

/*
This module produces a basic test pattern that checks our vga signal
generation implementation. We divide the top half of the screen into
8 parts and display the 8 colors discussed in the writeup (one in each
part). We output a blanks signal for the bottom half of the screen, so 
the bottom half of the display is just black.
*/
module test_pattern_generator
  (input  logic [9:0] row, col,
   output logic [7:0] red, green, blue);
  
  logic red1_out;
  logic green1_out, green2_out;
  logic blue1_out, blue2_out, blue3_out, blue4_out;
  logic row_out;

  logic red_mux_sel;
  logic green_mux_sel;
  logic blue_mux_sel;

  // Range Checks to divide the screen into 8 parts
  RangeCheck #(10) red1 (
                   .val(col),
                   .low(10'd400),
                   .high(10'd799),
                   .is_between(red1_out));
  
  RangeCheck #(10) green1 (
                   .val(col),
                   .low(10'd200),
                   .high(10'd399),
                   .is_between(green1_out));
  
  RangeCheck #(10) green2 (
                   .val(col),
                   .low(10'd600),
                   .high(10'd799),
                   .is_between(green2_out));
  
  RangeCheck #(10) blue1 (
                   .val(col),
                   .low(10'd100),
                   .high(10'd199),
                   .is_between(blue1_out));

  RangeCheck #(10) blue2 (
                   .val(col),
                   .low(10'd300),
                   .high(10'd399),
                   .is_between(blue2_out));
  
  RangeCheck #(10) blue3 (
                   .val(col),
                   .low(10'd500),
                   .high(10'd599),
                   .is_between(blue3_out));
  
  RangeCheck #(10) blue4 (
                   .val(col),
                   .low(10'd700),
                   .high(10'd799),
                   .is_between(blue4_out));
  
  RangeCheck #(10) row_check (
                   .val(row),
                   .low(10'd0),
                   .high(10'd299),
                   .is_between(row_out));
  
  // Selecting between red, green, and blue
  assign red_mux_sel = red1_out & row_out;
  assign green_mux_sel = (green1_out | green2_out) & row_out;
  assign blue_mux_sel = (blue1_out | blue2_out | blue3_out | blue4_out) 
                       & row_out;
  
  Mux2to1 #(8) red_mux (
               .I0(8'h00),
               .I1(8'hFF),
               .S(red_mux_sel),
               .Y(red));
  
  Mux2to1 #(8) green_mux (
               .I0(8'h00),
               .I1(8'hFF),
               .S(green_mux_sel),
               .Y(green));
  
  Mux2to1 #(8) blue_mux (
               .I0(8'h00),
               .I1(8'hFF),
               .S(blue_mux_sel),
               .Y(blue));

endmodule: test_pattern_generator

/*
This module tests the test pattern generator which was used to make
sure that we got all of ur timing correct. We pulled variables from this 
in the waveform viewer w/ VCS to check correctness bp, fp, tdisp, etc. 
*/
module testbench();
  logic clock_40MHz, reset;
  logic [9:0] row, col;
  logic [7:0] red, green, blue;
  logic HS, VS, blank;
   
  vga disp (.*);
  test_pattern_generator pattern_generate (.*);

  initial clock_40MHz = 0;
  always #10 clock_40MHz = ~clock_40MHz;
  
  initial begin
    reset = 1;
    #10 reset = 0;
    #40000000 $finish;
  end

endmodule: testbench

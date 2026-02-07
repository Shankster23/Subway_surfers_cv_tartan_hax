// `default_nettype none

// Checks equality between two inputs
module Comparator #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] A, B,
   output logic AeqB);
  
  assign AeqB = (A == B) ? 1 : 0;

endmodule: Comparator

// Compares two inputs and produces gt, lt, eq outputs
module MagComp #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] A, B,
   output logic AltB, AeqB, AgtB);

  assign AltB = (A < B);
  assign AeqB = (A == B);
  assign AgtB = (A > B);

endmodule: MagComp

// Adds two numbers
module Adder #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] A, B,
   input logic cin, 
   output logic [WIDTH - 1:0] sum,
   output logic cout);
  
  assign {cout, sum} = A + B + cin;

endmodule: Adder

// Subtracts input B from input A
module Subtractor #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] A, B,
   input logic bin,
   output logic [WIDTH - 1:0] diff,
   output logic bout);
 
  assign {bout, diff} = A - B - bin;

endmodule: Subtractor

// Selects one value between I inputs
module Multiplexer #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] I,
   input logic [$clog2(WIDTH) - 1:0] S,
   output logic Y);

  assign Y = I[S];

endmodule: Multiplexer

// Selects one value between 2 inputs
module Mux2to1 #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] I0, I1,
   input logic S,
   output logic [WIDTH - 1:0] Y);

  assign Y = (S) ? I1 : I0;

endmodule: Mux2to1

// Produces a one-hot output based on select bits
module Decoder #(parameter WIDTH = 8)
  (input logic [$clog2(WIDTH) - 1:0] I,
   input logic en,
   output logic [WIDTH - 1:0] D);

  always_comb begin
    D = '0;
    if (en) D[I] = 1'b1;
  end

endmodule: Decoder

// Stores one bit
module dFlipFlop
  (input logic D, clock, 
   input logic preset_L, reset_L,
   output logic Q);

  always_ff @(posedge clock, negedge preset_L, negedge reset_L) begin
    if (~reset_L) Q <= 1'b0;
    else if (~preset_L) Q <= 1'b1;
    else Q <= D;
  end

endmodule: dFlipFlop

// Multi-bit storage (collection of multiple flip flops)
module Register #(parameter WIDTH = 8)
  (input logic en, clear, clock,
   input logic [WIDTH - 1:0] D,
   output logic [WIDTH - 1:0] Q);

  always_ff @(posedge clock) begin
    if (en) Q <= D;
    else if (clear) Q <= '0;
  end

endmodule: Register

// Increments or decrements a value by 1
module Counter #(parameter WIDTH = 8)
  (input logic clock, en, clear, load, up,
   input logic [WIDTH - 1:0] D,
   output logic [WIDTH - 1:0] Q);
  
  always_ff @(posedge clock) begin
    if (clear) Q <= '0;
    else if (load) Q <= D;
    else if (en) begin
      if (up) Q <= Q + 1;
      else Q <= Q - 1;
    end
  end

endmodule: Counter

// Shifts a value with serial input parallel output
module ShiftRegisterSIPO #(parameter WIDTH = 8)
  (input logic clock, en, left,
   input logic serial,
   output logic [WIDTH - 1:0] Q);

  always_ff @(posedge clock) begin
    if (en)
      if (left) Q <= {Q[WIDTH - 2:0], serial};
      else      Q <= {serial, Q[WIDTH - 1:1]};
  end

endmodule: ShiftRegisterSIPO

// Shifts a value with parallel input parallel output
module ShiftRegisterPIPO #(parameter WIDTH = 8)
  (input logic clock, en, left, load,
   input logic [WIDTH - 1:0] D,
   output logic [WIDTH - 1:0] Q);

  always_ff @(posedge clock) begin
    if (load) Q <= D;
    else if (en)
      if (left) Q <= {Q[WIDTH - 2:0], 1'b0};
      else      Q <= {1'b0, Q[WIDTH - 1:1]};
  end

endmodule: ShiftRegisterPIPO

// Shifts a value by a specified number of bits
module BarrelShiftRegister #(parameter WIDTH = 8)
  (input logic clock, en, load,
   input logic [1:0] by,
   input logic [WIDTH - 1:0] D,
   output logic [WIDTH - 1:0] Q);

  always_ff @(posedge clock) begin
    if (load) Q <= D;
    else if (en) Q <= D << by;
  end

endmodule: BarrelShiftRegister

// Synchronizes an input to the clock
module Synchronizer
  (input logic async, clock,
   output logic sync);
  
  logic q1;
  always_ff @(posedge clock) begin
    q1 <= async;
    sync <= q1;
  end

endmodule: Synchronizer

// Safely allows for a tristate line with two antiparallel tri-state drivers
module BusDriver #(parameter WIDTH = 8)
  (input logic en,
   input logic [WIDTH - 1:0] data,
   output logic [WIDTH - 1:0] buff,
   inout tri [WIDTH - 1:0] bus);

  assign bus = (en) ? data : 'z;
  assign buff = bus;

endmodule: BusDriver

/*
Holds a variable width and varaible amount of registers that can be accessed
via an address input 
*/
module Memory #(parameter DW = 16, W = 256, AW = $clog2(W))
  (input logic re, we, clock,
   input logic [AW - 1:0] addr,
   inout tri   [DW - 1:0] data);

  logic [DW - 1:0] M[W];
  logic [DW - 1:0] rData;

  assign rData = M[addr];
  assign data = (re) ? rData: 'z;

  always_ff @(posedge clock) begin
    if (we)
      M[addr] <= data;
  end

endmodule: Memory

// checks that low <= val <= high
module RangeCheck #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] high, low, val,
   output logic is_between);

  always_comb begin
    if ((low <= val) && (val <= high))
      is_between = 1'b1;
    else
      is_between = 1'b0;
  end

endmodule: RangeCheck

// checks that low <= val <= low + delta
module OffsetCheck #(parameter WIDTH = 8)
  (input logic [WIDTH - 1:0] delta, low, val,
   output logic is_between);

  logic [WIDTH - 1:0] high;
  assign high = low + delta;

  RangeCheck #(WIDTH) r1 (.high, .low, .val, .is_between);

endmodule: OffsetCheck

// `default_nettype none

/*
 * 16-bit Linear Feedback Shift Register (LFSR)
 *
 * Generates pseudo-random numbers for obstacle/coin spawning.
 * Uses maximal-length polynomial: x^16 + x^14 + x^13 + x^11 + 1
 * This provides a period of 2^16 - 1 = 65535 before repeating.
 *
 * The LFSR advances every clock cycle when enabled, providing
 * good randomness when sampled at the slower frame rate (~60 Hz).
 */
module lfsr
  (input  logic clock, reset, enable,
   output logic [15:0] val);

  logic feedback;
  assign feedback = val[15] ^ val[13] ^ val[12] ^ val[10];

  always_ff @(posedge clock or posedge reset) begin
    if (reset)
      val <= 16'hACE1;  // Non-zero seed (LFSR must never be all-zeros)
    else if (enable)
      val <= {val[14:0], feedback};
  end

endmodule: lfsr

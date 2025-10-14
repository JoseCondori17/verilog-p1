module alu (
  input [31 : 0] op_a,
  input [31 : 0] op_b,
  input [1:0] op_code, // 00: add, 01: sub, 10: mul, 11: div
  input mode_fp, // 0: half, 1: single
  input clk,
  input rst,
  input round_mode,
  input start,

  output reg [31 : 0] result,
  output valid_out,
  output reg [4:0] flags // [0]: inexact, [1]: underflow, [2]: overflow, [3]: div_by_0, [4]: invalid
);



endmodule


/*
  references:

  - IEEE 754: https://en.wikipedia.org/wiki/IEEE_754
  - IEEE 754-1985: https://en.wikipedia.org/wiki/IEEE_754-1985
  - CS341: https://web.archive.org/web/20070505021348/http://babbage.cs.qc.edu/courses/cs341/IEEE-754references.html
*/
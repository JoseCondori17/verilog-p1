module alu #(
  parameter exp = 8,
  parameter frac = 23,
  parameter width = exp + frac + 1
) (
  input [width - 1 : 0] op_a,
  input [width - 1 : 0] op_b,
  input [1:0] op_code, // 00: add, 01: sub, 10: mul, 11: div
  input round_mode,

  output reg [width - 1 : 0] result,
  output reg [4:0] flags // [0]: inexact, [1]: underflow, [2]: overflow, [3]: div_by_0, [4]: invalid
);
  wire [width - 1 : 0] r_sum, r_sub, r_mul, r_div;
  wire [4 : 0] f_sum, f_sub, f_mul, f_div;

  wire [width-1:0] neg_b = {~op_b[width-1], op_b[width-2:0]};

  fadd #(exp, frac) add(op_a, op_b, round_mode, r_sum, f_sum);
  fadd #(exp, frac) sub(op_a, neg_b, round_mode, r_sub, f_sub);
  fmul #(exp, frac) mul(op_a, op_b, round_mode, r_mul, f_mul);
  fdiv #(exp, frac) div(op_a, op_b, round_mode, r_div, f_div);

  always @(*) begin
    case (op_code)
      2'b00: begin
        result = r_sum;
        flags = f_sum;
      end
      2'b01: begin
        result = r_sub;
        flags = f_sub;
      end
      2'b10: begin
        result = r_mul;
        flags = f_mul;
      end
      2'b11: begin
        result = r_div;
        flags = f_div;
      end
    endcase
  end
endmodule


/*
  references:

  - IEEE 754: https://en.wikipedia.org/wiki/IEEE_754
  - IEEE 754-1985: https://en.wikipedia.org/wiki/IEEE_754-1985
  - CS341: https://web.archive.org/web/20070505021348/http://babbage.cs.qc.edu/courses/cs341/IEEE-754references.html
*/
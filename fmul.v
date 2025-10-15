module fmul #(
  parameter exp = 8,
  parameter frac = 23,
  parameter width = exp + frac + 1
) (
  input [width - 1 : 0] a,
  input [width - 1 : 0] b,
  input round_mode, // 1: nearest, 0: truncate
  output reg [width- 1 : 0] r,
  output reg [3 : 0] flags
);
  // flag bits- positions
  localparam INVALID_FLAG   = 4;
  localparam DIVZERO_FLAG   = 3; // no used
  localparam OVERFLOW_FLAG  = 2;
  localparam UNDERFLOW_FLAG = 1;
  localparam INEXACT_FLAG   = 0;

  // divide into sign, exponent, fraction
  wire sign_a = a[width - 1];
  wire sign_b = b[width - 1];
  wire [exp - 1 : 0] exp_a = a[width - 2 : frac];
  wire [exp - 1 : 0] exp_b = b[width - 2 : frac];
  wire [frac- 1 : 0] frac_a = a[frac - 1 : 0];
  wire [frac- 1 : 0] frac_b = b[frac - 1 : 0];
  reg bias = (1 << (exp - 1)) - 1;

  // "a" properties
  wire is_exp_a_max   = &exp_a;
  wire is_exp_a_zero  = ~|exp_a;
  wire is_frac_a_zero = ~|frac_a;
  wire is_a_nan       = is_exp_a_max && !is_frac_a_zero;
  wire is_a_inf       = is_exp_a_max && is_frac_a_zero;
  wire is_a_zero      = is_exp_a_zero && is_frac_a_zero;

  // "b" properties
  wire is_exp_b_max   = &exp_b;
  wire is_exp_b_zero  = ~|exp_b;
  wire is_frac_b_zero = ~|frac_b;
  wire is_b_nan       = is_exp_b_max && !is_frac_b_zero;
  wire is_b_inf       = is_exp_b_max && is_frac_b_zero;
  wire is_b_zero      = is_exp_b_zero && is_frac_b_zero;

  // temp vars
  reg signed [exp + 1 : 0] exp_r; // review
  reg [exp : 0] exp_norm;
  reg [2 * frac + 1 : 0] frac_mult;
  reg [frac : 0] frac_a_r, frac_b_r;
  reg [frac + 3 : 0] frac_norm;
  reg [frac - 1 : 0] frac_r;
  reg sign_r;

  wire [frac:0] unrounded;
  wire guard, round_bit, sticky;

  always @(*) begin
    flags = 5'b00000;
    r = 0;
    // sign of result
    sign_r = sign_a ^ sign_b;

    // case 1: NaN
    if (is_a_nan || is_b_nan) begin
      flags[INVALID_FLAG] = 1'b1;
      r = {1'b0, {(exp){1'b1}}, {1'b1, {(frac - 1){1'b0}}}}; // qNaN
    end

    // case 2: Inf * 0
    else if ((is_a_inf && is_b_zero) || (is_a_zero && is_b_inf)) begin
      flags[INVALID_FLAG] = 1'b1;
      r = {1'b0, {(exp){1'b1}}, {1'b1, {(frac - 1){1'b0}}}}; // qNaN
    end

    // case 3: op with inf
    else if (is_a_inf || is_b_inf) begin
      r = {sign, {(exp){1'b1}}, {(frac){1'b0}}};
    end

    else if (is_a_zero || is_b_zero) begin
      r = {sign_r, {(width - 1){1'b0}}};
    end

    else begin
      // add 1 implicit bit
      frac_a_r = {(exp_a != 0), frac_a};
      frac_b_r = {(exp_b != 0), frac_b};

      // exponents
      exp_r = exp_a + exp_b - bias;

      // multiply fractions
      frac_mult = frac_a_r * frac_b_r;

      // normalize result
      if (frac_mult[2 * frac +1]) begin // overflow
          exp_norm = exp_r + 1;
          frac_norm = frac_mult[2*frac : frac];
      end
      else begin
          exp_norm = exp_r;
          frac_norm = frac_mult[2*frac-1 : frac-1];
      end

      // round
      if (round_mode) begin
        if (frac_norm[1] && (frac_norm[0] | frac_norm[frac+2])) begin
          frac_norm = frac_norm + 1;
          if (frac_norm[frac + 3]) begin // overflow
              frac_norm = frac_norm >> 1;
              exp_norm = exp_norm + 1;
          end
        end
      end

      frac_r = frac_norm[frac + 2 : 1];

      r = {sign_r, exp_norm[exp - 1 : 0], frac_r};
    end
  end
endmodule
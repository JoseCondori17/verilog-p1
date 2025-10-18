module fmul #(
  parameter exp = 8,
  parameter frac = 23,
  parameter width = exp + frac + 1
) (
  input [width - 1 : 0] a,
  input [width - 1 : 0] b,
  input                 round_mode, // 1: nearest, 0: truncate
  output reg [width- 1 : 0] r,
  output reg [4 : 0] flags // [0]: inexact, [1]: underflow, [2]: overflow, [3]: div_by_0, [4]: invalid
);
  // flag bits - positions
  localparam INVALID_FLAG   = 4;
  localparam DIVZERO_FLAG   = 3; // no used
  localparam OVERFLOW_FLAG  = 2;
  localparam UNDERFLOW_FLAG = 1;
  localparam INEXACT_FLAG   = 0;

  localparam bias = (1 << (exp - 1)) - 1;

  // divide into sign, exponent, fraction
  wire sign_a               = a[width - 1];
  wire sign_b               = b[width - 1];
  wire [exp - 1 : 0] exp_a  = a[width - 2 : frac];
  wire [exp - 1 : 0] exp_b  = b[width - 2 : frac];
  wire [frac- 1 : 0] frac_a = a[frac - 1 : 0];
  wire [frac- 1 : 0] frac_b = b[frac - 1 : 0];

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
  reg signed [exp + 1 : 0]  exp_r;
  reg [2 * frac + 1 : 0]    frac_mult;
  reg [frac : 0]            frac_a_r, frac_b_r;
  reg [frac - 1 : 0]        frac_r;
  reg                       sign_r;

  reg [frac : 0] unrounded;
  reg [frac : 0] rounded;
  reg guard, round_bit, sticky;
  reg case_1, case_2, rule;

  integer i;
  reg [2 * frac + 1 : 0] frac_mult_norm;

  always @(*) begin
    flags = 5'b00000;
    r     = 0;
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
      r = {sign_r, {(exp){1'b1}}, {(frac){1'b0}}};
    end

    else if (is_a_zero || is_b_zero) begin
      r = {sign_r, {(width - 1){1'b0}}};
    end

    else begin
      // add implicit bit
      frac_a_r = {(exp_a != 0), frac_a};
      frac_b_r = {(exp_b != 0), frac_b};

      // exponents
      exp_r = exp_a + exp_b - bias;

      // multiply fractions
      frac_mult = frac_a_r * frac_b_r;

      // normalize result
      if (frac_mult[2 * frac + 1]) begin // overflow -> shift right by 1
        frac_mult = frac_mult >> 1;
        exp_r  = exp_r + 1;
      end else begin
        frac_mult = frac_mult;
        // Left-normalize if top bit at [2*frac] is 0 (can happen with subnormals)
        if (!frac_mult[2 * frac]) begin
          for (i = 2 * frac - 1; i >= 0; i = i - 1) begin
            if (!frac_mult[2 * frac]) begin
              frac_mult = frac_mult << 1;
              exp_r = exp_r - 1;
            end
          end
        end
      end

      unrounded = frac_mult[2 * frac : frac]; // width = frac+1
      guard     = frac_mult[frac];
      round_bit = frac_mult[frac - 1];
      sticky    = |frac_mult[frac - 2 : 0];

      if (guard || round_bit || sticky) flags[INEXACT_FLAG] = 1'b1;

      // round
      if (round_mode) begin
        case_1 = guard & (round_bit | sticky);
        case_2 = ~guard & (round_bit & sticky);
        rule   = case_1 | case_2;

        if (rule) begin
          rounded = unrounded + 1'b1;
          if (rounded[frac]) begin // overflow
            exp_r = exp_r + 1'b1;
            frac_r = rounded[frac-1:0];
          end
          else frac_r = rounded[frac-1:0];
        end
        else frac_r = unrounded[frac-1:0]; // round down
      end
      else frac_r = unrounded[frac-1:0]; // truncate

      // overflow/underflow
      if (exp_r >= (1 << exp) - 1) begin
        flags[OVERFLOW_FLAG] = 1'b1;
        flags[INEXACT_FLAG]  = 1'b1;
        r = {sign_r, {(exp){1'b1}}, {(frac){1'b0}}};
      end
      else if (exp_r <= 0) begin
        flags[UNDERFLOW_FLAG] = 1'b1;
        flags[INEXACT_FLAG]   = 1'b1;
        r = {sign_r, {(width - 1){1'b0}}};
      end
      else begin
        r = {sign_r, exp_r[exp-1:0], frac_r};
      end
    end
  end
endmodule
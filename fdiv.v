module div #(
  parameter exp   = 8,
  parameter frac  = 23,
  parameter width = exp + frac + 1
) (
  input  [width-1:0] a,
  input  [width-1:0] b,
  input              round_mode, // 1: nearest-even, 0: truncate
  output reg [width-1:0] r,
  output reg [4:0]       flags // [0]: inexact, [1]: underflow, [2]: overflow, [3]: div_by_0, [4]: invalid
);
  // flags - positions
  localparam INVALID_FLAG   = 4;
  localparam DIVZERO_FLAG   = 3;
  localparam OVERFLOW_FLAG  = 2;
  localparam UNDERFLOW_FLAG = 1;
  localparam INEXACT_FLAG   = 0;

  localparam bias = (1 << (exp - 1)) - 1;

  // divide into sign, exponent, fraction
  wire sign_a               = a[width - 1];
  wire sign_b               = b[width - 1];
  wire [exp - 1 : 0]  exp_a = a[width - 2 : frac];
  wire [exp - 1 : 0]  exp_b = b[width - 2 : frac];
  wire [frac - 1 : 0] frac_a= a[frac - 1 : 0];
  wire [frac - 1 : 0] frac_b= b[frac - 1 : 0];

  // "a" properties
  wire is_exp_a_max   = &exp_a;
  wire is_exp_a_zero  = ~|exp_a;
  wire is_frac_a_zero = ~|frac_a;
  wire is_a_nan       = is_exp_a_max && !is_frac_a_zero;
  wire is_a_inf       = is_exp_a_max &&  is_frac_a_zero;
  wire is_a_zero      = is_exp_a_zero && is_frac_a_zero;

  // "b" properties
  wire is_exp_b_max   = &exp_b;
  wire is_exp_b_zero  = ~|exp_b;
  wire is_frac_b_zero = ~|frac_b;
  wire is_b_nan       = is_exp_b_max && !is_frac_b_zero;
  wire is_b_inf       = is_exp_b_max &&  is_frac_b_zero;
  wire is_b_zero      = is_exp_b_zero && is_frac_b_zero;

  // temp vars
  reg                      sign_r;
  reg signed [exp+1:0]     exp_r;
  reg [frac:0]             frac_a_r, frac_b_r;
  reg [frac-1:0]           frac_r;
  reg [frac:0]             unrounded, rounded;
  reg                      guard, round_bit, sticky;

  // divide comps
  reg [2*frac+4:0]         dividend_ext;
  reg [frac+3:0]           q_full; // 3 bits +
  reg [frac:0]             divisor;
  reg [frac:0]             remainder_ext;

  reg case_1, case_2, rule;

  always @(*) begin
    r     = {width{1'b0}};
    flags = 5'b00000;

    // sign
    sign_r = sign_a ^ sign_b;

    // NaN
    if (is_a_nan || is_b_nan) begin
      flags[INVALID_FLAG] = 1'b1;
      r = {1'b0, {(exp){1'b1}}, {1'b1, {(frac - 1){1'b0}}}}; // qNaN
    end

    // 0/0 or Inf/Inf
    else if ((is_a_zero && is_b_zero) || (is_a_inf && is_b_inf)) begin
      flags[INVALID_FLAG] = 1'b1;
      r = {1'b0, {(exp){1'b1}}, {1'b1, {(frac - 1){1'b0}}}}; // qNaN
    end

    // divide zero
    else if (!is_a_nan && !is_a_inf && !is_a_zero && is_b_zero) begin
      flags[DIVZERO_FLAG] = 1'b1;
      r = {sign_r, {(exp){1'b1}}, {(frac){1'b0}}};            // ±Inf
    end

    // Inf / finito
    else if (is_a_inf && !is_b_inf) begin
      r = {sign_r, {(exp){1'b1}}, {(frac){1'b0}}};
    end

    // finito / Inf
    else if (!is_a_inf && is_b_inf) begin
      r = {sign_r, {(width-1){1'b0}}};
    end

    // 0 / finito
    else if (is_a_zero && !is_b_zero) begin
      r = {sign_r, {(width-1){1'b0}}};
    end

    // normal case
    else begin
      // bit implicit+
      frac_a_r = {(exp_a != 0), frac_a};
      frac_b_r = {(exp_b != 0), frac_b};

      // exponent
      exp_r = $signed({1'b0,exp_a}) - $signed({1'b0,exp_b}) + $signed(bias);

      // divide
      divisor       = frac_b_r;
      dividend_ext  = {frac_a_r, {(frac+3){1'b0}}};
      q_full        = dividend_ext / divisor;
      remainder_ext = dividend_ext % divisor;

      // normalize
      if (q_full[frac+3]) begin
        // ya está en [1,2)
        unrounded = q_full[frac+3 : 3];
        guard     = q_full[2];
        round_bit = q_full[1];
        sticky    = q_full[0] | (|remainder_ext);
      end else begin
        exp_r     = exp_r - 1;
        unrounded = q_full[frac+2 : 2];
        guard     = q_full[1];
        round_bit = q_full[0];
        sticky    = |remainder_ext;
      end

      if (guard || round_bit || sticky) flags[INEXACT_FLAG] = 1'b1;

      // round
      if (round_mode) begin
        // round to nearest, ties to even
        case_1 = guard & (round_bit | sticky);
        case_2 = guard & ~round_bit & ~sticky & unrounded[0];
        rule   = case_1 | case_2;

        if (rule) begin
          rounded = unrounded + 1'b1;
          if (rounded[frac]) begin
            exp_r  = exp_r + 1'b1;
            frac_r = rounded[frac-1:0];
          end else begin
            frac_r = rounded[frac-1:0];
          end
        end else begin
          frac_r = unrounded[frac-1:0];
        end
      end else begin
        // truncate
        frac_r = unrounded[frac-1:0];
      end

      // overflow/underflow
      if (exp_r >= (1 << exp) - 1) begin
        flags[OVERFLOW_FLAG] = 1'b1;
        flags[INEXACT_FLAG]  = 1'b1;
        r = {sign_r, {(exp){1'b1}}, {(frac){1'b0}}}; // inf
      end
      else if (exp_r <= 0) begin
        // underflow+inexact
        flags[UNDERFLOW_FLAG] = 1'b1;
        flags[INEXACT_FLAG]   = 1'b1;
        r = {sign_r, {(width-1){1'b0}}}; // 0
      end
      else begin
        r = {sign_r, exp_r[exp-1:0], frac_r};
      end
    end
  end
endmodule
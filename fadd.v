module fadd #(
  parameter exp = 8,
  parameter frac = 23,
  parameter width = exp + frac + 1
) (
  input  [width-1:0] a,
  input  [width-1:0] b,
  input              round_mode, // 1: nearest-even, 0: truncate
  output reg [width-1:0] r,
  output reg [4:0] flags
);

  localparam INVALID_FLAG   = 4;
  localparam DIVZERO_FLAG   = 3;
  localparam OVERFLOW_FLAG  = 2;
  localparam UNDERFLOW_FLAG = 1;
  localparam INEXACT_FLAG   = 0;

  wire sign_a = a[width-1];
  wire sign_b = b[width-1];
  wire [exp-1:0] exp_a = a[width-2:frac];
  wire [exp-1:0] exp_b = b[width-2:frac];
  wire [frac-1:0] frac_a = a[frac-1:0];
  wire [frac-1:0] frac_b = b[frac-1:0];

  wire is_exp_a_max  = &exp_a;
  wire is_exp_a_zero = ~|exp_a;
  wire is_frac_a_zero= ~|frac_a;
  wire is_a_nan      = is_exp_a_max && !is_frac_a_zero;
  wire is_a_inf      = is_exp_a_max && is_frac_a_zero;
  wire is_a_zero     = is_exp_a_zero && is_frac_a_zero;

  wire is_exp_b_max  = &exp_b;
  wire is_exp_b_zero = ~|exp_b;
  wire is_frac_b_zero= ~|frac_b;
  wire is_b_nan      = is_exp_b_max && !is_frac_b_zero;
  wire is_b_inf      = is_exp_b_max && is_frac_b_zero;
  wire is_b_zero     = is_exp_b_zero && is_frac_b_zero;

  reg [exp-1:0] exp_r;
  reg signed [exp:0] exp_diff;
  reg [frac+3:0] frac_a_r, frac_b_r;
  reg [frac+4:0] frac_sum;
  reg [frac-1:0] frac_r;
  reg sign_r;

  reg [frac:0] unrounded;
  reg [frac + 1:0] rounded;
  reg guard, round_bit, sticky;
  reg case_1, case_2, rule;

  integer i;

  always @(*) begin
    flags = 5'b00000;
    r     = 0;

    if (is_a_nan || is_b_nan) begin
      flags[INVALID_FLAG] = 1'b1;
      r = {1'b0, {(exp){1'b1}}, 1'b1, {(frac-1){1'b0}}};
    end
    else if (is_a_inf || is_b_inf) begin
      if (is_a_inf && is_b_inf && (sign_a != sign_b)) begin
        flags[INVALID_FLAG] = 1'b1;
        r = {1'b0, {(exp){1'b1}}, 1'b1, {(frac-1){1'b0}}};
      end
      else r = is_a_inf ? a : b;
    end
    else begin
      frac_a_r = {(exp_a != 0), frac_a, 3'b000};
      frac_b_r = {(exp_b != 0), frac_b, 3'b000};

      if (exp_a > exp_b) begin
        exp_diff = exp_a - exp_b;
        frac_b_r = frac_b_r >> exp_diff;
        exp_r    = exp_a;
      end
      else begin
        exp_diff = exp_b - exp_a;
        frac_a_r = frac_a_r >> exp_diff;
        exp_r    = exp_b;
      end

      if (sign_a == sign_b) frac_sum = frac_a_r + frac_b_r;
      else begin
        if (frac_a_r >= frac_b_r) frac_sum = frac_a_r - frac_b_r;
        else                      frac_sum = frac_b_r - frac_a_r;
      end

      if (~|frac_sum) begin
        r = {1'b0, {(exp){1'b0}}, {(frac){1'b0}}};
      end
      else begin
        if (frac_sum[frac+4]) begin
          frac_sum = frac_sum >> 1;
          exp_r    = exp_r + 1;
        end
        else if (!frac_sum[frac+3]) begin
          for (i = frac+2; i >= 0; i = i - 1) begin
            if (!frac_sum[frac+3]) begin
              frac_sum = frac_sum << 1;
              exp_r    = exp_r - 1;
            end
          end
        end

        sign_r = (sign_a == sign_b) ? sign_a :
                 (frac_a_r >= frac_b_r) ? sign_a : sign_b;

        guard     = frac_sum[2];
        round_bit = frac_sum[1];
        sticky    = |frac_sum[0];
        unrounded = frac_sum[frac+3:3];

        if (guard || round_bit || sticky) flags[INEXACT_FLAG] = 1'b1;

        if (round_mode) begin
          case_1 = guard & (round_bit | sticky);
          case_2 = guard & ~round_bit & ~sticky & unrounded[0];
          rule   = case_1 | case_2;

          if (rule) begin
            rounded = unrounded + 1'b1;
            if (rounded[frac]) begin // overflow
              exp_r = exp_r + 1;
              frac_r = rounded[frac-1:0];
            end
            else frac_r = rounded[frac-1:0];
          end
          else frac_r = unrounded[frac-1:0];
        end
        else frac_r = unrounded[frac-1:0];

        if (exp_r >= ((1 << exp) - 1)) begin
          flags[OVERFLOW_FLAG] = 1'b1;
          flags[INEXACT_FLAG]  = 1'b1;
          r = {sign_r, {(exp){1'b1}}, {(frac){1'b0}}};
        end
        else if (exp_r <= 0) begin
          if (flags[INEXACT_FLAG]) flags[UNDERFLOW_FLAG] = 1'b1;
          r = {sign_r, {(width-1){1'b0}}};
        end
        else begin
          r = {sign_r, exp_r[exp-1:0], frac_r};
        end
      end
    end
  end
endmodule
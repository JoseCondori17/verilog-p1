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
  

  // divide into sign, exponent, fraction
  wire sign_a = a[width - 1];
  wire sign_b = b[width - 1];
  wire [exp - 1 : 0] exp_a = a[width - 2 : frac];
  wire [exp - 1 : 0] exp_b = b[width - 2 : frac];
  wire [frac- 1 : 0] frac_a = a[frac - 1 : 0];
  wire [frac- 1 : 0] frac_b = b[frac - 1 : 0];
  reg bias = (1 << (exp - 1)) - 1;

  // temp vars
  reg signed [exp : 0] exp_r;
  reg [frac : 0] frac_a_r, frac_b_r;
  reg [2 * frac - 1 : 0] frac_mult;
  reg [frac - 1 : 0] frac_r;
  reg sign_r;

  always @(*) begin
    // add 1 implicit bit
    frac_a_r = {(exp_a != 0), frac_a};
    frac_b_r = {(exp_b != 0), frac_b};

    // exponents
    exp_r = exp_a + exp_b - bias;

    // multiply fractions
    frac_mult = frac_a_r * frac_b_r;

    // normalize result
    if (frac_mult[2 * frac - 1]) begin
      frac_r = frac_mult[2 * frac - 2 : frac - 1];
      exp_r = exp_r + 1;
    end
    else begin
      frac_r = frac_mult[2 * frac - 3 : frac - 2];
    end



    // sign of result
    sign_r = sign_a ^ sign_b;
  end
endmodule
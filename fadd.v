
module fadd #(
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

  // temp vars
  reg [exp - 1 : 0] exp_r;
  reg signed [exp : 0] exp_diff;
  reg [frac + 1 : 0] frac_a_r, frac_b_r;
  reg [frac + 2 : 0] frac_sum;
  reg [frac - 1 : 0] frac_r;
  reg sign_r;

  always @(*) begin
    // add 1 implicit bit and guard bit
    frac_a_r = {(exp_a != 0), frac_a, 1'b0};
    frac_b_r = {(exp_b != 0), frac_b, 1'b0};

    // align exponents
    if (exp_a > exp_b) begin
      exp_diff = exp_a - exp_b;
      frac_b_r = frac_b_r >> exp_diff;
      exp_r = exp_a;
    end
    else begin
      exp_diff = exp_b - exp_a;
      frac_a_r = frac_a_r >> exp_diff;
      exp_r = exp_b;
    end
    
    // add fractions
    if (sign_a == sign_b) frac_sum = frac_a_r + frac_b_r;
    else begin
      if (frac_a_r >= frac_b_r) frac_sum = frac_a_r - frac_b_r;
      else frac_sum = frac_b_r - frac_a_r;
    end

    // normalize result
    if (frac_sum == 0) begin
      // zero
      exp_r = 0;
      sign_r = 0;
    end
    else if (frac_sum[frac + 2]) begin
      frac_sum = frac_sum >> 1;
      exp_r = exp_r + 1;
    end
    else if (!frac_sum[frac + 1]) begin
      for (integer i = frac + 1; i >= 0; i = i - 1) begin
        if (!frac_sum[i]) begin
          frac_sum = frac_sum << 1;
          exp_r = exp_r - 1;
        end
      end
    end

    // sign of result
    if (sign_a == sign_b) sign_r = sign_a;
    else if (frac_a_r >= frac_b_r) sign_r = sign_a;
    else if (frac_b_r > frac_a_r) sign_r = sign_b;

    // round
    wire guard = frac_sum[2];
    wire round = frac_sum[1];
    wire sticky = (frac_sum[0] != 0) ? 1'b1 : 1'b0;

    if (round_mode && (sticky || guard)) begin // nearest: floor or ceiling? ceiling
      frac_r = frac_sum[frac + 1 : 2] + 1;
      if (frac_r[frac]) begin
        frac_r = frac_r >> 1;
        exp_r = exp_r + 1;
      end

    end
    else begin // truncate
      frac_r = frac_sum[frac + 1 : 2];
    end
    r = {sign_r, exp_r, frac_r};
  end

endmodule
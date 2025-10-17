module fdiv #(
  parameter exp = 8,
  parameter frac = 23,
  parameter width = exp + frac + 1
) (
  input [width - 1 : 0] a,
  input [width - 1 : 0] b,
  input                 round_mode, // 1: nearest, 0: truncate
  output reg [width - 1 : 0] r,
  output reg [4 : 0] flags
);
  // flag bits- positions
  localparam INVALID_FLAG   = 4;
  localparam DIVZERO_FLAG   = 3;
  localparam OVERFLOW_FLAG  = 2;
  localparam UNDERFLOW_FLAG = 1;
  localparam INEXACT_FLAG   = 0;

  localparam bias = (1 << (exp - 1)) - 1;

  // divide into sign, exponent, fraction
  wire sign_a                = a[width - 1];
  wire sign_b                = b[width - 1];
  wire [exp - 1 : 0] exp_a   = a[width - 2 : frac];
  wire [exp - 1 : 0] exp_b   = b[width - 2 : frac];
  wire [frac - 1 : 0] frac_a = a[frac - 1 : 0];
  wire [frac - 1 : 0] frac_b = b[frac - 1 : 0];

  // temp vars
  reg signed [exp : 0] exp_r;
  reg [exp : 0] exp_norm;
  reg [2*frac + 3 : 0] frac_div;
  reg [frac : 0] frac_a_r, frac_b_r;
  reg [frac + 3 : 0] frac_norm;
  reg [frac - 1 : 0] frac_r;
  reg sign_r;

  integer i;

  always @(*) begin
    // add implicit bit
    frac_a_r = {(exp_a != 0), frac_a};
    frac_b_r = {(exp_b != 0), frac_b};

    // exponent
    exp_r = exp_a - exp_b + bias;

    // divide
    frac_div = {frac_a_r, {(frac + 2){1'b0}}} / frac_b_r;

    // normalize result
    exp_norm = exp_r;
    frac_norm = frac_div[frac + 3:0];

    if (!frac_norm[frac + 2]) begin
      for (i = 0; i < frac + 2; i = i + 1) begin // shift left -> msb=1
        if (!frac_norm[frac+2]) begin
          frac_norm = frac_norm << 1;
          exp_norm = exp_norm - 1;
        end
      end
    end

    // round
    if (round_mode) begin
      if (frac_norm[1] && (frac_norm[0] | frac_norm[frac + 2])) begin
        frac_norm = frac_norm + 1;
        if (frac_norm[frac + 3]) begin // overflow
          frac_norm = frac_norm >> 1;
          exp_norm = exp_norm + 1;
        end
      end
    end

    frac_r = frac_norm[frac + 2 : 1];

    // sign
    sign_r = sign_a ^ sign_b;

    r = {sign_r, exp_norm[exp - 1:0], frac_r};
  end
endmodule
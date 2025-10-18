module hex4_7seg(
  input  wire        clk,
  input  wire [15:0] val,
  output wire        dp,
  output reg  [6:0]  seg,
  output reg  [3:0]  an
);
  assign dp = 1'b1; // disable decimal point

  // divide frecuency of clk
  reg [15:0] refcnt = 16'd0; // reference counter
  always @(posedge clk) refcnt <= refcnt + 16'd1;

  /*
    00: select digit 0
    01: select digit 1
    10: select digit 2
    11: select digit 3
  */
  wire [1:0] sel = refcnt[15:14];

  // part of display [3, 2, 1, 0]
  reg [3:0] nibble;
  always @(*) begin
    case (sel)
      2'd0: nibble = val[3:0];
      2'd1: nibble = val[7:4];
      2'd2: nibble = val[11:8];
      default: nibble = val[15:12];
    endcase
  end

  always @(*) begin
    an = 4'b1111;
    an[sel] = 1'b0; // active low
  end

  // decorder hex to 7-seg
  always @(*) begin
    case (nibble)
      4'h0: seg = 7'b1000000;
      4'h1: seg = 7'b1111001;
      4'h2: seg = 7'b0100100;
      4'h3: seg = 7'b0110000;
      4'h4: seg = 7'b0011001;
      4'h5: seg = 7'b0010010;
      4'h6: seg = 7'b0000010;
      4'h7: seg = 7'b1111000;
      4'h8: seg = 7'b0000000;
      4'h9: seg = 7'b0010000;
      4'hA: seg = 7'b0001000;
      4'hB: seg = 7'b0000011;
      4'hC: seg = 7'b1000110;
      4'hD: seg = 7'b0100001;
      4'hE: seg = 7'b0000110;
      4'hF: seg = 7'b0001110;
      default: seg = 7'b1111111;
    endcase
  end
endmodule
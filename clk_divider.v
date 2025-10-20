module clk_divider#(
  parameter integer DIV_POW = 27
)(
  input  wire clk,
  input  wire reset,
  output reg  clk_w
);
  reg [DIV_POW-1:0] counter;
  always @(posedge clk) begin
    if (reset) begin
      counter <= {DIV_POW{1'b0}};
      clk_w   <= 1'b0;
    end else begin
      counter <= counter + 1'b1;
      if (counter == {DIV_POW{1'b0}}) clk_w <= ~clk_w; // toggle on overflow
    end
  end
endmodule
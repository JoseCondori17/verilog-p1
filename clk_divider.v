module clk_divider(
  input  wire clk,
  input  wire reset,
  output reg  clk_w
);
  reg [26:0] counter;
  always @(posedge clk) begin
    if (reset) begin
      counter <= 27'd0;
      clk_w   <= 1'b0;
    end else begin
      counter <= counter + 1'b1;
      if (counter == 27'd0) clk_w <= ~clk_w;
    end
  end
endmodule
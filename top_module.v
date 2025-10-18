module top_module(
  // in
  input wire         clk,
  input wire         reset,
  input              btnC,
  input wire [15: 0] sw,

  // out display
  output wire [6:0] seg,// 7-segment display
  output wire       dp, // decimal point(in our case always off)
  output wire [3:0] an, // active low(for each digit or anode)

  // out clock
  output wire clk_led,
  
  // out flags
  output wire [4:0] flags
);
  //##################################################
  // CLOCK DIVIDER
  // @description: generate a slower clock for led
  //##################################################
  wire clk_w;

  clk_divider u_div(
    .clk(clk), 
    .reset(reset), 
    .clk_w(clk_w)
  );
  assign clk_led = clk_w;

  //##################################################
  // BUTTON SYNC
  // @description: synchronize button press to clk_w
  //##################################################
  wire btn_rise;

  btn_sync u_btn_sync(
    .clk(clk_w),
    .reset(reset),
    .btn_rise(btn_rise)
  );
  
  //##################################################
  // ALU 16-BIT AND 32-BIT
  // @description: floating point ALU
  //##################################################
  reg mode_fp;
  reg [15:0]  A16, B16; // 16-bit inputs
  reg [31:0]  A32, B32; // 32-bit inputs
  reg [1:0]   op_code;  // operation code
  reg         round_mode; // 1: round to nearest even, 0: truncate

  wire [15:0] r16; // 16-bit result
  wire [4:0]  f16; // 16-bit flags

  wire [31:0] r32; // 32-bit result
  wire [4:0]  f32; // 32-bit flags

  alu #(5,10) U_ALU16(
    .op_a(A16), 
    .op_b(B16),
    .op_code(op_code), 
    .round_mode(round_mode),
    .result(r16), 
    .flags(f16)
  );

  alu #(8,23) U_ALU32(
    .op_a(A32), 
    .op_b(B32),
    .op_code(op_code), 
    .round_mode(round_mode),
    .result(r32), 
    .flags(f32)
  );

  //##################################################
  // FSM CONTROLLER
  // @description: finite state machine controller
  //##################################################
  reg [15:0] shown16; // to 7-seg display
  fsm_process U_FSM(
    .clk(clk),
    .clk_w(clk_w),
    .reset(reset),
    .n(btn_rise),
    .sw(sw),
    .r16(r16),
    .r32(r32),
    .f16(f16),
    .f32(f32),
    .mode_fp(mode_fp),
    .A16(A16),
    .B16(B16),
    .A32(A32),
    .B32(B32),
    .op_code(op_code),
    .round_mode(round_mode),
    .shown16(shown16),
    .flags(flags)
  );

  //##################################################
  // 7-SEG DISPLAY DRIVER
  // @description: drive 7-seg display
  //##################################################
  seg7decimal U_SEG7(
    .clk(clk),
    .val(shown16),
    .seg(seg),
    .dp(dp),
    .an(an)
  );
endmodule

module btn_sync(
  input clk,
  input reset,
  output btn_rise
);
  reg btn_ff1, btn_ff2, btn_prev;

  always @(posedge clk) begin
    if (reset) begin
      btn_ff1 <= 1'b0;
      btn_ff2 <= 1'b0;
      btn_prev<= 1'b0;
    end else begin
      btn_ff1  <= btnC;
      btn_ff2  <= btn_ff1;
      btn_prev <= btn_ff2;
    end
  end
  assign btn_rise = btn_ff2 & ~btn_prev;
endmodule
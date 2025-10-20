`timescale 1ns/1ps

module test_add_32();
  reg  [31:0] A32, B32;
  reg  [1:0]  op_code;
  reg         round_mode; // 1: nearest-even, 0: truncate
  wire [31:0] r32;
  wire [4:0]  f32; // [0]: inexact, [1]: underflow, [2]: overflow, [3]: div_by_0, [4]: invalid

  // DUT: ALU 32-bit
  alu #(8, 23) U_ALU32(
    .op_a(A32),
    .op_b(B32),
    .op_code(op_code),
    .round_mode(round_mode),
    .result(r32),
    .flags(f32)
  );

  // Common IEEE-754 constants (single precision)
  localparam [31:0] F32_PZERO   = 32'h0000_0000; // +0
  localparam [31:0] F32_NZERO   = 32'h8000_0000; // -0
  localparam [31:0] F32_PINF    = 32'h7F80_0000; // +Inf
  localparam [31:0] F32_NINF    = 32'hFF80_0000; // -Inf
  localparam [31:0] F32_QNAN    = 32'h7FC0_0000; // qNaN
  localparam [31:0] F32_NANX    = 32'h7FC1_2345; // NaN
  localparam [31:0] F32_ONE     = 32'h3F80_0000; // 1.0
  localparam [31:0] F32_MONE    = 32'hBF80_0000; // -1.0
  localparam [31:0] F32_TWO     = 32'h4000_0000; // 2.0
  localparam [31:0] F32_2P25    = 32'h4010_0000; // 2.25
  localparam [31:0] F32_3P5     = 32'h4060_0000; // 3.5
  localparam [31:0] F32_MAX     = 32'h7F7F_FFFF; // max normal
  localparam [31:0] F32_MIN_N   = 32'h0080_0000; // min normal
  localparam [31:0] F32_MIN_D   = 32'h0000_0001; // denormal

  initial begin
    $dumpfile("test_add_32.vcd");
    $dumpvars(0, test_add_32);

    round_mode = 1'b0;
    op_code    = 2'b00; // addition

    $display("\n=== Test Add 32-bit: Special Cases ===\n");

    // 1) Normal: 3.5 + 2.25 = 5.75 -> 0x40B80000
    $display("Test 1: 3.5 + 2.25");
    A32 = F32_3P5; B32 = F32_2P25; #10;
    $display("A32 = %b (hex: %h) = 3.5", A32, A32);
    $display("B32 = %b (hex: %h) = 2.25", B32, B32);
    $display("Result = %b (hex: %h)", r32, r32);
    $display("expected = 0_10000001_01110000000000000000000 (hex: 0x40B80000) = 5.75");
    $display("Flags = %b (inexact:%b, underflow:%b, overflow:%b, div_by_0:%b, invalid:%b)\n",
             f32, f32[0], f32[1], f32[2], f32[3], f32[4]);

    // 2) +Inf + 1.0 = +Inf
    $display("Test 2: +Inf + 1.0 -> +Inf");
    A32 = F32_PINF; B32 = F32_ONE; #10;
    $display("A32 = %h (+Inf), B32 = %h (1.0), Result = %h (expected +Inf)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 3) -Inf + 2.0 = -Inf
    $display("Test 3: -Inf + 2.0 -> -Inf");
    A32 = F32_NINF; B32 = F32_TWO; #10;
    $display("A32 = %h (-Inf), B32 = %h (2.0), Result = %h (expected -Inf)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 4) +Inf + -Inf -> qNaN, INVALID
    $display("Test 4: +Inf + -Inf -> qNaN, INVALID");
    A32 = F32_PINF; B32 = F32_NINF; #10;
    $display("A32 = %h (+Inf), B32 = %h (-Inf), Result = %h (expected qNaN: %h)", A32, B32, r32, F32_QNAN);
    $display("Flags = %b\n", f32);

    // 5) NaN + 1.0 -> qNaN, INVALID
    $display("Test 5: NaN + 1.0 -> qNaN, INVALID");
    A32 = F32_NANX; B32 = F32_ONE; #10;
    $display("A32 = %h (NaN), B32 = %h (1.0), Result = %h (expected qNaN: %h)", A32, B32, r32, F32_QNAN);
    $display("Flags = %b\n", f32);

    // 6) +0 + -0 -> +0
    $display("Test 6: +0 + -0 -> +0");
    A32 = F32_PZERO; B32 = F32_NZERO; #10;
    $display("A32 = %h (+0), B32 = %h (-0), Result = %h (expected +0)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 7) Max + Max -> +Inf (overflow + inexact)
    $display("Test 7: MAX + MAX -> +Inf (overflow, inexact)");
    A32 = F32_MAX; B32 = F32_MAX; #10;
    $display("A32 = %h (MAX), B32 = %h (MAX), Result = %h (expected +Inf)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 8) Subnormales UNDERFLOW/INEXACT
    $display("Test 8: min + min -> 0 underflow/inexact");
    A32 = F32_MIN_D; B32 = F32_MIN_D; #10;
    $display("A32 = %h (min), B32 = %h (min), Result = %h (expected 0 por FTZ)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 9) 1.0 + min -> 1.0
    $display("Test 9: 1.0 + min -> 1.0 (tlvs inexact)");
    A32 = F32_ONE; B32 = F32_MIN_D; #10;
    $display("A32 = %h (1.0), B32 = %h (min), Result = %h (expected 1.0)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 10) 1.0 + (-1.0) -> +0
    $display("Test 10: 1.0 + (-1.0) -> +0");
    A32 = F32_ONE; B32 = F32_MONE; #10;
    $display("A32 = %h (1.0), B32 = %h (-1.0), Result = %h (expected +0)", A32, B32, r32);
    $display("Flags = %b\n", f32);

    // 11) 3.5 + (-2.25) -> 1.25
    $display("Test 11: 3.5 + (-2.25) -> 1.25");
    A32 = F32_3P5; B32 = {1'b1, F32_2P25[30:0]}; #10; // -2.25
    $display("A32 = %h (3.5), B32 = %h (-2.25), Result = %h (expected 0x3FA00000)", A32, B32, r32);
    $display("Flags = %b\n", f32);
    #10; $finish;
  end
endmodule

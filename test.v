module test();
  reg [31:0] A32, B32;
  reg [1:0] op_code;
  reg round_mode;
  wire [31:0] r32;
  wire [4:0] f32;

  alu #(8, 23) U_ALU32(
    .op_a(A32),
    .op_b(B32),
    .op_code(op_code),
    .round_mode(round_mode),
    .result(r32),
    .flags(f32)
  );

  initial begin
    // out file
    $dumpfile("test.vcd");
    $dumpvars(0, test);

    // set
    round_mode = 1'b0;
    
    $display("\n=== Test for ALU 32-bit === \n");

    // ========================================
    // TEST 1: ADD 3.5 + 2.25 = 5.75
    // ========================================
    // 3.5:
    // sign: 0, exp: 128 (10000000), mant: 1.110000... = .11000000000000000000000
    // 3.5 = 0_10000000_11000000000000000000000 = 0x40600000
    
    // 2.25:
    // sign: 0, exp: 128 (10000000), mant: 1.001000... = .00100000000000000000000
    // 2.25 = 0_10000000_00100000000000000000000 = 0x40100000
    
    // result expect 5.75 = 0x40B80000
    $display("Test 1: Suma 3.5 + 2.25");
    A32 = 32'b0_10000000_11000000000000000000000; // 3.5
    B32 = 32'b0_10000000_00100000000000000000000; // 2.25
    op_code = 2'b00; // Suma
    #10;
    $display("  A32 = %b (hex: %h) = 3.5", A32, A32);
    $display("  B32 = %b (hex: %h) = 2.25", B32, B32);
    $display("  Result = %b (hex: %h)", r32, r32);
    $display("  Esperado  = 0_10000001_01110000000000000000000 (hex: 0x40B80000) = 5.75");
    $display("  Flags = %b (inexact:%b, underflow:%b, overflow:%b, div_by_0:%b, invalid:%b)\n", 
             f32, f32[0], f32[1], f32[2], f32[3], f32[4]);

    // ========================================
    // TEST 2: SUB 3.5 - 2.25 = 1.25
    // ========================================
    // result expect 1.25 = 0x3FA00000
    $display("Test 2: Resta 3.5 - 2.25");
    A32 = 32'b0_10000000_11000000000000000000000; // 3.5
    B32 = 32'b0_10000000_00100000000000000000000; // 2.25
    op_code = 2'b01; // Resta
    #10;
    $display("  A32 = %b (hex: %h) = 3.5", A32, A32);
    $display("  B32 = %b (hex: %h) = 2.25", B32, B32);
    $display("  Result = %b (hex: %h)", r32, r32);
    $display("  Expected  = 0_01111111_01000000000000000000000 (hex: 0x3FA00000) = 1.25");
    $display("  Flags = %b (inexact:%b, underflow:%b, overflow:%b, div_by_0:%b, invalid:%b)\n", 
             f32, f32[0], f32[1], f32[2], f32[3], f32[4]);

    // ========================================
    // TEST 3: MULTIPLICACIÓN 3.5 * 2.25 = 7.875
    // ========================================
    // result expect 7.875 = 0x40FC0000
    $display("Test 3: Multiplicación 3.5 * 2.25");
    A32 = 32'b0_10000000_11000000000000000000000; // 3.5
    B32 = 32'b0_10000000_00100000000000000000000; // 2.25
    op_code = 2'b10; // Multiplicación
    #10;
    $display("  A32 = %b (hex: %h) = 3.5", A32, A32);
    $display("  B32 = %b (hex: %h) = 2.25", B32, B32);
    $display("  Result = %b (hex: %h)", r32, r32);
    $display("  Expected  = 0_10000001_11111000000000000000000 (hex: 0x40FC0000) = 7.875");
    $display("  Flags = %b (inexact:%b, underflow:%b, overflow:%b, div_by_0:%b, invalid:%b)\n", 
             f32, f32[0], f32[1], f32[2], f32[3], f32[4]);

    #10;
    $display("=== Tests completados ===");
    $finish;
  end

endmodule
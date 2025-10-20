// Testbench para top_module
`timescale 1ns / 1ps

module tb_top_module;

  // Entradas del testbench (regs)
  reg         clk;
  reg         reset;
  reg         btnC;
  reg [15:0]  sw;

  // Salidas del testbench (wires)
  wire [6:0]  seg;
  wire        dp;
  wire [3:0]  an;
  wire        clk_led;
  wire [4:0]  flags;
  
  // Instancia del Módulo Bajo Prueba (DUT - Design Under Test)
  top_module DUT (
    .clk(clk),
    .reset(reset),
    .btnC(btnC),
    .sw(sw),
    .seg(seg),
    .dp(dp),
    .an(an),
    .clk_led(clk_led),
    .flags(flags)
  );

  // 1. Generador de reloj
  // Genera un pulso de reloj cada 5 unidades de tiempo (periodo de 10ns)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // 2. Secuencia de prueba y estímulos
  initial begin
    $dumpfile("test_add.vcd");
    $dumpvars(0, tb_top_module);
    // Clock 0: Inicialización y activación del reset
    reset = 1;
    btnC  = 0;
    sw    = 16'h0000;
    #10; // Espera un ciclo de reloj

    // Clock 1: Mantenemos el reset activo
    #10; 

    // Clock 2: Desactivamos el reset para que el módulo empiece a operar
    reset = 0;
    #10;

    // --- FASE DE CARGA DE OPERANDOS (32 BITS) ---
    // Suponemos que la FSM interna carga los datos en este orden:
    // 1. btnC -> Carga A[15:0] desde sw
    // 2. btnC -> Carga A[31:16] desde sw
    // 3. btnC -> Carga B[15:0] desde sw
    // 4. btnC -> Carga B[31:16] desde sw
    // 5. btnC -> Carga op_code y ejecuta

    // Clock 3: Cargar los 16 bits inferiores de A (3.5 = 0x40600000)
    sw = 16'h0000; // A[15:0]
    btnC = 1;
    #10;

    // Clock 4: Liberamos el botón. La FSM detectará el flanco de subida.
    btnC = 0;
    #10;

    // Clock 5: Cargar los 16 bits superiores de A
    sw = 16'h4060; // A[31:16]
    btnC = 1;
    #10;

    // Clock 6: Liberamos el botón.
    btnC = 0;
    #10;

    // Clock 7: Cargar los 16 bits inferiores de B (2.25 = 0x40100000)
    sw = 16'h0000; // B[15:0]
    btnC = 1;
    #10;

    // Clock 8: Liberamos el botón.
    btnC = 0;
    #10;

    // Clock 9: Cargar los 16 bits superiores de B
    sw = 16'h4010; // B[31:16]
    btnC = 1;
    #10;

    // Clock 10: Liberamos el botón.
    btnC = 0;
    #10;

    // --- FASE DE EJECUCIÓN ---
    // Clock 11: Cargar el código de operación para la suma (suponemos op_code=00)
    // y otros modos si es necesario.
    sw = 16'h0000; // Suponiendo que sw[1:0] es op_code, el resto no importa.
    btnC = 1;
    #10;

    // Clock 12: Liberamos el botón. La ALU empieza a calcular.
    btnC = 0;
    #10;
    #100; // Esperar 10 ciclos de reloj adicionales
    #20;
    $finish;
  end
endmodule
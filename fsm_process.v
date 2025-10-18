module fsm_process(
  // in
  input wire        clk,
  input wire        clk_w,
  input wire        reset,
  input wire        n, // ref to button rise
  input wire [15:0] sw, // switches

  // in ALU
  input wire [15:0] r16,
  input wire [31:0] r32,
  input wire [4:0]  f16,
  input wire [4:0]  f32,

  // out to other modules
  output reg mode_fp, // mode: 0->16-bit, 1->32-bit
  
  output reg [15:0] A16, // for 16-bit
  output reg [15:0] B16,

  output reg [31:0] A32, // for 32-bit
  output reg [31:0] B32,

  output reg [1:0] op_code,
  output reg round_mode,

  // out to display
  output reg [15:0] shown16,
  output reg [4:0]  flags
);
  reg [3:0] state, next_state;
  localparam [3:0]
    START       = 4'b0000,
    LATCH_MODE  = 4'b0001,
    // FOR 16-BIT
    LOAD_A16    = 4'b0010,
    LOAD_B16    = 4'b0011,
    LOAD_CTRL16 = 4'b0100,
    RESULT16    = 4'b0101,
    // FOR 32-BIT
    LOAD_A32_HI    = 4'b0110,
    LOAD_A32_LO    = 4'b0111,
    LOAD_B32_HI    = 4'b1000,
    LOAD_B32_LO    = 4'b1001,
    LOAD_CTRL32    = 4'b1010,
    RESULT32_LO    = 4'b1011,
    RESULT32_HI    = 4'b1100;

  always @(posedge clk_w) begin
    if (reset) state <= START;
    else state <= next_state;
  end

  // next state logic
  always @(*) begin
    next_state = state;
    case (state)
      START:        next_state = n ? LATCH_MODE : START;
      LATCH_MODE: begin
        if (n) next_state = mode_fp ? LOAD_A32_HI : LOAD_A16;
        else next_state = LATCH_MODE;
      end
      // FOR 16-BIT
      LOAD_A16:     next_state = n ? LOAD_B16 : LOAD_A16;
      LOAD_B16:     next_state = n ? LOAD_CTRL16 : LOAD_B16;
      LOAD_CTRL16:  next_state = n ? RESULT16 : LOAD_CTRL16;
      RESULT16:     next_state = n ? START : RESULT16;
      // FOR 32-BIT
      LOAD_A32_HI:  next_state = n ? LOAD_A32_LO : LOAD_A32_HI;
      LOAD_A32_LO:  next_state = n ? LOAD_B32_HI : LOAD_A32_LO;
      LOAD_B32_HI:  next_state = n ? LOAD_B32_LO : LOAD_B32_HI;
      LOAD_B32_LO:  next_state = n ? LOAD_CTRL32 : LOAD_B32_LO;
      LOAD_CTRL32:  next_state = n ? RESULT32_LO : LOAD_CTRL32;
      RESULT32_LO:  next_state = n ? RESULT32_HI : RESULT32_LO;
      RESULT32_HI:  next_state = n ? START : RESULT32_HI;
      default:      next_state = START;
    endcase
  end

  // actions for each state
  always @(posedge clk) begin
    if (reset) begin
      mode_fp <= 1'b0;
      // for 16-bit
      A16 <= 16'h0000;
      B16 <= 16'h0000;
      // for 32-bit
      A32 <= 32'h00000000;
      B32 <= 32'h00000000;
      op_code <= 2'b00;
      round_mode <= 1'b0;
    end
    else begin
      case (state)
        LATCH_MODE: mode_fp <= n ? sw[15] : mode_fp;
        // FOR 16-BIT
        LOAD_A16:    A16 <= n ? sw;
        LOAD_B16:    B16 <= n ? sw;
        LOAD_CTRL16: begin
          if (n) begin
            op_code    <= sw[1:0];
            round_mode <= sw[2];
          end
        end

        // FOR 32-BIT
        LOAD_A32_HI: A32[31:16] <= n ? sw : A32[31:16];
        LOAD_A32_LO: A32[15:0]  <= n ? sw : A32[15:0];
        LOAD_B32_HI: B32[31:16] <= n ? sw : B32[31:16];
        LOAD_B32_LO: B32[15:0] <= n ? sw : B32[15:0];
        LOAD_CTRL32: begin
          if (n) begin
            op_code    <= sw[1:0];
            round_mode <= sw[2];
          end
        end
        default: ;
      endcase
    end
  end

  always @(*) begin
    case (state)
      LATCH_MODE: shown16 = mode_fp ? 16'h0032 : 16'h0016; // display mode
      // FOR 16-BIT
      LOAD_A16:   shown16 = A16;
      LOAD_B16:   shown16 = B16;
      LOAD_CTRL16: shown16 = (round_mode << 8) | op_code; // review
      RESULT16:   shown16 = r16;
      
      // FOR 32-BIT
      LOAD_A32_HI: shown16 = A32[31:16];
      LOAD_A32_LO: shown16 = A32[15:0];
      LOAD_B32_HI: shown16 = B32[31:16];
      LOAD_B32_LO: shown16 = B32[15:0];
      LOAD_CTRL32: shown16 = (round_mode << 8) | op_code; // review
      RESULT32_LO: shown16 = r32[15:0];
      RESULT32_HI: shown16 = r32[31:16];
      default:     shown16 = 16'h0000;
    endcase
  end

  always @(*) begin
    case (state)
      // FOR 16-BIT
      RESULT16:    flags = f16;
      // FOR 32-BIT
      RESULT32_HI: flags = f32;
      default:     flags = 5'b00000;
    endcase
  end
endmodule
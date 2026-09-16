`timescale 1ns/1ps

// ============================================================================
// 1. TOP-LEVEL MODULE: mips_top
// Description: System integration mapping the Datapath and Control Unit 
//              for a 32-bit Single-Cycle MIPS Architecture.
// ============================================================================
module mips_top (
    input logic clk,
    input logic rst
);

    // ------------------------------------------------------------------------
    // Internal Datapath & Control Interconnects
    // ------------------------------------------------------------------------
    logic [31:0] pc_current, pc_next, pc_plus4, pc_branch;
    logic [31:0] instr;
    
    // Control Signals
    logic        reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump;
    logic [2:0]  alu_ctrl;
    logic        zero;
    
    // Datapath Data Wires
    logic [31:0] src_a, src_b, alu_result;
    logic [31:0] read_data_mem, write_data_reg;
    logic [31:0] sign_ext_imm;
    logic [4:0]  write_reg_addr;
    logic [31:0] read_data_2;

    // ========================================================================
    // Stage 1: Instruction Fetch (IF)
    // ========================================================================
    pc pc_reg (
        .clk(clk),
        .rst(rst),
        .pc_next(pc_next),
        .pc(pc_current)
    );

    // Increment PC by 4 (Word alignment)
    adder pc_adder_plus4 (
        .a(pc_current),
        .b(32'd4),
        .y(pc_plus4)
    );

    imem instruction_memory (
        .a(pc_current),
        .rd(instr)
    );

    // ========================================================================
    // Stage 2: Instruction Decode & Control (ID)
    // ========================================================================
    controller ctrl (
        .op(instr[31:26]),
        .funct(instr[5:0]),
        .reg_dst(reg_dst),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump),
        .alu_ctrl(alu_ctrl)
    );

    // Multiplexer: Select Register Destination (rt vs. rd)
    assign write_reg_addr = reg_dst ? instr[15:11] : instr[20:16];

    // Main Register File 
    regfile registers (
        .clk(clk),
        .we(reg_write),
        .ra1(instr[25:21]),
        .ra2(instr[20:16]),
        .wa(write_reg_addr),
        .wd(write_data_reg),
        .rd1(src_a),
        .rd2(read_data_2)
    );

    // Sign extension for 16-bit immediate values (I-Type instructions)
    signext sign_extender (
        .a(instr[15:0]),
        .y(sign_ext_imm)
    );

    // ========================================================================
    // Stage 3: Execute (EX)
    // ========================================================================
    
    // Multiplexer: Select ALU Operand B (Register vs. Sign-Extended Immediate)
    assign src_b = alu_src ? sign_ext_imm : read_data_2;

    alu main_alu (
        .a(src_a),
        .b(src_b),
        .alu_control(alu_ctrl),
        .result(alu_result),
        .zero(zero)
    );

    // ========================================================================
    // Stage 4: Memory Access (MEM)
    // ========================================================================
    dmem data_memory (
        .clk(clk),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .a(alu_result),
        .wd(read_data_2),
        .rd(read_data_mem)
    );

    // ========================================================================
    // Stage 5: Writeback (WB) & Next PC Logic
    // ========================================================================
    
    // Multiplexer: Select Writeback Data (ALU Result vs. Memory Data)
    assign write_data_reg = mem_to_reg ? read_data_mem : alu_result;

    // Branch Target Computation (PC + 4 + (Imm << 2))
    adder pc_adder_branch (
        .a(pc_plus4),
        .b({sign_ext_imm[29:0], 2'b00}), // Shift left by 2
        .y(pc_branch)
    );

    // Branch evaluation logic
    logic pc_src;
    assign pc_src = branch & zero;

    logic [31:0] pc_next_branch;
    assign pc_next_branch = pc_src ? pc_branch : pc_plus4;
    
    // Final Multiplexer: Jump Target Address evaluation
    assign pc_next = jump ? {pc_plus4[31:28], instr[25:0], 2'b00} : pc_next_branch;

endmodule

// ============================================================================
// INTERNAL DATAPATH MODULES
// ============================================================================

module alu (
    input  logic [31:0] a,           // 1st operand
    input  logic [31:0] b,           // 2nd operand
    input  logic [2:0]  alu_control, // Control signal specifying the operation
    
    output logic [31:0] result,      // Operation result
    output logic        zero         // Asserted (1) when result is entirely 0
);
    always_comb begin
        case (alu_control)
            3'b000: result = a + b;       // Addition
            3'b001: result = a - b;       // Subtraction
            3'b010: result = a & b;       // Bitwise AND
            3'b011: result = a | b;       // Bitwise OR
			3'b111: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // slt
            default: result = 32'b0;      // Default case to prevent latch inference
        endcase
    end
    assign zero = (result == 32'b0) ? 1'b1 : 1'b0;
endmodule

module regfile (
    input  logic        clk, // System clock
    input  logic        we,  // Write Enable flag
    input  logic [4:0]  ra1, // Read address 1 (5 bits mapping to 32 registers)
    input  logic [4:0]  ra2, // Read address 2
    input  logic [4:0]  wa,  // Write address
    input  logic [31:0] wd,  // Write data
    
    output logic [31:0] rd1, // Read data 1 output
    output logic [31:0] rd2  // Read data 2 output
);
    // 2D Array: 32 registers of 32-bit width
  logic [31:0] rf [0:31];
    
    // Synchronous write on positive clock edge
    always_ff @(posedge clk) begin
        if (we) begin
            rf[wa] <= wd; 
        end
    end
    
    // Asynchronous read (Register $0 is hardwired to 0)
    assign rd1 = (ra1 != 0) ? rf[ra1] : 32'b0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 32'b0;
endmodule

module controller (
    input  logic [5:0] op,         // Instruction Opcode bits [31:26]
    input  logic [5:0] funct,      // Instruction Funct bits [5:0]
    output logic       reg_dst,    // Register destination mux select
    output logic       alu_src,    // ALU second operand mux select
    output logic       mem_to_reg, // Writeback data mux select
    output logic       reg_write,  // Register File write enable
    output logic       mem_read,   // Data Memory read enable
    output logic       mem_write,  // Data Memory write enable
    output logic       branch,     // Branch enable flag (beq)
    output logic       jump,       // Jump enable flag (j)
    output logic [2:0] alu_ctrl    // 3-bit ALU operation selector
);
    logic [1:0] alu_op;
    
    control_unit main_ctrl (
        .op(op), .reg_dst(reg_dst), .alu_src(alu_src), .mem_to_reg(mem_to_reg),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .branch(branch), .jump(jump), .alu_op(alu_op)
    );
    
    alu_control alu_dec (
        .alu_op(alu_op), .funct(funct), .alu_ctrl(alu_ctrl)
    );
endmodule

module control_unit (
    input  logic [5:0] op,
    output logic       reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump,
    output logic [1:0] alu_op
);
    // Combinational logic for control signal generation based on Opcode
    always_comb begin
        // Default safe values
        reg_dst = 1'b0; alu_src = 1'b0; mem_to_reg = 1'b0; reg_write = 1'b0;
        mem_read = 1'b0; mem_write = 1'b0; branch = 1'b0; jump = 1'b0; alu_op = 2'b00;
        
        case (op)
            6'b000000: begin reg_dst=1'b1; reg_write=1'b1; alu_op=2'b10; end // R-Type
            6'b100011: begin alu_src=1'b1; mem_to_reg=1'b1; reg_write=1'b1; mem_read=1'b1; alu_op=2'b00; end // lw
            6'b101011: begin alu_src=1'b1; mem_write=1'b1; alu_op=2'b00; end // sw
            6'b000100: begin branch=1'b1; alu_op=2'b01; end // beq
            6'b000010: begin jump=1'b1; end // j
            default: begin end
        endcase
    end
endmodule

module alu_control (
    input  logic [1:0] alu_op,
    input  logic [5:0] funct,
    output logic [2:0] alu_ctrl
);
    // Combinational logic for ALU operation decoding
    always_comb begin
        alu_ctrl = 3'b000; // Default to Addition (000)

        case (alu_op)
            2'b00: alu_ctrl = 3'b000; // Memory access (lw / sw) -> ADD (000)
            2'b01: alu_ctrl = 3'b001; // Branch (beq) -> SUB (001)
            2'b10: begin              // R-Type decoded by funct field
                case (funct)
                    6'b100000: alu_ctrl = 3'b000; // add 
                    6'b100010: alu_ctrl = 3'b001; // sub 
                    6'b100100: alu_ctrl = 3'b010; // and 
                    6'b100101: alu_ctrl = 3'b011; // or  
                    6'b101010: alu_ctrl = 3'b111; // slt 
                    default:   alu_ctrl = 3'b000; // default to add
                endcase
            end
            default: alu_ctrl = 3'b000;
        endcase
    end
endmodule

module pc (
    input  logic        clk, rst,
    input  logic [31:0] pc_next,
    output logic [31:0] pc
);
    // Program Counter: Synchronous update
    always_ff @(posedge clk or posedge rst) begin
        if (rst) pc <= 32'b0;
        else     pc <= pc_next;
    end
endmodule

module adder (
    input  logic [31:0] a, b,
    output logic [31:0] y
);
    assign y = a + b;
endmodule

module imem (
    input  logic [31:0] a,
    output logic [31:0] rd
);
    // 64-word instruction memory
    logic [31:0] mem [0:63];
    
    // Asynchronous read (Word-aligned addressing)
    assign rd = mem[a[7:2]];
    
    initial begin
        for (int i = 0; i < 64; i++) begin
            mem[i] = 32'h00000000;
        end
    end
endmodule

module signext (
    input  logic [15:0] a,
    output logic [31:0] y
);
    // Sign extension preserving Two's Complement representation
    assign y = {{16{a[15]}}, a};
endmodule

module dmem (
    input  logic        clk, mem_write, mem_read,
    input  logic [31:0] a, wd,
    output logic [31:0] rd
);
    // 64-word data memory
    logic [31:0] mem [0:63];
    
    // Asynchronous read
    assign rd = mem_read ? mem[a[7:2]] : 32'b0;
    
    // Synchronous write
    always_ff @(posedge clk) begin
        if (mem_write) mem[a[7:2]] <= wd;
    end
    
    initial begin
        for (int i = 0; i < 64; i++) mem[i] = 32'b0;
    end
endmodule

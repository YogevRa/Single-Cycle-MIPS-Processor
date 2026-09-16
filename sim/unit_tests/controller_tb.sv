`timescale 1ns/1ps

module tb_controller;

    // 1. Inputs to controller
    logic [5:0] op;
    logic [5:0] funct;

    // 2. Outputs from controller
    logic       reg_dst;
    logic       alu_src;
    logic       mem_to_reg;
    logic       reg_write;
    logic       mem_read;
    logic       mem_write;
    logic       branch;
    logic       jump;
    logic [2:0] alu_ctrl;

    // 3. Instantiate the Unit Under Test (UUT)
    controller uut (
        .op(op),
        .funct(funct),
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

    // 4. Stimulus block
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_controller);

        // --- Test 1: R-Type ADD (op=000000, funct=add: 100000) ---
        op = 6'b000000; funct = 6'b100000; #10;
        $display("Time=%0t | R-Type ADD: reg_write=%b, reg_dst=%b, alu_src=%b, alu_ctrl=%b (Exp: 010)", 
                 $time, reg_write, reg_dst, alu_src, alu_ctrl);

        // --- Test 2: R-Type SUB (op=000000, funct=sub: 100010) ---
        op = 6'b000000; funct = 6'b100010; #10;
        $display("Time=%0t | R-Type SUB: reg_write=%b, reg_dst=%b, alu_ctrl=%b (Exp: 110)", 
                 $time, reg_write, reg_dst, alu_ctrl);

        // --- Test 3: R-Type SLT (op=000000, funct=slt: 101010) ---
        op = 6'b000000; funct = 6'b101010; #10;
        $display("Time=%0t | R-Type SLT: reg_write=%b, reg_dst=%b, alu_ctrl=%b (Exp: 111)", 
                 $time, reg_write, reg_dst, alu_ctrl);

        // --- Test 4: lw (Load Word) (op=100011, funct is Don't Care) ---
        op = 6'b100011; funct = 6'b000000; #10;
        $display("Time=%0t | lw: reg_write=%b, alu_src=%b, mem_read=%b, mem_to_reg=%b, alu_ctrl=%b (Exp: 010)", 
                 $time, reg_write, alu_src, mem_read, mem_to_reg, alu_ctrl);

        // --- Test 5: sw (Store Word) (op=101011, funct is Don't Care) ---
        op = 6'b101011; funct = 6'b000000; #10;
        $display("Time=%0t | sw: reg_write=%b, alu_src=%b, mem_write=%b, alu_ctrl=%b (Exp: 010)", 
                 $time, reg_write, alu_src, mem_write, alu_ctrl);

        // --- Test 6: beq (Branch if Equal) (op=000100, funct is Don't Care) ---
        op = 6'b000100; funct = 6'b000000; #10;
        $display("Time=%0t | beq: branch=%b, alu_src=%b, reg_write=%b, alu_ctrl=%b (Exp: 110)", 
                 $time, branch, alu_src, reg_write, alu_ctrl);

        // --- Test 7: j (Jump) (op=000010, funct is Don't Care) ---
        op = 6'b000010; funct = 6'b000000; #10;
        $display("Time=%0t | j: jump=%b, reg_write=%b, mem_write=%b", 
                 $time, jump, reg_write, mem_write);

        #10;
        $finish;
    end

endmodule

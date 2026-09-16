`timescale 1ns/1ps

// ============================================================================
// FULL SYSTEM TESTBENCH
// Description: Verifies the Single-Cycle MIPS processor by loading a 
//              machine code program and monitoring the internal state.
// ============================================================================
module testbench;

    // 1. System Inputs
    logic clk;
    logic rst;

    // 2. Instantiate the Device Under Test (DUT)
    mips_top dut (
        .clk(clk),
        .rst(rst)
    );

    // 3. Clock Generation (10ns period)
    always #5 clk = ~clk;

    // 4. Main Simulation Process
    initial begin
        // Enable waveform dumping for EPWave
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        // --- PRE-LOAD DATA MEMORY ---
        // Inject operands directly into Data Memory for 'lw' instructions
        dut.data_memory.mem[0] = 32'd5; // Address 0 will hold value 5
        dut.data_memory.mem[1] = 32'd7; // Address 4 (index 1) will hold value 7

        // --- LOAD INSTRUCTION MEMORY (MACHINE CODE) ---
        // Program: lw, lw, add, sw, beq, j
        dut.instruction_memory.mem[0] = 32'h8C100000; // lw  $s0, 0($0)
        dut.instruction_memory.mem[1] = 32'h8C110004; // lw  $s1, 4($0)
        dut.instruction_memory.mem[2] = 32'h02119020; // add $s2, $s0, $s1
        dut.instruction_memory.mem[3] = 32'hAC120008; // sw  $s2, 8($0)
        dut.instruction_memory.mem[4] = 32'h1211FFFF; // beq $s0, $s1, -1
        dut.instruction_memory.mem[5] = 32'h08000000; // j   0

        // Initialize system state
        clk = 0;
        rst = 1;

        // Release reset after 1 clock cycle to start execution
        #10;
        rst = 0;

        // Let the processor run for 100 nanoseconds (10 clock cycles)
        #100;

        // End simulation
        $finish;
    end

    // 5. System Monitor
    // Prints key variables to the console at every state change
    initial begin
        $display("==========================================================");
        $display(" TIME |  PC  | INSTRUCTION | ALU_OUT | REG_WRITE_DATA");
        $display("==========================================================");
        $monitor("%4t | %h |   %h  | %d      | %d", 
                 $time, 
                 dut.pc_current, 
                 dut.instr, 
                 dut.alu_result, 
                 dut.write_data_reg);
    end

endmodule

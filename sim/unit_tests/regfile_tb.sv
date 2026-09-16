`timescale 1ns/1ps

module tb_regfile;

    // 1. Signals declaration
    logic        clk;
    logic        we;
    logic [4:0]  ra1, ra2, wa;
    logic [31:0] wd;
    logic [31:0] rd1, rd2;

    // 2. Instantiate the Unit Under Test (UUT)
    regfile uut (
        .clk(clk),
        .we(we),
        .ra1(ra1),
        .ra2(ra2),
        .wa(wa),
        .wd(wd),
        .rd1(rd1),
        .rd2(rd2)
    );

    // 3. Clock Generation: Toggles every 5ns -> Clock period = 10ns (100MHz)
    always begin
        #5 clk = ~clk;
    end

    // 4. Stimulus block
    initial begin
        // Waveform generation setup
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_regfile);

        // --- Initialization ---
        clk = 0;
        we  = 0;
        ra1 = 0;
        ra2 = 0;
        wa  = 0;
        wd  = 0;
        #10;

        // --- Test 1: Write 0xAAAA_BBBB to Register 5 ---
        @(negedge clk);        // Drive inputs on the falling edge (standard verification practice)
        wa = 5'd5;
        wd = 32'hAAAA_BBBB;
        we = 1;

        @(negedge clk);        // Wait for the rising edge to commit write, then release WE
        we = 0;

        // --- Test 2: Read Register 5 via port rd1 ---
        ra1 = 5'd5;
        #2;                    // Small combinational delay to settle
        $display("Time = %0t | Read Reg 5: rd1 = 0x%0h (Expected: 0xAAAA_BBBB)", $time, rd1);

        // --- Test 3: Attempt to write to Register 0 (MIPS invariant test) ---
        @(negedge clk);
        wa = 5'd0;
        wd = 32'hFFFF_FFFF;    // Try overwriting register 0
        we = 1;

        @(negedge clk);
        we = 0;

        // --- Test 4: Verify Register 0 is still strictly 0 ---
        ra2 = 5'd0;
        #2;
        $display("Time = %0t | Read Reg 0: rd2 = 0x%0h (Expected: 0x0)", $time, rd2);

        #20;
        $finish;
    end

endmodule

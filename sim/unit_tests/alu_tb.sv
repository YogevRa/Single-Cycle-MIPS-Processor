module tb_alu;

    // Internal signals for connecting to the Design Under Test (DUT)
    logic [31:0] a_tb;
    logic [31:0] b_tb;
    logic [2:0]  alu_control_tb;
    
    logic [31:0] result_tb;
    logic        zero_tb;

    // Instantiate the ALU module
    alu uut (
        .a(a_tb),
        .b(b_tb),
        .alu_control(alu_control_tb),
        .result(result_tb),
        .zero(zero_tb)
    );

    // Initial block for stimulus generation
    initial begin
        // Enable waveform dumping for EDA Playground
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_alu);

        // --- Test Case 1: Addition ---
        a_tb = 32'd10;           
        b_tb = 32'd15;           
        alu_control_tb = 3'b000; 
        #10;                     
        $display("Time = %0t | a = %0d, b = %0d, Op = ADD | Result = %0d, Zero = %0b", $time, a_tb, b_tb, result_tb, zero_tb);

        // --- Test Case 2: Subtraction yielding zero ---
        a_tb = 32'd42;           
        b_tb = 32'd42;           
        alu_control_tb = 3'b001; 
        #10;
        $display("Time = %0t | a = %0d, b = %0d, Op = SUB | Result = %0d, Zero = %0b", $time, a_tb, b_tb, result_tb, zero_tb);

        // End simulation
        $finish;
    end

endmodule

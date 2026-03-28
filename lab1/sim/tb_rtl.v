// ECE4203 Lab 1 — RTL Testbench (pre-synthesis)
//
// Run:
//   make sim
//
// The registered_adder has 2-cycle latency:
//   cycle 0: inputs applied
//   cycle 1: inputs captured in a_r/b_r/cin_r; adder computes
//   cycle 2: result captured in sum/cout → visible on outputs
//
// This testbench drives inputs and checks outputs 2 cycles later.

`timescale 1ns/1ps

module tb_registered_adder;

    parameter WIDTH      = 8;
    parameter CLK_PERIOD = 10; // 10 ns = 100 MHz

    // ---- DUT signals ----
    reg              clk, rst_n;
    reg  [WIDTH-1:0] a, b;
    reg              cin;
    wire [WIDTH-1:0] sum;
    wire             cout;

    // ---- DUT ----
    registered_adder #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n),
        .a(a), .b(b), .cin(cin),
        .sum(sum), .cout(cout), .result()
    );

    // ---- Clock ----
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- VCD dump ----
    initial begin
        $dumpfile("results/rtl.vcd");
        $dumpvars(0, tb_registered_adder);
    end

    // ---- Test tracking ----
    integer errors = 0;
    integer tests  = 0;

    // apply_and_check:
    //   Drive a, b, cin on a negedge (setup before next posedge).
    //   Wait 2 rising edges (2-cycle pipeline latency).
    //   Sample outputs 1 ns after the second edge.
    task apply_and_check;
        input [WIDTH-1:0] in_a, in_b;
        input             in_cin;
        input [WIDTH-1:0] exp_sum;
        input             exp_cout;
        begin
            @(negedge clk);
            a   = in_a;
            b   = in_b;
            cin = in_cin;
            // 2-cycle latency
            @(posedge clk);
            @(posedge clk); #1;
            tests = tests + 1;
            if (sum !== exp_sum || cout !== exp_cout) begin
                $display("FAIL  a=%3d b=%3d cin=%0d | got sum=%3d cout=%0d | expected sum=%3d cout=%0d",
                    in_a, in_b, in_cin, sum, cout, exp_sum, exp_cout);
                errors = errors + 1;
            end else
                $display("PASS  a=%3d b=%3d cin=%0d => sum=%3d cout=%0d",
                    in_a, in_b, in_cin, sum, cout);
        end
    endtask

    // ---- Stimulus ----
    initial begin
        // Reset for 3 cycles
        rst_n = 0; a = 0; b = 0; cin = 0;
        repeat(3) @(posedge clk);
        #1;
        if (sum !== 0 || cout !== 0) begin
            $display("FAIL  reset did not zero outputs");
            errors = errors + 1;
        end else
            $display("PASS  synchronous reset cleared all outputs");
        rst_n = 1;

        // Basic cases
        apply_and_check(8'd0,   8'd0,   1'b0, 8'd0,   1'b0);
        apply_and_check(8'd10,  8'd20,  1'b0, 8'd30,  1'b0);
        apply_and_check(8'd100, 8'd55,  1'b0, 8'd155, 1'b0);
        apply_and_check(8'd127, 8'd127, 1'b1, 8'd255, 1'b0);
        apply_and_check(8'd255, 8'd1,   1'b0, 8'd0,   1'b1); // overflow
        apply_and_check(8'd200, 8'd100, 1'b0, 8'd44,  1'b1); // 300 → 44+cout
        apply_and_check(8'd255, 8'd255, 1'b1, 8'd255, 1'b1); // max+max+1

        // Mid-run reset
        @(negedge clk); rst_n = 0; a = 8'd99; b = 8'd99;
        @(posedge clk); @(posedge clk); #1;
        tests = tests + 1;
        if (sum !== 0 || cout !== 0) begin
            $display("FAIL  mid-run reset: sum=%0d cout=%0d", sum, cout);
            errors = errors + 1;
        end else
            $display("PASS  mid-run reset cleared outputs");
        rst_n = 1;

        // Recovery
        apply_and_check(8'd42, 8'd58, 1'b0, 8'd100, 1'b0);

        // Done
        repeat(4) @(posedge clk);
        $display("\n%0d/%0d tests passed.", tests - errors, tests);
        $finish_and_return(!(errors==0));
    end

endmodule

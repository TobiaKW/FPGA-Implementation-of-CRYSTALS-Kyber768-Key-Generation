`timescale 1ns / 1ps

module ntt_top_tb;

reg clk,
reg rst,
reg load_a_f,
reg load_a_i,
reg load_b_f,
reg load_b_i,
reg read_a,
reg read_b,
reg start_ab,
reg start_fntt,
reg start_pwm2,
reg start_intt,
reg din,  // 0,1,2,3
wire [12*PE_NUMBER-1:0] dout, // 0,1,2,3
wire done

// Example polynomial memory interface (adapt to DUT)
// If your DUT uses BRAM ports, these might be addr/data/we signals instead.
//reg  [11:0] poly_in  [0:255];   // 256 coefficients, 12 bits each (conceptual)
//wire [11:0] poly_out [0:255];   // adjust to your DUT interface

// Clock generation: 100 MHz (10 ns period)
always #5 clk = ~clk;

// DUT instantiation
// TODO: replace `ntt_top` and its ports with the real module and port list
ntt_top DUT (
    .clk(clk),
    .reset(reset),
    .load_a_f_R(load_a_f_R),
    .load_a_i_R(load_a_i_R),
    .load_b_f_R(load_b_f_R),
    .load_b_i_R(load_b_i_R),
    .read_a_R(read_a_R),
    .read_b_R(read_b_R),
    .start_ab_R(start_ab_R),
    .start_fntt_R(start_fntt_R),
    .start_pwm2_R(start_pwm2_R),
    .start_intt_R(start_intt_R),
    .din_R(din_R),
    .dout_W(dout_W),
    .done_W(done_W)
);

// Simple task to init an input polynomial (adapt to your interface)
task init_poly_single_one;
    integer i;
    begin
        for (i = 0; i < 256; i = i + 1)
            poly_in[i] = 12'd0;
        poly_in[0] = 12'd1;  // delta at index 0
    end
endtask

initial begin
    // Initialize regs
    clk   = 1'b0;
    rst_n = 1'b0;
    start = 1'b0;

    // Reset sequence
    #20;
    rst_n = 1'b1;    // deassert reset (or rst = 0 if active-high)
    #20;

    // Initialize test polynomial
    init_poly_single_one();

    // TODO: write poly_in[] into DUT's input RAM / ports here
    // e.g., drive DUT write bus in a loop if needed

    // Start NTT
    @(posedge clk);
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    // Wait for completion
    wait (done == 1'b1);
    @(posedge clk);


    $display("NTT finished.");

    $finish;
end

endmodule
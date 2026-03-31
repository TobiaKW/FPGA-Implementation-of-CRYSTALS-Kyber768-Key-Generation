`timescale 1ns / 1ps

module ntt_top_tb();

parameter PE_NUMBER = 1; //number of butterfly operations that can be performed in parallel

reg                     clk, reset;
reg                     load_a_f, load_a_i;
reg                     load_b_f, load_b_i;
reg                     read_a, read_b;
reg                     start_ab;
reg                     start_fntt, start_pwm2, start_intt;
reg  [12*PE_NUMBER-1:0] din;
wire [12*PE_NUMBER-1:0] dout;
wire                    done;

// 100 MHz testbench clock (10 ns period)
always #5 clk = ~clk;

// Internal polynomial storage for TB
reg  [11:0] poly_in  [0:255]; 
reg  [11:0] poly_out [0:255];
integer k; // Use k to avoid conflict with task internal i

// Simple task to init an input polynomial
task init_poly_all_ones;
    integer i;
    begin
        for (i = 0; i < 256; i = i + 1)
            poly_in[i] = 12'd1; // test: all 1
    end
endtask

// DUT instantiation
KyberHPM1PE_top #(.PE_NUMBER(1)) DUT (
    .clk        (clk),
    .reset      (reset),
    .load_a_f   (load_a_f),
    .load_a_i   (load_a_i),
    .load_b_f   (load_b_f),
    .load_b_i   (load_b_i),
    .read_a     (read_a),
    .read_b     (read_b),
    .start_ab   (start_ab),
    .start_fntt (start_fntt),
    .start_pwm2 (start_pwm2),
    .start_intt (start_intt),
    .din        (din),
    .dout       (dout),
    .done       (done)
);

initial begin
    // Initialize signals
    clk        = 1'b0;
    reset      = 1'b1;
    load_a_f   = 1'b0;
    load_a_i   = 1'b0;
    load_b_f   = 1'b0;
    load_b_i   = 1'b0;
    read_a     = 1'b0;
    read_b     = 1'b0;
    start_ab   = 1'b0;
    start_fntt = 1'b0;
    start_pwm2 = 1'b0;
    start_intt = 1'b0;
    din        = 0;

    // Reset sequence
    #20;
    reset = 1'b0;
    #20;

    // Initialize test polynomial
    init_poly_all_ones();
    @(posedge clk);

    // --- Load Polynomial A ---
    load_a_f = 1'b1;
    @(posedge clk);
    load_a_f = 1'b0;
    for (k = 0; k < 256; k = k + 1) begin
        din = poly_in[k];
        @(posedge clk);
    end
    din = 0;

    // --- Load Polynomial B ---
    load_b_f = 1'b1;
    @(posedge clk);
    load_b_f = 1'b0;
    for (k = 0; k < 256; k = k + 1) begin
        din = poly_in[k];
        @(posedge clk);
    end
    din = 0;

    // --- Perform FNTT on A ---
    @(posedge clk);
    start_fntt = 1'b1; 
    start_ab = 1'b1;
    @(posedge clk);
    start_fntt = 1'b0;
    start_ab = 1'b0;
    wait (done == 1'b1);
    @(posedge clk);

    // --- Perform FNTT on B ---
    @(posedge clk);
    start_fntt = 1'b1;
    start_ab = 1'b0; 
    @(posedge clk);
    start_fntt = 1'b0;
    wait (done == 1'b1);
    @(posedge clk);

    // --- Perform PWM2 (A * B) ---
    @(posedge clk);
    start_pwm2 = 1'b1;
    @(posedge clk);
    start_pwm2 = 1'b0;
    wait (done == 1'b1);
    @(posedge clk);

    read_a = 1'b1;
    @(posedge clk);
    read_a = 1'b0;
    repeat (3) @(posedge clk);

    for (k = 0; k < 256; k = k + 1) begin
        $display("dout=%0d", dout);
        poly_out[k] = dout[11:0];
        @(posedge clk);
    end
    $finish;
end

endmodule

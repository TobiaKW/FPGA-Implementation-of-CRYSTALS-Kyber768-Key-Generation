`timescale 1ns / 1ps

module topserver_tb;

reg         clk;
reg         rst;
reg         keygen_start;
reg [255:0] seed_a;
reg [7:0]   row_idx;
reg [7:0]   col_idx;

wire        keygen_done;
wire        busy;
wire [11:0] a_coeff;
wire        a_coeff_valid;
wire [255:0] pk;
wire [255:0] sk;

topserver dut (
    .clk(clk),
    .rst(rst),
    .keygen_start(keygen_start),
    .seed_a(seed_a),
    .row_idx(row_idx),
    .col_idx(col_idx),
    .keygen_done(keygen_done),
    .busy(busy),
    .a_coeff(a_coeff),
    .a_coeff_valid(a_coeff_valid),
    .pk(pk),
    .sk(sk)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;
    keygen_start = 1'b0;
    seed_a = 256'h2D7F7336_9973CD2D_0348B1CC_251AD82F_DD1A6BDB_E4106D0C_AA9476B0_A035997C;
    row_idx = 8'h01;
    col_idx = 8'h02;

    #30;
    rst = 1'b0;

    #20;
    keygen_start = 1'b1;
    #10;
    keygen_start = 1'b0;

    // Let the hash pipeline run and observe first coefficient capture.
    #5000;
    $finish;
end

always @(posedge clk) begin
    if (a_coeff_valid) begin
        $display("[T=%0t] a_coeff_valid=1 a_coeff=0x%03h busy=%b done=%b", $time, a_coeff, busy, keygen_done);
    end

    if (keygen_done) begin
        $display("[T=%0t] keygen_done pulse seen", $time);
    end
end

endmodule

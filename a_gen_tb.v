`timescale 1ns / 1ps

module a_gen_tb;

reg         clk;
reg         rst;
reg         a_gen_start;
reg [255:0] seed_a;
reg [11:0]  a_mem_rd_addr;

wire        a_gen_done;
wire        busy;
wire [11:0] a_mem_rd_data;

a_gen dut (
    .clk(clk),
    .rst(rst),
    .a_gen_start(a_gen_start),
    .seed_a(seed_a),
    .a_mem_rd_addr(a_mem_rd_addr),
    .a_gen_done(a_gen_done),
    .busy(busy),
    .a_mem_rd_data(a_mem_rd_data)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;
    a_gen_start = 1'b0;
    seed_a = 256'h2D7F7336_9973CD2D_0348B1CC_251AD82F_DD1A6BDB_E4106D0C_AA9476B0_A035997C;
    a_mem_rd_addr = 12'd0;

    #30;
    rst = 1'b0;

    #20;
    a_gen_start = 1'b1;
    #10;
    a_gen_start = 1'b0;

    // Let the hash pipeline run and observe first coefficient capture.
    #500000;
    $finish;
end

always @(posedge clk) begin
    if (a_gen_done) begin
        $display("[T=%0t] a_gen_done pulse seen", $time);
    end
end

endmodule

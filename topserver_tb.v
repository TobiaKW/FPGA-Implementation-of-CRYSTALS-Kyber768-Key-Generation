`timescale 1ns / 1ps

module topserver_tb;

reg         clk;
reg         rst;
reg         top_start;
reg [255:0] seed_a;

wire        top_done;
wire        rd_valid;
wire [11:0] rd_addr;
wire [11:0] rd_data;

topserver dut (
    .clk(clk),
    .rst(rst),
    .top_start(top_start),
    .seed_a(seed_a),
    .top_done(top_done),
    .rd_valid(rd_valid),
    .rd_addr(rd_addr),
    .rd_data(rd_data)
);

always #5 clk = ~clk;

initial begin
    clk = 1'b0;
    rst = 1'b1;
    top_start = 1'b0;
    seed_a = 256'h2D7F7336_9973CD2D_0348B1CC_251AD82F_DD1A6BDB_E4106D0C_AA9476B0_A035997C;

    #30;
    rst = 1'b0;
    #20;
    top_start = 1'b1;
    #10;
    top_start = 1'b0;

    #5000000;
    $finish;
end

always @(posedge clk) begin
    if (rd_valid && rd_addr < 12'd16) begin
        $display("[T=%0t] A[%0d] = 0x%03h", $time, rd_addr, rd_data);
    end
    if (top_done) begin
        $display("[T=%0t] top_done pulse seen", $time);
    end
end

endmodule

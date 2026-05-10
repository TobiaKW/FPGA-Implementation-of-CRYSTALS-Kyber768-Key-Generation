`timescale 1ns / 1ps

module topserver_tb;

reg         clk;
reg         rst;
reg         top_start;
reg [255:0] seed_a;
reg         out_rd_en;
reg         out_rd_sk;
reg [11:0]  out_rd_addr;

wire        top_done;
wire        rd_valid;
wire [11:0] rd_addr;
wire [11:0] rd_data;
integer pk_absorb_words_seen;
integer hpk_words_seen;

topserver dut (
    .clk(clk),
    .rst(rst),
    .top_start(top_start),
    .seed_a(seed_a),
    .out_rd_en(out_rd_en),
    .out_rd_sk(out_rd_sk),
    .out_rd_addr(out_rd_addr),
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
    out_rd_en = 1'b0;
    out_rd_sk = 1'b0;
    out_rd_addr = 12'd0;
    pk_absorb_words_seen = 0;
    hpk_words_seen = 0;

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
        $display("SK[0]    = %02h", dut.sk[0]);
        $display("SK[1151] = %02h", dut.sk[1151]);
        $display("SK[1152] = %02h", dut.sk[1152]);
        $display("SK[2335] = %02h", dut.sk[2335]);
        $display("SK[2336] = %02h", dut.sk[2336]);
        $display("SK[2367] = %02h", dut.sk[2367]);
        $display("SK[2368] = %02h", dut.sk[2368]);
        $display("SK[2399] = %02h", dut.sk[2399]);
    end
    if (dut.top_hash_absorb_valid && dut.top_hash_absorb_ready) begin
        $display("[T=%0t] PK absorb word %0d/295 last=%0b data=%08h",
                 $time, pk_absorb_words_seen, dut.top_hash_absorb_last, dut.top_hash_absorb_word);
        pk_absorb_words_seen = pk_absorb_words_seen + 1;
    end
    if (dut.shared_stream_valid && (dut.state == 4'd11)) begin
        $display("[T=%0t] H(pk) word %0d/7 = %08h",
                 $time, hpk_words_seen, dut.shared_stream_word);
        hpk_words_seen = hpk_words_seen + 1;
    end
end

endmodule

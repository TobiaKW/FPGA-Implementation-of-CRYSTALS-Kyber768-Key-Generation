`timescale 1ns / 1ps

module top_fpga(
    input         clk,
    input         rst,
    input         top_start,
    output        top_done
);

topserver u_topserver (
    .clk(clk),
    .rst(rst),
    .top_start(top_start),
    .out_rd_en(1'b0),
    .out_rd_sk(1'b1),
    .out_rd_addr(12'd0),
    .top_done(top_done),
    .rd_valid(),
    .rd_addr(),
    .rd_data()
);

endmodule


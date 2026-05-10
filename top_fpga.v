`timescale 1ns / 1ps

// Minimal FPGA wrapper to reduce top-level IO utilization.
// Exposes only essential control/status pins for bring-up.
module top_fpga(
    input         clk,
    input         rst,
    input         top_start,
    output        top_done
);

wire        rd_valid_unused;
wire [11:0] rd_addr_unused;
wire [11:0] rd_data_unused;
wire [255:0] seed_a_const;

// Bring-up default seed to avoid 256 external IO pins.
assign seed_a_const = 256'h00112233445566778899aabbccddeeffffeeddccbbaa99887766554433221100;

topserver u_topserver (
    .clk(clk),
    .rst(rst),
    .top_start(top_start),
    .seed_a(seed_a_const),
    .out_rd_en(1'b0),
    .out_rd_sk(1'b0),
    .out_rd_addr(12'd0),
    .top_done(top_done),
    .rd_valid(rd_valid_unused),
    .rd_addr(rd_addr_unused),
    .rd_data(rd_data_unused)
);

endmodule


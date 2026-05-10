`timescale 1ns / 1ps
// Vivado-friendly simple dual-port template: one synchronous write, one synchronous read
// (read data registered; 1-cycle latency from raddr change to rdata update).
// Depth 768 = Kyber768 vector t coefficients; width 12 = Zq element.
module bram_sdp_12x768 (
    input wire         clk,
    input wire         we,
    input wire  [9:0]  waddr,
    input wire  [11:0] wdata,
    input wire  [9:0]  raddr,
    output reg  [11:0] rdata
);
    (* ram_style = "block" *)
    reg [11:0] mem [0:767];

    reg [9:0] raddr_r;

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        raddr_r <= raddr;
        rdata   <= mem[raddr_r];
    end
endmodule


/*
The designers:

Ahmet Can Mert <ahmetcanmert@sabanciuniv.edu>
Ferhat Yaman <ferhatyaman@sabanciuniv.edu>

To the extent possible under law, the implementer has waived all copyright
and related or neighboring rights to the source code in this file.
http://creativecommons.org/publicdomain/zero/1.0/
*/

// read latency is 1 cc

module BRAM(input             clk,
            input             wen,
            input      [3:0]  waddr,
            input      [11:0] din,
            input      [3:0]  raddr,
            output reg [11:0] dout);
// bram
(* ram_style="block" *) reg [11:0] blockram [15:0];

// Simulation: avoid X on read-before-write (propagates to dout in OP_READ_DATA)
integer bram_init_i;
initial
    for (bram_init_i = 0; bram_init_i < 16; bram_init_i = bram_init_i + 1)
        blockram[bram_init_i] = 12'd0;

// write operation
always @(posedge clk) begin
    if(wen)
        blockram[waddr] <= din;
end

// read operation
always @(posedge clk) begin
    dout <= blockram[raddr];
end

endmodule

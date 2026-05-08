`timescale 1ns / 1ps

module topserver(
    input             clk,
    input             rst,
    input             top_start,
    input  [255:0]    seed_a,
    output reg        top_done,
    output reg        rd_valid,
    output reg [11:0] rd_addr,
    output reg [11:0] rd_data
);

localparam ST_IDLE      = 2'd0;
localparam ST_WAIT_AGEN = 2'd1;
localparam ST_READ_A    = 2'd2;
localparam ST_DONE      = 2'd3;

localparam A_COEFFS = 12'd2304; // 3x3x256

reg [1:0] state;
reg       a_gen_start;
wire      a_gen_done;
wire      a_gen_busy;
wire [11:0] a_mem_rd_data;

a_gen u_a_gen (
    .clk(clk),
    .rst(rst),
    .a_gen_start(a_gen_start),
    .seed_a(seed_a),
    .a_mem_rd_addr(rd_addr),
    .a_gen_done(a_gen_done),
    .busy(a_gen_busy),
    .a_mem_rd_data(a_mem_rd_data)
);

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        a_gen_start <= 1'b0;
        top_done <= 1'b0;
        rd_valid <= 1'b0;
        rd_addr <= 12'd0;
        rd_data <= 12'd0;
    end else begin
        a_gen_start <= 1'b0; // default pulse-low
        top_done <= 1'b0;
        rd_valid <= 1'b0;

        case (state)
            ST_IDLE: begin
                rd_addr <= 12'd0;
                if (top_start) begin
                    a_gen_start <= 1'b1; // one-cycle start pulse
                    state <= ST_WAIT_AGEN;
                end
            end

            ST_WAIT_AGEN: begin
                if (a_gen_done) begin
                    rd_addr <= 12'd0;
                    state <= ST_READ_A;
                end
            end

            ST_READ_A: begin
                // Address-driven readout from a_gen memory.
                rd_valid <= 1'b1;
                rd_data <= a_mem_rd_data;
                if (rd_addr == (A_COEFFS - 1'b1)) begin
                    state <= ST_DONE;
                end else begin
                    rd_addr <= rd_addr + 12'd1;
                end
            end

            ST_DONE: begin
                top_done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule

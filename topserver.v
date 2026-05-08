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

localparam ST_IDLE       = 4'd0;
localparam ST_WAIT_AGEN  = 4'd1;
localparam ST_READ_A     = 4'd2;
localparam ST_WAIT_S_GEN = 4'd3;
localparam ST_READ_S     = 4'd4;
localparam ST_WAIT_E_GEN = 4'd5;
localparam ST_READ_E     = 4'd6;
localparam ST_DONE       = 4'd7;

localparam A_COEFFS = 12'd2304; // 3x3x256
localparam S_COEFFS = 12'd768;  // k*256 for k=3
localparam E_COEFFS = 12'd768;  // k*256 for k=3

reg [3:0] state;
reg       a_gen_start;
reg       s_gen_start;
reg       e_gen_start;
wire      a_gen_done;
wire      a_gen_busy;
wire [11:0] a_mem_rd_data;
wire      s_gen_done;
wire      s_gen_busy;
wire [11:0] s_mem_rd_data;
wire      e_gen_done;
wire      e_gen_busy;
wire [11:0] e_mem_rd_data;
wire [255:0] sigma;

assign sigma = seed_a; // test hookup: reuse seed_a as sigma for now

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

s_gen u_s_gen (
    .clk(clk),
    .rst(rst),
    .s_gen_start(s_gen_start),
    .sigma(sigma),
    .s_mem_rd_addr(rd_addr),
    .s_gen_done(s_gen_done),
    .busy(s_gen_busy),
    .s_mem_rd_data(s_mem_rd_data)
);

e_gen u_e_gen (
    .clk(clk),
    .rst(rst),
    .e_gen_start(e_gen_start),
    .sigma(sigma),
    .e_mem_rd_addr(rd_addr),
    .e_gen_done(e_gen_done),
    .busy(e_gen_busy),
    .e_mem_rd_data(e_mem_rd_data)
);

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        a_gen_start <= 1'b0;
        s_gen_start <= 1'b0;
        e_gen_start <= 1'b0;
        top_done <= 1'b0;
        rd_valid <= 1'b0;
        rd_addr <= 12'd0;
        rd_data <= 12'd0;
    end else begin
        a_gen_start <= 1'b0; // default pulse-low
        s_gen_start <= 1'b0; // default pulse-low
        e_gen_start <= 1'b0; // default pulse-low
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
                    rd_addr <= 12'd0;
                    s_gen_start <= 1'b1;
                    state <= ST_WAIT_S_GEN;
                end else begin
                    rd_addr <= rd_addr + 12'd1;
                end
            end

            ST_WAIT_S_GEN: begin
                if (s_gen_done) begin
                    rd_addr <= 12'd0;
                    state <= ST_READ_S;
                end
            end

            ST_READ_S: begin
                rd_valid <= 1'b1;
                rd_data <= s_mem_rd_data;
                if (rd_addr == (S_COEFFS - 1'b1)) begin
                    rd_addr <= 12'd0;
                    e_gen_start <= 1'b1;
                    state <= ST_WAIT_E_GEN;
                end else begin
                    rd_addr <= rd_addr + 12'd1;
                end
            end

            ST_WAIT_E_GEN: begin
                if (e_gen_done) begin
                    rd_addr <= 12'd0;
                    state <= ST_READ_E;
                end
            end

            ST_READ_E: begin
                rd_valid <= 1'b1;
                rd_data <= e_mem_rd_data;
                if (rd_addr == (E_COEFFS - 1'b1)) begin
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

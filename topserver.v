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
localparam ST_COMPUTE_AS = 4'd7;
localparam ST_WAIT_AS_DONE= 4'd8;
localparam ST_DONE       = 4'd9;

localparam A_COEFFS = 12'd2304; // 3x3x256
localparam S_COEFFS = 12'd768;  // k*256 for k=3
localparam E_COEFFS = 12'd768;  // k*256 for k=3

//A, s, e generation modules
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

//mat_vec_mul module
reg       mat_vec_mul_start;
wire      mat_vec_mul_done;
wire      mat_vec_mul_busy;
wire [11:0] mat_rd_addr;
wire [11:0] vec_rd_addr;
wire       t_wr_en;
wire [9:0] t_wr_addr;
wire [11:0] t_wr_data;
wire [11:0] a_rd_addr_mux;
wire [11:0] s_rd_addr_mux;

assign sigma = seed_a; // test hookup: reuse seed_a as sigma for now
//When in state ST_COMPUTE_AS or ST_WAIT_AS_DONE, read from mat_vec_mul module.
assign a_rd_addr_mux = (state == ST_COMPUTE_AS || state == ST_WAIT_AS_DONE) ? mat_rd_addr : rd_addr;
assign s_rd_addr_mux = (state == ST_COMPUTE_AS || state == ST_WAIT_AS_DONE) ? vec_rd_addr : rd_addr;

a_gen u_a_gen (
    .clk(clk),
    .rst(rst),
    .a_gen_start(a_gen_start),
    .seed_a(seed_a),
    .a_mem_rd_addr(a_rd_addr_mux),
    .a_gen_done(a_gen_done),
    .busy(a_gen_busy),
    .a_mem_rd_data(a_mem_rd_data)
);

s_gen u_s_gen (
    .clk(clk),
    .rst(rst),
    .s_gen_start(s_gen_start),
    .sigma(sigma),
    .s_mem_rd_addr(s_rd_addr_mux),
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

mat_vec_mul u_mat_vec_mul (
    .clk(clk),
    .rst(rst),
    .start(mat_vec_mul_start),
    .mat_rd_addr(mat_rd_addr),
    .mat_rd_data(a_mem_rd_data),
    .vec_rd_addr(vec_rd_addr),
    .vec_rd_data(s_mem_rd_data),
    .out_wr_en(t_wr_en),
    .out_wr_addr(t_wr_addr),
    .out_wr_data(t_wr_data),
    .done(mat_vec_mul_done),
    .busy(mat_vec_mul_busy)
);

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        a_gen_start <= 1'b0;
        s_gen_start <= 1'b0;
        e_gen_start <= 1'b0;
        mat_vec_mul_start <= 1'b0;
        top_done <= 1'b0;
        rd_valid <= 1'b0;
        rd_addr <= 12'd0;
        rd_data <= 12'd0;
    end else begin
        a_gen_start <= 1'b0; // default pulse-low
        s_gen_start <= 1'b0; // default pulse-low
        e_gen_start <= 1'b0; // default pulse-low
        mat_vec_mul_start <= 1'b0; // default pulse-low
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
                    mat_vec_mul_start <= 1'b1;
                    state <= ST_COMPUTE_AS;
                end else begin
                    rd_addr <= rd_addr + 12'd1;
                end
            end

            ST_COMPUTE_AS: begin
                state <= ST_WAIT_AS_DONE;
            end

            ST_WAIT_AS_DONE: begin
                if (mat_vec_mul_done) begin
                    state <= ST_DONE;
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

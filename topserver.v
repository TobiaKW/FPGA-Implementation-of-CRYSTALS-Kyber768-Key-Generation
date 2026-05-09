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
localparam ST_WAIT_A_GEN = 4'd1;
localparam ST_WAIT_S_GEN = 4'd2;
localparam ST_WAIT_E_GEN = 4'd3;
localparam ST_COMPUTE_AS = 4'd4;
localparam ST_WAIT_AS_DONE= 4'd5;
localparam ST_ADD_E      = 4'd6;
localparam ST_DONE       = 4'd7;
localparam ST_TRNG_INIT  = 4'd8;
localparam ST_TRNG_COLLECT = 4'd9;

localparam E_COEFFS = 12'd768;  // k*256 for k=3

//A, s, e generation modules
reg [3:0] state;
reg       a_gen_start;
wire      a_gen_done;
wire      a_gen_busy;
wire [11:0] a_mem_rd_data;
reg       se_gen_start;
reg       se_gen_is_e;
wire      se_gen_done;
wire      se_gen_busy;
wire [11:0] s_mem_rd_data;
wire [11:0] e_mem_rd_data;
wire [255:0] sigma;
// Shared hash_unit control/status wires from generators
wire        a_hash_start, a_hash_stop_stream;
wire [1:0]  a_hash_mode;
wire [255:0] a_hash_seed;
wire [7:0]  a_hash_row_idx, a_hash_col_idx, a_hash_nonce;
wire        se_hash_start, se_hash_stop_stream;
wire [1:0]  se_hash_mode;
wire [255:0] se_hash_seed;
wire [7:0]  se_hash_row_idx, se_hash_col_idx, se_hash_nonce;
wire        shared_hash_busy, shared_hash_done, shared_stream_valid;
wire [31:0] shared_stream_word;
wire sel_a, sel_se;
wire sel_none;
wire hash_start_mux, hash_stop_mux;
wire [1:0] hash_mode_mux;
wire [255:0] hash_seed_mux;
wire [7:0] hash_row_mux, hash_col_mux, hash_nonce_mux;

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
reg  [11:0] t_mem [0:E_COEFFS-1];
reg         trng_en;
wire        trng_valid;
wire [7:0]  trng_byte;
reg [6:0]   trng_cnt;
reg [255:0] seed_a_reg;
reg [255:0] z_reg;
`ifdef SYNTHESIS
localparam TRNG_SIM_MODE = 1'b0; // physical TRNG in synthesis/implementation
`else
localparam TRNG_SIM_MODE = 1'b1; // avoid zero-delay oscillation in RTL simulation
`endif

function [11:0] add_mod_q12; //(vec + vec) mod3329
    input [11:0] a;
    input [11:0] b;
    reg [12:0] s;
begin
    s = a + b;
    if (s >= 13'd3329)
        add_mod_q12 = s - 13'd3329;
    else
        add_mod_q12 = s[11:0];
end
endfunction

assign sigma = seed_a_reg; // temporary hookup: reuse TRNG seed_a for sigma
assign sel_a = a_gen_busy | a_hash_start;
assign sel_se = (~sel_a) & (se_gen_busy | se_hash_start);
assign sel_none = ~sel_a & ~sel_se;
assign hash_start_mux = sel_a ? a_hash_start : (sel_se ? se_hash_start : 1'b0);
assign hash_mode_mux  = sel_a ? a_hash_mode  : (sel_se ? se_hash_mode  : 2'd0);
assign hash_seed_mux  = sel_a ? a_hash_seed  : (sel_se ? se_hash_seed  : 256'd0);
assign hash_row_mux   = sel_a ? a_hash_row_idx : (sel_se ? se_hash_row_idx : 8'd0);
assign hash_col_mux   = sel_a ? a_hash_col_idx : (sel_se ? se_hash_col_idx : 8'd0);
assign hash_nonce_mux = sel_a ? a_hash_nonce : (sel_se ? se_hash_nonce : 8'd0);
assign hash_stop_mux  = sel_a ? a_hash_stop_stream : (sel_se ? se_hash_stop_stream : 1'b0);
//When in state ST_COMPUTE_AS or ST_WAIT_AS_DONE, read from mat_vec_mul module.
assign a_rd_addr_mux = (state == ST_COMPUTE_AS || state == ST_WAIT_AS_DONE) ? mat_rd_addr : rd_addr;
assign s_rd_addr_mux = (state == ST_COMPUTE_AS || state == ST_WAIT_AS_DONE) ? vec_rd_addr : rd_addr;

a_gen u_a_gen (
    .clk(clk),
    .rst(rst),
    .a_gen_start(a_gen_start),
    .seed_a(seed_a_reg),
    .a_mem_rd_addr(a_rd_addr_mux),
    .a_gen_done(a_gen_done),
    .busy(a_gen_busy),
    .a_mem_rd_data(a_mem_rd_data),
    .hash_start_o(a_hash_start),
    .hash_mode_o(a_hash_mode),
    .hash_seed_o(a_hash_seed),
    .hash_row_idx_o(a_hash_row_idx),
    .hash_col_idx_o(a_hash_col_idx),
    .hash_nonce_o(a_hash_nonce),
    .hash_stop_stream_o(a_hash_stop_stream),
    .hash_done_i(shared_hash_done),
    .hash_stream_word_i(shared_stream_word),
    .hash_stream_valid_i(shared_stream_valid)
);

se_gen u_se_gen (
    .clk(clk),
    .rst(rst),
    .gen_start(se_gen_start),
    .gen_is_e(se_gen_is_e),
    .sigma(sigma), 
    .s_mem_rd_addr(s_rd_addr_mux),
    .e_mem_rd_addr(rd_addr),
    .gen_done(se_gen_done),
    .busy(se_gen_busy),
    .s_mem_rd_data(s_mem_rd_data),
    .e_mem_rd_data(e_mem_rd_data),
    .hash_start_o(se_hash_start),
    .hash_mode_o(se_hash_mode),
    .hash_seed_o(se_hash_seed),
    .hash_row_idx_o(se_hash_row_idx),
    .hash_col_idx_o(se_hash_col_idx),
    .hash_nonce_o(se_hash_nonce),
    .hash_stop_stream_o(se_hash_stop_stream),
    .hash_done_i(shared_hash_done),
    .hash_stream_word_i(shared_stream_word),
    .hash_stream_valid_i(shared_stream_valid)
);

hash_unit u_hash_shared (
    .clk(clk),
    .rst(rst),
    .start(hash_start_mux),
    .mode(hash_mode_mux),
    .seed(hash_seed_mux),
    .row_idx(hash_row_mux),
    .col_idx(hash_col_mux),
    .nonce(hash_nonce_mux),
    .stop_stream(hash_stop_mux),
    .busy(shared_hash_busy),
    .done(shared_hash_done),
    .stream_word(shared_stream_word),
    .stream_valid(shared_stream_valid),
    .stream_ready(~sel_none)
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

neoTRNG #(
    .NUM_CELLS(3),
    .NUM_INV_START(5),
    .NUM_RAW_BITS(64),
    .SIM_MODE(TRNG_SIM_MODE)
) u_trng (
    .clk_i(clk),
    .rstn_i(~rst),
    .enable_i(trng_en),
    .valid_o(trng_valid),
    .data_o(trng_byte)
);

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        a_gen_start <= 1'b0;
        se_gen_start <= 1'b0;
        se_gen_is_e <= 1'b0;
        mat_vec_mul_start <= 1'b0;
        top_done <= 1'b0;
        rd_valid <= 1'b0;
        rd_addr <= 12'd0;
        rd_data <= 12'd0;
        trng_en <= 1'b0;
        trng_cnt <= 7'd0;
        seed_a_reg <= 256'd0;
        z_reg <= 256'd0;
    end else begin
        if (t_wr_en)//handshake signal from mat_vec_mul module
            t_mem[t_wr_addr] <= t_wr_data;

        a_gen_start <= 1'b0; // default pulse-low
        se_gen_start <= 1'b0; // default pulse-low
        mat_vec_mul_start <= 1'b0; // default pulse-low
        top_done <= 1'b0;
        rd_valid <= 1'b0;

        case (state)
            ST_IDLE: begin
                rd_addr <= 12'd0;
                if (top_start) begin
                    state <= ST_TRNG_INIT;
                end
            end

            ST_TRNG_INIT: begin
                trng_en <= 1'b1;
                trng_cnt <= 7'd0;
                seed_a_reg <= 256'd0;
                z_reg <= 256'd0;
                state <= ST_TRNG_COLLECT;
            end

            ST_TRNG_COLLECT: begin
                trng_en <= 1'b1;
                if (trng_valid) begin
                    if (trng_cnt < 7'd32)
                        seed_a_reg <= {seed_a_reg[247:0], trng_byte};
                    else
                        z_reg <= {z_reg[247:0], trng_byte};

                    if (trng_cnt == 7'd63) begin
                        trng_en <= 1'b0;
                        a_gen_start <= 1'b1;
                        state <= ST_WAIT_A_GEN;
                    end else begin
                        trng_cnt <= trng_cnt + 7'd1;
                    end
                end
            end

            ST_WAIT_A_GEN: begin
                if (a_gen_done) begin
                    rd_addr <= 12'd0;
                    se_gen_is_e <= 1'b0;
                    se_gen_start <= 1'b1;
                    state <= ST_WAIT_S_GEN;
                end
            end

            ST_WAIT_S_GEN: begin
                if (se_gen_done) begin
                    rd_addr <= 12'd0;
                    se_gen_is_e <= 1'b1;
                    se_gen_start <= 1'b1;
                    state <= ST_WAIT_E_GEN;
                end
            end

            ST_WAIT_E_GEN: begin
                if (se_gen_done) begin
                    mat_vec_mul_start <= 1'b1;
                    state <= ST_COMPUTE_AS;
                end
            end

            ST_COMPUTE_AS: begin
                state <= ST_WAIT_AS_DONE;
            end

            ST_WAIT_AS_DONE: begin
                if (mat_vec_mul_done) begin
                    rd_addr <= 12'd0;
                    state <= ST_ADD_E;
                end
            end

            ST_ADD_E: begin
                // Final t = A*s + e (mod q), one coeff per cycle.
                t_mem[rd_addr] <= add_mod_q12(t_mem[rd_addr], e_mem_rd_data);
                if (rd_addr == (E_COEFFS - 1'b1))
                    state <= ST_DONE;
                else
                    rd_addr <= rd_addr + 12'd1;
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

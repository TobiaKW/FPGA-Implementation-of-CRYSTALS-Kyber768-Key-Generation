`timescale 1ns / 1ps

// Shared noise generator for s and e.
// Reuses one CBD(eta=2) datapath and one hash stream control path.
module se_gen(
    input              clk,
    input              rst,
    input              gen_start,
    input              gen_is_e,        // 0: generate s, 1: generate e
    input      [255:0] sigma,
    input      [11:0]  s_mem_rd_addr,
    input      [11:0]  e_mem_rd_addr,
    output reg         gen_done,
    output reg         busy,
    output reg  [11:0] s_mem_rd_data,
    output reg  [11:0] e_mem_rd_data,
    // Shared hash_unit interface
    output             hash_start_o,
    output      [1:0]  hash_mode_o,
    output     [255:0] hash_seed_o,
    output      [7:0]  hash_row_idx_o,
    output      [7:0]  hash_col_idx_o,
    output      [7:0]  hash_nonce_o,
    output             hash_stop_stream_o,
    input              hash_done_i,
    input      [31:0]  hash_stream_word_i,
    input              hash_stream_valid_i
);

localparam KYBER_K  = 3;
localparam POLY_N   = 256;
localparam S_COEFFS = KYBER_K * POLY_N;
localparam E_COEFFS = KYBER_K * POLY_N;

localparam ST_IDLE           = 3'd0;
localparam ST_SAMPLE         = 3'd1;
localparam ST_WAIT_HASH_DONE = 3'd2;
localparam ST_STORE_POLY     = 3'd3;
localparam ST_DONE           = 3'd4;

reg [2:0] state;
reg       is_e_r;
reg [1:0] poly_ctr; // 0..2 for k=3
reg [8:0] coeff_count;
reg [7:0] store_coeff_idx;

(* ram_style = "block" *)
reg [11:0] s_poly [0:255];
(* ram_style = "block" *)
reg [11:0] S_mem [0:S_COEFFS-1];
(* ram_style = "block" *)
reg [11:0] E_mem [0:E_COEFFS-1];

reg        hash_start;
reg        stop_stream;

wire [11:0] S_store_addr;
wire [11:0] E_store_addr;

// CBD sample: one s_poly write per cycle (multi-write per beat breaks BRAM inference).
reg [31:0] hash_word_latched;
reg        sam_active;
reg [2:0]  sam_j;
reg [8:0]  widx_run;

reg [31:0] d_tmp;
reg [1:0] a_bits;
reg [1:0] b_bits;
reg signed [3:0] coeff_s;

assign S_store_addr = {poly_ctr, 8'd0} + {4'd0, store_coeff_idx};
assign E_store_addr = {poly_ctr, 8'd0} + {4'd0, store_coeff_idx};

// Registered read port (1-cycle latency) so S_mem/E_mem infer as Block RAM.
reg [11:0] s_mem_rd_addr_r;
reg [11:0] e_mem_rd_addr_r;

assign hash_start_o = hash_start;
assign hash_mode_o = 2'd1; // MODE_NOISE
assign hash_seed_o = sigma;
assign hash_row_idx_o = 8'd0;
assign hash_col_idx_o = 8'd0;
assign hash_nonce_o = (is_e_r ? (8'd3 + poly_ctr) : {6'd0, poly_ctr}); // s:0..2, e:3..5
assign hash_stop_stream_o = stop_stream;

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        is_e_r <= 1'b0;
        poly_ctr <= 2'd0;
        coeff_count <= 9'd0;
        store_coeff_idx <= 8'd0;
        hash_start <= 1'b0;
        stop_stream <= 1'b0;
        gen_done <= 1'b0;
        busy <= 1'b0;
        sam_active <= 1'b0;
        sam_j <= 3'd0;
        widx_run <= 9'd0;
        hash_word_latched <= 32'd0;
        s_mem_rd_addr_r <= 12'd0;
        e_mem_rd_addr_r <= 12'd0;
        s_mem_rd_data <= 12'd0;
        e_mem_rd_data <= 12'd0;
    end else begin
        hash_start <= 1'b0; // one-cycle pulse default
        gen_done <= 1'b0;

        s_mem_rd_addr_r <= s_mem_rd_addr;
        e_mem_rd_addr_r <= e_mem_rd_addr;
        s_mem_rd_data <= S_mem[s_mem_rd_addr_r];
        e_mem_rd_data <= E_mem[e_mem_rd_addr_r];

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                stop_stream <= 1'b0;
                coeff_count <= 9'd0;
                store_coeff_idx <= 8'd0;

                if (gen_start) begin
                    busy <= 1'b1;
                    is_e_r <= gen_is_e;
                    poly_ctr <= 2'd0;
                    coeff_count <= 9'd0;
                    hash_start <= 1'b1;
                    state <= ST_SAMPLE;
                end
            end

            ST_SAMPLE: begin
                busy <= 1'b1;

                if (!sam_active) begin
                    if (hash_stream_valid_i) begin
                        hash_word_latched <= hash_stream_word_i;
                        widx_run <= coeff_count;
                        sam_active <= 1'b1;
                        sam_j <= 3'd0;
                    end
                end else begin
                    d_tmp = (hash_word_latched & 32'h5555_5555)
                          + ((hash_word_latched >> 1) & 32'h5555_5555);
                    a_bits = (d_tmp >> (4 * sam_j)) & 32'h3;
                    b_bits = (d_tmp >> (4 * sam_j + 2)) & 32'h3;
                    coeff_s = $signed({1'b0, a_bits}) - $signed({1'b0, b_bits});
                    if (widx_run < 9'd256) begin
                        s_poly[widx_run[7:0]] <= {{8{coeff_s[3]}}, coeff_s};
                        widx_run <= widx_run + 9'd1;
                    end
                    if (sam_j == 3'd7) begin
                        sam_active <= 1'b0;
                        coeff_count <= (widx_run < 9'd256) ? (widx_run + 9'd1) : widx_run;
                        if (((widx_run < 9'd256) ? (widx_run + 9'd1) : widx_run) >= 9'd256) begin
                            stop_stream <= 1'b1;
                            state <= ST_WAIT_HASH_DONE;
                        end
                    end else
                        sam_j <= sam_j + 3'd1;
                end
            end

            ST_WAIT_HASH_DONE: begin
                busy <= 1'b1;
                if (hash_done_i) begin
                    stop_stream <= 1'b0;
                    store_coeff_idx <= 8'd0;
                    state <= ST_STORE_POLY;
                end
            end

            ST_STORE_POLY: begin
                busy <= 1'b1;
                if (is_e_r)
                    E_mem[E_store_addr] <= s_poly[store_coeff_idx];
                else
                    S_mem[S_store_addr] <= s_poly[store_coeff_idx];

                if (store_coeff_idx == 8'd255) begin
                    store_coeff_idx <= 8'd0;
                    if (poly_ctr == KYBER_K - 1) begin
                        state <= ST_DONE;
                    end else begin
                        poly_ctr <= poly_ctr + 2'd1;
                        coeff_count <= 9'd0;
                        hash_start <= 1'b1;
                        state <= ST_SAMPLE;
                    end
                end else begin
                    store_coeff_idx <= store_coeff_idx + 8'd1;
                end
            end

            ST_DONE: begin
                busy <= 1'b0;
                gen_done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule


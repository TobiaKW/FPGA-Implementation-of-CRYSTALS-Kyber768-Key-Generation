`timescale 1ns / 1ps

module topserver(
    input             clk,
    input             rst,
    input             top_start,
    input             out_rd_en,
    input             out_rd_sk,      // 0: pk, 1: sk
    input  [11:0]     out_rd_addr,    // byte address
    output reg        top_done,
    output reg        rd_valid,
    output reg [11:0] rd_addr,
    output reg [11:0] rd_data
);

localparam ST_IDLE       = 5'd0;
localparam ST_WAIT_A_GEN = 5'd1;
localparam ST_WAIT_S_GEN = 5'd2;
localparam ST_WAIT_E_GEN = 5'd3;
localparam ST_COMPUTE_AS = 5'd4;
localparam ST_WAIT_AS_DONE= 5'd5;
localparam ST_ADD_E      = 5'd6;
localparam ST_DONE       = 5'd7;
localparam ST_TRNG_INIT  = 5'd8;
localparam ST_TRNG_COLLECT = 5'd9;
localparam ST_HASH_PK_START = 5'd10;
localparam ST_HASH_PK_STREAM = 5'd11;
localparam ST_HASH_PK_WAIT_DONE = 5'd12;
localparam ST_BUILD_PK_INIT = 5'd13;
localparam ST_BUILD_PK_PACK = 5'd14;
localparam ST_HASH_PK_ABSORB = 5'd15;
localparam ST_BUILD_SK_INIT = 5'd16;
localparam ST_BUILD_SK_S_PACK = 5'd17;
localparam ST_BUILD_SK_COPY_PK = 5'd18;
localparam ST_BUILD_SK_COPY_HPK = 5'd19;
localparam ST_BUILD_SK_COPY_Z = 5'd20;

localparam E_COEFFS = 12'd768;  // k*256 for k=3
localparam PK_BYTES = 11'd1184;
localparam PK_WORDS = 9'd296;
localparam SK_BYTES = 12'd2400;

//A, s, e generation modules
reg [4:0] state;
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
wire sel_a, sel_se, sel_top;
wire sel_none;
wire hash_start_mux, hash_stop_mux;
wire [1:0] hash_mode_mux;
wire [255:0] hash_seed_mux;
wire [7:0] hash_row_mux, hash_col_mux, hash_nonce_mux;
reg         top_hash_start;
reg         top_hash_stop;
reg [2:0]   top_hash_word_ctr;
reg [255:0] hpk_reg;
wire [255:0] pk_hash_seed;
reg [5:0]   pk_rho_idx;
reg [8:0]   pk_pair_idx;
reg [10:0]  pk_wr_idx;
wire        top_hash_absorb_ready;
reg [8:0]   top_hash_absorb_idx;
wire [31:0] top_hash_absorb_word;
wire        top_hash_absorb_valid;
wire        top_hash_absorb_last;
reg [11:0]  sk_wr_idx;
reg [8:0]   sk_s_pair_idx;
reg [2:0]   sk_s_sub; // S_PACK: 0->1 wait, 2 latch c0+rd++, 3 wait BRAM, 4/5/6 one byte each
reg [11:0]  sk_s_c0;
reg [10:0]  sk_copy_idx;
reg         keys_ready;
reg  [7:0]  sk [0:2399]; // secret key bytes: s || pk || H(pk) || z

// t_mem BRAM control (array lives in bram_sdp_12x768)
// add_e_phase: 0/1 = wait for t_mem + e_mem registered reads, 2 = latch sum, 3 = WE pulse
reg  [1:0]  add_e_phase;
reg  [11:0] t_mem_wdata_reg;
reg  [2:0]  pk_t_phase; // 0..5: addr0, cap0, addr1, wait, cap1, write sk
reg  [11:0] pk_tc0;
reg  [11:0] pk_tc1;
reg         t_mem_add_we;

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
reg         trng_en;
wire        trng_valid;
wire [7:0]  trng_byte;
reg [6:0]   trng_cnt;
reg [255:0] seed_a_reg;
reg [255:0] sigma_reg;
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

assign sigma = sigma_reg; // independent sigma seed from TRNG
// Legacy 256-bit seed path kept for compatibility; full pk hashing uses absorb stream.
assign pk_hash_seed = {sk[12'd1183], sk[12'd1182], sk[12'd1181], sk[12'd1180],
                       sk[12'd1179], sk[12'd1178], sk[12'd1177], sk[12'd1176],
                       sk[12'd1175], sk[12'd1174], sk[12'd1173], sk[12'd1172],
                       sk[12'd1171], sk[12'd1170], sk[12'd1169], sk[12'd1168],
                       sk[12'd1167], sk[12'd1166], sk[12'd1165], sk[12'd1164],
                       sk[12'd1163], sk[12'd1162], sk[12'd1161], sk[12'd1160],
                       sk[12'd1159], sk[12'd1158], sk[12'd1157], sk[12'd1156],
                       sk[12'd1155], sk[12'd1154], sk[12'd1153], sk[12'd1152]};//reverse order
assign top_hash_absorb_valid = (state == ST_HASH_PK_ABSORB) && (top_hash_absorb_idx < PK_WORDS);
assign top_hash_absorb_last  = (top_hash_absorb_idx == (PK_WORDS - 9'd1));
assign top_hash_absorb_word  = {sk[12'd1152 + (({2'b00, top_hash_absorb_idx} << 2) + 11'd3)],
                                sk[12'd1152 + (({2'b00, top_hash_absorb_idx} << 2) + 11'd2)],
                                sk[12'd1152 + (({2'b00, top_hash_absorb_idx} << 2) + 11'd1)],
                                sk[12'd1152 + (({2'b00, top_hash_absorb_idx} << 2))]};
assign sel_a = a_gen_busy | a_hash_start;
assign sel_se = (~sel_a) & (se_gen_busy | se_hash_start);
assign sel_top = (~sel_a) & (~sel_se) &
                 (state == ST_HASH_PK_START || state == ST_HASH_PK_ABSORB ||
                  state == ST_HASH_PK_STREAM || state == ST_HASH_PK_WAIT_DONE);
assign sel_none = ~sel_a & ~sel_se & ~sel_top;
assign hash_start_mux = sel_a ? a_hash_start : (sel_se ? se_hash_start : (sel_top ? top_hash_start : 1'b0));
assign hash_mode_mux  = sel_a ? a_hash_mode  : (sel_se ? se_hash_mode  : (sel_top ? 2'd2 : 2'd0)); // MODE_SHA3_256
assign hash_seed_mux  = sel_a ? a_hash_seed  : (sel_se ? se_hash_seed  : (sel_top ? pk_hash_seed : 256'd0));
assign hash_row_mux   = sel_a ? a_hash_row_idx : (sel_se ? se_hash_row_idx : 8'd0);
assign hash_col_mux   = sel_a ? a_hash_col_idx : (sel_se ? se_hash_col_idx : 8'd0);
assign hash_nonce_mux = sel_a ? a_hash_nonce : (sel_se ? se_hash_nonce : 8'd0);
assign hash_stop_mux  = sel_a ? a_hash_stop_stream : (sel_se ? se_hash_stop_stream : (sel_top ? top_hash_stop : 1'b0));
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
    .absorb_word_i(top_hash_absorb_word),
    .absorb_valid_i(top_hash_absorb_valid),
    .absorb_last_i(top_hash_absorb_last),
    .absorb_ready_o(top_hash_absorb_ready),
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

// t_mem: inferred Block RAM (must follow mat_vec_mul so t_wr_* are driven)
wire [11:0] t_mem_rdata;
wire [9:0]  t_pb_addr0;
wire [9:0]  t_mem_raddr_i;
wire        t_mem_we;
wire [9:0]  t_mem_waddr;
wire [11:0] t_mem_wdata;

assign t_pb_addr0 = {1'b0, pk_pair_idx} << 1;
assign t_mem_raddr_i =
    (state == ST_BUILD_PK_PACK && pk_rho_idx >= 6'd32 && pk_t_phase == 3'd0) ? t_pb_addr0 :
    (state == ST_BUILD_PK_PACK && pk_rho_idx >= 6'd32 &&
        (pk_t_phase == 3'd2 || pk_t_phase == 3'd3 || pk_t_phase == 3'd4)) ? (t_pb_addr0 + 10'd1) :
    (state == ST_ADD_E) ? rd_addr[9:0] :
    (state == ST_BUILD_PK_PACK && pk_rho_idx >= 6'd32) ? t_pb_addr0 :
    10'd0;

assign t_mem_we     = t_wr_en | t_mem_add_we;
assign t_mem_waddr  = t_wr_en ? t_wr_addr : rd_addr[9:0];
assign t_mem_wdata  = t_wr_en ? t_wr_data : t_mem_wdata_reg;

bram_sdp_12x768 u_t_mem (
    .clk   (clk),
    .we    (t_mem_we),
    .waddr (t_mem_waddr),
    .wdata (t_mem_wdata),
    .raddr (t_mem_raddr_i),
    .rdata (t_mem_rdata)
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
        sigma_reg <= 256'd0;
        z_reg <= 256'd0;
        top_hash_start <= 1'b0;
        top_hash_stop <= 1'b0;
        top_hash_word_ctr <= 3'd0;
        hpk_reg <= 256'd0;
        pk_rho_idx <= 6'd0;
        pk_pair_idx <= 9'd0;
        pk_wr_idx <= 11'd0;
        top_hash_absorb_idx <= 9'd0;
        sk_wr_idx <= 12'd0;
        sk_s_pair_idx <= 9'd0;
        sk_s_sub <= 3'd0;
        sk_s_c0 <= 12'd0;
        sk_copy_idx <= 11'd0;
        keys_ready <= 1'b0;
        add_e_phase <= 2'd0;
        t_mem_wdata_reg <= 12'd0;
        pk_t_phase <= 3'd0;
        pk_tc0 <= 12'd0;
        pk_tc1 <= 12'd0;
        t_mem_add_we <= 1'b0;
    end else begin
        t_mem_add_we <= 1'b0;

        a_gen_start <= 1'b0; // default pulse-low
        se_gen_start <= 1'b0; // default pulse-low
        mat_vec_mul_start <= 1'b0; // default pulse-low
        top_done <= 1'b0;
        rd_valid <= 1'b0;
        top_hash_start <= 1'b0;
        top_hash_stop <= 1'b0;

        case (state)
            ST_IDLE: begin
                rd_addr <= 12'd0;
                if (top_start) begin
                    keys_ready <= 1'b0;
                    state <= ST_TRNG_INIT;
                end
            end

            ST_TRNG_INIT: begin
                trng_en <= 1'b1;
                trng_cnt <= 7'd0;
                seed_a_reg <= 256'd0;
                sigma_reg <= 256'd0;
                z_reg <= 256'd0;
                state <= ST_TRNG_COLLECT;
            end

            ST_TRNG_COLLECT: begin
                trng_en <= 1'b1;
                if (trng_valid) begin
                    if (trng_cnt < 7'd32) begin
                        // Byte-addressed rho capture prevents shift-propagated X spread.
                        sk[12'd1152 + trng_cnt[4:0]] <= trng_byte;
                        seed_a_reg[trng_cnt*8 +: 8] <= trng_byte;
                    end
                    else if (trng_cnt < 7'd64)
                        sigma_reg <= {sigma_reg[247:0], trng_byte};
                    else
                        z_reg <= {z_reg[247:0], trng_byte};

                    if (trng_cnt == 7'd95) begin
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
                    add_e_phase <= 2'd0;
                    state <= ST_ADD_E;
                end
            end

            ST_ADD_E: begin
                // Final t = A*s + e (mod q). e_mem and t_mem are registered reads (1-cycle latency).
                case (add_e_phase)
                    2'd0: add_e_phase <= 2'd1;
                    2'd1: add_e_phase <= 2'd2;
                    2'd2: begin
                        t_mem_wdata_reg <= add_mod_q12(t_mem_rdata, e_mem_rd_data);
                        add_e_phase <= 2'd3;
                    end
                    default: begin // 2'd3
                        t_mem_add_we <= 1'b1;
                        if (rd_addr == (E_COEFFS - 1'b1)) begin
                            state <= ST_BUILD_PK_INIT;
                            add_e_phase <= 2'd0;
                        end else begin
                            rd_addr <= rd_addr + 12'd1;
                            add_e_phase <= 2'd0;
                        end
                    end
                endcase
            end

            ST_BUILD_PK_INIT: begin
                // pk[0:31] already captured directly during TRNG collection.
                pk_rho_idx <= 6'd32;
                pk_pair_idx <= 9'd0;
                pk_wr_idx <= 11'd32;
                pk_t_phase <= 3'd0;
                state <= ST_BUILD_PK_PACK;
            end

            ST_BUILD_PK_PACK: begin
                if (pk_rho_idx < 6'd32) begin
                    sk[12'd1152 + pk_rho_idx] <= seed_a_reg[pk_rho_idx*8 +: 8];
                    pk_rho_idx <= pk_rho_idx + 5'd1;
                end else begin
                    // Pack (c0,c1) from t_mem via BRAM read pipeline (pk_t_phase 0..5).
                    case (pk_t_phase)
                        3'd0: pk_t_phase <= 3'd1;
                        3'd1: begin
                            pk_tc0 <= t_mem_rdata;
                            pk_t_phase <= 3'd2;
                        end
                        3'd2: pk_t_phase <= 3'd3;
                        3'd3: pk_t_phase <= 3'd4;
                        3'd4: begin
                            pk_tc1 <= t_mem_rdata;
                            pk_t_phase <= 3'd5;
                        end
                        default: begin // 3'd5
                            sk[12'd1152 + pk_wr_idx] <= pk_tc0[7:0];
                            sk[12'd1152 + pk_wr_idx + 11'd1] <= {pk_tc1[3:0], pk_tc0[11:8]};
                            sk[12'd1152 + pk_wr_idx + 11'd2] <= pk_tc1[11:4];
                            if (pk_pair_idx == 9'd383) begin
                                state <= ST_HASH_PK_START;
                            end else begin
                                pk_pair_idx <= pk_pair_idx + 9'd1;
                                pk_wr_idx <= pk_wr_idx + 11'd3;
                                pk_t_phase <= 3'd0;
                            end
                        end
                    endcase
                end
            end

            ST_HASH_PK_START: begin
                top_hash_word_ctr <= 3'd0;
                hpk_reg <= 256'd0;
                top_hash_absorb_idx <= 9'd0;
                top_hash_start <= 1'b1; //tell hash_unit to use SHA3-256 mode
                state <= ST_HASH_PK_ABSORB;
            end

            ST_HASH_PK_ABSORB: begin
                if (top_hash_absorb_ready && top_hash_absorb_valid) begin
                    if (top_hash_absorb_idx == (PK_WORDS - 9'd1))
                        state <= ST_HASH_PK_STREAM;
                    else
                        top_hash_absorb_idx <= top_hash_absorb_idx + 9'd1;
                end
            end

            ST_HASH_PK_STREAM: begin
                if (shared_stream_valid) begin
                    hpk_reg <= {hpk_reg[223:0], shared_stream_word};
                    if (top_hash_word_ctr == 3'd7) begin
                        top_hash_stop <= 1'b1;
                        state <= ST_HASH_PK_WAIT_DONE;
                    end else begin
                        top_hash_word_ctr <= top_hash_word_ctr + 3'd1;
                    end
                end
            end

            ST_HASH_PK_WAIT_DONE: begin
                if (shared_hash_done)
                    state <= ST_BUILD_SK_INIT;
            end

            ST_BUILD_SK_INIT: begin
                rd_addr <= 12'd0;
                sk_wr_idx <= 12'd0;
                sk_s_pair_idx <= 9'd0;
                sk_s_sub <= 3'd0;
                sk_copy_idx <= 11'd0;
                state <= ST_BUILD_SK_S_PACK;
            end

            ST_BUILD_SK_S_PACK: begin
                // Pack s: 768x12-bit -> 1152 bytes (BRAM read latency + one sk[] write/cycle for reliable inference)
                case (sk_s_sub)
                    3'd0: sk_s_sub <= 3'd1;
                    3'd1: sk_s_sub <= 3'd2;
                    3'd2: begin
                        sk_s_c0 <= s_mem_rd_data;
                        rd_addr <= rd_addr + 12'd1;
                        sk_s_sub <= 3'd3;
                    end
                    3'd3: sk_s_sub <= 3'd4;
                    3'd4: begin
                        sk[sk_wr_idx] <= sk_s_c0[7:0];
                        sk_s_sub <= 3'd5;
                    end
                    3'd5: begin
                        sk[sk_wr_idx + 12'd1] <= {s_mem_rd_data[3:0], sk_s_c0[11:8]};
                        sk_s_sub <= 3'd6;
                    end
                    3'd6: begin
                        sk[sk_wr_idx + 12'd2] <= s_mem_rd_data[11:4];
                        sk_wr_idx <= sk_wr_idx + 12'd3;
                        rd_addr <= rd_addr + 12'd1;
                        if (sk_s_pair_idx == 9'd383) begin
                            sk_copy_idx <= 11'd0;
                            state <= ST_BUILD_SK_COPY_HPK;
                        end else begin
                            sk_s_pair_idx <= sk_s_pair_idx + 9'd1;
                        end
                        sk_s_sub <= 3'd0;
                    end
                    default: sk_s_sub <= 3'd0;
                endcase
            end

            ST_BUILD_SK_COPY_PK: begin
                // PK already built directly into sk[1152:2335].
                state <= ST_BUILD_SK_COPY_HPK;
            end

            ST_BUILD_SK_COPY_HPK: begin
                sk[12'd2336 + sk_copy_idx] <= hpk_reg[sk_copy_idx*8 +: 8];
                if (sk_copy_idx == 11'd31) begin
                    sk_copy_idx <= 11'd0;
                    state <= ST_BUILD_SK_COPY_Z;
                end else begin
                    sk_copy_idx <= sk_copy_idx + 11'd1;
                end
            end

            ST_BUILD_SK_COPY_Z: begin
                sk[12'd2368 + sk_copy_idx] <= z_reg[sk_copy_idx*8 +: 8];
                if (sk_copy_idx == 11'd31)
                    state <= ST_DONE;
                else
                    sk_copy_idx <= sk_copy_idx + 11'd1;
            end

            ST_DONE: begin
                top_done <= 1'b1;
                keys_ready <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase

        // Byte-addressed readout for PK/SK after key generation completes.
        if (out_rd_en && keys_ready) begin
            rd_valid <= 1'b1;
            if (out_rd_sk) begin
                if (out_rd_addr < SK_BYTES)
                    rd_data <= {4'd0, sk[out_rd_addr]};
                else
                    rd_data <= 12'd0;
            end else begin
                if (out_rd_addr < PK_BYTES)
                    rd_data <= {4'd0, sk[12'd1152 + out_rd_addr]};
                else
                    rd_data <= 12'd0;
            end
        end
    end
end

endmodule

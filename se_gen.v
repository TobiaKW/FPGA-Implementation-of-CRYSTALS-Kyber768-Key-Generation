`timescale 1ns / 1ps

// Shared noise generator for s and e.
// DEMO ONLY: deterministic lightweight filler, not Kyber-compliant CBD/PRF.
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
localparam ST_FILL           = 3'd1;
localparam ST_DONE           = 3'd3;

reg [2:0] state;
reg       is_e_r;
reg [9:0] coeff_count;
(* ram_style = "block" *)
reg [11:0] S_mem [0:S_COEFFS-1];
(* ram_style = "block" *)
reg [11:0] E_mem [0:E_COEFFS-1];

reg [15:0] lfsr;
wire       lfsr_fb;
reg [2:0] raw3;
reg [2:0] rem5;
reg signed [3:0] coeff_s;

// Registered read address (1-cycle latency). Reads are in a separate always
// block from writes so BRAM inference does not pick up huge bypass muxes.
reg [11:0] s_mem_rd_addr_r;
reg [11:0] e_mem_rd_addr_r;

assign lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

// In demo mode se_gen does not consume the shared hash unit.
assign hash_start_o = 1'b0;
assign hash_mode_o = 2'd1; // MODE_NOISE
assign hash_seed_o = sigma;
assign hash_row_idx_o = 8'd0;
assign hash_col_idx_o = 8'd0;
assign hash_nonce_o = 8'd0;
assign hash_stop_stream_o = 1'b0;

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        is_e_r <= 1'b0;
        coeff_count <= 10'd0;
        lfsr <= 16'h1ACE;
        gen_done <= 1'b0;
        busy <= 1'b0;
        s_mem_rd_addr_r <= 12'd0;
        e_mem_rd_addr_r <= 12'd0;
        s_mem_rd_data <= 12'd0;
        e_mem_rd_data <= 12'd0;
    end else begin
        gen_done <= 1'b0;

        s_mem_rd_addr_r <= s_mem_rd_addr;
        e_mem_rd_addr_r <= e_mem_rd_addr;

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                coeff_count <= 10'd0;

                if (gen_start) begin
                    busy <= 1'b1;
                    is_e_r <= gen_is_e;
                    coeff_count <= 10'd0;
                    lfsr <= sigma[15:0] ^ sigma[31:16] ^ sigma[47:32] ^ sigma[63:48] ^
                            sigma[79:64] ^ sigma[95:80] ^ sigma[111:96] ^ sigma[127:112] ^
                            sigma[143:128] ^ sigma[159:144] ^ sigma[175:160] ^ sigma[191:176] ^
                            sigma[207:192] ^ sigma[223:208] ^ sigma[239:224] ^ sigma[255:240] ^
                            16'h1ACE ^ {15'd0, gen_is_e};
                    state <= ST_FILL;
                end
            end

            ST_FILL: begin
                busy <= 1'b1;
                raw3 = lfsr[2:0];
                case (raw3)
                    3'd0: rem5 = 3'd0;
                    3'd1: rem5 = 3'd1;
                    3'd2: rem5 = 3'd2;
                    3'd3: rem5 = 3'd3;
                    3'd4: rem5 = 3'd4;
                    3'd5: rem5 = 3'd0;
                    3'd6: rem5 = 3'd1;
                    default: rem5 = 3'd2;
                endcase

                coeff_s = $signed({1'b0, rem5}) - 4'sd2;
                if (is_e_r)
                    E_mem[coeff_count] <= {{8{coeff_s[3]}}, coeff_s};
                else
                    S_mem[coeff_count] <= {{8{coeff_s[3]}}, coeff_s};

                lfsr <= {lfsr[14:0], lfsr_fb};
                if (coeff_count == 10'd767) begin
                    state <= ST_DONE;
                end else begin
                    coeff_count <= coeff_count + 10'd1;
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

// Separate read port: avoids read+write in the same always block as the sampler
// (which otherwise explodes LUT glue around inferred BRAM).
always @(posedge clk) begin
    if (rst) begin
        s_mem_rd_data <= 12'd0;
        e_mem_rd_data <= 12'd0;
    end else begin
        s_mem_rd_data <= S_mem[s_mem_rd_addr_r];
        e_mem_rd_data <= E_mem[e_mem_rd_addr_r];
    end
end

endmodule


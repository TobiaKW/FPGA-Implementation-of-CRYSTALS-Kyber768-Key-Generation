`timescale 1ns / 1ps

module e_gen(
    input             clk,
    input             rst,
    input             e_gen_start,
    input  [255:0]    sigma,          // noise seed (32 bytes)
    input  [11:0]     e_mem_rd_addr,  // flattened E memory read address
    output reg        e_gen_done,
    output reg        busy,
    output [11:0]     e_mem_rd_data   // flattened E memory read data
);

localparam KYBER_K  = 3;
localparam POLY_N   = 256;
localparam E_COEFFS = KYBER_K * POLY_N;

localparam ST_IDLE           = 3'd0;
localparam ST_SAMPLE         = 3'd1;
localparam ST_WAIT_HASH_DONE = 3'd2;
localparam ST_STORE_POLY     = 3'd3;
localparam ST_DONE           = 3'd4;

reg [2:0] state;

reg [1:0] poly_ctr; // 0..2 for k=3
reg [8:0] coeff_count;
reg [7:0] store_coeff_idx;

reg [11:0] e_poly [0:255];
reg [11:0] E_mem [0:E_COEFFS-1];

reg        hash_start;
reg        stop_stream;
wire       hash_done;
wire [31:0] stream_word;
wire        stream_valid;

wire [11:0] E_store_addr;

integer j;
reg [31:0] d_tmp;
reg [8:0] widx;
reg [1:0] a_bits;
reg [1:0] b_bits;
reg signed [3:0] coeff_e;
assign E_store_addr = {poly_ctr, 8'd0} + {4'd0, store_coeff_idx};
assign e_mem_rd_data = E_mem[e_mem_rd_addr];

// MODE_NOISE = 2'd1 in hash_unit
hash_unit u_hash_unit (
    .clk(clk),
    .rst(rst),
    .start(hash_start),
    .mode(2'd1),
    .seed(sigma),
    .row_idx(8'd0),
    .col_idx(8'd0),
    .nonce(8'd3 + poly_ctr), // distinct nonce per e polynomial (3,4,5)
    .stop_stream(stop_stream),
    .busy(),
    .done(hash_done),
    .stream_word(stream_word),
    .stream_valid(stream_valid),
    .stream_ready(1'b1)
);

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        poly_ctr <= 2'd0;
        coeff_count <= 9'd0;
        store_coeff_idx <= 8'd0;
        hash_start <= 1'b0;
        stop_stream <= 1'b0;
        e_gen_done <= 1'b0;
        busy <= 1'b0;
    end else begin
        hash_start <= 1'b0; // one-cycle pulse default
        e_gen_done <= 1'b0;

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                stop_stream <= 1'b0;
                coeff_count <= 9'd0;
                store_coeff_idx <= 8'd0;

                if (e_gen_start) begin
                    busy <= 1'b1;
                    poly_ctr <= 2'd0;
                    coeff_count <= 9'd0;
                    hash_start <= 1'b1;
                    state <= ST_SAMPLE;
                end
            end

            ST_SAMPLE: begin
                busy <= 1'b1;

                if (stream_valid) begin
                    // CBD eta=2 reference:
                    // d = (t & 0x55555555) + ((t >> 1) & 0x55555555)
                    // for j=0..7:
                    //   a = (d >> (4*j)) & 0x3
                    //   b = (d >> (4*j+2)) & 0x3
                    //   coeff = a - b
                    d_tmp = (stream_word & 32'h5555_5555) + ((stream_word >> 1) & 32'h5555_5555);
                    widx = coeff_count;

                    for (j = 0; j < 8; j = j + 1) begin
                        if (widx < 9'd256) begin
                            a_bits = (d_tmp >> (4*j)) & 32'h3;
                            b_bits = (d_tmp >> (4*j + 2)) & 32'h3;
                            coeff_e = $signed({1'b0, a_bits}) - $signed({1'b0, b_bits});
                            e_poly[widx[7:0]] <= {{8{coeff_e[3]}}, coeff_e};
                            widx = widx + 9'd1;
                        end
                    end

                    coeff_count <= widx;
                    if (widx >= 9'd256) begin
                        stop_stream <= 1'b1;
                        state <= ST_WAIT_HASH_DONE;
                    end
                end
            end

            ST_WAIT_HASH_DONE: begin
                busy <= 1'b1;
                if (hash_done) begin
                    stop_stream <= 1'b0;
                    store_coeff_idx <= 8'd0;
                    state <= ST_STORE_POLY;
                end
            end

            ST_STORE_POLY: begin
                busy <= 1'b1;
                E_mem[E_store_addr] <= e_poly[store_coeff_idx];

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
                e_gen_done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule


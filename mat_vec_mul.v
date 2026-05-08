`timescale 1ns / 1ps

// Generic 3x3 matrix times 3x1 vector (polynomial-coefficient domain).
// Computes: y = M * v  (mod q), without +e.
//
// Flattened addressing convention:
// - M[i][j][n] -> ((i*3 + j) << 8) + n
// - v[j][n]    -> (j << 8) + n
// - y[i][n]    -> (i << 8) + n
module mat_vec_mul(
    input             clk,
    input             rst,
    input             start,

    output reg [11:0] mat_rd_addr,
    input      [11:0] mat_rd_data,
    output reg [11:0] vec_rd_addr,
    input      [11:0] vec_rd_data,

    output reg        out_wr_en,
    output reg [9:0]  out_wr_addr,   // 3*256 = 768 entries
    output reg [11:0] out_wr_data,

    output reg        done,
    output reg        busy
);

localparam K = 3;
localparam N = 256;
localparam Q = 3329;

localparam ST_IDLE    = 3'd0;
localparam ST_SETADDR = 3'd1;
localparam ST_ACCUM   = 3'd2;//replace with NTT later
localparam ST_WRITE   = 3'd3;
localparam ST_NEXT    = 3'd4;
localparam ST_DONE    = 3'd5;

reg [2:0] state;
reg [1:0] row_idx; //0,1,2
reg [1:0] col_idx; //0,1,2
reg [7:0] coeff_idx; //0-255


reg signed [31:0] acc;

function [11:0] mod_q12;
    input signed [31:0] x;
    reg signed [31:0] r;
begin
    // signed modulo operation: do modulo but keep the sign
    // in this fuction output is kept in range [0:Q-1]
    r = x % Q; // modulo Q=3329
    if (r < 0)
        r = r + Q;
    mod_q12 = r[11:0];
end
endfunction

always @(posedge clk) begin
    if (rst) begin
        state <= ST_IDLE;
        row_idx <= 2'd0;
        col_idx <= 2'd0;
        coeff_idx <= 8'd0;
        acc <= 32'sd0;

        mat_rd_addr <= 12'd0;
        vec_rd_addr <= 12'd0;
        out_wr_en <= 1'b0;
        out_wr_addr <= 10'd0;
        out_wr_data <= 12'd0;
        done <= 1'b0;
        busy <= 1'b0;
    end else begin
        out_wr_en <= 1'b0;
        done <= 1'b0;

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                row_idx <= 2'd0;
                col_idx <= 2'd0;
                coeff_idx <= 8'd0;
                acc <= 32'sd0;
                if (start) begin
                    busy <= 1'b1;
                    state <= ST_SETADDR;
                end
            end

            ST_SETADDR: begin
                mat_rd_addr <= (((row_idx * K) + col_idx) << 8) + coeff_idx;
                vec_rd_addr <= (col_idx << 8) + coeff_idx;
                state <= ST_ACCUM;
            end

            ST_ACCUM: begin
                acc <= acc + ($signed({1'b0, mat_rd_data}) * $signed(vec_rd_data));
                if (col_idx == K - 1) begin
                    state <= ST_WRITE;
                end else begin
                    col_idx <= col_idx + 2'd1;
                    state <= ST_SETADDR;
                end
                //NOTE: no need to care about fold-back coeff here, it will be covered by polmul later
            end

            ST_WRITE: begin
                out_wr_en <= 1'b1;
                out_wr_addr <= (row_idx << 8) + coeff_idx;
                out_wr_data <= mod_q12(acc);
                state <= ST_NEXT;
            end

            ST_NEXT: begin
                acc <= 32'sd0;
                col_idx <= 2'd0;

                if (coeff_idx == 8'd255) begin
                    coeff_idx <= 8'd0;
                    if (row_idx == K - 1) begin
                        state <= ST_DONE;
                    end else begin
                        row_idx <= row_idx + 2'd1;
                        state <= ST_SETADDR;
                    end
                end else begin
                    coeff_idx <= coeff_idx + 8'd1;
                    state <= ST_SETADDR;
                end
            end

            ST_DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule

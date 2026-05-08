`timescale 1ns / 1ps

module s_gen(
    input             clk,
    input             rst,
    input             s_gen_start,
    input  [255:0]    seed_a,       // rho: 32-byte public matrix seed
    input  [11:0]     s_mem_rd_addr, // flattened S memory read address
    output reg        s_gen_done,
    output reg        busy,
    output [11:0]     s_mem_rd_data // flattened S memory read data
);

// FSM states (direct keccak_dout sampling path)
localparam ST_IDLE              = 4'd0;
localparam ST_INIT_WAIT         = 4'd1;
localparam ST_ABSORB            = 4'd2;
localparam ST_WAIT_KECCAK_READY = 4'd3;
localparam ST_SAMPLE_KECCAK     = 4'd4;
localparam ST_STORE_POLY        = 4'd5;
localparam ST_NEXT_CELL         = 4'd6;
localparam ST_DONE              = 4'd7;

localparam KYBER_K      = 3;
localparam POLY_N       = 256;
localparam MATRIX_CELLS = KYBER_K * 1; // s is a 3x1 vector
localparam S_COEFFS     = MATRIX_CELLS * POLY_N;


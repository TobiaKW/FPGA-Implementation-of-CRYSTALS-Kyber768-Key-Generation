`timescale 1ns / 1ps

module topserver(
    input             clk,
    input             rst,
    input             keygen_start,
    input  [255:0]    seed_a,       // rho: 32-byte public matrix seed
    input  [7:0]      row_idx,      // A[row_idx][col_idx]
    input  [7:0]      col_idx,
    output reg        keygen_done,
    output reg        busy,
    output reg [11:0] a_coeff,      // demo: one sampled coefficient from output stream
    output reg        a_coeff_valid,
    output reg [255:0] pk,          // placeholder
    output reg [255:0] sk           // placeholder
);

// -----------------------------------------------------------------------------
//TODO
//Treat seed_a as rho (public matrix seed, 32 bytes).
//For each matrix element A[i][j]:
// absorb rho || col_idx || row_idx (note the order used in Kyber ref; usually column/row bytes)
//squeeze bytes from SHAKE128
//parse into 12-bit candidates
//keep values < q (q=3329) via rejection sampling
//collect 256 coefficients for one polynomial
//Repeat for all k x k polynomials (k=2/3/4 depending Kyber level).
// -----------------------------------------------------------------------------

//FSM states
localparam ST_IDLE       = 3'd0;
localparam ST_ABSORB     = 3'd1;
localparam ST_WAIT_READY = 3'd2;
localparam ST_READ_REQ   = 3'd3;
localparam ST_CAPTURE    = 3'd4;
localparam ST_DONE       = 3'd5;


reg [2:0] state;
reg [3:0] absorb_word_ctr; // 0..8 (8 seed words + 1 index word)
reg [7:0] row_ctr;
reg [7:0] col_ctr;
reg       ready_seen;

// hash_core_Server controls
reg        keccak_init;
reg        extend;
reg        patt_bit;
reg        eta3_bit;
reg [1:0]  absorb_ctr_r1;
reg [2:0]  keccak_ctr;
reg        ififo_wen;
reg [31:0] ififo_din;
reg        ififo_absorb;
reg [1:0]  ififo_mode;
reg        ififo_last;
reg        ofifo_ena;
reg        ofifo0_req;
reg        ofifo1_req;

// hash_core_Server outputs
wire        ififo_empty;
wire        keccak_ready;
wire        keccak_squeeze;
wire [31:0] keccak_dout;
wire [23:0] ofifo0_dout;
wire [24:0] ofifo1_dout;
wire        ofifo0_full;
wire        ofifo1_full;
wire        ofifo0_empty;
wire        ofifo1_empty;
wire [5:0]  squeeze_ctr;
wire [7:0]  fifo_GENA_ctr;

//component declaration
hash_core_Server u_hash_core (
    .clk(clk),
    .rst(rst),
    .keccak_init(keccak_init),
    .extend(extend),
    .patt_bit(patt_bit),
    .eta3_bit(eta3_bit),
    .absorb_ctr_r1(absorb_ctr_r1),
    .keccak_ctr(keccak_ctr),
    .ififo_wen(ififo_wen),
    .ififo_din(ififo_din),
    .ififo_absorb(ififo_absorb),
    .ififo_mode(ififo_mode),
    .ififo_last(ififo_last),
    .ififo_empty(ififo_empty),
    .keccak_ready(keccak_ready),
    .keccak_squeeze(keccak_squeeze),
    .keccak_dout(keccak_dout),
    .ofifo_ena(ofifo_ena),
    .ofifo0_req(ofifo0_req),
    .ofifo1_req(ofifo1_req),
    .ofifo0_dout(ofifo0_dout),
    .ofifo1_dout(ofifo1_dout),
    .ofifo0_full(ofifo0_full),
    .ofifo1_full(ofifo1_full),
    .ofifo0_empty(ofifo0_empty),
    .ofifo1_empty(ofifo1_empty),
    .squeeze_ctr(squeeze_ctr),
    .fifo_GENA_ctr(fifo_GENA_ctr)
);

always @(posedge clk) begin
    if (rst) begin 
        state <= ST_IDLE;
        absorb_word_ctr <= 4'd0;
        row_ctr <= 8'd0;
        col_ctr <= 8'd0;
        ready_seen <= 1'b0;
        keygen_done <= 1'b0;
        busy <= 1'b0;
        a_coeff <= 12'd0;
        a_coeff_valid <= 1'b0;
        pk <= 256'd0;
        sk <= 256'd0;

        keccak_init <= 1'b0;
        extend <= 1'b0;
        patt_bit <= 1'b0;
        eta3_bit <= 1'b0;
        absorb_ctr_r1 <= 2'd0;
        keccak_ctr <= 3'h1;     // enables internal output FIFO writes
        ififo_wen <= 1'b0;
        ififo_din <= 32'd0;
        ififo_absorb <= 1'b0;
        ififo_mode <= 2'b01;    // 16-word mode; we send 9 words + internal pad
        ififo_last <= 1'b0;
        ofifo_ena <= 1'b0;
        ofifo0_req <= 1'b0;
        ofifo1_req <= 1'b0;
    end else begin
        // default one-cycle pulses
        keccak_init <= 1'b0;
        ififo_wen <= 1'b0;
        ififo_last <= 1'b0;
        ofifo0_req <= 1'b0;
        a_coeff_valid <= 1'b0;
        keygen_done <= 1'b0;

        // Latch short keccak_ready pulses so FSM can react safely.
        if (keccak_ready) begin
            ready_seen <= 1'b1;
        end

        case (state)
            ST_IDLE: begin
                //state IDLE: check for keygen_start every cycle
                busy <= 1'b0;
                ofifo_ena <= 1'b0;
                absorb_word_ctr <= 4'd0;
                ready_seen <= 1'b0;
                if (keygen_start) begin
                    //signal detected, init keccak core and change state to ABSORB
                    busy <= 1'b1;
                    row_ctr <= row_idx;
                    col_ctr <= col_idx;
                    keccak_init <= 1'b1; //we reset keccak_init every cycle
                    ready_seen <= 1'b0;
                    state <= ST_ABSORB;
                end else begin
                    row_ctr <= 8'd0;
                    col_ctr <= 8'd0;
                end
            end

            ST_ABSORB: begin
                // feed one word per clock into input FIFO:
                // 8 seed words + 1 selector word {col,row}
                ififo_wen <= 1'b1;
                if (absorb_word_ctr < 4'd8) begin
                    ififo_din <= seed_a[absorb_word_ctr*32 +: 32]; // absorb the seed_a in 8 words
                end else begin
                    ififo_din <= {16'h0000, col_ctr, row_ctr}; // absorb the col_idx and row_idx with 16 bits zero padding before
                    ififo_last <= 1'b1;
                end

                if (absorb_word_ctr == 4'd8) begin
                    absorb_word_ctr <= 4'd0;
                    state <= ST_WAIT_READY;
                end else begin
                    absorb_word_ctr <= absorb_word_ctr + 4'd1;
                end
            end

            ST_WAIT_READY: begin
                if (ready_seen && !ofifo0_empty) begin
                    state <= ST_READ_REQ;
                end
            end

            ST_READ_REQ: begin
                // Read only when data is available.
                if (!ofifo0_empty) begin
                    ofifo0_req <= 1'b1;
                    state <= ST_CAPTURE;
                end
            end

            ST_CAPTURE: begin
                // Capture one sample coefficient (bootstrap path).
                a_coeff <= ofifo0_dout[11:0];
                a_coeff_valid <= 1'b1;
                ready_seen <= 1'b0;
                state <= ST_DONE;
            end

            ST_DONE: begin
                busy <= 1'b0;
                keygen_done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule
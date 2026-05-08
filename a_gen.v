`timescale 1ns / 1ps

module a_gen(
    input             clk,
    input             rst,
    input             keygen_start,
    input  [255:0]    seed_a,       // rho: 32-byte public matrix seed
    input  [11:0]     a_mem_rd_addr, // flattened A memory read address
    output reg        keygen_done,
    output reg        busy,
    output [11:0]     a_mem_rd_data // flattened A memory read data
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
localparam MATRIX_CELLS = KYBER_K * KYBER_K;
localparam A_COEFFS     = MATRIX_CELLS * POLY_N;


reg [3:0] state;
reg [3:0] absorb_word_ctr; // 0..8 (8 rho words + 1 index word)
reg [7:0] row_ctr;
reg [7:0] col_ctr;
reg       ready_seen;
reg [1:0] init_wait_ctr;
reg [8:0] coeff_count;
reg [5:0] sample_squeeze_ctr;
reg [11:0] a_poly [0:255];
reg [11:0] A_mem [0:A_COEFFS-1];
reg [3:0] cell_ctr;
reg [7:0] store_coeff_idx;

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
wire        cand0_valid;
wire        cand1_valid;
wire [11:0] cand0;
wire [11:0] cand1;
wire [11:0] A_store_addr;

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

assign cand0 = keccak_dout[11:0];
assign cand1 = keccak_dout[23:12];
assign cand0_valid = (cand0 < 12'd3329);
assign cand1_valid = (cand1 < 12'd3329);
assign A_store_addr = {cell_ctr, 8'd0} + {4'd0, store_coeff_idx};
assign a_mem_rd_data = A_mem[a_mem_rd_addr];

always @(posedge clk) begin
    if (rst) begin 
        state <= ST_IDLE;
        absorb_word_ctr <= 4'd0;
        row_ctr <= 8'd0;
        col_ctr <= 8'd0;
        ready_seen <= 1'b0;
        init_wait_ctr <= 2'd0;
        coeff_count <= 9'd0;
        sample_squeeze_ctr <= 6'd0;
        cell_ctr <= 4'd0;
        store_coeff_idx <= 8'd0;
        keygen_done <= 1'b0;
        busy <= 1'b0;

        keccak_init <= 1'b0;
        extend <= 1'b0;
        patt_bit <= 1'b0;
        eta3_bit <= 1'b0;
        absorb_ctr_r1 <= 2'd0;
        keccak_ctr <= 3'h1;     // enables internal output FIFO writes
        ififo_wen <= 1'b0;
        ififo_din <= 32'd0;
        ififo_absorb <= 1'b0;
        ififo_mode <= 2'b01;    // 16-word framing for 9-word absorb
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
        keygen_done <= 1'b0;
        ififo_absorb <= 1'b0;

        // Latch short keccak_ready pulses so FSM can react safely.
        if (keccak_ready) begin
            ready_seen <= 1'b1;
        end

        case (state)
            ST_IDLE: begin
                //state IDLE: check for keygen_start every cycle
                busy <= 1'b0;
                ofifo_ena <= 1'b0;
                extend <= 1'b0;
                absorb_word_ctr <= 4'd0;
                ready_seen <= 1'b0;
                coeff_count <= 9'd0;
                sample_squeeze_ctr <= 6'd0;
                store_coeff_idx <= 8'd0;
                if (keygen_start) begin
                    // Generate full 3x3 matrix A starting at A[0][0].
                    busy <= 1'b1;
                    row_ctr <= 8'd0;
                    col_ctr <= 8'd0;
                    cell_ctr <= 4'd0;
                    patt_bit <= 1'b0;
                    eta3_bit <= 1'b0;
                    keccak_ctr <= 3'h1;
                    ififo_mode <= 2'b01; // 9-word absorb (rho||j||i packed in last word)
                    ofifo_ena <= 1'b1;
                    keccak_init <= 1'b1;
                    ready_seen <= 1'b0;
                    init_wait_ctr <= 2'd0;
                    state <= ST_INIT_WAIT;
                end else begin
                    row_ctr <= 8'd0;
                    col_ctr <= 8'd0;
                end
            end

            ST_INIT_WAIT: begin
                //wait 2 cycles after init pulse.
                busy <= 1'b1;
                ofifo_ena <= 1'b1;
                if (init_wait_ctr == 2'd2) begin
                    state <= ST_ABSORB;
                end else begin
                    init_wait_ctr <= init_wait_ctr + 2'd1;
                end
            end

            ST_ABSORB: begin
                busy <= 1'b1;
                ofifo_ena <= 1'b1;
                // feed one word per clock into input FIFO:
                // rho || j || i as 9 words (8 rho words + one index word)
                ififo_wen <= 1'b1;
                ififo_absorb <= 1'b0;
                if (absorb_word_ctr < 4'd8) begin
                    ififo_din <= seed_a[absorb_word_ctr*32 +: 32];
                end else begin
                    // index word packs j then i in low bytes
                    ififo_din <= {16'h0000, col_ctr, row_ctr};
                end
                if (absorb_word_ctr == 4'd8) begin
                    ififo_last <= 1'b1;
                end

                if (absorb_word_ctr == 4'd8) begin
                    absorb_word_ctr <= 4'd0;
                    state <= ST_WAIT_KECCAK_READY;
                end else begin
                    absorb_word_ctr <= absorb_word_ctr + 4'd1;
                end
            end

            ST_WAIT_KECCAK_READY: begin
                busy <= 1'b1;
                ofifo_ena <= 1'b1;
                if (ready_seen) begin
                    // Start XOF extension only after first permutation finishes.
                    extend <= 1'b1;
                    sample_squeeze_ctr <= squeeze_ctr;
                    state <= ST_SAMPLE_KECCAK;
                end
            end

            ST_SAMPLE_KECCAK: begin
                busy <= 1'b1;
                ofifo_ena <= 1'b1;
                extend <= 1'b1;

                // Count each SHAKE word once. squeeze_ctr advances while extend is high.
                if (squeeze_ctr != sample_squeeze_ctr) begin
                    sample_squeeze_ctr <= squeeze_ctr;

                    if (cand0_valid && cand1_valid) begin
                        if (coeff_count <= 9'd253) begin
                            a_poly[coeff_count[7:0]] <= cand0;
                            a_poly[coeff_count[7:0] + 8'd1] <= cand1;
                            coeff_count <= coeff_count + 9'd2;
                        end else if (coeff_count == 9'd254) begin
                            a_poly[8'd254] <= cand0;
                            a_poly[8'd255] <= cand1;
                            coeff_count <= 9'd256;
                            store_coeff_idx <= 8'd0;
                            ready_seen <= 1'b0;
                            state <= ST_STORE_POLY;
                        end else begin
                            a_poly[8'd255] <= cand0;
                            coeff_count <= 9'd256;
                            store_coeff_idx <= 8'd0;
                            ready_seen <= 1'b0;
                            state <= ST_STORE_POLY;
                        end
                    end else if (cand0_valid || cand1_valid) begin
                        if (coeff_count <= 9'd254) begin
                            a_poly[coeff_count[7:0]] <= cand0_valid ? cand0 : cand1;
                            coeff_count <= coeff_count + 9'd1;
                        end else begin
                            a_poly[8'd255] <= cand0_valid ? cand0 : cand1;
                            coeff_count <= 9'd256;
                            store_coeff_idx <= 8'd0;
                            ready_seen <= 1'b0;
                            state <= ST_STORE_POLY; 
                        end
                    end
                end
            end

            ST_STORE_POLY: begin
                busy <= 1'b1;
                extend <= 1'b0;
                ofifo_ena <= 1'b0;

                // Store one coefficient per cycle into flattened A[cell][coeff].
                A_mem[A_store_addr] <= a_poly[store_coeff_idx];

                if (store_coeff_idx == 8'd255) begin
                    store_coeff_idx <= 8'd0;
                    if (cell_ctr == MATRIX_CELLS - 1) begin
                        state <= ST_DONE;
                    end else begin
                        cell_ctr <= cell_ctr + 4'd1;
                        if(col_ctr == KYBER_K - 1) begin
                            row_ctr <= row_ctr + 8'd1;
                            col_ctr <= 8'd0;
                        end else begin
                            col_ctr <= col_ctr + 8'd1;
                        end
                        state <= ST_NEXT_CELL;
                    end
                end else begin
                    store_coeff_idx <= store_coeff_idx + 8'd1;
                end
            end

            ST_NEXT_CELL: begin
                busy <= 1'b1;
                extend <= 1'b0;
                ofifo_ena <= 1'b1;
                coeff_count <= 9'd0;
                sample_squeeze_ctr <= 6'd0;
                absorb_word_ctr <= 4'd0;
                ready_seen <= 1'b0;
                init_wait_ctr <= 2'd0;

                keccak_init <= 1'b1;
                state <= ST_INIT_WAIT;
            end

            ST_DONE: begin
                busy <= 1'b0;
                extend <= 1'b0;
                ofifo_ena <= 1'b0;
                keygen_done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule

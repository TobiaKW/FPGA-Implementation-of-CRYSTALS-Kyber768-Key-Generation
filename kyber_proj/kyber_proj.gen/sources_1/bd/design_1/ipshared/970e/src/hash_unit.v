`timescale 1ns / 1ps

// Small command wrapper around hash_core_Server.
//
// Intended use:
// - a_gen asks for MODE_A_UNIFORM: absorb rho || j || i, then stream SHAKE words.
// - s_gen/e_gen ask for MODE_NOISE: absorb sigma || nonce, then stream PRF bytes.
//
// This is a skeleton: the public interface and state shape are defined first,
// then each mode's exact absorb/squeeze schedule can be filled in safely.
module hash_unit(
    input             clk,
    input             rst,

    input             start,
    input      [1:0]  mode,
    input      [255:0] seed,
    input      [7:0]  row_idx,   // used by MODE_A_UNIFORM as i
    input      [7:0]  col_idx,   // used by MODE_A_UNIFORM as j
    input      [7:0]  nonce,     // used by MODE_NOISE
    input      [31:0] absorb_word_i,  // streaming absorb word for MODE_SHA3_256
    input             absorb_valid_i, // valid for absorb_word_i
    input             absorb_last_i,  // marks final absorb word
    output            absorb_ready_o, // high when hash_unit accepts absorb words
    input             stop_stream, // stop the stream

    output reg        busy,
    output reg        done,

    output reg [31:0] stream_word,
    output reg        stream_valid,
    input             stream_ready
);

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------
localparam MODE_A_UNIFORM = 2'd0; // SHAKE128(rho || j || i), uniform A coeffs
localparam MODE_NOISE     = 2'd1; // PRF/CBD seed || nonce for s/e
localparam MODE_SHA3_256   = 2'd2;
localparam MODE_SHA3_512  = 2'd3;

// ---------------------------------------------------------------------------
// FSM
// ---------------------------------------------------------------------------
localparam ST_IDLE       = 3'd0;
localparam ST_INIT_WAIT  = 3'd1;
localparam ST_ABSORB     = 3'd2;
localparam ST_WAIT_READY = 3'd3;
localparam ST_STREAM     = 3'd4;
localparam ST_DONE       = 3'd5;

reg [2:0] state;
reg [1:0] mode_r;
reg [3:0] absorb_word_ctr;
reg [5:0] sample_squeeze_ctr;
reg       ready_seen;
reg [1:0] init_wait_ctr;

// ---------------------------------------------------------------------------
// hash_core_Server controls
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// hash_core_Server outputs
// ---------------------------------------------------------------------------
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
assign absorb_ready_o = (state == ST_ABSORB) && (mode_r == MODE_SHA3_256);

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
        mode_r <= MODE_A_UNIFORM; // default latched mode after reset
        absorb_word_ctr <= 4'd0;
        sample_squeeze_ctr <= 6'd0;
        ready_seen <= 1'b0;
        init_wait_ctr <= 2'd0;

        busy <= 1'b0;
        done <= 1'b0;
        stream_word <= 32'd0;
        stream_valid <= 1'b0;

        keccak_init <= 1'b0;
        extend <= 1'b0;
        patt_bit <= 1'b0;
        eta3_bit <= 1'b0;
        absorb_ctr_r1 <= 2'd0;
        keccak_ctr <= 3'h1;
        ififo_wen <= 1'b0;
        ififo_din <= 32'd0;
        ififo_absorb <= 1'b0;
        ififo_mode <= 2'b01;
        ififo_last <= 1'b0;
        ofifo_ena <= 1'b0;
        ofifo0_req <= 1'b0;
        ofifo1_req <= 1'b0;
    end else begin
        // Default one-cycle controls.
        done <= 1'b0;
        stream_valid <= 1'b0;
        keccak_init <= 1'b0;
        ififo_wen <= 1'b0;
        ififo_last <= 1'b0;
        ififo_absorb <= 1'b0;
        ofifo0_req <= 1'b0;
        ofifo1_req <= 1'b0;

        if (keccak_ready) begin
            ready_seen <= 1'b1;
        end

        

        case (state)
            ST_IDLE: begin
                busy <= 1'b0;
                extend <= 1'b0;
                ofifo_ena <= 1'b0;
                absorb_word_ctr <= 4'd0;
                sample_squeeze_ctr <= 6'd0;
                ready_seen <= 1'b0;

                if (start) begin
                    busy <= 1'b1;
                    mode_r <= mode;
                    keccak_ctr <= 3'h1;
                    ofifo_ena <= 1'b1;
                    keccak_init <= 1'b1;
                    init_wait_ctr <= 2'd0;

                    // TODO: mode-specific setup.
                    // A uniform currently uses 9 words: seed[255:0] + {0,j,i}.
                    // Noise mode likely uses seed[255:0] + nonce framing.
                    case (mode)
                        MODE_A_UNIFORM: ififo_mode <= 2'b01; // 9-word absorb: seed + {0,j,i}
                        MODE_NOISE:     ififo_mode <= 2'b01; // 9-word absorb: seed + {0,0,0,nonce}
                        MODE_SHA3_256:  ififo_mode <= 2'b00; // 8-word absorb
                        MODE_SHA3_512:  ififo_mode <= 2'b00; // 8-word absorb
                        default:        ififo_mode <= 2'b00;    
                    endcase

                    patt_bit <= 1'b0;
                    eta3_bit <= 1'b0;

                    state <= ST_INIT_WAIT;
                end
            end

            ST_INIT_WAIT: begin
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
                ififo_absorb <= 1'b0;

                // MODE_A_UNIFORM and MODE_NOISE use 9-word absorb:
                //   - A:     seed[0..7] + {0,j,i}
                //   - noise: seed[0..7] + {0,0,0,nonce}
                // SHA3 fixed modes use 8-word absorb: seed[0..7] only.
                if (mode_r == MODE_A_UNIFORM || mode_r == MODE_NOISE) begin
                    ififo_wen <= 1'b1;
                    if (absorb_word_ctr < 4'd8) begin
                        ififo_din <= seed[absorb_word_ctr*32 +: 32];
                    end else begin
                        if (mode_r == MODE_A_UNIFORM) begin
                            ififo_din <= {16'h0000, col_idx, row_idx};
                        end else begin
                            ififo_din <= {24'h000000, nonce};
                        end
                    end

                    if (absorb_word_ctr == 4'd8) begin
                        ififo_last <= 1'b1;
                        absorb_word_ctr <= 4'd0;
                        state <= ST_WAIT_READY;
                    end else begin
                        absorb_word_ctr <= absorb_word_ctr + 4'd1;
                    end
                end else if (mode_r == MODE_SHA3_256) begin
                    if (absorb_valid_i) begin
                        ififo_wen <= 1'b1;
                        ififo_din <= absorb_word_i;
                        ififo_last <= absorb_last_i;
                        if (absorb_last_i) begin
                            absorb_word_ctr <= 4'd0;
                            ready_seen <= 1'b0;
                            state <= ST_WAIT_READY;
                        end
                    end
                end else begin // MODE_SHA3_512 fallback uses 8-word fixed absorb: seed[0..7].
                    ififo_wen <= 1'b1;
                    ififo_din <= seed[absorb_word_ctr*32 +: 32];
                    if (absorb_word_ctr == 4'd7) begin
                        ififo_last <= 1'b1;
                        absorb_word_ctr <= 4'd0;
                        state <= ST_WAIT_READY;
                    end else begin
                        absorb_word_ctr <= absorb_word_ctr + 4'd1;
                    end
                end
            end

            ST_WAIT_READY: begin
                busy <= 1'b1;
                ofifo_ena <= 1'b1;
                if (ready_seen) begin
                    if (mode_r == MODE_A_UNIFORM || mode_r == MODE_NOISE) begin
                        extend <= 1'b1;
                    end else begin
                        extend <= 1'b0;
                    end
                    sample_squeeze_ctr <= (mode_r == MODE_SHA3_256) ? 6'd0 : squeeze_ctr;
                    state <= ST_STREAM;
                end
            end

            ST_STREAM: begin
                busy <= 1'b1;
                ofifo_ena <= 1'b1;
                if (mode_r == MODE_SHA3_256) begin
                    if (stream_ready) begin
                        stream_word <= keccak_dout;
                        stream_valid <= 1'b1;
                        if (sample_squeeze_ctr < 6'd7) begin
                            extend <= 1'b1; // shift next digest word
                            sample_squeeze_ctr <= sample_squeeze_ctr + 6'd1;
                        end else begin
                            extend <= 1'b0;
                        end
                    end
                end else begin
                    if (mode_r == MODE_A_UNIFORM || mode_r == MODE_NOISE) begin
                        extend <= 1'b1;
                    end else begin
                        extend <= 1'b0;
                    end

                    // Raw SHAKE stream output. Caller decides how many words to consume.
                    if ((squeeze_ctr != sample_squeeze_ctr) && stream_ready) begin
                        sample_squeeze_ctr <= squeeze_ctr;
                        stream_word <= keccak_dout;
                        stream_valid <= 1'b1;
                    end
                end

                // TODO: add a requested word count, or an explicit stop input.
                if (stop_stream) begin
                    extend <= 1'b0;
                    ofifo_ena <= 1'b0;
                    state <= ST_DONE;
                end
            end

            ST_DONE: begin
                busy <= 1'b0;
                extend <= 1'b0;
                ofifo_ena <= 1'b0;
                done <= 1'b1;
                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule

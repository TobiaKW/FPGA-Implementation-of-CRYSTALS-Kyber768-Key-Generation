`timescale 1ns / 1ps

// Generic 3x3 matrix times 3x1 vector (polynomial domain — full NTT path TBD).
// Computes: y = M * v (mod q), without +e.
//
// Flattened addressing:
// - M[i][j][n] -> ((i*3 + j) << 8) + n
// - v[j][n]    -> (j << 8) + n
// - y[i][n]    -> (i << 8) + n
//
// PE1 pipeline: LOAD_A/B (256 cycles each) -> FNTT_A -> FNTT_B -> PWM2 -> INTT
// -> READ_A pulse + ST_READ_STREAM (256 samples, PE1 bank interleave) -> ACC_ROW -> WRITE.
module mat_vec_mul(
    input             clk,
    input             rst,
    input             start,

    output reg [11:0] mat_rd_addr,
    input      [11:0] mat_rd_data,
    output reg [11:0] vec_rd_addr,
    input      [11:0] vec_rd_data,

    output reg        out_wr_en,
    output reg [9:0]  out_wr_addr,
    output reg [11:0] out_wr_data,

    output reg        done,
    output reg        busy
);

    localparam K         = 3;
    localparam N         = 256;
    localparam Q         = 3329;
    localparam PE_NUMBER = 1;

    // Outer loop: one coeff index at a time (placeholder until full per-column poly mult).
    localparam ST_IDLE           = 6'd0;
    localparam ST_SETADDR        = 6'd1;
    // PE1 sequence (mirror KyberHPM1PE_test_ALL_FULL read order)
    localparam ST_LOAD_A_PULSE   = 6'd2;
    localparam ST_LOAD_A_STREAM  = 6'd3;
    localparam ST_LOAD_B_PULSE   = 6'd4;
    localparam ST_LOAD_B_STREAM  = 6'd5;
    localparam ST_FNTT_A_PULSE   = 6'd6;
    localparam ST_FNTT_A_WAIT    = 6'd7;
    localparam ST_FNTT_B_PULSE   = 6'd8;
    localparam ST_FNTT_B_WAIT    = 6'd9;
    localparam ST_PWM2_PULSE     = 6'd10;
    localparam ST_PWM2_WAIT      = 6'd11;
    localparam ST_INTT_PULSE     = 6'd12;
    localparam ST_INTT_WAIT      = 6'd13;
    // Idle after INTT (vendor TB uses gap before read_a; PE must be in OP_IDLE)
    localparam ST_READ_PRE       = 6'd14;
    // read_a: registered inside KyberHPM1PE_top — separate HOLD so pulse is not swallowed
    localparam ST_READ_A_PULSE   = 6'd15;
    localparam ST_READ_A_HOLD    = 6'd16;
    localparam ST_READ_STREAM    = 6'd17;
    localparam ST_ACC_ROW        = 6'd18;
    localparam ST_WRITE          = 6'd19;
    localparam ST_NEXT           = 6'd20;
    localparam ST_DONE           = 6'd21;

    reg [5:0] state;
    reg [1:0] row_idx;
    reg [1:0] col_idx;

    // PE1 datapath (KyberHPM1PE_top)
    reg        pe_reset;
    reg        load_a_f, load_a_i;
    reg        load_b_f, load_b_i;
    reg        read_a, read_b;
    reg        start_ab;
    reg        start_fntt, start_pwm2, start_intt;
    reg [12*PE_NUMBER-1:0] din;
    wire [12*PE_NUMBER-1:0] dout;
    wire [11:0] dout_coeff;
    wire pe_done;

    // Load streaming: 256 coeffs, one per cycle (PE1)
    reg [8:0] load_beat;

    reg [11:0] wait_ctr;
    // Align first valid dout after read_a (PE1 testbench uses ~2 idle cycles).
    localparam READ_DOUT_ALIGN = 3'd6;
    reg [8:0] read_stream_ctr;
    reg [1:0] read_pre_ctr;
    reg [2:0] read_align_ctr;
    reg [7:0] write_idx;
    reg [7:0] acc_idx;
    (* ram_style = "block" *)
    reg [11:0] poly_buf [0:N-1];
    (* ram_style = "block" *)
    reg [11:0] row_acc_buf [0:N-1];

    KyberHPM1PE_top #(.PE_NUMBER(PE_NUMBER)) u_pe (
        .clk        (clk),
        .reset      (pe_reset),
        .load_a_f   (load_a_f),
        .load_a_i   (load_a_i),
        .load_b_f   (load_b_f),
        .load_b_i   (load_b_i),
        .read_a     (read_a),
        .read_b     (read_b),
        .start_ab   (start_ab),
        .start_fntt (start_fntt),
        .start_pwm2 (start_pwm2),
        .start_intt (start_intt),
        .din        (din),
        .dout       (dout),
        .done       (pe_done)
    );

    assign dout_coeff = dout[11:0];

    function [11:0] add_mod_q12;
        input [11:0] a;
        input [11:0] b;
        reg [12:0] s;
    begin
        s = a + b;
        if (s >= Q)
            add_mod_q12 = s - Q;
        else
            add_mod_q12 = s[11:0];
    end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            row_idx <= 2'd0;
            col_idx <= 2'd0;
            load_beat <= 9'd0;
            wait_ctr <= 12'd0;
            read_stream_ctr <= 9'd0;
            read_pre_ctr <= 2'd0;
            read_align_ctr <= 3'd0;
            write_idx <= 8'd0;
            acc_idx <= 8'd0;

            mat_rd_addr <= 12'd0;
            vec_rd_addr <= 12'd0;
            out_wr_en <= 1'b0;
            out_wr_addr <= 10'd0;
            out_wr_data <= 12'd0;
            done <= 1'b0;
            busy <= 1'b0;

            pe_reset <= 1'b1;
            load_a_f <= 1'b0;
            load_a_i <= 1'b0;
            load_b_f <= 1'b0;
            load_b_i <= 1'b0;
            read_a <= 1'b0;
            read_b <= 1'b0;
            start_ab <= 1'b0;
            start_fntt <= 1'b0;
            start_pwm2 <= 1'b0;
            start_intt <= 1'b0;
            din <= 12'd0;
        end else begin
            out_wr_en <= 1'b0;
            done <= 1'b0;
            pe_reset <= 1'b0;

            // default: deassert strobes
            load_a_f <= 1'b0;
            load_b_f <= 1'b0;
            start_ab <= 1'b0;
            start_fntt <= 1'b0;
            start_pwm2 <= 1'b0;
            start_intt <= 1'b0;
            read_a <= 1'b0;
            read_b <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    wait_ctr <= 12'd0;
                    load_beat <= 9'd0;
                    row_idx <= 2'd0;
                    col_idx <= 2'd0;
                    if (start) begin
                        busy <= 1'b1;
                        state <= ST_SETADDR;
                    end
                end

                ST_SETADDR: begin
                    // Full-polynomial PE flow starts at coefficient 0 each column.
                    mat_rd_addr <= (((row_idx * K) + col_idx) << 8);
                    vec_rd_addr <= (col_idx << 8);
                    state <= ST_LOAD_A_PULSE;
                end

                ST_LOAD_A_PULSE: begin
                    load_a_f <= 1'b1;
                    load_beat <= 9'd0;
                    state <= ST_LOAD_A_STREAM;
                end

                ST_LOAD_A_STREAM: begin
                    load_a_f <= 1'b0;
                    mat_rd_addr <= (((row_idx * K) + col_idx) << 8) + load_beat;
                    din <= mat_rd_data;
                    if (load_beat == 9'd255) begin
                        load_beat <= 9'd0;
                        state <= ST_LOAD_B_PULSE;
                    end else begin
                        load_beat <= load_beat + 9'd1;
                    end
                end

                ST_LOAD_B_PULSE: begin
                    load_b_f <= 1'b1;
                    load_beat <= 9'd0;
                    // s_mem is registered read: prime address one cycle before first din sample.
                    vec_rd_addr <= (col_idx << 8);
                    state <= ST_LOAD_B_STREAM;
                end

                ST_LOAD_B_STREAM: begin
                    load_b_f <= 1'b0;
                    din <= vec_rd_data;
                    if (load_beat == 9'd255) begin
                        state <= ST_FNTT_A_PULSE;
                        wait_ctr <= 12'd0;
                    end else begin
                        load_beat <= load_beat + 9'd1;
                        vec_rd_addr <= (col_idx << 8) + (load_beat + 9'd1);
                    end
                end

                ST_FNTT_A_PULSE: begin
                    start_fntt <= 1'b1;
                    start_ab   <= 1'b1;
                    state <= ST_FNTT_A_WAIT;
                    wait_ctr <= 12'd0;
                end

                ST_FNTT_A_WAIT: begin
                    start_fntt <= 1'b0;
                    start_ab   <= 1'b0;
                    if (pe_done)
                        state <= ST_FNTT_B_PULSE;
                    else
                        wait_ctr <= wait_ctr + 12'd1;
                end

                ST_FNTT_B_PULSE: begin
                    start_fntt <= 1'b1;
                    start_ab   <= 1'b0;
                    state <= ST_FNTT_B_WAIT;
                    wait_ctr <= 12'd0;
                end

                ST_FNTT_B_WAIT: begin
                    start_fntt <= 1'b0;
                    if (pe_done)
                        state <= ST_PWM2_PULSE;
                    else
                        wait_ctr <= wait_ctr + 12'd1;
                end

                ST_PWM2_PULSE: begin
                    start_pwm2 <= 1'b1;
                    state <= ST_PWM2_WAIT;
                    wait_ctr <= 12'd0;
                end

                ST_PWM2_WAIT: begin
                    start_pwm2 <= 1'b0;
                    if (pe_done)
                        state <= ST_INTT_PULSE;
                    else
                        wait_ctr <= wait_ctr + 12'd1;
                end

                ST_INTT_PULSE: begin
                    start_intt <= 1'b1;
                    state <= ST_INTT_WAIT;
                    wait_ctr <= 12'd0;
                end

                ST_INTT_WAIT: begin
                    start_intt <= 1'b0;
                    if (pe_done) begin
                        read_pre_ctr <= 2'd0;
                        state <= ST_READ_PRE;
                    end else
                        wait_ctr <= wait_ctr + 12'd1;
                end

                // Match KyberHPM1PE_test_ALL_FULL: brief idle in OP_IDLE before read_a
                ST_READ_PRE: begin
                    if (read_pre_ctr == 2'd1)
                        state <= ST_READ_A_PULSE;
                    else
                        read_pre_ctr <= read_pre_ctr + 2'd1;
                end

                ST_READ_A_PULSE: begin
                    read_a <= 1'b1;
                    state <= ST_READ_A_HOLD;
                end

                ST_READ_A_HOLD: begin
                    read_a <= 1'b0;
                    read_stream_ctr <= 9'd0;
                    read_align_ctr <= 3'd0;
                    state <= ST_READ_STREAM;
                end

                // 256 cycles: dout order matches KyberHPM1PE_test_ALL_FULL (m then m+128 pairs).
                ST_READ_STREAM: begin
                    if (read_align_ctr < READ_DOUT_ALIGN) begin
                        read_align_ctr <= read_align_ctr + 3'd1;
                        read_stream_ctr <= 9'd0;
                    end else if (read_stream_ctr < 9'd256) begin
                        poly_buf[(read_stream_ctr[0]) ? (8'd128 + read_stream_ctr[8:1])
                                                       : {1'b0, read_stream_ctr[8:1]}]
                            <= dout_coeff;
                        if (read_stream_ctr == 9'd255) begin
                            acc_idx <= 8'd0;
                            state <= ST_ACC_ROW;
                        end else
                            read_stream_ctr <= read_stream_ctr + 9'd1;
                    end
                end

                ST_ACC_ROW: begin
                    if (col_idx == 2'd0)
                        row_acc_buf[acc_idx] <= poly_buf[acc_idx];
                    else
                        row_acc_buf[acc_idx] <= add_mod_q12(row_acc_buf[acc_idx], poly_buf[acc_idx]);

                    if (acc_idx == 8'd255) begin
                        if (col_idx == K - 1) begin
                            write_idx <= 8'd0;
                            state <= ST_WRITE;
                        end else begin
                            col_idx <= col_idx + 2'd1;
                            state <= ST_SETADDR;
                        end
                    end else begin
                        acc_idx <= acc_idx + 8'd1;
                    end
                end

                ST_WRITE: begin
                    out_wr_en <= 1'b1;
                    out_wr_addr <= (row_idx << 8) + write_idx;
                    out_wr_data <= row_acc_buf[write_idx];
                    if (write_idx == 8'd255)
                        state <= ST_NEXT;
                    else
                        write_idx <= write_idx + 8'd1;
                end

                ST_NEXT: begin
                    // ST_WRITE is reached only after finishing all columns for this row.
                    col_idx <= 2'd0;
                    if (row_idx == K - 1)
                        state <= ST_DONE;
                    else begin
                        row_idx <= row_idx + 2'd1;
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

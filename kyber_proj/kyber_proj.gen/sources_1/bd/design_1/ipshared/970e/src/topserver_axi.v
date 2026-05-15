`timescale 1ns / 1ps

// AXI4-Lite wrapper for topserver, intended for PYNQ PS control.
// Register map (byte offsets):
// 0x00 CONTROL  [0]=start_pulse(W1P), [1]=clear_done(W1C)
// 0x04 STATUS   [0]=done_sticky, [1]=rd_valid
// 0x08 READ_CFG [0]=rd_en, [1]=rd_sk
// 0x0C READ_ADDR[11:0]=byte address
// 0x10 READ_DATA[11:0]=read data
module topserver_axi #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aclk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 50000000" *)
    input  wire                               s_axi_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axi_aresetn, POLARITY ACTIVE_LOW" *)
    input  wire                               s_axi_aresetn,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  wire                               s_axi_awvalid,
    output reg                                s_axi_awready,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]      s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]  s_axi_wstrb,
    input  wire                               s_axi_wvalid,
    output reg                                s_axi_wready,
    output reg  [1:0]                         s_axi_bresp,
    output reg                                s_axi_bvalid,
    input  wire                               s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]      s_axi_araddr,
    input  wire                               s_axi_arvalid,
    output reg                                s_axi_arready,
    output reg [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output reg [1:0]                          s_axi_rresp,
    output reg                                s_axi_rvalid,
    input  wire                               s_axi_rready
);

localparam [5:0] ADDR_CONTROL  = 6'h00;
localparam [5:0] ADDR_STATUS   = 6'h04;
localparam [5:0] ADDR_READ_CFG = 6'h08;
localparam [5:0] ADDR_READ_ADDR= 6'h0C;
localparam [5:0] ADDR_READ_DATA= 6'h10;

reg        reg_rd_en;
reg        reg_rd_sk;
reg [11:0] reg_rd_addr;
reg        start_pulse;
reg        done_sticky;

wire       core_top_done;
wire       core_rd_valid;
wire [11:0] core_rd_data;

wire write_fire = s_axi_awvalid && s_axi_wvalid && (!s_axi_bvalid);
wire read_fire  = s_axi_arvalid && (!s_axi_rvalid);

integer byte_idx;
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        s_axi_bresp   <= 2'b00;
        s_axi_bvalid  <= 1'b0;
        s_axi_arready <= 1'b0;
        s_axi_rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};
        s_axi_rresp   <= 2'b00;
        s_axi_rvalid  <= 1'b0;

        reg_rd_en   <= 1'b0;
        reg_rd_sk   <= 1'b1;
        reg_rd_addr <= 12'd0;
        start_pulse <= 1'b0;
        done_sticky <= 1'b0;
    end else begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        s_axi_arready <= 1'b0;
        start_pulse   <= 1'b0;

        if (core_top_done) begin
            done_sticky <= 1'b1;
        end

        if (write_fire) begin
            s_axi_awready <= 1'b1;
            s_axi_wready  <= 1'b1;
            s_axi_bvalid  <= 1'b1;
            s_axi_bresp   <= 2'b00;
            case (s_axi_awaddr[5:0])
                ADDR_CONTROL: begin
                    if (s_axi_wstrb[0]) begin
                        if (s_axi_wdata[0]) start_pulse <= 1'b1;
                        if (s_axi_wdata[1]) done_sticky <= 1'b0;
                    end
                end
                ADDR_READ_CFG: begin
                    if (s_axi_wstrb[0]) begin
                        reg_rd_en <= s_axi_wdata[0];
                        reg_rd_sk <= s_axi_wdata[1];
                    end
                end
                ADDR_READ_ADDR: begin
                    for (byte_idx = 0; byte_idx < (C_S_AXI_DATA_WIDTH/8); byte_idx = byte_idx + 1) begin
                        if (s_axi_wstrb[byte_idx]) begin
                            if (byte_idx == 0) reg_rd_addr[7:0]  <= s_axi_wdata[7:0];
                            if (byte_idx == 1) reg_rd_addr[11:8] <= s_axi_wdata[11:8];
                        end
                    end
                end
                default: begin
                end
            endcase
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end

        if (read_fire) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b1;
            s_axi_rresp   <= 2'b00;
            case (s_axi_araddr[5:0])
                ADDR_CONTROL: begin
                    s_axi_rdata <= 32'd0;
                end
                ADDR_STATUS: begin
                    s_axi_rdata <= {30'd0, core_rd_valid, done_sticky};
                end
                ADDR_READ_CFG: begin
                    s_axi_rdata <= {30'd0, reg_rd_sk, reg_rd_en};
                end
                ADDR_READ_ADDR: begin
                    s_axi_rdata <= {20'd0, reg_rd_addr};
                end
                ADDR_READ_DATA: begin
                    s_axi_rdata <= {20'd0, core_rd_data};
                end
                default: begin
                    s_axi_rdata <= 32'd0;
                end
            endcase
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end

topserver u_topserver (
    .clk(s_axi_aclk),
    .rst(~s_axi_aresetn),
    .top_start(start_pulse),
    .out_rd_en(reg_rd_en),
    .out_rd_sk(reg_rd_sk),
    .out_rd_addr(reg_rd_addr),
    .top_done(core_top_done),
    .rd_valid(core_rd_valid),
    .rd_addr(),
    .rd_data(core_rd_data)
);

endmodule

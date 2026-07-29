`timescale 1ns/1ps
// 1-lane CSI-2 RX link: custom RX PHY → Digilent CSI-2 RX → AXI4-Stream Video.
//
// Simplest configuration: 1 data lane, no AXI-Lite (vEnable always 1).
// The custom PHY's PPI goes straight to the CSI-2 RX; aClkEnable/aD0Enable
// (video_aclk domain) cross to refclk_i via a 2-FF synchronizer.

module csi2_rx_link1 #(
    parameter int  SERIAL_CLK_PER    = 8,
    parameter string TARGET_DT       = "RAW10",
    parameter int  C_M_AXIS_TDATA_W  = 40
) (
    // System
    input  logic               refclk_i,
    input  logic               arstn,

    // D-PHY pads (clock + 1 data)
    input  logic               clk_lp_p_i, clk_lp_n_i,
    input  logic               clk_hs_p_i, clk_hs_n_i,
    input  logic               dat_lp_p_i, dat_lp_n_i,
    input  logic               dat_hs_p_i, dat_hs_n_i,

    // Video clock / reset
    input  logic               video_aclk,
    input  logic               video_aresetn,

    // AXI4-Stream video output
    output logic [C_M_AXIS_TDATA_W-1:0] m_axis_tdata,
    output logic                        m_axis_tvalid,
    input  logic                        m_axis_tready,
    output logic                        m_axis_tlast,
    output logic [0:0]                  m_axis_tuser
);

    // PPI interfaces
    rx_clk_ppi_if    clk_ppi();
    rx_data_ppi_if   data_ppi();

    // D-PHY pad wiring
    rx_clk_d_phy_if  clk_dphy();
    rx_data_d_phy_if dat_dphy();

    assign clk_dphy.clk_LP_Dp_i = clk_lp_p_i;
    assign clk_dphy.clk_LP_Dn_i = clk_lp_n_i;
    assign clk_dphy.clk_HS_Dp_i = clk_hs_p_i;
    assign clk_dphy.clk_HS_Dn_i = clk_hs_n_i;

    assign dat_dphy.data_LP_Dp_i = dat_lp_p_i;
    assign dat_dphy.data_LP_Dn_i = dat_lp_n_i;
    assign dat_dphy.data_HS_Dp_i = dat_hs_p_i;
    assign dat_dphy.data_HS_Dn_i = dat_hs_n_i;

    // Custom RX PHY (digital + behavioral analog)
    rx_phy_top #(.SERIAL_CLK_PER(SERIAL_CLK_PER)) u_phy (
        .arstn      (arstn),
        .refclk_i   (refclk_i),
        .clk_ppi    (clk_ppi),
        .data_ppi   (data_ppi),
        .clk_d_phy  (clk_dphy),
        .data_d_phy (dat_dphy)
    );

    // PHY enables: always active
    assign clk_ppi.Shutdownz_i  = 1'b1;
    assign data_ppi.Shutdownz_i = 1'b1;

    // CSI-2 enable outputs (video_aclk domain) → CDC → PHY enables
    wire aClkEnable, aD0Enable;

    logic cdc_s0, cdc_s1;  // aClkEnable 2-FF
    logic cdc_d0, cdc_d1;  // aD0Enable 2-FF

    always_ff @(posedge refclk_i or negedge arstn) begin
        if (!arstn) begin
            cdc_s0 <= 1'b0; cdc_s1 <= 1'b0;
            cdc_d0 <= 1'b0; cdc_d1 <= 1'b0;
        end else begin
            cdc_s0 <= aClkEnable; cdc_s1 <= cdc_s0;
            cdc_d0 <= aD0Enable;  cdc_d1 <= cdc_d0;
        end
    end

    assign clk_ppi.Enable_i  = cdc_s1;
    assign data_ppi.Enable_i = cdc_d1;

    // PPI mapping to CSI-2 RX
    wire [7:0] d_hs   = data_ppi.RxDataHS_o;
    wire       d_valid = data_ppi.RxValidHS_o;
    wire       d_active= data_ppi.RxActiveHS_o;
    wire       d_sync  = data_ppi.RxSyncHS_o;

    // Digilent CSI-2 RX (VHDL entity)
    mipi_csi2_rx_top #(
        .kVersionMajor           (0),
        .kVersionMinor           (0),
        .kTargetDT               (TARGET_DT),
        .kGenerateAXIL           (0),
        .kDebug                  (0),
        .kLaneCount              (1),
        .C_M_AXIS_COMPONENT_WIDTH(10),
        .C_M_AXIS_TDATA_WIDTH    (C_M_AXIS_TDATA_W),
        .C_M_MAX_SAMPLES_PER_CLOCK(4)
    ) u_csi2 (
        .RxByteClkHS         (clk_ppi.RxByteClkHS_o),
        .aClkStopstate       (clk_ppi.StopState_o),
        .aRxClkActiveHS      (clk_ppi.RxClkActiveHS_o),
        .RxDataHSD0          (d_hs),
        .RxSyncHSD0          (d_sync),
        .RxValidHSD0         (d_valid),
        .RxActiveHSD0        (d_active),
        .aD0Enable           (aD0Enable),
        .RxDataHSD1          (8'd0),
        .RxSyncHSD1          (1'b0),
        .RxValidHSD1         (1'b0),
        .RxActiveHSD1        (1'b0),
        .aD1Enable           (),
        .RxDataHSD2          (8'd0),
        .RxSyncHSD2          (1'b0),
        .RxValidHSD2         (1'b0),
        .RxActiveHSD2        (1'b0),
        .aD2Enable           (),
        .RxDataHSD3          (8'd0),
        .RxSyncHSD3          (1'b0),
        .RxValidHSD3         (1'b0),
        .RxActiveHSD3        (1'b0),
        .aD3Enable           (),
        .aClkEnable          (aClkEnable),
        .m_axis_video_tdata  (m_axis_tdata),
        .m_axis_video_tvalid (m_axis_tvalid),
        .m_axis_video_tready (m_axis_tready),
        .m_axis_video_tlast  (m_axis_tlast),
        .m_axis_video_tuser  (m_axis_tuser),
        .video_aresetn       (video_aresetn),
        .video_aclk          (video_aclk),
        .s_axi_lite_aclk     (1'b0),
        .s_axi_lite_aresetn  (1'b0),
        .s_axi_lite_awaddr   ('0),
        .s_axi_lite_awprot   ('0),
        .s_axi_lite_awvalid  (1'b0),
        .s_axi_lite_awready  (),
        .s_axi_lite_wdata    ('0),
        .s_axi_lite_wstrb    ('0),
        .s_axi_lite_wvalid   (1'b0),
        .s_axi_lite_wready   (),
        .s_axi_lite_bresp    (),
        .s_axi_lite_bvalid   (),
        .s_axi_lite_bready   (1'b0),
        .s_axi_lite_araddr   ('0),
        .s_axi_lite_arprot   ('0),
        .s_axi_lite_arvalid  (1'b0),
        .s_axi_lite_arready  (),
        .s_axi_lite_rdata    (),
        .s_axi_lite_rresp    (),
        .s_axi_lite_rvalid   (),
        .s_axi_lite_rready   (1'b0)
    );

endmodule

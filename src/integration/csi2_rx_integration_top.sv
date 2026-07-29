`timescale 1ns/1ps
// CSI-2 RX Integration Top
//
// Connects the custom RX PHY (MIPI-D-PHY-TX-RX/src/rx/) to the Digilent MIPI CSI-2
// RX protocol layer (digilent_csi2_rx/ip/MIPI_CSI_2_RX/).
//
// Architecture:
//   Custom RX PHY (rx_phy_top)  ---PPI--->  Digilent CSI-2 RX (mipi_csi2_rx_top)
//       |                                       |
//   D-PHY pads                              AXI4-Stream Video
//
// The custom RX PHY replaces the Digilent D-PHY RX (MIPI_D_PHY_RX) while the
// CSI-2 protocol layer is reused as-is.  CDC synchronisers are inserted for
// the aClkEnable / aDxEnable control paths (video_aclk -> refclk_i).

module csi2_rx_integration_top #(
    // PHY configuration
    parameter int unsigned LANE_COUNT       = 1,
    parameter int unsigned SERIAL_CLK_PER   = 8,

    // CSI-2 protocol configuration
    parameter string  TARGET_DT             = "RAW10",
    parameter bit     GEN_AXIL              = 0,
    parameter bit     DEBUG                 = 0,

    // Video format
    parameter int unsigned C_M_AXIS_COMPONENT_WIDTH    = 10,
    parameter int unsigned C_M_AXIS_TDATA_WIDTH        = 40,
    parameter int unsigned C_M_MAX_SAMPLES_PER_CLOCK   = 4,

    // AXI-Lite bus parameters
    parameter int unsigned C_S_AXI_LITE_DATA_WIDTH     = 32,
    parameter int unsigned C_S_AXI_LITE_ADDR_WIDTH     = 4
) (
    //=== System ============================================================
    input  logic                     refclk_i,       // LP-sample / IDELAY refclk
    input  logic                     arstn,           // async reset, active-low

    //=== D-PHY Pad Interface ===============================================
    // Clock lane (differential LP + HS)
    input  logic                     clk_lp_p_i,
    input  logic                     clk_lp_n_i,
    input  logic                     clk_hs_p_i,
    input  logic                     clk_hs_n_i,
    // Data lanes
    input  logic [LANE_COUNT-1:0]    data_lp_p_i,
    input  logic [LANE_COUNT-1:0]    data_lp_n_i,
    input  logic [LANE_COUNT-1:0]    data_hs_p_i,
    input  logic [LANE_COUNT-1:0]    data_hs_n_i,

    //=== Video Output Clock Domain =========================================
    input  logic                     video_aclk,
    input  logic                     video_aresetn,

    // AXI4-Stream Video (video_aclk domain)
    output logic [C_M_AXIS_TDATA_WIDTH-1:0] m_axis_video_tdata,
    output logic                             m_axis_video_tvalid,
    input  logic                             m_axis_video_tready,
    output logic                             m_axis_video_tlast,
    output logic [0:0]                       m_axis_video_tuser,

    //=== Optional AXI-Lite (only when GEN_AXIL == 1) ======================
    input  logic                             s_axi_lite_aclk,
    input  logic                             s_axi_lite_aresetn,
    input  logic [C_S_AXI_LITE_ADDR_WIDTH-1:0] s_axi_lite_awaddr,
    input  logic [2:0]                       s_axi_lite_awprot,
    input  logic                             s_axi_lite_awvalid,
    output logic                             s_axi_lite_awready,
    input  logic [C_S_AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_wdata,
    input  logic [(C_S_AXI_LITE_DATA_WIDTH/8)-1:0] s_axi_lite_wstrb,
    input  logic                             s_axi_lite_wvalid,
    output logic                             s_axi_lite_wready,
    output logic [1:0]                       s_axi_lite_bresp,
    output logic                             s_axi_lite_bvalid,
    input  logic                             s_axi_lite_bready,
    input  logic [C_S_AXI_LITE_ADDR_WIDTH-1:0] s_axi_lite_araddr,
    input  logic [2:0]                       s_axi_lite_arprot,
    input  logic                             s_axi_lite_arvalid,
    output logic                             s_axi_lite_arready,
    output logic [C_S_AXI_LITE_DATA_WIDTH-1:0] s_axi_lite_rdata,
    output logic [1:0]                       s_axi_lite_rresp,
    output logic                             s_axi_lite_rvalid,
    input  logic                             s_axi_lite_rready
);

//=============================================================================
// Internal PPI interfaces
//=============================================================================

rx_clk_ppi_if  clk_ppi_int();
rx_data_ppi_if data_ppi_int[LANE_COUNT]();

//=============================================================================
// D-PHY pad-to-interface wiring
//=============================================================================

rx_clk_d_phy_if  clk_d_phy_int();
rx_data_d_phy_if data_d_phy_int[LANE_COUNT]();

assign clk_d_phy_int.clk_LP_Dp_i = clk_lp_p_i;
assign clk_d_phy_int.clk_LP_Dn_i = clk_lp_n_i;
assign clk_d_phy_int.clk_HS_Dp_i = clk_hs_p_i;
assign clk_d_phy_int.clk_HS_Dn_i = clk_hs_n_i;

generate for (genvar i = 0; i < LANE_COUNT; i++) begin : pad_map
    assign data_d_phy_int[i].data_LP_Dp_i = data_lp_p_i[i];
    assign data_d_phy_int[i].data_LP_Dn_i = data_lp_n_i[i];
    assign data_d_phy_int[i].data_HS_Dp_i = data_hs_p_i[i];
    assign data_d_phy_int[i].data_HS_Dn_i = data_hs_n_i[i];
end endgenerate

//=============================================================================
// CSI-2 enable outputs (video_aclk domain) -> CDC -> PHY enable inputs
//=============================================================================
// The CSI-2 RX generates aClkEnable / aDxEnable in the video_aclk domain.
// The custom PHY consumes Enable_i in the refclk_i domain.  A 2-FF
// synchroniser bridges the domains.

wire aClkEnable;
wire aD0Enable;
wire aD1Enable;
wire aD2Enable;
wire aD3Enable;

// Collect CSI-2 enables into a vector for CDC (max 4 data lanes + 1 clock)
logic [4:0] csi2_enable;

assign csi2_enable[0] = aClkEnable;
assign csi2_enable[1] = aD0Enable;
assign csi2_enable[2] = (LANE_COUNT >= 2) ? aD1Enable : 1'b0;
assign csi2_enable[3] = (LANE_COUNT >= 3) ? aD2Enable : 1'b0;
assign csi2_enable[4] = (LANE_COUNT >= 4) ? aD3Enable : 1'b0;

// 2-FF synchroniser: video_aclk domain -> refclk_i domain
logic [4:0] enable_sync_meta;
logic [4:0] enable_sync;

always_ff @(posedge refclk_i or negedge arstn) begin
    if (!arstn) begin
        enable_sync_meta <= '0;
        enable_sync      <= '0;
    end else begin
        enable_sync_meta <= csi2_enable;
        enable_sync      <= enable_sync_meta;
    end
end

// Drive PHY enables
assign clk_ppi_int.Shutdownz_i    = 1'b1;
assign clk_ppi_int.Enable_i       = enable_sync[0];

generate for (genvar i = 0; i < LANE_COUNT; i++) begin : data_enable
    assign data_ppi_int[i].Shutdownz_i = 1'b1;
    assign data_ppi_int[i].Enable_i    = enable_sync[1+i];
end endgenerate

//=============================================================================
// Custom RX PHY: digital lane FSMs + behavioral analog front-end
//=============================================================================
// LANE_COUNT = 1:  instantiate rx_phy_top once (bundles clock + 1 data lane).
// LANE_COUNT > 1:  lane 0 uses rx_phy_top for both clock and data;
//                  additional lanes instantiate rx_data_lane + analog_rx_top
//                  with the shared clock lane's HS clock.

generate if (LANE_COUNT == 1) begin : single_lane

    // rx_phy_top bundles clock + 1 data lane (digital + analog).
    rx_phy_top #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_rx_phy (
        .arstn      (arstn),
        .refclk_i   (refclk_i),
        .clk_ppi    (clk_ppi_int),
        .data_ppi   (data_ppi_int[0]),
        .clk_d_phy  (clk_d_phy_int),
        .data_d_phy (data_d_phy_int[0])
    );

end else begin : multi_lane

    //--- Lane 0 (clock + data 0) ---
    rx_phy_top #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_rx_phy_lane0 (
        .arstn      (arstn),
        .refclk_i   (refclk_i),
        .clk_ppi    (clk_ppi_int),
        .data_ppi   (data_ppi_int[0]),
        .clk_d_phy  (clk_d_phy_int),
        .data_d_phy (data_d_phy_int[0])
    );

    //--- Lanes 1 .. LANE_COUNT-1 (data only) ---
    rx_clk_analog_if  clk_analog_share();
    rx_clk_d_phy_if   clk_d_phy_share();

    // Share the clock lane's HS clock with all data-only analog instances.
    assign clk_d_phy_share.clk_HS_Dp_i = clk_hs_p_i;
    assign clk_d_phy_share.clk_HS_Dn_i = clk_hs_n_i;
    assign clk_d_phy_share.clk_LP_Dp_i = clk_lp_p_i;
    assign clk_d_phy_share.clk_LP_Dn_i = clk_lp_n_i;

    for (genvar i = 1; i < LANE_COUNT; i++) begin : extra_lanes

        rx_data_analog_if data_analog_int();
        rx_data_d_phy_if  data_d_phy_int_i();

        assign data_d_phy_int_i.data_LP_Dp_i = data_lp_p_i[i];
        assign data_d_phy_int_i.data_LP_Dn_i = data_lp_n_i[i];
        assign data_d_phy_int_i.data_HS_Dp_i = data_hs_p_i[i];
        assign data_d_phy_int_i.data_HS_Dn_i = data_hs_n_i[i];

        // Digital data lane FSM
        rx_data_lane u_data_lane (
            .arstn   (arstn),
            .refclk_i(refclk_i),
            .ppi     (data_ppi_int[i]),
            .analog  (data_analog_int)
        );

        // Analog front-end: uses shared clock HS + per-lane data HS
        analog_rx_top #(
            .SERIAL_CLK_PER(SERIAL_CLK_PER)
        ) u_analog_data (
            .rstn_i     (arstn),
            .clk_analog (clk_analog_share),
            .data_analog(data_analog_int),
            .clk_d_phy  (clk_d_phy_share),
            .data_d_phy (data_d_phy_int_i)
        );
    end

end endgenerate

//=============================================================================
// CSI-2 RX PPI signal mapping
//=============================================================================
// Map the custom RX PHY's PPI (SystemVerilog interface) to the Digilent CSI-2
// RX port list (VHDL entity mipi_csi2_rx_top).

logic [7:0] rx_data_hs_vec [4];
logic       rx_sync_hs_vec  [4];
logic       rx_valid_hs_vec [4];
logic       rx_active_hs_vec[4];

generate for (genvar i = 0; i < 4; i++) begin : ppi_map
    if (i < LANE_COUNT) begin
        assign rx_data_hs_vec [i] = data_ppi_int[i].RxDataHS_o;
        assign rx_sync_hs_vec [i] = data_ppi_int[i].RxSyncHS_o;
        assign rx_valid_hs_vec[i] = data_ppi_int[i].RxValidHS_o;
        assign rx_active_hs_vec[i] = data_ppi_int[i].RxActiveHS_o;
    end else begin
        assign rx_data_hs_vec [i] = 8'd0;
        assign rx_sync_hs_vec [i] = 1'b0;
        assign rx_valid_hs_vec[i] = 1'b0;
        assign rx_active_hs_vec[i] = 1'b0;
    end
end endgenerate

//=============================================================================
// Digilent MIPI CSI-2 RX (VHDL entity)
//=============================================================================

mipi_csi2_rx_top #(
    .kVersionMajor               (0),
    .kVersionMinor               (0),
    .kTargetDT                   (TARGET_DT),
    .kGenerateAXIL               (GEN_AXIL),
    .kDebug                      (DEBUG),
    .kLaneCount                  (LANE_COUNT),
    .C_M_AXIS_COMPONENT_WIDTH    (C_M_AXIS_COMPONENT_WIDTH),
    .C_M_AXIS_TDATA_WIDTH        (C_M_AXIS_TDATA_WIDTH),
    .C_M_MAX_SAMPLES_PER_CLOCK   (C_M_MAX_SAMPLES_PER_CLOCK),
    .C_S_AXI_LITE_DATA_WIDTH     (C_S_AXI_LITE_DATA_WIDTH),
    .C_S_AXI_LITE_ADDR_WIDTH     (C_S_AXI_LITE_ADDR_WIDTH)
) u_csi2_rx (
    // PPI - Clock lane
    .RxByteClkHS            (clk_ppi_int.RxByteClkHS_o),
    .aClkStopstate          (clk_ppi_int.StopState_o),
    .aRxClkActiveHS         (clk_ppi_int.RxClkActiveHS_o),

    // PPI - Data lane 0
    .RxDataHSD0             (rx_data_hs_vec[0]),
    .RxSyncHSD0             (rx_sync_hs_vec[0]),
    .RxValidHSD0            (rx_valid_hs_vec[0]),
    .RxActiveHSD0           (rx_active_hs_vec[0]),
    .aD0Enable              (aD0Enable),

    // PPI - Data lane 1
    .RxDataHSD1             (rx_data_hs_vec[1]),
    .RxSyncHSD1             (rx_sync_hs_vec[1]),
    .RxValidHSD1            (rx_valid_hs_vec[1]),
    .RxActiveHSD1           (rx_active_hs_vec[1]),
    .aD1Enable              (aD1Enable),

    // PPI - Data lane 2
    .RxDataHSD2             (rx_data_hs_vec[2]),
    .RxSyncHSD2             (rx_sync_hs_vec[2]),
    .RxValidHSD2            (rx_valid_hs_vec[2]),
    .RxActiveHSD2           (rx_active_hs_vec[2]),
    .aD2Enable              (aD2Enable),

    // PPI - Data lane 3
    .RxDataHSD3             (rx_data_hs_vec[3]),
    .RxSyncHSD3             (rx_sync_hs_vec[3]),
    .RxValidHSD3            (rx_valid_hs_vec[3]),
    .RxActiveHSD3           (rx_active_hs_vec[3]),
    .aD3Enable              (aD3Enable),

    // Clock lane enable
    .aClkEnable             (aClkEnable),

    // AXI4-Stream Video
    .m_axis_video_tdata     (m_axis_video_tdata),
    .m_axis_video_tvalid    (m_axis_video_tvalid),
    .m_axis_video_tready    (m_axis_video_tready),
    .m_axis_video_tlast     (m_axis_video_tlast),
    .m_axis_video_tuser     (m_axis_video_tuser),

    // Video clock / reset
    .video_aresetn          (video_aresetn),
    .video_aclk             (video_aclk),

    // AXI-Lite (always connected; unused when GEN_AXIL == 0)
    .s_axi_lite_aclk        (s_axi_lite_aclk),
    .s_axi_lite_aresetn     (s_axi_lite_aresetn),
    .s_axi_lite_awaddr      (s_axi_lite_awaddr),
    .s_axi_lite_awprot      (s_axi_lite_awprot),
    .s_axi_lite_awvalid     (s_axi_lite_awvalid),
    .s_axi_lite_awready     (s_axi_lite_awready),
    .s_axi_lite_wdata       (s_axi_lite_wdata),
    .s_axi_lite_wstrb       (s_axi_lite_wstrb),
    .s_axi_lite_wvalid      (s_axi_lite_wvalid),
    .s_axi_lite_wready      (s_axi_lite_wready),
    .s_axi_lite_bresp       (s_axi_lite_bresp),
    .s_axi_lite_bvalid      (s_axi_lite_bvalid),
    .s_axi_lite_bready      (s_axi_lite_bready),
    .s_axi_lite_araddr      (s_axi_lite_araddr),
    .s_axi_lite_arprot      (s_axi_lite_arprot),
    .s_axi_lite_arvalid     (s_axi_lite_arvalid),
    .s_axi_lite_arready     (s_axi_lite_arready),
    .s_axi_lite_rdata       (s_axi_lite_rdata),
    .s_axi_lite_rresp       (s_axi_lite_rresp),
    .s_axi_lite_rvalid      (s_axi_lite_rvalid),
    .s_axi_lite_rready      (s_axi_lite_rready)
);

endmodule

module tx_phy_top #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic        arstn,
    input  logic        ref_clk_i,
    // Digital PPI and control interface
    input  logic        TxClkEsc_i,
    input  logic        ForceTXStopmode_i,
    input  logic        TxRequestHS_i,
    input  logic        TxUlpsClk_i,
    input  logic        TxUlpsClkExit_i,
    input  logic        DataLaneEnable_i,
    input  logic [7:0]  TxDataHS_i,
    input  logic [1:0]  TxDataWidthHS_i,
    input  logic [3:0]  TxWordValidHS_i,
    input  logic        TxDataTransferEnHS_i,
    input  logic        TxRequestEsc_i,
    input  logic [3:0]  TxTriggerEsc_i,
    input  logic        TxUlpsEsc_i,
    input  logic        TxUlpsDataExit_i,
    
    // High-speed analog outputs
    output logic        hs_data_Dp_o,
    output logic        hs_data_Dn_o,
    output logic        hs_clk_Dp_o,
    output logic        hs_clk_Dn_o,

    // Low Power Outputs
    output logic        tx_lane_LP_Dp_o,
    output logic        tx_lane_LP_Dn_o,
    output logic        clk_LP_Dp_o,
    output logic        clk_LP_Dn_o
    

);
    // Internal signals for digital/analog interface
    logic        serializer_en;
    logic [7:0]  parallel_data;
    logic        ddr_clk_buff_en;
    logic        clk_div8;
    logic        pll_lock;
    logic        hs_clk_i;
    logic        hs_clk_q;
    logic        hs_clk_q_gated;

    tx_clk_ppi_if      clk_ppi_if();
    tx_clk_analog_if   clk_analog_if();
    tx_clk_d_phy_if    clk_d_phy_if();

    tx_data_ppi_if     data_ppi_if();
    tx_data_analog_if  data_analog_if();
    tx_data_d_phy_if   data_d_phy_if();

    // Bridge scalar control inputs from top-level into the lane interfaces.
    assign clk_ppi_if.TxClkEsc_i            = TxClkEsc_i;
    assign clk_ppi_if.ForceTXStopmode_i     = ForceTXStopmode_i;
    assign clk_ppi_if.TxRequestHS_i         = TxRequestHS_i;
    assign clk_ppi_if.TxUlpsClk_i           = TxUlpsClk_i;
    assign clk_ppi_if.TxUlpsExit_i          = TxUlpsClkExit_i;

    assign data_ppi_if.TxClkEsc_i           = TxClkEsc_i;
    assign data_ppi_if.enable_i             = DataLaneEnable_i;
    assign data_ppi_if.ForceTXStopmode_i    = ForceTXStopmode_i;
    assign data_ppi_if.TxRequestHS_i        = TxRequestHS_i;
    assign data_ppi_if.TxDataHS_i           = TxDataHS_i;
    assign data_ppi_if.TxDataWidthHS_i      = TxDataWidthHS_i;
    assign data_ppi_if.TxWordValidHS_i      = TxWordValidHS_i;
    assign data_ppi_if.TxDataTransferEnHS_i = TxDataTransferEnHS_i;
    assign data_ppi_if.TxRequestEsc_i       = TxRequestEsc_i;
    assign data_ppi_if.TxTriggerEsc_i       = TxTriggerEsc_i;
    assign data_ppi_if.TxUlpsEsc_i          = TxUlpsEsc_i;
    assign data_ppi_if.TxUlpsExit_i         = TxUlpsDataExit_i;

    assign clk_analog_if.clk_div            = clk_div8;
    assign data_analog_if.tx_lane_clk_div_i = clk_div8;

    // Bridge key digital outputs toward analog and top-level pins.
    assign serializer_en    = data_analog_if.serializer_en_o;
    assign parallel_data    = data_analog_if.parallel_data_o;
    assign ddr_clk_buff_en  = clk_analog_if.ddr_clk_buff_en;
    assign clk_LP_Dp_o      = clk_d_phy_if.clk_LP_Dp_o;
    assign clk_LP_Dn_o      = clk_d_phy_if.clk_LP_Dn_o;
    assign tx_lane_LP_Dp_o  = data_d_phy_if.tx_lane_LP_Dp_o;
    assign tx_lane_LP_Dn_o  = data_d_phy_if.tx_lane_LP_Dn_o;

    // Digital wrapper instance
    tx_d_phy u_tx_d_phy (
        .arstn(arstn),
        .clk_ppi(clk_ppi_if),
        .clk_analog(clk_analog_if),
        .clk_d_phy(clk_d_phy_if),
        .data_ppi(data_ppi_if),
        .data_analog(data_analog_if),
        .data_d_phy(data_d_phy_if)
    );
    // Analog top instance
    analog_top #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_analog_top (
        .rstn_i(arstn),
        .ref_clk_i(ref_clk_i),
        .serializer_en_i(serializer_en),
        .parallel_data_i(parallel_data),
        .ddr_clk_buff_en_i(ddr_clk_buff_en),
        .hs_data_dp_o(hs_data_Dp_o),
        .hs_data_dn_o(hs_data_Dn_o),
        .hs_clk_dp_o(hs_clk_Dp_o),
        .hs_clk_dn_o(hs_clk_Dn_o),
        .clk_i_o(hs_clk_i),
        .clk_q_o(hs_clk_q),
        .clk_div8_o(clk_div8),
        .pll_lock_o(pll_lock)
    );
endmodule

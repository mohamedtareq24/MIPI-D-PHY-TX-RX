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
    // Digital wrapper instance
    tx_d_phy u_tx_d_phy (
        .arstn(arstn),
        .TxClkEsc_i(TxClkEsc_i),
        .ForceTXStopmode_i(ForceTXStopmode_i),
        .TxRequestHS_i(TxRequestHS_i),
        .TxUlpsClk_i(TxUlpsClk_i),
        .TxUlpsClkExit_i(TxUlpsClkExit_i),
        .DataLaneEnable_i(DataLaneEnable_i),
        .TxDataHS_i(TxDataHS_i),
        .TxDataWidthHS_i(TxDataWidthHS_i),
        .TxWordValidHS_i(TxWordValidHS_i),
        .TxDataTransferEnHS_i(TxDataTransferEnHS_i),
        .TxRequestEsc_i(TxRequestEsc_i),
        .TxTriggerEsc_i(TxTriggerEsc_i),
        .TxUlpsEsc_i(TxUlpsEsc_i),
        .TxUlpsDataExit_i(TxUlpsDataExit_i),
        .clk_div_i(clk_div8), // Connects to analog clk_div8
        // Outputs not used for analog path are left unconnected
        .TxReadyHSClk_o(TxReadyHSClk_o),
        .TxByteClkHS_o(TxByteClkHS_o),
        .TxUlpsClkActive_n_o(TxUlpsClkActive_n_o),
        .ClkStopState_o(ClkStopState_o),
        .clk_LP_Dp_o(clk_LP_Dp_o),
        .clk_LP_Dn_o(clk_LP_Dn_o),
        .TxReadyHSData_o(TxReadyHSData_o),
        .TxUlpsDataActive_n_o(TxUlpsDataActive_n_o),
        .DataStopState_o(DataStopState_o),
        .tx_lane_LP_Dp_o(tx_lane_LP_Dp_o),
        .tx_lane_LP_Dn_o(tx_lane_LP_Dn_o),
        .serializer_en_o(serializer_en),
        .parallel_data_o(parallel_data)
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
        .hs_data_dp_o(hs_data_dp_o),
        .hs_data_dn_o(hs_data_dn_o),
        .hs_clk_dp_o(hs_clk_dp_o),
        .hs_clk_dn_o(hs_clk_dn_o),
        .clk_i_o(hs_clk_i),
        .clk_q_o(hs_clk_q),
        .clk_div8_o(clk_div8),
        .pll_lock_o(pll_lock)
    );
endmodule

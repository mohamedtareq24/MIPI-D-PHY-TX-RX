module tx_d_phy (
    input  logic        arstn,

    // Shared PPI control clock/reset domain
    input  logic        TxClkEsc_i,
    input  logic        ForceTXStopmode_i,

    // Shared HS request
    input  logic        TxRequestHS_i,

    // Clock-lane ULPS controls
    input  logic        TxUlpsClk_i,
    input  logic        TxUlpsClkExit_i,

    // Data-lane controls
    input  logic        DataLaneEnable_i,
    input  logic [7:0]  TxDataHS_i,
    input  logic [1:0]  TxDataWidthHS_i,
    input  logic [3:0]  TxWordValidHS_i,
    input  logic        TxDataTransferEnHS_i,

    // Data-lane ESC controls
    input  logic        TxRequestEsc_i,
    input  logic [3:0]  TxTriggerEsc_i,
    input  logic        TxUlpsEsc_i,
    input  logic        TxUlpsDataExit_i,

    // Analog clocks
    input  logic        clk_div_i,

    // Clock-lane outputs
    output logic        TxReadyHSClk_o,
    output logic        TxByteClkHS_o,
    output logic        TxUlpsClkActive_n_o,
    output logic        ClkStopState_o,
    output logic        clk_LP_Dp_o,
    output logic        clk_LP_Dn_o,
    output logic        ddr_clk_buff_en_o,

    // Data-lane outputs
    output logic        TxReadyHSData_o,
    output logic        TxUlpsDataActive_n_o,
    output logic        DataStopState_o,
    output logic        tx_lane_LP_Dp_o,
    output logic        tx_lane_LP_Dn_o,
    output logic        serializer_en_o,
    output logic [7:0]  parallel_data_o
);

    clock_lane u_clock_lane (
        .arstn(arstn),
        .TxClkEsc_i(TxClkEsc_i),
        .TxRequestHS_i(TxRequestHS_i),
        .TxReadyHS_o(TxReadyHSClk_o),
        .TxByteClkHS_o(TxByteClkHS_o),
        .TxUlpsClk_i(TxUlpsClk_i),
        .TxUlpsExit_i(TxUlpsClkExit_i),
        .TxUlpsActive_n_o(TxUlpsClkActive_n_o),
        .StopState_o(ClkStopState_o),
        .ForceTXStopmode_i(ForceTXStopmode_i),
        .clk_LP_Dp_o(clk_LP_Dp_o),
        .clk_LP_Dn_o(clk_LP_Dn_o),
        .clk_div(clk_div_i),
        .ddr_clk_buff_en(ddr_clk_buff_en_o)
    );

    tx_data_lane u_tx_data_lane (
        .arstn(arstn),
        .TxClkEsc_i(TxClkEsc_i),
        .enable_i(DataLaneEnable_i),
        .ForceTXStopmode_i(ForceTXStopmode_i),
        .StopState_o(DataStopState_o),
        .TxRequestHS_i(TxRequestHS_i),
        .TxDataHS_i(TxDataHS_i),
        .TxDataWidthHS_i(TxDataWidthHS_i),
        .TxWordValidHS_i(TxWordValidHS_i),
        .TxDataTransferEnHS_i(TxDataTransferEnHS_i),
        .TxReadyHS_o(TxReadyHSData_o),
        .TxRequestEsc_i(TxRequestEsc_i),
        .TxTriggerEsc_i(TxTriggerEsc_i),
        .TxUlpsEsc_i(TxUlpsEsc_i),
        .TxUlpsExit_i(TxUlpsDataExit_i),
        .TxUlpsActive_n_o(TxUlpsDataActive_n_o),
        .tx_lane_LP_Dp_o(tx_lane_LP_Dp_o),
        .tx_lane_LP_Dn_o(tx_lane_LP_Dn_o),
        .tx_lane_clk_div_i(clk_div_i),
        .serializer_en_o(serializer_en_o),
        .parallel_data_o(parallel_data_o)
    );

endmodule

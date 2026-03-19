module ppi_clk_tb_top;
    import uvm_pkg::*;
    import ppi_clk_pkg::*;

    localparam int unsigned SERIAL_CLK_PER = 8;
    ppi_clk_intf clk_intf();
    
    logic arstn;
    logic ref_clk_i;
    logic clk_LP_Dp_o, clk_LP_Dn_o;
    logic hs_clk_Dp_o, hs_clk_Dn_o;

    initial begin
        arstn = 0;
        ref_clk_i = 0;
        #20 arstn = 1;
    end

    always #1 ref_clk_i = ~ref_clk_i;

tx_phy_top # (
    .SERIAL_CLK_PER(SERIAL_CLK_PER)
    )
    tx_phy_top_inst (
    .arstn(arstn),
    .ref_clk_i(ref_clk_i),

    .TxClkEsc_i(clk_intf.TxClkEsc_i),
    .ForceTXStopmode_i(clk_intf.ForceTXStopmode_i),
    .TxRequestHS_i(clk_intf.TxRequestHS_i),
    .TxUlpsClk_i(clk_intf.TxUlpsClk_i),
    .TxUlpsClkExit_i(clk_intf.TxUlpsClkExit_i),
    
    .clk_LP_Dp_o(clk_LP_Dp_o),
    .clk_LP_Dn_o(clk_LP_Dn_o),
    .hs_clk_Dp_o(hs_clk_Dp_o),
    .hs_clk_Dn_o(hs_clk_Dn_o),

    .DataLaneEnable_i(),
    .TxDataHS_i(),
    .TxDataWidthHS_i(),
    .TxWordValidHS_i(),
    .TxDataTransferEnHS_i(),
    .TxRequestEsc_i(),
    .TxTriggerEsc_i(),
    .TxUlpsEsc_i(),
    .TxUlpsDataExit_i(),
    .hs_data_Dp_o(),
    .hs_data_Dn_o(),
    .tx_lane_LP_Dp_o(),
    .tx_lane_LP_Dn_o()
    );
    initial begin
        uvm_config_db#(virtual ppi_clk_intf)::set(null, "uvm_test_top.clk_agent.clk_drv", "vif", clk_intf);
        uvm_config_db#(virtual ppi_clk_intf)::set(null, "*uvm_test_top.clk_agent.clk_mon", "vif", clk_intf);
        run_test();
    end

endmodule
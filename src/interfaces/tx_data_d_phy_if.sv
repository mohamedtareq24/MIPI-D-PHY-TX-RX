interface tx_data_d_phy_if();
    logic       tx_lane_LP_Dp_o;
    logic       tx_lane_LP_Dn_o;
    logic       hs_data_Dp_o;
    logic       hs_data_Dn_o;
    
    modport tx_d_phy_lp (
        output tx_lane_LP_Dp_o,
        output tx_lane_LP_Dn_o
    );

    modport tx_d_phy_hs (
        output hs_data_Dp_o,
        output hs_data_Dn_o
    );

    modport tx (
        output tx_lane_LP_Dp_o,
        output tx_lane_LP_Dn_o,
        output hs_data_Dp_o,
        output hs_data_Dn_o
    );
endinterface
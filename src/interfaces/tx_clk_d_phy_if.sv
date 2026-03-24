interface tx_clk_d_phy_if();
    logic clk_LP_Dp_o;
    logic clk_LP_Dn_o;

    modport tx_d_phy_lp (
        output clk_LP_Dp_o,
        output clk_LP_Dn_o
    );

endinterface

module tx_phy_top #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic                  arstn,

    tx_clk_ppi_if.tx                          clk_ppi,
    tx_data_ppi_if.tx                         data_ppi,

    tx_clk_d_phy_if.tx_d_phy_lp               clk_d_phy_lp,
    tx_clk_d_phy_if.tx_d_phy_hs               clk_d_phy_hs,

    tx_data_d_phy_if.tx_d_phy_lp              data_d_phy_lp,
    tx_data_d_phy_if.tx_d_phy_hs              data_d_phy_hs
);

    tx_clk_analog_if  clk_analog_if();
    tx_data_analog_if data_analog_if();

    // Digital wrapper instance
    tx_d_phy u_tx_d_phy (
        .arstn(arstn),
        .clk_ppi(clk_ppi),
        .clk_analog(clk_analog_if),
        .clk_d_phy(clk_d_phy_lp),

        .data_ppi(data_ppi),
        .data_analog(data_analog_if),
        .data_d_phy(data_d_phy_lp)
    );
    // Analog top instance
    analog_top #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_analog_top (
        .rstn_i(arstn),
        .data_analog(data_analog_if),
        .clk_analog(clk_analog_if),
        .data_d_phy(data_d_phy_hs),
        .clk_d_phy(clk_d_phy_hs),
        .clk_i_o(),
        .clk_q_o(),
        .clk_div8_o(),
        .pll_lock_o()
    );
endmodule

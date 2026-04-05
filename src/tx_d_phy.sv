`timescale 1ns/1ps
module tx_d_phy (
    input  logic                  arstn,
    
    tx_clk_ppi_if.tx              clk_ppi,
    tx_clk_analog_if.digital      clk_analog,
    tx_clk_d_phy_if.tx_d_phy_lp   clk_d_phy,

    tx_data_ppi_if.tx             data_ppi,
    tx_data_analog_if.digital     data_analog,
    tx_data_d_phy_if.tx_d_phy_lp  data_d_phy
);

    tx_clock_lane u_tx_clock_lane (
        .arstn(arstn),
        .ppi(clk_ppi),
        .analog(clk_analog),
        .d_phy(clk_d_phy)
    );

    tx_data_lane u_tx_data_lane (
        .arstn(arstn),
        .ppi(data_ppi),
        .analog(data_analog),
        .d_phy(data_d_phy)
    );

endmodule

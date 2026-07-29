`timescale 1ns/1ps
// RX PHY top (mirror of tx_phy_top): digital wrapper (rx_d_phy) + behavioral analog
// front-end (analog_rx_top). Exposes the PPI to the controller and the pad-side
// LP/HS lines (driven by the link / testbench).
//
// NOTE: embeds the behavioral analog model, so this integration top is verified in
// simulation (Questa); the Verilator gate applies to rx_d_phy and the lanes.
module rx_phy_top #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic               arstn,
    input  logic               refclk_i,

    rx_clk_ppi_if.rx           clk_ppi,
    rx_data_ppi_if.rx          data_ppi,

    rx_clk_d_phy_if.analog     clk_d_phy,    // pad-side LP/HS inputs
    rx_data_d_phy_if.analog    data_d_phy
);

    rx_clk_analog_if  clk_analog_if();
    rx_data_analog_if data_analog_if();

    // Digital wrapper.
    rx_d_phy u_rx_d_phy (
        .arstn      (arstn),
        .refclk_i   (refclk_i),
        .clk_ppi    (clk_ppi),
        .clk_analog (clk_analog_if),
        .data_ppi   (data_ppi),
        .data_analog(data_analog_if)
    );

    // Behavioral analog front-end.
    analog_rx_top #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_analog_rx_top (
        .rstn_i     (arstn),
        .clk_analog (clk_analog_if),
        .data_analog(data_analog_if),
        .clk_d_phy  (clk_d_phy),
        .data_d_phy (data_d_phy)
    );

endmodule

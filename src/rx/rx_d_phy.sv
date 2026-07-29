`timescale 1ns/1ps
// RX digital wrapper (mirror of tx_d_phy): instantiates the two RX lane FSMs.
module rx_d_phy (
    input  logic               arstn,
    input  logic               refclk_i,   // LP sample clock for both lanes

    rx_clk_ppi_if.rx           clk_ppi,
    rx_clk_analog_if.digital   clk_analog,

    rx_data_ppi_if.rx          data_ppi,
    rx_data_analog_if.digital  data_analog
);

    rx_clock_lane u_rx_clock_lane (
        .arstn   (arstn),
        .refclk_i(refclk_i),
        .ppi     (clk_ppi),
        .analog  (clk_analog)
    );

    rx_data_lane u_rx_data_lane (
        .arstn   (arstn),
        .refclk_i(refclk_i),
        .ppi     (data_ppi),
        .analog  (data_analog)
    );

endmodule

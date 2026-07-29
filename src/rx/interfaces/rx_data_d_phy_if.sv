`timescale 1ns/1ps
// RX data lane pad <-> analog wires (mirror of tx_data_d_phy_if, reversed direction).
// On RX the LP/HS lines are INPUTS received from the pads by analog_rx_top.
interface rx_data_d_phy_if();
    logic data_LP_Dp_i;
    logic data_LP_Dn_i;
    logic data_HS_Dp_i;
    logic data_HS_Dn_i;

    // Analog front-end consumes the LP lines.
    modport rx_d_phy_lp (
        input data_LP_Dp_i,
        input data_LP_Dn_i
    );

    // Analog front-end consumes the HS data lines.
    modport rx_d_phy_hs (
        input data_HS_Dp_i,
        input data_HS_Dn_i
    );

    // Whole-lane analog consumer (LP + HS).
    modport analog (
        input data_LP_Dp_i,
        input data_LP_Dn_i,
        input data_HS_Dp_i,
        input data_HS_Dn_i
    );

    // Pad driver side (e.g. testbench stimulus).
    modport pad (
        output data_LP_Dp_i,
        output data_LP_Dn_i,
        output data_HS_Dp_i,
        output data_HS_Dn_i
    );
endinterface

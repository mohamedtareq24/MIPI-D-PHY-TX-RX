`timescale 1ns/1ps
// RX clock lane pad <-> analog wires (mirror of tx_clk_d_phy_if, reversed direction).
// On RX the LP/HS lines are INPUTS received from the pads by analog_rx_top.
interface rx_clk_d_phy_if();
    logic clk_LP_Dp_i;
    logic clk_LP_Dn_i;
    logic clk_HS_Dp_i;
    logic clk_HS_Dn_i;

    // Analog front-end consumes the LP lines.
    modport rx_d_phy_lp (
        input clk_LP_Dp_i,
        input clk_LP_Dn_i
    );

    // Analog front-end consumes the HS clock lines.
    modport rx_d_phy_hs (
        input clk_HS_Dp_i,
        input clk_HS_Dn_i
    );

    // Whole-lane analog consumer (LP + HS).
    modport analog (
        input clk_LP_Dp_i,
        input clk_LP_Dn_i,
        input clk_HS_Dp_i,
        input clk_HS_Dn_i
    );

    // Pad driver side (e.g. testbench stimulus).
    modport pad (
        output clk_LP_Dp_i,
        output clk_LP_Dn_i,
        output clk_HS_Dp_i,
        output clk_HS_Dn_i
    );
endinterface

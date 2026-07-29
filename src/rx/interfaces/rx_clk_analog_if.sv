`timescale 1ns/1ps
// RX clock lane analog <-> digital boundary (mirror of tx_clk_analog_if).
// Analog recovers the HS clock and presents LP receiver levels; digital decodes
// line state and enables the HS clock receiver.
interface rx_clk_analog_if();
    logic rx_byte_clk_i;        // recovered byte clock (analog -> digital)
    logic hs_clk_active_i;      // analog detects HS clock toggling (analog -> digital)
    logic lp_rxp_i;             // LP-RX receiver level, Dp (analog -> digital)
    logic lp_rxn_i;             // LP-RX receiver level, Dn (analog -> digital)
    logic hs_rx_en_o;           // enable HS clock receiver (digital -> analog)

    modport digital (
        input   rx_byte_clk_i,
        input   hs_clk_active_i,
        input   lp_rxp_i,
        input   lp_rxn_i,
        output  hs_rx_en_o
    );

    modport analog (
        output  rx_byte_clk_i,
        output  hs_clk_active_i,
        output  lp_rxp_i,
        output  lp_rxn_i,
        input   hs_rx_en_o
    );
endinterface

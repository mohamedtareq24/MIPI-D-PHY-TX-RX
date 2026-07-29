`timescale 1ns/1ps
// RX data lane analog <-> digital boundary (mirror of tx_data_analog_if).
// Analog samples HS, 1:8 deserializes to a parallel byte on the recovered byte
// clock, and presents LP receiver levels; digital aligns/decodes and enables HS.
interface rx_data_analog_if();
    logic       rx_lane_clk_div_i;   // recovered byte clock for this lane (analog -> digital)
    logic [7:0] parallel_data_i;     // deserialized byte, unaligned (analog -> digital)
    logic       lp_rxp_i;            // LP-RX receiver level, Dp (analog -> digital)
    logic       lp_rxn_i;            // LP-RX receiver level, Dn (analog -> digital)
    logic       hs_rx_en_o;          // enable HS sampler/deserializer (digital -> analog)

    modport digital (
        input   rx_lane_clk_div_i,
        input   parallel_data_i,
        input   lp_rxp_i,
        input   lp_rxn_i,
        output  hs_rx_en_o
    );

    modport analog (
        output  rx_lane_clk_div_i,
        output  parallel_data_i,
        output  lp_rxp_i,
        output  lp_rxn_i,
        input   hs_rx_en_o
    );
endinterface

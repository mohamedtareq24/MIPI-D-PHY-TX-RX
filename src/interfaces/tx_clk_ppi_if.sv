`timescale 1ns/1ps
interface tx_clk_ppi_if();
    // PPI Control
    logic TxClkEsc_i;
    logic ForceTXStopmode_i;
    logic Enable_i;
    logic StopState_o;


    // PPI HS
    logic TxRequestHS_i;
    logic TxReadyHS_o;
    logic TxByteClkHS_o;

    // PPI ULPS
    logic TxUlpsClk_i;
    logic TxUlpsExit_i;
    logic TxUlpsActive_n_o;

    modport tx (
        input   TxClkEsc_i,
        input   ForceTXStopmode_i,
        output  StopState_o,

        input   TxRequestHS_i,
        output  TxReadyHS_o,
        output  TxByteClkHS_o,

        input   TxUlpsClk_i,
        input   TxUlpsExit_i,
        output  TxUlpsActive_n_o
    );

endinterface

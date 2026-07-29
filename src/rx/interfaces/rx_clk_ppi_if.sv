`timescale 1ns/1ps
// PPI for the RX clock lane (digital <-> controller).
// Scope: HS-clock receive + ULPS. See docs/RX_PHY_SCOPE.md.
interface rx_clk_ppi_if();
    // Control (from controller)
    logic Enable_i;
    logic Shutdownz_i;          // active-low shutdown

    // Status / receive indications (to controller)
    logic StopState_o;
    logic RxClkActiveHS_o;       // HS clock is being received
    logic RxUlpsActiveNot_o;     // active-low: 0 => clock lane in ULPS
    logic RxByteClkHS_o;         // recovered byte clock, forwarded to controller + data lane
    logic ErrControl_o;          // illegal LP line-state sequence

    // Clock-lane FSM side.
    modport rx (
        input   Enable_i,
        input   Shutdownz_i,
        output  StopState_o,
        output  RxClkActiveHS_o,
        output  RxUlpsActiveNot_o,
        output  RxByteClkHS_o,
        output  ErrControl_o
    );
endinterface

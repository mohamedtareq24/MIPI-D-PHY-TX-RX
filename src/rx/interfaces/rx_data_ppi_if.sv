`timescale 1ns/1ps
// PPI for the RX data lane (digital <-> controller).
// Scope: HS receive (<1.5 Gbps) + Escape (ULPS, Remote triggers). See docs/RX_PHY_SCOPE.md.
// Note: RxByteClkHS lives on the clock-lane PPI (rx_clk_ppi_if), as in TX.
interface rx_data_ppi_if();
    // Control (from controller)
    logic Enable_i;
    logic Shutdownz_i;          // active-low shutdown

    // HS receive
    logic [7:0] RxDataHS_o;
    logic       RxValidHS_o;     // RxDataHS is valid this byte-clock
    logic       RxActiveHS_o;    // HS reception in progress
    logic       RxSyncHS_o;      // SoT sync (0xB8) detected, byte boundary aligned

    // Escape receive
    logic       RxClkEsc_o;      // recovered escape clock
    logic       RxUlpsEsc_o;     // ULPS escape entered
    logic       RxUlpsActiveNot_o; // active-low: 0 => data lane in ULPS
    logic [3:0] RxTriggerEsc_o;  // remote trigger received (one-hot)
    logic       RxValidEsc_o;    // escape payload valid

    // Escape receive — LPDT
    logic       RxLpdtEsc_o;    // LPDT reception in progress
    logic [7:0] RxDataEsc_o;     // recovered LPDT payload byte

    // Status
    logic StopState_o;

    // Errors
    logic ErrSotHS_o;            // SoT error, recoverable
    logic ErrSotSyncHS_o;        // SoT sync not found, HS aborted
    logic ErrControl_o;          // illegal LP line-state sequence
    logic ErrEsc_o;              // unrecognized escape command

    // Data-lane FSM side.
    modport rx (
        input   Enable_i,
        input   Shutdownz_i,
        output  RxDataHS_o,
        output  RxValidHS_o,
        output  RxActiveHS_o,
        output  RxSyncHS_o,
        output  RxClkEsc_o,
        output  RxUlpsEsc_o,
        output  RxUlpsActiveNot_o,
        output  RxTriggerEsc_o,
        output  RxValidEsc_o,
        output  RxLpdtEsc_o,
        output  RxDataEsc_o,
        output  StopState_o,
        output  ErrSotHS_o,
        output  ErrSotSyncHS_o,
        output  ErrControl_o,
        output  ErrEsc_o
    );
endinterface

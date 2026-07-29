`timescale 1ns/1ps
// RX data-lane UVC: emulates the link transmitter's DATA lane.
// Drives the data-lane pad (HS bitstream + LP escape signalling) and the
// data-lane PPI enables, and monitors the data-lane PPI outputs to recover the
// received payload / escape events.
//
// HS bits are timed to the clk_HS edges produced by the rx_clock_lane_uvc; the
// top-level virtual sequence starts the clock before an HS burst and stops it
// afterwards. See docs/RX_PHY_SCOPE.md.
package rx_data_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Keep include order aligned with class dependencies.
    `include "rx_data_tr.sv"
    `include "rx_data_seqncr.sv"
    `include "rx_data_driver.sv"
    `include "rx_data_mon.sv"
    `include "rx_data_agent.sv"
    `include "rx_data_seq_lib.sv"
endpackage

`timescale 1ns/1ps
// RX clock-lane UVC: emulates the link transmitter's CLOCK lane.
// Drives the clock-lane pad (LP entry/exit + free-running HS clock) and the
// clock-lane PPI enables, and passively monitors the clock-lane PPI outputs.
//
// The HS clock free-runs once started; the data-lane UVC times its bits to the
// clk_HS edges produced here. Coordination (start clock -> data burst -> stop
// clock) is done by the top-level virtual sequence. See docs/RX_PHY_SCOPE.md.
package rx_clk_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Keep include order aligned with class dependencies.
    `include "rx_clk_tr.sv"
    `include "rx_clk_seqncr.sv"
    `include "rx_clk_driver.sv"
    `include "rx_clk_mon.sv"
    `include "rx_clk_agent.sv"
    `include "rx_clk_seq_lib.sv"
endpackage

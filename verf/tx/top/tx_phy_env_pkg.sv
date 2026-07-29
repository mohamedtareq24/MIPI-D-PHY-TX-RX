`timescale 1ns/1ps
package tx_phy_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Golden spec oracle (shared TX/RX).
    import mipi_spec_pkg::*;

    // Reuse the per-lane UVCs.
    import ppi_clk_pkg::*;
    import ppi_data_pkg::*;

    // Keep include order aligned with class dependencies.
    `include "tx_phy_vseqr.sv"
    `include "tx_phy_vseq_lib.sv"
    `include "tx_phy_hs_recover_mon.sv"
    `include "tx_phy_scoreboard.sv"
    `include "tx_phy_coverage.sv"
    `include "tx_phy_env.sv"
    `include "tx_phy_test_lib.sv"
endpackage

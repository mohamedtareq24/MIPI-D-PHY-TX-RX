`timescale 1ns/1ps
// RX PHY environment: container for the per-lane UVCs (clock + data), a virtual
// sequencer that coordinates them, a scoreboard, and the tests.
// HS-receive smoke scope. See docs/RX_PHY_SCOPE.md.
package rx_phy_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Golden spec oracle (shared TX/RX).
    import mipi_spec_pkg::*;

    // Reuse the per-lane UVCs.
    import rx_clk_pkg::*;
    import rx_data_pkg::*;

    // Keep include order aligned with class dependencies.
    `include "rx_phy_vseqr.sv"
    `include "rx_phy_vseq_lib.sv"
    `include "rx_phy_scoreboard.sv"
    `include "rx_phy_coverage.sv"
    `include "rx_phy_env.sv"
    `include "rx_phy_test_lib.sv"
endpackage

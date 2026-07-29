package loopback_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import mipi_spec_pkg::*;
    import ppi_clk_pkg::*;
    import ppi_data_pkg::*;
    import rx_clk_pkg::*;
    import rx_data_pkg::*;

    // Reused TX virtual sequencer + vseq library (depend only on the TX UVC pkgs).
    `include "tx_phy_vseqr.sv"
    `include "tx_phy_vseq_lib.sv"

    // Loopback components.
    `include "loopback_scoreboard.sv"
    `include "loopback_env.sv"
    `include "loopback_test_lib.sv"
endpackage

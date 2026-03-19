package ppi_clk_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Keep include order aligned with class dependencies.
    `include "ppi_clk_tr.sv"
    `include "ppi_clk_seqncr.sv"
    `include "ppi_clk_driver.sv"
    `include "ppi_clk_mon.sv"
    `include "ppi_clk_agent.sv"
    `include "ppi_clk_seq_lib.sv"
    `include "tb/ppi_clk_test_lib.sv"
endpackage
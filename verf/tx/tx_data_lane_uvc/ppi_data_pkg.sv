`timescale 1ns/1ps
package ppi_data_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Keep include order aligned with class dependencies.
    `include "ppi_tx_data_tr.sv"
    `include "ppi_tx_data_seqncr.sv"
    `include "ppi_tx_data_driver.sv"
    `include "ppi_tx_data_mon.sv"
    `include "ppi_tx_data_agent.sv"
    `include "ppi_tx_data_seq_lib.sv"
endpackage

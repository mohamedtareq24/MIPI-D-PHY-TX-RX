// Virtual sequencer: holds handles to both lane sequencers so virtual
// sequences can coordinate clock-lane and data-lane stimulus.
class tx_phy_vseqr extends uvm_sequencer;
    `uvm_component_utils(tx_phy_vseqr)

    ppi_clk_seqncr     clk_seqncr;
    ppi_tx_data_seqncr data_seqncr;

    function new(string name = "tx_phy_vseqr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

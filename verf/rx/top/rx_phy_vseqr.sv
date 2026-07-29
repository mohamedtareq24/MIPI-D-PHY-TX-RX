// Virtual sequencer: holds handles to both lane sequencers so virtual sequences
// can coordinate clock-lane and data-lane stimulus.
class rx_phy_vseqr extends uvm_sequencer;
    `uvm_component_utils(rx_phy_vseqr)

    rx_clk_seqncr  clk_seqr;
    rx_data_seqncr data_seqr;

    function new(string name = "rx_phy_vseqr", uvm_component parent);
        super.new(name, parent);
    endfunction
endclass

class ppi_tx_data_seqncr extends uvm_sequencer #(ppi_tx_data_tr);
    `uvm_component_utils(ppi_tx_data_seqncr)

    function new(string name = "ppi_tx_data_seqncr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class rx_data_seqncr extends uvm_sequencer #(rx_data_tr);
    `uvm_component_utils(rx_data_seqncr)

    function new(string name = "rx_data_seqncr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

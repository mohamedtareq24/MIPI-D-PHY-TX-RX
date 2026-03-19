class ppi_tx_data_seqncr extends uvm_sequencer #(ppi_clk_tr);
    `uvm_component_utils(ppi_tx_data_seqncr)

    function new(string name = "ppi_tx_data_seqncr");
        super.new(name);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
endclass
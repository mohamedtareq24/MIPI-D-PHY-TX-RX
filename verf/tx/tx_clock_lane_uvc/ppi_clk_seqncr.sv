class ppi_clk_seqncr extends uvm_sequencer #(ppi_clk_tr);
    `uvm_component_utils(ppi_clk_seqncr)

    function new(string name = "ppi_clk_seqncr", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction
endclass
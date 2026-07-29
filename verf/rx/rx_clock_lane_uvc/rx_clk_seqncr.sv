class rx_clk_seqncr extends uvm_sequencer #(rx_clk_tr);
    `uvm_component_utils(rx_clk_seqncr)

    function new(string name = "rx_clk_seqncr", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

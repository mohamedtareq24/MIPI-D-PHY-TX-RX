class ppi_clk_agent extends uvm_agent;
    `uvm_component_utils(ppi_clk_agent)

    ppi_clk_driver  clk_drv;
    ppi_clk_seqncr  clk_seqncr;
    ppi_clk_mon     clk_mon;
    uvm_analysis_port #(ppi_clk_tr) clk_ap;
    
    function new(string name = "ppi_clk_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        clk_drv = ppi_clk_driver::type_id::create("clk_drv", this);
        clk_seqncr = ppi_clk_seqncr::type_id::create("clk_seqncr", this);
        clk_mon = ppi_clk_mon::type_id::create("clk_mon", this);
        clk_ap = new("clk_ap", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        clk_drv.seq_item_port.connect(clk_seqncr.seq_item_export);
        clk_mon.analysis_port.connect(clk_ap);
    endfunction

endclass
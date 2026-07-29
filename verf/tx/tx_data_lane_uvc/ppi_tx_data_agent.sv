class ppi_tx_data_agent extends uvm_agent;
    `uvm_component_utils(ppi_tx_data_agent)
    ppi_tx_data_driver data_driver;
    ppi_tx_data_mon    data_mon;
    ppi_tx_data_seqncr data_seqncr;
    uvm_analysis_port #(ppi_tx_data_tr) data_ap;

    function new (string name = "ppi_tx_data_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        data_mon = ppi_tx_data_mon::type_id::create("data_mon", this);
        data_ap  = new("data_ap", this);
        if (get_is_active() == UVM_ACTIVE) begin
            data_driver = ppi_tx_data_driver::type_id::create("data_driver", this);
            data_seqncr = ppi_tx_data_seqncr::type_id::create("data_seqncr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        data_mon.analysis_port.connect(data_ap);
        if (get_is_active() == UVM_ACTIVE)
            data_driver.seq_item_port.connect(data_seqncr.seq_item_export);
    endfunction
endclass

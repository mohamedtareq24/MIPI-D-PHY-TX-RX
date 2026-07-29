class ppi_tx_data_mon extends uvm_monitor;
    `uvm_component_utils(ppi_tx_data_mon)

    virtual tx_data_ppi_if data_vif;
    virtual tx_clk_ppi_if  clk_vif;
    uvm_analysis_port #(ppi_tx_data_tr) analysis_port;

    function new(string name = "ppi_tx_data_mon", uvm_component parent);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual tx_data_ppi_if)::get(this, "", "data_vif", data_vif))
            `uvm_fatal("NOVIF", "data_vif (tx_data_ppi_if) not set for data monitor")
        if (!uvm_config_db#(virtual tx_clk_ppi_if)::get(this, "", "clk_vif", clk_vif))
            `uvm_fatal("NOVIF", "clk_vif (tx_clk_ppi_if) not set for data monitor")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            ppi_tx_data_tr tr;
            // Burst starts on HS request.
            @(posedge data_vif.TxRequestHS_i);
            tr = ppi_tx_data_tr::type_id::create("tr");
            tr.transaction_type = HS_DATA;

            // Collect injected payload bytes while the datapath is in payload phase.
            wait (data_vif.TxReadyHS_o == 1);
            while (data_vif.TxReadyHS_o == 1) begin
                tr.payload.push_back(data_vif.TxDataHS_i);
                @(posedge clk_vif.TxByteClkHS_o);
            end
            tr.payload_size = tr.payload.size();
            analysis_port.write(tr);
        end
    endtask
endclass

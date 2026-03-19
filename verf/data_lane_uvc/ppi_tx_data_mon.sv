class ppi_tx_data_mon extends uvm_monitor;
    `uvm_component_utils(ppi_tx_data_mon)
    ppi_tr tr;
    virtual ppi_intf data_vif;
    uvm_analysis_port#(ppi_tr) analysis_port;

    function new(string name = "ppi_tx_data_mon", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual ppi_intf)::get(this, "", "data_vif", data_vif)) begin
            `uvm_fatal("Data Interface not found", "Please set the virtual interface for data_vif")
        end
    endfunction

    function void extract_tr_type(ppi_tx_data_tr tr);
        case(1)
            (data_vif.TxDataTransferEnHS & data_vif.TxRequestHS & data_vif.TxWordValidHS): 
                tr.transaction_type = HS_DATA;
            (data_vif.TxUlpsEsc & data_vif.TxRequestEsc): 
                tr.transaction_type = ULPS_DATA;
            (data_vif.TxRequestEsc && data_vif.TxTriggerEsc[3:0]):
            begin  
                tr.transaction_type = TRGR_DATA; 
                tr.trgr_type = data_vif.TxTriggerEsc[3:0];                             
            end
            (data_vif.enable & data_vif.ForceTxStopmode):
                tr.transaction_type = LANE_EN;
             default: tr.transaction_type = HS_DATA; // Default case, can be modified as needed
        endcase
    endfunction


    task run_phase(uvm_phase phase);
        forever begin
            tr = ppi_tr::type_id::create("tr"); 
            extract_tr_type(tr);
            if (tr.transaction_type == HS_DATA) begin
                int size = 0;
                while ((data_vif.TxRequestHS == 1 && data_vif.TxDataTransferEnHS == 1));
                begin
                    @(posedge data_vif.TXWordClkHS);
                    tr.payload.push_back(data_vif.TxDataHS);
                    wait (data_vif.TxReadyHS == 1);
                end
                // Send the transaction to the analysis port
                // tr.payload_size = size;
            end
            analysis_port.write(tr);
        end
    endtask
endclass
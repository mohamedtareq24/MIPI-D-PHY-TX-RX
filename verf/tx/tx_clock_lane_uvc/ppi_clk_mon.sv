class ppi_clk_mon extends uvm_monitor;
    `uvm_component_utils(ppi_clk_mon)
    virtual tx_clk_ppi_if vif;
    uvm_analysis_port#(ppi_clk_tr) analysis_port;
    ppi_clk_tr tr;

    function new (string name =" ppi_clk_mon", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual tx_clk_ppi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not found")
        end
        analysis_port = new("analysis_port", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            tr = ppi_clk_tr::type_id::create("tr");
            case (1'b1)
                vif.TxRequestHS_i:      tr.transaction_type = HS_CLK;
                vif.TxUlpsClk_i:        tr.transaction_type = ULPS_CLK;
                vif.ForceTXStopmode_i:  tr.transaction_type = LANE_EN;
                default:                tr.transaction_type = HS_CLK;
            endcase
            @(posedge vif.TxClkEsc_i);
            tr.stop_state = vif.StopState_o;
            tr.ulps_active_n = vif.TxUlpsActive_n_o;
            tr.ulps_esc = 1'b0;
            // Send the transaction to the analysis port
            analysis_port.write(tr);
        end
    endtask
endclass
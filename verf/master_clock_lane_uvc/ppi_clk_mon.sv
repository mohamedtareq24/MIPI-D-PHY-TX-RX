class ppi_clk_mon extends uvm_monitor;
    `uvm_component_utils(ppi_clk_mon)
    virtual ppi_clk_intf vif;
    uvm_analysis_port#(ppi_clk_tr) analysis_port;
    ppi_clk_tr tr;

    function new (string name =" ppi_clk_mon", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ppi_clk_intf)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not found")
        end
        analysis_port = new("analysis_port", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            tr = ppi_clk_tr::type_id::create("tr");
            case (1'b1)
                vif.TxRequestHS: tr.transaction_type = HS_CLK;
                vif.TxUlpsClk:   tr.transaction_type = ULPS_CLK;
                vif.enable:      tr.transaction_type = LANE_ENABLE;
                default:             tr.transaction_type = HS_CLK;
            endcase
            @(posedge vif.TxClkEsc);
            tr.stop_state = vif.stop_state;
            tr.ulps_active_n = vif.TxUlpsActive_n;
            tr.ulps_esc = vif.TxUlpsEsc;
            // Send the transaction to the analysis port
            analysis_port.write(tr);
        end
    endtask
endclass
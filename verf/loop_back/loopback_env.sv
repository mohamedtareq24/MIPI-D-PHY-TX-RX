// Loopback environment: TX UVCs (active) drive the TX DUT; RX UVCs (passive)
// monitor the RX DUT. A loopback scoreboard compares intended vs recovered.
class loopback_env extends uvm_env;
    `uvm_component_utils(loopback_env)

    ppi_clk_agent      tx_clk_agent;
    ppi_tx_data_agent  tx_data_agent;
    rx_clk_agent       rx_clk_agent_h;
    rx_data_agent      rx_data_agent_h;

    tx_phy_vseqr        vseqr;
    loopback_scoreboard sb;

    function new(string name = "loopback_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "tx_clk_agent",  "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "tx_data_agent", "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "rx_clk_agent_h",  "is_active", UVM_PASSIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "rx_data_agent_h", "is_active", UVM_PASSIVE);

        tx_clk_agent    = ppi_clk_agent::type_id::create("tx_clk_agent", this);
        tx_data_agent   = ppi_tx_data_agent::type_id::create("tx_data_agent", this);
        rx_clk_agent_h  = rx_clk_agent::type_id::create("rx_clk_agent_h", this);
        rx_data_agent_h = rx_data_agent::type_id::create("rx_data_agent_h", this);

        vseqr = tx_phy_vseqr::type_id::create("vseqr", this);
        sb    = loopback_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vseqr.clk_seqncr  = tx_clk_agent.clk_seqncr;
        vseqr.data_seqncr = tx_data_agent.data_seqncr;
        tx_data_agent.data_driver.ap.connect(sb.tx_data_exp);
        rx_data_agent_h.mon.ap.connect(sb.rx_data_act);
    endfunction
endclass

// Integrated TX-PHY environment: clock-lane agent + data-lane agent + virtual
// sequencer. Scoreboard and coverage are added in later phases.
class tx_phy_env extends uvm_env;
    `uvm_component_utils(tx_phy_env)

    ppi_clk_agent          clk_agent;
    ppi_tx_data_agent      data_agent;
    tx_phy_vseqr           vseqr;
    tx_phy_hs_recover_mon  recover_mon;
    tx_phy_scoreboard      scoreboard;
    tx_phy_coverage        coverage;

    function new(string name = "tx_phy_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        clk_agent   = ppi_clk_agent::type_id::create("clk_agent", this);
        data_agent  = ppi_tx_data_agent::type_id::create("data_agent", this);
        vseqr       = tx_phy_vseqr::type_id::create("vseqr", this);
        recover_mon = tx_phy_hs_recover_mon::type_id::create("recover_mon", this);
        scoreboard  = tx_phy_scoreboard::type_id::create("scoreboard", this);
        coverage    = tx_phy_coverage::type_id::create("coverage", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        vseqr.clk_seqncr  = clk_agent.clk_seqncr;
        vseqr.data_seqncr = data_agent.data_seqncr;
        // HS payload integrity: injected (driver, authoritative) vs recovered (serial line).
        data_agent.data_driver.ap.connect(scoreboard.inj_imp);
        recover_mon.analysis_port.connect(scoreboard.rec_imp);
        // Escape command integrity: decoded off the LP lines vs spec Table 10.
        recover_mon.esc_port.connect(scoreboard.escrec_imp);
        // Functional coverage taps the same injected stream.
        data_agent.data_driver.ap.connect(coverage.analysis_export);
    endfunction
endclass

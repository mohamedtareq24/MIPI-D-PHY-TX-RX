// RX PHY environment: clock-lane UVC + data-lane UVC + scoreboard + virtual
// sequencer.
class rx_phy_env extends uvm_env;
    `uvm_component_utils(rx_phy_env)

    rx_clk_agent      clk_agent;
    rx_data_agent     data_agent;
    rx_phy_scoreboard sb;
    rx_phy_coverage   cov;
    rx_phy_vseqr      vseqr;

    function new(string name = "rx_phy_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        clk_agent  = rx_clk_agent::type_id::create("clk_agent", this);
        data_agent = rx_data_agent::type_id::create("data_agent", this);
        sb         = rx_phy_scoreboard::type_id::create("sb", this);
        cov        = rx_phy_coverage::type_id::create("cov", this);
        vseqr      = rx_phy_vseqr::type_id::create("vseqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        data_agent.drv.ap.connect(sb.exp_imp);
        data_agent.mon.ap.connect(sb.rcv_imp);
        data_agent.drv.ap.connect(cov.analysis_export);
        vseqr.clk_seqr  = clk_agent.seqr;
        vseqr.data_seqr = data_agent.seqr;
    endfunction
endclass

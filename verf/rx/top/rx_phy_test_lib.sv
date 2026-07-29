// RX PHY tests: each starts a top-level virtual sequence on the env vseqr.
class rx_phy_base_test extends uvm_test;
    `uvm_component_utils(rx_phy_base_test)

    rx_phy_env env;

    function new(string name = "rx_phy_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = rx_phy_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        rx_phy_hs_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_hs_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #1us;  // drain: let the burst propagate through the RX + monitor
        phase.drop_objection(this);
    endtask
endclass

class rx_phy_ulps_test extends rx_phy_base_test;
    `uvm_component_utils(rx_phy_ulps_test)
    function new(string name = "rx_phy_ulps_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        rx_phy_ulps_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_ulps_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #2us;
        phase.drop_objection(this);
    endtask
endclass

class rx_phy_lpdt_test extends rx_phy_base_test;
    `uvm_component_utils(rx_phy_lpdt_test)
    function new(string name = "rx_phy_lpdt_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        rx_phy_lpdt_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_lpdt_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #2us;
        phase.drop_objection(this);
    endtask
endclass

class rx_phy_trigger_test extends rx_phy_base_test;
    `uvm_component_utils(rx_phy_trigger_test)
    function new(string name = "rx_phy_trigger_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        rx_phy_trigger_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_trigger_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #2us;
        phase.drop_objection(this);
    endtask
endclass

class rx_phy_regress_test extends rx_phy_base_test;
    `uvm_component_utils(rx_phy_regress_test)
    function new(string name = "rx_phy_regress_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        rx_phy_regress_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_regress_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #2us;
        phase.drop_objection(this);
    endtask
endclass

// Inclusive: every HS size 1..16 + ULPS + all four triggers (all supported cases).
class rx_phy_inclusive_test extends rx_phy_base_test;
    `uvm_component_utils(rx_phy_inclusive_test)
    function new(string name = "rx_phy_inclusive_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        rx_phy_inclusive_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_inclusive_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

// Random: 15 randomly-chosen transactions.
class rx_phy_random_test extends rx_phy_base_test;
    `uvm_component_utils(rx_phy_random_test)
    function new(string name = "rx_phy_random_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        rx_phy_random_vseq vseq;
        phase.raise_objection(this);
        vseq = rx_phy_random_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

class loopback_base_test extends uvm_test;
    `uvm_component_utils(loopback_base_test)
    loopback_env env;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = loopback_env::type_id::create("env", this);
    endfunction
endclass

class loopback_hs_test extends loopback_base_test;
    `uvm_component_utils(loopback_hs_test)
    function new(string name = "loopback_hs_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        tx_phy_smoke_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_smoke_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

class loopback_escape_test extends loopback_base_test;
    `uvm_component_utils(loopback_escape_test)
    function new(string name = "loopback_escape_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        tx_phy_escape_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_escape_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5us;
        phase.drop_objection(this);
    endtask
endclass

class loopback_lpdt_test extends loopback_base_test;
    `uvm_component_utils(loopback_lpdt_test)
    function new(string name = "loopback_lpdt_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        tx_phy_lpdt_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_lpdt_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #10us;
        phase.drop_objection(this);
    endtask
endclass

class loopback_regress_test extends loopback_base_test;
    `uvm_component_utils(loopback_regress_test)
    function new(string name = "loopback_regress_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task run_phase(uvm_phase phase);
        tx_phy_regress_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_regress_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #20us;
        phase.drop_objection(this);
    endtask
endclass

class tx_phy_test_base extends uvm_test;
    `uvm_component_utils(tx_phy_test_base)

    tx_phy_env env;

    function new(string name = "tx_phy_test_base", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = tx_phy_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction
endclass

// Integrated smoke: powerup both lanes, hold clock HS, run a data HS burst.
class tx_phy_smoke_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_smoke_test)

    function new(string name = "tx_phy_smoke_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        tx_phy_smoke_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_smoke_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

// Regression: varied HS sizes + ULPS + all triggers (fills coverage).
class tx_phy_regress_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_regress_test)

    function new(string name = "tx_phy_regress_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        tx_phy_regress_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_regress_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

// Escape-only test (ULPS + triggers, no HS) — short and self-contained.
class tx_phy_escape_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_escape_test)

    function new(string name = "tx_phy_escape_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        tx_phy_escape_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_escape_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

// LPDT test (low-power data transmission, no HS).
class tx_phy_lpdt_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_lpdt_test)
    function new(string name = "tx_phy_lpdt_test", uvm_component parent);
        super.new(name, parent);
    endfunction
    task main_phase(uvm_phase phase);
        tx_phy_lpdt_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_lpdt_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

// Inclusive: every HS size 1..16 + ULPS + all four triggers (all supported cases).
class tx_phy_inclusive_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_inclusive_test)

    function new(string name = "tx_phy_inclusive_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        tx_phy_inclusive_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_inclusive_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

// Random: 15 randomly-chosen transactions.
class tx_phy_random_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_random_test)

    function new(string name = "tx_phy_random_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        tx_phy_random_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_random_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

// Powerup-only test.
class tx_phy_powerup_test extends tx_phy_test_base;
    `uvm_component_utils(tx_phy_powerup_test)

    function new(string name = "tx_phy_powerup_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    task main_phase(uvm_phase phase);
        tx_phy_powerup_vseq vseq;
        phase.raise_objection(this);
        vseq = tx_phy_powerup_vseq::type_id::create("vseq");
        vseq.start(env.vseqr);
        #5000;
        phase.drop_objection(this);
    endtask
endclass

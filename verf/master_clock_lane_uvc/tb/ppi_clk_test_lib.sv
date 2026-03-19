class ppi_clk_test_base extends uvm_test;
    `uvm_component_utils(ppi_clk_test_base)
    
    ppi_clk_agent clk_agent;
    ppi_clk_base_seq clk_seq;
    
    function new(string name = "ppi_clk_test_base", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        clk_agent = ppi_clk_agent::type_id::create("clk_agent", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        clk_seq =ppi_clk_base_seq::type_id::create("clk_seq");
        clk_seq.start(clk_agent.clk_seq);
        phase.drop_objection(this);
    endtask
endclass



class ppi_clk_test_en extends ppi_clk_test_base;
    `uvm_component_utils(ppi_clk_test_en)

    function new(string name = "ppi_clk_test_en", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        set_type_override_by_type(ppi_clk_base_seq::get_type(), ppi_clk_en_seq::get_type());
        super.build_phase(phase);
    endfunction
endclass

class ppi_clk_test_hs extends ppi_clk_test_base;
    `uvm_component_utils(ppi_clk_test_hs)

    function new(string name = "ppi_clk_test_hs", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        set_type_override_by_type(ppi_clk_base_seq::get_type(), ppi_clk_hs_seq::get_type());
        super.build_phase(phase);
    endfunction
endclass

class ppi_clk_test_ulps extends ppi_clk_test_base;
    `uvm_component_utils(ppi_clk_test_ulps)

    function new(string name = "ppi_clk_test_ulps", uvm_component parent);
        super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        set_type_override_by_type(ppi_clk_base_seq::get_type(), ppi_clk_ulps_seq::get_type());
        super.build_phase(phase);
    endfunction
endclass

class ppi_clk_test_rand extends ppi_clk_test_base;
    `uvm_component_utils(ppi_clk_test_rand)

    function new(string name = "ppi_clk_test_rand", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        set_type_override_by_type(ppi_clk_base_seq::get_type(), ppi_clk_rand_seq::get_type());
        super.build_phase(phase);
    endfunction
endclass

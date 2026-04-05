class ppi_clk_base_seq extends uvm_sequence #(ppi_clk_tr);
    `uvm_object_utils(ppi_clk_base_seq)
    
    function new(string name = "ppi_clk_base_seq");
        super.new(name);
    endfunction

    virtual task pre_body();
        `uvm_info("CLKSEQ", $sformatf("Starting %s", get_type_name()), UVM_LOW)
    endtask
    
endclass

class ppi_clk_en_seq extends ppi_clk_base_seq;
    `uvm_object_utils(ppi_clk_en_seq)

    function new(string name = "ppi_clk_en_seq");
        super.new(name);
    endfunction

    virtual task body();
        ppi_clk_tr tr;
        tr = ppi_clk_tr::type_id::create("tr");
        tr.transaction_type = LANE_ENABLE;
        start_item(tr);
        finish_item(tr);
    endtask
endclass    


class ppi_clk_hs_seq extends ppi_clk_base_seq;
    `uvm_object_utils(ppi_clk_hs_seq)
    rand ppi_clk_tr tr;
    function new(string name = "ppi_clk_hs_seq");
        super.new(name);
    endfunction

    virtual task body();
        tr = ppi_clk_tr::type_id::create("tr");
        assert(tr.randomize()) else `uvm_fatal("RAND_FAIL", "Failed to randomize HS clock transaction");
        tr.transaction_type = HS_CLK;
        start_item(tr);
        finish_item(tr);
    endtask
endclass

class ppi_clk_ulps_seq extends ppi_clk_base_seq;
    `uvm_object_utils(ppi_clk_ulps_seq)

    function new(string name = "ppi_clk_ulps_seq");
        super.new(name);
    endfunction

    virtual task body();
        ppi_clk_tr tr;
        tr = ppi_clk_tr::type_id::create("tr");
        tr.transaction_type = ULPS_CLK;
        start_item(tr);
        finish_item(tr);
    endtask
endclass


class ppi_clk_rand_seq extends ppi_clk_base_seq;
    `uvm_object_utils(ppi_clk_rand_seq)
    ppi_clk_en_seq en_seq;
    function new(string name = "ppi_clk_rand_seq");
        super.new(name);
    endfunction

    virtual task body();
        ppi_clk_tr tr;
        `uvm_do(en_seq);
        repeat(1000) begin
            `uvm_do_with(tr, {transaction_type inside {HS_CLK, ULPS_CLK};})
        end
    endtask
endclass
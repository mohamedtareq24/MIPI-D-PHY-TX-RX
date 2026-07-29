typedef enum {LANE_EN, HS_CLK, ULPS_CLK} clk_transaction_type_t;
class ppi_clk_tr extends uvm_sequence_item;
    `uvm_object_utils(ppi_clk_tr)
    rand clk_transaction_type_t transaction_type;
    bit stop_state;
    bit ulps_active_n;
    bit ulps_esc;

    rand int unsigned num_hs_active_cycles;
    rand int unsigned num_ulps_active_cycles;

    constraint num_hs_active_cycles_c {
        num_hs_active_cycles > 1;
        num_hs_active_cycles < 1000;
    }

    constraint num_ulps_active_cycles_c {
        num_ulps_active_cycles > 10;
        num_ulps_active_cycles < 100;
    }
    
    function new(string name = "ppi_clk_tr");
        super.new(name);
    endfunction

    function void print_transaction();
        `uvm_info(get_name(), $sformatf("==============================================================================\n"), UVM_LOW)
        `uvm_info(get_name(), $sformatf("Transaction Type: %s, Num HS Active Cycles: %0d, Num ULPS Active Cycles: %0d", transaction_type.name(), num_hs_active_cycles, num_ulps_active_cycles), UVM_LOW)
        `uvm_info(get_name(), $sformatf("==============================================================================\n"), UVM_LOW)
    endfunction

endclass
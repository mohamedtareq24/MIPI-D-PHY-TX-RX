typedef enum {LANE_ENABLE, HS_CLK, ULPS_CLK} clk_transaction_type_t;
class ppi_clk_tr extends uvm_sequence_item;
    `uvm_object_utils(ppi_clk_tr)
    rand clk_transaction_type_t transaction_type;
    rand int ulps_active_delay;
    bit stop_state;
    bit ulps_active_n;
    bit ulps_esc;
    
    function new(string name = "ppi_clk_tr");
        super.new(name);
    endfunction


endclass
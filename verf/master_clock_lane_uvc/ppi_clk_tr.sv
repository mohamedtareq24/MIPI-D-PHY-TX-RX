typedef enum {LANE_ENABLE, HS_CLK, ULPS_CLK} clk_transaction_type_t;
class ppi_clk_tr extends uvm_sequence_item;
    `uvm_object_utils(ppi_clk_tr)
    rand clk_transaction_type_t transaction_type;
    rand int ulps_active_delay;
    bit stop_state;
    bit ulps_active_n;
    bit ulps_esc;
    rand int unsigned num_cycles;
        constraint num_cycles_c {
            num_cycles > 1;
            num_cycles < 1000;
        }
    function new(string name = "ppi_clk_tr");
        super.new(name);
    endfunction


endclass
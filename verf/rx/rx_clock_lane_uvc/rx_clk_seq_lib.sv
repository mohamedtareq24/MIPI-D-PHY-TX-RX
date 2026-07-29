// RX clock-lane sequences: start / stop the received HS clock.
class rx_clk_base_seq extends uvm_sequence #(rx_clk_tr);
    `uvm_object_utils(rx_clk_base_seq)
    function new(string name = "rx_clk_base_seq"); super.new(name); endfunction
endclass

class rx_clk_hs_start_seq extends rx_clk_base_seq;
    `uvm_object_utils(rx_clk_hs_start_seq)
    function new(string name = "rx_clk_hs_start_seq"); super.new(name); endfunction
    virtual task body();
        rx_clk_tr tr = rx_clk_tr::type_id::create("tr");
        start_item(tr);
        tr.cmd = RX_CLK_HS_START;
        finish_item(tr);
    endtask
endclass

class rx_clk_hs_stop_seq extends rx_clk_base_seq;
    `uvm_object_utils(rx_clk_hs_stop_seq)
    function new(string name = "rx_clk_hs_stop_seq"); super.new(name); endfunction
    virtual task body();
        rx_clk_tr tr = rx_clk_tr::type_id::create("tr");
        start_item(tr);
        tr.cmd = RX_CLK_HS_STOP;
        finish_item(tr);
    endtask
endclass

// RX clock-lane transaction: start / stop the received HS clock.
typedef enum { RX_CLK_HS_START, RX_CLK_HS_STOP } rx_clk_cmd_e;

class rx_clk_tr extends uvm_sequence_item;
    rand rx_clk_cmd_e cmd;

    `uvm_object_utils_begin(rx_clk_tr)
        `uvm_field_enum(rx_clk_cmd_e, cmd, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "rx_clk_tr");
        super.new(name);
    endfunction
endclass

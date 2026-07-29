// RX clock-lane agent: driver + sequencer + monitor.
class rx_clk_agent extends uvm_agent;
    `uvm_component_utils(rx_clk_agent)

    rx_clk_driver drv;
    rx_clk_seqncr seqr;
    rx_clk_mon    mon;

    function new(string name = "rx_clk_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = rx_clk_mon::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv  = rx_clk_driver::type_id::create("drv", this);
            seqr = rx_clk_seqncr::type_id::create("seqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

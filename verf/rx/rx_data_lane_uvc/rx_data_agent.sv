// RX data-lane agent: driver + sequencer + monitor.
class rx_data_agent extends uvm_agent;
    `uvm_component_utils(rx_data_agent)

    rx_data_driver drv;
    rx_data_seqncr seqr;
    rx_data_mon    mon;

    function new(string name = "rx_data_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = rx_data_mon::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            drv  = rx_data_driver::type_id::create("drv", this);
            seqr = rx_data_seqncr::type_id::create("seqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction
endclass

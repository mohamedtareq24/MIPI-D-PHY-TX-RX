// Monitor: passively watch the clock-lane PPI (HS-active / recovered byte clock).
class rx_clk_mon extends uvm_monitor;
    `uvm_component_utils(rx_clk_mon)

    virtual rx_clk_ppi_if clk_ppi;
    int unsigned byte_clk_edges;

    function new(string name = "rx_clk_mon", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rx_clk_ppi_if)::get(this, "", "clk_ppi", clk_ppi))
            `uvm_fatal("NOVIF", "clk_ppi not set (clk mon)")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            forever begin
                @(posedge clk_ppi.RxByteClkHS_o);
                byte_clk_edges++;
            end
        join
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("RXCLK", $sformatf("byte-clock edges observed: %0d", byte_clk_edges), UVM_LOW)
    endfunction
endclass

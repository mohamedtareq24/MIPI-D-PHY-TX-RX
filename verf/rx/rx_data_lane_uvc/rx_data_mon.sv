// Monitor: recover HS payload + escape events from the data-lane PPI.
// Uses the clock-lane PPI byte clock (RxByteClkHS) to sample HS bytes.
class rx_data_mon extends uvm_monitor;
    `uvm_component_utils(rx_data_mon)

    virtual rx_clk_ppi_if  clk_ppi;   // read-only: recovered byte clock
    virtual rx_data_ppi_if data_ppi;
    uvm_analysis_port #(rx_data_tr) ap;

    function new(string name = "rx_data_mon", uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rx_clk_ppi_if)::get(this, "", "clk_ppi", clk_ppi))
            `uvm_fatal("NOVIF", "clk_ppi not set (mon)")
        if (!uvm_config_db#(virtual rx_data_ppi_if)::get(this, "", "data_ppi", data_ppi))
            `uvm_fatal("NOVIF", "data_ppi not set (mon)")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            hs_capture();
            ulps_capture();
            trigger_capture();
            lpdt_capture();
        join
    endtask

    // HS payload: collect aligned bytes between RxSyncHS and end of RxActiveHS.
    task hs_capture();
        bit       collecting = 1'b0;
        bit [7:0] bytes[$];
        forever begin
            @(posedge clk_ppi.RxByteClkHS_o);
            if (data_ppi.RxSyncHS_o) begin
                collecting = 1'b1;
                bytes.delete();
            end
            else if (collecting && data_ppi.RxValidHS_o) begin
                bytes.push_back(data_ppi.RxDataHS_o);
            end
            if (collecting && !data_ppi.RxActiveHS_o) begin
                rx_data_tr r = rx_data_tr::type_id::create("rcv_hs");
                r.txn_type     = RX_HS_BURST;
                r.payload      = bytes;
                r.payload_size = bytes.size();
                `uvm_info("HS_RECOVERED", $sformatf("RX recovered HS payload (%0d): %p",
                          bytes.size(), bytes), UVM_LOW)
                ap.write(r);
                collecting = 1'b0;
            end
        end
    endtask

    // ULPS: active-low RxUlpsActiveNot falls on enter, rises on exit.
    task ulps_capture();
        forever begin
            @(negedge data_ppi.RxUlpsActiveNot_o);
            @(posedge data_ppi.RxUlpsActiveNot_o);
            begin
                rx_data_tr r = rx_data_tr::type_id::create("rcv_ulps");
                r.txn_type = RX_ULPS;
                ap.write(r);
            end
        end
    endtask

    // Trigger: one-hot RxTriggerEsc pulses for one refclk on decode.
    task trigger_capture();
        forever begin
            @(data_ppi.RxTriggerEsc_o);
            if (data_ppi.RxTriggerEsc_o != 4'b0) begin
                rx_data_tr r = rx_data_tr::type_id::create("rcv_trgr");
                r.txn_type = RX_TRIGGER;
                r.trgr     = data_ppi.RxTriggerEsc_o;
                ap.write(r);
            end
        end
    endtask

    // LPDT: while RxLpdtEsc_o is high, sample RxDataEsc_o on each RxValidEsc_o
    // strobe (RxClkEsc_o domain); emit one transaction with the byte stream.
    task lpdt_capture();
        bit [7:0] bytes[$];
        forever begin
            @(posedge data_ppi.RxLpdtEsc_o);
            bytes.delete();
            while (data_ppi.RxLpdtEsc_o) begin
                @(posedge data_ppi.RxClkEsc_o or negedge data_ppi.RxLpdtEsc_o);
                if (data_ppi.RxValidEsc_o && data_ppi.RxLpdtEsc_o)
                    bytes.push_back(data_ppi.RxDataEsc_o);
            end
            begin
                rx_data_tr r = rx_data_tr::type_id::create("rcv_lpdt");
                r.txn_type     = RX_LPDT;
                r.lpdt_payload = bytes;
                r.lpdt_size    = bytes.size();
                ap.write(r);
            end
        end
    endtask
endclass

// Functional coverage on RX data-lane transactions (sampled from the driver's
// published stimulus intent). Closure bar for RX scenario richness.
class rx_phy_coverage extends uvm_subscriber #(rx_data_tr);
    `uvm_component_utils(rx_phy_coverage)

    rx_data_tr tr;

    covergroup data_cg;
        option.per_instance = 1;

        // Transaction kinds exercised.
        cp_type : coverpoint tr.txn_type;

        // HS payload size bins (HS bursts only).
        cp_size : coverpoint tr.payload_size iff (tr.txn_type == RX_HS_BURST) {
            bins one     = {1};
            bins two     = {2};
            bins sz_3_8  = {[3:8]};
            bins sz_9_16 = {[9:16]};
        }

        // Remote trigger commands (one-hot), for trigger transactions.
        cp_trgr : coverpoint tr.trgr iff (tr.txn_type == RX_TRIGGER) {
            bins rst    = {4'b0001};
            bins hstest = {4'b0010};
            bins unk4   = {4'b0100};
            bins unk5   = {4'b1000};
        }

        // LPDT payload size bins (LPDT transactions only).
        cp_lpdt_size : coverpoint tr.lpdt_size iff (tr.txn_type == RX_LPDT) {
            bins one  = {1};
            bins few  = {[2:4]};
            bins many = {[5:8]};
        }

        // Scenario sequencing: back-to-back bursts, burst-after-ULPS, trigger
        // after a burst (transition bins on the transaction stream).
        cp_seq : coverpoint tr.txn_type {
            bins hs_back2back  = (RX_HS_BURST => RX_HS_BURST);
            bins hs_after_ulps = (RX_ULPS     => RX_HS_BURST);
            bins trig_after_hs = (RX_HS_BURST => RX_TRIGGER);
            bins ulps_after_hs = (RX_HS_BURST => RX_ULPS);
        }
    endgroup

    function new(string name = "rx_phy_coverage", uvm_component parent);
        super.new(name, parent);
        data_cg = new();
    endfunction

    function void write(rx_data_tr t);
        tr = t;
        data_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("data_cg coverage = %.1f%%", data_cg.get_coverage()), UVM_NONE)
    endfunction
endclass

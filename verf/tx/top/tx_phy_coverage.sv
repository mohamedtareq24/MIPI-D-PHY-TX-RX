// Functional coverage on data-lane transactions (sampled from the driver).
class tx_phy_coverage extends uvm_subscriber #(ppi_tx_data_tr);
    `uvm_component_utils(tx_phy_coverage)

    ppi_tx_data_tr tr;

    covergroup data_cg;
        option.per_instance = 1;

        // Transaction kinds exercised.
        cp_type : coverpoint tr.transaction_type;

        // HS payload size bins (meaningful for HS bursts).
        cp_size : coverpoint tr.payload_size iff (tr.transaction_type == HS_DATA) {
            bins one    = {1};
            bins two    = {2};
            bins sz_3_8 = {[3:8]};
            bins sz_9_16= {[9:16]};
        }

        // Escape trigger commands (one-hot), for trigger transactions.
        cp_trgr : coverpoint tr.trgr_type iff (tr.transaction_type == TRGR_DATA) {
            bins rst    = {4'b0001};
            bins hstest = {4'b0010};
            bins unk4   = {4'b0100};
            bins unk5   = {4'b1000};
        }

        // LPDT payload size bins.
        cp_lpdt_size : coverpoint tr.lpdt_size iff (tr.transaction_type == LPDT_DATA) {
            bins one    = {1};
            bins few    = {[2:4]};
            bins many   = {[5:8]};
        }
    endgroup

    function new(string name = "tx_phy_coverage", uvm_component parent);
        super.new(name, parent);
        data_cg = new();
    endfunction

    function void write(ppi_tx_data_tr t);
        tr = t;
        data_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("data_cg coverage = %.1f%%", data_cg.get_coverage()), UVM_NONE)
    endfunction
endclass

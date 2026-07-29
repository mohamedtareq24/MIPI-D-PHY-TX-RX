// Loopback scoreboard: compares the TX driver's intended transaction stream
// (expected) against the RX monitor's recovered stream (actual), in order.
// Data lane only; the clock lane is verified implicitly (no HS carrier => no
// recovered HS bytes => mismatch here).
`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class loopback_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(loopback_scoreboard)

    uvm_analysis_imp_exp #(ppi_tx_data_tr, loopback_scoreboard) tx_data_exp;
    uvm_analysis_imp_act #(rx_data_tr,     loopback_scoreboard) rx_data_act;

    ppi_tx_data_tr exp_q[$];
    rx_data_tr     act_q[$];
    int unsigned   n_match;
    int unsigned   n_mismatch;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        tx_data_exp = new("tx_data_exp", this);
        rx_data_act = new("rx_data_act", this);
    endfunction

    // Expected: drop powerup (LANE_EN) — it produces no recovered RX txn.
    // LANE_EN is exported by BOTH ppi_clk_pkg and ppi_data_pkg, so qualify it.
    function void write_exp(ppi_tx_data_tr t);
        if (t.transaction_type == ppi_data_pkg::LANE_EN) return;
        exp_q.push_back(t);
        try_compare();
    endfunction

    function void write_act(rx_data_tr r);
        act_q.push_back(r);
        try_compare();
    endfunction

    function void try_compare();
        while (exp_q.size() > 0 && act_q.size() > 0) begin
            ppi_tx_data_tr e = exp_q.pop_front();
            rx_data_tr     a = act_q.pop_front();
            compare_one(e, a);
        end
    endfunction

    function void compare_one(ppi_tx_data_tr e, rx_data_tr a);
        bit ok = 1'b1;
        case (e.transaction_type)
            HS_DATA: begin
                // The RX D-PHY legitimately emits trailing HS-Trail "flush" bytes
                // after the payload (the line stays in HS during TX trail until LP
                // is detected). The canonical RX scoreboard (verf/rx/top/
                // rx_phy_scoreboard.sv) handles this with size() >= expected and a
                // leading-prefix compare; mirror that contract here.
                ok = (a.txn_type == RX_HS_BURST) &&
                     (a.payload.size() >= e.payload.size());
                if (ok)
                    foreach (e.payload[i])
                        if (a.payload[i] !== e.payload[i]) ok = 0;
                if (!ok)
                    `uvm_error("LB_HS", $sformatf("HS payload mismatch: exp(%0d)=%p got kind=%s (%0d)=%p",
                              e.payload.size(), e.payload, a.txn_type.name(), a.payload.size(), a.payload))
            end
            LPDT_DATA: begin
                ok = (a.txn_type == RX_LPDT) &&
                     (a.lpdt_payload.size() == e.lpdt_payload.size());
                if (ok)
                    foreach (e.lpdt_payload[i])
                        if (a.lpdt_payload[i] !== e.lpdt_payload[i]) ok = 0;
                if (!ok)
                    `uvm_error("LB_LPDT", $sformatf("LPDT payload mismatch: exp(%0d)=%p got kind=%s (%0d)=%p",
                              e.lpdt_payload.size(), e.lpdt_payload, a.txn_type.name(), a.lpdt_payload.size(), a.lpdt_payload))
            end
            ULPS_DATA: begin
                ok = (a.txn_type == RX_ULPS);
                if (!ok)
                    `uvm_error("LB_ULPS", $sformatf("ULPS expected, got kind=%s", a.txn_type.name()))
            end
            TRGR_DATA: begin
                ok = (a.txn_type == RX_TRIGGER) && (a.trgr === e.trgr_type);
                if (!ok)
                    `uvm_error("LB_TRGR", $sformatf("Trigger mismatch: exp one-hot=%b got kind=%s trgr=%b",
                              e.trgr_type, a.txn_type.name(), a.trgr))
            end
            default: begin
                ok = 0;
                `uvm_error("LB_TYPE", $sformatf("Unexpected expected txn type %s", e.transaction_type.name()))
            end
        endcase
        if (ok) n_match++; else n_mismatch++;
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (exp_q.size() != 0 || act_q.size() != 0)
            `uvm_error("LB_LEFTOVER", $sformatf("Unmatched leftovers: exp_q=%0d act_q=%0d",
                      exp_q.size(), act_q.size()))
        if (n_match == 0 && n_mismatch == 0)
            `uvm_warning("LB_EMPTY", "Loopback scoreboard saw no transactions")
        `uvm_info("LB_SUMMARY", $sformatf("%0d matched, %0d mismatched", n_match, n_mismatch),
                  UVM_LOW)
    endfunction
endclass

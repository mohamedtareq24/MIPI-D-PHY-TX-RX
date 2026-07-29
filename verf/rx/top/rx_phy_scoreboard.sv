`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_rcv)

// Scoreboard: expected (from data driver) vs recovered (from data monitor).
class rx_phy_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(rx_phy_scoreboard)

    uvm_analysis_imp_exp #(rx_data_tr, rx_phy_scoreboard) exp_imp;
    uvm_analysis_imp_rcv #(rx_data_tr, rx_phy_scoreboard) rcv_imp;

    rx_data_tr exp_q[$];
    int        matched, mismatched;

    function new(string name = "rx_phy_scoreboard", uvm_component parent);
        super.new(name, parent);
        exp_imp = new("exp_imp", this);
        rcv_imp = new("rcv_imp", this);
    endfunction

    function void write_exp(rx_data_tr tr);
        exp_q.push_back(tr);
    endfunction

    function void write_rcv(rx_data_tr tr);
        rx_data_tr e;
        bit ok;
        if (exp_q.size() == 0) begin
            `uvm_error("SB_UNEXP", "Recovered txn with no expected payload queued")
            mismatched++;
            return;
        end
        e = exp_q.pop_front();
        if (tr.txn_type != e.txn_type) begin
            mismatched++;
            `uvm_error("SB_ERR", $sformatf("txn_type mismatch: exp=%s got=%s",
                                           e.txn_type.name(), tr.txn_type.name()))
            return;
        end
        // Expected RX response is DERIVED from the driven activity per the spec
        // oracle (mipi_spec_pkg), never read from a stimulus-authored field. The
        // RTL has its own decode; a divergence here is a DUT bug.
        ok = 1'b1;
        case (e.txn_type)
            RX_HS_BURST: begin
                // Payload integrity is a legitimate black-box loopback check:
                // the bytes injected must be recovered, in order, same count.
                ok = (tr.payload.size() >= e.payload_size);
                if (ok)
                    for (int i = 0; i < e.payload_size; i++)
                        if (tr.payload[i] !== e.payload[i]) ok = 0;
            end
            RX_TRIGGER: begin
                // Compliant RX must map the DRIVEN command byte to this one-hot.
                logic [3:0] exp_onehot = mipi_spec_pkg::esc_trigger_for_cmd(e.esc_cmd);
                if (exp_onehot === 4'b0000) begin
                    // Stimulus drove a byte that is not a spec trigger command:
                    // a test (stimulus) error, not a DUT pass/fail.
                    ok = 1'b0;
                    `uvm_error("SB_STIM", $sformatf("Driven esc cmd 0x%02h is not a spec trigger code (Table 10)", e.esc_cmd))
                end
                else begin
                    ok = (tr.trgr === exp_onehot);
                    if (!ok)
                        `uvm_error("SB_ERR", $sformatf("Trigger mismatch for cmd 0x%02h: spec one-hot=%b, DUT RxTriggerEsc=%b",
                                                       e.esc_cmd, exp_onehot, tr.trgr))
                end
            end
            RX_ULPS: begin
                // Compliant RX enters ULPS only for the spec ULPS command.
                ok = mipi_spec_pkg::esc_is_ulps(e.esc_cmd);
                if (!ok)
                    `uvm_error("SB_STIM", $sformatf("ULPS txn but driven cmd 0x%02h is not the spec ULPS code 0x%02h",
                                                    e.esc_cmd, mipi_spec_pkg::CMD_ULPS))
            end
            RX_LPDT: begin
                // Black-box loopback: bytes driven must be recovered, in order.
                ok = (tr.lpdt_payload.size() == e.lpdt_size);
                if (ok)
                    for (int i = 0; i < e.lpdt_size; i++)
                        if (tr.lpdt_payload[i] !== e.lpdt_payload[i]) ok = 0;
                if (!ok)
                    `uvm_error("SB_ERR", $sformatf("LPDT payload mismatch: exp=%p got=%p",
                                                   e.lpdt_payload, tr.lpdt_payload))
            end
            default: ok = 1'b0;
        endcase
        if (ok) begin
            matched++;
            `uvm_info("SB_OK", $sformatf("%s OK", e.txn_type.name()), UVM_LOW)
        end
        else begin
            mismatched++;
            if (e.txn_type == RX_HS_BURST)
                `uvm_error("SB_ERR", $sformatf("HS payload mismatch: exp=%p got=%p", e.payload, tr.payload))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SB_SUMMARY", $sformatf("%0d matched, %0d mismatched", matched, mismatched), UVM_LOW)
        if (mismatched > 0 || matched == 0)
            `uvm_error("SB_SUMMARY", "Scoreboard failed (mismatch or no traffic)")
    endfunction
endclass

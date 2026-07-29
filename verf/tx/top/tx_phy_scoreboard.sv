`uvm_analysis_imp_decl(_inj)
`uvm_analysis_imp_decl(_rec)
`uvm_analysis_imp_decl(_escrec)

// HS payload integrity scoreboard. Pairs each injected burst (payload bytes
// sampled on the PPI by the data monitor) with the bytes recovered off the
// serial line by the recovery monitor, and checks SoT + payload.
class tx_phy_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(tx_phy_scoreboard)

    uvm_analysis_imp_inj    #(ppi_tx_data_tr, tx_phy_scoreboard) inj_imp;
    uvm_analysis_imp_rec    #(ppi_tx_data_tr, tx_phy_scoreboard) rec_imp;
    uvm_analysis_imp_escrec #(ppi_tx_data_tr, tx_phy_scoreboard) escrec_imp;

    ppi_tx_data_tr inj_q[$];
    ppi_tx_data_tr rec_q[$];
    ppi_tx_data_tr esc_inj_q[$];   // injected ULPS/TRGR (expected, golden = Table 10)
    ppi_tx_data_tr esc_rec_q[$];   // escape command bytes decoded off the LP lines

    int n_match;
    int n_mismatch;
    int n_esc_match;
    int n_esc_mismatch;

    // Golden SoT leader; from the shared spec oracle (mipi_spec_pkg, spec §1.1).
    localparam byte unsigned SOT = mipi_spec_pkg::SOT_LEADER;

    function new(string name = "tx_phy_scoreboard", uvm_component parent);
        super.new(name, parent);
        n_match        = 0;
        n_mismatch     = 0;
        n_esc_match    = 0;
        n_esc_mismatch = 0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        inj_imp    = new("inj_imp", this);
        rec_imp    = new("rec_imp", this);
        escrec_imp = new("escrec_imp", this);
    endfunction

    // From the data driver: injected transaction (expected). HS bursts are checked
    // against the serial line; ULPS/TRGR escape commands against the LP lines.
    function void write_inj(ppi_tx_data_tr tr);
        case (tr.transaction_type)
            HS_DATA:   begin inj_q.push_back(tr);     try_compare();     end
            ULPS_DATA,
            TRGR_DATA,
            LPDT_DATA: begin esc_inj_q.push_back(tr); try_compare_esc(); end
            default:   ; // LANE_EN etc.: nothing to check
        endcase
    endfunction

    // From the escape recovery monitor: command byte decoded off the LP lines.
    function void write_escrec(ppi_tx_data_tr tr);
        esc_rec_q.push_back(tr);
        try_compare_esc();
    endfunction

    // Golden expected escape command for an injected transaction, derived from
    // the shared spec oracle (mipi_spec_pkg, spec §2.2). For triggers the
    // one-hot intent maps to the command byte a compliant TX must transmit.
    function byte unsigned expected_esc(ppi_tx_data_tr inj);
        if (inj.transaction_type == ULPS_DATA) return mipi_spec_pkg::CMD_ULPS;
        return mipi_spec_pkg::esc_cmd_for_trigger(inj.trgr_type);  // TRGR_DATA
    endfunction

    function void try_compare_esc();
        while (esc_inj_q.size() > 0 && esc_rec_q.size() > 0) begin
            ppi_tx_data_tr inj = esc_inj_q.pop_front();
            ppi_tx_data_tr rec = esc_rec_q.pop_front();
            if (inj.transaction_type == LPDT_DATA) begin
                bit ok = (rec.recovered_payload.size() == inj.lpdt_payload.size());
                if (ok)
                    foreach (inj.lpdt_payload[i])
                        if (rec.recovered_payload[i] !== inj.lpdt_payload[i]) ok = 0;
                if (ok) begin
                    n_esc_match++;
                    `uvm_info("SB_LPDT_OK", $sformatf("LPDT payload OK: %0d bytes", inj.lpdt_payload.size()), UVM_LOW)
                end
                else begin
                    n_esc_mismatch++;
                    `uvm_error("SB_LPDT", $sformatf("LPDT payload mismatch: exp=%p got=%p",
                              inj.lpdt_payload, rec.recovered_payload))
                end
            end
            else begin
                byte unsigned exp = expected_esc(inj);
                if (rec.recovered_esc_cmd === exp) begin
                    n_esc_match++;
                    `uvm_info("SB_ESC_OK", $sformatf("%s escape command OK: 0x%02h",
                              inj.transaction_type.name(), exp), UVM_LOW)
                end
                else begin
                    n_esc_mismatch++;
                    `uvm_error("SB_ESC", $sformatf("%s escape command mismatch: spec=0x%02h, transmitted=0x%02h",
                              inj.transaction_type.name(), exp, rec.recovered_esc_cmd))
                end
            end
        end
    endfunction

    // From the recovery monitor: bytes off the serial line (actual).
    function void write_rec(ppi_tx_data_tr tr);
        rec_q.push_back(tr);
        try_compare();
    endfunction

    function void try_compare();
        while (inj_q.size() > 0 && rec_q.size() > 0) begin
            ppi_tx_data_tr inj = inj_q.pop_front();
            ppi_tx_data_tr rec = rec_q.pop_front();
            check_burst(inj, rec);
        end
    endfunction

    // Assemble a byte LSB-first from the recovered bit stream at bit offset k
    // (MIPI D-PHY: the first bit transmitted is the LSB). bits[k] is the LSB.
    function byte unsigned get_byte(ref bit bits[$], input int k);
        byte unsigned b = 0;
        for (int j = 0; j < 8; j++)
            b[j] = bits[k + j];
        return b;
    endfunction

    // True iff the injected payload appears byte-aligned starting at bit offset k.
    function bit payload_matches_at(ref bit bits[$], input int k, ppi_tx_data_tr inj);
        foreach (inj.payload[i])
            if (get_byte(bits, k + i*8) !== inj.payload[i]) return 0;
        return 1;
    endfunction

    function void check_burst(ppi_tx_data_tr inj, ppi_tx_data_tr rec);
        int nbits = rec.recovered_bits.size();
        int sot_k = -1;
        int pay_k;

        // Documentation-compliant framing (mirrors a spec receiver): first sync on
        // the SoT Leader (Table 28 = 0xB8 LSB-first), then take the payload as the
        // bytes immediately following it. Decoding the Leader at all proves the
        // serializer bit order is correct.
        for (int k = 0; k + 8 <= nbits; k++) begin
            if (get_byte(rec.recovered_bits, k) === SOT) begin
                sot_k = k;
                break;
            end
        end
        if (sot_k < 0) begin
            n_mismatch++;
            `uvm_error("SB_SOT", $sformatf("SoT Leader 0x%02h (00011101 LSB-first) not found in %0d recovered bits",
                                           SOT, nbits))
            return;
        end

        pay_k = sot_k + 8;
        if (pay_k + inj.payload.size() * 8 > nbits) begin
            n_mismatch++;
            `uvm_error("SB_DATA", $sformatf("Only %0d bits after SoT; need %0d for %0d payload bytes",
                                            nbits - pay_k, inj.payload.size() * 8, inj.payload.size()))
            return;
        end

        if (payload_matches_at(rec.recovered_bits, pay_k, inj)) begin
            n_match++;
            `uvm_info("SB_OK", $sformatf("Burst OK: SoT=0x%02h + %0d payload bytes recovered intact",
                                         SOT, inj.payload.size()), UVM_LOW)
        end
        else begin
            byte unsigned got [$];
            foreach (inj.payload[i]) got.push_back(get_byte(rec.recovered_bits, pay_k + i*8));
            n_mismatch++;
            `uvm_error("SB_DATA", $sformatf("Payload mismatch after SoT: exp=%p got=%p", inj.payload, got))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        if (n_match == 0 && n_mismatch == 0)
            `uvm_warning("SB_EMPTY", "Scoreboard saw no paired HS bursts")
        else
            `uvm_info("SB_SUMMARY", $sformatf("HS bursts: %0d matched, %0d mismatched", n_match, n_mismatch), UVM_NONE)
        `uvm_info("SB_SUMMARY", $sformatf("Escape commands: %0d matched, %0d mismatched",
                  n_esc_match, n_esc_mismatch), UVM_NONE)
        if (n_mismatch > 0)
            `uvm_error("SB_FAIL", $sformatf("%0d HS burst(s) mismatched", n_mismatch))
        if (n_esc_mismatch > 0)
            `uvm_error("SB_FAIL", $sformatf("%0d escape command(s) mismatched", n_esc_mismatch))
    endfunction
endclass

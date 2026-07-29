// Recovers transmitted HS bytes by deserializing the serial line. The serializer
// shifts LSB-first (MIPI D-PHY: first bit transmitted is the LSB); byte framing
// and LSB-first assembly are done in the scoreboard. One transaction is emitted
// per burst (delimited by serializer enable) carrying the raw recovered bits.
class tx_phy_hs_recover_mon extends uvm_monitor;
    `uvm_component_utils(tx_phy_hs_recover_mon)

    virtual hs_line_if  vif;
    virtual esc_line_if esc_vif;
    uvm_analysis_port #(ppi_tx_data_tr) analysis_port;  // HS bytes
    uvm_analysis_port #(ppi_tx_data_tr) esc_port;       // recovered escape command

    function new(string name = "tx_phy_hs_recover_mon", uvm_component parent);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
        esc_port      = new("esc_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual hs_line_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "hs_line_if vif not set for recovery monitor")
        if (!uvm_config_db#(virtual esc_line_if)::get(this, "", "esc_vif", esc_vif))
            `uvm_fatal("NOVIF", "esc_line_if esc_vif not set for recovery monitor")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            hs_capture();
            esc_capture();
        join
    endtask

    // ---- HS serial-line recovery ----
    task hs_capture();
        ppi_tx_data_tr tr;
        bit            active;

        active = 0;
        // Sample mid-bit (negedge) so the registered line value is stable.
        // Collect the raw bit stream; byte framing is resolved in the scoreboard
        // by searching for the SoT marker (avoids modeling the serializer's
        // internal 2-FF byte-clock synchronization here).
        forever @(negedge vif.bitclk) begin
            if (vif.en !== 1'b1) begin
                if (active) begin
                    analysis_port.write(tr);
                    active = 0;
                end
                continue;
            end
            if (!active) begin
                tr = ppi_tx_data_tr::type_id::create("rec_tr");
                tr.transaction_type = HS_DATA;
                active = 1;
            end
            tr.recovered_bits.push_back(vif.serial);
        end
    endtask

    // ---- Escape Entry Command recovery (LP lines, Esc-clock domain) ----
    // Decodes the spaced-one-hot stream exactly as the spec defines the receive
    // side: entry Mark-1, Space, HS-req(Space-One), Space, then 8 command symbols
    // each followed by a Space. Mark-1(10)=1, Space-One(01)=0. The command byte is
    // assembled MSB-first (first symbol = MSB) to match spec Table 10 literals.
    task esc_capture();
        typedef enum { E_IDLE, E_E1, E_E2, E_E3, E_CMD, E_LPDT, E_DONE } es_state_e;
        es_state_e  st;
        logic [1:0] code, prev;
        logic [7:0] shft;
        int         cnt;
        ppi_tx_data_tr lpdt_e;
        logic [7:0]    pshft;
        int            pcnt;
        logic          parmed;  // payload bit armed by an in-state Space->Mark leading edge

        st   = E_IDLE;
        prev = LP_STOP;   // Stop
        shft = '0;
        cnt  = 0;
        forever @(posedge esc_vif.escclk) begin
            code = {esc_vif.lp_p, esc_vif.lp_n};
            case (st)
                E_IDLE: if (code == LP_MARK1) st = E_E1;                 // Mark-1
                E_E1:   if      (code == LP_SPACE) st = E_E2;            // Space
                        else if (code == LP_STOP) st = E_IDLE;
                E_E2:   if      (code == LP_HSREQ) st = E_E3;            // HS-req
                        else if (code == LP_STOP) st = E_IDLE;
                E_E3:   if      (code == LP_SPACE) begin st = E_CMD; cnt = 0; shft = '0; end
                        else if (code == LP_STOP) st = E_IDLE;
                E_CMD: begin
                    if ((prev == LP_SPACE) && (code == LP_HSREQ || code == LP_MARK1)) begin
                        shft = {shft[6:0], (code == LP_MARK1)};
                        cnt++;
                        if (cnt == 8) begin
                            ppi_tx_data_tr e = ppi_tx_data_tr::type_id::create("esc_rec");
                            e.recovered_esc_cmd = shft;
                            if (shft == mipi_spec_pkg::CMD_LPDT) begin
                                e.transaction_type = LPDT_DATA;
                                lpdt_e = e;            // hold; fill payload below
                                st     = E_LPDT;
                                pcnt   = 0;
                                pshft  = '0;
                                parmed = 1'b0;
                            end
                            else begin
                                esc_port.write(e);
                                // The trigger command repeats while TxRequestEsc is held;
                                // wait for the burst to end (Stop) before re-arming so
                                // exactly one command is reported per escape burst.
                                st = E_DONE;
                            end
                        end
                    end
                    else if (code == LP_STOP) st = E_IDLE;             // aborted
                end
                E_LPDT: begin
                    // Payload bit: armed by its own in-state Space->Mark leading edge,
                    // VALUE decoded on the following Mark->Space trailing edge (LSB-first:
                    // shift right, insert at MSB). The armed gate mirrors the RX
                    // LP_LPDT_RX FSM: the command's residual last Mark had its leading
                    // edge back in E_CMD, so it is never armed here and its trailing
                    // Space is not counted. Exit Mark-1 (followed by Stop, not Space) is
                    // never counted. Stop ends LPDT.
                    if (code == LP_STOP) begin
                        esc_port.write(lpdt_e);   // publish whatever bytes completed
                        st = E_IDLE;
                    end
                    else if ((prev == LP_SPACE) && (code == LP_MARK1 || code == LP_HSREQ)) begin
                        parmed = 1'b1;            // leading edge into a payload Mark
                    end
                    else if (parmed && (prev == LP_MARK1 || prev == LP_HSREQ) && (code == LP_SPACE)) begin
                        parmed = 1'b0;
                        pshft = {(prev == LP_MARK1), pshft[7:1]};
                        if (pcnt == 7) begin
                            lpdt_e.recovered_payload.push_back(pshft);
                            pcnt = 0;
                        end
                        else pcnt++;
                    end
                end
                E_DONE: if (code == LP_STOP) st = E_IDLE;              // burst ended (Stop)
                default: st = E_IDLE;
            endcase
            prev = code;
        end
    endtask
endclass

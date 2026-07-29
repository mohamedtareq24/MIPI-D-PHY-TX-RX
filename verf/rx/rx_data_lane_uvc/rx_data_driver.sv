// Driver: owns the data-lane pad + data-lane PPI enables.
// HS bits are timed to the clk_HS edges produced by the rx_clock_lane_uvc: the
// clock free-runs and this driver places each bit on the falling edge so it is
// stable for the next sampling (rising) edge in the analog deserializer.
class rx_data_driver extends uvm_driver #(rx_data_tr);
    `uvm_component_utils(rx_data_driver)

    virtual rx_data_ppi_if   data_ppi;
    virtual rx_data_d_phy_if data_pad;
    virtual rx_clk_d_phy_if  clk_pad;   // read-only: sync HS bits to clk_HS

    uvm_analysis_port #(rx_data_tr) ap;  // publishes sent payload (expected)

    localparam time T_LP   = 100ns;      // LP state hold
    localparam logic [7:0] SOT = 8'hB8;

    function new(string name = "rx_data_driver", uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rx_data_ppi_if)::get(this, "", "data_ppi", data_ppi))
            `uvm_fatal("NOVIF", "data_ppi not set")
        if (!uvm_config_db#(virtual rx_data_d_phy_if)::get(this, "", "data_pad", data_pad))
            `uvm_fatal("NOVIF", "data_pad not set")
        if (!uvm_config_db#(virtual rx_clk_d_phy_if)::get(this, "", "clk_pad", clk_pad))
            `uvm_fatal("NOVIF", "clk_pad not set")
    endfunction

    task run_phase(uvm_phase phase);
        idle();
        phy_enable();
        forever begin
            seq_item_port.get_next_item(req);
            publish(req);            // queue expected before the monitor can recover it
            send_to_dut(req);
            seq_item_port.item_done();
        end
    endtask

    task idle();
        data_pad.data_LP_Dp_i = 1'b1; data_pad.data_LP_Dn_i = 1'b1;  // LP-11 Stop
        data_pad.data_HS_Dp_i = 1'b0; data_pad.data_HS_Dn_i = 1'b0;
        data_ppi.Enable_i     = 1'b0; data_ppi.Shutdownz_i  = 1'b0;
    endtask

    task phy_enable();
        #T_LP;
        data_ppi.Shutdownz_i = 1'b1;
        data_ppi.Enable_i    = 1'b1;
        #T_LP;
    endtask

    // Place one HS bit, timed to the (free-running) clk_HS so it is stable for
    // the next sampling (rising) edge in the analog deserializer.
    task send_bit(bit b);
        @(negedge clk_pad.clk_HS_Dp_i);
        data_pad.data_HS_Dp_i = b;
        data_pad.data_HS_Dn_i = ~b;
    endtask

    task send_byte_lsb(bit [7:0] v);
        for (int i = 0; i < 8; i++) send_bit(v[i]);   // LSB-first (MIPI order)
    endtask

    task send_to_dut(rx_data_tr tr);
        case (tr.txn_type)
            RX_HS_BURST: drive_hs_burst(tr);
            RX_ULPS:     drive_ulps();
            RX_TRIGGER:  drive_trigger(tr.esc_cmd);
            RX_LPDT:     drive_lpdt(tr);
        endcase
    endtask

    // ---- Escape signalling on the data lane LP lines (refclk domain) ----
    task data_lp(bit p, bit n);
        data_pad.data_LP_Dp_i = p; data_pad.data_LP_Dn_i = n; #T_LP;
    endtask

    // Escape entry: Mark-1 -> Space -> HS-request -> Space.
    task esc_entry();
        data_lp(1'b1, 1'b0);   // LP-10 Mark-1
        data_lp(1'b0, 1'b0);   // LP-00 Space
        data_lp(1'b0, 1'b1);   // LP-01 HS-request
        data_lp(1'b0, 1'b0);   // LP-00 Space -> enter command phase
    endtask

    // One spaced-one-hot symbol: 1->Mark(LP-10), 0->HS-req(LP-01), then a Space.
    task esc_symbol(bit b);
        if (b) data_lp(1'b1, 1'b0);
        else   data_lp(1'b0, 1'b1);
        data_lp(1'b0, 1'b0);
    endtask

    task send_esc_cmd(bit [7:0] cmd);
        for (int i = 7; i >= 0; i--) esc_symbol(cmd[i]);   // MSB-first (spec Table 10)
    endtask

    task drive_ulps();
        esc_entry();
        send_esc_cmd(RX_CMD_ULPS);
        repeat (4) data_lp(1'b0, 1'b0);   // ULPS active hold (Space)
        data_lp(1'b1, 1'b0);              // Mark-1 -> ULPS exit
        data_lp(1'b1, 1'b1);              // Stop
        #T_LP;
    endtask

    task drive_trigger(bit [7:0] cmd);
        esc_entry();
        send_esc_cmd(cmd);
        data_lp(1'b1, 1'b1);              // Stop (leave escape)
        #T_LP;
    endtask

    // Drive a full LPDT burst: entry, 0xE1 command (MSB-first), payload bytes
    // (LSB-first, spaced-one-hot), then Mark-1 -> Stop exit.
    task drive_lpdt(rx_data_tr tr);
        esc_entry();
        send_esc_cmd(RX_CMD_LPDT);                  // 0xE1, MSB-first
        foreach (tr.lpdt_payload[i])
            for (int b = 0; b < 8; b++)
                esc_symbol(tr.lpdt_payload[i][b]);  // LSB-first: bit0 first
        data_lp(1'b1, 1'b0);                        // Mark-1 (exit flag)
        data_lp(1'b1, 1'b1);                        // Stop -> leave escape
        #T_LP;
    endtask

    // HS burst. The clock lane is started by the virtual sequence beforehand and
    // stopped afterwards; here we only drive the data-lane LP framing and the HS
    // bitstream, then hold data in Stop while the clock drains.
    task drive_hs_burst(rx_data_tr tr);
        // ---- data lane -> HS arm ----
        data_pad.data_LP_Dp_i = 1'b0; data_pad.data_LP_Dn_i = 1'b1; #T_LP; // LP-01
        data_pad.data_LP_Dp_i = 1'b0; data_pad.data_LP_Dn_i = 1'b0; #T_LP; // LP-00 -> HS arm

        // ---- HS bitstream: preamble (sync search) + SoT + payload + flush ----
        for (int i = 0; i < 4; i++) send_byte_lsb(8'h00);   // preamble
        send_byte_lsb(SOT);                                 // 0xB8 sync
        foreach (tr.payload[i]) send_byte_lsb(tr.payload[i]);
        for (int i = 0; i < 2; i++) send_byte_lsb(8'h00);   // flush window/byte path

        // ---- data lane back to Stop (clock lane HS still running) ----
        data_pad.data_HS_Dp_i = 1'b0; data_pad.data_HS_Dn_i = 1'b0;
        data_pad.data_LP_Dp_i = 1'b1; data_pad.data_LP_Dn_i = 1'b1;
        // Let the byte-clock domain drain (clock still toggling) so RxActiveHS
        // can deassert before the clock lane is stopped.
        repeat (48) @(negedge clk_pad.clk_HS_Dp_i);
    endtask

    task publish(rx_data_tr tr);
        rx_data_tr e = rx_data_tr::type_id::create("exp");
        e.txn_type     = tr.txn_type;
        e.payload_size = tr.payload_size;
        e.payload      = tr.payload;
        e.esc_cmd      = tr.esc_cmd;
        e.trgr         = tr.trgr;
        e.lpdt_size    = tr.lpdt_size;
        e.lpdt_payload = tr.lpdt_payload;
        ap.write(e);
    endtask
endclass

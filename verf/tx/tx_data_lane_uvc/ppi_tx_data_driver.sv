class ppi_tx_data_driver extends uvm_driver #(ppi_tx_data_tr);
    `uvm_component_utils(ppi_tx_data_driver)

    // DUT data-lane PPI (driven) and clock-lane PPI (read-only, for HS byte clock).
    virtual tx_data_ppi_if data_vif;
    virtual tx_clk_ppi_if  clk_vif;

    // Publishes exactly what was injected (authoritative expected for the scoreboard).
    uvm_analysis_port #(ppi_tx_data_tr) ap;

    function new(string name = "ppi_tx_data_driver", uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual tx_data_ppi_if)::get(this, "", "data_vif", data_vif))
            `uvm_fatal("NOVIF", "data_vif (tx_data_ppi_if) not set for data driver")
        if (!uvm_config_db#(virtual tx_clk_ppi_if)::get(this, "", "clk_vif", clk_vif))
            `uvm_fatal("NOVIF", "clk_vif (tx_clk_ppi_if) not set for data driver")
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Idle defaults
        data_vif.TxRequestHS_i        <= 0;
        data_vif.TxDataHS_i           <= '0;
        data_vif.TxDataWidthHS_i      <= '0;
        data_vif.TxWordValidHS_i      <= '0;
        data_vif.TxDataTransferEnHS_i <= 0;
        data_vif.TxRequestEsc_i       <= 0;
        data_vif.TxTriggerEsc_i       <= '0;
        data_vif.TxUlpsEsc_i          <= 0;
        data_vif.TxUlpsExit_i         <= 0;
        data_vif.TxLpdtEsc_i  <= 0;
        data_vif.TxDataEsc_i  <= '0;
        data_vif.TxValidEsc_i <= 0;
        data_vif.enable_i              <= 0;
        data_vif.ForceTXStopmode_i     <= 0;
        forever begin
            seq_item_port.get_next_item(req);
            send_to_dut(req);
            seq_item_port.item_done();
        end
    endtask

    task send_to_dut(ppi_tx_data_tr tr);
        case (tr.transaction_type)
            LANE_EN  : phy_enable();
            HS_DATA  : send_hs_data(tr);
            ULPS_DATA: send_ulps(tr);
            TRGR_DATA: send_trigger(tr);
            LPDT_DATA: send_lpdt(tr);
        endcase
        // Publish every transaction (HS payload for the scoreboard; all types for
        // coverage). A copy, since req is reused by the sequencer.
        begin
            ppi_tx_data_tr pub = ppi_tx_data_tr::type_id::create("pub");
            pub.transaction_type = tr.transaction_type;
            pub.payload          = tr.payload;
            pub.payload_size     = tr.payload_size;
            pub.trgr_type        = tr.trgr_type;
            pub.lpdt_payload = tr.lpdt_payload;
            pub.lpdt_size    = tr.lpdt_size;
            ap.write(pub);
            if (tr.transaction_type == HS_DATA)
                `uvm_info("HS_GOLDEN", $sformatf("TX golden HS payload (%0d): %p",
                          tr.payload_size, tr.payload), UVM_LOW)
        end
    endtask

    // Bring the PHY up to StopState.
    task phy_enable();
        data_vif.ForceTXStopmode_i <= 1;
        @(posedge data_vif.TxClkEsc_i);
        data_vif.enable_i <= 1'b0;
        @(posedge data_vif.TxClkEsc_i);
        data_vif.enable_i <= 1'b1;
        wait (data_vif.StopState_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.ForceTXStopmode_i <= 0;
    endtask

    // HS burst: request -> stream payload on byte clock -> drop request -> trail/stop.
    task send_hs_data(ppi_tx_data_tr tr);
        wait (data_vif.StopState_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.TxRequestHS_i        <= 1;
        data_vif.TxDataTransferEnHS_i <= 1;
        data_vif.TxWordValidHS_i      <= '1;
        data_vif.TxDataHS_i           <= tr.payload[0];

        // Datapath reaches the payload phase when TxReadyHS asserts.
        wait (data_vif.TxReadyHS_o == 1);
        for (int i = 1; i < tr.payload_size; i++) begin
            @(posedge clk_vif.TxByteClkHS_o);
            data_vif.TxDataHS_i <= tr.payload[i];
        end
        @(posedge clk_vif.TxByteClkHS_o);

        // End of burst.
        data_vif.TxRequestHS_i        <= 0;
        data_vif.TxDataTransferEnHS_i <= 0;
        data_vif.TxWordValidHS_i      <= '0;
        wait (data_vif.StopState_o == 1);
    endtask

    // Escape ULPS enter/exit.
    task send_ulps(ppi_tx_data_tr tr);
        wait (data_vif.StopState_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.TxUlpsEsc_i    <= 1;
        repeat (tr.tx_ulps_esc_req_delay) @(posedge data_vif.TxClkEsc_i);
        data_vif.TxRequestEsc_i <= 1;

        wait (data_vif.TxUlpsActive_n_o == 0);
        repeat (tr.ulps_active_delay) @(posedge data_vif.TxClkEsc_i);

        data_vif.TxUlpsExit_i <= 1;
        wait (data_vif.TxUlpsActive_n_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.TxUlpsEsc_i    <= 0;
        data_vif.TxRequestEsc_i <= 0;
        data_vif.TxUlpsExit_i   <= 0;
        wait (data_vif.StopState_o == 1);
    endtask

    // Escape trigger command.
    task send_trigger(ppi_tx_data_tr tr);
        wait (data_vif.StopState_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.TxTriggerEsc_i <= tr.trgr_type;
        repeat (tr.tx_trgr_esc_req_delay) @(posedge data_vif.TxClkEsc_i);
        data_vif.TxRequestEsc_i <= 1;

        // Hold request until the command has been clocked out, then deassert.
        repeat (tr.tx_trgr_esc_req_delay) @(posedge data_vif.TxClkEsc_i);
        data_vif.TxRequestEsc_i <= 0;
        wait (data_vif.StopState_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.TxTriggerEsc_i <= '0;
    endtask

    // Escape LPDT: assert request+lpdt, stream payload bytes honouring TxReadyEsc,
    // then drop request so the DUT runs the exit sequence.
    task send_lpdt(ppi_tx_data_tr tr);
        wait (data_vif.StopState_o == 1);
        @(posedge data_vif.TxClkEsc_i);
        data_vif.TxDataEsc_i  <= tr.lpdt_payload[0];
        data_vif.TxValidEsc_i <= 1;
        data_vif.TxLpdtEsc_i  <= 1;
        data_vif.TxRequestEsc_i <= 1;

        // Feed the remaining bytes: present the next byte each time the DUT pulses
        // TxReadyEsc (one ready per byte consumed).
        for (int i = 1; i < tr.lpdt_size; i++) begin
            @(posedge data_vif.TxClkEsc_i iff data_vif.TxReadyEsc_o == 1);
            data_vif.TxDataEsc_i <= tr.lpdt_payload[i];
        end
        // Wait for the last byte to be consumed, then signal end of data.
        @(posedge data_vif.TxClkEsc_i iff data_vif.TxReadyEsc_o == 1);
        data_vif.TxValidEsc_i   <= 0;
        data_vif.TxRequestEsc_i <= 0;
        data_vif.TxLpdtEsc_i    <= 0;
        wait (data_vif.StopState_o == 1);
    endtask
endclass

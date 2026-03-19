class ppi_data_driver extends uvm_driver #(ppi_tx_data_tr);
    `uvm_component_utils(ppi_data_driver)
    virtual ppi_intf data_vif;
    function new(string name = "ppi_data_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ppi_intf)::get(this, "", "data_vif", data_vif)) begin
            `uvm_fatal("NOVIF", "Virtual interface not found")
        end
    endfunction


    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            send_to_dut(req);
            seq_item_port.item_done();
        end
    endtask

    task send_to_dut(ppi_tx_data_tr tr);
        case (tr.transaction_type)
            HS_DATA: begin
                send_hs_data_tr(tr);
            end
            ULPS_DATA: begin
                send_ulps_data_tr(tr);
            end
            TRGR_DATA: begin
                send_trgr_data_tr(tr);
            end
            LANE_EN: begin
                phy_enable();
            end
        endcase
    endtask

    task send_hs_data_tr();
        @(posedge data_vif.TxClkEsc);
        data_vif.TxRequestHS <= 1;
        data_vif.TxWordValidHS <= 1;
        data_vif.TxDataHS <= req.payload.pop_front();

        repeat (req.throttle_delay)         // Throttle for the 1st data word
            @(posedge data_vif.TxClkEsc);
        begin
            @(posedge data_vif.TxWordClkHS);
            data_vif.TxDataTransferEnHS <= 0;
        end
        data_vif.TxDataTransferEnHS <= 1;

        wait (data_vif.TxReadyHS == 1);
        for (int i = 1; i < req.payload_size; i++) begin
            @(posedge data_vif.TxWordClkHS);
            data_vif.TxDataHS <= req.payload.pop_front();
        end
        data_vif.TxRequestHS <= 0;
        data_vif.TxWordValidHS <= 0;
        data_vif.TxDataTransferEnHS <= 0;
        // Add an event to say that the transaction is done
    endtask

    task send_ulps_data_tr();
        data_vif.TxUlpsExit      <=  0;
        wait (data_vif.stop_state == 1); // Wait for the clock lane to be in stop state
        @(posedge data_vif.TxClkEsc);
        data_vif.TxUlpsEsc <= 1;
        #(req.tx_ulps_esc_req_delay); 
        data_vif.TxRequestEsc <= 1; 
        
        fork begin
            #(req.tx_ulps_deassrt_delay);
            @(posedge data_vif.TxClkEsc);
            data_vif.TxUlpsEsc <= 0;
        end
        join_none
        #(req.ulps_active_delay)
        @(posedge data_vif.TxClkEsc);
        data_vif.TxUlpsExit      <=  1;
        wait (data_vif.TxUlpsActive_n == 1); 
        # WAKEUP_TIME;
        @(posedge data_vif.TxClkEsc);
        data_vif.TxRequestEsc <= 0;
    endtask

    task send_trgr_data_tr();
        wait (data_vif.stop_state == 1); // Wait for the clock lane to be in stop state
        @(posedge data_vif.TxClkEsc);
        data_vif.TxTriggerEsc[3:0] <= req.trgr_type;
        #(req.tx_trgr_esc_req_delay); 
        data_vif.TxRequestEsc <= 1; 
        
        fork begin
            #(req.tx_trgr_esc_deassrt_delay);
            @(posedge data_vif.TxClkEsc);
            data_vif.TxTriggerEsc[3:0] <= 0;
        end
        join_none
        #(req.trgr_esc_req_deassrt_delay)
        @(posedge data_vif.TxClkEsc);
        data_vif.TxRequestEsc <= 0;
    endtask

    task phy_enable ()
        data_vif.ForceTxStopmode     <= 1;
        data_vif.enable      = 1 ;
        #1420 ; // 
        data_vif.tx_clk_esc_en = 1;
        wait (data_vif.Stopstate == 1);
        @(posedge clk_vif.TxClkEsc);
        data_vif.ForceTxStopmode     <= 0;
        repeat (10) @(posedge clk_vif.TxClkEsc); // wait for some time see page 153
    endtask


endclass
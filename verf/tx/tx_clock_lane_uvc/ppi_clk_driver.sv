class ppi_clk_driver extends uvm_driver #(ppi_clk_tr);
    `uvm_component_utils(ppi_clk_driver)
    virtual tx_clk_ppi_if vif;
    localparam time WAKEUP_TIME = 1us;
    localparam time ESC_CLK_PER = 50;

    bit esc_clk = 0;
    bit tx_clk_esc_en = 0;

    function new (string name =" ppi_clk_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase (uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual tx_clk_ppi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("NOVIF", "Virtual clock interface not found")
        end
    endfunction



    task run_phase(uvm_phase phase);
        vif.TxClkEsc_i <= 1'b0;
        vif.enable_i <= 1'b0;
        vif.TxRequestHS_i <= 1'b0;
        vif.ForceTXStopmode_i <= 1'b0;
        vif.TxUlpsClk_i <= 1'b0;
        vif.TxUlpsExit_i <= 1'b0;

        fork
            drive_esc_clk();
            begin
                forever begin
                    seq_item_port.get_next_item(req);
                    send_to_dut(req);
                    seq_item_port.item_done();
                end
            end
        join
    endtask

    task drive_esc_clk();
        forever begin
            #(ESC_CLK_PER / 2) esc_clk = ~esc_clk;
            if (tx_clk_esc_en)
                vif.TxClkEsc_i <= esc_clk;
            else
                vif.TxClkEsc_i <= 1'b0;
        end
    endtask

    task send_to_dut(ppi_clk_tr tr);
        tr.print_transaction();
        case (tr.transaction_type)
            HS_CLK: begin
                hs_clk_enable(tr);
            end
            ULPS_CLK: begin
                send_ulps_clk_tr();
            end
            LANE_EN: begin
                lane_enable();
            end
        endcase
    endtask

    task hs_clk_enable(ppi_clk_tr tr);
        wait (vif.StopState_o == 1); // Wait for the clock lane to be in stop state
        @(posedge vif.TxClkEsc_i);
        vif.TxRequestHS_i <= 1;
        repeat(tr.num_hs_active_cycles) @(posedge vif.TxByteClkHS_o);
        `uvm_info(get_name(), $sformatf("Sent %0d HS clock cycles", tr.num_hs_active_cycles), UVM_LOW);
        @(posedge vif.TxClkEsc_i);
        vif.TxRequestHS_i <= 0;
        wait (vif.StopState_o == 1); // Wait for the clock lane to be in stop state
    endtask

    task lane_enable();
        vif.enable_i <= 1'b0;
        vif.ForceTXStopmode_i <= 1;
        #1420;
        tx_clk_esc_en <= 1;
        @(posedge vif.TxClkEsc_i);
        vif.enable_i <= 1'b1;   // active-high enable releases the FSM from CLK_INIT
        `uvm_info(get_name(), "waiting for stop state", UVM_LOW)
        wait (vif.StopState_o);
        @(posedge vif.TxClkEsc_i);
        vif.ForceTXStopmode_i <= 0;
        repeat (10) @(posedge vif.TxClkEsc_i);

        wait (vif.StopState_o == 1); // Wait for the clock lane to be in stop state
    endtask

    task send_ulps_clk_tr();
        vif.TxUlpsExit_i <= 0;
        wait (vif.StopState_o == 1); // Wait for the clock lane to be in stop state
        @(posedge vif.TxClkEsc_i);
        vif.TxUlpsClk_i <= 1;
        repeat (req.num_ulps_active_cycles) @(posedge vif.TxClkEsc_i);
        @(posedge vif.TxClkEsc_i);
        vif.TxUlpsExit_i <= 1;
        wait (vif.TxUlpsActive_n_o == 1);
        #WAKEUP_TIME;
        @(posedge vif.TxClkEsc_i);
        vif.TxUlpsClk_i <= 0;
        wait (vif.StopState_o == 1); // Wait for the clock lane to be in stop state
    endtask
endclass
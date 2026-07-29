// Driver: owns the clock-lane pad and the clock-lane PPI enables.
// The HS clock free-runs once started; the data-lane UVC times its bits to the
// clk_HS edges produced here.
class rx_clk_driver extends uvm_driver #(rx_clk_tr);
    `uvm_component_utils(rx_clk_driver)

    virtual rx_clk_ppi_if   clk_ppi;
    virtual rx_clk_d_phy_if clk_pad;

    localparam time T_LP   = 100ns;   // LP state hold
    localparam time T_HALF = 4ns;     // HS half-bit period (8 ns bit period)

    bit hs_run;                       // gates the free-running HS clock

    function new(string name = "rx_clk_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rx_clk_ppi_if)::get(this, "", "clk_ppi", clk_ppi))
            `uvm_fatal("NOVIF", "clk_ppi not set")
        if (!uvm_config_db#(virtual rx_clk_d_phy_if)::get(this, "", "clk_pad", clk_pad))
            `uvm_fatal("NOVIF", "clk_pad not set")
    endfunction

    task run_phase(uvm_phase phase);
        idle();
        phy_enable();
        forever begin
            seq_item_port.get_next_item(req);
            case (req.cmd)
                RX_CLK_HS_START: hs_start();
                RX_CLK_HS_STOP:  hs_stop();
            endcase
            seq_item_port.item_done();
        end
    endtask

    task idle();
        clk_pad.clk_LP_Dp_i = 1'b1; clk_pad.clk_LP_Dn_i = 1'b1;  // LP-11 Stop
        clk_pad.clk_HS_Dp_i = 1'b0; clk_pad.clk_HS_Dn_i = 1'b0;
        clk_ppi.Enable_i    = 1'b0; clk_ppi.Shutdownz_i = 1'b0;
        hs_run = 1'b0;
    endtask

    task phy_enable();
        #T_LP;
        clk_ppi.Shutdownz_i = 1'b1;
        clk_ppi.Enable_i    = 1'b1;
        #T_LP;
    endtask

    // Enter HS, then free-run the HS clock until hs_stop() clears hs_run.
    task hs_start();
        clk_pad.clk_LP_Dp_i = 1'b0; clk_pad.clk_LP_Dn_i = 1'b1; #T_LP; // LP-01 HS request
        clk_pad.clk_LP_Dp_i = 1'b0; clk_pad.clk_LP_Dn_i = 1'b0; #T_LP; // LP-00 -> HS_ZERO
        hs_run = 1'b1;
        fork
            while (hs_run) begin
                clk_pad.clk_HS_Dp_i = 1'b1; clk_pad.clk_HS_Dn_i = 1'b0; #T_HALF;
                clk_pad.clk_HS_Dp_i = 1'b0; clk_pad.clk_HS_Dn_i = 1'b1; #T_HALF;
            end
        join_none
    endtask

    // Stop the HS clock and park the clock lane back in Stop (LP-11).
    task hs_stop();
        hs_run = 1'b0;
        #(2*T_HALF);                       // let the in-flight half-period drain
        clk_pad.clk_HS_Dp_i = 1'b0; clk_pad.clk_HS_Dn_i = 1'b0;
        clk_pad.clk_LP_Dp_i = 1'b1; clk_pad.clk_LP_Dn_i = 1'b1;
        #T_LP;
    endtask
endclass

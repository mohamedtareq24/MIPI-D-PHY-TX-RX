`include "clock_lane_defs.svh"
module tx_clock_lane (
    input logic arstn, // Asynchronous reset, active low
    tx_clk_ppi_if.tx            ppi,
    tx_clk_analog_if.digital    analog,
    tx_clk_d_phy_if.tx_d_phy_lp d_phy
);
    
    
    // Clock lane state machine
    typedef enum int  {
        CLK_INIT,
        LP_CLK_STOP,
        HS_CLK_REQ,
        HS_CLK_PRPR,
        HS_CLK_ZERO,
        HS_CLK_ACTIVE,
        HS_CLK_TRAIL,
        
        ULPS_CLK_REQ,
        ULPS_CLK_ACTIVE,
        ULPS_CLK_EXIT
    } clk_lane_state_e;

    clk_lane_state_e state, next_state;

    logic [15:0] timer_cntr;
    logic [15:0] timer_value;
    logic        timer_load;
    logic        timer_done;
    logic        init_done;

    ///////////////////////////////////////
    //TIMER
    //////////////////////////////////////
    
    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) begin
        if (!arstn) begin   
            timer_cntr <= `TX_INIT_TIME;
        end
        else if (timer_cntr > 0) begin
            timer_cntr <= timer_cntr - 1;
        end
        else if (timer_load ) begin
            timer_cntr <= timer_value;
        end
    end 
    assign timer_done = (timer_cntr == 0) ? 1 : 0;

    // State transition logic
    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) begin
        if (!arstn) begin
            state <= CLK_INIT;
        end else begin
            state <= next_state;
        end
    end

    
    always_comb begin
        // Default outputs
        ppi.TxReadyHS_o = 0;
        ppi.TxByteClkHS_o = 0;
        d_phy.clk_LP_Dp_o = 0;
        d_phy.clk_LP_Dn_o = 0;
        // clk_HS_D_o = 0;
        analog.ddr_clk_buff_en = 0;
        timer_load = 0;
        timer_value = 0;
        ppi.StopState_o = 0;
        ppi.TxUlpsActive_n_o = 1;
        init_done = 0 ;
        if (ppi.ForceTXStopmode_i && init_done && state != LP_CLK_STOP) begin
            next_state = LP_CLK_STOP;
        end
        else
        case (state)
            CLK_INIT: begin
                timer_value  = `TX_INIT_TIME;
                d_phy.clk_LP_Dp_o   = 1;
                d_phy.clk_LP_Dn_o   = 1;
                init_done = 0;
                ppi.StopState_o = 0;
                if (timer_cntr == 1) begin
                    timer_value = `LP_CLK_STOP_TIME;
                    timer_load = 1;
                end
                else if (timer_cntr == 0) begin
                    next_state = LP_CLK_STOP;
                    init_done = 1;
                    timer_value = `LP_CLK_STOP_TIME;
                    timer_load = 1;
                end
                else
                    next_state = CLK_INIT;
            end
            LP_CLK_STOP: begin
                d_phy.clk_LP_Dp_o = 1;
                d_phy.clk_LP_Dn_o = 1;
                ppi.StopState_o = 1;
                // timer_load =    0; // Stop the timer
                // timer_value =   0;
                if (timer_done) begin
                    if (ppi.TxRequestHS_i) begin
                        next_state = HS_CLK_REQ;
                    end
                    else if (ppi.TxUlpsClk_i) begin
                        next_state = ULPS_CLK_REQ;
                    end
                    else begin
                        next_state = LP_CLK_STOP;
                    end
                end
                else begin
                    next_state = LP_CLK_STOP;
                end
            end
            HS_CLK_REQ: begin
                d_phy.clk_LP_Dp_o = 0;      
                d_phy.clk_LP_Dn_o = 1;      

                timer_value = `LP_CLK_REQ_TIME;
                timer_load = 1;
                if (timer_done & ppi.TxRequestHS_i) begin
                    next_state = HS_CLK_PRPR;
                end
                else begin
                    next_state = HS_CLK_REQ;
                end
            end
            HS_CLK_PRPR: begin
                d_phy.clk_LP_Dp_o = 0;
                d_phy.clk_LP_Dn_o = 0;

                timer_value = `LP_CLK_PRPR_TIME;
                timer_load = 1;
                if (timer_done & ppi.TxRequestHS_i) begin
                    next_state = HS_CLK_ZERO;
                end
                else begin
                    next_state = HS_CLK_PRPR;
                end
            end
            HS_CLK_ZERO: begin
                d_phy.clk_LP_Dp_o = 0;
                d_phy.clk_LP_Dn_o = 0;
                // clk_HS_D_o  = 0;

                timer_value = `LP_CLK_ZERO_TIME;
                timer_load = 1;
                if (timer_done & ppi.TxRequestHS_i) begin
                    next_state = HS_CLK_ACTIVE;
                end
                else begin
                    next_state = HS_CLK_ZERO;
                end
            end
            HS_CLK_ACTIVE: begin
                d_phy.clk_LP_Dp_o = 0;
                d_phy.clk_LP_Dn_o = 0;

                ppi.TxReadyHS_o = 1;
                ppi.TxByteClkHS_o = analog.clk_div; // Use the divided clock for byte clock
                analog.ddr_clk_buff_en = 1; // Enable the DDR clock buffer
                
                if (!ppi.TxRequestHS_i) begin
                    next_state = HS_CLK_TRAIL; // Transition to trail state when request is deasserted
                end
                else begin
                    next_state = HS_CLK_ACTIVE; // Stay in active state until request is deasserted
                end
            end
            HS_CLK_TRAIL: begin
                d_phy.clk_LP_Dp_o = 0;
                d_phy.clk_LP_Dn_o = 0;
                analog.ddr_clk_buff_en = 0; // Disable the DDR clock buffer

                ppi.TxReadyHS_o = 0;
                ppi.TxByteClkHS_o = 0;

                timer_value = `LP_CLK_TRAIL_TIME;
                timer_load = 1;
                if (timer_done) begin
                    next_state = LP_CLK_STOP; // Transition back to LP mode after trail time
                end
                else begin
                    next_state = HS_CLK_TRAIL;
                end
            end

            ULPS_CLK_REQ: begin
                d_phy.clk_LP_Dp_o = 1;
                d_phy.clk_LP_Dn_o = 0;

                timer_value = `ULPS_CLK_REQ_TIME;
                timer_load = 1;
                if (timer_done & ppi.TxUlpsClk_i) begin
                    next_state = ULPS_CLK_ACTIVE;
                end
                else begin
                    next_state = ULPS_CLK_REQ;
                end
            end
            ULPS_CLK_ACTIVE: begin
                d_phy.clk_LP_Dp_o = 0;
                d_phy.clk_LP_Dn_o = 0;

                // You can wait for sometime before asserting ppi.TxUlpsActive_n_o 
                ppi.TxUlpsActive_n_o = 0;
                
                if (ppi.TxUlpsExit_i) begin
                    next_state = ULPS_CLK_EXIT;
                end
                else begin
                    next_state = ULPS_CLK_ACTIVE;
                end
            end
            ULPS_CLK_EXIT: begin
                d_phy.clk_LP_Dp_o = 1;
                d_phy.clk_LP_Dn_o = 0;

                ppi.TxUlpsActive_n_o = 1;
                timer_value = `ULPS_CLK_EXIT_TIME; // Should be Twakeup + Some margin 
                timer_load = 1;
                
                if (timer_done) begin
                    next_state = LP_CLK_STOP;
                end
                else begin
                    next_state = ULPS_CLK_EXIT;
                end
            end
        endcase
    end

endmodule
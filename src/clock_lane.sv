`include "clock_lane_defs.svh"
module clock_lane (
    input logic arstn, // Asynchronous reset, active low
    // PPI
    input   logic TxClkEsc_i,
    input   logic TxRequestHS_i,
    output  logic TxReadyHS_o,
    output  logic TxByteClkHS_o,

    input   logic TxUlpsClk_i,
    input   logic TxUlpsExit_i,
    output  logic TxUlpsActive_n_o,

    /// NOTE: ADD AN ENABLE 
    output  logic   StopState_o, 
    input   logic   ForceTXStopmode_i,
    // D-PHY
    output logic clk_LP_Dp_o,
    output logic clk_LP_Dn_o,
    //output logic clk_HS_D_o,

    // Analog 
    input   logic clk_div,          // SERDES Clock  / 8 
    output  logic ddr_clk_buff_en  // Enable for the Serail Clock
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

    ///////////////////////////////////////
    //TIMER
    //////////////////////////////////////
    
    always_ff @(posedge TxClkEsc_i or negedge arstn) begin
        if (!arstn) begin   
            timer_cntr <= `TX_INIT_TIME;
            timer_done <= 0;
        end
        else if (timer_cntr > 0) begin
            timer_cntr <= timer_cntr - 1;
            timer_done <= 0;
        end
        else if (timer_cntr == 0) begin
            timer_done <= 1;
        end
        else if (timer_load ) begin
            timer_cntr <= timer_value;
            timer_done <= 0;
        end
    end 

    // State transition logic
    always_ff @(posedge TxClkEsc_i or negedge arstn) begin
        if (!arstn) begin
            state <= CLK_INIT;
        end else begin
            state <= next_state;
        end
    end

    
    always_comb begin
        // Default outputs
        TxReadyHS_o = 0;
        TxByteClkHS_o = 0;
        clk_LP_Dp_o = 0;
        clk_LP_Dn_o = 0;
        // clk_HS_D_o = 0;
        ddr_clk_buff_en = 0;
        timer_load = 0;
        timer_value = 0;
        StopState_o = 0;
        TxUlpsActive_n_o = 1;

        next_state = LP_CLK_STOP;

        if (ForceTXStopmode_i) begin
            next_state = LP_CLK_STOP;
        end
        else 
        case (state)
            CLK_INIT: begin
                timer_value  = `TX_INIT_TIME;
                clk_LP_Dp_o   = 1;
                clk_LP_Dn_o   = 1;
                StopState_o = 0;
                if (timer_done)
                    next_state = LP_CLK_STOP;
                else
                    next_state = CLK_INIT;
            end
            LP_CLK_STOP: begin
                clk_LP_Dp_o = 1;
                clk_LP_Dn_o = 1;
                StopState_o = 1;
                timer_value = `LP_CLK_STOP_TIME;
                timer_load = 1;
                if (timer_done) begin
                    timer_load =    0; // Stop the timer
                    timer_value =   0;
                    if (TxRequestHS_i) begin
                        next_state = HS_CLK_REQ;
                    end
                    else if (TxUlpsClk_i) begin
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
                clk_LP_Dp_o = 0;      
                clk_LP_Dn_o = 1;      

                timer_value = `LP_CLK_REQ_TIME;
                timer_load = 1;
                if (timer_done & TxRequestHS_i) begin
                    next_state = HS_CLK_PRPR;
                end
                else begin
                    next_state = HS_CLK_REQ;
                end
            end
            HS_CLK_PRPR: begin
                clk_LP_Dp_o = 0;
                clk_LP_Dn_o = 0;

                timer_value = `LP_CLK_PRPR_TIME;
                timer_load = 1;
                if (timer_done & TxRequestHS_i) begin
                    next_state = HS_CLK_ZERO;
                end
                else begin
                    next_state = HS_CLK_PRPR;
                end
            end
            HS_CLK_ZERO: begin
                clk_LP_Dp_o = 0;
                clk_LP_Dn_o = 0;
                // clk_HS_D_o  = 0;

                timer_value = `LP_CLK_ZERO_TIME;
                timer_load = 1;
                if (timer_done & TxRequestHS_i) begin
                    next_state = HS_CLK_ACTIVE;
                end
                else begin
                    next_state = HS_CLK_ZERO;
                end
            end
            HS_CLK_ACTIVE: begin
                clk_LP_Dp_o = 0;
                clk_LP_Dn_o = 0;

                TxReadyHS_o = 1;
                TxByteClkHS_o = clk_div; // Use the divided clock for byte clock
                ddr_clk_buff_en = 1; // Enable the DDR clock buffer
                
                if (!TxRequestHS_i) begin
                    next_state = HS_CLK_TRAIL; // Transition to trail state when request is deasserted
                end
                else begin
                    next_state = HS_CLK_ACTIVE; // Stay in active state until request is deasserted
                end
            end
            HS_CLK_TRAIL: begin
                clk_LP_Dp_o = 0;
                clk_LP_Dn_o = 0;
                ddr_clk_buff_en = 0; // Disable the DDR clock buffer

                TxReadyHS_o = 0;
                TxByteClkHS_o = 0;

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
                clk_LP_Dp_o = 1;
                clk_LP_Dn_o = 0;

                timer_value = `ULPS_CLK_REQ_TIME;
                timer_load = 1;
                if (timer_done & TxUlpsClk_i) begin
                    next_state = ULPS_CLK_ACTIVE;
                end
                else begin
                    next_state = ULPS_CLK_REQ;
                end
            end
            ULPS_CLK_ACTIVE: begin
                clk_LP_Dp_o = 0;
                clk_LP_Dn_o = 0;

                // You can wait for sometime before asserting TxUlpsActive_n_o 
                TxUlpsActive_n_o = 0;
                
                if (TxUlpsExit_i) begin
                    next_state = ULPS_CLK_EXIT;
                end
                else begin
                    next_state = ULPS_CLK_ACTIVE;
                end
            end
            ULPS_CLK_EXIT: begin
                clk_LP_Dp_o = 1;
                clk_LP_Dn_o = 0;

                TxUlpsActive_n_o = 1;
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
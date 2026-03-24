module tx_data_lane(
    input logic arstn, // Asynchronous reset, active low
    tx_data_ppi_if.tx               ppi,
    tx_data_analog_if.tx            analog,
    tx_data_d_phy_if.tx_d_phy_lp    d_phy
);

    localparam logic [15:0] TX_INIT_TIME            = 16'd1000;
    localparam logic [15:0] LP_TXDATA_STOP_TIME     = 16'd1000;
    localparam logic [15:0] LP_TXDATA_REQ_TIME      = 16'd1000;
    localparam logic [15:0] LP_TXDATA_PRPR_TIME     = 16'd1000;
    localparam logic [15:0] LP_TXDATA_ZERO_TIME     = 16'd1000;
    localparam logic [15:0] LP_TXDATA_TRAIL_TIME    = 16'd1000;
    localparam logic [15:0] ULPS_TXDATA_REQ_TIME    = 16'd1000;
    localparam logic [15:0] ULPS_TXDATA_EXIT_TIME   = 16'd1000;
    localparam logic [7:0]  SOT_PATTERN = 8'h1D;
                                              // --[0:7]--//             [8:39]
                                              //---ENTRY--// -------------CMD------------------------------  
    localparam logic [0:39] ESC_LPDT       = 40'b10_00_01_00_10_00_10_00_10_00_01_00_01_00_01_00_01_00_10_00; 
    localparam logic [0:39] ESC_ULPS       = 40'b10_00_01_00_01_00_01_00_01_00_10_00_10_00_10_00_10_00_01_00; 
    localparam logic [0:39] ESC_UNDEFINED1 = 40'b10_00_01_00_10_00_01_00_01_00_10_00_10_00_10_00_10_00_10_00; 
    localparam logic [0:39] ESC_UNDEFINED2 = 40'b10_00_01_00_10_00_10_00_01_00_10_00_10_00_10_00_10_00_01_00; 
    localparam logic [0:39] ESC_RESET      = 40'b10_00_01_00_01_00_10_00_10_00_01_00_01_00_01_00_10_00_01_00; 
    localparam logic [0:39] ESC_HSTEST     = 40'b10_00_01_00_01_00_10_00_01_00_10_00_10_00_10_00_01_00_10_00; 
    localparam logic [0:39] ESC_UNKNOWN4   = 40'b10_00_01_00_01_00_01_00_10_00_01_00_01_00_01_00_01_00_10_00; 
    localparam logic [0:39] ESC_UNKNOWN5   = 40'b10_00_01_00_10_00_01_00_10_00_01_00_01_00_01_00_01_00_01_00; 


    typedef enum int  {
        TXDATA_INIT,
        LP_TXDATA_STOP,
        HS_TXDATA_REQ,
        HS_TXDATA_PRPR,
        HS_TXDATA_ZERO,
        HS_TXDATA_SOT,
        HS_TXDATA_ACTIVE,
        HS_TXDATA_TRAIL,
        TRIGGER_CMD_SEND,
        TRIGGER_CMD_EXT,    
        ULPS_CMD_SEND,
        ULPS_TXDATA_ACTIVE,
        ULPS_TXDATA_EXIT
    } tx_data_lane_state_e;

    tx_data_lane_state_e state, next_state;

    logic [15:0] timer_cntr;
    logic [15:0] timer_value;
    logic        timer_load;
    logic        timer_done;
    logic        send_sot;
    logic        hs_rst;
    logic        hs_finished;
    logic [1:0]  data_path_cntr;
    logic [0:41] esc_seq;
    logic [5:0]  esc_indx;

    ///////////////////////////////////////
    //TIMER
    //////////////////////////////////////
    
    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn) begin
            timer_cntr <= 0;
            timer_done <= 0;
        end
        else if (ppi.enable_i) begin
            timer_cntr <= TX_INIT_TIME;
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

    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn)
            state <= TXDATA_INIT;
        else if (ppi.enable_i)
            state <= TXDATA_INIT;
        else
            state <= next_state;
    end

    always_comb begin
        d_phy.tx_lane_LP_Dp_o = 0;
        d_phy.tx_lane_LP_Dn_o = 0;
        analog.serializer_en_o = 0;
        send_sot = 0;
        hs_rst = 0;
        timer_load  = 0;
        timer_value = 0;
        ppi.StopState_o = 0;
        ppi.TxUlpsActive_n_o = 1;
  
        next_state = LP_TXDATA_STOP;

        if (ppi.ForceTXStopmode_i) begin
            next_state = LP_TXDATA_STOP;
        end
        else 
        case (state)
            TXDATA_INIT: begin
                timer_value  = TX_INIT_TIME;
                d_phy.tx_lane_LP_Dp_o     = 1;
                d_phy.tx_lane_LP_Dn_o     = 1;
                ppi.StopState_o     = 0;
                if (timer_done)
                    next_state = LP_TXDATA_STOP;
                else
                    next_state = TXDATA_INIT;
            end
            LP_TXDATA_STOP: begin
                d_phy.tx_lane_LP_Dp_o = 1;
                d_phy.tx_lane_LP_Dn_o = 1;
                ppi.StopState_o = 1;
                timer_value = LP_TXDATA_STOP_TIME;
                timer_load = 1;
                hs_rst = 1;
                if (timer_done) begin
                    timer_load =    0; // Stop the timer
                    timer_value =   0;
                    if (ppi.TxRequestHS_i) begin
                        next_state = HS_TXDATA_REQ;
                    end
                    else if (ppi.TxRequestEsc_i && ppi.TxTriggerEsc_i) begin
                        next_state = TRIGGER_CMD_SEND;
                    end
                    else if (ppi.TxRequestEsc_i && ppi.TxUlpsEsc_i) begin
                        next_state = ULPS_CMD_SEND;
                    end
                    else begin
                        next_state = LP_TXDATA_STOP;
                    end
                end
                else begin
                    next_state = LP_TXDATA_STOP;
                end
            end
            HS_TXDATA_REQ: begin
                d_phy.tx_lane_LP_Dp_o = 0;      
                d_phy.tx_lane_LP_Dn_o = 1;      

                timer_value = LP_TXDATA_REQ_TIME;
                timer_load = 1;
                if (timer_done && ppi.TxRequestHS_i) begin
                    next_state = HS_TXDATA_PRPR;
                end
                else begin
                    next_state = HS_TXDATA_REQ;
                end
            end
            HS_TXDATA_PRPR: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;

                timer_value = LP_TXDATA_PRPR_TIME;
                timer_load = 1;
                if (timer_done && ppi.TxRequestHS_i) begin
                    next_state = HS_TXDATA_ZERO;
                end
                else begin
                    next_state = HS_TXDATA_PRPR;
                end
            end
            HS_TXDATA_ZERO: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;
                // tx_lane_HS_D_o  = 0;
                analog.serializer_en_o = 1;
                timer_value = LP_TXDATA_ZERO_TIME;
                timer_load = 1;
                if (timer_done && ppi.TxRequestHS_i && ppi.TxDataTransferEnHS_i) begin
                    next_state = HS_TXDATA_SOT;
                end
                else begin
                    next_state = HS_TXDATA_ZERO;
                end
            end
            
            HS_TXDATA_SOT: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;
                analog.serializer_en_o = 1;
                send_sot        = 1;
                next_state      = HS_TXDATA_ACTIVE ;
            end

            HS_TXDATA_ACTIVE: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;
                send_sot        = 1;
                analog.serializer_en_o = 1;
                // data_path_en    = 1;
                // ppi.TxReadyHS_o     = 1;
                
                if (hs_finished) begin  // ana 5lst ya abla from HS 
                    next_state  = HS_TXDATA_TRAIL; // Transition to trail state when request is deasserted
                end
                else begin
                    next_state = HS_TXDATA_ACTIVE; // Stay in active state until request is deasserted
                end
            end
            HS_TXDATA_TRAIL: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;
                analog.serializer_en_o = 1;

                timer_value = LP_TXDATA_TRAIL_TIME;
                timer_load = 1;
                if (timer_done) begin
                    next_state = LP_TXDATA_STOP; // Transition back to LP mode after trail time
                    analog.serializer_en_o = 0;
                    send_sot = 0;
                    hs_rst = 1;
                end
                else begin
                    next_state = HS_TXDATA_TRAIL;
                end
            end
            TRIGGER_CMD_SEND: begin
                d_phy.tx_lane_LP_Dp_o = esc_seq[esc_indx];
                d_phy.tx_lane_LP_Dn_o = esc_seq[esc_indx+1];

                if (esc_indx > 38 & !ppi.TxRequestEsc_i) begin
                    next_state = TRIGGER_CMD_EXT;          
                end
                else begin     // Keep sending the Esc command as dummy data ppi.TxRequestEsc_i || esc_indx <= 40 
                    next_state = TRIGGER_CMD_SEND;
                end
            end
            TRIGGER_CMD_EXT: begin
                    d_phy.tx_lane_LP_Dp_o = 1;
                    d_phy.tx_lane_LP_Dn_o = 0;
                    next_state = LP_TXDATA_STOP;
            end
            ULPS_CMD_SEND: begin
                d_phy.tx_lane_LP_Dp_o = esc_seq[esc_indx];
                d_phy.tx_lane_LP_Dn_o = esc_seq[esc_indx+1];
                if (esc_indx > 38) begin
                    next_state = ULPS_TXDATA_ACTIVE; // Transition back to LP mode after sending ESC command
                end
                else begin
                    next_state = ULPS_CMD_SEND;
                end
            end
            ULPS_TXDATA_ACTIVE: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;

                // You can wait for sometime before asserting ppi.TxUlpsActive_n_o 
                ppi.TxUlpsActive_n_o = 0;
                
                if (ppi.TxUlpsExit_i) begin
                    next_state = ULPS_TXDATA_EXIT;
                end
                else begin
                    next_state = ULPS_TXDATA_ACTIVE;
                end
            end
            ULPS_TXDATA_EXIT: begin
                d_phy.tx_lane_LP_Dp_o = 1;
                d_phy.tx_lane_LP_Dn_o = 0;

                ppi.TxUlpsActive_n_o = 1;
                timer_value = ULPS_TXDATA_EXIT_TIME; // Should be Twakeup + Some margin 
                timer_load = 1;
                
                if (timer_done) begin
                    next_state = LP_TXDATA_STOP;
                end
                else begin
                    next_state = ULPS_TXDATA_EXIT;
                end
            end
            default: next_state = LP_TXDATA_STOP;
        endcase
    end

    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn) begin
            esc_indx    <= 0;
            esc_seq     <= '1;
        end
        else if (next_state == TRIGGER_CMD_SEND || next_state == ULPS_CMD_SEND) begin
            case (1)
                ppi.TxUlpsEsc_i:        esc_seq <= ESC_ULPS;
                ppi.TxTriggerEsc_i[0]:  esc_seq <= ESC_RESET;
                ppi.TxTriggerEsc_i[1]:  esc_seq <= ESC_HSTEST;
                ppi.TxTriggerEsc_i[2]:  esc_seq <= ESC_UNKNOWN4;
                ppi.TxTriggerEsc_i[3]:  esc_seq <= ESC_UNKNOWN5;
                default:            esc_seq <= '1;
            endcase
        end
        else if (state == TRIGGER_CMD_SEND || state == ULPS_CMD_SEND)
        begin
            if (esc_indx > 38)
                esc_indx <= 8;
            else
                esc_indx <= esc_indx + 2;
        end
        else 
            esc_indx <= 0;
    end

    // Need some CDC here 
    always_comb 
    begin
        analog.parallel_data_o = 8'h00;
        ppi.TxReadyHS_o = 0;
        hs_finished = 0;
        case(data_path_cntr)
                0 : analog.parallel_data_o = 0 ;
                1 : analog.parallel_data_o = SOT_PATTERN; //00011101
                2 : begin 
                    analog.parallel_data_o = ppi.TxDataHS_i ;
                    ppi.TxReadyHS_o     = 1;
                end
                3: begin 
                    analog.parallel_data_o = {8{!analog.parallel_data_o[7]}} ; // Bit Toggle 
                    ppi.TxReadyHS_o     = 0;
                    hs_finished     = 1; // ana 5lst ya abla from HS
                end
                default: begin
                    analog.parallel_data_o = 8'h00;
                end
        endcase
    end

    always_ff @( posedge analog.tx_lane_clk_div_i or negedge arstn ) begin
        if(!arstn)
            data_path_cntr <= 0;
        else if (hs_rst)
            data_path_cntr <= 0;
        else if (!ppi.TxRequestHS_i && (data_path_cntr == 2))
        begin
            data_path_cntr <= 3;
        end
        else if (data_path_cntr == 2)
            data_path_cntr <= 2;
        else if (send_sot)
            data_path_cntr <= data_path_cntr + 1; 
    end
endmodule
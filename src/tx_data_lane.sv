module tx_data_lane(
    input logic arstn, // Asynchronous reset, active low
    // PPI Control 
    input   logic TxClkEsc_i,
    input   logic enable_i,
    input   logic   ForceTXStopmode_i,
    output  logic   StopState_o, 

    // PPI Data 
    input   logic       TxRequestHS_i,
    input   logic [7:0] TxDataHS_i,
    input   logic [1:0] TxDataWidthHS_i,
    input   logic [3:0] TxWordValidHS_i,
    input   logic       TxDataTransferEnHS_i,
    output  logic       TxReadyHS_o,
    // PPI Esc
    input logic TxRequestEsc_i,
    input logic [3:0] TxTriggerEsc_i,
    input logic TxUlpsEsc_i,
    input logic TxUlpsExit_i,
    output logic TxUlpsActive_n_o,
    // D-PHY
    output logic tx_lane_LP_Dp_o,
    output logic tx_lane_LP_Dn_o,
    //output logic tx_lane_HS_D_o,

    // Analog 
    input   logic   tx_lane_clk_div_i,            // SERDES Clock  / 8
    output  logic   serializer_en_o,      // Serialzer Enable
    output  logic   [7:0] parallel_data_o
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
    
    always_ff @(posedge TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn) begin
            timer_cntr <= 0;
            timer_done <= 0;
        end
        else if (enable_i) begin
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

    always_ff @(posedge TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn)
            state <= TXDATA_INIT;
        else if (enable_i)
            state <= TXDATA_INIT;
        else
            state <= next_state;
    end

    always_comb begin
        tx_lane_LP_Dp_o = 0;
        tx_lane_LP_Dn_o = 0;
        serializer_en_o = 0;
        send_sot = 0;
        hs_rst = 0;
        timer_load  = 0;
        timer_value = 0;
        StopState_o = 0;
        TxUlpsActive_n_o = 1;
  
        next_state = LP_TXDATA_STOP;

        if (ForceTXStopmode_i) begin
            next_state = LP_TXDATA_STOP;
        end
        else 
        case (state)
            TXDATA_INIT: begin
                timer_value  = TX_INIT_TIME;
                tx_lane_LP_Dp_o     = 1;
                tx_lane_LP_Dn_o     = 1;
                StopState_o     = 0;
                if (timer_done)
                    next_state = LP_TXDATA_STOP;
                else
                    next_state = TXDATA_INIT;
            end
            LP_TXDATA_STOP: begin
                tx_lane_LP_Dp_o = 1;
                tx_lane_LP_Dn_o = 1;
                StopState_o = 1;
                timer_value = LP_TXDATA_STOP_TIME;
                timer_load = 1;
                hs_rst = 1;
                if (timer_done) begin
                    timer_load =    0; // Stop the timer
                    timer_value =   0;
                    if (TxRequestHS_i) begin
                        next_state = HS_TXDATA_REQ;
                    end
                    else if (TxRequestEsc_i && TxTriggerEsc_i) begin
                        next_state = TRIGGER_CMD_SEND;
                    end
                    else if (TxRequestEsc_i && TxUlpsEsc_i) begin
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
                tx_lane_LP_Dp_o = 0;      
                tx_lane_LP_Dn_o = 1;      

                timer_value = LP_TXDATA_REQ_TIME;
                timer_load = 1;
                if (timer_done && TxRequestHS_i) begin
                    next_state = HS_TXDATA_PRPR;
                end
                else begin
                    next_state = HS_TXDATA_REQ;
                end
            end
            HS_TXDATA_PRPR: begin
                tx_lane_LP_Dp_o = 0;
                tx_lane_LP_Dn_o = 0;

                timer_value = LP_TXDATA_PRPR_TIME;
                timer_load = 1;
                if (timer_done && TxRequestHS_i) begin
                    next_state = HS_TXDATA_ZERO;
                end
                else begin
                    next_state = HS_TXDATA_PRPR;
                end
            end
            HS_TXDATA_ZERO: begin
                tx_lane_LP_Dp_o = 0;
                tx_lane_LP_Dn_o = 0;
                // tx_lane_HS_D_o  = 0;
                serializer_en_o = 1;
                timer_value = LP_TXDATA_ZERO_TIME;
                timer_load = 1;
                if (timer_done && TxRequestHS_i && TxDataTransferEnHS_i) begin
                    next_state = HS_TXDATA_SOT;
                end
                else begin
                    next_state = HS_TXDATA_ZERO;
                end
            end
            
            HS_TXDATA_SOT: begin
                tx_lane_LP_Dp_o = 0;
                tx_lane_LP_Dn_o = 0;
                serializer_en_o = 1;
                send_sot        = 1;
                next_state      = HS_TXDATA_ACTIVE ;
            end

            HS_TXDATA_ACTIVE: begin
                tx_lane_LP_Dp_o = 0;
                tx_lane_LP_Dn_o = 0;
                send_sot        = 1;
                serializer_en_o = 1;
                // data_path_en    = 1;
                // TxReadyHS_o     = 1;
                
                if (hs_finished) begin  // ana 5lst ya abla from HS 
                    next_state  = HS_TXDATA_TRAIL; // Transition to trail state when request is deasserted
                end
                else begin
                    next_state = HS_TXDATA_ACTIVE; // Stay in active state until request is deasserted
                end
            end
            HS_TXDATA_TRAIL: begin
                tx_lane_LP_Dp_o = 0;
                tx_lane_LP_Dn_o = 0;
                serializer_en_o = 1;

                timer_value = LP_TXDATA_TRAIL_TIME;
                timer_load = 1;
                if (timer_done) begin
                    next_state = LP_TXDATA_STOP; // Transition back to LP mode after trail time
                    serializer_en_o = 0;
                    send_sot = 0;
                    hs_rst = 1;
                end
                else begin
                    next_state = HS_TXDATA_TRAIL;
                end
            end
            TRIGGER_CMD_SEND: begin
                tx_lane_LP_Dp_o = esc_seq[esc_indx];
                tx_lane_LP_Dn_o = esc_seq[esc_indx+1];

                if (esc_indx > 38 & !TxRequestEsc_i) begin
                    next_state = TRIGGER_CMD_EXT;          
                end
                else begin     // Keep sending the Esc command as dummy data TxRequestEsc_i || esc_indx <= 40 
                    next_state = TRIGGER_CMD_SEND;
                end
            end
            TRIGGER_CMD_EXT: begin
                    tx_lane_LP_Dp_o = 1;
                    tx_lane_LP_Dn_o = 0;
                    next_state = LP_TXDATA_STOP;
            end
            ULPS_CMD_SEND: begin
                tx_lane_LP_Dp_o = esc_seq[esc_indx];
                tx_lane_LP_Dn_o = esc_seq[esc_indx+1];
                if (esc_indx > 38) begin
                    next_state = ULPS_TXDATA_ACTIVE; // Transition back to LP mode after sending ESC command
                end
                else begin
                    next_state = ULPS_CMD_SEND;
                end
            end
            ULPS_TXDATA_ACTIVE: begin
                tx_lane_LP_Dp_o = 0;
                tx_lane_LP_Dn_o = 0;

                // You can wait for sometime before asserting TxUlpsActive_n_o 
                TxUlpsActive_n_o = 0;
                
                if (TxUlpsExit_i) begin
                    next_state = ULPS_TXDATA_EXIT;
                end
                else begin
                    next_state = ULPS_TXDATA_ACTIVE;
                end
            end
            ULPS_TXDATA_EXIT: begin
                tx_lane_LP_Dp_o = 1;
                tx_lane_LP_Dn_o = 0;

                TxUlpsActive_n_o = 1;
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

    always_ff @(posedge TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn) begin
            esc_indx    <= 0;
            esc_seq     <= '1;
        end
        else if (next_state == TRIGGER_CMD_SEND || next_state == ULPS_CMD_SEND) begin
            case (1)
                TxUlpsEsc_i:        esc_seq <= ESC_ULPS;
                TxTriggerEsc_i[0]:  esc_seq <= ESC_RESET;
                TxTriggerEsc_i[1]:  esc_seq <= ESC_HSTEST;
                TxTriggerEsc_i[2]:  esc_seq <= ESC_UNKNOWN4;
                TxTriggerEsc_i[3]:  esc_seq <= ESC_UNKNOWN5;
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
        parallel_data_o = 8'h00;
        TxReadyHS_o = 0;
        hs_finished = 0;
        case(data_path_cntr)
                0 : parallel_data_o = 0 ;
                1 : parallel_data_o = SOT_PATTERN; //00011101
                2 : begin 
                    parallel_data_o = TxDataHS_i ;
                    TxReadyHS_o     = 1;
                end
                3: begin 
                    parallel_data_o = {8{!parallel_data_o[7]}} ; // Bit Toggle 
                    TxReadyHS_o     = 0;
                    hs_finished     = 1; // ana 5lst ya abla from HS
                end
                default: begin
                    parallel_data_o = 8'h00;
                end
        endcase
    end

    always_ff @( posedge tx_lane_clk_div_i or negedge arstn ) begin
        if(!arstn)
            data_path_cntr <= 0;
        else if (hs_rst)
            data_path_cntr <= 0;
        else if (!TxRequestHS_i && (data_path_cntr == 2))
        begin
            data_path_cntr <= 3;
        end
        else if (data_path_cntr == 2)
            data_path_cntr <= 2;
        else if (send_sot)
            data_path_cntr <= data_path_cntr + 1; 
    end
endmodule
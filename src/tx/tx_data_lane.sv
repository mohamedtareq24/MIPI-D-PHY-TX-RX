`timescale 1ns/1ps
module tx_data_lane(
    input logic arstn, // Asynchronous reset, active low
    tx_data_ppi_if.tx               ppi,
    tx_data_analog_if.digital       analog,
    tx_data_d_phy_if.tx_d_phy_lp    d_phy
);

    // NOTE: simulation-scale placeholders (counts of TxClkEsc cycles). Real MIPI
    // D-PHY LP timings are tens of ns; size these per spec before sign-off.
    localparam logic [15:0] TX_INIT_TIME            = 16'd10;
    localparam logic [15:0] LP_TXDATA_STOP_TIME     = 16'd4;
    localparam logic [15:0] LP_TXDATA_REQ_TIME      = 16'd2;
    localparam logic [15:0] LP_TXDATA_PRPR_TIME     = 16'd2;
    localparam logic [15:0] LP_TXDATA_ZERO_TIME     = 16'd3;
    localparam logic [15:0] LP_TXDATA_TRAIL_TIME    = 16'd3;
    localparam logic [15:0] ULPS_TXDATA_REQ_TIME    = 16'd4;
    localparam logic [15:0] ULPS_TXDATA_EXIT_TIME   = 16'd8;
    localparam logic [7:0]  SOT_PATTERN = 8'hB8;  // LSB-first on wire = 00011101 (spec Table 28 Leader)
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
        ULPS_TXDATA_EXIT,
        LPDT_CMD_SEND,
        LPDT_DATA_MARK,
        LPDT_DATA_SPACE,
        LPDT_EXIT
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
    logic [7:0]  lpdt_byte;   // payload byte being serialized
    logic [2:0]  lpdt_bit;    // current payload bit index (LSB-first)
    logic        lpdt_ready;  // drives ppi.TxReadyEsc_o (1-cycle pulse)

    // CDC synchronizer registers (2-FF level synchronizers)
    // Esc-domain controls -> byte-clock (div) domain
    logic        send_sot_meta, send_sot_div;
    logic        hs_rst_meta,   hs_rst_div;
    // div-domain status -> Esc domain
    logic        hs_finished_meta, hs_finished_esc;

    ///////////////////////////////////////
    //TIMER
    //////////////////////////////////////
    
    // Load-on-transition timer (clock-lane idiom): timer_load is pulsed by the FSM
    // when entering a timed state and loads that state's duration. Must be checked
    // BEFORE the count-down branch, otherwise reloads never happen.
    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn)
    begin
        if (!arstn)
            timer_cntr <= '0;
        else if (!ppi.enable_i)
            timer_cntr <= TX_INIT_TIME;
        else if (timer_load)
            timer_cntr <= timer_value;
        else if (timer_cntr > 0)
            timer_cntr <= timer_cntr - 1;
    end

    always_comb timer_done = (timer_cntr == 0);

    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) 
    begin
        if (!arstn)
            state <= TXDATA_INIT;
        else if (!ppi.enable_i)
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
            // Forced stop must also drive the StopState outputs, not just the
            // next state (otherwise StopState_o stays at its default 0).
            next_state            = LP_TXDATA_STOP;
            d_phy.tx_lane_LP_Dp_o = 1;
            d_phy.tx_lane_LP_Dn_o = 1;
            ppi.StopState_o       = 1;
        end
        else
        case (state)
            TXDATA_INIT: begin
                // TX_INIT_TIME is loaded by the enable_i branch in the timer ff.
                d_phy.tx_lane_LP_Dp_o     = 1;
                d_phy.tx_lane_LP_Dn_o     = 1;
                ppi.StopState_o     = 0;
                if (timer_done) begin
                    next_state  = LP_TXDATA_STOP;
                    timer_load  = 1;                  // arm STOP timer on entry
                    timer_value = LP_TXDATA_STOP_TIME;
                end
                else
                    next_state = TXDATA_INIT;
            end
            LP_TXDATA_STOP: begin
                d_phy.tx_lane_LP_Dp_o = 1;
                d_phy.tx_lane_LP_Dn_o = 1;
                ppi.StopState_o = 1;
                hs_rst = 1;
                if (timer_done) begin
                    if (ppi.TxRequestHS_i) begin
                        next_state  = HS_TXDATA_REQ;
                        timer_load  = 1;                 // arm REQ timer on entry
                        timer_value = LP_TXDATA_REQ_TIME;
                    end
                    else if (ppi.TxRequestEsc_i && ppi.TxLpdtEsc_i) begin
                        next_state = LPDT_CMD_SEND;
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

                if (timer_done && ppi.TxRequestHS_i) begin
                    next_state  = HS_TXDATA_PRPR;
                    timer_load  = 1;                  // arm PRPR timer on entry
                    timer_value = LP_TXDATA_PRPR_TIME;
                end
                else begin
                    next_state = HS_TXDATA_REQ;
                end
            end
            HS_TXDATA_PRPR: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;

                if (timer_done && ppi.TxRequestHS_i) begin
                    next_state  = HS_TXDATA_ZERO;
                    timer_load  = 1;                  // arm ZERO timer on entry
                    timer_value = LP_TXDATA_ZERO_TIME;
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
                if (timer_done && ppi.TxRequestHS_i && ppi.TxDataTransferEnHS_i) begin
                    next_state = HS_TXDATA_SOT;       // SOT is a single cycle, no timer
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

                if (hs_finished_esc) begin            // synchronized div-domain status
                    next_state  = HS_TXDATA_TRAIL;
                    timer_load  = 1;                  // arm TRAIL timer on entry
                    timer_value = LP_TXDATA_TRAIL_TIME;
                end
                else begin
                    next_state = HS_TXDATA_ACTIVE; // Stay in active state until request is deasserted
                end
            end
            HS_TXDATA_TRAIL: begin
                d_phy.tx_lane_LP_Dp_o = 0;
                d_phy.tx_lane_LP_Dn_o = 0;
                analog.serializer_en_o = 1;

                if (timer_done) begin
                    next_state  = LP_TXDATA_STOP; // Transition back to LP mode after trail time
                    hs_rst      = 1;
                    timer_load  = 1;                  // arm STOP timer on entry
                    timer_value = LP_TXDATA_STOP_TIME;
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
                    next_state  = ULPS_TXDATA_EXIT;
                    timer_load  = 1;                    // arm EXIT (wakeup) timer on entry
                    timer_value = ULPS_TXDATA_EXIT_TIME; // Should be Twakeup + some margin
                end
                else begin
                    next_state = ULPS_TXDATA_ACTIVE;
                end
            end
            ULPS_TXDATA_EXIT: begin
                d_phy.tx_lane_LP_Dp_o = 1;
                d_phy.tx_lane_LP_Dn_o = 0;

                ppi.TxUlpsActive_n_o = 1;

                if (timer_done) begin
                    next_state  = LP_TXDATA_STOP;
                    timer_load  = 1;                    // arm STOP timer on entry
                    timer_value = LP_TXDATA_STOP_TIME;
                end
                else begin
                    next_state = ULPS_TXDATA_EXIT;
                end
            end
            LPDT_CMD_SEND: begin
                d_phy.tx_lane_LP_Dp_o = esc_seq[esc_indx];
                d_phy.tx_lane_LP_Dn_o = esc_seq[esc_indx+1];
                // ESC_LPDT[0:39] = entry(8b)+command(32b): the 8th command bit is the
                // Mark at pair 36-37 and its required Space at pair 38-39. The emitted
                // symbol lags esc_indx by one symbol (esc_seq loads a cycle late), so
                // exiting at ==38 drops the command's trailing Space -- it merges the
                // last command Mark with LPDT data bit 0 and the RX loses one bit.
                // Exit at >38 (matching ULPS/TRIGGER_CMD_SEND) emits that final Space
                // before payload. The lag means the esc_indx==40 cycle emits sym 20
                // (Space), not an out-of-range esc_seq[40] read.
                if (esc_indx > 38)
                    next_state = LPDT_DATA_MARK;   // entry+0xE1 done (incl. last Space) -> payload
                else
                    next_state = LPDT_CMD_SEND;
            end
            LPDT_DATA_MARK: begin
                // Mark phase of the current bit: Mark-1 (10) for 1, Mark-0 (01) for 0.
                if (lpdt_byte[lpdt_bit]) begin
                    d_phy.tx_lane_LP_Dp_o = 1; d_phy.tx_lane_LP_Dn_o = 0;
                end
                else begin
                    d_phy.tx_lane_LP_Dp_o = 0; d_phy.tx_lane_LP_Dn_o = 1;
                end
                next_state = LPDT_DATA_SPACE;
            end
            LPDT_DATA_SPACE: begin
                d_phy.tx_lane_LP_Dp_o = 0; d_phy.tx_lane_LP_Dn_o = 0;  // Space
                if (lpdt_bit == 3'd7) begin
                    if (ppi.TxValidEsc_i) next_state = LPDT_DATA_MARK; // more bytes
                    else                  next_state = LPDT_EXIT;
                end
                else begin
                    next_state = LPDT_DATA_MARK;                       // next bit
                end
            end
            LPDT_EXIT: begin
                d_phy.tx_lane_LP_Dp_o = 1; d_phy.tx_lane_LP_Dn_o = 0;  // Mark-1
                next_state = LP_TXDATA_STOP;
            end
            default: next_state = LP_TXDATA_STOP;
        endcase
    end

    assign ppi.TxReadyEsc_o = lpdt_ready;

    // synopsys translate_off
    always_ff @(posedge ppi.TxClkEsc_i) begin
        if (state == LPDT_CMD_SEND || state == LPDT_DATA_MARK ||
            state == LPDT_DATA_SPACE || state == LPDT_EXIT)
            $display("[TXLPDTDBG] %0t state=%s next=%s lpdt_bit=%0d valid=%b req=%b Dp=%b Dn=%b",
                     $time, state.name(), next_state.name(), lpdt_bit,
                     ppi.TxValidEsc_i, ppi.TxRequestEsc_i,
                     d_phy.tx_lane_LP_Dp_o, d_phy.tx_lane_LP_Dn_o);
    end
    // synopsys translate_on

    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn)
    begin
        if (!arstn) begin
            esc_indx    <= 0;
            esc_seq     <= '1;
        end
        // Load the command pattern only on ENTRY to a CMD_SEND state (transition in
        // from a non-CMD_SEND state). Matching on next_state alone re-fired every
        // cycle while looping (next_state stays CMD_SEND until esc_indx>38), which
        // shadowed the increment branch below and froze esc_indx at 0 so the command
        // never advanced or exited (escape hang).
        else if ((next_state == TRIGGER_CMD_SEND || next_state == ULPS_CMD_SEND || next_state == LPDT_CMD_SEND) &&
                 (state != TRIGGER_CMD_SEND && state != ULPS_CMD_SEND && state != LPDT_CMD_SEND)) begin
            esc_indx <= 0;
            case (1)
                ppi.TxLpdtEsc_i:        esc_seq <= ESC_LPDT;
                ppi.TxUlpsEsc_i:        esc_seq <= ESC_ULPS;
                ppi.TxTriggerEsc_i[0]:  esc_seq <= ESC_RESET;
                ppi.TxTriggerEsc_i[1]:  esc_seq <= ESC_HSTEST;
                ppi.TxTriggerEsc_i[2]:  esc_seq <= ESC_UNKNOWN4;
                ppi.TxTriggerEsc_i[3]:  esc_seq <= ESC_UNKNOWN5;
                default:                esc_seq <= '1;
            endcase
        end
        else if (state == TRIGGER_CMD_SEND || state == ULPS_CMD_SEND || state == LPDT_CMD_SEND)
        begin
            if (esc_indx > 38)
                esc_indx <= 8;
            else
                esc_indx <= esc_indx + 2;
        end
        else
            esc_indx <= 0;
    end

    // LPDT payload sequencing: load a byte (pulsing TxReadyEsc) when entering the
    // data phase and at each byte boundary; advance the bit index during the Space.
    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) begin
        if (!arstn) begin
            lpdt_byte  <= '0;
            lpdt_bit   <= '0;
            lpdt_ready <= 1'b0;
        end
        else begin
            lpdt_ready <= 1'b0;  // default: 1-cycle pulse
            if (state == LPDT_CMD_SEND && next_state == LPDT_DATA_MARK) begin
                lpdt_byte  <= ppi.TxDataEsc_i;   // first byte
                lpdt_bit   <= 3'd0;
                lpdt_ready <= 1'b1;
            end
            else if (state == LPDT_DATA_SPACE) begin
                if (lpdt_bit == 3'd7) begin
                    if (ppi.TxValidEsc_i) begin
                        lpdt_byte  <= ppi.TxDataEsc_i;   // next byte
                        lpdt_bit   <= 3'd0;
                        lpdt_ready <= 1'b1;
                    end
                end
                else begin
                    lpdt_bit <= lpdt_bit + 3'd1;
                end
            end
        end
    end

    // Need some CDC here 
    always_comb 
    begin
        analog.parallel_data_o = 8'h00;
        ppi.TxReadyHS_o = 0;
        hs_finished = 0;
        case(data_path_cntr)
                0 : analog.parallel_data_o = 0 ;
                1 : analog.parallel_data_o = SOT_PATTERN; // 0xB8 -> LSB-first wire 00011101
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

    ///////////////////////////////////////
    // CDC: 2-FF level synchronizers
    //////////////////////////////////////
    // Esc-domain control levels (send_sot, hs_rst) -> byte-clock (div) domain.
    always_ff @(posedge analog.tx_lane_clk_div_i or negedge arstn) begin
        if (!arstn) begin
            send_sot_meta <= 1'b0;
            send_sot_div  <= 1'b0;
            hs_rst_meta   <= 1'b0;
            hs_rst_div    <= 1'b0;
        end
        else begin
            send_sot_meta <= send_sot;
            send_sot_div  <= send_sot_meta;
            hs_rst_meta   <= hs_rst;
            hs_rst_div    <= hs_rst_meta;
        end
    end

    // div-domain status level (hs_finished) -> Esc domain, consumed by the FSM.
    always_ff @(posedge ppi.TxClkEsc_i or negedge arstn) begin
        if (!arstn) begin
            hs_finished_meta <= 1'b0;
            hs_finished_esc  <= 1'b0;
        end
        else begin
            hs_finished_meta <= hs_finished;
            hs_finished_esc  <= hs_finished_meta;
        end
    end

    always_ff @( posedge analog.tx_lane_clk_div_i or negedge arstn ) begin
        if(!arstn)
            data_path_cntr <= 0;
        else if (hs_rst_div)
            data_path_cntr <= 0;
        // NOTE: ppi.TxRequestHS_i is a slow Esc-domain control read here; it is held
        // stable across the HS burst so it is not separately synchronized (per plan).
        else if (!ppi.TxRequestHS_i && (data_path_cntr == 2))
        begin
            data_path_cntr <= 3;
        end
        else if (data_path_cntr == 2)
            data_path_cntr <= 2;
        else if (send_sot_div)
            data_path_cntr <= data_path_cntr + 1;
    end
endmodule
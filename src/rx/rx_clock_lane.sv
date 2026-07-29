`timescale 1ns/1ps
// RX clock lane (digital). Tracks the LP line state, detects the HS-clock entry
// and ULPS enter/exit, and forwards the recovered byte clock. See docs/RX_PHY_SCOPE.md.
//
// Clocking: refclk_i is a free-running sample clock for the LP FSM (the RX has no
// controller-supplied escape clock, and rx_byte_clk runs only during HS).
//
// LP line code {lp_rxp, lp_rxn} (matches what the TX clock lane drives):
//   2'b11 Stop   2'b01 HS-request   2'b10 ULPS-request/mark   2'b00 bridge/zero
module rx_clock_lane (
    input logic               arstn,     // async reset, active low
    input logic               refclk_i,  // LP sample / FSM clock (free-running)
    rx_clk_ppi_if.rx          ppi,
    rx_clk_analog_if.digital  analog
);

    typedef enum int {
        RX_CLK_INIT,
        RX_CLK_STOP,
        RX_HS_RQST,
        RX_HS_ZERO,
        RX_HS_ACTIVE,
        RX_ULPS_RQST,
        RX_ULPS_ACTIVE,
        RX_ULPS_EXIT
    } rx_clk_state_e;

    rx_clk_state_e state, next_state;

    // Line-state decode (combinational).
    localparam logic [1:0] LP_STOP    = 2'b11;
    localparam logic [1:0] LP_HS_RQ   = 2'b01;
    localparam logic [1:0] LP_ULPS_RQ = 2'b10;
    localparam logic [1:0] LP_ZERO    = 2'b00;

    logic [1:0] lp_code;
    assign lp_code = {analog.lp_rxp_i, analog.lp_rxn_i};

    logic enabled;
    assign enabled = ppi.Enable_i & ppi.Shutdownz_i;

    // State register.
    always_ff @(posedge refclk_i or negedge arstn) begin
        if (!arstn)
            state <= RX_CLK_INIT;
        else if (!enabled)
            state <= RX_CLK_INIT;
        else
            state <= next_state;
    end

    // Next-state logic.
    always_comb begin
        next_state = state;
        case (state)
            RX_CLK_INIT: begin
                if (lp_code == LP_STOP) next_state = RX_CLK_STOP;
            end
            RX_CLK_STOP: begin
                if      (lp_code == LP_HS_RQ)   next_state = RX_HS_RQST;
                else if (lp_code == LP_ULPS_RQ) next_state = RX_ULPS_RQST;
            end
            RX_HS_RQST: begin
                if      (lp_code == LP_ZERO) next_state = RX_HS_ZERO;
                else if (lp_code == LP_STOP) next_state = RX_CLK_STOP; // aborted
            end
            RX_HS_ZERO: begin
                if      (analog.hs_clk_active_i) next_state = RX_HS_ACTIVE;
                else if (lp_code == LP_STOP)     next_state = RX_CLK_STOP;
            end
            RX_HS_ACTIVE: begin
                // HS clock stopped -> lane returns to LP stop.
                if (!analog.hs_clk_active_i) next_state = RX_CLK_STOP;
            end
            RX_ULPS_RQST: begin
                if      (lp_code == LP_ZERO) next_state = RX_ULPS_ACTIVE;
                else if (lp_code == LP_STOP) next_state = RX_CLK_STOP; // aborted
            end
            RX_ULPS_ACTIVE: begin
                // Exit begins with a Mark-1 (ULPS-request code) before returning to stop.
                if (lp_code == LP_ULPS_RQ) next_state = RX_ULPS_EXIT;
            end
            RX_ULPS_EXIT: begin
                if (lp_code == LP_STOP) next_state = RX_CLK_STOP;
            end
            default: next_state = RX_CLK_INIT;
        endcase
    end

    // Output decode (combinational from state).
    always_comb begin
        ppi.StopState_o        = 1'b0;
        ppi.RxClkActiveHS_o    = 1'b0;
        ppi.RxUlpsActiveNot_o  = 1'b1;   // active-low: 1 => not in ULPS
        ppi.RxByteClkHS_o      = 1'b0;
        ppi.ErrControl_o       = 1'b0;   // control-error detection: later refinement
        analog.hs_rx_en_o      = 1'b0;

        case (state)
            RX_CLK_STOP:    ppi.StopState_o = 1'b1;
            RX_HS_ZERO:     analog.hs_rx_en_o = 1'b1;   // arm HS receiver to detect the clock
            RX_HS_ACTIVE: begin
                ppi.RxClkActiveHS_o = 1'b1;
                analog.hs_rx_en_o   = 1'b1;
                ppi.RxByteClkHS_o   = analog.rx_byte_clk_i; // forward recovered byte clock
            end
            RX_ULPS_ACTIVE: ppi.RxUlpsActiveNot_o = 1'b0;
            default: ; // INIT / RQST / EXIT: idle defaults
        endcase
    end

endmodule

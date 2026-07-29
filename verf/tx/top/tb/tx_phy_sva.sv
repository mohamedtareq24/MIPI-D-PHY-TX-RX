`timescale 1ns/1ps
// Data-lane protocol + cross-lane system assertions for the integrated TX-PHY.
// Clocked on the shared Esc clock (LP/protocol domain).
module tx_phy_sva (
    input  logic       arstn,
    tx_clk_ppi_if      clk_ppi,
    tx_data_ppi_if     data_ppi,
    tx_data_d_phy_if   data_d_phy,
    input  logic       data_ser_en   // data-lane serializer enable
);
    import mipi_spec_pkg::*;   // golden LP-state codes (spec oracle)

    logic [1:0] D_LP;
    assign D_LP = {data_d_phy.tx_lane_LP_Dp_o, data_d_phy.tx_lane_LP_Dn_o};

    // -------- Data-lane protocol --------

    // HS request is only issued from StopState.
    property data_stopstate_on_hs_req;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            $rose(data_ppi.TxRequestHS_i) |-> data_ppi.StopState_o;
    endproperty

    // HS entry drives the LP line sequence Stop(11) -> Req(01) -> Bridge(00).
    property data_hs_lp_sequence;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            $rose(data_ppi.TxRequestHS_i) |->
                (D_LP == LP_STOP) ##[1:$] (D_LP == LP_HSREQ) ##[1:$] (D_LP == LP_SPACE);
    endproperty

    // TxReadyHS is only asserted while the serializer is enabled.
    property data_readyhs_implies_seren;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            data_ppi.TxReadyHS_o |-> data_ser_en;
    endproperty

    // When ULPS becomes active the LP lines are driven to 00.
    property data_ulps_lp00;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            $fell(data_ppi.TxUlpsActive_n_o) |-> (D_LP == LP_SPACE);
    endproperty

    // Forced stop drives the data lane to StopState.
    property data_force_stop;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            data_ppi.ForceTXStopmode_i |-> ##[0:3] data_ppi.StopState_o;
    endproperty

    // -------- Cross-lane system --------

    // Forced stop eventually drives the clock lane to StopState. (Liveness, not
    // bounded: the clock lane completes its T_INIT before honoring stop, unlike
    // the data lane which asserts StopState immediately on ForceTXStopmode.)
    property clk_force_stop;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            $rose(clk_ppi.ForceTXStopmode_i) |-> ##[1:$] clk_ppi.StopState_o;
    endproperty

    // Data HS (serializer active) only while the clock lane is in HS (D-PHY
    // clock-before-data: the byte clock the data lane needs comes from clock HS).
    property data_hs_requires_clk_hs;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            data_ser_en |-> clk_ppi.TxReadyHS_o;
    endproperty

    // Data lane is doing an escape op when a request is held without an HS request.
    // (LPDT/ULPS/trigger all assert TxRequestEsc_i; HS uses TxRequestHS_i.)
    logic data_escape_active;
    assign data_escape_active = data_ppi.TxRequestEsc_i && !data_ppi.TxRequestHS_i;

    // A. Clock lane is in HS BEFORE the data serializer starts (T_CLK-PRE): when
    // the data serializer rises, the clock lane is already in HS.
    property xlane_clk_pre;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            $rose(data_ser_en) |-> clk_ppi.TxReadyHS_o;
    endproperty

    // A. Clock lane stays in HS until AFTER the data burst ends (T_CLK-POST): the
    // clock lane does not leave HS while the data serializer is active.
    property xlane_clk_post;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            (data_ser_en && clk_ppi.TxReadyHS_o) |=> (clk_ppi.TxReadyHS_o || !data_ser_en);
    endproperty

    // B. While the data lane is in an escape op (incl. LPDT), the clock lane is
    // NOT in HS (escape uses the Esc clock, never the HS byte clock).
    property xlane_escape_clk_lp;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            data_escape_active |-> !clk_ppi.TxReadyHS_o;
    endproperty

    // C. ForceTXStopmode brings BOTH lanes to StopState (data immediately, clock
    // eventually).
    property xlane_force_stop_both;
        @(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
            data_ppi.ForceTXStopmode_i |->
                (##[0:3] data_ppi.StopState_o) and (s_eventually clk_ppi.StopState_o);
    endproperty

    a_data_stopstate_on_hs_req : assert property (data_stopstate_on_hs_req)
        else $error("SVA_DATA_HSREQ: TxRequestHS_i rose while data lane not in StopState");
    a_data_hs_lp_sequence : assert property (data_hs_lp_sequence)
        else $error("SVA_DATA_HSSEQ: data lane LP sequence after TxRequestHS_i invalid (D_LP=%b)", D_LP);
    a_data_readyhs_implies_seren : assert property (data_readyhs_implies_seren)
        else $error("SVA_DATA_READY: TxReadyHS_o asserted while serializer disabled");
    a_data_ulps_lp00 : assert property (data_ulps_lp00)
        else $error("SVA_DATA_ULPS: ULPS active but data LP lines not 00 (D_LP=%b)", D_LP);
    a_data_force_stop : assert property (data_force_stop)
        else $error("SVA_DATA_FORCE: ForceTXStopmode did not drive data StopState");
    a_clk_force_stop : assert property (clk_force_stop)
        else $error("SVA_CLK_FORCE: ForceTXStopmode did not drive clock StopState");
    a_data_hs_requires_clk_hs : assert property (data_hs_requires_clk_hs)
        else $error("SVA_XLANE_CLKHS: data serializer active while clock lane not in HS");
    a_xlane_clk_pre : assert property (xlane_clk_pre)
        else $error("SVA_XLANE_PRE: data serializer started before clock lane in HS (T_CLK-PRE violated)");
    a_xlane_clk_post : assert property (xlane_clk_post)
        else $error("SVA_XLANE_POST: clock lane left HS while data serializer still active (T_CLK-POST violated)");
    a_xlane_escape_clk_lp : assert property (xlane_escape_clk_lp)
        else $error("SVA_XLANE_ESC: clock lane in HS while data lane in escape/LPDT");
    a_xlane_force_stop_both : assert property (xlane_force_stop_both)
        else $error("SVA_XLANE_STOP: ForceTXStopmode did not bring both lanes to StopState");

    // -------- Cover: key protocol events were exercised --------
    c_hs_burst : cover property (@(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
        $rose(data_ppi.TxRequestHS_i));
    c_ulps_enter : cover property (@(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
        $fell(data_ppi.TxUlpsActive_n_o));
    c_ulps_exit : cover property (@(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
        $rose(data_ppi.TxUlpsExit_i));
    c_trigger : cover property (@(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
        $rose(data_ppi.TxRequestEsc_i) && (|data_ppi.TxTriggerEsc_i));
    c_lpdt : cover property (@(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
        $rose(data_ppi.TxRequestEsc_i) && data_ppi.TxLpdtEsc_i);
    c_xlane_pre : cover property (@(posedge data_ppi.TxClkEsc_i) disable iff (!arstn)
        $rose(data_ser_en) && clk_ppi.TxReadyHS_o);

endmodule

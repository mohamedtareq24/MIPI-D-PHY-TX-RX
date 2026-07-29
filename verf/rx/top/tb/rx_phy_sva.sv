`timescale 1ns/1ps
// =============================================================================
// rx_phy_sva — RX D-PHY protocol / timing / sequencing assertions.
//
// These check the SPEC (docs/MIPI_DPHY_SPEC_REQUIREMENTS.md), not the design.
// The scoreboard checks payload integrity; this module checks everything the
// scoreboard cannot see: the PPI HS handshake, escape wire-legality, and the
// cross-lane clock-before-data relationship.
//
// Two sample domains:
//   - byte-clock domain (clk_ppi.RxByteClkHS_o): HS PPI handshake.
//   - refclk domain (LP FSM sample clock): escape / LP-line legality, cross-lane.
// =============================================================================
module rx_phy_sva (
    input  logic     arstn,
    input  logic     refclk,
    rx_clk_ppi_if    clk_ppi,
    rx_data_ppi_if   data_ppi,
    rx_data_d_phy_if data_dp
);
    import mipi_spec_pkg::*;

    // Driven data-lane LP line state (the actual wire).
    logic [1:0] LP_D;
    assign LP_D = {data_dp.data_LP_Dp_i, data_dp.data_LP_Dn_i};

    // -------------------------------------------------------------------------
    // HS PPI handshake (byte-clock domain)
    // -------------------------------------------------------------------------

    // RxValidHS may be asserted only while RxActiveHS (spec §1.2).
    property p_valid_in_active;
        @(posedge clk_ppi.RxByteClkHS_o) disable iff (!arstn)
            data_ppi.RxValidHS_o |-> data_ppi.RxActiveHS_o;
    endproperty

    // RxSyncHS may be asserted only while RxActiveHS (spec §1.2).
    property p_sync_in_active;
        @(posedge clk_ppi.RxByteClkHS_o) disable iff (!arstn)
            data_ppi.RxSyncHS_o |-> data_ppi.RxActiveHS_o;
    endproperty

    // RxSyncHS is a single-cycle pulse: at most one sync per burst (spec §1.2).
    property p_sync_one_pulse;
        @(posedge clk_ppi.RxByteClkHS_o) disable iff (!arstn)
            data_ppi.RxSyncHS_o |=> !data_ppi.RxSyncHS_o;
    endproperty

    a_valid_in_active : assert property (p_valid_in_active)
        else uvm_pkg::uvm_report_error("RXSVA_VALID_ACTIVE",
            $sformatf("RxValidHS_o=1 while RxActiveHS_o=0 at %0t (valid asserted outside active burst)", $time),
            uvm_pkg::UVM_NONE);
    a_sync_in_active : assert property (p_sync_in_active)
        else uvm_pkg::uvm_report_error("RXSVA_SYNC_ACTIVE",
            $sformatf("RxSyncHS_o=1 while RxActiveHS_o=0 at %0t", $time), uvm_pkg::UVM_NONE);
    a_sync_one_pulse : assert property (p_sync_one_pulse)
        else uvm_pkg::uvm_report_error("RXSVA_SYNC_PULSE",
            $sformatf("RxSyncHS_o asserted for more than one byte-clock at %0t (multiple SoT syncs in a burst)", $time),
            uvm_pkg::UVM_NONE);

    // -------------------------------------------------------------------------
    // Escape / LP-line legality + HS framing vs the wire (refclk domain)
    // -------------------------------------------------------------------------

    // RxTriggerEsc is one-hot (or zero) — never two triggers at once (spec §2.2).
    property p_trigger_onehot0;
        @(posedge refclk) disable iff (!arstn)
            $onehot0(data_ppi.RxTriggerEsc_o);
    endproperty

    // Escape entry on the wire is legal: Mark-1 (from Stop) -> Space -> HS-request
    // -> Space, before any command symbols (spec §2.1). Mark-1 from Stop uniquely
    // begins an escape (HS entry begins with HS-request, not Mark-1).
    property p_esc_entry_legal;
        @(posedge refclk) disable iff (!arstn)
            (LP_D == LP_MARK1 && $past(LP_D) == LP_STOP) |->
                ##[1:$] (LP_D == LP_SPACE)
                ##[1:$] (LP_D == LP_HSREQ)
                ##[1:$] (LP_D == LP_SPACE);
    endproperty

    // A completed HS entry on the wire (HS-request -> Space) must eventually bring
    // up RxActiveHS (spec §1.2). Liveness, unbounded above.
    property p_hs_entry_to_active;
        @(posedge refclk) disable iff (!arstn)
            ($rose(LP_D == LP_SPACE) && $past(LP_D) == LP_HSREQ) |->
                ##[1:$] data_ppi.RxActiveHS_o;
    endproperty

    // End of transmission: once the data line is back in Stop, an in-progress HS
    // burst must end (RxActiveHS deasserts). Liveness (spec §1.2).
    property p_eot_active_drop;
        @(posedge refclk) disable iff (!arstn)
            (data_ppi.RxActiveHS_o && LP_D == LP_STOP) |->
                ##[1:$] !data_ppi.RxActiveHS_o;
    endproperty

    // ULPS PPI consistency: RxUlpsEsc and RxUlpsActiveNot are complementary.
    property p_ulps_consistent;
        @(posedge refclk) disable iff (!arstn)
            data_ppi.RxUlpsEsc_o |-> !data_ppi.RxUlpsActiveNot_o;
    endproperty

    // -------------------------------------------------------------------------
    // Cross-lane: clock-before-data. HS data reception requires the clock lane in
    // HS-active (the byte clock the data lane needs) (spec §3).
    // -------------------------------------------------------------------------
    property p_data_hs_requires_clk_hs;
        @(posedge refclk) disable iff (!arstn)
            data_ppi.RxActiveHS_o |-> clk_ppi.RxClkActiveHS_o;
    endproperty

    // A (mirror). Recovered clock lane is in HS before/through the data-lane HS
    // burst: when RxActiveHS rises, the clock lane is already HS-active, and the
    // clock lane does not drop HS while the data burst is active.
    property p_rx_clk_pre;
        @(posedge refclk) disable iff (!arstn)
            $rose(data_ppi.RxActiveHS_o) |-> clk_ppi.RxClkActiveHS_o;
    endproperty
    property p_rx_clk_post;
        @(posedge refclk) disable iff (!arstn)
            (data_ppi.RxActiveHS_o && clk_ppi.RxClkActiveHS_o) |=>
                (clk_ppi.RxClkActiveHS_o || !data_ppi.RxActiveHS_o);
    endproperty

    // B (mirror). While the data lane is receiving an escape op (LPDT/ULPS) the
    // clock lane is NOT in HS.
    property p_rx_escape_clk_lp;
        @(posedge refclk) disable iff (!arstn)
            (data_ppi.RxLpdtEsc_o || data_ppi.RxUlpsEsc_o) |-> !clk_ppi.RxClkActiveHS_o;
    endproperty

    a_trigger_onehot0 : assert property (p_trigger_onehot0)
        else uvm_pkg::uvm_report_error("RXSVA_TRGR_ONEHOT",
            $sformatf("RxTriggerEsc_o not one-hot/zero (%b) at %0t", data_ppi.RxTriggerEsc_o, $time), uvm_pkg::UVM_NONE);
    a_esc_entry_legal : assert property (p_esc_entry_legal)
        else uvm_pkg::uvm_report_error("RXSVA_ESC_ENTRY",
            $sformatf("Illegal escape entry LP sequence on the wire at %0t (expect Mark1->Space->HSreq->Space)", $time),
            uvm_pkg::UVM_NONE);
    a_hs_entry_to_active : assert property (p_hs_entry_to_active)
        else uvm_pkg::uvm_report_error("RXSVA_HS_ENTRY",
            $sformatf("HS entry on the wire did not bring up RxActiveHS_o (started %0t)", $time), uvm_pkg::UVM_NONE);
    a_eot_active_drop : assert property (p_eot_active_drop)
        else uvm_pkg::uvm_report_error("RXSVA_EOT",
            $sformatf("Data line returned to Stop but RxActiveHS_o never deasserted (from %0t)", $time), uvm_pkg::UVM_NONE);
    a_ulps_consistent : assert property (p_ulps_consistent)
        else uvm_pkg::uvm_report_error("RXSVA_ULPS",
            $sformatf("RxUlpsEsc_o=1 but RxUlpsActiveNot_o=1 at %0t", $time), uvm_pkg::UVM_NONE);
    a_data_hs_requires_clk_hs : assert property (p_data_hs_requires_clk_hs)
        else uvm_pkg::uvm_report_error("RXSVA_XLANE_CLKHS",
            $sformatf("Data RxActiveHS_o high while clock lane not in HS (RxClkActiveHS_o=0) at %0t", $time),
            uvm_pkg::UVM_NONE);
    a_rx_clk_pre : assert property (p_rx_clk_pre)
        else uvm_pkg::uvm_report_error("RXSVA_XLANE_PRE",
            $sformatf("RxActiveHS rose while clock lane not HS-active at %0t", $time), uvm_pkg::UVM_NONE);
    a_rx_clk_post : assert property (p_rx_clk_post)
        else uvm_pkg::uvm_report_error("RXSVA_XLANE_POST",
            $sformatf("Clock lane dropped HS while RxActiveHS still high at %0t", $time), uvm_pkg::UVM_NONE);
    a_rx_escape_clk_lp : assert property (p_rx_escape_clk_lp)
        else uvm_pkg::uvm_report_error("RXSVA_XLANE_ESC",
            $sformatf("Clock lane HS-active while data lane in escape/LPDT at %0t", $time), uvm_pkg::UVM_NONE);

    // -------------------------------------------------------------------------
    // Cover: key protocol events exercised
    // -------------------------------------------------------------------------
    c_hs_active  : cover property (@(posedge refclk) disable iff (!arstn) $rose(data_ppi.RxActiveHS_o));
    c_sync       : cover property (@(posedge clk_ppi.RxByteClkHS_o) disable iff (!arstn) data_ppi.RxSyncHS_o);
    c_ulps_enter : cover property (@(posedge refclk) disable iff (!arstn) $fell(data_ppi.RxUlpsActiveNot_o));
    c_trigger    : cover property (@(posedge refclk) disable iff (!arstn) $rose(|data_ppi.RxTriggerEsc_o));
    c_esc_entry  : cover property (@(posedge refclk) disable iff (!arstn)
                    (LP_D == LP_MARK1 && $past(LP_D) == LP_STOP));
    c_lpdt       : cover property (@(posedge refclk) disable iff (!arstn) $rose(data_ppi.RxLpdtEsc_o));

endmodule

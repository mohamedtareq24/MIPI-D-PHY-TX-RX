`timescale 1ns/1ps
// RX data lane (digital). See docs/RX_PHY_SCOPE.md.
//
// Two domains (mirror of the TX data lane):
//   - LP / escape FSM on refclk_i (free-running sample clock).
//   - HS byte path on analog.rx_lane_clk_div_i (recovered byte clock).
//   hs_arm crosses refclk -> byte-clock through a 2-FF synchronizer.
//
// LP line code {lp_rxp, lp_rxn} (matches what the TX data lane drives):
//   2'b11 Stop   2'b01 HS-request   2'b10 Mark-1 / escape-entry   2'b00 bridge/space
//
// Scope: HS receive (<1.5 Gbps) + Escape (ULPS, Remote triggers, LPDT receive).
module rx_data_lane (
    input logic                arstn,     // async reset, active low
    input logic                refclk_i,  // LP sample / FSM clock (free-running)
    rx_data_ppi_if.rx          ppi,
    rx_data_analog_if.digital  analog
);

    localparam logic [7:0] SOT_SYNC   = 8'hB8;  // HS SoT sync; LSB-first on wire = 00011101 (spec Table 28 Leader)
    localparam int         SYNC_LIMIT = 16;     // byte-clocks to find SoT before ErrSotSyncHS

    // Escape entry command codes (spec D-PHY v2.5 Table 10). The byte literal is the
    // pattern "first bit transmitted to last" read MSB->LSB, so it is deserialized
    // MSB-first (see LP_ESC_CMD).
    localparam logic [7:0] CMD_ULPS   = 8'h1E;  // Ultra-Low Power State : 00011110
    localparam logic [7:0] CMD_TRGR0  = 8'h62;  // Reset-Trigger         : 01100010
    localparam logic [7:0] CMD_TRGR1  = 8'h5D;  // HS-Test Trigger       : 01011101
    localparam logic [7:0] CMD_TRGR2  = 8'h21;  // Unknown-4 Trigger     : 00100001
    localparam logic [7:0] CMD_TRGR3  = 8'hA0;  // Unknown-5 Trigger     : 10100000
    localparam logic [7:0] CMD_LPDT   = 8'hE1;  // Low-Power Data Transmission : 11100001

    logic [1:0] lp_code;
    assign lp_code = {analog.lp_rxp_i, analog.lp_rxn_i};

    localparam logic [1:0] LP_STOP = 2'b11;
    localparam logic [1:0] LP_HSRQ = 2'b01;
    localparam logic [1:0] LP_MARK = 2'b10;
    localparam logic [1:0] LP_SPC  = 2'b00;

    logic enabled;
    assign enabled = ppi.Enable_i & ppi.Shutdownz_i;

    // ----------------------------------------------------------------------
    // LP / escape FSM (refclk domain)
    // ----------------------------------------------------------------------
    typedef enum int {
        LP_INIT, LP_STOPST, LP_HS_RQ, LP_HS_GO,
        LP_ESC_E1, LP_ESC_E2, LP_ESC_E3, LP_ESC_CMD, LP_ESC_WAIT,
        LP_ULPS, LP_ULPS_EXIT, LP_LPDT_RX
    } lp_state_e;

    lp_state_e  lp_state;
    logic       hs_arm;            // request analog HS receiver (to byte-clock domain)
    logic [1:0] prev_lp;
    logic [7:0] esc_shift;
    logic [3:0] esc_cnt;

    // LPDT payload receive registers
    logic [7:0] lpdt_shift;
    logic [3:0] lpdt_cnt;
    logic [7:0] rxdataesc_q;
    logic       lpdt_armed;  // set by a payload Space->Mark leading edge seen in-state

    // registered escape pulse outputs
    logic       rxclkesc_q, rxvalidesc_q, erresc_q;
    logic [3:0] rxtrigger_q;

    always_ff @(posedge refclk_i or negedge arstn) begin
        if (!arstn) begin
            lp_state     <= LP_INIT;
            hs_arm       <= 1'b0;
            prev_lp      <= LP_STOP;
            esc_shift    <= '0;
            esc_cnt      <= '0;
            lpdt_shift   <= '0;
            lpdt_cnt     <= '0;
            rxdataesc_q  <= '0;
            lpdt_armed   <= 1'b0;
            rxclkesc_q   <= 1'b0;
            rxvalidesc_q <= 1'b0;
            erresc_q     <= 1'b0;
            rxtrigger_q  <= '0;
        end
        else if (!enabled) begin
            lp_state     <= LP_INIT;
            hs_arm       <= 1'b0;
            rxclkesc_q   <= 1'b0;
            rxvalidesc_q <= 1'b0;
            erresc_q     <= 1'b0;
            rxtrigger_q  <= '0;
        end
        else begin
            // one-cycle defaults
            rxclkesc_q   <= 1'b0;
            rxvalidesc_q <= 1'b0;
            erresc_q     <= 1'b0;
            rxtrigger_q  <= '0;
            prev_lp      <= lp_code;

            // synopsys translate_off
            if (lp_state == LP_ESC_CMD || lp_state == LP_LPDT_RX)
                $display("[LPDTDBG] %0t state=%s prev=%b code=%b esc_cnt=%0d lpdt_cnt=%0d armed=%b shift=%b",
                         $time, lp_state.name(), prev_lp, lp_code, esc_cnt, lpdt_cnt, lpdt_armed, lpdt_shift);
            // synopsys translate_on

            case (lp_state)
                LP_INIT: begin
                    if (lp_code == LP_STOP) lp_state <= LP_STOPST;
                end
                LP_STOPST: begin
                    hs_arm  <= 1'b0;
                    esc_cnt <= '0;
                    if      (lp_code == LP_HSRQ) lp_state <= LP_HS_RQ;
                    else if (lp_code == LP_MARK) lp_state <= LP_ESC_E1;
                end
                // ---- HS entry ----
                LP_HS_RQ: begin
                    if      (lp_code == LP_SPC)  lp_state <= LP_HS_GO;
                    else if (lp_code == LP_STOP) lp_state <= LP_STOPST;
                end
                LP_HS_GO: begin
                    hs_arm <= 1'b1;                 // analog samples HS; byte path aligns
                    if (lp_code == LP_STOP) begin   // HS burst ended
                        hs_arm   <= 1'b0;
                        lp_state <= LP_STOPST;
                    end
                end
                // ---- Escape entry: Mark-1 -> space -> HS-req -> space ----
                LP_ESC_E1: begin
                    if      (lp_code == LP_SPC)  lp_state <= LP_ESC_E2;
                    else if (lp_code == LP_STOP) lp_state <= LP_STOPST;
                end
                LP_ESC_E2: begin
                    if      (lp_code == LP_HSRQ) lp_state <= LP_ESC_E3;
                    else if (lp_code == LP_STOP) lp_state <= LP_STOPST;
                end
                LP_ESC_E3: begin
                    if (lp_code == LP_SPC) begin
                        lp_state  <= LP_ESC_CMD;
                        esc_cnt   <= '0;
                        esc_shift <= '0;
                    end
                end
                // ---- Escape command deserialize (spaced-one-hot, simplified) ----
                // A symbol is a non-space code following a space; 01->0, 10->1.
                // MSB-first per spec Table 10 ("first bit transmitted to last"): the
                // first symbol is the MSB of the command byte, so each new bit shifts
                // in at the LSB end. The assembled byte equals the CMD_* literal.
                LP_ESC_CMD: begin
                    if ((prev_lp == LP_SPC) && (lp_code == LP_HSRQ || lp_code == LP_MARK)) begin
                        esc_shift    <= {esc_shift[6:0], (lp_code == LP_MARK)};
                        esc_cnt      <= esc_cnt + 4'd1;
                        rxclkesc_q   <= 1'b1;
                        rxvalidesc_q <= 1'b1;
                    end
                    else if (esc_cnt == 4'd8) begin   // all 8 bits captured
                        unique case (esc_shift)
                            CMD_ULPS:  lp_state <= LP_ULPS;
                            CMD_TRGR0: begin rxtrigger_q <= 4'b0001; lp_state <= LP_ESC_WAIT; end
                            CMD_TRGR1: begin rxtrigger_q <= 4'b0010; lp_state <= LP_ESC_WAIT; end
                            CMD_TRGR2: begin rxtrigger_q <= 4'b0100; lp_state <= LP_ESC_WAIT; end
                            CMD_TRGR3: begin rxtrigger_q <= 4'b1000; lp_state <= LP_ESC_WAIT; end
                            CMD_LPDT:  begin lp_state <= LP_LPDT_RX; lpdt_cnt <= '0; lpdt_shift <= '0; lpdt_armed <= 1'b0; end
                            default:   begin erresc_q <= 1'b1;       lp_state <= LP_ESC_WAIT; end
                        endcase
                    end
                    else if (lp_code == LP_STOP) begin
                        lp_state <= LP_STOPST;       // aborted escape
                    end
                end
                LP_ESC_WAIT: begin
                    if (lp_code == LP_STOP) lp_state <= LP_STOPST;
                end
                // ---- ULPS ----
                LP_ULPS: begin
                    if (lp_code == LP_MARK) lp_state <= LP_ULPS_EXIT; // Mark-1 begins exit
                end
                LP_ULPS_EXIT: begin
                    if (lp_code == LP_STOP) lp_state <= LP_STOPST;
                end
                // ---- LPDT payload receive (spaced-one-hot, LSB-first) ----
                // A payload bit is armed by its own in-state Space->Mark leading edge
                // and its VALUE is decoded on the following Mark->Space trailing edge.
                // Decoding the value on the trailing edge is what keeps the exit safe:
                // the exit flag is a Mark-1 followed by Stop (no trailing Space), so it
                // never decodes a bit; Stop (checked first) ends LPDT.
                // The "armed" gate makes this symbol-width independent: the command's
                // residual last Mark had its leading edge back in LP_ESC_CMD, so it is
                // never armed here and its trailing Space is never counted at any symbol
                // width. Bytes are recovered LSB-first: right-shift, insert at the MSB.
                LP_LPDT_RX: begin
                    if (lp_code == LP_STOP) begin
                        lp_state <= LP_STOPST;
                    end
                    else if ((prev_lp == LP_SPC) && (lp_code == LP_MARK || lp_code == LP_HSRQ)) begin
                        lpdt_armed <= 1'b1;             // leading edge into a payload Mark
                    end
                    else if (lpdt_armed && (prev_lp == LP_MARK || prev_lp == LP_HSRQ) && (lp_code == LP_SPC)) begin
                        lpdt_armed <= 1'b0;
                        lpdt_shift <= {(prev_lp == LP_MARK), lpdt_shift[7:1]};
                        if (lpdt_cnt == 4'd7) begin
                            rxdataesc_q  <= {(prev_lp == LP_MARK), lpdt_shift[7:1]};
                            rxvalidesc_q <= 1'b1;
                            rxclkesc_q   <= 1'b1;
                            lpdt_cnt     <= '0;
                            // synopsys translate_off
                            $display("[LPDTBYTE] %0t emit=%0d (0x%02h)", $time,
                                     {(prev_lp == LP_MARK), lpdt_shift[7:1]},
                                     {(prev_lp == LP_MARK), lpdt_shift[7:1]});
                            // synopsys translate_on
                        end
                        else begin
                            lpdt_cnt <= lpdt_cnt + 4'd1;
                        end
                    end
                end
                default: lp_state <= LP_INIT;
            endcase
        end
    end

    // State-derived (combinational) outputs.
    always_comb begin
        ppi.StopState_o       = (lp_state == LP_STOPST);
        analog.hs_rx_en_o     = hs_arm;
        ppi.RxUlpsEsc_o       = (lp_state == LP_ULPS);
        ppi.RxUlpsActiveNot_o = !(lp_state == LP_ULPS); // active-low
        ppi.RxLpdtEsc_o       = (lp_state == LP_LPDT_RX);
        ppi.ErrSotHS_o        = 1'b0;   // recoverable-SoT detection: later refinement
        ppi.ErrControl_o      = 1'b0;   // LP control-error detection: later refinement
    end

    assign ppi.RxClkEsc_o     = rxclkesc_q;
    assign ppi.RxValidEsc_o   = rxvalidesc_q;
    assign ppi.RxTriggerEsc_o = rxtrigger_q;
    assign ppi.ErrEsc_o       = erresc_q;
    assign ppi.RxDataEsc_o    = rxdataesc_q;

    // ----------------------------------------------------------------------
    // hs_arm: refclk -> byte-clock 2-FF synchronizer
    // ----------------------------------------------------------------------
    logic hs_en_meta, hs_en_sync;
    always_ff @(posedge analog.rx_lane_clk_div_i or negedge arstn) begin
        if (!arstn) begin
            hs_en_meta <= 1'b0;
            hs_en_sync <= 1'b0;
        end
        else begin
            hs_en_meta <= hs_arm;
            hs_en_sync <= hs_en_meta;
        end
    end

    // ----------------------------------------------------------------------
    // HS byte path (byte-clock domain): barrel-align to SoT 0xB8, then stream
    // ----------------------------------------------------------------------
    typedef enum int { HS_IDLE, HS_SYNC, HS_DATA } hs_state_e;
    hs_state_e   hs_state;
    logic [7:0]  prev_byte;
    logic [2:0]  align_sh;
    logic [4:0]  sync_cnt;

    // LSB-first alignment window. Bytes are deserialized LSB-first (bit[0] = oldest
    // bit), and prev_byte is older than the current byte, so concatenating
    // {current, prev_byte} orders the 16 bits oldest -> newest from window[0] up.
    // A byte aligned at offset s is window[s +: 8] (its bit[0] is the oldest bit).
    logic [15:0] window;
    assign window = {analog.parallel_data_i, prev_byte};

    // Priority-encode the first byte offset (0..7) in the window that matches
    // SOT_SYNC. Returns {found, shift[2:0]}. Pure combinational helper so the HS
    // FSM always_ff stays free of blocking assignments (blocking here is local
    // to the function and required for the read-after-write priority search).
    function automatic logic [3:0] find_sot_align(input logic [15:0] win);
        logic       f;
        logic [2:0] sh;
        f  = 1'b0;
        sh = 3'd0;
        for (int s = 0; s < 8; s++)
            if (!f && (win[s +: 8] == SOT_SYNC)) begin
                f  = 1'b1;
                sh = s[2:0];
            end
        return {f, sh};
    endfunction

    logic       sync_found;
    logic [2:0] sync_sh;
    always_comb {sync_found, sync_sh} = find_sot_align(window);

    // registered HS outputs
    logic [7:0] rxdata_q;
    logic       rxvalid_q, rxactive_q, rxsync_q, errsotsync_q;

    always_ff @(posedge analog.rx_lane_clk_div_i or negedge arstn) begin
        if (!arstn) begin
            hs_state     <= HS_IDLE;
            prev_byte    <= '0;
            align_sh     <= '0;
            sync_cnt     <= '0;
            rxdata_q     <= '0;
            rxvalid_q    <= 1'b0;
            rxactive_q   <= 1'b0;
            rxsync_q     <= 1'b0;
            errsotsync_q <= 1'b0;
        end
        else begin
            // one-cycle defaults
            rxvalid_q <= 1'b0;
            rxsync_q  <= 1'b0;
            prev_byte <= analog.parallel_data_i;

            case (hs_state)
                HS_IDLE: begin
                    rxactive_q   <= 1'b0;
                    errsotsync_q <= 1'b0;
                    sync_cnt     <= '0;
                    if (hs_en_sync) begin
                        hs_state   <= HS_SYNC;
                        rxactive_q <= 1'b1;
                    end
                end
                HS_SYNC: begin
                    if (!hs_en_sync) begin
                        hs_state <= HS_IDLE;
                    end
                    else begin
                        if (sync_found) begin
                            align_sh <= sync_sh;
                            rxsync_q <= 1'b1;
                            hs_state <= HS_DATA;
                        end
                        else begin
                            sync_cnt <= sync_cnt + 5'd1;
                            if (sync_cnt >= SYNC_LIMIT[4:0]) begin
                                errsotsync_q <= 1'b1;
                                hs_state     <= HS_IDLE;
                            end
                        end
                    end
                end
                HS_DATA: begin
                    if (!hs_en_sync) begin
                        // Burst ended: drop active and present NO valid byte this
                        // cycle. RxValidHS must only be high within RxActiveHS
                        // (spec §1.2); the byte here is trailing flush, not payload.
                        hs_state   <= HS_IDLE;
                        rxactive_q <= 1'b0;
                    end
                    else begin
                        rxdata_q  <= window[4'(align_sh) +: 8];
                        rxvalid_q <= 1'b1;
                    end
                end
                default: hs_state <= HS_IDLE;
            endcase
        end
    end

    assign ppi.RxDataHS_o     = rxdata_q;
    assign ppi.RxValidHS_o    = rxvalid_q;
    assign ppi.RxActiveHS_o   = rxactive_q;
    assign ppi.RxSyncHS_o     = rxsync_q;
    assign ppi.ErrSotSyncHS_o = errsotsync_q;

endmodule

`timescale 1ns/1ps
// =============================================================================
// mipi_spec_pkg — MIPI D-PHY v2.5 GOLDEN SPEC VALUES (verification oracle).
//
// SINGLE SOURCE OF TRUTH for both the TX and RX verification environments.
// Every value here is derived from the SPEC, documented in
//   docs/MIPI_DPHY_SPEC_REQUIREMENTS.md
// (which cites the PDF tables). The RTL under src/ keeps its OWN copies of these
// constants — the DUT is allowed to be wrong; the oracle exists to catch that.
//
//   RULE: NEVER edit a value here to make a test pass. A DUT/oracle divergence
//   is a DUT bug until docs/MIPI_DPHY_SPEC_REQUIREMENTS.md is shown wrong against
//   the PDF — fix the doc first (with a citation), then this package follows.
// =============================================================================
package mipi_spec_pkg;

    // ---- HS Start-of-Transmission ----
    // Spec leader 00011101, transmitted LSB-first on the wire -> byte 0xB8.
    // (spec §1.1 / PDF Table 28 — VERIFY). 0x1D is the stale MSB-first rendering.
    localparam logic [7:0] SOT_LEADER = 8'hB8;

    // ---- Escape entry command codes (spec §2.2 / PDF Table 10 — VERIFY) ----
    // Sent MSB-first on the LP lines. These are golden oracle values.
    localparam logic [7:0] CMD_ULPS   = 8'h1E;  // 00011110  Ultra-Low Power State
    localparam logic [7:0] CMD_TRGR0  = 8'h62;  // 01100010  Reset-Trigger
    localparam logic [7:0] CMD_TRGR1  = 8'h5D;  // 01011101  HS-Test Trigger
    localparam logic [7:0] CMD_TRGR2  = 8'h21;  // 00100001  Unknown-4 Trigger
    localparam logic [7:0] CMD_TRGR3  = 8'hA0;  // 10100000  Unknown-5 Trigger
    localparam logic [7:0] CMD_LPDT   = 8'hE1;  // 11100001  Low-Power Data Transmission

    // ---- Trigger command <-> RxTriggerEsc[3:0] one-hot (spec §2.2 mapping) ----
    // The byte->one-hot correspondence a compliant RX must implement. The RX
    // scoreboard DERIVES the expected one-hot from the driven command via this
    // function; it must not trust a stimulus-authored expected field.
    function automatic logic [3:0] esc_trigger_for_cmd(input logic [7:0] cmd);
        case (cmd)
            CMD_TRGR0: return 4'b0001;
            CMD_TRGR1: return 4'b0010;
            CMD_TRGR2: return 4'b0100;
            CMD_TRGR3: return 4'b1000;
            default:   return 4'b0000;   // not a trigger command
        endcase
    endfunction

    // Reverse direction, used by the TX oracle (one-hot intent -> command byte
    // a compliant TX must transmit on the line).
    function automatic logic [7:0] esc_cmd_for_trigger(input logic [3:0] onehot);
        case (1'b1)
            onehot[0]: return CMD_TRGR0;
            onehot[1]: return CMD_TRGR1;
            onehot[2]: return CMD_TRGR2;
            onehot[3]: return CMD_TRGR3;
            default:   return 8'hxx;
        endcase
    endfunction

    function automatic bit esc_is_ulps(input logic [7:0] cmd);
        return (cmd === CMD_ULPS);
    endfunction

    function automatic bit esc_is_lpdt(input logic [7:0] cmd);
        return (cmd === CMD_LPDT);
    endfunction

    // ---- LP line states (D[p],D[n]) ----
    localparam logic [1:0] LP_STOP  = 2'b11;  // LP-11
    localparam logic [1:0] LP_HSREQ = 2'b01;  // LP-01 (HS request / Bridge)
    localparam logic [1:0] LP_MARK1 = 2'b10;  // LP-10 (Mark-1)
    localparam logic [1:0] LP_SPACE = 2'b00;  // LP-00 (Space / HS-0)

    // ---- Timing parameters (spec §4 — VERIFY each against PDF tables) ----
    localparam time T_LPX_MIN         = 50ns;    // LP transmit period / esc unit
    localparam time T_INIT_MIN        = 100us;   // initialisation period
    localparam time T_CLK_PREPARE_MIN = 38ns;
    localparam time T_CLK_PREPARE_MAX = 95ns;
    localparam time T_CLK_ZERO_MIN    = 300ns - T_CLK_PREPARE_MAX; // combined >=300ns
    localparam time T_CLK_ZERO_MAX    = 300ns - T_CLK_PREPARE_MIN;
    localparam time T_WAKEUP_MIN      = 1ms;     // ULPS wakeup

endpackage

`timescale 1ns/1ps
// Taps the data-lane LP lines and the Esc clock so the escape recovery monitor
// can decode the spaced-one-hot Escape Entry Command transmitted by the DUT and
// the scoreboard can check it against spec D-PHY v2.5 Table 10.
interface esc_line_if();
    logic escclk;     // Esc clock (TxClkEsc)
    logic lp_p;       // data lane LP line Dp
    logic lp_n;       // data lane LP line Dn
endinterface

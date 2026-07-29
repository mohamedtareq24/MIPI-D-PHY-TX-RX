`timescale 1ns/1ps
// Behavioral RX analog front-end (ANALOG — Verilator-exempt). Mirror of analog_top.
// Models, behaviorally:
//   - LP receivers: pass pad LP levels to the digital lanes.
//   - HS clock recovery: single-ended view of the differential HS clock, /8 byte clock.
//   - HS 1:8 deserializer: shift HS data LSB-first (first bit -> bit[0]) on the
//     recovered bit clock, latch per byte clock.
//   - HS-clock activity detector (realtime watchdog) gated by the digital hs_rx_en.
// Simplifications (refine for sign-off / Xilinx model): SDR sampling (no DDR I/Q),
// ideal recovery (no jitter/skew), byte clock = HS clock / 8.
module analog_rx_top #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic               rstn_i,

    rx_clk_analog_if.analog    clk_analog,
    rx_data_analog_if.analog   data_analog,

    rx_clk_d_phy_if.analog     clk_d_phy,
    rx_data_d_phy_if.analog    data_d_phy
);

    // ---- LP receivers: pass pad LP levels to the digital lanes ----
    assign clk_analog.lp_rxp_i  = clk_d_phy.clk_LP_Dp_i;
    assign clk_analog.lp_rxn_i  = clk_d_phy.clk_LP_Dn_i;
    assign data_analog.lp_rxp_i = data_d_phy.data_LP_Dp_i;
    assign data_analog.lp_rxn_i = data_d_phy.data_LP_Dn_i;

    // ---- HS clock recovery (single-ended view of the differential clock) ----
    logic hs_clk;
    assign hs_clk = clk_d_phy.clk_HS_Dp_i;

    // /8 byte-clock divider: 3-bit counter MSB toggles every 4 bit-edges -> period 8.
    logic [2:0] div_cnt;
    always_ff @(posedge hs_clk or negedge rstn_i) begin
        if (!rstn_i) div_cnt <= 3'd0;
        else         div_cnt <= div_cnt + 3'd1;
    end

    logic byte_clk;
    assign byte_clk = div_cnt[2];

    assign clk_analog.rx_byte_clk_i      = byte_clk;
    assign data_analog.rx_lane_clk_div_i = byte_clk;

    // ---- HS 1:8 deserializer ----
    logic [7:0] hs_shift;
    always_ff @(posedge hs_clk or negedge rstn_i) begin
        if (!rstn_i) hs_shift <= 8'h00;
        // LSB-first: first-arrived bit enters at MSB and shifts down so that after
        // 8 bit-clocks the oldest bit sits in bit[0] (MIPI transmits LSB first).
        else         hs_shift <= {data_d_phy.data_HS_Dp_i, hs_shift[7:1]};
    end

    logic [7:0] par_byte;
    always_ff @(posedge byte_clk or negedge rstn_i) begin
        if (!rstn_i) par_byte <= 8'h00;
        else         par_byte <= hs_shift;
    end
    assign data_analog.parallel_data_i = par_byte;

    // ---- HS-clock activity detector (behavioral realtime watchdog) ----
    // Re-triggered on every HS clock edge; declared active while edges keep arriving
    // and the digital side has armed the receiver (hs_rx_en).
    localparam realtime HS_TIMEOUT = SERIAL_CLK_PER * 4;
    realtime last_edge;
    logic    hs_active;

    always @(hs_clk or negedge rstn_i) begin
        if (!rstn_i) last_edge = 0;
        else         last_edge = $realtime;
    end

    initial hs_active = 1'b0;
    always #(SERIAL_CLK_PER) begin
        hs_active = rstn_i && clk_analog.hs_rx_en_o &&
                    (($realtime - last_edge) <= HS_TIMEOUT);
    end
    assign clk_analog.hs_clk_active_i = hs_active;

endmodule

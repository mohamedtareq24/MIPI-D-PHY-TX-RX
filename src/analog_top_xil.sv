`timescale 1ns/1ps
module analog_top_xil #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic       rstn_i,

        // Clock Lane
    tx_clk_analog_if.analog         clk_analog,
    tx_clk_d_phy_if.tx_d_phy_hs     clk_d_phy,
    
    // Data Lane 
    tx_data_analog_if.analog        data_analog,
    tx_data_d_phy_if.tx_d_phy_hs    data_d_phy,

    // Exported clocks for top-level observability
    output logic       clk_i_o,
    output logic       clk_q_o,
    output logic       clk_div8_o,
    output logic       pll_lock_o
);

    logic hs_clk_i;
    logic hs_clk_q;
    logic hs_clk_q_gated;
    logic hs_serial_data;

    // Analog I/Q clock generator: generates quadrature high-speed clocks.
    pll #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_pll (
        .in_phase_clk_o(hs_clk_i),
        .quadrature_clk_o(hs_clk_q)
    );

    // Required 8:1 ratio timing reference for the parallel interface.
    clk_div_by_8 u_clk_div_by_8 (
        .rstn_i(rstn_i),
        .clk_i(hs_clk_i),
        .clk_div8_o(clk_div8_o)
    );

    // 8:1 serializer: parallel side on clk_div8, serial side on I-phase high-speed clock.
    serializer_8to1 u_serializer_8to1 (
        .rstn_i(rstn_i),
        .clk_i(hs_clk_i),
        .clk_div8_i(clk_div8_o),
        .en_i(data_analog.serializer_en_o),
        .parallel_data_i(data_analog.parallel_data_o),
        .serial_data_o(hs_serial_data)
    );

    // Explicitly gate only the Q-phase clock with ddr_clk_buff_en.
    q_clock_gate u_q_clock_gate (
        .clk_q_i(hs_clk_q),
        .en_i(clk_analog.ddr_clk_buff_en),
        .clk_q_gated_o(hs_clk_q_gated)
    );

    // Differential data output stage.
    diff_data_driver u_diff_data_driver (
        .en_i(data_analog.serializer_en_o),
        .data_i(hs_serial_data),
        .dp_o(data_d_phy.hs_data_Dp_o),
        .dn_o(data_d_phy.hs_data_Dn_o)
    );

    // Differential clock output stage driven by gated Q-phase clock.
    diff_clk_driver_xil u_diff_clk_driver (
        .en_i(clk_analog.ddr_clk_buff_en),
        .clk_i(hs_clk_q_gated),
        .dp_o(clk_d_phy.clk_HS_Dp_o),
        .dn_o(clk_d_phy.clk_HS_Dn_o)
    );

    assign clk_i_o = hs_clk_i;
    assign clk_q_o = hs_clk_q;
    assign pll_lock_o = rstn_i;

    // Export byte-clock reference back into digital control interfaces.
    assign clk_analog.clk_div = clk_div8_o;
    assign data_analog.tx_lane_clk_div_i = clk_div8_o;

endmodule

module diff_clk_driver_xil (
    input  logic  clk_i,  // e.g., 400 MHz from MMCM
    input  logic  en_i,     // High-Speed enable (Active Low) from CIL
    output logic  dp_o,   // Physical Pad P
    output logic  dn_o    // Physical Pad N
);

    logic oddr_to_obuftds;

    // ODDR to forward the clock
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"), 
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) ODDR_clk_forward (
        .Q  (oddr_to_obuftds),
        .C  (clk_i),
        .CE (1'b1),
        .D1 (1'b1),          // Forward High on rising edge
        .D2 (1'b0),          // Forward Low on falling edge
        .R  (1'b0),
        .S  (1'b0)
    );

    // OBUFTDS to drive the differential pads
    OBUFTDS #(
        .IOSTANDARD("LVDS_25") // Or HSUL_12 depending on resistor network
    ) OBUFTDS_inst (
        .O  (dp_o),
        .OB (dn_o),
        .I  (oddr_to_obuftds),
        .T  (en_i)          // Tristate control (1 = High-Z, 0 = Drive)
    );

    // LP drivers (OBUF) would be instantiated here...

endmodule
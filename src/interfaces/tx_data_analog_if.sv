interface tx_data_analog_if();
    logic   tx_lane_clk_div_i;              // SERDES Clock  / 8
    logic   serializer_en_o;                // Serialzer Enable
    logic   [7:0] parallel_data_o;

    modport tx (
        input   tx_lane_clk_div_i,
        output  serializer_en_o,
        output  parallel_data_o
    );

endinterface
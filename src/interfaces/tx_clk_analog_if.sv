interface tx_clk_analog_if();
    logic clk_div;              // SERDES Clock / 8
    logic ddr_clk_buff_en;      // Enable for the Serial Clock

    modport digital (
        input   clk_div,
        output  ddr_clk_buff_en
    );

    modport analog (
        output  clk_div,
        input   ddr_clk_buff_en
    );

endinterface

interface ppi_clk_intf;
    parameter time ESC_CLK_PER = 50;

    logic clk;

    logic TxClkEsc;
    logic TxRequestHS;
    logic TxReadyHS;
    logic TxByteClkHS;
    logic TxUlpsClk;
    logic TxUlpsExit;
    logic TxUlpsEsc;
    logic TxUlpsActive_n;
    logic enable;
    logic stop_state;
    logic ForceTXStopmode;


    logic tx_clk_esc_en;
    bit esc_clk = 0;
    always #(ESC_CLK_PER / 2) esc_clk = ~esc_clk;

    always_comb begin
        if (tx_clk_esc_en)
            TxClkEsc = esc_clk;
        else
            TxClkEsc = 1'b0;
    end
endinterface
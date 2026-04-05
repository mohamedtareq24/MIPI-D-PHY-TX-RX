module ppi_clk_tb_top;
    import uvm_pkg::*;
    import ppi_clk_pkg::*;

    localparam int unsigned SERIAL_CLK_PER = 8;
    tx_clk_ppi_if clk_ppi_if();
    tx_data_ppi_if data_ppi_if();
    tx_clk_d_phy_if clk_d_phy_if();
    tx_data_d_phy_if data_d_phy_if();
    
    logic arstn;

    initial begin
        arstn = 0;
        #100;
        arstn = 1;
        #100;
        arstn = 0;
        #100;
        arstn = 1;
    
    end


    tx_phy_top # (
    .SERIAL_CLK_PER(SERIAL_CLK_PER)
    )
    tx_phy_top_inst (
    .arstn(arstn),
    .clk_ppi(clk_ppi_if),
    .data_ppi(data_ppi_if),
    .clk_d_phy_lp(clk_d_phy_if),
    .clk_d_phy_hs(clk_d_phy_if),
    .data_d_phy_lp(data_d_phy_if),
    .data_d_phy_hs(data_d_phy_if)
    );

    bind tx_d_phy PPI_sva u_ppi_sva (
        .arstn(arstn),
        .clk_ppi(clk_ppi),
        .data_ppi(data_ppi),
        .clk_d_phy(clk_d_phy),
        .data_d_phy(data_d_phy),
        .clk_analog(clk_analog),
        .data_analog(data_analog)
    );

    initial begin
        uvm_config_db#(virtual tx_clk_ppi_if)::set(null, "uvm_test_top.clk_agent.clk_drv", "vif", clk_ppi_if);
        uvm_config_db#(virtual tx_clk_ppi_if)::set(null, "uvm_test_top.clk_agent.clk_mon", "vif", clk_ppi_if);
        run_test();
    end

endmodule
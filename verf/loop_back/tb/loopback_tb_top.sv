`timescale 1ns/1ps
module loopback_tb_top;
    import uvm_pkg::*;
    import loopback_env_pkg::*;

    localparam int unsigned SERIAL_CLK_PER = 8;

    tx_clk_ppi_if    tx_clk_ppi();
    tx_data_ppi_if   tx_data_ppi();
    tx_clk_d_phy_if  tx_clk_dp();
    tx_data_d_phy_if tx_data_dp();

    rx_clk_ppi_if    rx_clk_ppi();
    rx_data_ppi_if   rx_data_ppi();
    rx_clk_d_phy_if  rx_clk_dp();
    rx_data_d_phy_if rx_data_dp();

    logic arstn;
    logic refclk;

    assign tx_data_ppi.TxClkEsc_i = tx_clk_ppi.TxClkEsc_i;

    // Loopback wiring: TX line outputs -> RX line inputs.
    assign rx_data_dp.data_LP_Dp_i = tx_data_dp.tx_lane_LP_Dp_o;
    assign rx_data_dp.data_LP_Dn_i = tx_data_dp.tx_lane_LP_Dn_o;
    assign rx_data_dp.data_HS_Dp_i = tx_data_dp.hs_data_Dp_o;
    assign rx_data_dp.data_HS_Dn_i = tx_data_dp.hs_data_Dn_o;
    assign rx_clk_dp.clk_LP_Dp_i = tx_clk_dp.clk_LP_Dp_o;
    assign rx_clk_dp.clk_LP_Dn_i = tx_clk_dp.clk_LP_Dn_o;
    assign rx_clk_dp.clk_HS_Dp_i = tx_clk_dp.clk_HS_Dp_o;
    assign rx_clk_dp.clk_HS_Dn_i = tx_clk_dp.clk_HS_Dn_o;

    tx_phy_top #(.SERIAL_CLK_PER(SERIAL_CLK_PER)) tx_dut (
        .arstn        (arstn),
        .clk_ppi      (tx_clk_ppi),
        .data_ppi     (tx_data_ppi),
        .clk_d_phy_lp (tx_clk_dp),
        .clk_d_phy_hs (tx_clk_dp),
        .data_d_phy_lp(tx_data_dp),
        .data_d_phy_hs(tx_data_dp)
    );

    rx_phy_top #(.SERIAL_CLK_PER(SERIAL_CLK_PER)) rx_dut (
        .arstn     (arstn),
        .refclk_i  (refclk),
        .clk_ppi   (rx_clk_ppi),
        .data_ppi  (rx_data_ppi),
        .clk_d_phy (rx_clk_dp),
        .data_d_phy(rx_data_dp)
    );

    initial refclk = 1'b0;
    always #10 refclk = ~refclk;

    initial begin
        arstn = 1'b0;
        #100; arstn = 1'b1;
        #100; arstn = 1'b0;
        #100; arstn = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual tx_clk_ppi_if) ::set(null, "*tx_clk_agent*",  "vif",      tx_clk_ppi);
        uvm_config_db#(virtual tx_data_ppi_if)::set(null, "*tx_data_agent*", "data_vif", tx_data_ppi);
        uvm_config_db#(virtual tx_clk_ppi_if) ::set(null, "*tx_data_agent*", "clk_vif",  tx_clk_ppi);
        uvm_config_db#(virtual rx_clk_ppi_if)   ::set(null, "*", "clk_ppi",  rx_clk_ppi);
        uvm_config_db#(virtual rx_data_ppi_if)  ::set(null, "*", "data_ppi", rx_data_ppi);
        uvm_config_db#(virtual rx_clk_d_phy_if) ::set(null, "*", "clk_pad",  rx_clk_dp);
        uvm_config_db#(virtual rx_data_d_phy_if)::set(null, "*", "data_pad", rx_data_dp);
        run_test("loopback_hs_test");
    end
endmodule

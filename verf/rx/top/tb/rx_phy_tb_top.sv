`timescale 1ns/1ps
module rx_phy_tb_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import rx_phy_env_pkg::*;

    logic arstn;
    logic refclk;

    // Interfaces
    rx_clk_ppi_if    clk_ppi();
    rx_data_ppi_if   data_ppi();
    rx_clk_d_phy_if  clk_dp();
    rx_data_d_phy_if data_dp();

    // DUT
    rx_phy_top #(.SERIAL_CLK_PER(8)) dut (
        .arstn     (arstn),
        .refclk_i  (refclk),
        .clk_ppi   (clk_ppi),
        .data_ppi  (data_ppi),
        .clk_d_phy (clk_dp),
        .data_d_phy(data_dp)
    );

    // LP sample / FSM clock (20 ns)
    initial refclk = 1'b0;
    always #10 refclk = ~refclk;

    // Reset
    initial begin
        arstn = 1'b0;
        #100;
        arstn = 1'b1;
    end

    // Protocol / timing / sequencing assertions (checks the spec, not the design).
    rx_phy_sva u_sva (
        .arstn    (arstn),
        .refclk   (refclk),
        .clk_ppi  (clk_ppi),
        .data_ppi (data_ppi),
        .data_dp  (data_dp)
    );

    initial begin
        uvm_config_db #(virtual rx_clk_ppi_if)   ::set(null, "*", "clk_ppi",  clk_ppi);
        uvm_config_db #(virtual rx_data_ppi_if)  ::set(null, "*", "data_ppi", data_ppi);
        uvm_config_db #(virtual rx_clk_d_phy_if) ::set(null, "*", "clk_pad",  clk_dp);
        uvm_config_db #(virtual rx_data_d_phy_if)::set(null, "*", "data_pad", data_dp);
        run_test("rx_phy_base_test");
    end
endmodule

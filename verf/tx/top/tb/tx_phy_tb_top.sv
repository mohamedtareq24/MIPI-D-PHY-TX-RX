`timescale 1ns/1ps
module tx_phy_tb_top;
    import uvm_pkg::*;
    import tx_phy_env_pkg::*;

    localparam int unsigned SERIAL_CLK_PER = 8;

    tx_clk_ppi_if    clk_ppi_if();
    tx_data_ppi_if   data_ppi_if();
    tx_clk_d_phy_if  clk_d_phy_if();
    tx_data_d_phy_if data_d_phy_if();

    logic arstn;

    // Both lanes share one Esc clock. The clock-lane UVC driver generates it on
    // clk_ppi_if.TxClkEsc_i; mirror it onto the data-lane PPI (read-only there).
    assign data_ppi_if.TxClkEsc_i = clk_ppi_if.TxClkEsc_i;

    initial begin
        arstn = 0;
        #100; arstn = 1;
        #100; arstn = 0;
        #100; arstn = 1;
    end

    // DUT: default (no XIL_PHY define) selects the behavioral analog_top.
    tx_phy_top #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) dut (
        .arstn        (arstn),
        .clk_ppi      (clk_ppi_if),
        .data_ppi     (data_ppi_if),
        .clk_d_phy_lp (clk_d_phy_if),
        .clk_d_phy_hs (clk_d_phy_if),
        .data_d_phy_lp(data_d_phy_if),
        .data_d_phy_hs(data_d_phy_if)
    );

    // HS serial line tap for the recovery monitor (behavioral analog model).
    hs_line_if hs_line();
    assign hs_line.bitclk  = dut.u_analog_top.clk_i_o;
    assign hs_line.byteclk = dut.u_analog_top.clk_div8_o;
    assign hs_line.serial  = data_d_phy_if.hs_data_Dp_o;
    assign hs_line.en      = dut.data_analog_if.serializer_en_o;

    // LP-line tap for escape-command recovery (Esc-clock domain).
    esc_line_if esc_line();
    assign esc_line.escclk = clk_ppi_if.TxClkEsc_i;
    assign esc_line.lp_p   = data_d_phy_if.tx_lane_LP_Dp_o;
    assign esc_line.lp_n   = data_d_phy_if.tx_lane_LP_Dn_o;

    // FSM state coverage (clk x data) bound into the digital wrapper.
    bind tx_d_phy tx_phy_state_cov u_state_cov (
        .esc       (clk_ppi.TxClkEsc_i),
        .arstn     (arstn),
        .clk_state (u_tx_clock_lane.state),
        .data_state(u_tx_data_lane.state)
    );

    // Protocol + cross-lane assertions.
    tx_phy_sva u_sva (
        .arstn      (arstn),
        .clk_ppi    (clk_ppi_if),
        .data_ppi   (data_ppi_if),
        .data_d_phy (data_d_phy_if),
        .data_ser_en(dut.data_analog_if.serializer_en_o)
    );

    initial begin
        // Clock agent
        uvm_config_db#(virtual tx_clk_ppi_if)::set(null, "*clk_agent*",  "vif",      clk_ppi_if);
        // Data agent: PPI it drives + clock PPI it reads for the HS byte clock
        uvm_config_db#(virtual tx_data_ppi_if)::set(null, "*data_agent*", "data_vif", data_ppi_if);
        uvm_config_db#(virtual tx_clk_ppi_if)::set(null, "*data_agent*", "clk_vif",  clk_ppi_if);
        // Recovery monitor: HS serial line tap + LP escape line tap
        uvm_config_db#(virtual hs_line_if)::set(null, "*recover_mon*", "vif", hs_line);
        uvm_config_db#(virtual esc_line_if)::set(null, "*recover_mon*", "esc_vif", esc_line);
        run_test();
    end
endmodule

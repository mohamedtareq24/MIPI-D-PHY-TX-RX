// XRUN filelist for master_clock_lane_uvc Makefile
// Relative base: verf/master_clock_lane_uvc

+incdir+.
+incdir+./tb
+incdir+../../src
+incdir+../../src/interfaces
// DUT sources

// Interface sources (must be compiled explicitly)
../../src/interfaces/tx_clk_ppi_if.sv
../../src/interfaces/tx_data_ppi_if.sv
../../src/interfaces/tx_clk_d_phy_if.sv
../../src/interfaces/tx_data_d_phy_if.sv
../../src/interfaces/tx_clk_analog_if.sv
../../src/interfaces/tx_data_analog_if.sv

../../src/analog_top.sv
../../src/analog_top_xil.sv
../../src/tx_clock_lane.sv
../../src/tx_data_lane.sv
../../src/tx_d_phy.sv
../../src/tx_phy_top.sv

// Verification sources
./ppi_clk_pkg.sv
./tb/clock_lane_assertions.sv
./tb/ppi_clk_tb_top.sv

// XRUN filelist for tx_clock_lane_uvc Makefile
// Relative base: verf/tx/tx_clock_lane_uvc

+incdir+.
+incdir+./tb
+incdir+../../../src/tx
+incdir+../../../src/tx/interfaces
// DUT sources

// Interface sources (must be compiled explicitly)
../../../src/tx/interfaces/tx_clk_ppi_if.sv
../../../src/tx/interfaces/tx_data_ppi_if.sv
../../../src/tx/interfaces/tx_clk_d_phy_if.sv
../../../src/tx/interfaces/tx_data_d_phy_if.sv
../../../src/tx/interfaces/tx_clk_analog_if.sv
../../../src/tx/interfaces/tx_data_analog_if.sv

../../../src/tx/analog_top.sv
../../../src/tx/analog_top_xil.sv
../../../src/tx/tx_clock_lane.sv
../../../src/tx/tx_data_lane.sv
../../../src/tx/tx_d_phy.sv
../../../src/tx/tx_phy_top.sv

// Verification sources
../../common/mipi_spec_pkg.sv
./ppi_clk_pkg.sv
./tb/clock_lane_assertions.sv
./tb/ppi_clk_tb_top.sv

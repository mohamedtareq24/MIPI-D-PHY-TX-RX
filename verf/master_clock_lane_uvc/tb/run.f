// XRUN filelist for master_clock_lane_uvc Makefile
// Relative base: verf/master_clock_lane_uvc

+incdir+.
+incdir+./tb
+incdir+../../src
// DUT sources

../../src/analog_top.sv
../../src/clock_lane.sv
../../src/tx_data_lane.sv
../../src/tx_d_phy.sv
../../src/tx_phy_top.sv

// Verification sources
./ppi_clk_intf.sv
./ppi_clk_pkg.sv
./tb/ppi_clk_tb_top.sv

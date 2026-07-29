// Filelist for the MIPI D-PHY loopback env. Base dir: verf/loop_back

+incdir+../../src/tx
+incdir+../../src/tx/interfaces
+incdir+../../src/rx/interfaces
+incdir+../tx/tx_clock_lane_uvc
+incdir+../tx/tx_data_lane_uvc
+incdir+../rx/rx_clock_lane_uvc
+incdir+../rx/rx_data_lane_uvc
+incdir+../tx/top
+incdir+.
+incdir+./tb

../common/mipi_spec_pkg.sv

../../src/tx/interfaces/tx_clk_ppi_if.sv
../../src/tx/interfaces/tx_data_ppi_if.sv
../../src/tx/interfaces/tx_clk_analog_if.sv
../../src/tx/interfaces/tx_data_analog_if.sv
../../src/tx/interfaces/tx_clk_d_phy_if.sv
../../src/tx/interfaces/tx_data_d_phy_if.sv
../../src/tx/tx_clock_lane.sv
../../src/tx/tx_data_lane.sv
../../src/tx/tx_d_phy.sv
../../src/tx/analog_top.sv
../../src/tx/tx_phy_top.sv

../../src/rx/interfaces/rx_clk_ppi_if.sv
../../src/rx/interfaces/rx_data_ppi_if.sv
../../src/rx/interfaces/rx_clk_analog_if.sv
../../src/rx/interfaces/rx_data_analog_if.sv
../../src/rx/interfaces/rx_clk_d_phy_if.sv
../../src/rx/interfaces/rx_data_d_phy_if.sv
../../src/rx/rx_clock_lane.sv
../../src/rx/rx_data_lane.sv
../../src/rx/rx_d_phy.sv
../../src/rx/analog_rx_top.sv
../../src/rx/rx_phy_top.sv

../tx/tx_clock_lane_uvc/ppi_clk_pkg.sv
../tx/tx_data_lane_uvc/ppi_data_pkg.sv
../rx/rx_clock_lane_uvc/rx_clk_pkg.sv
../rx/rx_data_lane_uvc/rx_data_pkg.sv

./loopback_env_pkg.sv

./tb/loopback_tb_top.sv

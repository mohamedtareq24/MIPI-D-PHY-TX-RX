// Filelist for the integrated TX-PHY environment.
// Relative base: verf/tx/top
// Default analog model: behavioral (no XIL_PHY define). Add +define+XIL_PHY for
// the Xilinx-primitive analog top (requires compiled simlibs + glbl).

+incdir+../../../src/tx
+incdir+../../../src/tx/interfaces
+incdir+../tx_clock_lane_uvc
+incdir+../tx_clock_lane_uvc/tb
+incdir+../tx_data_lane_uvc
+incdir+.
+incdir+./tb

// Interfaces
../../../src/tx/interfaces/tx_clk_ppi_if.sv
../../../src/tx/interfaces/tx_data_ppi_if.sv
../../../src/tx/interfaces/tx_clk_d_phy_if.sv
../../../src/tx/interfaces/tx_data_d_phy_if.sv
../../../src/tx/interfaces/tx_clk_analog_if.sv
../../../src/tx/interfaces/tx_data_analog_if.sv

// DUT (behavioral analog model)
../../../src/tx/analog_top.sv
../../../src/tx/tx_clock_lane.sv
../../../src/tx/tx_data_lane.sv
../../../src/tx/tx_d_phy.sv
../../../src/tx/tx_phy_top.sv

// Shared spec oracle package (golden values for TX + RX)
../../common/mipi_spec_pkg.sv

// Per-lane UVCs
../tx_clock_lane_uvc/ppi_clk_pkg.sv
../tx_data_lane_uvc/ppi_data_pkg.sv

// Integrated env + top
./tb/hs_line_if.sv
./tb/esc_line_if.sv
./tx_phy_env_pkg.sv
./tb/tx_phy_sva.sv
./tb/tx_phy_state_cov.sv
./tb/tx_phy_tb_top.sv

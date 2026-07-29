// Filelist for the RX PHY env (HS-receive smoke).
// Relative base: verf/rx/top

+incdir+../../../src/rx/interfaces
+incdir+../rx_clock_lane_uvc
+incdir+../rx_data_lane_uvc
+incdir+.
+incdir+./tb

// Interfaces
../../../src/rx/interfaces/rx_clk_ppi_if.sv
../../../src/rx/interfaces/rx_data_ppi_if.sv
../../../src/rx/interfaces/rx_clk_analog_if.sv
../../../src/rx/interfaces/rx_data_analog_if.sv
../../../src/rx/interfaces/rx_clk_d_phy_if.sv
../../../src/rx/interfaces/rx_data_d_phy_if.sv

// DUT (behavioral analog model)
../../../src/rx/rx_clock_lane.sv
../../../src/rx/rx_data_lane.sv
../../../src/rx/rx_d_phy.sv
../../../src/rx/analog_rx_top.sv
../../../src/rx/rx_phy_top.sv

// Shared spec oracle package (golden values for TX + RX)
../../common/mipi_spec_pkg.sv

// Per-lane UVCs
../rx_clock_lane_uvc/rx_clk_pkg.sv
../rx_data_lane_uvc/rx_data_pkg.sv

// Top env
./rx_phy_env_pkg.sv

// Protocol / timing / sequencing assertions
./tb/rx_phy_sva.sv

// Testbench top
./tb/rx_phy_tb_top.sv

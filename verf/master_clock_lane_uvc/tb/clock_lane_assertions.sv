`timescale 1ns/1ps
module PPI_sva (
    input  logic            arstn,
    tx_clk_ppi_if           clk_ppi,
    tx_data_ppi_if          data_ppi,
    tx_clk_d_phy_if         clk_d_phy,
    tx_data_d_phy_if        data_d_phy,
    tx_clk_analog_if        clk_analog,
    tx_data_analog_if       data_analog
);

// Clock lane assertions
// control, LP , signals are clocked by TxClkEsc_i
parameter real  T_ESC_CLK_PER = 50ns; 

logic [1:0] LP_STATE;
assign LP_STATE = {clk_d_phy.clk_LP_Dp_o, clk_d_phy.clk_LP_Dn_o};
// Timing parameters in terms of clock cycles
localparam int unsigned T_INIT_CYCLES_MIN = $ceil(100us / T_ESC_CLK_PER);
localparam int unsigned T_CLK_PREPARE_CYCLES_MIN = $ceil(38ns / T_ESC_CLK_PER); 
localparam int unsigned T_CLK_PREPARE_CYCLES_MAX = $floor(95ns / T_ESC_CLK_PER);
localparam int unsigned T_CLK_ZERO_MIN = $ceil((300ns - 95ns) / T_ESC_CLK_PER);
localparam int unsigned T_CLK_ZERO_MAX = $floor((300ns - 38ns) / T_ESC_CLK_PER);
localparam int unsigned WAKEUP_TIME_CYCLES_MIN = $ceil(1ms / T_ESC_CLK_PER);



// Clock lane enable
// Stop_State_o Assertion after enable & T_init Time

property Stopstate_high_after_Enable;
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) (clk_ppi.ForceTXStopmode_i && $isunknown(LP_STATE)) |-> ##[T_INIT_CYCLES_MIN:$] (clk_ppi.StopState_o == 1'b1);
endproperty

property ForceTXStopmode_deassertion_when_Stopstate;
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $fell(clk_ppi.ForceTXStopmode_i) |-> (clk_ppi.StopState_o == 1'b1);
endproperty

property TxRequestHS_when_Stopstate;
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $rose(clk_ppi.TxRequestHS_i) |-> (clk_ppi.StopState_o == 1'b1);
endproperty

property TxRequestHS_HS_sequence; // HS request must be followed by the correct LP state sequence
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $rose(clk_ppi.TxRequestHS_i) |-> (LP_STATE == 2'b11) ##[1:$] (LP_STATE == 2'b01) ##[1:$] (LP_STATE == 2'b00);
endproperty

property TxRequestHS_TxReadyHS_relation; // TxReadyHS_o must be high after TxRequestHS_i is asserted
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $rose(clk_ppi.TxRequestHS_i) |->  ##[(T_CLK_PREPARE_CYCLES_MIN + T_CLK_ZERO_MIN):(T_CLK_PREPARE_CYCLES_MAX + T_CLK_ZERO_MAX)] $rose(clk_ppi.TxReadyHS_o);
endproperty

property StopState_TxUlpsClk; // When ULPS clock is asserted, the clock lane must be in stop state
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $rose(clk_ppi.TxUlpsClk_i) |-> (clk_ppi.StopState_o == 1'b1);
endproperty

property TxUlpsClk_LP_STATE; // After ULPS clock is asserted, the LP state must be 10 followed by 00
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $rose(clk_ppi.TxUlpsClk_i) |->  (LP_STATE == 2'b10)[->1] ##1 (LP_STATE == 2'b00);
endproperty


property TxUlpsActive_n_LP_STATE; // When ULPS is active (TxUlpsActive_n_o is 0), the LP state must be 00
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $fell(clk_ppi.TxUlpsActive_n_o) |-> (LP_STATE == 2'b00);
endproperty

property TxUlpsExit_UlpsActiveNot; // Exit can only occur if currently in ULPS
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) $rose(clk_ppi.TxUlpsExit_i) |-> (clk_ppi.TxUlpsActive_n_o == 1'b0);
endproperty

property TxUlpsExit_LP_STATE; // After ULPS exit, the LP state must be 00 followed by 10 for T_WAKEUP_TIME
    @(posedge clk_ppi.TxClkEsc_i) disable iff (!arstn) ($rose(clk_ppi.TxUlpsExit_i) && LP_STATE == 2'b00)|-> (LP_STATE == 2'b10)[*WAKEUP_TIME_CYCLES_MIN:$] ##1 (LP_STATE == 2'b11) [->1];
endproperty


assert property (Stopstate_high_after_Enable)
    else uvm_pkg::uvm_report_error("ASSERT_STOPSTATE_HIGH_AFTER_ENABLE",
                                   $sformatf("Stopstate_high_after_Enable failed at %0t: StopState_o did not assert %0d esc cycles after ForceTXStopmode_i.",
                                             $time,
                                             T_INIT_CYCLES_MIN),
                                   uvm_pkg::UVM_NONE);

assert property (ForceTXStopmode_deassertion_when_Stopstate)
    else uvm_pkg::uvm_report_error("ASSERT_FORCETXSTOPMODE_DEASSERTION_WHEN_STOPSTATE",
                                   $sformatf("ForceTXStopmode_deassertion_when_Stopstate failed at %0t: ForceTXStopmode_i deasserted while StopState_o=%0b.",
                                             $time,
                                             clk_ppi.StopState_o),
                                   uvm_pkg::UVM_NONE);

assert property (TxRequestHS_when_Stopstate)
    else uvm_pkg::uvm_report_error("ASSERT_TXREQUESTHS_WHEN_STOPSTATE",
                                   $sformatf("TxRequestHS_when_Stopstate failed at %0t: TxRequestHS_i rose while clk_ppi.StopState_o=%0b.",
                                             $time,
                                             clk_ppi.StopState_o),
                                   uvm_pkg::UVM_NONE);

assert property (TxRequestHS_HS_sequence)
    else uvm_pkg::uvm_report_error("ASSERT_TXREQUESTHS_HS_SEQUENCE",
                                   $sformatf("TxRequestHS_HS_sequence failed at %0t: LP sequence after TxRequestHS_i was invalid, LP_STATE=%0b.",
                                             $time,
                                             LP_STATE),
                                   uvm_pkg::UVM_NONE);

assert property (TxRequestHS_TxReadyHS_relation)
    else uvm_pkg::uvm_report_error("ASSERT_TXREQUESTHS_TXREADYHS_RELATION",
                                   $sformatf("TxRequestHS_TxReadyHS_relation failed at %0t: TxReadyHS_o did not rise within expected prepare+zero window [%0d:%0d] cycles.",
                                             $time,
                                             (T_CLK_PREPARE_CYCLES_MIN + T_CLK_ZERO_MIN),
                                             (T_CLK_PREPARE_CYCLES_MAX + T_CLK_ZERO_MAX)),
                                   uvm_pkg::UVM_NONE);

assert property (StopState_TxUlpsClk)
    else uvm_pkg::uvm_report_error("ASSERT_STOPSTATE_TXULPSCLK",
                                   $sformatf("StopState_TxUlpsClk failed at %0t: TxUlpsClk_i rose while StopState_o=%0b.",
                                             $time,
                                             clk_ppi.StopState_o),
                                   uvm_pkg::UVM_NONE);

assert property (TxUlpsClk_LP_STATE)
    else uvm_pkg::uvm_report_error("ASSERT_TXULPSCLK_LP_STATE",
                                   $sformatf("TxUlpsClk_LP_STATE failed at %0t: Expected LP transition to 2'b10 then 2'b00 after TxUlpsClk_i, current LP_STATE=%0b.",
                                             $time,
                                             LP_STATE),
                                   uvm_pkg::UVM_NONE);

assert property (TxUlpsActive_n_LP_STATE)
    else uvm_pkg::uvm_report_error("ASSERT_TXULPSACTIVE_N_LP_STATE",
                                   $sformatf("TxUlpsActive_n_LP_STATE failed at %0t: TxUlpsActive_n_o fell but LP_STATE is %0b instead of 2'b00.",
                                             $time,
                                             LP_STATE),
                                   uvm_pkg::UVM_NONE);

assert property (TxUlpsExit_UlpsActiveNot)
    else uvm_pkg::uvm_report_error("ASSERT_TXULPSEXIT_ULPSACTIVENOT",
                                   $sformatf("TxUlpsExit_UlpsActiveNot failed at %0t: TxUlpsExit_i rose while TxUlpsActive_n_o=%0b (expected 0 for active ULPS).",
                                             $time,
                                             clk_ppi.TxUlpsActive_n_o),
                                   uvm_pkg::UVM_NONE);

assert property (TxUlpsExit_LP_STATE)
    else uvm_pkg::uvm_report_error("ASSERT_TXULPSEXIT_LP_STATE",
                                   $sformatf("TxUlpsExit_LP_STATE failed at %0t: ULPS exit LP sequence or wakeup hold violated, LP_STATE=%0b, min wakeup cycles=%0d.",
                                             $time,
                                             LP_STATE,
                                             WAKEUP_TIME_CYCLES_MIN),
                                   uvm_pkg::UVM_NONE);


endmodule
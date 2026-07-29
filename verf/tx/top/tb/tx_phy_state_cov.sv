`timescale 1ns/1ps
// FSM state coverage + clk_state x data_state cross. Bound into tx_d_phy so it
// can see both lane state registers. States are passed as int (enum value).
module tx_phy_state_cov (
    input logic esc,
    input logic arstn,
    input int   clk_state,
    input int   data_state
);
    // Sample only when a lane state changes (cheap, captures every state/cross).
    covergroup cg @(clk_state or data_state);
        option.per_instance = 1;
        cp_clk  : coverpoint clk_state  iff (arstn);
        cp_data : coverpoint data_state iff (arstn);
        x_clk_data : cross cp_clk, cp_data;
    endgroup

    cg cg_inst = new();
endmodule

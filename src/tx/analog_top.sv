`timescale 1ns/1ps
module analog_top #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic       rstn_i,

        // Clock Lane
    tx_clk_analog_if.analog         clk_analog,
    tx_clk_d_phy_if.tx_d_phy_hs     clk_d_phy,
    
    // Data Lane 
    tx_data_analog_if.analog        data_analog,
    tx_data_d_phy_if.tx_d_phy_hs    data_d_phy,

    // Exported clocks for top-level observability
    output logic       clk_i_o,
    output logic       clk_q_o,
    output logic       clk_div8_o,
    output logic       pll_lock_o
);

    logic hs_clk_i;
    logic hs_clk_q;
    logic hs_clk_q_gated;
    logic hs_serial_data;

    // Analog I/Q clock generator: generates quadrature high-speed clocks.
    pll #(
        .SERIAL_CLK_PER(SERIAL_CLK_PER)
    ) u_pll (
        .in_phase_clk_o(hs_clk_i),
        .quadrature_clk_o(hs_clk_q)
    );

    // Required 8:1 ratio timing reference for the parallel interface.
    clk_div_by_8 u_clk_div_by_8 (
        .rstn_i(rstn_i),
        .clk_i(hs_clk_i),
        .clk_div8_o(clk_div8_o)
    );

    // 8:1 serializer: parallel side on clk_div8, serial side on I-phase high-speed clock.
    serializer_8to1 u_serializer_8to1 (
        .rstn_i(rstn_i),
        .clk_i(hs_clk_i),
        .clk_div8_i(clk_div8_o),
        .en_i(data_analog.serializer_en_o),
        .parallel_data_i(data_analog.parallel_data_o),
        .serial_data_o(hs_serial_data)
    );

    // Explicitly gate only the Q-phase clock with ddr_clk_buff_en.
    q_clock_gate u_q_clock_gate (
        .clk_q_i(hs_clk_q),
        .en_i(clk_analog.ddr_clk_buff_en),
        .clk_q_gated_o(hs_clk_q_gated)
    );

    // Differential data output stage.
    diff_data_driver u_diff_data_driver (
        .en_i(data_analog.serializer_en_o),
        .data_i(hs_serial_data),
        .dp_o(data_d_phy.hs_data_Dp_o),
        .dn_o(data_d_phy.hs_data_Dn_o)
    );

    // Differential clock output stage driven by gated Q-phase clock.
    diff_clk_driver u_diff_clk_driver (
        .en_i(clk_analog.ddr_clk_buff_en),
        .clk_i(hs_clk_q_gated),
        .dp_o(clk_d_phy.clk_HS_Dp_o),
        .dn_o(clk_d_phy.clk_HS_Dn_o)
    );

    assign clk_i_o = hs_clk_i;
    assign clk_q_o = hs_clk_q;
    assign pll_lock_o = rstn_i;

    // Export byte-clock reference back into digital control interfaces.
    assign clk_analog.clk_div = clk_div8_o;
    assign data_analog.tx_lane_clk_div_i = clk_div8_o;

endmodule


module pll(
    output logic in_phase_clk_o,
    output logic quadrature_clk_o
);
    parameter int unsigned SERIAL_CLK_PER = 8;
    bit i_clk;
    bit q_clk;

    always #(SERIAL_CLK_PER/2)
        i_clk <= ~i_clk;
    always@(*)
        q_clk <= #(SERIAL_CLK_PER/4) i_clk;
        
    assign in_phase_clk_o = i_clk;
    assign quadrature_clk_o = q_clk;
endmodule

module clk_div_by_8 (
    input  logic rstn_i,
    input  logic clk_i,
    output logic clk_div8_o
);
    logic [2:0] div_cnt;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            div_cnt    <= 3'd0;
            clk_div8_o <= 1'b0;
        end else begin
            if (div_cnt == 3'd3) begin
                div_cnt    <= 3'd0;
                clk_div8_o <= ~clk_div8_o;
            end else begin
                div_cnt <= div_cnt + 3'd1;
            end
        end
    end
endmodule

module serializer_8to1 (
    input  logic       rstn_i,
    input  logic       clk_i,
    input  logic       clk_div8_i,
    input  logic       en_i,
    input  logic [7:0] parallel_data_i,
    output logic       serial_data_o
);
    logic [7:0] shreg;
    logic [2:0] bit_cnt;
    logic       div8_sync_0;
    logic       div8_sync_1;

    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            div8_sync_0  <= 1'b0;
            div8_sync_1  <= 1'b0;
            shreg        <= 8'h00;
            bit_cnt      <= 3'd0;
            serial_data_o <= 1'b0;
        end else begin
            div8_sync_0 <= clk_div8_i;
            div8_sync_1 <= div8_sync_0;

            if (!en_i) begin
                shreg         <= 8'h00;
                bit_cnt       <= 3'd0;
                serial_data_o <= 1'b0;
            end else if (div8_sync_0 && !div8_sync_1) begin
                // LSB-first (MIPI D-PHY: LSB transmitted first). Pre-shift the loaded
                // byte: bit 0 goes out now, so the shift register holds bits [7:1]
                // for the following cycles.
                shreg         <= {1'b0, parallel_data_i[7:1]};
                bit_cnt       <= 3'd0;
                serial_data_o <= parallel_data_i[0];
            end else begin
                serial_data_o <= shreg[0];
                shreg         <= {1'b0, shreg[7:1]};
                bit_cnt       <= bit_cnt + 3'd1;
            end
        end
    end
endmodule

module q_clock_gate (
    input  logic clk_q_i,
    input  logic en_i,
    output logic clk_q_gated_o
);
    logic en_lat;

    // Latch enable during clock low phase to minimize gating glitches.
    always_latch begin
        if (!clk_q_i)
            en_lat <= en_i;
    end

    assign clk_q_gated_o = clk_q_i & en_lat;
endmodule

module diff_data_driver (
    input  logic en_i,
    input  logic data_i,
    output logic dp_o,
    output logic dn_o
);
    always_comb begin
        if (en_i) begin
            dp_o = data_i;
            dn_o = ~data_i;
        end else begin
            dp_o = 1'b1;
            dn_o = 1'b1;
        end
    end
endmodule

module diff_clk_driver (
    input  logic en_i,
    input  logic clk_i,
    output logic dp_o,
    output logic dn_o
);
    always_comb begin
        if (en_i) begin
            dp_o = clk_i;
            dn_o = ~clk_i;
        end else begin
            dp_o = 1'b1;
            dn_o = 1'b1;
        end
    end
endmodule

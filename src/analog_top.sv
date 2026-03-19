module analog_top #(
    parameter int unsigned SERIAL_CLK_PER = 8
) (
    input  logic       rstn_i,
    input  logic       ref_clk_i,

    // Digital-front-end interface
    input  logic       serializer_en_i,
    input  logic [7:0] parallel_data_i,
    input  logic       ddr_clk_buff_en_i,

    // High-speed differential outputs
    output logic       hs_data_dp_o,
    output logic       hs_data_dn_o,
    output logic       hs_clk_dp_o,
    output logic       hs_clk_dn_o,

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
        .en_i(serializer_en_i),
        .parallel_data_i(parallel_data_i),
        .serial_data_o(hs_serial_data)
    );

    // Explicitly gate only the Q-phase clock with ddr_clk_buff_en.
    q_clock_gate u_q_clock_gate (
        .clk_q_i(hs_clk_q),
        .en_i(ddr_clk_buff_en_i),
        .clk_q_gated_o(hs_clk_q_gated)
    );

    // Differential data output stage.
    diff_data_driver u_diff_data_driver (
        .en_i(serializer_en_i),
        .data_i(hs_serial_data),
        .dp_o(hs_data_dp_o),
        .dn_o(hs_data_dn_o)
    );

    // Differential clock output stage driven by gated Q-phase clock.
    diff_clk_driver u_diff_clk_driver (
        .en_i(ddr_clk_buff_en_i),
        .clk_i(hs_clk_q_gated),
        .dp_o(hs_clk_dp_o),
        .dn_o(hs_clk_dn_o)
    );

    assign clk_i_o = hs_clk_i;
    assign clk_q_o = hs_clk_q;

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
                shreg         <= parallel_data_i;
                bit_cnt       <= 3'd0;
                serial_data_o <= parallel_data_i[7];
            end else begin
                serial_data_o <= shreg[7];
                shreg         <= {shreg[6:0], 1'b0};
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

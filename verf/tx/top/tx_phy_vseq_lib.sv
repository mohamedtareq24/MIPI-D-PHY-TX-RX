// Base virtual sequence: gains access to both lane sequencers via p_sequencer.
class tx_phy_base_vseq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(tx_phy_base_vseq)
    `uvm_declare_p_sequencer(tx_phy_vseqr)

    function new(string name = "tx_phy_base_vseq");
        super.new(name);
    endfunction

    // Bring both lanes up to StopState: clock lane first (it enables the Esc
    // clock and the byte clock path), then the data lane.
    task powerup();
        ppi_clk_tr     clk_tr;
        ppi_tx_data_tr data_tr;
        // Both lane packages export LANE_EN; qualify to avoid the wildcard-import clash.
        `uvm_do_on_with(clk_tr,  p_sequencer.clk_seqncr,  { transaction_type == ppi_clk_pkg::LANE_EN; })
        `uvm_do_on_with(data_tr, p_sequencer.data_seqncr, { transaction_type == ppi_data_pkg::LANE_EN; })
    endtask

    // One HS burst of `size` bytes with its own clock-HS window. Sizing the clock
    // window per burst (rather than one window for many bursts) avoids the clock
    // stopping mid-burst, which would leave the data serializer stalled. 900 active
    // cycles span up to 16 payload bytes plus SoT/trail/framing (~20 cyc/byte) and
    // stay under the ppi_clk_tr constraint num_hs_active_cycles < 1000.
    task hs_one(int unsigned size);
        ppi_clk_tr     clk_tr;
        ppi_tx_data_tr data_tr;
        fork
            `uvm_do_on_with(clk_tr, p_sequencer.clk_seqncr,
                            { transaction_type == HS_CLK; num_hs_active_cycles == 900; })
            begin
                #5000;
                `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                                { transaction_type == HS_DATA; payload_size == size; })
            end
        join
    endtask
endclass

// Powerup only: both lanes reach StopState.
class tx_phy_powerup_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_powerup_vseq)
    function new(string name = "tx_phy_powerup_vseq"); super.new(name); endfunction
    virtual task body();
        powerup();
    endtask
endclass

// Integrated smoke: powerup, then hold clock HS while a data HS burst runs.
// Enforces the D-PHY clock-before-data ordering (clock HS provides the byte
// clock the data lane needs).
class tx_phy_smoke_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_smoke_vseq)
    function new(string name = "tx_phy_smoke_vseq"); super.new(name); endfunction

    virtual task body();
        ppi_clk_tr     clk_tr;
        ppi_tx_data_tr data_tr;

        powerup();

        fork
            // Clock lane HS held long enough to span the data burst.
            `uvm_do_on_with(clk_tr, p_sequencer.clk_seqncr,
                            { transaction_type == HS_CLK; num_hs_active_cycles == 400; })
            begin
                // Small lead so the clock lane reaches HS first.
                #5000;
                `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                                { transaction_type == HS_DATA; payload_size == 4; })
            end
        join
    endtask
endclass

// Regression: varied HS payload sizes under clock HS, then escape ULPS + all
// four trigger commands. Fills the functional coverage model.
class tx_phy_regress_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_regress_vseq)
    function new(string name = "tx_phy_regress_vseq"); super.new(name); endfunction

    virtual task body();
        ppi_clk_tr     clk_tr;
        ppi_tx_data_tr data_tr;
        int        sizes [4] = '{1, 2, 5, 12};       // one / two / small / large bins
        bit [3:0]  trgs  [4] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};

        powerup();

        // HS bursts of varied sizes while clock HS is held.
        fork
            `uvm_do_on_with(clk_tr, p_sequencer.clk_seqncr,
                            { transaction_type == HS_CLK; num_hs_active_cycles == 400; })
            begin
                #5000;
                foreach (sizes[i])
                    `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                                    { transaction_type == HS_DATA; payload_size == sizes[i]; })
            end
        join

        // Escape mode (clock lane back in stop): ULPS enter/exit + each trigger.
        `uvm_do_on_with(data_tr, p_sequencer.data_seqncr, { transaction_type == ULPS_DATA; })
        foreach (trgs[i])
            `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                            { transaction_type == TRGR_DATA; trgr_type == trgs[i]; })
    endtask
endclass

// Inclusive (directed): every HS payload size 1..16 under one clock-HS window,
// then escape ULPS + all four trigger commands. Covers every supported case.
class tx_phy_inclusive_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_inclusive_vseq)
    function new(string name = "tx_phy_inclusive_vseq"); super.new(name); endfunction

    virtual task body();
        ppi_tx_data_tr data_tr;
        bit [3:0] trgs [4] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};

        powerup();

        // Every HS payload size 1..16, each in its own clock-HS window.
        for (int s = 1; s <= 16; s++) hs_one(s);

        // Escape mode (clock lane in stop): ULPS + each trigger command.
        `uvm_do_on_with(data_tr, p_sequencer.data_seqncr, { transaction_type == ULPS_DATA; })
        foreach (trgs[i])
            `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                            { transaction_type == TRGR_DATA; trgr_type == trgs[i]; })
    endtask
endclass

// Randomized: 15 randomly-chosen transactions (HS of random size under its own
// clock-HS window, ULPS, or a random single trigger command).
class tx_phy_random_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_random_vseq)
    int unsigned num_txns = 15;
    function new(string name = "tx_phy_random_vseq"); super.new(name); endfunction

    virtual task body();
        ppi_tx_data_tr data_tr;
        bit [3:0] trgs [4] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};
        powerup();
        for (int i = 0; i < num_txns; i++) begin
            int sel = $urandom_range(0, 2);
            case (sel)
                0: hs_one($urandom_range(1, 16));
                1: begin
                    `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                                    { transaction_type == ULPS_DATA; })
                end
                default: begin
                    bit [3:0] t = trgs[$urandom_range(0, 3)];
                    `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                                    { transaction_type == TRGR_DATA; trgr_type == t; })
                end
            endcase
        end
    endtask
endclass

// Escape-only: powerup then ULPS + all four triggers (no HS, no clock HS).
// Short sim; exercises the escape path / ULPS+trigger coverage on its own.
class tx_phy_escape_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_escape_vseq)
    function new(string name = "tx_phy_escape_vseq"); super.new(name); endfunction

    virtual task body();
        ppi_tx_data_tr data_tr;
        bit [3:0] trgs [4] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};
        powerup();
        `uvm_do_on_with(data_tr, p_sequencer.data_seqncr, { transaction_type == ULPS_DATA; })
        foreach (trgs[i])
            `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                            { transaction_type == TRGR_DATA; trgr_type == trgs[i]; })
    endtask
endclass

// LPDT: powerup, then send low-power data payloads of varied sizes (clock lane
// stays in Stop — LPDT uses the Esc clock, not the HS byte clock).
class tx_phy_lpdt_vseq extends tx_phy_base_vseq;
    `uvm_object_utils(tx_phy_lpdt_vseq)
    function new(string name = "tx_phy_lpdt_vseq"); super.new(name); endfunction

    virtual task body();
        ppi_tx_data_tr data_tr;
        int sizes [3] = '{1, 4, 8};
        powerup();
        foreach (sizes[i])
            `uvm_do_on_with(data_tr, p_sequencer.data_seqncr,
                            { transaction_type == LPDT_DATA; lpdt_size == sizes[i]; })
    endtask
endclass

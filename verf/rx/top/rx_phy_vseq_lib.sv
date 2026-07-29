// Virtual sequences: coordinate clock-lane + data-lane stimulus via p_sequencer.
class rx_phy_vseq_base extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(rx_phy_vseq_base)
    `uvm_declare_p_sequencer(rx_phy_vseqr)
    function new(string name = "rx_phy_vseq_base"); super.new(name); endfunction

    // One HS burst: start the recovered clock, send the data burst, stop clock.
    task hs_burst(int unsigned size);
        rx_clk_hs_start_seq cs = rx_clk_hs_start_seq::type_id::create("cs");
        rx_clk_hs_stop_seq  ce = rx_clk_hs_stop_seq::type_id::create("ce");
        rx_data_hs_seq      ds = rx_data_hs_seq::type_id::create("ds");
        cs.start(p_sequencer.clk_seqr);    // clock now free-running
        ds.size = size;
        ds.start(p_sequencer.data_seqr);   // data burst (waits for drain)
        ce.start(p_sequencer.clk_seqr);    // stop clock, park LP-11
    endtask
endclass

// Single HS burst (smoke).
class rx_phy_hs_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_hs_vseq)
    function new(string name = "rx_phy_hs_vseq"); super.new(name); endfunction
    virtual task body();
        hs_burst(4);
    endtask
endclass

// Escape ULPS (data-lane LP only; clock lane stays in Stop).
class rx_phy_ulps_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_ulps_vseq)
    function new(string name = "rx_phy_ulps_vseq"); super.new(name); endfunction
    virtual task body();
        rx_data_ulps_seq ds = rx_data_ulps_seq::type_id::create("ds");
        ds.start(p_sequencer.data_seqr);
    endtask
endclass

// Escape remote triggers (all four; data-lane LP only).
class rx_phy_trigger_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_trigger_vseq)
    function new(string name = "rx_phy_trigger_vseq"); super.new(name); endfunction
    virtual task body();
        rx_data_trigger_seq ds = rx_data_trigger_seq::type_id::create("ds");
        ds.start(p_sequencer.data_seqr);
    endtask
endclass

// Combined regression: varied-size HS bursts, then ULPS, then all triggers.
class rx_phy_regress_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_regress_vseq)
    function new(string name = "rx_phy_regress_vseq"); super.new(name); endfunction
    virtual task body();
        int sizes[4] = '{1, 2, 5, 12};
        rx_data_ulps_seq    us = rx_data_ulps_seq::type_id::create("us");
        rx_data_trigger_seq ts = rx_data_trigger_seq::type_id::create("ts");
        foreach (sizes[i]) hs_burst(sizes[i]);
        us.start(p_sequencer.data_seqr);
        ts.start(p_sequencer.data_seqr);
    endtask
endclass

// Inclusive (directed) regression: every HS payload size 1..16, then ULPS, then
// all four trigger commands. Exercises every supported case exactly once.
class rx_phy_inclusive_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_inclusive_vseq)
    function new(string name = "rx_phy_inclusive_vseq"); super.new(name); endfunction
    virtual task body();
        rx_data_ulps_seq    us = rx_data_ulps_seq::type_id::create("us");
        rx_data_trigger_seq ts = rx_data_trigger_seq::type_id::create("ts");
        for (int s = 1; s <= 16; s++) hs_burst(s);
        us.start(p_sequencer.data_seqr);
        ts.start(p_sequencer.data_seqr);
    endtask
endclass

// LPDT: data-lane LP only (clock lane stays in Stop).
class rx_phy_lpdt_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_lpdt_vseq)
    function new(string name = "rx_phy_lpdt_vseq"); super.new(name); endfunction
    virtual task body();
        int sizes[3] = '{1, 4, 8};
        foreach (sizes[i]) begin
            rx_data_lpdt_seq ds = rx_data_lpdt_seq::type_id::create("ds");
            ds.size = sizes[i];
            ds.start(p_sequencer.data_seqr);
        end
    endtask
endclass

// Randomized regression: 15 randomly-chosen transactions (HS of random size,
// ULPS, or a random single trigger).
class rx_phy_random_vseq extends rx_phy_vseq_base;
    `uvm_object_utils(rx_phy_random_vseq)
    int unsigned num_txns = 15;
    function new(string name = "rx_phy_random_vseq"); super.new(name); endfunction
    virtual task body();
        for (int i = 0; i < num_txns; i++) begin
            int sel = $urandom_range(0, 2);
            case (sel)
                0: hs_burst($urandom_range(1, 16));
                1: begin
                    rx_data_ulps_seq us = rx_data_ulps_seq::type_id::create("us");
                    us.start(p_sequencer.data_seqr);
                end
                default: begin
                    rx_data_trigger_one_seq ts = rx_data_trigger_one_seq::type_id::create("ts");
                    if (!ts.randomize())
                        `uvm_fatal("RAND", "rx_data_trigger_one_seq randomize failed")
                    ts.start(p_sequencer.data_seqr);
                end
            endcase
        end
    endtask
endclass

// Base sequence: one randomized data-lane transaction.
class ppi_data_base_seq extends uvm_sequence #(ppi_tx_data_tr);
    `uvm_object_utils(ppi_data_base_seq)

    function new(string name = "ppi_data_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        req = ppi_tx_data_tr::type_id::create("req");
        start_item(req);
        if (!req.randomize())
            `uvm_error("RANDFAIL", "ppi_tx_data_tr randomize failed")
        finish_item(req);
    endtask
endclass

// PHY bring-up.
class ppi_data_en_seq extends ppi_data_base_seq;
    `uvm_object_utils(ppi_data_en_seq)
    function new(string name = "ppi_data_en_seq"); super.new(name); endfunction
    virtual task body();
        req = ppi_tx_data_tr::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { transaction_type == LANE_EN; })
            `uvm_error("RANDFAIL", "en seq randomize failed")
        finish_item(req);
    endtask
endclass

// HS data burst.
class ppi_data_hs_seq extends ppi_data_base_seq;
    `uvm_object_utils(ppi_data_hs_seq)
    function new(string name = "ppi_data_hs_seq"); super.new(name); endfunction
    virtual task body();
        req = ppi_tx_data_tr::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { transaction_type == HS_DATA; })
            `uvm_error("RANDFAIL", "hs seq randomize failed")
        finish_item(req);
    endtask
endclass

// Escape ULPS.
class ppi_data_ulps_seq extends ppi_data_base_seq;
    `uvm_object_utils(ppi_data_ulps_seq)
    function new(string name = "ppi_data_ulps_seq"); super.new(name); endfunction
    virtual task body();
        req = ppi_tx_data_tr::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { transaction_type == ULPS_DATA; })
            `uvm_error("RANDFAIL", "ulps seq randomize failed")
        finish_item(req);
    endtask
endclass

// Escape trigger command.
class ppi_data_trgr_seq extends ppi_data_base_seq;
    `uvm_object_utils(ppi_data_trgr_seq)
    function new(string name = "ppi_data_trgr_seq"); super.new(name); endfunction
    virtual task body();
        req = ppi_tx_data_tr::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { transaction_type == TRGR_DATA; })
            `uvm_error("RANDFAIL", "trgr seq randomize failed")
        finish_item(req);
    endtask
endclass

// Escape LPDT (low-power data transmission).
class ppi_data_lpdt_seq extends ppi_data_base_seq;
    `uvm_object_utils(ppi_data_lpdt_seq)
    rand int unsigned size = 4;
    function new(string name = "ppi_data_lpdt_seq"); super.new(name); endfunction
    virtual task body();
        req = ppi_tx_data_tr::type_id::create("req");
        start_item(req);
        if (!req.randomize() with { transaction_type == LPDT_DATA; lpdt_size == size; })
            `uvm_error("RANDFAIL", "lpdt seq randomize failed")
        finish_item(req);
    endtask
endclass

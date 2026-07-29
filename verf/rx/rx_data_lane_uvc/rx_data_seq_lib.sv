// RX data-lane sequences (data-lane stimulus only; the HS clock is sequenced by
// the top-level virtual sequence).
class rx_data_base_seq extends uvm_sequence #(rx_data_tr);
    `uvm_object_utils(rx_data_base_seq)
    function new(string name = "rx_data_base_seq"); super.new(name); endfunction
endclass

class rx_data_hs_seq extends rx_data_base_seq;
    `uvm_object_utils(rx_data_hs_seq)
    rand int unsigned size = 4;
    function new(string name = "rx_data_hs_seq"); super.new(name); endfunction
    virtual task body();
        rx_data_tr tr = rx_data_tr::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with { txn_type == RX_HS_BURST; payload_size == size; })
            `uvm_fatal("RAND", "rx_data_tr randomize failed")
        finish_item(tr);
    endtask
endclass

class rx_data_ulps_seq extends rx_data_base_seq;
    `uvm_object_utils(rx_data_ulps_seq)
    function new(string name = "rx_data_ulps_seq"); super.new(name); endfunction
    virtual task body();
        rx_data_tr tr = rx_data_tr::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with { txn_type == RX_ULPS; })
            `uvm_fatal("RAND", "rx_data_tr randomize failed")
        tr.esc_cmd = RX_CMD_ULPS;
        finish_item(tr);
    endtask
endclass

class rx_data_trigger_seq extends rx_data_base_seq;
    `uvm_object_utils(rx_data_trigger_seq)
    function new(string name = "rx_data_trigger_seq"); super.new(name); endfunction
    virtual task body();
        bit [7:0] cmds[4] = '{RX_CMD_TRGR0, RX_CMD_TRGR1, RX_CMD_TRGR2, RX_CMD_TRGR3};
        bit [3:0] sels[4] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};
        foreach (cmds[i]) begin
            rx_data_tr tr = rx_data_tr::type_id::create("tr");
            start_item(tr);
            if (!tr.randomize() with { txn_type == RX_TRIGGER; })
                `uvm_fatal("RAND", "rx_data_tr randomize failed")
            tr.esc_cmd = cmds[i];
            tr.trgr    = sels[i];
            finish_item(tr);
        end
    endtask
endclass

// One trigger command, selected by `which` (0..3). Used by the random regression.
class rx_data_trigger_one_seq extends rx_data_base_seq;
    `uvm_object_utils(rx_data_trigger_one_seq)
    rand bit [1:0] which;
    function new(string name = "rx_data_trigger_one_seq"); super.new(name); endfunction
    virtual task body();
        bit [7:0] cmds[4] = '{RX_CMD_TRGR0, RX_CMD_TRGR1, RX_CMD_TRGR2, RX_CMD_TRGR3};
        bit [3:0] sels[4] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};
        rx_data_tr tr = rx_data_tr::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with { txn_type == RX_TRIGGER; })
            `uvm_fatal("RAND", "rx_data_tr randomize failed")
        tr.esc_cmd = cmds[which];
        tr.trgr    = sels[which];
        finish_item(tr);
    endtask
endclass

class rx_data_lpdt_seq extends rx_data_base_seq;
    `uvm_object_utils(rx_data_lpdt_seq)
    rand int unsigned size = 4;
    function new(string name = "rx_data_lpdt_seq"); super.new(name); endfunction
    virtual task body();
        rx_data_tr tr = rx_data_tr::type_id::create("tr");
        start_item(tr);
        if (!tr.randomize() with { txn_type == RX_LPDT; lpdt_size == size; })
            `uvm_fatal("RAND", "rx_data_tr (LPDT) randomize failed")
        tr.esc_cmd = RX_CMD_LPDT;
        finish_item(tr);
    endtask
endclass

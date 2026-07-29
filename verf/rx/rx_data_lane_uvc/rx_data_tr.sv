// RX data-lane transaction + shared escape-command constants.
typedef enum { RX_HS_BURST, RX_ULPS, RX_TRIGGER, RX_LPDT } rx_txn_type_e;

// Escape entry command bytes used as STIMULUS (driven MSB-first on the LP lines).
// Golden values come from the shared spec oracle (mipi_spec_pkg, spec §2.2 /
// docs/MIPI_DPHY_SPEC_REQUIREMENTS.md) — NOT from the RTL. The RTL has its own
// copy; a DUT divergence is a DUT bug. The expected RX response is derived
// independently in rx_phy_scoreboard, never authored alongside the stimulus.
localparam logic [7:0] RX_CMD_ULPS  = mipi_spec_pkg::CMD_ULPS;
localparam logic [7:0] RX_CMD_TRGR0 = mipi_spec_pkg::CMD_TRGR0;
localparam logic [7:0] RX_CMD_TRGR1 = mipi_spec_pkg::CMD_TRGR1;
localparam logic [7:0] RX_CMD_TRGR2 = mipi_spec_pkg::CMD_TRGR2;
localparam logic [7:0] RX_CMD_TRGR3 = mipi_spec_pkg::CMD_TRGR3;
localparam logic [7:0] RX_CMD_LPDT  = mipi_spec_pkg::CMD_LPDT;

// An HS burst payload (also used by the monitor to carry the recovered bytes
// back to the scoreboard).
class rx_data_tr extends uvm_sequence_item;
    rand rx_txn_type_e  txn_type;
    rand int unsigned   payload_size;
    rand bit [7:0]      payload[];
    bit [7:0]           esc_cmd;   // escape command byte (ULPS / TRIGGER / LPDT)
    bit [3:0]           trgr;      // expected one-hot trigger (TRIGGER)

    rand int unsigned lpdt_size;
    rand bit [7:0]    lpdt_payload[];   // driven (and, in the recovered txn, captured)

    constraint c_size {
        payload_size inside {[1:16]};
        payload.size() == payload_size;
    }

    constraint c_lpdt {
        lpdt_size inside {[1:8]};
        lpdt_payload.size() == lpdt_size;
    }

    `uvm_object_utils_begin(rx_data_tr)
        `uvm_field_int(payload_size, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "rx_data_tr");
        super.new(name);
    endfunction
endclass

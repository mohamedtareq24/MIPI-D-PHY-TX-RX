typedef enum { HS_DATA, ULPS_DATA, TRGR_DATA, LPDT_DATA, LANE_EN } transaction_type_t;

class ppi_tx_data_tr extends uvm_sequence_item;
    `uvm_object_utils(ppi_tx_data_tr)

    rand transaction_type_t transaction_type;

    // HS payload
    rand byte unsigned payload [$];
    rand int unsigned  payload_size;
    rand int unsigned  throttle_delay;

    // Escape trigger select (one-hot: [0]=RESET [1]=HSTEST [2]=UNKNOWN4 [3]=UNKNOWN5)
    rand bit [3:0] trgr_type;

    // Escape-mode skew delays (Esc clock cycles)
    rand int unsigned tx_ulps_esc_req_delay;
    rand int unsigned ulps_active_delay;
    rand int unsigned tx_trgr_esc_req_delay;

    // Raw recovered serial bits (transmission order; decoded LSB-first by the
    // scoreboard), filled by the recovery monitor.
    bit recovered_bits [$];

    // Escape command byte recovered off the LP lines (spec Table 10), filled by
    // the escape recovery monitor for ULPS_DATA / TRGR_DATA transactions.
    byte unsigned recovered_esc_cmd;

    // LPDT payload to transmit (also reused by the recovery monitor to carry the
    // bytes decoded off the LP lines back to the scoreboard).
    rand byte unsigned lpdt_payload [$];
    rand int unsigned  lpdt_size;
    byte unsigned      recovered_payload [$];

    constraint lpdt_size_c {
        lpdt_size inside {[1:8]};
        lpdt_payload.size() == lpdt_size;
    }

    constraint payload_size_c {
        payload_size inside {[1:16]};
        payload.size() == payload_size;
    }

    // DUT decodes TxTriggerEsc_i as one-hot, so constrain it that way.
    constraint trgr_onehot_c { $onehot(trgr_type); }

    constraint delay_c {
        throttle_delay        inside {[0:4]};
        tx_ulps_esc_req_delay inside {[1:20]};
        ulps_active_delay     inside {[1:20]};
        tx_trgr_esc_req_delay inside {[1:20]};
    }

    function new(string name = "ppi_tx_data_tr");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("type=%s size=%0d trgr=%04b",
                         transaction_type.name(), payload_size, trgr_type);
    endfunction
endclass

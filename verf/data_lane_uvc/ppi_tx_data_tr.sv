typedef enum  { HS_DATA , ULPS_DATA, TRGR_DATA,LANE_EN} transaction_type_t;

class ppi_tr extends uvm_sequence_item;
    `uvm_object_utils(ppi_tr)
    
    rand byte   payload [$];
    rand int    payload_size;
    rand int    throttle_delay;
    rand transaction_type_t transaction_type;

    rand int is_rst_trgr;
    rand int is_hstst_trgr;
    rand int is_unknown4_trgr;
    rand int is_unknown5_trgr;
    
    bit [3:0] trgr_type = {is_unknown5_trgr, is_unknown4_trgr, is_hstst_trgr, is_rst_trgr};
    // Signals Random Skew delays
    rand int tx_ulps_esc_req_delay;
    rand int tx_ulps_esc_deassrt_delay;
    rand int trgr_esc_req_deassrt_delay;

    constraint payload_c {
        payload.size() == payload_size;
        foreach (payload[i]) begin
            payload[i] inside {[0:255]};
        end
    }
    function new(string name = "ppi_tr");
        super.new(name);
    endfunction

endclass
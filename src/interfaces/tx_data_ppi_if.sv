interface tx_data_ppi_if();
    // PPI Control 
    logic TxClkEsc_i;
    logic enable_i;
    logic ForceTXStopmode_i;
    logic StopState_o; 

    // PPI Data 
    logic       TxRequestHS_i;
    logic [7:0] TxDataHS_i;
    logic [1:0] TxDataWidthHS_i;
    logic [3:0] TxWordValidHS_i;
    logic       TxDataTransferEnHS_i;
    logic       TxReadyHS_o;
    // PPI Esc
    logic TxRequestEsc_i;
    logic [3:0] TxTriggerEsc_i;
    logic TxUlpsEsc_i;
    logic TxUlpsExit_i;
    logic TxUlpsActive_n_o;

    modport tx (
        input   TxClkEsc_i,
        input   enable_i,
        input   ForceTXStopmode_i,
        output  StopState_o,

        input   TxRequestHS_i,
        input   TxDataHS_i,
        input   TxDataWidthHS_i,
        input   TxWordValidHS_i,
        input   TxDataTransferEnHS_i,
        output  TxReadyHS_o,

        input   TxRequestEsc_i,
        input   TxTriggerEsc_i,
        input   TxUlpsEsc_i,
        input   TxUlpsExit_i,
        output  TxUlpsActive_n_o
    );

endinterface
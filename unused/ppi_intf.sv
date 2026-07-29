interface ppi_intf;
    
    ///////////////////////////////// HS RX    
    logic       RxWordClkHS;
    logic [1:0] RxDataWidthHS;
    logic [7:0] RxDataHS;
    logic [3:0] RxValidHS;
    logic       RxActiveHS;
    logic       RxSyncHS;
    logic       RxDetectEobHS;  
    logic       RxClkActiveHS;
    logic       RxDDRClkHS;
    logic       RxSkewCalHS;
    logic       RxAlternateCalHS;
    logic       RxErrorCalHS;
    ///////////////////////////////// HS TX
    logic TxWordClkHS;
    logic [1:0] TxDataWidthHS;
    logic [7:0] TxDataHS;
    logic [3:0] TxWordValidHS;
    logic TxEqActiveHS;
    logic TxEqLevelHS;
    logic TxRequestHS;
    logic TxReadyHS;
    logic TxDataTransferEnHS;
    logic TxSkewCalHS;
    logic TxAlternateCalHS;
    /////////////////////////////////ESC RX
    logic RxClkEsc;
    logic RxLpdtEsc;
    logic RxUlpsEsc;
    logic [3:0] RxTriggerEsc;
    logic RxWakeup;
    logic [7:0] RxDataEsc;
    logic RxValidEsc;
    /////////////////////////////////ESC TX
    logic TxClkEsc;
    logic TxRequestEsc;
    logic [3:0] TxRequestTypeEsc;
    logic TxLpdtEsc;
    logic TxUlpsExit;
    logic TxUlpsEsc;
    logic [3:0] TxTriggerEsc;
    logic [7:0] TxDataEsc;
    logic TxValidEsc;
    logic TxReadyEsc;
    ///////////////////////////////// Error signals 
    logic ErrSotHS;
    logic ErrSotSyncHS;
    logic ErrEsc;
    logic ErrSyncEsc;
    logic ErrControl;
    logic ErrContentionLP0;
    logic ErrContentionLP1;


    
endinterface
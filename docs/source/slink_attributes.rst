S-Link Attributes
-----------------
.. table::
  :widths: 10 30 10 10 20 50

  ======== ============= ====== ======== ================== ===============================================================================================
  Address  Name          Width  ReadOnly Reset              Description                                                                                    
  ======== ============= ====== ======== ================== ===============================================================================================
  0x0      max_txs       3      1        NUM_TX_LANES_CLOG2 Maximum number of TX lanes this S-Link supports                                                
  0x1      max_rxs       3      1        NUM_RX_LANES_CLOG2 Maximum number of RX lanes this S-Link supports                                                
  0x2      active_txs    3      0        NUM_TX_LANES_CLOG2 Active TX lanes                                                                                
  0x3      active_rxs    3      0        NUM_RX_LANES_CLOG2 Active RX lanes                                                                                
  0x8      hard_reset_us 10     0        100                Time (in us) at which a Hard Reset Condition is detected.                                      
  0x10     px_clk_trail  8      0        32                 Number of clock cycles to run the bitclk when going to a P state that doesn't supply the bitclk
  0x20     p1_ts1_tx     16     0        32                 TS1s to send if exiting from P1                                                                
  0x21     p1_ts1_rx     16     0        32                 TS1s to receive if exiting from P1                                                             
  0x22     p1_ts2_tx     16     0        4                  TS2s to send if exiting from P1                                                                
  0x23     p1_ts2_rx     16     0        4                  TS2s to receive if exiting from P1                                                             
  0x24     p2_ts1_tx     16     0        64                 TS1s to send if exiting from P2                                                                
  0x25     p2_ts1_rx     16     0        64                 TS1s to receive if exiting from P2                                                             
  0x26     p2_ts2_tx     16     0        8                  TS2s to send if exiting from P2                                                                
  0x27     p2_ts2_rx     16     0        8                  TS2s to receive if exiting from P2                                                             
  0x28     p3r_ts1_tx    16     0        128                TS1s to send if exiting from P3 or when coming out of reset                                    
  0x29     p3r_ts1_rx    16     0        128                TS1s to receive if exiting from P3 or when coming out of reset                                 
  0x2a     p3r_ts2_tx    16     0        16                 TS2s to send if exiting from P3 or when coming out of reset                                    
  0x2b     p3r_ts2_rx    16     0        16                 TS2s to receive if exiting from P3 or when coming out of reset                                 
  0x30     sync_freq     8      0        15                 How often SYNC Ordered Sets are sent during training                                           
  ======== ============= ====== ======== ================== ===============================================================================================

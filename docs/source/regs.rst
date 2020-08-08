SLINK_CTRL Registers
====================
SWRESET
-------

Address: 0x0

Description: 

.. table::
  :widths: 25 10 10 10 50

  ======= ======== ======== ========== ================================================
  Name    Index    Type     Reset      Description                                     
  ======= ======== ======== ========== ================================================
  SWRESET [0]      RW       0x1        Main reset. Must be cleared prior to operation. 
  ======= ======== ======== ========== ================================================


ENABLE
------

Address: 0x4

Description: 

.. table::
  :widths: 25 10 10 10 50

  ====== ======== ======== ========== ======================================================================================================
  Name   Index    Type     Reset      Description                                                                                           
  ====== ======== ======== ========== ======================================================================================================
  ENABLE [0]      RW       0x0        Main enable. Must be set prior to operation. Any configurations should be performed prior to enabling.
  ====== ======== ======== ========== ======================================================================================================


INTERRUPT_STATUS
----------------

Address: 0x8

Description: 

.. table::
  :widths: 25 10 10 10 50

  ====================== ======== ======== ========== =====================================================================================================================
  Name                   Index    Type     Reset      Description                                                                                                          
  ====================== ======== ======== ========== =====================================================================================================================
  ECC_CORRUPTED          [0]      W1C      0x0        Indicates that a packet header was received with the ECC corrupted.                                                  
  ECC_CORRECTED          [1]      W1C      0x0        Indicates that a packet header was received with the ECC corrected.                                                  
  CRC_CORRUPTED          [2]      W1C      0x0        Indicates that a long packet was received and the received CRC did not match the calculated CRC based on the payload.
  AUX_RX_FIFO_WRITE_FULL [3]      W1C      0x0        Indicates that a packet was attempted to be written in the AUX RX FIFO but the FIFO was full on the write attempt.   
  RESET_SEEN             [4]      W1C      0x0        Indicates a reset condition was seen                                                                                 
  WAKE_SEEN              [5]      W1C      0x0        Indicates a wake condition was seen                                                                                  
  IN_PSTATE              [6]      W1C      0x0        Indicates the link has entered into a P state (only asserts on entry)                                                
  ====================== ======== ======== ========== =====================================================================================================================


INTERRUPT_ENABLE
----------------

Address: 0xc

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============================= ======== ======== ========== ============================================
  Name                          Index    Type     Reset      Description                                 
  ============================= ======== ======== ========== ============================================
  ECC_CORRUPTED_INT_EN          [0]      RW       0x1        Enables the ecc_corrupted interrupt         
  ECC_CORRECTED_INT_EN          [1]      RW       0x1        Enables the ecc_corrected interrupt         
  CRC_CORRUPTED_INT_EN          [2]      RW       0x1        Enables the crc_corrupted interrupt         
  AUX_RX_FIFO_WRITE_FULL_INT_EN [3]      RW       0x1        Enables the aux_rx_fifo_write_full interrupt
  RESET_SEEN_INT_EN             [4]      RW       0x1        Enables the reset_seen interrupt            
  WAKE_SEEN_INT_EN              [5]      RW       0x0        Enables the wake_seen interrupt             
  IN_PSTATE_INT_EN              [6]      RW       0x0        Enables the in_pstate interrupt             
  ============================= ======== ======== ========== ============================================


PSTATE_CONTROL
--------------

Address: 0x10

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============== ======== ======== ========== =================================================================
  Name           Index    Type     Reset      Description                                                      
  ============== ======== ======== ========== =================================================================
  P1_STATE_ENTER [0]      RW       0x0        Set to enter P1 power state                                      
  P2_STATE_ENTER [1]      RW       0x0        Set to enter P2 power state                                      
  P3_STATE_ENTER [2]      RW       0x0        Set to enter P3 power state                                      
  RESERVED0      [29:3]   RO       0x0                                                                         
  LINK_RESET     [30]     RW       0x0        Forces the link to the reset state for both sides of the link    
  LINK_WAKE      [31]     RW       0x0        Forces the link to wake up to P0 without a packet being available
  ============== ======== ======== ========== =================================================================


ERROR_CONTROL
-------------

Address: 0x14

Description: 

.. table::
  :widths: 25 10 10 10 50

  ========================== ======== ======== ========== ==================================================================================================
  Name                       Index    Type     Reset      Description                                                                                       
  ========================== ======== ======== ========== ==================================================================================================
  ALLOW_ECC_CORRECTED        [0]      RW       0x1        1 - ECC Corrected conditions will not block the Packet Header from going to the application layer 
  ECC_CORRECTED_CAUSES_RESET [1]      RW       0x0        1 - ECC Corrected will cause S-Link to reset. This should not be set if allow_ecc_corrected is set
  ECC_CORRUPTED_CAUSES_RESET [2]      RW       0x1        1 - ECC Corrupted condition will cause S-Link to reset.                                           
  CRC_CORRUPTED_CAUSES_RESET [3]      RW       0x0        1 - CRC Corrupted condition will cause S-Link to reset.                                           
  ========================== ======== ======== ========== ==================================================================================================


COUNT_VAL_1US
-------------

Address: 0x18

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============= ======== ======== ========== =======================================
  Name          Index    Type     Reset      Description                            
  ============= ======== ======== ========== =======================================
  COUNT_VAL_1US [9:0]    RW       0x26       Number of REFCLK cycles that equal 1us.
  ============= ======== ======== ========== =======================================


AUX_LINK_CONTROL_STATUS
-----------------------

Address: 0x1c

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============================= ======== ======== ========== ===========================================================================================================================================================
  Name                          Index    Type     Reset      Description                                                                                                                                                
  ============================= ======== ======== ========== ===========================================================================================================================================================
  AUX_LINK_SHORT_PKT_MIN_FILTER [7:0]    RW       0x4        Used in conjuntion with aux_link_short_pkt_max_filter to *filter* certain short packets for receiption to the RX FIFOs.                                    
  AUX_LINK_SHORT_PKT_MAX_FILTER [15:8]   RW       0x4                                                                                                                                                                   
  AUX_LINK_FIFOS_ACTIVE         [16]     RO       0x0        1 - Software based S-Link AUX FIFOs are active. 0 - Software based S-Link FIFOs are inactive and thus software cannot be used to send/receive short packets
  ============================= ======== ======== ========== ===========================================================================================================================================================


AUX_LINK_TX_SHORT_PACKET
------------------------

Address: 0x20

Description: 

.. table::
  :widths: 25 10 10 10 50

  ======================== ======== ======== ========== =========================================================================================================================
  Name                     Index    Type     Reset      Description                                                                                                              
  ======================== ======== ======== ========== =========================================================================================================================
  AUX_LINK_TX_SHORT_PACKET [23:0]   WFIFO    0x0        Short packet to send via software FIFO. If aux_link_tx_wfull is asserted when this is written, the write will be ignored.
  RESERVED0                [29:24]  RO       0x0                                                                                                                                 
  AUX_LINK_TX_WFULL        [30]     RO       0x0        Indicates S-Link AUX TX FIFO is full and should not be written to.                                                       
  AUX_LINK_TX_REMPTY       [31]     RO       0x0        Indicates S-Link AUX TX FIFO is empty. Informative only.                                                                 
  ======================== ======== ======== ========== =========================================================================================================================


AUX_LINK_RX_SHORT_PACKET
------------------------

Address: 0x24

Description: 

.. table::
  :widths: 25 10 10 10 50

  ======================== ======== ======== ========== ===========================================================================================================================================================================================
  Name                     Index    Type     Reset      Description                                                                                                                                                                                
  ======================== ======== ======== ========== ===========================================================================================================================================================================================
  AUX_LINK_RX_SHORT_PACKET [23:0]   RFIFO    0x0        Short packet(s) received via S-Link RX based on aux_LINK filters. Reading this register causes the FIFO to "pop". If aux_link_rx_empty is asserted, nothing happens to the FIFO            
  ======================== ======== ======== ========== ===========================================================================================================================================================================================


AUX_LINK_RX_SHORT_PACKET_STATUS
-------------------------------

Address: 0x28

Description: 

.. table::
  :widths: 25 10 10 10 50

  ================== ======== ======== ========== =======================================================
  Name               Index    Type     Reset      Description                                            
  ================== ======== ======== ========== =======================================================
  AUX_LINK_RX_WFULL  [0]      RO       0x0        Indicates S-Link AUX RX FIFO is full. Informative only.
  AUX_LINK_RX_REMPTY [1]      RO       0x0        Indicates S-Link AUX RX FIFO is empty                  
  ================== ======== ======== ========== =======================================================


SW_ATTR_ADDR_DATA
-----------------

Address: 0x2c

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============ ======== ======== ========== ============================================
  Name         Index    Type     Reset      Description                                 
  ============ ======== ======== ========== ============================================
  SW_ATTR_ADDR [15:0]   RW       0x0        Address for software based attribute updates
  SW_ATTR_DATA [31:16]  RW       0x0        Data for software based attribute updates   
  ============ ======== ======== ========== ============================================


SW_ATTR_DATA_READ
-----------------

Address: 0x30

Description: 

.. table::
  :widths: 25 10 10 10 50

  ================= ======== ======== ========== ==========================================================================================================================================================================================
  Name              Index    Type     Reset      Description                                                                                                                                                                               
  ================= ======== ======== ========== ==========================================================================================================================================================================================
  SW_ATTR_DATA_READ [15:0]   RO       0x0        Shadow attribute data based on the sw_attr_addr value. *The sw_attr_data_read is actually only the link_clk, so it is advised to set the sw_attr_addr for several cycles prior to reading*
  ================= ======== ======== ========== ==========================================================================================================================================================================================


SW_ATTR_SHADOW_UPDATE
---------------------

Address: 0x34

Description: 

.. table::
  :widths: 25 10 10 10 50

  ===================== ======== ======== ========== ============================================================================
  Name                  Index    Type     Reset      Description                                                                 
  ===================== ======== ======== ========== ============================================================================
  SW_ATTR_SHADOW_UPDATE [0]      WFIFO    0x0        Write a 1 to update the current sw_attr_addr with the current sw_attr_data. 
  ===================== ======== ======== ========== ============================================================================


SW_ATTR_EFFECTIVE_UPDATE
------------------------

Address: 0x38

Description: 

.. table::
  :widths: 25 10 10 10 50

  ======================== ======== ======== ========== ======================================================================
  Name                     Index    Type     Reset      Description                                                           
  ======================== ======== ======== ========== ======================================================================
  SW_ATTR_EFFECTIVE_UPDATE [0]      WFIFO    0x0        Write a 1 to set the shadow attribute values to the effective values. 
  ======================== ======== ======== ========== ======================================================================


STATE_STATUS
------------

Address: 0x3c

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============ ======== ======== ========== ============
  Name         Index    Type     Reset      Description 
  ============ ======== ======== ========== ============
  LTSSM_STATE  [4:0]    RO       0x0        LTSSM State 
  RESERVED0    [7:5]    RO       0x0                    
  LL_TX_STATE  [11:8]   RO       0x0        LL TX State 
  LL_RX_STATE  [15:12]  RO       0x0        LL RX State 
  DESKEW_STATE [17:16]  RO       0x0        Deskew State
  ============ ======== ======== ========== ============


DEBUG_BUS_CTRL
--------------

Address: 0x40

Description: Debug observation bus selection for signals that have a mux override

.. table::
  :widths: 25 10 10 10 50

  ================== ======== ======== ========== ================================
  Name               Index    Type     Reset      Description                     
  ================== ======== ======== ========== ================================
  DEBUG_BUS_CTRL_SEL [2:0]    RW       0x0        Select signal for DEBUG_BUS_CTRL
  ================== ======== ======== ========== ================================


DEBUG_BUS_STATUS
----------------

Address: 0x44

Description: Debug observation bus for signals that have a mux override

.. table::
  :widths: 25 10 10 10 50

  ===================== ======== ======== ========== ==================================
  Name                  Index    Type     Reset      Description                       
  ===================== ======== ======== ========== ==================================
  DEBUG_BUS_CTRL_STATUS [31:0]   RO       0x0        Status output for DEBUG_BUS_STATUS
  ===================== ======== ======== ========== ==================================




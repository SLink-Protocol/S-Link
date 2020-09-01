SLINK_BIST Registers
====================
SWRESET
-------

Address: 0x0

Description: 

.. table::
  :widths: 25 10 10 10 50

  ======= ======== ======== ========== ==================================
  Name    Index    Type     Reset      Description                       
  ======= ======== ======== ========== ==================================
  SWRESET [0]      RW       0x1        Main software reset for BIST logic
  ======= ======== ======== ========== ==================================


BIST_MAIN_CONTROL
-----------------

Address: 0x4

Description: 

.. table::
  :widths: 25 10 10 10 50

  =============== ======== ======== ========== =====================================================================================
  Name            Index    Type     Reset      Description                                                                          
  =============== ======== ======== ========== =====================================================================================
  BIST_TX_EN      [0]      RW       0x0        Main Enable for TX. Controls clock gate for BIST logic                               
  BIST_RX_EN      [1]      RW       0x0        Main Enable for RX. Controls clock gate for BIST logic                               
  BIST_RESET      [2]      RW       0x0        Reset for clearing BIST error counters                                               
  BIST_ACTIVE     [3]      RW       0x0        Signal exits the BIST block and can be used to control an external mux for data path.
  DISABLE_CLKGATE [4]      RW       0x0                                                                                             
  =============== ======== ======== ========== =====================================================================================


BIST_MODE
---------

Address: 0x8

Description: 

.. table::
  :widths: 25 10 10 10 50

  ================= ======== ======== ========== ================================================================================================
  Name              Index    Type     Reset      Description                                                                                     
  ================= ======== ======== ========== ================================================================================================
  BIST_MODE_PAYLOAD [3:0]    RW       0x0        Denotes long data payload type. 0 - 1010, 1 - 1100, 2 - 1111_0000, 8 - counter, 9 - PRBS9       
  BIST_MODE_WC      [4]      RW       0x0        0 - Always use fixed word count (wc_min). 1 - Cycle through word counts (min -> max back to min)
  BIST_MODE_DI      [5]      RW       0x0        0 - Always use fixed data id (di_min). 1 - Cycle through data id (min -> max back to min)       
  ================= ======== ======== ========== ================================================================================================


BIST_WORD_COUNT_VALUES
----------------------

Address: 0xc

Description: 

.. table::
  :widths: 25 10 10 10 50

  =========== ======== ======== ========== ==================================
  Name        Index    Type     Reset      Description                       
  =========== ======== ======== ========== ==================================
  BIST_WC_MIN [15:0]   RW       0xa        Minimum number of bytes in payload
  BIST_WC_MAX [31:16]  RW       0x64       Maximum number of bytes in payload
  =========== ======== ======== ========== ==================================


BIST_DATA_ID_VALUES
-------------------

Address: 0x10

Description: 

.. table::
  :widths: 25 10 10 10 50

  =========== ======== ======== ========== =====================
  Name        Index    Type     Reset      Description          
  =========== ======== ======== ========== =====================
  BIST_DI_MIN [7:0]    RW       0x20       Minimum Data ID Value
  BIST_DI_MAX [15:8]   RW       0xf0       Maximum Data ID Value
  =========== ======== ======== ========== =====================


BIST_STATUS
-----------

Address: 0x14

Description: 

.. table::
  :widths: 25 10 10 10 50

  ============== ======== ======== ========== ==========================================================================================================
  Name           Index    Type     Reset      Description                                                                                               
  ============== ======== ======== ========== ==========================================================================================================
  BIST_LOCKED    [0]      RO       0x0        1 - BIST RX has seen at least one start of packet and word count has not had an issue                     
  BIST_UNRECOVER [1]      RO       0x0        1 - BIST RX has received data in such a way that the remaining data stream is not likely to be observable.
  RESERVED0      [15:2]   RO       0x0                                                                                                                  
  BIST_ERRORS    [31:16]  RO       0x0        Number of errors seen during this run. Saturates at all ones.                                             
  ============== ======== ======== ========== ==========================================================================================================


DEBUG_BUS_CTRL
--------------

Address: 0x18

Description: Debug observation bus selection for signals that have a mux override

.. table::
  :widths: 25 10 10 10 50

  ================== ======== ======== ========== ================================
  Name               Index    Type     Reset      Description                     
  ================== ======== ======== ========== ================================
  DEBUG_BUS_CTRL_SEL [0]      RW       0x0        Select signal for DEBUG_BUS_CTRL
  ================== ======== ======== ========== ================================


DEBUG_BUS_STATUS
----------------

Address: 0x1c

Description: Debug observation bus for signals that have a mux override

.. table::
  :widths: 25 10 10 10 50

  ===================== ======== ======== ========== ==================================
  Name                  Index    Type     Reset      Description                       
  ===================== ======== ======== ========== ==================================
  DEBUG_BUS_CTRL_STATUS [31:0]   RO       0x0        Status output for DEBUG_BUS_STATUS
  ===================== ======== ======== ========== ==================================




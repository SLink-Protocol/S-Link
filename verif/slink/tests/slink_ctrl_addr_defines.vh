//===================================================================
//
// Created by sbridges on February/02/2021 at 13:47:34
//
// slink_ctrl_addr_defines.vh
//
//===================================================================



`define SLINK_CTRL_SWRESET                                                     'h00000000
`define SLINK_CTRL_SWRESET__SWRESET_MUX                                                 1
`define SLINK_CTRL_SWRESET__SWRESET                                                     0
`define SLINK_CTRL_SWRESET___POR                                             32'h00000001

`define SLINK_CTRL_ENABLE                                                      'h00000004
`define SLINK_CTRL_ENABLE__ENABLE_MUX                                                   1
`define SLINK_CTRL_ENABLE__ENABLE                                                       0
`define SLINK_CTRL_ENABLE___POR                                              32'h00000000

`define SLINK_CTRL_INTERRUPT_STATUS                                            'h00000008
`define SLINK_CTRL_INTERRUPT_STATUS__IN_PSTATE                                          5
`define SLINK_CTRL_INTERRUPT_STATUS__WAKE_SEEN                                          4
`define SLINK_CTRL_INTERRUPT_STATUS__RESET_SEEN                                         3
`define SLINK_CTRL_INTERRUPT_STATUS__CRC_CORRUPTED                                      2
`define SLINK_CTRL_INTERRUPT_STATUS__ECC_CORRECTED                                      1
`define SLINK_CTRL_INTERRUPT_STATUS__ECC_CORRUPTED                                      0
`define SLINK_CTRL_INTERRUPT_STATUS___POR                                    32'h00000000

`define SLINK_CTRL_INTERRUPT_ENABLE                                            'h0000000C
`define SLINK_CTRL_INTERRUPT_ENABLE__IN_PSTATE_INT_EN                                   5
`define SLINK_CTRL_INTERRUPT_ENABLE__WAKE_SEEN_INT_EN                                   4
`define SLINK_CTRL_INTERRUPT_ENABLE__RESET_SEEN_INT_EN                                  3
`define SLINK_CTRL_INTERRUPT_ENABLE__CRC_CORRUPTED_INT_EN                               2
`define SLINK_CTRL_INTERRUPT_ENABLE__ECC_CORRECTED_INT_EN                               1
`define SLINK_CTRL_INTERRUPT_ENABLE__ECC_CORRUPTED_INT_EN                               0
`define SLINK_CTRL_INTERRUPT_ENABLE___POR                                    32'h0000000F

`define SLINK_CTRL_PSTATE_CONTROL                                              'h00000010
`define SLINK_CTRL_PSTATE_CONTROL__LINK_WAKE                                           31
`define SLINK_CTRL_PSTATE_CONTROL__LINK_RESET                                          30
`define SLINK_CTRL_PSTATE_CONTROL__RESERVED0                                         29:3
`define SLINK_CTRL_PSTATE_CONTROL__P3_STATE_ENTER                                       2
`define SLINK_CTRL_PSTATE_CONTROL__P2_STATE_ENTER                                       1
`define SLINK_CTRL_PSTATE_CONTROL__P1_STATE_ENTER                                       0
`define SLINK_CTRL_PSTATE_CONTROL___POR                                      32'h00000000

`define SLINK_CTRL_ERROR_CONTROL                                               'h00000014
`define SLINK_CTRL_ERROR_CONTROL__CRC_CORRUPTED_CAUSES_RESET                            3
`define SLINK_CTRL_ERROR_CONTROL__ECC_CORRUPTED_CAUSES_RESET                            2
`define SLINK_CTRL_ERROR_CONTROL__ECC_CORRECTED_CAUSES_RESET                            1
`define SLINK_CTRL_ERROR_CONTROL__ALLOW_ECC_CORRECTED                                   0
`define SLINK_CTRL_ERROR_CONTROL___POR                                       32'h00000005

`define SLINK_CTRL_COUNT_VAL_1US                                               'h00000018
`define SLINK_CTRL_COUNT_VAL_1US__COUNT_VAL_1US                                       9:0
`define SLINK_CTRL_COUNT_VAL_1US___POR                                       32'h00000026

`define SLINK_CTRL_SHORT_PACKET_MAX                                            'h0000001C
`define SLINK_CTRL_SHORT_PACKET_MAX__SHORT_PACKET_MAX                                 7:0
`define SLINK_CTRL_SHORT_PACKET_MAX___POR                                    32'h0000002F

`define SLINK_CTRL_SW_ATTR_ADDR_DATA                                           'h00000020
`define SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_WDATA                                 31:16
`define SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_ADDR                                   15:0
`define SLINK_CTRL_SW_ATTR_ADDR_DATA___POR                                   32'h00000000

`define SLINK_CTRL_SW_ATTR_CONTROLS                                            'h00000024
`define SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_LOCAL                                      1
`define SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_WRITE                                      0
`define SLINK_CTRL_SW_ATTR_CONTROLS___POR                                    32'h00000003

`define SLINK_CTRL_SW_ATTR_DATA_READ                                           'h00000028
`define SLINK_CTRL_SW_ATTR_DATA_READ__SW_ATTR_RDATA                                  15:0
`define SLINK_CTRL_SW_ATTR_DATA_READ___POR                                   32'h00000000

`define SLINK_CTRL_SW_ATTR_FIFO_STATUS                                         'h0000002C
`define SLINK_CTRL_SW_ATTR_FIFO_STATUS__SW_ATTR_RECV_FIFO_EMPTY                         3
`define SLINK_CTRL_SW_ATTR_FIFO_STATUS__SW_ATTR_RECV_FIFO_FULL                          2
`define SLINK_CTRL_SW_ATTR_FIFO_STATUS__SW_ATTR_SEND_FIFO_EMPTY                         1
`define SLINK_CTRL_SW_ATTR_FIFO_STATUS__SW_ATTR_SEND_FIFO_FULL                          0
`define SLINK_CTRL_SW_ATTR_FIFO_STATUS___POR                                 32'h00000000

`define SLINK_CTRL_SW_ATTR_SHADOW_UPDATE                                       'h00000030
`define SLINK_CTRL_SW_ATTR_SHADOW_UPDATE__SW_ATTR_SHADOW_UPDATE                         0
`define SLINK_CTRL_SW_ATTR_SHADOW_UPDATE___POR                               32'h00000000

`define SLINK_CTRL_SW_ATTR_EFFECTIVE_UPDATE                                    'h00000034
`define SLINK_CTRL_SW_ATTR_EFFECTIVE_UPDATE__SW_ATTR_EFFECTIVE_UPDATE                    0
`define SLINK_CTRL_SW_ATTR_EFFECTIVE_UPDATE___POR                            32'h00000000

`define SLINK_CTRL_STATE_STATUS                                                'h00000038
`define SLINK_CTRL_STATE_STATUS__DESKEW_STATE                                       17:16
`define SLINK_CTRL_STATE_STATUS__LL_RX_STATE                                        15:12
`define SLINK_CTRL_STATE_STATUS__LL_TX_STATE                                         11:8
`define SLINK_CTRL_STATE_STATUS__RESERVED0                                            7:5
`define SLINK_CTRL_STATE_STATUS__LTSSM_STATE                                          4:0
`define SLINK_CTRL_STATE_STATUS___POR                                        32'h00000000

`define SLINK_CTRL_DEBUG_BUS_CTRL                                              'h0000003C
`define SLINK_CTRL_DEBUG_BUS_CTRL__DEBUG_BUS_CTRL_SEL                                 2:0
`define SLINK_CTRL_DEBUG_BUS_CTRL___POR                                      32'h00000000

`define SLINK_CTRL_DEBUG_BUS_STATUS                                            'h00000040
`define SLINK_CTRL_DEBUG_BUS_STATUS__DEBUG_BUS_CTRL_STATUS                           31:0
`define SLINK_CTRL_DEBUG_BUS_STATUS___POR                                    32'h00000000


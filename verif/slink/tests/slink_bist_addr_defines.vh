//===================================================================
//
// Created by steven on August/18/2020 at 11:35:52
//
// slink_bist_addr_defines.vh
//
//===================================================================



`define SLINK_BIST_SWRESET                                                     'h00000000
`define SLINK_BIST_SWRESET__SWRESET                                                     0
`define SLINK_BIST_SWRESET___POR                                             32'h00000001

`define SLINK_BIST_BIST_MAIN_CONTROL                                           'h00000004
`define SLINK_BIST_BIST_MAIN_CONTROL__DISABLE_CLKGATE                                   4
`define SLINK_BIST_BIST_MAIN_CONTROL__BIST_ACTIVE                                       3
`define SLINK_BIST_BIST_MAIN_CONTROL__BIST_RESET                                        2
`define SLINK_BIST_BIST_MAIN_CONTROL__BIST_RX_EN                                        1
`define SLINK_BIST_BIST_MAIN_CONTROL__BIST_TX_EN                                        0
`define SLINK_BIST_BIST_MAIN_CONTROL___POR                                   32'h00000000

`define SLINK_BIST_BIST_MODE                                                   'h00000008
`define SLINK_BIST_BIST_MODE__BIST_MODE_DI                                              5
`define SLINK_BIST_BIST_MODE__BIST_MODE_WC                                              4
`define SLINK_BIST_BIST_MODE__BIST_MODE_PAYLOAD                                       3:0
`define SLINK_BIST_BIST_MODE___POR                                           32'h00000000

`define SLINK_BIST_BIST_WORD_COUNT_VALUES                                      'h0000000C
`define SLINK_BIST_BIST_WORD_COUNT_VALUES__BIST_WC_MAX                              31:16
`define SLINK_BIST_BIST_WORD_COUNT_VALUES__BIST_WC_MIN                               15:0
`define SLINK_BIST_BIST_WORD_COUNT_VALUES___POR                              32'h0064000A

`define SLINK_BIST_BIST_DATA_ID_VALUES                                         'h00000010
`define SLINK_BIST_BIST_DATA_ID_VALUES__BIST_DI_MAX                                  15:8
`define SLINK_BIST_BIST_DATA_ID_VALUES__BIST_DI_MIN                                   7:0
`define SLINK_BIST_BIST_DATA_ID_VALUES___POR                                 32'h0000F020

`define SLINK_BIST_BIST_STATUS                                                 'h00000014
`define SLINK_BIST_BIST_STATUS__BIST_ERRORS                                         31:16
`define SLINK_BIST_BIST_STATUS__RESERVED0                                            15:2
`define SLINK_BIST_BIST_STATUS__BIST_UNRECOVER                                          1
`define SLINK_BIST_BIST_STATUS__BIST_LOCKED                                             0
`define SLINK_BIST_BIST_STATUS___POR                                         32'h00000000

`define SLINK_BIST_DEBUG_BUS_CTRL                                              'h00000018
`define SLINK_BIST_DEBUG_BUS_CTRL__DEBUG_BUS_CTRL_SEL                                   0
`define SLINK_BIST_DEBUG_BUS_CTRL___POR                                      32'h00000000

`define SLINK_BIST_DEBUG_BUS_STATUS                                            'h0000001C
`define SLINK_BIST_DEBUG_BUS_STATUS__DEBUG_BUS_CTRL_STATUS                           31:0
`define SLINK_BIST_DEBUG_BUS_STATUS___POR                                    32'h00000000


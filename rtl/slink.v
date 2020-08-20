module slink #(
  parameter     NUM_TX_LANES              = 4,
  parameter     NUM_RX_LANES              = 4,
  parameter     PHY_DATA_WIDTH            = 8,
  parameter     TX_APP_DATA_WIDTH         = (NUM_TX_LANES * PHY_DATA_WIDTH),
  parameter     RX_APP_DATA_WIDTH         = (NUM_RX_LANES * PHY_DATA_WIDTH),
  parameter     DESKEW_FIFO_DEPTH         = 4,
  parameter     LTSSM_REGISTER_TXDATA     = 1,
  parameter     INCLUDE_BIST              = 1
)(
  input  wire                                     core_scan_mode,
  input  wire                                     core_scan_clk,
  input  wire                                     core_scan_asyncrst_ctrl,
    
  // Control/Status Registers
  input  wire                                     apb_clk,
  input  wire                                     apb_reset,
  input  wire [8:0]                               apb_paddr,
  input  wire                                     apb_pwrite,
  input  wire                                     apb_psel,
  input  wire                                     apb_penable,
  input  wire [31:0]                              apb_pwdata,
  output wire [31:0]                              apb_prdata,
  output wire                                     apb_pready,
  output wire                                     apb_pslverr,
  
  output wire                                     link_clk,
  output wire                                     link_reset,
  
  // Attributes
  input  wire [15:0]                              app_attr_addr,
  input  wire [15:0]                              app_attr_data,
  input  wire                                     app_shadow_update,
  output wire [15:0]                              app_attr_data_read,
  
  
  // TX Application/Transaction Layer
  input  wire                                     tx_sop,
  input  wire [7:0]                               tx_data_id,
  input  wire [15:0]                              tx_word_count,
  input  wire [TX_APP_DATA_WIDTH-1:0]             tx_app_data,
  output wire                                     tx_advance,
  
  // RX Application/Transaction Layer
  output wire                                     rx_sop,
  output wire [7:0]                               rx_data_id,
  output wire [15:0]                              rx_word_count,
  output wire [RX_APP_DATA_WIDTH-1:0]             rx_app_data,
  output wire                                     rx_valid,
  output wire                                     rx_crc_corrupted,
  
  output wire                                     interrupt,
  
  // P State Control
  input  wire                                     p1_req,
  input  wire                                     p2_req,
  input  wire                                     p3_req,
  output wire                                     in_px_state,
  output wire                                     in_reset_state,
  
  // Sideband Signals
  output wire                                     slink_gpio_reset_n_oen,
  input  wire                                     slink_gpio_reset_n,
  output wire                                     slink_gpio_wake_n_oen,
  input  wire                                     slink_gpio_wake_n,
  
  // PHY
  input  wire                                     refclk,
  input  wire                                     phy_clk,
  
  output wire                                     phy_clk_en,
  output wire                                     phy_clk_idle,
  input  wire                                     phy_clk_ready,
  
  output wire [NUM_TX_LANES-1:0]                  phy_tx_en,
  input  wire [NUM_TX_LANES-1:0]                  phy_tx_ready,
  input  wire [NUM_TX_LANES-1:0]                  phy_tx_dirdy,
  output wire [(NUM_TX_LANES*PHY_DATA_WIDTH)-1:0] phy_tx_data,
  
  output wire [NUM_RX_LANES-1:0]                  phy_rx_en,
  input  wire [NUM_RX_LANES-1:0]                  phy_rx_ready,
  input  wire [NUM_RX_LANES-1:0]                  phy_rx_valid,   
  input  wire [NUM_RX_LANES-1:0]                  phy_rx_dordy,  
  output wire [NUM_RX_LANES-1:0]                  phy_rx_align,     
  input  wire [(NUM_RX_LANES*PHY_DATA_WIDTH)-1:0] phy_rx_data
  
             
);

wire                                    apb_clk_scan;
wire                                    apb_reset_scan;
wire                                    use_phy_clk;
wire                                    refclk_scan;
wire                                    refclk_scan_reset;

wire [NUM_RX_LANES-1:0]                 rx_ts1_seen;
wire [NUM_RX_LANES-1:0]                 rx_ts2_seen;
wire [NUM_RX_LANES-1:0]                 rx_sds_seen;
wire [(NUM_RX_LANES*PHY_DATA_WIDTH)-1:0]rx_deskew_data;
wire                                    deskew_enable;
wire                                    sds_sent;
wire [(NUM_TX_LANES*PHY_DATA_WIDTH)-1:0]tx_link_data;


wire          swi_swreset;
wire          swi_enable;

wire          swi_ecc_corrupted_int_en;
wire          w1c_in_ecc_corrupted;
wire          w1c_out_ecc_corrupted;
wire          swi_ecc_corrected_int_en;
wire          w1c_in_ecc_corrected;
wire          w1c_out_ecc_corrected;
wire          swi_crc_corrupted_int_en;
wire          w1c_in_crc_corrupted;
wire          w1c_out_crc_corrupted;
wire          w1c_in_aux_rx_fifo_write_full ;
wire          w1c_out_aux_rx_fifo_write_full;
wire          swi_aux_rx_fifo_write_full_int_en;

wire          w1c_out_reset_seen;
wire          w1c_out_wake_seen;
wire          w1c_out_in_pstate;
wire          swi_reset_seen_int_en;
wire          swi_wake_seen_int_en;
wire          swi_in_pstate_int_en;


wire          swi_p1_state_enter;
wire          swi_p2_state_enter;
wire          swi_p3_state_enter;

wire [7:0]    swi_aux_link_short_pkt_min_filter;
wire [7:0]    swi_aux_link_short_pkt_max_filter;
wire          aux_link_fifos_active;
wire [23:0]   wfifo_aux_link_tx_short_packet;
wire          wfifo_winc_aux_link_tx_short_packet;
wire          aux_link_tx_wfull;
wire          aux_link_tx_rempty;
wire [23:0]   rfifo_aux_link_rx_short_packet;
wire          rfifo_rinc_aux_link_rx_short_packet;
wire          aux_link_rx_wfull;
wire          aux_link_rx_rempty;


wire          link_attr_shadow_update;
wire [15:0]   link_attr_addr;
wire [15:0]   link_attr_data;
wire [15:0]   link_attr_data_read;
wire          link_attr_read_req;

wire  [15:0]  swi_sw_attr_addr;
wire  [15:0]  swi_sw_attr_data;
wire  [15:0]  sw_attr_data_read;
wire          wfifo_sw_attr_shadow_update;
wire          wfifo_winc_sw_attr_shadow_update;
wire          wfifo_sw_attr_effective_update;
wire          wfifo_winc_sw_attr_effective_update;


wire [2:0]    attr_active_txs;
wire [2:0]    attr_active_rxs;
wire [9:0]    attr_hard_reset_us;
wire [7:0]    attr_px_clk_trail;
wire [15:0]   attr_p1_ts1_tx;
wire [15:0]   attr_p1_ts1_rx;
wire [15:0]   attr_p1_ts2_tx;
wire [15:0]   attr_p1_ts2_rx;
wire [15:0]   attr_p2_ts1_tx;
wire [15:0]   attr_p2_ts1_rx;
wire [15:0]   attr_p2_ts2_tx;
wire [15:0]   attr_p2_ts2_rx;
wire [15:0]   attr_p3r_ts1_tx;
wire [15:0]   attr_p3r_ts1_rx;
wire [15:0]   attr_p3r_ts2_tx;
wire [15:0]   attr_p3r_ts2_rx;


wire          rx_px_req_pkt;
wire [2:0]    rx_px_req_state;
wire          rx_px_rej_pkt;
wire          rx_px_start_pkt;
wire          link_enter_px_state;
wire          link_p1_req;
wire          link_p2_req;
wire          link_p3_req;
wire          effect_update;

wire          link_active_req;
wire          ltssm_link_wake_n;
wire          link_reset_req;
wire          link_reset_req_local;
wire          ltssm_link_reset_n;
wire          swi_link_wake;
wire          swi_link_reset;
wire          ll_rx_link_reset_condition;
wire          link_hard_reset_cond;

wire  [4:0]   ltssm_state ;
wire  [3:0]   ll_tx_state ;
wire  [3:0]   ll_rx_state ;
wire  [1:0]   deskew_state ;
wire          swi_allow_ecc_corrected;
wire          swi_ecc_corrected_causes_reset;
wire          swi_ecc_corrupted_causes_reset;
wire          swi_crc_corrupted_causes_reset;
wire  [9:0]   swi_count_val_1us;


wire                          ll_tx_sop;
wire [7:0]                    ll_tx_data_id;
wire [15:0]                   ll_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]  ll_tx_app_data;
wire                          ll_tx_advance;
wire                          ll_rx_sop;
wire [7:0]                    ll_rx_data_id;
wire [15:0]                   ll_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]  ll_rx_app_data;
wire                          ll_rx_valid;
wire                          ll_rx_crc_corrupted;


slink_clk_control u_slink_clk_control (
  .core_scan_mode              ( core_scan_mode               ),  
  .core_scan_clk               ( core_scan_clk                ),  
  .core_scan_asyncrst_ctrl     ( core_scan_asyncrst_ctrl      ),  
  .apb_clk                     ( apb_clk                      ),     
  .apb_reset                   ( apb_reset                    ),     
  .apb_clk_scan                ( apb_clk_scan                 ),     
  .apb_reset_scan              ( apb_reset_scan               ),     
  .refclk                      ( refclk                       ),        
  .phy_clk                     ( phy_clk                      ),        
  .main_reset                  ( swi_swreset                  ),  
  .use_phy_clk                 ( use_phy_clk                  ),       
  .refclk_scan                 ( refclk_scan                  ),  
  .refclk_scan_reset           ( refclk_scan_reset            ),
  .link_clk                    ( link_clk                     ),         
  .link_clk_reset              ( link_clk_reset               )); 

assign link_reset = link_clk_reset;


//-------------------------------------------
// TX Path
//-------------------------------------------

wire swi_p1_state_enter_link_clk;
wire swi_p2_state_enter_link_clk;
wire swi_p3_state_enter_link_clk;
slink_demet_reset u_slink_demet_reset_px_state_enter[2:0] (
  .clk     ( link_clk                       ),        
  .reset   ( link_clk_reset                 ),        
  .sig_in  ( {swi_p3_state_enter,
              swi_p2_state_enter,
              swi_p1_state_enter}           ),        
  .sig_out ( {swi_p3_state_enter_link_clk,
              swi_p2_state_enter_link_clk,
              swi_p1_state_enter_link_clk}  )); 


assign link_p1_req = p1_req || rx_px_req_state[0] || swi_p1_state_enter_link_clk;
assign link_p2_req = p2_req || rx_px_req_state[1] || swi_p2_state_enter_link_clk;
assign link_p3_req = p3_req || rx_px_req_state[2] || swi_p3_state_enter_link_clk;

//wire [1:0] tempsig = ((32/PHY_DATA_WIDTH) - 'd1);
wire [1:0] tempsig = PHY_DATA_WIDTH == 8  ? 2'b11 :
                     PHY_DATA_WIDTH == 16 ? 2'b01 : 2'b00;

slink_ll_tx #(
  //parameters
  .DATA_WIDTH         ( PHY_DATA_WIDTH    ),
  .NUM_LANES          ( NUM_TX_LANES      ),
  .APP_DATA_WIDTH     ( TX_APP_DATA_WIDTH )
) u_slink_ll_tx (
  .clk                      ( link_clk                            ),  
  .reset                    ( link_clk_reset                      ),  
  .apb_clk                  ( apb_clk_scan                        ),
  .apb_reset                ( apb_reset_scan                      ),
  
  .sop                      ( ll_tx_sop                           ),  
  .data_id                  ( ll_tx_data_id                       ),  
  .word_count               ( ll_tx_word_count                    ),  
  .app_data                 ( ll_tx_app_data                      ),  
  .valid                    ( 1'b0                                ),  
  .advance                  ( ll_tx_advance                       ),  
  
  .delimeter                ( tempsig/*temp*/   ),
  
  .p1_req                   ( link_p1_req                         ),   
  .p2_req                   ( link_p2_req                         ),   
  .p3_req                   ( link_p3_req                         ),   
  
  .rx_px_req                ( rx_px_req_pkt                       ),
  .rx_px_rej                ( rx_px_rej_pkt                       ),
  .enter_px_state           ( link_enter_px_state                 ),
  .link_reset_condition     ( link_reset_req                      ),
  
  .apb_aux_winc             ( wfifo_winc_aux_link_tx_short_packet ),
  .apb_aux_data             ( wfifo_aux_link_tx_short_packet      ),
  .apb_aux_wfull            ( aux_link_tx_wfull                   ),
  .aux_link_rempty          ( aux_link_tx_rempty                  ),
  .aux_fifo_write_full_err  ( /*connect me*/                      ),
  
  .attr_data                ( link_attr_data_read                 ),
  .attr_read_req            ( link_attr_read_req                  ),
  
  .active_lanes             ( attr_active_txs                     ),  
  .sds_sent                 ( sds_sent                            ), 
  .link_data                ( tx_link_data                        ),
  .ll_tx_state              ( ll_tx_state                         )); 


//-------------------------------------------
// Rx Path
//-------------------------------------------
wire ecc_corrected_link_clk;
wire ecc_corrupted_link_clk;
wire aux_fifo_write_full_err_link_clk;

slink_ll_rx #(
  //parameters
  .APP_DATA_WIDTH     ( RX_APP_DATA_WIDTH ),
  .NUM_LANES          ( NUM_RX_LANES      ),
  .DATA_WIDTH         ( PHY_DATA_WIDTH    )
) u_slink_ll_rx (
  .clk                                ( link_clk                            ),  
  .reset                              ( link_clk_reset                      ),  
  .apb_clk                            ( apb_clk_scan                        ),
  .apb_reset                          ( apb_reset_scan                      ),
  .sop                                ( ll_rx_sop                           ),  
  .data_id                            ( ll_rx_data_id                       ),  
  .word_count                         ( ll_rx_word_count                    ),  
  .app_data                           ( ll_rx_app_data                      ),  
  .valid                              ( ll_rx_valid                         ),  
  .active_lanes                       ( attr_active_rxs                     ),  
  .delimeter                          ( tempsig/*temp*/   ),
  
  .swi_allow_ecc_corrected            ( swi_allow_ecc_corrected             ),
  .swi_ecc_corrected_causes_reset     ( swi_ecc_corrected_causes_reset      ),
  .swi_ecc_corrupted_causes_reset     ( swi_ecc_corrupted_causes_reset      ),
  .swi_crc_corrupted_causes_reset     ( swi_crc_corrupted_causes_reset      ),
  .sds_received                       ( rx_sds_seen[0]                      ),  
  .link_enter_px_state                ( link_enter_px_state                 ),
  
  .ecc_corrected                      ( ecc_corrected_link_clk              ),  
  .ecc_corrupted                      ( ecc_corrupted_link_clk              ),  
  .crc_corrupted                      ( ll_rx_crc_corrupted                 ),
  .aux_fifo_write_full_err            ( aux_fifo_write_full_err_link_clk    ),
  
  .external_link_reset_condition      ( link_reset_req                      ),
  .link_reset_condition               ( ll_rx_link_reset_condition          ),
  .apb_aux_rinc                       ( rfifo_rinc_aux_link_rx_short_packet ),
  .apb_aux_data                       ( rfifo_aux_link_rx_short_packet      ),
  .apb_aux_rempty                     ( aux_link_rx_rempty                  ),
  .aux_link_wfull                     ( aux_link_rx_wfull                   ),
  .swi_aux_link_short_pkt_min_filter  ( swi_aux_link_short_pkt_min_filter   ),
  .swi_aux_link_short_pkt_max_filter  ( swi_aux_link_short_pkt_max_filter   ),
  
  .attr_addr                          ( link_attr_addr                      ),    
  .attr_data                          ( link_attr_data                      ),    
  .attr_shadow_update                 ( link_attr_shadow_update             ),
  .attr_read_req                      ( link_attr_read_req                  ),

  .px_req_pkt                         ( rx_px_req_pkt                       ),  
  .px_req_state                       ( rx_px_req_state                     ),  
  .px_rej_pkt                         ( rx_px_rej_pkt                       ),  
  .px_start_pkt                       ( rx_px_start_pkt                     ),
    
  .link_data                          ( rx_deskew_data                      ),
  .ll_rx_state                        ( ll_rx_state                         )); 


slink_rx_deskew #(
  //parameters
  .DATA_WIDTH         ( PHY_DATA_WIDTH      ),
  .FIFO_DEPTH         ( DESKEW_FIFO_DEPTH   ),
  .NUM_LANES          ( NUM_RX_LANES        )
) u_slink_rx_deskew (
  .clk                 ( link_clk             ),  
  .reset               ( link_clk_reset       ),  
  .enable              ( deskew_enable        ),  
  .rx_data_in          ( phy_rx_data          ), 
  .active_lanes        ( attr_active_rxs      ),   
  .fifo_ptr_status     ( /*connect me*/       ),  //output - [(NUM_LANES*FIFO_CLOG2)-1:0]              
  .rx_ts1_seen         ( rx_ts1_seen          ),  
  .rx_ts2_seen         ( rx_ts2_seen          ),  
  .rx_sds_seen         ( rx_sds_seen          ),  
  .rx_data_out         ( rx_deskew_data       ),  //output - [(NUM_LANES*DATA_WIDTH)-1:0]              
  .rx_data_valid_out   ( /*connect me???*/    ),
  .deskew_state        ( deskew_state         )); 


//-------------------------------------------
// LTSSM
//-------------------------------------------

wire swi_link_wake_link_clk;
wire slink_gpio_wake_link_clk;
wire swi_link_reset_link_clk;
wire slink_gpio_reset_link_clk;
slink_demet_reset u_slink_demet_reset_wake_reset_signals[3:0] (
  .clk     ( link_clk               ), 
  .reset   ( link_clk_reset         ), 
  .sig_in  ( {swi_link_wake,
              ~slink_gpio_wake_n,
              swi_link_reset,
              ~slink_gpio_reset_n}  ), 
  .sig_out ( {swi_link_wake_link_clk,
              slink_gpio_wake_link_clk,
              swi_link_reset_link_clk,
              slink_gpio_reset_link_clk}  ));

assign link_active_req      = tx_sop || slink_gpio_wake_link_clk || swi_link_wake_link_clk;

assign link_reset_req_local = ll_rx_link_reset_condition || swi_link_reset_link_clk;
assign link_reset_req       = link_reset_req_local || slink_gpio_reset_link_clk;



slink_ltssm #(
  //parameters
  .REGISTER_TXDATA    ( LTSSM_REGISTER_TXDATA ),
  .NUM_TX_LANES       ( NUM_TX_LANES          ),
  .NUM_RX_LANES       ( NUM_RX_LANES          ),
  .DATA_WIDTH         ( PHY_DATA_WIDTH        )
) u_slink_ltssm (
  .clk                     ( link_clk                     ),             
  .reset                   ( link_clk_reset               ),    
  .refclk                  ( refclk_scan                  ),
  .refclk_reset            ( refclk_scan_reset            ),
  .enable                  ( swi_enable                   ),         
  .p1_ts1_tx_count         ( attr_p1_ts1_tx               ),  
  .p1_ts1_rx_count         ( attr_p1_ts1_rx               ),  
  .p1_ts2_tx_count         ( attr_p1_ts2_tx               ),  
  .p1_ts2_rx_count         ( attr_p1_ts2_rx               ),  
  .p2_ts1_tx_count         ( attr_p2_ts1_tx               ),  
  .p2_ts1_rx_count         ( attr_p2_ts1_rx               ),  
  .p2_ts2_tx_count         ( attr_p2_ts2_tx               ),  
  .p2_ts2_rx_count         ( attr_p2_ts2_rx               ),  
  .p3r_ts1_tx_count        ( attr_p3r_ts1_tx              ),  
  .p3r_ts1_rx_count        ( attr_p3r_ts1_rx              ),  
  .p3r_ts2_tx_count        ( attr_p3r_ts2_tx              ),  
  .p3r_ts2_rx_count        ( attr_p3r_ts2_rx              ),  
  .px_clk_trail            ( {8'd0, attr_px_clk_trail}    ),
  .swi_clk_switch_time     ( 16'd8                        ),  
  .swi_p0_exit_time        ( 16'd16                        ),
  .active_rx_lanes         ( attr_active_rxs              ),      
  .active_tx_lanes         ( attr_active_txs              ),      
  .use_phy_clk             ( use_phy_clk                  ),  
  .rx_ts1_seen             ( rx_ts1_seen                  ),  
  .rx_ts2_seen             ( rx_ts2_seen                  ),  
  .rx_sds_seen             ( rx_sds_seen                  ),  
  .sds_sent                ( sds_sent                     ),
  .deskew_enable           ( deskew_enable                ),
  
  .enter_px_state          ( link_enter_px_state          ),
  .link_p1_req             ( link_p1_req                  ),   
  .link_p2_req             ( link_p2_req                  ),   
  .link_p3_req             ( link_p3_req                  ),
  .in_px_state             ( in_px_state                  ), 
  .effect_update           ( effect_update                ),
  
  .link_active_req         ( link_active_req              ),
  .link_wake_n             ( ltssm_link_wake_n            ),
  .link_reset_req          ( link_reset_req               ),
  .link_reset_req_local    ( link_reset_req_local         ),
  .link_reset_n            ( ltssm_link_reset_n           ),
  .swi_count_val_1us       ( swi_count_val_1us            ),
  .attr_hard_reset_us      ( attr_hard_reset_us           ),
  .link_hard_reset_cond    ( link_hard_reset_cond         ),
  .in_reset_state          ( in_reset_state               ),
  
  .phy_clk_en              ( phy_clk_en                   ),  
  .phy_clk_idle            ( phy_clk_idle                 ),
  .phy_clk_ready           ( phy_clk_ready                ),  
  .phy_tx_en               ( phy_tx_en                    ),  
  .phy_tx_ready            ( phy_tx_ready                 ),  
  .phy_tx_dirdy            ( phy_tx_dirdy                 ),
  .phy_rx_en               ( phy_rx_en                    ),  
  .phy_rx_ready            ( phy_rx_ready                 ),  
  .phy_rx_valid            ( phy_rx_valid                 ),  
  .phy_rx_dordy            ( phy_rx_dordy                 ),
  .phy_rx_align            ( phy_rx_align                 ),  
  .link_data               ( tx_link_data                 ),  
  .ltssm_data              ( phy_tx_data                  ),
  .ltssm_state             ( ltssm_state                  )); 


assign slink_gpio_wake_n_oen = ~ltssm_link_wake_n;
assign slink_gpio_reset_n_oen= ~ltssm_link_reset_n;

//-------------------------------------------
// Attributes
//-------------------------------------------
wire sw_shadow_update;
wire sw_shadow_update_link_clk;
wire sw_effective_update;
wire sw_effective_update_link_clk;

assign sw_shadow_update       = wfifo_sw_attr_shadow_update    && wfifo_winc_sw_attr_shadow_update;
assign sw_effective_update    = wfifo_sw_attr_effective_update && wfifo_winc_sw_attr_effective_update;

slink_sync_pulse u_slink_sync_pulse_attr_sw_override[1:0] (
  .clk_in          ( apb_clk_scan                   ),              
  .clk_in_reset    ( apb_reset_scan                 ),              
  .data_in         ( {sw_shadow_update,
                      sw_effective_update}          ),              
  .clk_out         ( link_clk                       ),              
  .clk_out_reset   ( link_clk_reset                 ),              
  .data_out        ( {sw_shadow_update_link_clk,
                      sw_effective_update_link_clk} )); 

slink_attributes #(
  .NUM_TX_LANES_CLOG2    ( $clog2(NUM_TX_LANES)         ),
  .NUM_RX_LANES_CLOG2    ( $clog2(NUM_RX_LANES)         )
) u_slink_attributes (            
  .attr_max_txs          (                              ),     
  .attr_max_rxs          (                              ),     
  .attr_active_txs       ( attr_active_txs              ),  
  .attr_active_rxs       ( attr_active_rxs              ),  
  .attr_hard_reset_us    ( attr_hard_reset_us           ),
  .attr_px_clk_trail     ( attr_px_clk_trail            ),
  
  .attr_p1_ts1_tx        ( attr_p1_ts1_tx               ),  
  .attr_p1_ts1_rx        ( attr_p1_ts1_rx               ),  
  .attr_p1_ts2_tx        ( attr_p1_ts2_tx               ),  
  .attr_p1_ts2_rx        ( attr_p1_ts2_rx               ),  
  .attr_p2_ts1_tx        ( attr_p2_ts1_tx               ),  
  .attr_p2_ts1_rx        ( attr_p2_ts1_rx               ),  
  .attr_p2_ts2_tx        ( attr_p2_ts2_tx               ),  
  .attr_p2_ts2_rx        ( attr_p2_ts2_rx               ),  
  .attr_p3r_ts1_tx       ( attr_p3r_ts1_tx              ),  
  .attr_p3r_ts1_rx       ( attr_p3r_ts1_rx              ),  
  .attr_p3r_ts2_tx       ( attr_p3r_ts2_tx              ),  
  .attr_p3r_ts2_rx       ( attr_p3r_ts2_rx              ),  

  .clk                   ( link_clk                     ),  
  .reset                 ( link_clk_reset               ),       
  .hard_reset_cond       ( link_hard_reset_cond         ),
  .link_attr_addr        ( link_attr_addr               ),  
  .link_attr_data        ( link_attr_data               ),  
  .link_shadow_update    ( link_attr_shadow_update      ),  
  .link_attr_data_read   ( link_attr_data_read          ),  
  .app_attr_addr         ( app_attr_addr                ),  
  .app_attr_data         ( app_attr_data                ),  
  .app_shadow_update     ( app_shadow_update            ),  
  .app_attr_data_read    ( app_attr_data_read           ),  
  .sw_attr_addr          ( swi_sw_attr_addr             ), 
  .sw_attr_data          ( swi_sw_attr_data             ), 
  .sw_shadow_update      ( sw_shadow_update_link_clk    ), 
  .sw_attr_data_read     ( sw_attr_data_read            ),  

   
  .effective_update      ( effect_update  ||
                           sw_effective_update_link_clk )); 



slink_sync_pulse u_slink_sync_pulse_software_w1c[3:0] (
  .clk_in          ( link_clk                           ),              
  .clk_in_reset    ( link_clk_reset                     ),              
  .data_in         ( {aux_fifo_write_full_err_link_clk,
                      rx_crc_corrupted,
                      ecc_corrupted_link_clk,
                      ecc_corrected_link_clk}           ),              
  .clk_out         ( apb_clk_scan                       ),              
  .clk_out_reset   ( apb_reset_scan                     ),              
  .data_out        ( {w1c_in_aux_rx_fifo_write_full,
                      w1c_in_crc_corrupted,
                      w1c_in_ecc_corrupted,
                      w1c_in_ecc_corrected}             )); 

assign interrupt = (w1c_out_ecc_corrupted           && swi_ecc_corrupted_int_en)          ||
                   (w1c_out_ecc_corrected           && swi_ecc_corrected_int_en)          ||
                   (w1c_out_crc_corrupted           && swi_crc_corrupted_int_en)          ||
                   (w1c_out_reset_seen              && swi_reset_seen_int_en)             ||
                   (w1c_out_wake_seen               && swi_wake_seen_int_en)              ||
                   (w1c_out_in_pstate               && swi_in_pstate_int_en)              ||
                   (w1c_out_aux_rx_fifo_write_full  && swi_aux_rx_fifo_write_full_int_en);



// ABP Decode
localparam  APB_CTRL = 1'b0,
            APB_BIST = 1'b1;

wire [7:0]  apb_paddr_ctrl;
wire        apb_pwrite_ctrl;
wire        apb_psel_ctrl;
wire        apb_penable_ctrl;
wire [31:0] apb_pwdata_ctrl;
wire [31:0] apb_prdata_ctrl;
wire        apb_pready_ctrl;
wire        apb_pslverr_ctrl;

wire [7:0]  apb_paddr_bist;
wire        apb_pwrite_bist;
wire        apb_psel_bist;
wire        apb_penable_bist;
wire [31:0] apb_pwdata_bist;
wire [31:0] apb_prdata_bist;
wire        apb_pready_bist;
wire        apb_pslverr_bist;

assign apb_paddr_ctrl   = apb_paddr[7:0];
assign apb_pwrite_ctrl  = (apb_paddr[8] == APB_CTRL) && apb_pwrite;
assign apb_psel_ctrl    = (apb_paddr[8] == APB_CTRL) && apb_psel;
assign apb_penable_ctrl = (apb_paddr[8] == APB_CTRL) && apb_penable;
assign apb_pwdata_ctrl  = apb_pwdata;

assign apb_paddr_bist   = apb_paddr[7:0];
assign apb_pwrite_bist  = (apb_paddr[8] == APB_BIST) && apb_pwrite;
assign apb_psel_bist    = (apb_paddr[8] == APB_BIST) && apb_psel;
assign apb_penable_bist = (apb_paddr[8] == APB_BIST) && apb_penable;
assign apb_pwdata_bist  = apb_pwdata;

assign apb_prdata       = (apb_paddr[8] == APB_CTRL) ? apb_prdata_ctrl  : apb_prdata_bist;
assign apb_prready      = (apb_paddr[8] == APB_CTRL) ? apb_pready_ctrl  : apb_pready_bist;
assign apb_pslverr      = (apb_paddr[8] == APB_CTRL) ? apb_pslverr_ctrl : apb_pslverr_bist;

slink_ctrl_regs_top u_slink_ctrl_regs_top (
  .swi_swreset                             ( swi_swreset                              ),             
  .swi_enable                              ( swi_enable                               ), 
  .w1c_in_ecc_corrupted                    ( w1c_in_ecc_corrupted                     ),  
  .w1c_out_ecc_corrupted                   ( w1c_out_ecc_corrupted                    ),  
  .w1c_in_ecc_corrected                    ( w1c_in_ecc_corrected                     ),  
  .w1c_out_ecc_corrected                   ( w1c_out_ecc_corrected                    ),  
  .w1c_in_crc_corrupted                    ( w1c_in_crc_corrupted                     ),  
  .w1c_out_crc_corrupted                   ( w1c_out_crc_corrupted                    ),  
  .w1c_in_aux_rx_fifo_write_full           ( w1c_in_aux_rx_fifo_write_full            ),  
  .w1c_out_aux_rx_fifo_write_full          ( w1c_out_aux_rx_fifo_write_full           ),  
  .w1c_in_reset_seen                       ( in_reset_state                           ),  
  .w1c_out_reset_seen                      ( w1c_out_reset_seen                       ),  
  .w1c_in_wake_seen                        ( link_reset_req                           ),  
  .w1c_out_wake_seen                       ( w1c_out_wake_seen                        ),  
  .w1c_in_in_pstate                        ( in_px_state                              ),  
  .w1c_out_in_pstate                       ( w1c_out_in_pstate                        ),  

  .swi_ecc_corrupted_int_en                ( swi_ecc_corrupted_int_en                 ),  
  .swi_ecc_corrected_int_en                ( swi_ecc_corrected_int_en                 ),  
  .swi_crc_corrupted_int_en                ( swi_crc_corrupted_int_en                 ),  
  .swi_aux_rx_fifo_write_full_int_en       ( swi_aux_rx_fifo_write_full_int_en        ),  
  .swi_reset_seen_int_en                   ( swi_reset_seen_int_en                    ),  
  .swi_wake_seen_int_en                    ( swi_wake_seen_int_en                     ),  
  .swi_in_pstate_int_en                    ( swi_in_pstate_int_en                     ),  

  
  .swi_p1_state_enter                      ( swi_p1_state_enter                       ),  
  .swi_p2_state_enter                      ( swi_p2_state_enter                       ),  
  .swi_p3_state_enter                      ( swi_p3_state_enter                       ), 
  .swi_link_reset                          ( swi_link_reset                           ), 
  .swi_link_wake                           ( swi_link_wake                            ),
  
  .swi_allow_ecc_corrected                 ( swi_allow_ecc_corrected                  ),  
  .swi_ecc_corrected_causes_reset          ( swi_ecc_corrected_causes_reset           ),  
  .swi_ecc_corrupted_causes_reset          ( swi_ecc_corrupted_causes_reset           ),  
  .swi_crc_corrupted_causes_reset          ( swi_crc_corrupted_causes_reset           ),  
  
  .swi_count_val_1us                       ( swi_count_val_1us                        ),   

  
  .swi_aux_link_short_pkt_min_filter       ( swi_aux_link_short_pkt_min_filter        ),  
  .swi_aux_link_short_pkt_max_filter       ( swi_aux_link_short_pkt_max_filter        ),  
  .aux_link_fifos_active                   ( 1'b1                                     ),    
  .wfifo_aux_link_tx_short_packet          ( wfifo_aux_link_tx_short_packet           ),         
  .wfifo_winc_aux_link_tx_short_packet     ( wfifo_winc_aux_link_tx_short_packet      ),    
  .aux_link_tx_wfull                       ( aux_link_tx_wfull                        ),    
  .aux_link_tx_rempty                      ( aux_link_tx_rempty                       ),    
  .rfifo_aux_link_rx_short_packet          ( rfifo_aux_link_rx_short_packet           ),          
  .rfifo_rinc_aux_link_rx_short_packet     ( rfifo_rinc_aux_link_rx_short_packet      ),       
  .aux_link_rx_wfull                       ( aux_link_rx_wfull                        ),       
  .aux_link_rx_rempty                      ( aux_link_rx_rempty                       ),  
  
  .swi_sw_attr_addr                        ( swi_sw_attr_addr                         ),  
  .swi_sw_attr_data                        ( swi_sw_attr_data                         ), 
  .sw_attr_data_read                       ( sw_attr_data_read                        ), 
  .wfifo_sw_attr_shadow_update             ( wfifo_sw_attr_shadow_update              ),  
  .wfifo_winc_sw_attr_shadow_update        ( wfifo_winc_sw_attr_shadow_update         ),  
  .wfifo_sw_attr_effective_update          ( wfifo_sw_attr_effective_update           ),  
  .wfifo_winc_sw_attr_effective_update     ( wfifo_winc_sw_attr_effective_update      ),  
  
  .ltssm_state                             ( ltssm_state                              ),  
  .ll_tx_state                             ( ll_tx_state                              ),  
  .ll_rx_state                             ( ll_rx_state                              ),  
  .deskew_state                            ( deskew_state                             ),  

           
  .debug_bus_ctrl_status                   (                                          ),      
  .RegReset                                ( apb_reset_scan                           ),      
  .RegClk                                  ( apb_clk_scan                             ),      
  .PSEL                                    ( apb_psel_ctrl                            ),      
  .PENABLE                                 ( apb_penable_ctrl                         ),      
  .PWRITE                                  ( apb_pwrite_ctrl                          ),      
  .PSLVERR                                 ( apb_pslverr_ctrl                         ),      
  .PREADY                                  ( apb_pready_ctrl                          ),      
  .PADDR                                   ( apb_paddr_ctrl                           ),      
  .PWDATA                                  ( apb_pwdata_ctrl                          ),      
  .PRDATA                                  ( apb_prdata_ctrl                          ));     



generate
  if(INCLUDE_BIST) begin : gen_include_bist
    wire                          bist_active;
    wire                          bist_tx_sop;
    wire [7:0]                    bist_tx_data_id;
    wire [15:0]                   bist_tx_word_count;
    wire [TX_APP_DATA_WIDTH-1:0]  bist_tx_app_data;
    wire                          bist_tx_advance;
    wire                          bist_rx_sop;
    wire [7:0]                    bist_rx_data_id;
    wire [15:0]                   bist_rx_word_count;
    wire [RX_APP_DATA_WIDTH-1:0]  bist_rx_app_data;
    wire                          bist_rx_valid;
  
    slink_bist #(
      .TX_APP_DATA_WIDTH     ( TX_APP_DATA_WIDTH ),
      .RX_APP_DATA_WIDTH     ( RX_APP_DATA_WIDTH )
    ) u_slink_bist (
      .core_scan_mode              ( core_scan_mode               ),            
      .core_scan_clk               ( core_scan_clk                ),            
      .core_scan_asyncrst_ctrl     ( core_scan_asyncrst_ctrl      ),            
      .link_clk                    ( link_clk                     ),            
      .link_clk_reset              ( link_reset                   ),            
      .apb_clk                     ( apb_clk_scan                 ), 
      .apb_reset                   ( apb_reset_scan               ), 
      .apb_paddr                   ( apb_paddr_bist               ), 
      .apb_pwrite                  ( apb_pwrite_bist              ), 
      .apb_psel                    ( apb_psel_bist                ), 
      .apb_penable                 ( apb_penable_bist             ), 
      .apb_pwdata                  ( apb_pwdata_bist              ), 
      .apb_prdata                  ( apb_prdata_bist              ), 
      .apb_pready                  ( apb_pready_bist              ), 
      .apb_pslverr                 ( apb_pslverr_bist             ),  
      .bist_active                 ( bist_active                  ),  
      .tx_sop                      ( bist_tx_sop                  ),  
      .tx_data_id                  ( bist_tx_data_id              ),  
      .tx_word_count               ( bist_tx_word_count           ),  
      .tx_app_data                 ( bist_tx_app_data             ),           
      .tx_advance                  ( bist_tx_advance              ),  
      .rx_sop                      ( bist_rx_sop                  ),  
      .rx_data_id                  ( bist_rx_data_id              ),  
      .rx_word_count               ( bist_rx_word_count           ),  
      .rx_app_data                 ( bist_rx_app_data             ),       
      .rx_valid                    ( bist_rx_valid                )); 
    
    assign ll_tx_sop        = bist_active ? bist_tx_sop         : tx_sop;
    assign ll_tx_data_id    = bist_active ? bist_tx_data_id     : tx_data_id;
    assign ll_tx_word_count = bist_active ? bist_tx_word_count  : tx_word_count;
    assign ll_tx_app_data   = bist_active ? bist_tx_app_data    : tx_app_data;
    assign tx_advance       = bist_active ? 1'b0                : ll_tx_advance;
    assign bist_tx_advance  = ll_tx_advance;
    
    assign rx_sop           = bist_active ? 1'b0 : ll_rx_sop;
    assign rx_data_id       = ll_rx_data_id;
    assign rx_word_count    = ll_rx_word_count;
    assign rx_app_data      = ll_rx_app_data;
    assign rx_valid         = bist_active ? 1'b0 : ll_rx_valid;
    assign rx_crc_corrupted = bist_active ? 1'b0 : ll_rx_crc_corrupted;
    
    assign bist_rx_sop           = ll_rx_sop;
    assign bist_rx_data_id       = ll_rx_data_id;
    assign bist_rx_word_count    = ll_rx_word_count;
    assign bist_rx_app_data      = ll_rx_app_data;
    assign bist_rx_valid         = ll_rx_valid;
    
  end else begin : bist_tieoff
    
    assign ll_tx_sop        = tx_sop;
    assign ll_tx_data_id    = tx_data_id;
    assign ll_tx_word_count = tx_word_count;
    assign ll_tx_app_data   = tx_app_data;
    assign tx_advance       = ll_tx_advance;
    
    assign rx_sop           = ll_rx_sop;
    assign rx_data_id       = ll_rx_data_id;
    assign rx_word_count    = ll_rx_word_count;
    assign rx_app_data      = ll_rx_app_data;
    assign rx_valid         = ll_rx_valid;
    assign rx_crc_corrupted = ll_rx_crc_corrupted;
    
    assign apb_prdata_bist  = 32'd0;
    assign apb_pready_bist  = 1'b1;
    assign apb_pslverr_bist = 1'b1; //force a slave error if you try to read it
  end
endgenerate

endmodule


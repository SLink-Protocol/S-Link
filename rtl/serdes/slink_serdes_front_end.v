module slink_serdes_front_end #(
  //
  parameter PHY_DATA_WIDTH        = 8,
  parameter NUM_TX_LANES          = 4,
  parameter NUM_RX_LANES          = 4,
  parameter LTSSM_REGISTER_TXDATA = 1,
  
  parameter DESKEW_FIFO_DEPTH     = 4,  
  
  //Attribute
  parameter P1_TS1_TX_RESET       = 16, 
  parameter P1_TS1_RX_RESET       = 8,  
  parameter P1_TS2_TX_RESET       = 8,  
  parameter P1_TS2_RX_RESET       = 8,  
  
  parameter P2_TS1_TX_RESET       = 32, 
  parameter P2_TS1_RX_RESET       = 16, 
  parameter P2_TS2_TX_RESET       = 8,  
  parameter P2_TS2_RX_RESET       = 8,  
  
  parameter P3R_TS1_TX_RESET      = 32, 
  parameter P3R_TS1_RX_RESET      = 16, 
  parameter P3R_TS2_TX_RESET      = 8,  
  parameter P3R_TS2_RX_RESET      = 8,  
  
  parameter SYNC_FREQ_RESET       = 15  
)(
  
  input  wire                         link_clk,
  input  wire                         link_clk_reset,
  input  wire                         refclk,
  input  wire                         refclk_reset,
  input  wire                         apb_clk,
  input  wire                         apb_reset,
  
  input  wire                         enable,
  
  output wire                         use_phy_clk,
  
  input  wire                         link_p1_req,
  input  wire                         link_p2_req,
  input  wire                         link_p3_req,
  output wire                         in_px_state,
  
  input  wire                         link_active_req,
  output wire                         ltssm_link_wake_n,
  input  wire                         link_reset_req,
  input  wire                         link_reset_req_local,
  output wire                         ltssm_link_reset_n,
  output wire                         in_reset_state,
  
  input  wire [9:0]                   swi_count_val_1us,
  
  // Attributes
  input  wire [15:0]                  sw_attr_addr,
  input  wire [15:0]                  sw_attr_wdata,
  input  wire                         sw_attr_write,
  input  wire                         sw_attr_local,
  output wire [15:0]                  sw_attr_data_read,
  input  wire                         sw_attr_data_read_rinc,
  output wire                         sw_attr_send_fifo_full,
  output wire                         sw_attr_send_fifo_empty,
  output wire                         sw_attr_recv_fifo_full,
  output wire                         sw_attr_recv_fifo_empty,
  input  wire                         sw_attr_shadow_update,
  input  wire                         sw_attr_shadow_update_winc,
  input  wire                         sw_attr_effective_update,
  input  wire                         sw_attr_effective_update_winc,
  
  output wire [2:0]                   attr_active_txs,
  output wire [2:0]                   attr_active_rxs,
  
  // LL
  output wire                         ll_enable,
  output wire                         ll_tx_valid,
  input  wire                         ll_tx_idle,
  input  wire [(NUM_TX_LANES*
                PHY_DATA_WIDTH)-1:0]  ll_tx_data,
  output wire                         ll_tx_sds_sent,
                
  output wire                         ll_rx_valid,
  output wire [(NUM_RX_LANES*
                PHY_DATA_WIDTH)-1:0]  ll_rx_data,
  output wire                         ll_rx_sds_recv,
  
  
  // PHY
  output wire                         phy_clk_en,
  output wire                         phy_clk_idle,
  input  wire                         phy_clk_ready,
  
  output wire [NUM_TX_LANES-1:0]      phy_tx_en,
  input  wire [NUM_TX_LANES-1:0]      phy_tx_ready,
  input  wire [NUM_TX_LANES-1:0]      phy_tx_dirdy,
  output wire [(NUM_TX_LANES*
                PHY_DATA_WIDTH)-1:0]  phy_tx_data,
  
  output wire [NUM_RX_LANES-1:0]      phy_rx_en,
  input  wire [NUM_RX_LANES-1:0]      phy_rx_clk,   
  input  wire [NUM_RX_LANES-1:0]      phy_rx_clk_reset,   
  input  wire [NUM_RX_LANES-1:0]      phy_rx_ready,
  input  wire [NUM_RX_LANES-1:0]      phy_rx_valid,   
  input  wire [NUM_RX_LANES-1:0]      phy_rx_dordy,  
  output wire [NUM_RX_LANES-1:0]      phy_rx_align,     
  input  wire [(NUM_RX_LANES*
                PHY_DATA_WIDTH)-1:0]  phy_rx_data
);

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
wire [ 7:0]   attr_sync_freq;


wire          ltssm_attr_ready;
wire [15:0]   ltssm_attr_addr;
wire [15:0]   ltssm_attr_wdata;
wire          ltssm_attr_write;
wire          ltssm_attr_sent;

wire          link_attr_shadow_update;
wire [15:0]   link_attr_addr;
wire [15:0]   link_attr_data;
wire [15:0]   link_attr_data_read;
wire          link_attr_read_req;

wire [NUM_RX_LANES-1:0]       rx_ts1_seen;
wire [NUM_RX_LANES-1:0]       rx_ts2_seen;
wire [NUM_RX_LANES-1:0]       rx_sds_seen;
wire [(NUM_RX_LANES*
       PHY_DATA_WIDTH)-1:0]   rx_deskew_data;
wire                          deskew_enable;

wire          rx_px_req_pkt;
wire [2:0]    rx_px_req_state;
wire          rx_px_rej_pkt;
wire          rx_px_start_pkt;
wire          effect_update;
wire          link_hard_reset_cond;


slink_ltssm #(
  //parameters
  .REGISTER_TXDATA    ( LTSSM_REGISTER_TXDATA ),
  .NUM_TX_LANES       ( NUM_TX_LANES          ),
  .NUM_RX_LANES       ( NUM_RX_LANES          ),
  .DATA_WIDTH         ( PHY_DATA_WIDTH        )
) u_slink_ltssm (
  .clk                     ( link_clk                           ),       
  .reset                   ( link_clk_reset                     ),    
  .refclk                  ( refclk                             ),
  .refclk_reset            ( refclk_reset                       ),
  .enable                  ( enable                             ),    
  .p1_ts1_tx_count         ( attr_p1_ts1_tx                     ),  
  .p1_ts1_rx_count         ( attr_p1_ts1_rx                     ),  
  .p1_ts2_tx_count         ( attr_p1_ts2_tx                     ),  
  .p1_ts2_rx_count         ( attr_p1_ts2_rx                     ),  
  .p2_ts1_tx_count         ( attr_p2_ts1_tx                     ),  
  .p2_ts1_rx_count         ( attr_p2_ts1_rx                     ),  
  .p2_ts2_tx_count         ( attr_p2_ts2_tx                     ),  
  .p2_ts2_rx_count         ( attr_p2_ts2_rx                     ),  
  .p3r_ts1_tx_count        ( attr_p3r_ts1_tx                    ),  
  .p3r_ts1_rx_count        ( attr_p3r_ts1_rx                    ),  
  .p3r_ts2_tx_count        ( attr_p3r_ts2_tx                    ),  
  .p3r_ts2_rx_count        ( attr_p3r_ts2_rx                    ),  
  .px_clk_trail            ( {8'd0, attr_px_clk_trail}          ),
  .swi_clk_switch_time     ( 16'd8                              ),  
  .swi_p0_exit_time        ( 16'd16                             ),
  .attr_sync_freq          ( attr_sync_freq                     ),
  .active_rx_lanes         ( attr_active_rxs                    ),    
  .active_tx_lanes         ( attr_active_txs                    ),    
  .use_phy_clk             ( use_phy_clk                        ),  
  .rx_ts1_seen             ( rx_ts1_seen                        ),  
  .rx_ts2_seen             ( rx_ts2_seen                        ),  
  .rx_sds_seen             ( rx_sds_seen                        ),  
  .sds_sent                ( ll_tx_sds_sent                     ),
  .deskew_enable           ( deskew_enable                      ),
  
  
  .link_p1_req             ( link_p1_req || rx_px_req_state [0] ),   
  .link_p2_req             ( link_p2_req || rx_px_req_state [1] ),   
  .link_p3_req             ( link_p3_req || rx_px_req_state [2] ),
  .link_px_req_pkt         ( rx_px_req_pkt                      ),  
  .link_px_start_pkt       ( rx_px_start_pkt                    ),  
  .in_px_state             ( in_px_state                        ),  
  .effect_update           ( effect_update                      ),
  
  .link_active_req         ( link_active_req                    ),
  .link_wake_n             ( ltssm_link_wake_n                  ),
  .link_reset_req          ( link_reset_req                     ),
  .link_reset_req_local    ( link_reset_req_local               ),
  .link_reset_n            ( ltssm_link_reset_n                 ),
  .swi_count_val_1us       ( swi_count_val_1us                  ),
  .attr_hard_reset_us      ( attr_hard_reset_us                 ),
  .link_hard_reset_cond    ( link_hard_reset_cond               ),
  .in_reset_state          ( in_reset_state                     ),
  
  .attr_ready              ( ltssm_attr_ready                   ),
  .attr_addr               ( ltssm_attr_addr                    ),
  .attr_wdata              ( ltssm_attr_wdata                   ),
  .attr_write              ( ltssm_attr_write                   ),
  .attr_sent               ( ltssm_attr_sent                    ),
  
  .phy_clk_en              ( phy_clk_en                         ),  
  .phy_clk_idle            ( phy_clk_idle                       ),
  .phy_clk_ready           ( phy_clk_ready                      ),  
  .phy_tx_en               ( phy_tx_en                          ),  
  .phy_tx_ready            ( phy_tx_ready                       ),  
  .phy_tx_dirdy            ( phy_tx_dirdy                       ),
  .phy_rx_en               ( phy_rx_en                          ),  
  .phy_rx_ready            ( phy_rx_ready                       ),  
  .phy_rx_valid            ( phy_rx_valid                       ),  
  .phy_rx_dordy            ( phy_rx_dordy                       ),
  .phy_rx_align            ( phy_rx_align                       ),  
  .link_data               ( ll_tx_data                         ),  
  .ll_tx_idle              ( ll_tx_idle                         ),
  .ll_tx_valid             ( ll_tx_valid                        ),
  .ll_enable               ( ll_enable                          ),
  .ltssm_data              ( phy_tx_data                        ),
  .ltssm_state             ( ltssm_state                        )); 


assign ll_rx_sds_recv = (&rx_sds_seen);

slink_rx_align_deskew #(
  //parameters
  .FIFO_DEPTH         ( DESKEW_FIFO_DEPTH ),
  .NUM_LANES          ( NUM_RX_LANES      ),
  .DATA_WIDTH         ( PHY_DATA_WIDTH    )
) u_slink_rx_align_deskew (
  .clk                 ( link_clk                 ),  
  .reset               ( link_clk_reset           ),  
  .enable              ( deskew_enable            ),  
  .blockalign          ( (|phy_rx_align)          ),  
  
  .rxclk               ( phy_rx_clk               ),
  .rxclk_reset         ( phy_rx_clk_reset         ),
  .rx_data_in          ( phy_rx_data              ),  
  
  .active_lanes        ( attr_active_rxs          ),  
  .fifo_ptr_status     ( /*connect me???*/        ),  
  .rx_ts1_seen         ( rx_ts1_seen              ),  
  .rx_ts2_seen         ( rx_ts2_seen              ),  
  .rx_sds_seen         ( rx_sds_seen              ),  
  .rx_data_out         ( ll_rx_data               ),    
  .ll_rx_datavalid     ( ll_rx_valid              ), 
  
  .rx_px_req_pkt       ( rx_px_req_pkt            ),
  .rx_px_req_state     ( rx_px_req_state          ),
  .rx_px_start_pkt     ( rx_px_start_pkt          ),
  
  .attr_addr           ( link_attr_addr           ),
  .attr_data           ( link_attr_data           ),
  .attr_update         ( link_attr_shadow_update  ),
  .attr_rd_req         (                          ),
  
  .deskew_state        ( deskew_state             )); 


wire [15:0]   sw_attr_rdata_fe_fifo;     
wire [15:0]   sw_attr_rdata_local;   

wire          sw_shadow_update;
wire          sw_shadow_update_link_clk;
wire          sw_effective_update;
wire          sw_effective_update_link_clk;


assign sw_shadow_update       = sw_attr_shadow_update    && sw_attr_shadow_update_winc;
assign sw_effective_update    = sw_attr_effective_update && sw_attr_effective_update_winc;

slink_sync_pulse u_slink_sync_pulse_attr_sw_override[1:0] (
  .clk_in          ( apb_clk                        ),         
  .clk_in_reset    ( apb_reset                      ),         
  .data_in         ( {(sw_shadow_update  && 
                       sw_attr_local &&
                       sw_attr_write),
                      sw_effective_update}          ),              
  .clk_out         ( link_clk                       ),              
  .clk_out_reset   ( link_clk_reset                 ),              
  .data_out        ( {sw_shadow_update_link_clk,
                      sw_effective_update_link_clk} )); 


assign ltssm_attr_ready = ~sw_attr_send_fifo_empty;

slink_attr_ctrl #(
  //parameters
  .SW_ATTR_FIFO_DEPTH ( 2         )
) u_slink_attr_ctrl (
  .link_clk              ( link_clk                     ),      
  .link_reset            ( link_clk_reset               ),      
  .apb_clk               ( apb_clk                      ),   
  .apb_reset             ( apb_reset                    ),   
  
  .apb_attr_addr         ( sw_attr_addr                 ), 
  .apb_attr_wdata        ( sw_attr_wdata                ), 
  .apb_attr_wr           ( sw_attr_write                ), 
  
  .apb_send_fifo_winc    ( sw_shadow_update &&
                           ~sw_attr_local               ),     
  .apb_send_fifo_rinc    ( ltssm_attr_sent              ),         
  .apb_send_fifo_full    ( sw_attr_send_fifo_full       ),
  .apb_send_fifo_empty   ( sw_attr_send_fifo_empty      ),
  
  .send_attr_addr        ( ltssm_attr_addr              ),         
  .send_attr_wdata       ( ltssm_attr_wdata             ),         
  .send_attr_wr          ( ltssm_attr_write             ),    
  
  .recv_attr_rdata       ( 16'd0/*recv_attr_rdata*/     ),  //input -  [15:0]              
  .apb_recv_fifo_winc    ( 1'b0/*apb_recv_fifo_winc*/   ),  //input -  1              
  .apb_recv_fifo_rinc    ( sw_attr_data_read_rinc &&
                           sw_attr_local                ),       
  .apb_recv_fifo_full    ( sw_attr_recv_fifo_full       ), 
  .apb_recv_fifo_empty   ( sw_attr_recv_fifo_empty      ), 
  .apb_recv_attr_rdata   ( sw_attr_rdata_fe_fifo        )); 



assign sw_attr_data_read  = sw_attr_local ? sw_attr_rdata_local : sw_attr_rdata_fe_fifo;

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
  .attr_sync_freq        ( attr_sync_freq               ),

  .clk                   ( link_clk                     ),  
  .reset                 ( link_clk_reset               ),       
  .hard_reset_cond       ( link_hard_reset_cond         ),
  .link_attr_addr        ( link_attr_addr               ),  
  .link_attr_data        ( link_attr_data               ),  
  .link_shadow_update    ( link_attr_shadow_update      ),  
  .link_attr_data_read   ( link_attr_data_read          ),  
  .app_attr_addr         ( 16'd0                        ),  
  .app_attr_data         ( 16'd0                        ),  
  .app_shadow_update     ( 1'b0                         ),  
  .app_attr_data_read    (                              ),  
  .sw_attr_addr          ( sw_attr_addr                 ), 
  .sw_attr_data          ( sw_attr_wdata                ), 
  .sw_shadow_update      ( sw_shadow_update_link_clk    ), 
  .sw_attr_data_read     ( sw_attr_rdata_local          ),  

   
  .effective_update      ( effect_update  ||
                           sw_effective_update_link_clk )); 


endmodule

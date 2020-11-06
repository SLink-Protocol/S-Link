`ifndef MAX_TX_LANES
  `define MAX_TX_LANES 8
`endif

`ifndef MAX_RX_LANES
  `define MAX_RX_LANES 8
`endif



`ifndef MST_PHY_DATA_WIDTH
  `define MST_PHY_DATA_WIDTH 16
`endif

`ifndef SLV_PHY_DATA_WIDTH
  `define SLV_PHY_DATA_WIDTH 16
`endif


`ifndef MST_TX_APP_DATA_WIDTH
  `define MST_TX_APP_DATA_WIDTH (`MAX_TX_LANES * `MST_PHY_DATA_WIDTH)
`endif
`ifndef MST_RX_APP_DATA_WIDTH
  `define MST_RX_APP_DATA_WIDTH (`MAX_RX_LANES * `MST_PHY_DATA_WIDTH)
`endif

`ifndef SLV_TX_APP_DATA_WIDTH
  `define SLV_TX_APP_DATA_WIDTH (`MAX_RX_LANES * `SLV_PHY_DATA_WIDTH)
`endif
`ifndef SLV_RX_APP_DATA_WIDTH
  `define SLV_RX_APP_DATA_WIDTH (`MAX_TX_LANES * `SLV_PHY_DATA_WIDTH)
`endif


parameter MST_TX_APP_DATA_WIDTH   = `MST_TX_APP_DATA_WIDTH;
parameter MST_RX_APP_DATA_WIDTH   = `MST_RX_APP_DATA_WIDTH;
parameter SLV_TX_APP_DATA_WIDTH   = `SLV_TX_APP_DATA_WIDTH;
parameter SLV_RX_APP_DATA_WIDTH   = `SLV_RX_APP_DATA_WIDTH;
parameter NUM_TX_LANES            = `MAX_TX_LANES;
parameter NUM_RX_LANES            = `MAX_RX_LANES;
parameter MST_PHY_DATA_WIDTH      = `MST_PHY_DATA_WIDTH;
parameter SLV_PHY_DATA_WIDTH      = `SLV_PHY_DATA_WIDTH;

//App Data Width Check
initial begin
  if(MST_TX_APP_DATA_WIDTH < (NUM_TX_LANES * MST_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("MST_TX_APP_DATA_WIDTH is too small"))
  end
  if(MST_RX_APP_DATA_WIDTH < (NUM_RX_LANES * MST_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("MST_RX_APP_DATA_WIDTH is too small"))
  end
  
  if(SLV_TX_APP_DATA_WIDTH < (NUM_RX_LANES * SLV_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("SLV_TX_APP_DATA_WIDTH is too small"))
  end
  if(SLV_RX_APP_DATA_WIDTH < (NUM_TX_LANES * SLV_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("SLV_RX_APP_DATA_WIDTH is too small"))
  end
end

//-------------------------
// Clocks / Reset
//-------------------------
reg main_reset = 0;

reg apb_clk = 0;
reg refclk  = 0;
//reg phy_clk = 0;
wire [NUM_TX_LANES-1:0] mst_phy_clk;  //fix
wire [NUM_TX_LANES-1:0] slv_phy_clk;

always #5     apb_clk <= ~apb_clk;
always #13.02 refclk  <= ~refclk;


wire                                mst_link_clk;
wire                                mst_link_reset;

wire                                mst_tx_sop;
wire  [7:0]                         mst_tx_data_id;
wire  [15:0]                        mst_tx_word_count;
wire  [MST_TX_APP_DATA_WIDTH-1:0]   mst_tx_app_data;
wire                                mst_tx_valid;
wire                                mst_tx_advance;

wire                                mst_rx_sop;
wire  [7:0]                         mst_rx_data_id;
wire  [15:0]                        mst_rx_word_count;
wire  [MST_RX_APP_DATA_WIDTH-1:0]   mst_rx_app_data;
wire                                mst_rx_valid;
wire                                mst_rx_crc_corrupted;
wire                                mst_interrupt;

wire                                slv_link_clk;
wire                                slv_link_reset;

wire                                slv_tx_sop;
wire  [7:0]                         slv_tx_data_id;
wire  [15:0]                        slv_tx_word_count;
wire  [SLV_TX_APP_DATA_WIDTH-1:0]   slv_tx_app_data;
wire                                slv_tx_valid;
wire                                slv_tx_advance;

wire                                slv_rx_sop;
wire  [7:0]                         slv_rx_data_id;
wire  [15:0]                        slv_rx_word_count;
wire  [SLV_RX_APP_DATA_WIDTH-1:0]   slv_rx_app_data;
wire                                slv_rx_valid;
wire                                slv_rx_crc_corrupted;
wire                                slv_interrupt;


wire [NUM_TX_LANES-1:0]                       mst_phy_txclk;
wire                                          mst_phy_clk_en;
wire                                          mst_phy_clk_idle;
wire                                          mst_phy_clk_ready;
wire [NUM_TX_LANES-1:0]                       mst_phy_tx_en;
wire [NUM_TX_LANES-1:0]                       mst_phy_tx_ready;
wire [NUM_TX_LANES-1:0]                       mst_phy_tx_dirdy;
wire [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0]  mst_phy_tx_data;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_en;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_clk;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_ready;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_valid;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_dordy;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_align;
wire [(NUM_RX_LANES*MST_PHY_DATA_WIDTH)-1:0]  mst_phy_rx_data;

wire [NUM_RX_LANES-1:0]                       slv_phy_txclk;
wire                                          slv_phy_clk_en;
wire                                          slv_phy_clk_idle;
wire                                          slv_phy_clk_ready;
wire [NUM_RX_LANES-1:0]                       slv_phy_tx_en;
wire [NUM_RX_LANES-1:0]                       slv_phy_tx_ready;
wire [NUM_RX_LANES-1:0]                       slv_phy_tx_dirdy;
wire [(NUM_RX_LANES*SLV_PHY_DATA_WIDTH)-1:0]  slv_phy_tx_data;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_en;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_clk;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_ready;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_valid;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_dordy;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_align;
wire [(NUM_TX_LANES*SLV_PHY_DATA_WIDTH)-1:0]  slv_phy_rx_data;


bit pkt_type = 0;





wire [8:0]            apb_paddr;
wire                  apb_pwrite;
wire                  apb_psel;
wire                  apb_penable;
wire [31:0]           apb_pwdata;
wire [31:0]           apb_prdata;
wire                  apb_pready;
wire                  apb_pslverr;

wire [8:0]            slv_apb_paddr;
wire                  slv_apb_pwrite;
wire                  slv_apb_psel;
wire                  slv_apb_penable;
wire [31:0]           slv_apb_pwdata;
wire [31:0]           slv_apb_prdata;
wire                  slv_apb_pready;
wire                  slv_apb_pslverr;

wire mst_slink_gpio_reset_n_oen;
wire mst_slink_gpio_reset_n   ;
wire mst_slink_gpio_wake_n_oen;
wire mst_slink_gpio_wake_n    ;
wire slv_slink_gpio_reset_n_oen;
wire slv_slink_gpio_reset_n   ;
wire slv_slink_gpio_wake_n_oen;
wire slv_slink_gpio_wake_n    ;


`include "slink_drivers_inst.vh"

slink #(
  //parameters
  .NUM_TX_LANES       ( NUM_TX_LANES          ),
  .NUM_RX_LANES       ( NUM_RX_LANES          ),
  .TX_APP_DATA_WIDTH  ( MST_TX_APP_DATA_WIDTH ),
  .RX_APP_DATA_WIDTH  ( MST_RX_APP_DATA_WIDTH ),
  .PHY_DATA_WIDTH     ( MST_PHY_DATA_WIDTH    ),
  .DESKEW_FIFO_DEPTH  ( 4         )
) u_slink_MASTER (
  .core_scan_mode              ( 1'b0                         ),  
  .core_scan_clk               ( 1'b0                         ),  
  .core_scan_asyncrst_ctrl     ( 1'b0                         ),  
  .apb_clk                     ( apb_clk                      ),  
  .apb_reset                   ( main_reset                   ),  
  .apb_paddr                   ( apb_paddr                    ),   
  .apb_pwrite                  ( apb_pwrite                   ),  
  .apb_psel                    ( apb_psel                     ),  
  .apb_penable                 ( apb_penable                  ),  
  .apb_pwdata                  ( apb_pwdata                   ),   
  .apb_prdata                  ( apb_prdata                   ),   
  .apb_pready                  ( apb_pready                   ),  
  .apb_pslverr                 ( apb_pslverr                  ),  
  .link_clk                    ( mst_link_clk                 ),  
  .link_reset                  ( mst_link_reset               ),  
  
               
  .tx_sop                      ( mst_tx_sop                   ),  
  .tx_data_id                  ( mst_tx_data_id               ),  
  .tx_word_count               ( mst_tx_word_count            ),  
  .tx_app_data                 ( mst_tx_app_data              ),   
  .tx_advance                  ( mst_tx_advance               ),  
  .rx_sop                      ( mst_rx_sop                   ),  
  .rx_data_id                  ( mst_rx_data_id               ),  
  .rx_word_count               ( mst_rx_word_count            ),  
  .rx_app_data                 ( mst_rx_app_data              ),   
  .rx_valid                    ( mst_rx_valid                 ),  
  .rx_crc_corrupted            ( mst_rx_crc_corrupted         ),
  .interrupt                   ( mst_interrupt                ),
  
  .p1_req                      ( 1'b0 ),
  .p2_req                      ( 1'b0 ),
  .p3_req                      ( 1'b0 ),
  
  .slink_gpio_reset_n_oen      ( mst_slink_gpio_reset_n_oen   ),
  .slink_gpio_reset_n          ( mst_slink_gpio_reset_n       ),
  .slink_gpio_wake_n_oen       ( mst_slink_gpio_wake_n_oen    ),
  .slink_gpio_wake_n           ( mst_slink_gpio_wake_n        ),
  
  .refclk                      ( refclk                       ),            
  .phy_clk                     ( mst_phy_txclk[0]             ),            
  .phy_clk_en                  ( mst_phy_clk_en               ),  
  .phy_clk_idle                ( mst_phy_clk_idle             ),
  .phy_clk_ready               ( mst_phy_clk_ready            ),  
  .phy_tx_en                   ( mst_phy_tx_en                ),  
  .phy_tx_ready                ( mst_phy_tx_ready             ),  
  .phy_tx_dirdy                ( mst_phy_tx_dirdy             ),
  .phy_tx_data                 ( mst_phy_tx_data              ),   
  .phy_rx_en                   ( mst_phy_rx_en                ), 
  .phy_rx_clk                  ( mst_phy_rx_clk               ), 
  .phy_rx_ready                ( mst_phy_rx_ready             ),  
  .phy_rx_valid                ( mst_phy_rx_valid             ), 
  .phy_rx_dordy                ( mst_phy_rx_dordy             ), 
  .phy_rx_align                ( mst_phy_rx_align             ),  
  .phy_rx_data                 ( mst_phy_rx_data              ));  



slink #(
  //parameters
  .NUM_TX_LANES       ( NUM_RX_LANES          ),
  .NUM_RX_LANES       ( NUM_TX_LANES          ),
  .TX_APP_DATA_WIDTH  ( SLV_TX_APP_DATA_WIDTH ),
  .RX_APP_DATA_WIDTH  ( SLV_RX_APP_DATA_WIDTH ),
  .PHY_DATA_WIDTH     ( SLV_PHY_DATA_WIDTH    ),
  .DESKEW_FIFO_DEPTH  ( 4         )
) u_slink_SLAVE (
  .core_scan_mode              ( 1'b0                         ),  
  .core_scan_clk               ( 1'b0                         ),  
  .core_scan_asyncrst_ctrl     ( 1'b0                         ),  
  //.main_reset                  ( main_reset                   ),  
  .apb_clk                     ( apb_clk                      ),  
  .apb_reset                   ( main_reset                   ),  
  .apb_paddr                   ( slv_apb_paddr                ),   
  .apb_pwrite                  ( slv_apb_pwrite               ),  
  .apb_psel                    ( slv_apb_psel                 ),  
  .apb_penable                 ( slv_apb_penable              ),  
  .apb_pwdata                  ( slv_apb_pwdata               ),    
  .apb_prdata                  ( slv_apb_prdata               ),    
  .apb_pready                  ( slv_apb_pready               ),  
  .apb_pslverr                 ( slv_apb_pslverr              ),  
  .link_clk                    ( slv_link_clk                 ),  
  .link_reset                  ( slv_link_reset               ),  
  
  .tx_sop                      ( slv_tx_sop                   ),  
  .tx_data_id                  ( slv_tx_data_id               ),  
  .tx_word_count               ( slv_tx_word_count            ),  
  .tx_app_data                 ( slv_tx_app_data              ),    
  .tx_advance                  ( slv_tx_advance               ),  
  .rx_sop                      ( slv_rx_sop                   ),  
  .rx_data_id                  ( slv_rx_data_id               ),  
  .rx_word_count               ( slv_rx_word_count            ),  
  .rx_app_data                 ( slv_rx_app_data              ),      
  .rx_valid                    ( slv_rx_valid                 ),  
  .rx_crc_corrupted            ( slv_rx_crc_corrupted         ),
  .interrupt                   ( slv_interrupt                ),
  
  .p1_req                      ( 1'b0 ),
  .p2_req                      ( 1'b0 ),
  .p3_req                      ( 1'b0 ),
  
  .slink_gpio_reset_n_oen      ( slv_slink_gpio_reset_n_oen   ),
  .slink_gpio_reset_n          ( slv_slink_gpio_reset_n       ),
  .slink_gpio_wake_n_oen       ( slv_slink_gpio_wake_n_oen    ),
  .slink_gpio_wake_n           ( slv_slink_gpio_wake_n        ),
  
  .refclk                      ( refclk                       ),             
  .phy_clk                     ( slv_phy_txclk[0]             ),            
  .phy_clk_en                  ( slv_phy_clk_en               ),  
  .phy_clk_idle                ( slv_phy_clk_idle             ),
  .phy_clk_ready               ( slv_phy_clk_ready            ),  
  .phy_tx_en                   ( slv_phy_tx_en                ),  
  .phy_tx_ready                ( slv_phy_tx_ready             ),  
  .phy_tx_dirdy                ( slv_phy_tx_dirdy             ),
  .phy_tx_data                 ( slv_phy_tx_data              ),   
  .phy_rx_en                   ( slv_phy_rx_en                ),  
  .phy_rx_clk                  ( slv_phy_rx_clk               ),
  .phy_rx_ready                ( slv_phy_rx_ready             ),  
  .phy_rx_valid                ( slv_phy_rx_valid             ), 
  .phy_rx_dordy                ( slv_phy_rx_dordy             ), 
  .phy_rx_align                ( slv_phy_rx_align             ),  
  .phy_rx_data                 ( slv_phy_rx_data              ));     


// Sideband signals
wire slink_reset_n_io;
wire slink_wake_n_io;
wire bla;

slink_gpio_model u_slink_gpio_model_MASTER[1:0] (
  .oen     ( {mst_slink_gpio_reset_n_oen,
              mst_slink_gpio_wake_n_oen}  ),      
  .sig_in  ( {mst_slink_gpio_reset_n,
              mst_slink_gpio_wake_n}      ),      
  .pad     ( {slink_reset_n_io,
              slink_wake_n_io}            )); 


slink_gpio_model u_slink_gpio_model_SLAVE[1:0] (
  .oen     ( {slv_slink_gpio_reset_n_oen,
              slv_slink_gpio_wake_n_oen}  ),      
  .sig_in  ( {slv_slink_gpio_reset_n,
              slv_slink_gpio_wake_n}      ),      
  .pad     ( {slink_reset_n_io,
              slink_wake_n_io}            )); 






wire [NUM_TX_LANES-1:0] txp, txn;
wire [NUM_RX_LANES-1:0] rxp, rxn;
wire                    clk_bitclk;

serdes_phy_model #(
  //parameters
  .IS_MASTER          ( 1                 ),
  .MAX_DELAY_CYC      ( 16                ),
  .DATA_WIDTH         ( MST_PHY_DATA_WIDTH),
  .NUM_TX_LANES       ( NUM_TX_LANES      ),
  .NUM_RX_LANES       ( NUM_RX_LANES      )
) u_serdes_phy_model_MASTER (
  .clk_enable    ( mst_phy_clk_en               ),  
  .clk_idle      ( mst_phy_clk_idle             ),  
  .clk_ready     ( mst_phy_clk_ready            ),  
  .clk_bitclk    ( clk_bitclk                   ),
  .tx_enable     ( mst_phy_tx_en                ),  
  .txclk         ( mst_phy_txclk                ),  
  .tx_data       ( mst_phy_tx_data              ),  
  .tx_reset      ( {NUM_TX_LANES{main_reset}}   ),  
  .tx_dirdy      ( mst_phy_tx_dirdy             ),  
  .tx_ready      ( mst_phy_tx_ready             ),  
  .rx_enable     ( mst_phy_rx_en                ),  
  .rxclk         ( mst_phy_rx_clk               ),  
  .rx_align      ( mst_phy_rx_align             ),  
  .rx_data       ( mst_phy_rx_data              ),  
  .rx_reset      ( {NUM_RX_LANES{main_reset}}   ),  
  .rx_locked     (                              ),  
  .rx_valid      ( mst_phy_rx_valid             ),  
  .rx_dordy      ( mst_phy_rx_dordy             ),
  .rx_ready      ( mst_phy_rx_ready             ),
  .txp           ( txp                          ),  
  .txn           ( txn                          ),  
  .rxp           ( rxp                          ),  
  .rxn           ( rxn                          )); 

serdes_phy_model #(
  //parameters
  .IS_MASTER          ( 0                 ),
  .MAX_DELAY_CYC      ( 16                ),
  .DATA_WIDTH         ( SLV_PHY_DATA_WIDTH),
  .NUM_TX_LANES       ( NUM_RX_LANES      ),
  .NUM_RX_LANES       ( NUM_TX_LANES      )
) u_serdes_phy_model_SLAVE (
  .clk_enable    ( slv_phy_clk_en               ),  
  .clk_idle      ( slv_phy_clk_idle             ),  
  .clk_ready     ( slv_phy_clk_ready            ),  
  .clk_bitclk    ( clk_bitclk                   ),
  .tx_enable     ( slv_phy_tx_en                ),  
  .txclk         ( slv_phy_txclk                ),  
  .tx_data       ( slv_phy_tx_data              ),  
  .tx_reset      ( {NUM_RX_LANES{main_reset}}   ),  
  .tx_dirdy      ( slv_phy_tx_dirdy             ),  
  .tx_ready      ( slv_phy_tx_ready             ),  
  .rx_enable     ( slv_phy_rx_en                ),  
  .rxclk         ( slv_phy_rx_clk               ),  
  .rx_align      ( slv_phy_rx_align             ),  
  .rx_data       ( slv_phy_rx_data              ),  
  .rx_reset      ( {NUM_TX_LANES{main_reset}}   ),  
  .rx_locked     (                              ),  
  .rx_valid      ( slv_phy_rx_valid             ),  
  .rx_dordy      ( slv_phy_rx_dordy             ),
  .rx_ready      ( slv_phy_rx_ready             ),
  .txp           ( rxp                          ),  
  .txn           ( rxn                          ),  
  .rxp           ( txp                          ),  
  .rxn           ( txn                          )); 

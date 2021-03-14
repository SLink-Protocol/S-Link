module slink_b2b_tb_wrapper #(
  parameter MST_TX_APP_DATA_WIDTH   = 32,
  parameter MST_RX_APP_DATA_WIDTH   = 32,
  parameter SLV_TX_APP_DATA_WIDTH   = 32,
  parameter SLV_RX_APP_DATA_WIDTH   = 32,
  parameter NUM_TX_LANES            = 8,
  parameter NUM_RX_LANES            = 8,
  parameter MST_PHY_DATA_WIDTH      = 16,
  parameter SLV_PHY_DATA_WIDTH      = 16,
  parameter SERDES_MODE             = 1
)(
  input  wire                               main_reset,
  
  input  wire                               mst_apb_clk,
  input  wire                               mst_apb_reset,
  input  wire [8:0]                         mst_apb_paddr,
  input  wire                               mst_apb_pwrite,
  input  wire                               mst_apb_psel,
  input  wire                               mst_apb_penable,
  input  wire [31:0]                        mst_apb_pwdata,
  output wire [31:0]                        mst_apb_prdata,
  output wire                               mst_apb_pready,
  output wire                               mst_apb_pslverr,

  
  output wire                               mst_link_clk,
  output wire                               mst_link_reset,
  input  wire                               mst_tx_sop,
  input  wire [7:0]                         mst_tx_data_id,
  input  wire [15:0]                        mst_tx_word_count,
  input  wire [MST_TX_APP_DATA_WIDTH-1:0]   mst_tx_app_data,
  output wire                               mst_tx_advance,
  output wire                               mst_rx_sop,
  output wire [7:0]                         mst_rx_data_id,
  output wire [15:0]                        mst_rx_word_count,
  output wire [MST_RX_APP_DATA_WIDTH-1:0]   mst_rx_app_data,
  output wire                               mst_rx_valid,
  output wire                               mst_rx_crc_corrupted,
  output wire                               mst_interrupt,
  input  wire                               mst_p1_req,
  input  wire                               mst_p2_req,
  input  wire                               mst_p3_req,
  output wire                               mst_in_px_state,
  output wire                               mst_in_reset_state,
  
  
  input  wire                               slv_apb_clk,
  input  wire                               slv_apb_reset,
  input  wire [8:0]                         slv_apb_paddr,
  input  wire                               slv_apb_pwrite,
  input  wire                               slv_apb_psel,
  input  wire                               slv_apb_penable,
  input  wire [31:0]                        slv_apb_pwdata,
  output wire [31:0]                        slv_apb_prdata,
  output wire                               slv_apb_pready,
  output wire                               slv_apb_pslverr,
  
  output wire                               slv_link_clk,
  output wire                               slv_link_reset,
  input  wire                               slv_tx_sop,
  input  wire [7:0]                         slv_tx_data_id,
  input  wire [15:0]                        slv_tx_word_count,
  input  wire [SLV_TX_APP_DATA_WIDTH-1:0]   slv_tx_app_data,
  output wire                               slv_tx_advance,
  output wire                               slv_rx_sop,
  output wire [7:0]                         slv_rx_data_id,
  output wire [15:0]                        slv_rx_word_count,
  output wire [SLV_RX_APP_DATA_WIDTH-1:0]   slv_rx_app_data,
  output wire                               slv_rx_valid,
  output wire                               slv_rx_crc_corrupted,
  output wire                               slv_interrupt,
  input  wire                               slv_p1_req,
  input  wire                               slv_p2_req,
  input  wire                               slv_p3_req,
  output wire                               slv_in_px_state,
  output wire                               slv_in_reset_state,
  
  input  wire                               refclk
);


wire [NUM_TX_LANES-1:0]                       mst_phy_tx_clk;
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

wire [NUM_RX_LANES-1:0]                       slv_phy_tx_clk;
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

wire mst_slink_gpio_reset_n_oen;
wire mst_slink_gpio_reset_n   ;
wire mst_slink_gpio_wake_n_oen;
wire mst_slink_gpio_wake_n    ;
wire slv_slink_gpio_reset_n_oen;
wire slv_slink_gpio_reset_n   ;
wire slv_slink_gpio_wake_n_oen;
wire slv_slink_gpio_wake_n    ;




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
  .apb_clk                     ( mst_apb_clk                  ),  
  .apb_reset                   ( mst_apb_reset                ),  
  .apb_paddr                   ( mst_apb_paddr                ),   
  .apb_pwrite                  ( mst_apb_pwrite               ),  
  .apb_psel                    ( mst_apb_psel                 ),  
  .apb_penable                 ( mst_apb_penable              ),  
  .apb_pwdata                  ( mst_apb_pwdata               ),   
  .apb_prdata                  ( mst_apb_prdata               ),   
  .apb_pready                  ( mst_apb_pready               ),  
  .apb_pslverr                 ( mst_apb_pslverr              ),  
  .link_clk                    ( mst_link_clk                 ),  
  .link_reset                  ( mst_link_reset               ),  
  
  .slink_enable                ( ~main_reset                  ),
  .por_reset                   ( main_reset                   ),
               
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
  
  .p1_req                      ( mst_p1_req                   ),
  .p2_req                      ( mst_p2_req                   ),
  .p3_req                      ( mst_p3_req                   ),
  .in_px_state                 ( mst_in_px_state              ),
  .in_reset_state              ( mst_in_reset_state           ),
  
  .slink_gpio_reset_n_oen      ( mst_slink_gpio_reset_n_oen   ),
  .slink_gpio_reset_n          ( mst_slink_gpio_reset_n       ),
  .slink_gpio_wake_n_oen       ( mst_slink_gpio_wake_n_oen    ),
  .slink_gpio_wake_n           ( mst_slink_gpio_wake_n        ),
  
  .refclk                      ( refclk                       ),            
  .phy_clk                     ( mst_phy_tx_clk[0]             ),            
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
  .apb_clk                     ( slv_apb_clk                  ),  
  .apb_reset                   ( slv_apb_reset                ),  
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
  
  .slink_enable                ( ~main_reset                  ),
  .por_reset                   ( main_reset                   ),
  
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
  
  .p1_req                      ( slv_p1_req                   ),
  .p2_req                      ( slv_p2_req                   ),
  .p3_req                      ( slv_p3_req                   ),
  .in_px_state                 ( slv_in_px_state              ),
  .in_reset_state              ( slv_in_reset_state           ),
  
  .slink_gpio_reset_n_oen      ( slv_slink_gpio_reset_n_oen   ),
  .slink_gpio_reset_n          ( slv_slink_gpio_reset_n       ),
  .slink_gpio_wake_n_oen       ( slv_slink_gpio_wake_n_oen    ),
  .slink_gpio_wake_n           ( slv_slink_gpio_wake_n        ),
  
  .refclk                      ( refclk                       ),             
  .phy_clk                     ( slv_phy_tx_clk[0]             ),            
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





generate
  if(SERDES_MODE == 1) begin : gen_serdes_mode
    //------------------------------------
    // PHY
    //------------------------------------
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
      .txclk         ( mst_phy_tx_clk                ),  
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
      .txclk         ( slv_phy_tx_clk                ),  
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
      
  end else begin : gen_parallel_mode
    wire [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0]  tx_par;
    wire                                          tx_ctrl;
    wire [(NUM_RX_LANES*MST_PHY_DATA_WIDTH)-1:0]  rx_par;
    wire                                          rx_ctrl;
    wire clk_byteclk;
    wire parclk;
    
    //TEMP
    assign mst_phy_tx_clk = {NUM_TX_LANES{parclk}};
    assign mst_phy_rx_clk = {NUM_RX_LANES{parclk}};
    assign slv_phy_tx_clk = {NUM_RX_LANES{parclk}};
    assign slv_phy_rx_clk = {NUM_TX_LANES{parclk}};
    
    //Size Check
    initial begin
      if(MST_PHY_DATA_WIDTH != SLV_PHY_DATA_WIDTH) begin
        `sim_fatal($display("MST_PHY_DATA_WIDTH must equal SLV_PHY_DATA_WIDTH in PARALLEL MODE!!"))
      end
    end
  
    slink_simple_io_phy_model #(
      //parameters
      .IS_MASTER          ( 1                   ),
      .CLK_PER_NS         ( 2                   ),
      .DATA_WIDTH         ( MST_PHY_DATA_WIDTH  ),
      .NUM_TX_LANES       ( NUM_TX_LANES        ),
      .NUM_RX_LANES       ( NUM_RX_LANES        )
    ) u_slink_simple_io_phy_model_MASTER (
      .clk_enable    ( mst_phy_clk_en             ),  
      .clk_idle      ( mst_phy_clk_idle           ),  
      .clk_ready     ( mst_phy_clk_ready          ),  
      .clk_byteclk   ( clk_byteclk                ),  
      .parclk        ( parclk                     ),  
      .tx_enable     ( mst_phy_tx_en              ),  
      .tx_data       ( mst_phy_tx_data            ),  
      .tx_data_ctrl  ( 1'b0                       ),  
      .tx_reset      ( {NUM_TX_LANES{main_reset}} ),  
      .tx_dirdy      ( mst_phy_tx_dirdy           ),  
      .tx_ready      ( mst_phy_tx_ready           ),  
      .rx_enable     ( mst_phy_rx_en              ),  
      .rx_data       ( mst_phy_rx_data            ),  
      .rx_data_ctrl  ( /*connme*/                 ),  
      .rx_reset      ( {NUM_RX_LANES{main_reset}} ),  
      .rx_dordy      ( mst_phy_rx_dordy           ),  
      .rx_ready      ( mst_phy_rx_ready           ),  
      .tx            ( tx_par                     ),  
      .tx_ctrl       ( tx_ctrl                    ),  
      .rx            ( rx_par                     ),  
      .rx_ctrl       ( rx_ctrl                    )); 
    
    slink_simple_io_phy_model #(
      //parameters
      .IS_MASTER          ( 1                   ),
      .CLK_PER_NS         ( 2                   ),
      .DATA_WIDTH         ( SLV_PHY_DATA_WIDTH  ),
      .NUM_TX_LANES       ( NUM_RX_LANES        ),
      .NUM_RX_LANES       ( NUM_TX_LANES        )
    ) u_slink_simple_io_phy_model_SLAVE (
      .clk_enable    ( slv_phy_clk_en             ),  
      .clk_idle      ( slv_phy_clk_idle           ),  
      .clk_ready     ( slv_phy_clk_ready          ),  
      .clk_byteclk   ( clk_byteclk                ),  
      .parclk        ( parclk                     ),  
      .tx_enable     ( slv_phy_tx_en              ),  
      .tx_data       ( slv_phy_tx_data            ),  
      .tx_data_ctrl  ( 1'b0                       ),  
      .tx_reset      ( {NUM_TX_LANES{main_reset}} ),  
      .tx_dirdy      ( slv_phy_tx_dirdy           ),  
      .tx_ready      ( slv_phy_tx_ready           ),  
      .rx_enable     ( slv_phy_rx_en              ),  
      .rx_data       ( slv_phy_rx_data            ),  
      .rx_data_ctrl  ( /*connme*/                 ),  
      .rx_reset      ( {NUM_RX_LANES{main_reset}} ),  
      .rx_dordy      ( slv_phy_rx_dordy           ),  
      .rx_ready      ( slv_phy_rx_ready           ),  
      .tx            ( rx_par                     ),  
      .tx_ctrl       ( rx_ctrl                    ),  
      .rx            ( tx_par                     ),  
      .rx_ctrl       ( tx_ctrl                    )); 
    
  end
endgenerate
endmodule

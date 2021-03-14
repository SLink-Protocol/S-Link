module slink_apb_gpio_top #(
  parameter     IS_HOST       = 1,
  parameter     IO_DATA_WIDTH = 1
)(
  input  wire                     core_scan_mode,
  input  wire                     core_scan_clk,
  input  wire                     core_scan_asyncrst_ctrl,
  input  wire                     core_scan_shift,
  input  wire                     core_scan_in,
  output wire                     core_scan_out,

  input  wire                     apb_clk,
  input  wire                     apb_reset,
  input  wire                     apb_psel,    
  input  wire                     apb_penable, 
  input  wire                     apb_pwrite,  
  input  wire [31:0]              apb_pwdata,  
  input  wire [9:0]               apb_paddr,   
  output wire                     apb_pslverr, 
  output wire                     apb_pready,  
  output wire [31:0]              apb_prdata, 
  
  //-------------------------------
  // Target APB
  //-------------------------------
  input  wire                     apb_tgt_psel,    
  input  wire                     apb_tgt_penable, 
  input  wire                     apb_tgt_pwrite,  
  input  wire [31:0]              apb_tgt_pwdata,  
  input  wire [31:0]              apb_tgt_paddr,   
  output wire                     apb_tgt_pslverr, 
  output wire                     apb_tgt_pready,  
  output wire [31:0]              apb_tgt_prdata, 
  
  //-------------------------------
  // Initiator APB
  //-------------------------------
  output wire                     apb_ini_psel,    
  output wire                     apb_ini_penable, 
  output wire                     apb_ini_pwrite,  
  output wire [31:0]              apb_ini_pwdata,  
  output wire [31:0]              apb_ini_paddr,   
  input  wire                     apb_ini_pslverr, 
  input  wire                     apb_ini_pready,  
  input  wire [31:0]              apb_ini_prdata, 
  
  input  wire                     por_reset,
  input  wire                     refclk,
  input  wire                     hsclk,
    
  input  wire                     slink_rx_clk,
  output wire                     slink_tx_clk,
  output wire [IO_DATA_WIDTH-1:0] slink_tx_data,                             
  input  wire [IO_DATA_WIDTH-1:0] slink_rx_data,
  
  output wire                     slink_gpio_reset_n_oen,
  input  wire                     slink_gpio_reset_n,
  output wire                     slink_gpio_wake_n_oen,
  input  wire                     slink_gpio_wake_n                
  
);

localparam TX_APP_DATA_WIDTH = 128;
localparam RX_APP_DATA_WIDTH = 128;

wire                          link_clk;
wire                          link_reset;
wire                          tx_sop;
wire [7:0]                    tx_data_id;
wire [15:0]                   tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]  tx_app_data;
wire                          tx_advance;
wire                          rx_sop;
wire [7:0]                    rx_data_id;
wire [15:0]                   rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]  rx_app_data;
wire                          rx_valid;
wire                          rx_crc_corrupted;
wire                          interrupt;
wire                          p1_req;
wire                          p2_req;
wire                          p3_req;
wire                          in_px_state;
wire                          in_reset_state;
wire                          phy_clk;
wire                          phy_clk_en;
wire                          phy_clk_idle;
wire                          phy_clk_ready;
wire                          phy_tx_en;
wire                          phy_tx_ready;
wire                          phy_tx_dirdy;
wire [7:0]                    phy_tx_data;
wire                          phy_rx_en;    
wire                          phy_rx_clk;   
wire                          phy_rx_ready; 
wire                          phy_rx_valid; 
wire                          phy_rx_dordy; 
wire                          phy_rx_align; 
wire [7:0]                    phy_rx_data;


wire                          apb_psel_app;    
wire                          apb_penable_app; 
wire                          apb_pwrite_app;  
wire [31:0]                   apb_pwdata_app;  
wire [7:0]                    apb_paddr_app;   
wire                          apb_pslverr_app; 
wire                          apb_pready_app;  
wire [31:0]                   apb_prdata_app; 

wire                          apb_psel_link;    
wire                          apb_penable_link; 
wire                          apb_pwrite_link;  
wire [31:0]                   apb_pwdata_link;  
wire [8:0]                    apb_paddr_link;   
wire                          apb_pslverr_link; 
wire                          apb_pready_link;  
wire [31:0]                   apb_prdata_link; 


wire  apb_clk_scan;
wire  apb_reset_scan;
slink_clock_mux u_slink_clock_mux_apb_clk (
  .clk0    ( apb_clk          ),     
  .clk1    ( core_scan_clk    ),     
  .sel     ( core_scan_mode   ),     
  .clk_out ( apb_clk_scan     )); 

slink_reset_sync u_slink_reset_sync_apb_reset (
  .clk           ( apb_clk_scan             ),  
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),  
  .reset_in      ( apb_reset                ),  
  .reset_out     ( apb_reset_scan           )); 

localparam  APB_LINK      = 2'h0,
            APB_LINK_BIST = 2'h1,
            APB_APP       = 2'h2;


assign apb_psel_app       = (apb_paddr[9:8] == APB_APP) && apb_psel;
assign apb_penable_app    = (apb_paddr[9:8] == APB_APP) && apb_penable;
assign apb_pwrite_app     = (apb_paddr[9:8] == APB_APP) && apb_pwrite;
assign apb_paddr_app      = apb_paddr[7:0];
assign apb_pwdata_app     = apb_pwdata;

assign apb_psel_link      = (apb_paddr[9:8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) && apb_psel;
assign apb_penable_link   = (apb_paddr[9:8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) && apb_penable;
assign apb_pwrite_link    = (apb_paddr[9:8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) && apb_pwrite;
assign apb_paddr_link     = apb_paddr[8:0];
assign apb_pwdata_link    = apb_pwdata;

assign apb_prdata         = (apb_paddr[8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) ? apb_prdata_link  : apb_prdata_app;
assign apb_pready         = (apb_paddr[8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) ? apb_pready_link  : apb_pready_app;
assign apb_pslverr        = (apb_paddr[8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) ? apb_pslverr_link : apb_pslverr_app;

slink_apb_top #(
  //parameters
  .APB_TARGET         ( IS_HOST                 ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       )
) u_slink_apb_top (
  .apb_clk             ( apb_clk_scan         ), 
  .apb_reset           ( apb_reset_scan       ), 
  .apb_psel            ( apb_psel_app         ), 
  .apb_penable         ( apb_penable_app      ), 
  .apb_pwrite          ( apb_pwrite_app       ), 
  .apb_pwdata          ( apb_pwdata_app       ),   
  .apb_paddr           ( apb_paddr_app        ),  
  .apb_pslverr         ( apb_pslverr_app      ), 
  .apb_pready          ( apb_pready_app       ), 
  .apb_prdata          ( apb_prdata_app       ),   
  .apb_tgt_psel        ( apb_tgt_psel         ),  
  .apb_tgt_penable     ( apb_tgt_penable      ),  
  .apb_tgt_pwrite      ( apb_tgt_pwrite       ),  
  .apb_tgt_pwdata      ( apb_tgt_pwdata       ),  
  .apb_tgt_paddr       ( apb_tgt_paddr        ),  
  .apb_tgt_pslverr     ( apb_tgt_pslverr      ),  
  .apb_tgt_pready      ( apb_tgt_pready       ),  
  .apb_tgt_prdata      ( apb_tgt_prdata       ),  
  .apb_ini_psel        ( apb_ini_psel         ),  
  .apb_ini_penable     ( apb_ini_penable      ),  
  .apb_ini_pwrite      ( apb_ini_pwrite       ),  
  .apb_ini_pwdata      ( apb_ini_pwdata       ),  
  .apb_ini_paddr       ( apb_ini_paddr        ),  
  .apb_ini_pslverr     ( apb_ini_pslverr      ),  
  .apb_ini_pready      ( apb_ini_pready       ),  
  .apb_ini_prdata      ( apb_ini_prdata       ),  
  .link_clk            ( link_clk             ),  
  .link_reset          ( link_reset           ),  
  .tx_sop              ( tx_sop               ),  
  .tx_data_id          ( tx_data_id           ),  
  .tx_word_count       ( tx_word_count        ),  
  .tx_app_data         ( tx_app_data          ),  
  .tx_advance          ( tx_advance           ),  
  .rx_sop              ( rx_sop               ),  
  .rx_data_id          ( rx_data_id           ),  
  .rx_word_count       ( rx_word_count        ),  
  .rx_app_data         ( rx_app_data          ),  
  .rx_valid            ( rx_valid             ),  
  .rx_crc_corrupted    ( rx_crc_corrupted     )); 


assign p1_req = 1'b0;
assign p2_req = 1'b0;
assign p3_req = 1'b0;

slink #(
  //parameters
  .DESKEW_FIFO_DEPTH     ( 4                       ),
  .INCLUDE_BIST          ( 1                       ),
  .LTSSM_REGISTER_TXDATA ( 0                       ),
  .NUM_RX_LANES          ( 1                       ),
  .NUM_TX_LANES          ( 1                       ),
  .P1_TS1_RX_RESET       ( 1                       ),
  .P1_TS1_TX_RESET       ( 1                       ),
  .P1_TS2_RX_RESET       ( 1                       ),
  .P1_TS2_TX_RESET       ( 1                       ),
  .P2_TS1_RX_RESET       ( 1                       ),
  .P2_TS1_TX_RESET       ( 1                       ),
  .P2_TS2_RX_RESET       ( 1                       ),
  .P2_TS2_TX_RESET       ( 1                       ),
  .P3R_TS1_RX_RESET      ( 1                       ),
  .P3R_TS1_TX_RESET      ( 1                       ),
  .P3R_TS2_RX_RESET      ( 1                       ),
  .P3R_TS2_TX_RESET      ( 1                       ),
  .PHY_DATA_WIDTH        ( 8                       ),
  .PX_CLK_TRAIL_RESET    ( 16                      ),
  .RX_APP_DATA_WIDTH     ( RX_APP_DATA_WIDTH       ),
  .START_IN_ONE_LANE     ( 1                       ),
  .SYNC_FREQ_RESET       ( 8                       ),
  .TX_APP_DATA_WIDTH     ( TX_APP_DATA_WIDTH       )
) u_slink (
  .core_scan_mode              ( core_scan_mode               ), 
  .core_scan_clk               ( core_scan_clk                ), 
  .core_scan_asyncrst_ctrl     ( core_scan_asyncrst_ctrl      ), 
  .apb_clk                     ( apb_clk_scan                 ),  
  .apb_reset                   ( apb_reset_scan               ),  
  .apb_paddr                   ( apb_paddr_link               ),  
  .apb_pwrite                  ( apb_pwrite_link              ),  
  .apb_psel                    ( apb_psel_link                ),  
  .apb_penable                 ( apb_penable_link             ),  
  .apb_pwdata                  ( apb_pwdata_link              ),  
  .apb_prdata                  ( apb_prdata_link              ),  
  .apb_pready                  ( apb_pready_link              ),  
  .apb_pslverr                 ( apb_pslverr_link             ),  
  .link_clk                    ( link_clk                     ),  
  .link_reset                  ( link_reset                   ),
  .slink_enable                ( ~por_reset                   ),  
  .por_reset                   ( por_reset                    ),
  .tx_sop                      ( tx_sop                       ),  
  .tx_data_id                  ( tx_data_id                   ),  
  .tx_word_count               ( tx_word_count                ),  
  .tx_app_data                 ( tx_app_data                  ),  
  .tx_advance                  ( tx_advance                   ),  
  .rx_sop                      ( rx_sop                       ),  
  .rx_data_id                  ( rx_data_id                   ),  
  .rx_word_count               ( rx_word_count                ),  
  .rx_app_data                 ( rx_app_data                  ),  
  .rx_valid                    ( rx_valid                     ),  
  .rx_crc_corrupted            ( rx_crc_corrupted             ),  
  .interrupt                   ( interrupt                    ),  
  .p1_req                      ( p1_req                       ),  
  .p2_req                      ( p2_req                       ),  
  .p3_req                      ( p3_req                       ),  
  .in_px_state                 ( in_px_state                  ),  
  .in_reset_state              ( in_reset_state               ),  
  .slink_gpio_reset_n_oen      ( slink_gpio_reset_n_oen       ),  
  .slink_gpio_reset_n          ( slink_gpio_reset_n           ),  
  .slink_gpio_wake_n_oen       ( slink_gpio_wake_n_oen        ),  
  .slink_gpio_wake_n           ( slink_gpio_wake_n            ),  
  .refclk                      ( refclk                       ),  
  .phy_clk                     ( phy_clk                      ),  
  .phy_clk_en                  ( phy_clk_en                   ),  
  .phy_clk_idle                ( phy_clk_idle                 ),  
  .phy_clk_ready               ( phy_clk_ready                ),  
  .phy_tx_en                   ( phy_tx_en                    ),  
  .phy_tx_ready                ( phy_tx_ready                 ),  
  .phy_tx_dirdy                ( 1'b1                         ),  
  .phy_tx_data                 ( phy_tx_data                  ),             
  .phy_rx_en                   ( phy_rx_en                    ),  
  .phy_rx_clk                  ( phy_rx_clk                   ),  
  .phy_rx_ready                ( phy_rx_ready                 ),  
  .phy_rx_valid                ( phy_rx_valid                 ),  
  .phy_rx_dordy                ( 1'b1                         ),  
  .phy_rx_align                ( phy_rx_align                 ),  
  .phy_rx_data                 ( phy_rx_data                  )); 


assign phy_rx_clk = phy_clk;

wire  slink_base_serial_clk;  
generate
  if(IS_HOST) begin
    slink_clock_mux u_slink_clock_mux_highspeed_clock (
      .clk0    ( hsclk                  ),     
      .clk1    ( core_scan_clk          ),     
      .sel     ( core_scan_mode         ),     
      .clk_out ( slink_base_serial_clk  )); 
  end else begin
    slink_clock_mux u_slink_clock_mux_highspeed_clock (
      .clk0    ( slink_rx_clk           ),     
      .clk1    ( core_scan_clk          ),     
      .sel     ( core_scan_mode         ),     
      .clk_out ( slink_base_serial_clk  )); 
  end
endgenerate


wire por_reset_serial_clk;
slink_reset_sync u_slink_reset_sync_hs_clk_porreset (
  .clk           ( slink_base_serial_clk    ),  
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),  
  .reset_in      ( por_reset                ),  
  .reset_out     ( por_reset_serial_clk     )); 

slink_gpio_serdes #(
  //parameters
  .IO_DATA_WIDTH      ( IO_DATA_WIDTH ),
  .IS_MASTER          ( IS_HOST       ),
  .PAR_DATA_WIDTH     ( 8             )
) u_slink_gpio_serdes (
  .core_scan_mode    ( core_scan_mode         ),  
  .serial_clk        ( slink_base_serial_clk  ),  
  .serial_reset      ( por_reset_serial_clk   ),  
  .clk_en            ( phy_clk_en             ), 
  .clk_idle          ( phy_clk_idle           ), 
  .clk_ready         ( phy_clk_ready          ), 
  .phy_clk           ( phy_clk                ),  
  .tx_en             ( phy_tx_en              ),  
  .tx_ready          ( phy_tx_ready           ),  
  .tx_par_data       ( phy_tx_data            ),  
  .rx_en             ( phy_rx_en              ),  
  .rx_ready          ( phy_rx_ready           ),  
  .rx_par_data       ( phy_rx_data            ),  
  .tx_ser_clk        ( slink_tx_clk           ), 
  .tx_ser_data       ( slink_tx_data          ),    
  .rx_ser_data       ( slink_rx_data          ));

endmodule

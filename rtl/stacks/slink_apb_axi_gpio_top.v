module slink_apb_axi_gpio_top #(
  parameter     IS_HOST       = 1,
  parameter     IO_DATA_WIDTH = 1,
  
  parameter     NUM_INTS      = 16,
  parameter     NUM_GPIOS     = 8,
  
  parameter   AXI_ADDR_WIDTH  = 32,
  parameter   AXI_DATA_WIDTH  = 64
)(
  input  wire                           core_scan_mode,
  input  wire                           core_scan_clk,
  input  wire                           core_scan_asyncrst_ctrl,
  input  wire                           core_scan_shift,
  input  wire                           core_scan_in,
  output wire                           core_scan_out,

  input  wire                           apb_clk,
  input  wire                           apb_reset,
  input  wire                           apb_psel,    
  input  wire                           apb_penable, 
  input  wire                           apb_pwrite,  
  input  wire [31:0]                    apb_pwdata,  
  input  wire [9:0]                     apb_paddr,   
  output wire                           apb_pslverr, 
  output wire                           apb_pready,  
  output wire [31:0]                    apb_prdata, 
  
  output wire                           interrupt,
  
  //-------------------------------
  // Interrupts / GPIOs
  //-------------------------------
  input  wire [NUM_INTS-1:0]            i_interrupt,
  output wire [NUM_INTS-1:0]            o_interrupt,
  input  wire [NUM_GPIOS-1:0]           i_gpio,
  output wire [NUM_GPIOS-1:0]           o_gpio,
  
  //-------------------------------
  // Target APB
  //-------------------------------
  input  wire                           apb_tgt_psel,    
  input  wire                           apb_tgt_penable, 
  input  wire                           apb_tgt_pwrite,  
  input  wire [31:0]                    apb_tgt_pwdata,  
  input  wire [31:0]                    apb_tgt_paddr,   
  output wire                           apb_tgt_pslverr, 
  output wire                           apb_tgt_pready,  
  output wire [31:0]                    apb_tgt_prdata, 
  
  //-------------------------------
  // Initiator APB
  //-------------------------------
  output wire                           apb_ini_psel,    
  output wire                           apb_ini_penable, 
  output wire                           apb_ini_pwrite,  
  output wire [31:0]                    apb_ini_pwdata,  
  output wire [31:0]                    apb_ini_paddr,   
  input  wire                           apb_ini_pslverr, 
  input  wire                           apb_ini_pready,  
  input  wire [31:0]                    apb_ini_prdata, 
  
  
  //--------------------------------------
  // AXI Target
  //--------------------------------------
  input  wire [7:0]                     axi_tgt_awid,
  input  wire [AXI_ADDR_WIDTH-1:0]      axi_tgt_awaddr,
  input  wire [7:0]                     axi_tgt_awlen,
  input  wire [2:0]                     axi_tgt_awsize,
  input  wire [1:0]                     axi_tgt_awburst,
  input  wire [1:0]                     axi_tgt_awlock,
  input  wire [3:0]                     axi_tgt_awcache,
  input  wire [2:0]                     axi_tgt_awprot,
  input  wire [3:0]                     axi_tgt_awqos,
  input  wire [3:0]                     axi_tgt_awregion,
  input  wire                           axi_tgt_awvalid,
  output wire                           axi_tgt_awready,
  
  input  wire [7:0]                     axi_tgt_wid,
  input  wire [AXI_DATA_WIDTH-1:0]      axi_tgt_wdata,
  input  wire [(AXI_DATA_WIDTH/8)-1:0]  axi_tgt_wstrb,
  input  wire                           axi_tgt_wlast,
  input  wire                           axi_tgt_wvalid,
  output wire                           axi_tgt_wready,
  
  output wire [7:0]                     axi_tgt_bid,
  output wire [1:0]                     axi_tgt_bresp,
  output wire                           axi_tgt_bvalid,
  input  wire                           axi_tgt_bready,
  
  input  wire [7:0]                     axi_tgt_arid,
  input  wire [AXI_ADDR_WIDTH-1:0]      axi_tgt_araddr,
  input  wire [7:0]                     axi_tgt_arlen,
  input  wire [2:0]                     axi_tgt_arsize,
  input  wire [1:0]                     axi_tgt_arburst,
  input  wire [1:0]                     axi_tgt_arlock,
  input  wire [3:0]                     axi_tgt_arcache,
  input  wire [2:0]                     axi_tgt_arprot,
  input  wire [3:0]                     axi_tgt_arqos,
  input  wire [3:0]                     axi_tgt_arregion,
  input  wire                           axi_tgt_arvalid,
  output wire                           axi_tgt_arready,
  
  output wire [7:0]                     axi_tgt_rid,
  output wire [AXI_DATA_WIDTH-1:0]      axi_tgt_rdata,
  output wire [1:0]                     axi_tgt_rresp,
  output wire                           axi_tgt_rlast,
  output wire                           axi_tgt_rvalid,
  input  wire                           axi_tgt_rready,
  
  //--------------------------------------
  // AXI Initiator
  //--------------------------------------
  output wire [7:0]                     axi_ini_awid,
  output wire [AXI_ADDR_WIDTH-1:0]      axi_ini_awaddr,
  output wire [7:0]                     axi_ini_awlen,
  output wire [2:0]                     axi_ini_awsize,
  output wire [1:0]                     axi_ini_awburst,
  output wire [1:0]                     axi_ini_awlock,
  output wire [3:0]                     axi_ini_awcache,
  output wire [2:0]                     axi_ini_awprot,
  output wire [3:0]                     axi_ini_awqos,
  output wire [3:0]                     axi_ini_awregion,
  output wire                           axi_ini_awvalid,
  input  wire                           axi_ini_awready,
  
  output wire [7:0]                     axi_ini_wid,
  output wire [AXI_DATA_WIDTH-1:0]      axi_ini_wdata,
  output wire [(AXI_DATA_WIDTH/8)-1:0]  axi_ini_wstrb,
  output wire                           axi_ini_wlast,
  output wire                           axi_ini_wvalid,
  input  wire                           axi_ini_wready,
  
  input  wire [7:0]                     axi_ini_bid,
  input  wire [1:0]                     axi_ini_bresp,
  input  wire                           axi_ini_bvalid,
  output wire                           axi_ini_bready,
  
  output wire [7:0]                     axi_ini_arid,
  output wire [AXI_ADDR_WIDTH-1:0]      axi_ini_araddr,
  output wire [7:0]                     axi_ini_arlen,
  output wire [2:0]                     axi_ini_arsize,
  output wire [1:0]                     axi_ini_arburst,
  output wire [1:0]                     axi_ini_arlock,
  output wire [3:0]                     axi_ini_arcache,
  output wire [2:0]                     axi_ini_arprot,
  output wire [3:0]                     axi_ini_arqos,
  output wire [3:0]                     axi_ini_arregion,
  output wire                           axi_ini_arvalid,
  input  wire                           axi_ini_arready,
  
  input  wire [7:0]                     axi_ini_rid,
  input  wire [AXI_DATA_WIDTH-1:0]      axi_ini_rdata,
  input  wire [1:0]                     axi_ini_rresp,
  input  wire                           axi_ini_rlast,
  input  wire                           axi_ini_rvalid,
  output wire                           axi_ini_rready,
  
  
  input  wire                           por_reset,
  input  wire                           refclk,
  input  wire                           hsclk,
    
  input  wire                           slink_rx_clk,
  output wire                           slink_tx_clk,
  output wire [IO_DATA_WIDTH-1:0]       slink_tx_data,                       
  input  wire [IO_DATA_WIDTH-1:0]       slink_rx_data,
  
  output wire                           slink_gpio_reset_n_oen,
  input  wire                           slink_gpio_reset_n,
  output wire                           slink_gpio_wake_n_oen,
  input  wire                           slink_gpio_wake_n               
  
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




wire                          link_interrupt;
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

wire  refclk_scan;
wire  por_reset_refclk_scan;
slink_clock_mux u_slink_clock_mux_ref_clk (
  .clk0    ( refclk           ),     
  .clk1    ( core_scan_clk    ),     
  .sel     ( core_scan_mode   ),     
  .clk_out ( refclk_scan      )); 

slink_reset_sync u_slink_reset_sync_por_reset (
  .clk           ( refclk_scan              ),  
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),  
  .reset_in      ( por_reset                ),  
  .reset_out     ( por_reset_refclk_scan    )); 



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

assign apb_prdata         = (apb_paddr[9:8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) ? apb_prdata_link  : apb_prdata_app;
assign apb_pready         = (apb_paddr[9:8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) ? apb_pready_link  : apb_pready_app;
assign apb_pslverr        = (apb_paddr[9:8] == APB_LINK || apb_paddr[9:8] == APB_LINK_BIST) ? apb_pslverr_link : apb_pslverr_app;



wire          swi_apb_app_enable_muxed;
wire          swi_axi_app_enable_muxed;
wire          swi_int_app_enable_muxed;

wire  [7:0]   swi_tick_1us;
wire  [7:0]   swi_inactivity_count;
wire  [2:0]   swi_pstate_req;
wire          swi_pstate_ctrl_enable;
wire  [7:0]   swi_apb_cr_id;
wire  [7:0]   swi_apb_crack_id;
wire  [7:0]   swi_apb_ack_id;
wire  [7:0]   swi_apb_nack_id;
wire  [7:0]   swi_int_cr_id;
wire  [7:0]   swi_int_crack_id;
wire  [7:0]   swi_int_ack_id;
wire  [7:0]   swi_int_nack_id;
wire  [7:0]   swi_int_data_id;
wire  [15:0]  swi_int_word_count;



slink_apb_axi_regs_top #(
  .PSTATE_CTRL_ENABLE_RESET_PARAM ( IS_HOST )   //Slave should just listen
) u_slink_apb_axi_regs_top (
  .apb_app_enable              ( ~por_reset_refclk_scan       ),  
  .swi_apb_app_enable_muxed    ( swi_apb_app_enable_muxed     ),  
  .axi_app_enable              ( ~por_reset_refclk_scan       ),  
  .swi_axi_app_enable_muxed    ( swi_axi_app_enable_muxed     ),  
  .int_app_enable              ( ~por_reset_refclk_scan       ),  
  .swi_int_app_enable_muxed    ( swi_int_app_enable_muxed     ),  
  .w1c_in_apb_nack_seen        ( w1c_in_apb_nack_seen         ),  //input -  1                --NEW PORT
  .w1c_out_apb_nack_seen       ( w1c_out_apb_nack_seen        ),  //output - 1                --NEW PORT
  .w1c_in_apb_nack_sent        ( w1c_in_apb_nack_sent         ),  //input -  1                --NEW PORT
  .w1c_out_apb_nack_sent       ( w1c_out_apb_nack_sent        ),  //output - 1                --NEW PORT
  .w1c_in_int_nack_seen        ( w1c_in_int_nack_seen         ),  //input -  1                --NEW PORT
  .w1c_out_int_nack_seen       ( w1c_out_int_nack_seen        ),  //output - 1                --NEW PORT
  .w1c_in_int_nack_sent        ( w1c_in_int_nack_sent         ),  //input -  1                --NEW PORT
  .w1c_out_int_nack_sent       ( w1c_out_int_nack_sent        ),  //output - 1                --NEW PORT
  .swi_tick_1us                ( swi_tick_1us                 ),  
  .swi_inactivity_count        ( swi_inactivity_count         ),  
  .swi_pstate_req              ( swi_pstate_req               ),  
  .swi_pstate_ctrl_enable      ( swi_pstate_ctrl_enable       ),  
  .swi_apb_cr_id               ( swi_apb_cr_id                ),  
  .swi_apb_crack_id            ( swi_apb_crack_id             ),  
  .swi_apb_ack_id              ( swi_apb_ack_id               ),  
  .swi_apb_nack_id             ( swi_apb_nack_id              ),  
  .swi_int_cr_id               ( swi_int_cr_id                ),  
  .swi_int_crack_id            ( swi_int_crack_id             ),  
  .swi_int_ack_id              ( swi_int_ack_id               ),  
  .swi_int_nack_id             ( swi_int_nack_id              ),  
  .swi_int_data_id             ( swi_int_data_id              ),  
  .swi_int_word_count          ( swi_int_word_count           ),  
  .debug_bus_ctrl_status       (                              ),  
  .RegReset                    ( apb_reset_scan               ),  
  .RegClk                      ( apb_clk_scan                 ),  
  .PSEL                        ( apb_psel_app                 ),  
  .PENABLE                     ( apb_penable_app              ),  
  .PWRITE                      ( apb_pwrite_app               ),  
  .PSLVERR                     ( apb_pslverr_app              ),  
  .PREADY                      ( apb_pready_app               ),  
  .PADDR                       ( apb_paddr_app                ),  
  .PWDATA                      ( apb_pwdata_app               ),  
  .PRDATA                      ( apb_prdata_app               )); 


assign interrupt = link_interrupt;


//----------------------------------
// APB
//----------------------------------
wire                          apb_tx_sop;
wire [7:0]                    apb_tx_data_id;
wire [15:0]                   apb_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]  apb_tx_app_data;
wire                          apb_tx_advance;
wire                          apb_rx_sop;
wire [7:0]                    apb_rx_data_id;
wire [15:0]                   apb_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]  apb_rx_app_data;
wire                          apb_rx_valid;
wire                          apb_rx_crc_corrupted;

slink_apb_top #(
  //parameters
  .APB_TARGET         ( IS_HOST                 ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       )
) u_slink_apb_top (
  .apb_clk             ( apb_clk_scan             ), 
  .apb_reset           ( apb_reset_scan           ), 
  .enable              ( swi_apb_app_enable_muxed ),
  .swi_cr_id           ( swi_apb_cr_id            ),
  .swi_crack_id        ( swi_apb_crack_id         ),
  .swi_ack_id          ( swi_apb_ack_id           ),
  .swi_nack_id         ( swi_apb_nack_id          ), 
  .apb_tgt_psel        ( apb_tgt_psel             ),  
  .apb_tgt_penable     ( apb_tgt_penable          ),  
  .apb_tgt_pwrite      ( apb_tgt_pwrite           ),  
  .apb_tgt_pwdata      ( apb_tgt_pwdata           ),  
  .apb_tgt_paddr       ( apb_tgt_paddr            ),  
  .apb_tgt_pslverr     ( apb_tgt_pslverr          ),  
  .apb_tgt_pready      ( apb_tgt_pready           ),  
  .apb_tgt_prdata      ( apb_tgt_prdata           ),  
  .apb_ini_psel        ( apb_ini_psel             ),  
  .apb_ini_penable     ( apb_ini_penable          ),  
  .apb_ini_pwrite      ( apb_ini_pwrite           ),  
  .apb_ini_pwdata      ( apb_ini_pwdata           ),  
  .apb_ini_paddr       ( apb_ini_paddr            ),  
  .apb_ini_pslverr     ( apb_ini_pslverr          ),  
  .apb_ini_pready      ( apb_ini_pready           ),  
  .apb_ini_prdata      ( apb_ini_prdata           ),  
  .link_clk            ( link_clk                 ),  
  .link_reset          ( link_reset               ),  
  .tx_sop              ( apb_tx_sop               ),  
  .tx_data_id          ( apb_tx_data_id           ),  
  .tx_word_count       ( apb_tx_word_count        ),  
  .tx_app_data         ( apb_tx_app_data          ),  
  .tx_advance          ( apb_tx_advance           ),  
  .rx_sop              ( apb_rx_sop               ),  
  .rx_data_id          ( apb_rx_data_id           ),  
  .rx_word_count       ( apb_rx_word_count        ),  
  .rx_app_data         ( apb_rx_app_data          ),  
  .rx_valid            ( apb_rx_valid             ),  
  .rx_crc_corrupted    ( apb_rx_crc_corrupted     )); 



//----------------------------------
// Interrupts / IO
//----------------------------------
wire                          int_tx_sop;
wire [7:0]                    int_tx_data_id;
wire [15:0]                   int_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]  int_tx_app_data;
wire                          int_tx_advance;
wire                          int_rx_sop;
wire [7:0]                    int_rx_data_id;
wire [15:0]                   int_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]  int_rx_app_data;
wire                          int_rx_valid;
wire                          int_rx_crc_corrupted;

slink_int_gpio_top #(
  //parameters
  .NUM_GPIOS          ( NUM_GPIOS             ),
  .NUM_INTS           ( NUM_INTS              ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH     ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH     )
) u_slink_int_gpio_top (
  .app_clk             ( apb_clk_scan             ),              
  .app_reset           ( apb_reset_scan           ),              
  .enable              ( swi_int_app_enable_muxed ),              
  .swi_cr_id           ( swi_int_cr_id            ),   
  .swi_crack_id        ( swi_int_crack_id         ),   
  .swi_ack_id          ( swi_int_ack_id           ),   
  .swi_nack_id         ( swi_int_nack_id          ),   
  .swi_data_id         ( swi_int_data_id          ),   
  .swi_word_count      ( swi_int_word_count       ),    
  .nack_sent           (                          ),  //output - 1              
  .nack_seen           (                          ),  //output - 1              
  .i_interrupt         ( i_interrupt              ),  
  .o_interrupt         ( o_interrupt              ),  
  .i_gpio              ( i_gpio                   ),  
  .o_gpio              ( o_gpio                   ),  
  .link_clk            ( link_clk                 ),           
  .link_reset          ( link_reset               ),           
  .tx_sop              ( int_tx_sop               ),  
  .tx_data_id          ( int_tx_data_id           ),  
  .tx_word_count       ( int_tx_word_count        ),  
  .tx_app_data         ( int_tx_app_data          ),        
  .tx_advance          ( int_tx_advance           ),  
  .rx_sop              ( int_rx_sop               ),  
  .rx_data_id          ( int_rx_data_id           ),  
  .rx_word_count       ( int_rx_word_count        ),  
  .rx_app_data         ( int_rx_app_data          ),        
  .rx_valid            ( int_rx_valid             ),  
  .rx_crc_corrupted    ( int_rx_crc_corrupted     )); 


//----------------------------------
// Interrupts / IO
//----------------------------------
wire                          axi_tx_sop;
wire [7:0]                    axi_tx_data_id;
wire [15:0]                   axi_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]  axi_tx_app_data;
wire                          axi_tx_advance;
wire                          axi_rx_sop;
wire [7:0]                    axi_rx_data_id;
wire [15:0]                   axi_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]  axi_rx_app_data;
wire                          axi_rx_valid;
wire                          axi_rx_crc_corrupted;

slink_axi_top #(
  //parameters
  .ADDR_CH_APP_DEPTH  ( 4                 ),
  .AXI_ADDR_WIDTH     ( AXI_ADDR_WIDTH    ),
  .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH    ),
  .DATA_CH_APP_DEPTH  ( 8                 ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH )
) u_slink_axi_top (
  .axi_clk             ( apb_clk_scan             ),  //we tie these together here
  .axi_reset           ( apb_reset_scan           ),  //we tie these together here
  .tgt_awid            ( axi_tgt_awid             ),  
  .tgt_awaddr          ( axi_tgt_awaddr           ),            
  .tgt_awlen           ( axi_tgt_awlen            ),  
  .tgt_awsize          ( axi_tgt_awsize           ),  
  .tgt_awburst         ( axi_tgt_awburst          ),  
  .tgt_awlock          ( axi_tgt_awlock           ),  
  .tgt_awcache         ( axi_tgt_awcache          ),  
  .tgt_awprot          ( axi_tgt_awprot           ),  
  .tgt_awqos           ( axi_tgt_awqos            ),  
  .tgt_awregion        ( axi_tgt_awregion         ),  
  .tgt_awvalid         ( axi_tgt_awvalid          ),  
  .tgt_awready         ( axi_tgt_awready          ),  
  .tgt_wid             ( axi_tgt_wid              ),  
  .tgt_wdata           ( axi_tgt_wdata            ),            
  .tgt_wstrb           ( axi_tgt_wstrb            ),                
  .tgt_wlast           ( axi_tgt_wlast            ),  
  .tgt_wvalid          ( axi_tgt_wvalid           ),  
  .tgt_wready          ( axi_tgt_wready           ),  
  .tgt_bid             ( axi_tgt_bid              ),  
  .tgt_bresp           ( axi_tgt_bresp            ),  
  .tgt_bvalid          ( axi_tgt_bvalid           ),  
  .tgt_bready          ( axi_tgt_bready           ),  
  .tgt_arid            ( axi_tgt_arid             ),  
  .tgt_araddr          ( axi_tgt_araddr           ),            
  .tgt_arlen           ( axi_tgt_arlen            ),  
  .tgt_arsize          ( axi_tgt_arsize           ),  
  .tgt_arburst         ( axi_tgt_arburst          ),  
  .tgt_arlock          ( axi_tgt_arlock           ),  
  .tgt_arcache         ( axi_tgt_arcache          ),  
  .tgt_arprot          ( axi_tgt_arprot           ),  
  .tgt_arqos           ( axi_tgt_arqos            ),  
  .tgt_arregion        ( axi_tgt_arregion         ),  
  .tgt_arvalid         ( axi_tgt_arvalid          ),  
  .tgt_arready         ( axi_tgt_arready          ),  
  .tgt_rid             ( axi_tgt_rid              ),  
  .tgt_rdata           ( axi_tgt_rdata            ),            
  .tgt_rresp           ( axi_tgt_rresp            ),  
  .tgt_rlast           ( axi_tgt_rlast            ),  
  .tgt_rvalid          ( axi_tgt_rvalid           ),  
  .tgt_rready          ( axi_tgt_rready           ),  
  .ini_awid            ( axi_ini_awid             ),  
  .ini_awaddr          ( axi_ini_awaddr           ),            
  .ini_awlen           ( axi_ini_awlen            ),  
  .ini_awsize          ( axi_ini_awsize           ),  
  .ini_awburst         ( axi_ini_awburst          ),  
  .ini_awlock          ( axi_ini_awlock           ),  
  .ini_awcache         ( axi_ini_awcache          ),  
  .ini_awprot          ( axi_ini_awprot           ),  
  .ini_awqos           ( axi_ini_awqos            ),  
  .ini_awregion        ( axi_ini_awregion         ),  
  .ini_awvalid         ( axi_ini_awvalid          ),  
  .ini_awready         ( axi_ini_awready          ),  
  .ini_wid             ( axi_ini_wid              ),  
  .ini_wdata           ( axi_ini_wdata            ),            
  .ini_wstrb           ( axi_ini_wstrb            ),                
  .ini_wlast           ( axi_ini_wlast            ),  
  .ini_wvalid          ( axi_ini_wvalid           ),  
  .ini_wready          ( axi_ini_wready           ),  
  .ini_bid             ( axi_ini_bid              ),  
  .ini_bresp           ( axi_ini_bresp            ),  
  .ini_bvalid          ( axi_ini_bvalid           ),  
  .ini_bready          ( axi_ini_bready           ),  
  .ini_arid            ( axi_ini_arid             ),  
  .ini_araddr          ( axi_ini_araddr           ),            
  .ini_arlen           ( axi_ini_arlen            ),  
  .ini_arsize          ( axi_ini_arsize           ),  
  .ini_arburst         ( axi_ini_arburst          ),  
  .ini_arlock          ( axi_ini_arlock           ),  
  .ini_arcache         ( axi_ini_arcache          ),  
  .ini_arprot          ( axi_ini_arprot           ),  
  .ini_arqos           ( axi_ini_arqos            ),  
  .ini_arregion        ( axi_ini_arregion         ),  
  .ini_arvalid         ( axi_ini_arvalid          ),  
  .ini_arready         ( axi_ini_arready          ),  
  .ini_rid             ( axi_ini_rid              ),  
  .ini_rdata           ( axi_ini_rdata            ),            
  .ini_rresp           ( axi_ini_rresp            ),  
  .ini_rlast           ( axi_ini_rlast            ),  
  .ini_rvalid          ( axi_ini_rvalid           ),  
  .ini_rready          ( axi_ini_rready           ),  
  .enable              ( swi_axi_app_enable_muxed ),  
  .swi_aw_cr_id        ( 8'h40                    ),  
  .swi_aw_crack_id     ( 8'h41                    ),  
  .swi_aw_ack_id       ( 8'h42                    ),  
  .swi_aw_nack_id      ( 8'h43                    ),  
  .swi_aw_data_id      ( 8'h44                    ),  
  .swi_w_cr_id         ( 8'h45                    ),  
  .swi_w_crack_id      ( 8'h46                    ),  
  .swi_w_ack_id        ( 8'h47                    ),  
  .swi_w_nack_id       ( 8'h48                    ),  
  .swi_w_data_id       ( 8'h49                    ),  
  .swi_b_cr_id         ( 8'h4a                    ),  
  .swi_b_crack_id      ( 8'h4b                    ),  
  .swi_b_ack_id        ( 8'h4c                    ),  
  .swi_b_nack_id       ( 8'h4d                    ),  
  .swi_b_data_id       ( 8'h4e                    ),  
  .swi_ar_cr_id        ( 8'h50                    ),  
  .swi_ar_crack_id     ( 8'h51                    ),  
  .swi_ar_ack_id       ( 8'h52                    ),  
  .swi_ar_nack_id      ( 8'h53                    ),  
  .swi_ar_data_id      ( 8'h54                    ),  
  .swi_r_cr_id         ( 8'h55                    ),  
  .swi_r_crack_id      ( 8'h56                    ),  
  .swi_r_ack_id        ( 8'h57                    ),  
  .swi_r_nack_id       ( 8'h58                    ),  
  .swi_r_data_id       ( 8'h59                    ),  
  .link_clk            ( link_clk                 ),  
  .link_reset          ( link_reset               ),  
  .tx_sop              ( axi_tx_sop               ),  
  .tx_data_id          ( axi_tx_data_id           ),  
  .tx_word_count       ( axi_tx_word_count        ),  
  .tx_app_data         ( axi_tx_app_data          ),          
  .tx_advance          ( axi_tx_advance           ),  
  .rx_sop              ( axi_rx_sop               ),  
  .rx_data_id          ( axi_rx_data_id           ),  
  .rx_word_count       ( axi_rx_word_count        ),  
  .rx_app_data         ( axi_rx_app_data          ),          
  .rx_valid            ( axi_rx_valid             ),  
  .rx_crc_corrupted    ( axi_rx_crc_corrupted     )); 



slink_generic_tx_router #(
  //parameters
  .NUM_CHANNELS       ( 3         ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH )
) u_slink_generic_tx_router (
  .clk                 ( link_clk             ),   
  .reset               ( link_reset           ),   
  .enable              ( 1'b1                 ),  //What is best way to connect?
  .tx_sop_ch           ( {int_tx_sop,
                          apb_tx_sop,
                          axi_tx_sop}         ),  
  .tx_data_id_ch       ( {int_tx_data_id,
                          apb_tx_data_id,
                          axi_tx_data_id}     ),  
  .tx_word_count_ch    ( {int_tx_word_count,
                          apb_tx_word_count,
                          axi_tx_word_count}  ),  
  .tx_app_data_ch      ( {int_tx_app_data,
                          apb_tx_app_data,
                          axi_tx_app_data}    ),          
  .tx_advance_ch       ( {int_tx_advance,
                          apb_tx_advance,
                          axi_tx_advance}     ),  
  .tx_sop              ( tx_sop               ),  
  .tx_data_id          ( tx_data_id           ),  
  .tx_word_count       ( tx_word_count        ),  
  .tx_app_data         ( tx_app_data          ),    
  .tx_advance          ( tx_advance           )); 



slink_generic_rx_router #(
  //parameters
  .NUM_CHANNELS       ( 3         ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH )
) u_slink_generic_rx_router (
  .clk                 ( link_clk                 ),  
  .reset               ( link_reset               ),  
  .rx_sop              ( rx_sop                   ),  
  .rx_data_id          ( rx_data_id               ),  
  .rx_word_count       ( rx_word_count            ),  
  .rx_app_data         ( rx_app_data              ),             
  .rx_valid            ( rx_valid                 ),  
  .rx_crc_corrupted    ( rx_crc_corrupted         ),  
  .swi_ch_sp_min       ( {8'h10,
                          8'h10,
                          8'h10}                  ),  //input -  [(NUM_CHANNELS*8)-1:0]      
  .swi_ch_sp_max       ( {8'h10,
                          8'h10,
                          8'h10}                  ),  //input -  [(NUM_CHANNELS*8)-1:0]      
  .swi_ch_lp_min       ( {8'h30,
                          8'h20,
                          8'h40}                  ),  //input -  [(NUM_CHANNELS*8)-1:0]      
  .swi_ch_lp_max       ( {8'h3f,
                          8'h2f,
                          8'h5f}                  ),  //input -  [(NUM_CHANNELS*8)-1:0]      
  .rx_sop_ch           ( {int_rx_sop,
                          apb_rx_sop,
                          axi_rx_sop}             ),  
  .rx_data_id_ch       ( {int_rx_data_id,
                          apb_rx_data_id,
                          axi_rx_data_id}         ),  
  .rx_word_count_ch    ( {int_rx_word_count,
                          apb_rx_word_count,
                          axi_rx_word_count}      ),  
  .rx_app_data_ch      ( {int_rx_app_data,
                          apb_rx_app_data,
                          axi_rx_app_data}        ),      
  .rx_valid_ch         ( {int_rx_valid,
                          apb_rx_valid,
                          axi_rx_valid}           ),  
  .rx_crc_corrupted_ch ( {int_rx_crc_corrupted,
                          apb_rx_crc_corrupted,
                          axi_rx_crc_corrupted}   )); 



slink_generic_pstate_ctrl u_slink_generic_pstate_ctrl (
  .refclk                ( refclk_scan            ),         
  .refclk_reset          ( por_reset_refclk_scan  ),         
  .enable                ( swi_pstate_ctrl_enable ),        
  .link_clk              ( link_clk               ),  
  .link_clk_reset        ( link_reset             ),  
  .link_active           ( tx_sop                 ),  //
  .in_px_state           ( in_px_state ||
                           in_reset_state         ),
  .swi_1us_tick_count    ( swi_tick_1us           ),      
  .swi_inactivity_count  ( swi_inactivity_count   ),      
  .swi_pstate_req        ( swi_pstate_req         ),      
  .p1_req                ( p1_req                 ),       
  .p2_req                ( p2_req                 ),       
  .p3_req                ( p3_req                 )); 



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
  .slink_enable                ( ~por_reset_refclk_scan       ),  
  .por_reset                   ( por_reset_refclk_scan        ),
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
  .interrupt                   ( link_interrupt               ),  
  .p1_req                      ( p1_req                       ),  
  .p2_req                      ( p2_req                       ),  
  .p3_req                      ( p3_req                       ),  
  .in_px_state                 ( in_px_state                  ),  
  .in_reset_state              ( in_reset_state               ),  
  .slink_gpio_reset_n_oen      ( slink_gpio_reset_n_oen       ),  
  .slink_gpio_reset_n          ( slink_gpio_reset_n           ),  
  .slink_gpio_wake_n_oen       ( slink_gpio_wake_n_oen        ),  
  .slink_gpio_wake_n           ( slink_gpio_wake_n            ),  
  .refclk                      ( refclk_scan                  ),  
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
  .core_scan_clk     ( core_scan_clk          ),
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

module slink_bist #(
  parameter TX_APP_DATA_WIDTH  = 32,
  parameter RX_APP_DATA_WIDTH  = 32
)(
  input  wire                         core_scan_mode,
  input  wire                         core_scan_clk,
  input  wire                         core_scan_asyncrst_ctrl,

  input  wire                         link_clk,
  input  wire                         link_clk_reset,
  
  input  wire                         apb_clk,
  input  wire                         apb_reset,
  input  wire [7:0]                   apb_paddr,
  input  wire                         apb_pwrite,
  input  wire                         apb_psel,
  input  wire                         apb_penable,
  input  wire [31:0]                  apb_pwdata,
  output wire [31:0]                  apb_prdata,
  output wire                         apb_pready,
  output wire                         apb_pslverr,
  
  output wire                         bist_active,
  
  output reg                          tx_sop,
  output reg  [7:0]                   tx_data_id,
  output reg  [15:0]                  tx_word_count,
  output reg  [TX_APP_DATA_WIDTH-1:0] tx_app_data,
  input  wire                         tx_advance,
  
  input  wire                         rx_sop,
  input  wire [7:0]                   rx_data_id,
  input  wire [15:0]                  rx_word_count,
  input  wire [RX_APP_DATA_WIDTH-1:0] rx_app_data,
  input  wire                         rx_valid

);


wire          swi_swreset;
wire          swi_bist_tx_en;
wire          swi_bist_rx_en;
wire          swi_bist_reset;
wire          swi_bist_active;
wire          swi_disable_clkgate;
wire  [3:0]   swi_bist_mode_payload;
wire          swi_bist_mode_wc;
wire          swi_bist_mode_di;
wire  [15:0]  swi_bist_wc_min;
wire  [15:0]  swi_bist_wc_max;
wire  [7:0]   swi_bist_di_min;
wire  [7:0]   swi_bist_di_max;
wire          bist_locked;
wire          bist_unrecover;
wire  [15:0]  bist_errors;




wire apb_clk_scan;
slink_clock_mux u_slink_clock_mux_apb_clk (
  .clk0    ( apb_clk            ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( apb_clk_scan       )); 

wire apb_reset_scan;
slink_reset_sync u_slink_reset_sync_apb_reset (
  .clk           ( apb_clk_scan             ),      
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),      
  .reset_in      ( apb_reset                ),      
  .reset_out     ( apb_reset_scan           )); 


wire link_clk_scan;
slink_clock_mux u_slink_clock_mux_link_clk (
  .clk0    ( link_clk           ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( link_clk_scan      )); 

wire swreset_scan;
slink_reset_sync u_slink_reset_sync_swreset (
  .clk           ( apb_clk_scan             ),      
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),      
  .reset_in      ( link_clk_reset ||
                   swi_swreset              ),      
  .reset_out     ( swreset_scan             )); 


wire link_clk_gated;
slink_clock_gate u_slink_clock_gate (
  .clk_in            ( link_clk_scan        ),  
  .reset             ( swreset_scan         ),  
  .core_scan_mode    ( core_scan_mode       ),        
  .enable            ( swi_bist_tx_en ||
                       swi_bist_rx_en       ),             
  .disable_clkgate   ( swi_disable_clkgate  ),             
  .clk_out           ( link_clk_gated       )); 

slink_demet_reset u_slink_demet_reset_bist_active (
  .clk     ( link_clk_scan      ),     
  .reset   ( swreset_scan       ),     
  .sig_in  ( swi_bist_active    ),     
  .sig_out ( bist_active        )); 



slink_bist_tx #(
  //parameters
  .APP_DATA_WIDTH     ( TX_APP_DATA_WIDTH )
) u_slink_bist_tx (
  .clk                       ( link_clk_gated             ),    
  .reset                     ( swreset_scan               ),    
  .swi_bist_en               ( swi_bist_tx_en             ),    
  .swi_bist_reset            ( swi_bist_reset             ),    
  .swi_bist_mode_payload     ( swi_bist_mode_payload      ),        
  .swi_bist_mode_wc          ( swi_bist_mode_wc           ),    
  .swi_bist_wc_min           ( swi_bist_wc_min            ),         
  .swi_bist_wc_max           ( swi_bist_wc_max            ),         
  .swi_bist_mode_di          ( swi_bist_mode_di           ),    
  .swi_bist_di_min           ( swi_bist_di_min            ),        
  .swi_bist_di_max           ( swi_bist_di_max            ),      
  .swi_bist_seed             ( 32'd1 ),  
  .sop                       ( tx_sop                     ), 
  .data_id                   ( tx_data_id                 ), 
  .word_count                ( tx_word_count              ), 
  .app_data                  ( tx_app_data                ),          
  .advance                   ( tx_advance                 ));


slink_bist_rx #(
  //parameters
  .APP_DATA_WIDTH     ( RX_APP_DATA_WIDTH )
) u_slink_bist_rx (
  .clk                       ( link_clk_gated             ),  
  .reset                     ( swreset_scan               ),  
  .swi_bist_en               ( swi_bist_rx_en             ),  
  .swi_bist_reset            ( swi_bist_reset             ),  
  .swi_bist_mode_payload     ( swi_bist_mode_payload      ),  
  .swi_bist_mode_wc          ( swi_bist_mode_wc           ),  
  .swi_bist_wc_min           ( swi_bist_wc_min            ),  
  .swi_bist_wc_max           ( swi_bist_wc_max            ),  
  .swi_bist_mode_di          ( swi_bist_mode_di           ),  
  .swi_bist_di_min           ( swi_bist_di_min            ),  
  .swi_bist_di_max           ( swi_bist_di_max            ),  
  .bist_errors               ( bist_errors                ),     
  .bist_locked               ( bist_locked                ),  
  .bist_unrec                ( bist_unrecover             ),
  .sop                       ( rx_sop                     ),  
  .data_id                   ( rx_data_id                 ),  
  .word_count                ( rx_word_count              ),  
  .app_data                  ( rx_app_data                ),               
  .valid                     ( rx_valid                   )); 


slink_bist_regs_top u_slink_bist_regs_top (
  .swi_swreset             ( swi_swreset              ),  
  .swi_bist_tx_en          ( swi_bist_tx_en           ), 
  .swi_bist_rx_en          ( swi_bist_rx_en           ), 
  .swi_bist_reset          ( swi_bist_reset           ),  
  .swi_bist_active         ( swi_bist_active          ),
  .swi_disable_clkgate     ( swi_disable_clkgate      ),  
  .swi_bist_mode_payload   ( swi_bist_mode_payload    ),   
  .swi_bist_mode_wc        ( swi_bist_mode_wc         ),  
  .swi_bist_mode_di        ( swi_bist_mode_di         ),  
  .swi_bist_wc_min         ( swi_bist_wc_min          ),    
  .swi_bist_wc_max         ( swi_bist_wc_max          ),    
  .swi_bist_di_min         ( swi_bist_di_min          ),   
  .swi_bist_di_max         ( swi_bist_di_max          ),   
  .bist_locked             ( bist_locked              ),  
  .bist_unrecover          ( bist_unrecover           ),  
  .bist_errors             ( bist_errors              ),    
  .debug_bus_ctrl_status   (                          ),        
  .RegReset                ( apb_reset_scan           ),  
  .RegClk                  ( apb_clk_scan             ),  
  .PSEL                    ( apb_psel                 ),  
  .PENABLE                 ( apb_penable              ),  
  .PWRITE                  ( apb_pwrite               ),  
  .PSLVERR                 ( apb_pslverr              ),  
  .PREADY                  ( apb_pready               ),  
  .PADDR                   ( apb_paddr                ),  
  .PWDATA                  ( apb_pwdata               ),  
  .PRDATA                  ( apb_prdata               )); 

endmodule

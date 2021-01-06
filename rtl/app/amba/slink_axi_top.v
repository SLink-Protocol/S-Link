module slink_axi_top #(
  parameter   AXI_ADDR_WIDTH          = 32,       //8/16/24/32/40/48/56/64 (I hope to be retired by the time we need 128)
  parameter   AXI_DATA_WIDTH          = 64,       //32/64/128/256/512/1024
  parameter   DATA_CH_APP_DEPTH       = 16,
  parameter   ADDR_CH_APP_DEPTH       = 4,
  
  parameter   TX_APP_DATA_WIDTH       = 32,
  parameter   RX_APP_DATA_WIDTH       = 32
)(
  input  wire                           axi_clk,
  input  wire                           axi_reset,
  
  //--------------------------------------
  // AXI Target
  //--------------------------------------
  input  wire [7:0]                     tgt_awid,
  input  wire [AXI_ADDR_WIDTH-1:0]      tgt_awaddr,
  input  wire [7:0]                     tgt_awlen,
  input  wire [2:0]                     tgt_awsize,
  input  wire [1:0]                     tgt_awburst,
  input  wire [1:0]                     tgt_awlock,
  input  wire [3:0]                     tgt_awcache,
  input  wire [2:0]                     tgt_awprot,
  input  wire [3:0]                     tgt_awqos,
  input  wire [3:0]                     tgt_awregion,
  input  wire                           tgt_awvalid,
  output wire                           tgt_awready,
  
  input  wire [7:0]                     tgt_wid,
  input  wire [AXI_DATA_WIDTH-1:0]      tgt_wdata,
  input  wire [(AXI_DATA_WIDTH/8)-1:0]  tgt_wstrb,
  input  wire                           tgt_wlast,
  input  wire                           tgt_wvalid,
  output wire                           tgt_wready,
  
  output wire [7:0]                     tgt_bid,
  output wire [1:0]                     tgt_bresp,
  output wire                           tgt_bvalid,
  input  wire                           tgt_bready,
  
  input  wire [7:0]                     tgt_arid,
  input  wire [AXI_ADDR_WIDTH-1:0]      tgt_araddr,
  input  wire [7:0]                     tgt_arlen,
  input  wire [2:0]                     tgt_arsize,
  input  wire [1:0]                     tgt_arburst,
  input  wire [1:0]                     tgt_arlock,
  input  wire [3:0]                     tgt_arcache,
  input  wire [2:0]                     tgt_arprot,
  input  wire [3:0]                     tgt_arqos,
  input  wire [3:0]                     tgt_arregion,
  input  wire                           tgt_arvalid,
  output wire                           tgt_arready,
  
  output wire [7:0]                     tgt_rid,
  output wire [AXI_DATA_WIDTH-1:0]      tgt_rdata,
  output wire [1:0]                     tgt_rresp,
  output wire                           tgt_rlast,
  output wire                           tgt_rvalid,
  input  wire                           tgt_rready,
  
  //--------------------------------------
  // AXI Initiator
  //--------------------------------------
  output wire [7:0]                     ini_awid,
  output wire [AXI_ADDR_WIDTH-1:0]      ini_awaddr,
  output wire [7:0]                     ini_awlen,
  output wire [2:0]                     ini_awsize,
  output wire [1:0]                     ini_awburst,
  output wire [1:0]                     ini_awlock,
  output wire [3:0]                     ini_awcache,
  output wire [2:0]                     ini_awprot,
  output wire [3:0]                     ini_awqos,
  output wire [3:0]                     ini_awregion,
  output wire                           ini_awvalid,
  input  wire                           ini_awready,
  
  output wire [7:0]                     ini_wid,
  output wire [AXI_DATA_WIDTH-1:0]      ini_wdata,
  output wire [(AXI_DATA_WIDTH/8)-1:0]  ini_wstrb,
  output wire                           ini_wlast,
  output wire                           ini_wvalid,
  input  wire                           ini_wready,
  
  input  wire [7:0]                     ini_bid,
  input  wire [1:0]                     ini_bresp,
  input  wire                           ini_bvalid,
  output wire                           ini_bready,
  
  output wire [7:0]                     ini_arid,
  output wire [AXI_ADDR_WIDTH-1:0]      ini_araddr,
  output wire [7:0]                     ini_arlen,
  output wire [2:0]                     ini_arsize,
  output wire [1:0]                     ini_arburst,
  output wire [1:0]                     ini_arlock,
  output wire [3:0]                     ini_arcache,
  output wire [2:0]                     ini_arprot,
  output wire [3:0]                     ini_arqos,
  output wire [3:0]                     ini_arregion,
  output wire                           ini_arvalid,
  input  wire                           ini_arready,
  
  input  wire [7:0]                     ini_rid,
  input  wire [AXI_DATA_WIDTH-1:0]      ini_rdata,
  input  wire [1:0]                     ini_rresp,
  input  wire                           ini_rlast,
  input  wire                           ini_rvalid,
  output wire                           ini_rready,

  
  //--------------------------------------
  // Controls
  //--------------------------------------
  input  wire                           enable,
  
  input  wire [7:0]                     swi_aw_cr_id,
  input  wire [7:0]                     swi_aw_crack_id, 
  input  wire [7:0]                     swi_aw_ack_id,
  input  wire [7:0]                     swi_aw_nack_id,
  input  wire [7:0]                     swi_aw_data_id,
  
  input  wire [7:0]                     swi_w_cr_id,
  input  wire [7:0]                     swi_w_crack_id, 
  input  wire [7:0]                     swi_w_ack_id,
  input  wire [7:0]                     swi_w_nack_id,
  input  wire [7:0]                     swi_w_data_id,
  
  input  wire [7:0]                     swi_b_cr_id,
  input  wire [7:0]                     swi_b_crack_id, 
  input  wire [7:0]                     swi_b_ack_id,
  input  wire [7:0]                     swi_b_nack_id,
  input  wire [7:0]                     swi_b_data_id,
  
  input  wire [7:0]                     swi_ar_cr_id,
  input  wire [7:0]                     swi_ar_crack_id, 
  input  wire [7:0]                     swi_ar_ack_id,
  input  wire [7:0]                     swi_ar_nack_id,
  input  wire [7:0]                     swi_ar_data_id,
  
  input  wire [7:0]                     swi_r_cr_id,
  input  wire [7:0]                     swi_r_crack_id, 
  input  wire [7:0]                     swi_r_ack_id,
  input  wire [7:0]                     swi_r_nack_id,
  input  wire [7:0]                     swi_r_data_id,
  
  //--------------------------------------
  // Link Layer
  //--------------------------------------
  input  wire                           link_clk,
  input  wire                           link_reset,
  
  output wire                           tx_sop,
  output wire [7:0]                     tx_data_id,
  output wire [15:0]                    tx_word_count,
  output wire [TX_APP_DATA_WIDTH-1:0]   tx_app_data,
  input  wire                           tx_advance,
  
  input  wire                           rx_sop,
  input  wire [7:0]                     rx_data_id,
  input  wire [15:0]                    rx_word_count,
  input  wire [RX_APP_DATA_WIDTH-1:0]   rx_app_data,
  input  wire                           rx_valid,
  input  wire                           rx_crc_corrupted


);



localparam  WDATA_CHANNEL_WIDTH     = 1 + 8 + AXI_DATA_WIDTH + (AXI_DATA_WIDTH/8);      //W channel is always larger than R/B due to WSTRB's
localparam  RDATA_CHANNEL_WIDTH     = 1 + 8 + AXI_DATA_WIDTH + 2;
localparam  ADDR_CHANNEL_WIDTH      = 38 + AXI_ADDR_WIDTH;                              //AW/AR are same size
localparam  B_CHANNEL_WIDTH         = 10;

localparam  [15:0] AW_PKT_WC   = 5 + (AXI_ADDR_WIDTH/8);
localparam  [15:0] WSTRB_WC    = AXI_DATA_WIDTH == 8   ? 1 :
                                 AXI_DATA_WIDTH == 16  ? 1 :
                                 AXI_DATA_WIDTH == 32  ? 1 :
                                 AXI_DATA_WIDTH == 64  ? 1 :
                                 AXI_DATA_WIDTH == 128 ? 2 :
                                 AXI_DATA_WIDTH == 256 ? 4 :
                                 AXI_DATA_WIDTH == 512 ? 8 : 16;
localparam  [15:0] W_PKT_WC    = 2 + (AXI_DATA_WIDTH/8) + WSTRB_WC;
localparam  [15:0] B_PKT_WC    = 2;
localparam  [15:0] AR_PKT_WC   = 5 + (AXI_ADDR_WIDTH/8);
localparam  [15:0] R_PKT_WC    = 2 + (AXI_DATA_WIDTH/8);




//------------------------------------------
// ADDR Write Channel
//------------------------------------------
wire                           aw_tx_sop;
wire [7:0]                     aw_tx_data_id;
wire [15:0]                    aw_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]   aw_tx_app_data;
wire                           aw_tx_advance;

wire                           aw_rx_sop;
wire [7:0]                     aw_rx_data_id;
wire [15:0]                    aw_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]   aw_rx_app_data;
wire                           aw_rx_valid;
wire                           aw_rx_crc_corrupted;

wire                           aw_a2l_valid;
wire                           aw_a2l_ready;
wire [ADDR_CHANNEL_WIDTH-1:0]  aw_a2l_data;

wire                           aw_l2a_valid;
wire                           aw_l2a_accept;
wire [ADDR_CHANNEL_WIDTH-1:0]  aw_l2a_data;

assign aw_a2l_data  = {tgt_awaddr,
                       tgt_awregion,
                       tgt_awqos,
                       tgt_awprot,
                       tgt_awcache,
                       tgt_awlock,
                       tgt_awburst,
                       tgt_awsize,
                       tgt_awlen,
                       tgt_awid};
assign tgt_awready  = aw_a2l_ready;

assign aw_a2l_valid = tgt_awvalid;


assign ini_awvalid  = aw_l2a_valid;
assign ini_awaddr   = aw_l2a_data[38+AXI_ADDR_WIDTH-1:38];
assign ini_awregion = aw_l2a_data[37:34];
assign ini_awqos    = aw_l2a_data[33:30];
assign ini_awprot   = aw_l2a_data[29:27];
assign ini_awcache  = aw_l2a_data[26:23];
assign ini_awlock   = aw_l2a_data[22:21];
assign ini_awburst  = aw_l2a_data[20:19];
assign ini_awsize   = aw_l2a_data[18:16];
assign ini_awlen    = aw_l2a_data[15: 8];
assign ini_awid     = aw_l2a_data[ 7: 0];

assign aw_l2a_accept= ini_awready;

slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( ADDR_CHANNEL_WIDTH      ),
  .A2L_DEPTH          ( ADDR_CH_APP_DEPTH       ),
  .L2A_DATA_WIDTH     ( ADDR_CHANNEL_WIDTH      ),
  .L2A_DEPTH          ( ADDR_CH_APP_DEPTH       ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       ),
  .USE_HARDCODED_DTWC ( 1                       )
) u_slink_generic_fc_sm_AW_CHANNEL (
  .app_clk             ( axi_clk              ),       
  .app_reset           ( axi_reset            ),       
  .enable              ( enable               ),       
  .swi_cr_id           ( swi_aw_cr_id         ),  
  .swi_crack_id        ( swi_aw_crack_id      ),  
  .swi_ack_id          ( swi_aw_ack_id        ),  
  .swi_nack_id         ( swi_aw_nack_id       ),  
  .swi_data_id         ( swi_aw_data_id       ),  
  .swi_word_count      ( AW_PKT_WC            ),  
  .a2l_valid           ( aw_a2l_valid         ),  
  .a2l_ready           ( aw_a2l_ready         ),  
  .a2l_data            ( aw_a2l_data          ),  
  .l2a_valid           ( aw_l2a_valid         ),  
  .l2a_accept          ( aw_l2a_accept        ),  
  .l2a_data            ( aw_l2a_data          ),  
  .tx_fifo_empty       (                      ),  //output - 1              
  .rx_fifo_empty       (                      ),  //output - 1              
  .link_clk            ( link_clk             ),          
  .link_reset          ( link_reset           ),          
  .nack_sent           (                      ),  //output - 1              
  .nack_seen           (                      ),  //output - 1              
  .tx_sop              ( aw_tx_sop            ),  
  .tx_data_id          ( aw_tx_data_id        ),  
  .tx_word_count       ( aw_tx_word_count     ),  
  .tx_app_data         ( aw_tx_app_data       ),               
  .tx_advance          ( aw_tx_advance        ),  
  .rx_sop              ( aw_rx_sop            ),  
  .rx_data_id          ( aw_rx_data_id        ),  
  .rx_word_count       ( aw_rx_word_count     ),  
  .rx_app_data         ( aw_rx_app_data       ),           
  .rx_valid            ( aw_rx_valid          ),  
  .rx_crc_corrupted    ( aw_rx_crc_corrupted  )); 



//------------------------------------------
// Write Data Channel
//------------------------------------------
wire                           w_tx_sop;
wire [7:0]                     w_tx_data_id;
wire [15:0]                    w_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]   w_tx_app_data;
wire                           w_tx_advance;

wire                           w_rx_sop;
wire [7:0]                     w_rx_data_id;
wire [15:0]                    w_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]   w_rx_app_data;
wire                           w_rx_valid;
wire                           w_rx_crc_corrupted;

wire                           w_a2l_valid;
wire                           w_a2l_ready;
wire [WDATA_CHANNEL_WIDTH-1:0] w_a2l_data;

wire                           w_l2a_valid;
wire                           w_l2a_accept;
wire [WDATA_CHANNEL_WIDTH-1:0] w_l2a_data;

assign w_a2l_data   = {tgt_wdata,
                       tgt_wstrb,
                       tgt_wlast,
                       tgt_wid};
assign tgt_wready   = w_a2l_ready;

assign w_a2l_valid  = tgt_wvalid;

assign ini_wvalid   = w_l2a_valid;
//assign ini_wdata    = w_l2a_data[9+(AXI_DATA_WIDTH/8)+1+AXI_DATA_WIDTH-1 : 9+(AXI_DATA_WIDTH/8)];
assign ini_wdata    = w_l2a_data[80 : 17];
assign ini_wstrb    = w_l2a_data[9+(AXI_DATA_WIDTH/8)-1:9];
assign ini_wlast    = w_l2a_data[8];
assign ini_wid      = w_l2a_data[7:0];

assign w_l2a_accept = ini_wready;

slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( WDATA_CHANNEL_WIDTH     ),
  .A2L_DEPTH          ( DATA_CH_APP_DEPTH       ),
  .L2A_DATA_WIDTH     ( WDATA_CHANNEL_WIDTH     ),
  .L2A_DEPTH          ( DATA_CH_APP_DEPTH       ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       ),
  .USE_HARDCODED_DTWC ( 1                       )
) u_slink_generic_fc_sm_W_CHANNEL (
  .app_clk             ( axi_clk              ),       
  .app_reset           ( axi_reset            ),       
  .enable              ( enable               ),       
  .swi_cr_id           ( swi_w_cr_id          ),  
  .swi_crack_id        ( swi_w_crack_id       ),  
  .swi_ack_id          ( swi_w_ack_id         ),  
  .swi_nack_id         ( swi_w_nack_id        ),  
  .swi_data_id         ( swi_w_data_id        ),  
  .swi_word_count      ( W_PKT_WC             ),  
  .a2l_valid           ( w_a2l_valid          ),  
  .a2l_ready           ( w_a2l_ready          ),  
  .a2l_data            ( w_a2l_data           ),  
  .l2a_valid           ( w_l2a_valid          ),  
  .l2a_accept          ( w_l2a_accept         ),  
  .l2a_data            ( w_l2a_data           ),  
  .tx_fifo_empty       (                      ),  //output - 1              
  .rx_fifo_empty       (                      ),  //output - 1              
  .link_clk            ( link_clk             ),          
  .link_reset          ( link_reset           ),          
  .nack_sent           (                      ),  //output - 1              
  .nack_seen           (                      ),  //output - 1              
  .tx_sop              ( w_tx_sop             ),  
  .tx_data_id          ( w_tx_data_id         ),  
  .tx_word_count       ( w_tx_word_count      ),  
  .tx_app_data         ( w_tx_app_data        ),              
  .tx_advance          ( w_tx_advance         ),  
  .rx_sop              ( w_rx_sop             ),  
  .rx_data_id          ( w_rx_data_id         ),  
  .rx_word_count       ( w_rx_word_count      ),  
  .rx_app_data         ( w_rx_app_data        ),          
  .rx_valid            ( w_rx_valid           ),  
  .rx_crc_corrupted    ( w_rx_crc_corrupted   )); 



//------------------------------------------
// Write Response Channel
//------------------------------------------
wire                           b_tx_sop;
wire [7:0]                     b_tx_data_id;
wire [15:0]                    b_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]   b_tx_app_data;
wire                           b_tx_advance;

wire                           b_rx_sop;
wire [7:0]                     b_rx_data_id;
wire [15:0]                    b_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]   b_rx_app_data;
wire                           b_rx_valid;
wire                           b_rx_crc_corrupted;

wire                           b_a2l_valid;
wire                           b_a2l_ready;
wire [B_CHANNEL_WIDTH-1:0]     b_a2l_data;

wire                           b_l2a_valid;
wire                           b_l2a_accept;
wire [B_CHANNEL_WIDTH-1:0]     b_l2a_data;

assign b_a2l_data   = {ini_bresp,
                       ini_bid};
assign ini_bready   = b_a2l_ready;

assign b_a2l_valid  = ini_bvalid;


assign tgt_bvalid   = b_l2a_valid;
assign tgt_bresp    = b_l2a_data[9:8];
assign tgt_bid      = b_l2a_data[7:0];

assign b_l2a_accept = tgt_bready;

slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( B_CHANNEL_WIDTH         ),
  .A2L_DEPTH          ( ADDR_CH_APP_DEPTH       ),
  .L2A_DATA_WIDTH     ( B_CHANNEL_WIDTH         ),
  .L2A_DEPTH          ( ADDR_CH_APP_DEPTH       ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       ),
  .USE_HARDCODED_DTWC ( 1                       )
) u_slink_generic_fc_sm_B_CHANNEL (
  .app_clk             ( axi_clk              ),       
  .app_reset           ( axi_reset            ),       
  .enable              ( enable               ),       
  .swi_cr_id           ( swi_b_cr_id          ),  
  .swi_crack_id        ( swi_b_crack_id       ),  
  .swi_ack_id          ( swi_b_ack_id         ),  
  .swi_nack_id         ( swi_b_nack_id        ),  
  .swi_data_id         ( swi_b_data_id        ),  
  .swi_word_count      ( B_PKT_WC             ),  
  .a2l_valid           ( b_a2l_valid          ),  
  .a2l_ready           ( b_a2l_ready          ),  
  .a2l_data            ( b_a2l_data           ),  
  .l2a_valid           ( b_l2a_valid          ),  
  .l2a_accept          ( b_l2a_accept         ),  
  .l2a_data            ( b_l2a_data           ),  
  .tx_fifo_empty       (                      ),  //output - 1              
  .rx_fifo_empty       (                      ),  //output - 1              
  .link_clk            ( link_clk             ),          
  .link_reset          ( link_reset           ),          
  .nack_sent           (                      ),  //output - 1              
  .nack_seen           (                      ),  //output - 1              
  .tx_sop              ( b_tx_sop             ),  
  .tx_data_id          ( b_tx_data_id         ),  
  .tx_word_count       ( b_tx_word_count      ),  
  .tx_app_data         ( b_tx_app_data        ),              
  .tx_advance          ( b_tx_advance         ),  
  .rx_sop              ( b_rx_sop             ),  
  .rx_data_id          ( b_rx_data_id         ),  
  .rx_word_count       ( b_rx_word_count      ),  
  .rx_app_data         ( b_rx_app_data        ),          
  .rx_valid            ( b_rx_valid           ),  
  .rx_crc_corrupted    ( b_rx_crc_corrupted   )); 




//------------------------------------------
// ADDR Read Channel
//------------------------------------------
wire                           ar_tx_sop;
wire [7:0]                     ar_tx_data_id;
wire [15:0]                    ar_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]   ar_tx_app_data;
wire                           ar_tx_advance;

wire                           ar_rx_sop;
wire [7:0]                     ar_rx_data_id;
wire [15:0]                    ar_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]   ar_rx_app_data;
wire                           ar_rx_valid;
wire                           ar_rx_crc_corrupted;

wire                           ar_a2l_valid;
wire                           ar_a2l_ready;
wire [ADDR_CHANNEL_WIDTH-1:0]  ar_a2l_data;

wire                           ar_l2a_valid;
wire                           ar_l2a_accept;
wire [ADDR_CHANNEL_WIDTH-1:0]  ar_l2a_data;

assign ar_a2l_data  = {tgt_araddr,
                       tgt_arregion,
                       tgt_arqos,
                       tgt_arprot,
                       tgt_arcache,
                       tgt_arlock,
                       tgt_arburst,
                       tgt_arsize,
                       tgt_arlen,
                       tgt_arid};
assign tgt_arready  = ar_a2l_ready;

assign ar_a2l_valid = tgt_arvalid;


assign ini_arvalid  = ar_l2a_valid;
assign ini_araddr   = ar_l2a_data[38+AXI_ADDR_WIDTH-1:38];
assign ini_arregion = ar_l2a_data[37:34];
assign ini_arqos    = ar_l2a_data[33:30];
assign ini_arprot   = ar_l2a_data[29:27];
assign ini_arcache  = ar_l2a_data[26:23];
assign ini_arlock   = ar_l2a_data[22:21];
assign ini_arburst  = ar_l2a_data[20:19];
assign ini_arsize   = ar_l2a_data[18:16];
assign ini_arlen    = ar_l2a_data[15: 8];
assign ini_arid     = ar_l2a_data[ 7: 0];

assign ar_l2a_accept= ini_arready;

slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( ADDR_CHANNEL_WIDTH      ),
  .A2L_DEPTH          ( ADDR_CH_APP_DEPTH       ),
  .L2A_DATA_WIDTH     ( ADDR_CHANNEL_WIDTH      ),
  .L2A_DEPTH          ( ADDR_CH_APP_DEPTH       ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       ),
  .USE_HARDCODED_DTWC ( 1                       )
) u_slink_generic_fc_sm_AR_CHANNEL (
  .app_clk             ( axi_clk              ),       
  .app_reset           ( axi_reset            ),       
  .enable              ( enable               ),       
  .swi_cr_id           ( swi_ar_cr_id         ),  
  .swi_crack_id        ( swi_ar_crack_id      ),  
  .swi_ack_id          ( swi_ar_ack_id        ),  
  .swi_nack_id         ( swi_ar_nack_id       ),  
  .swi_data_id         ( swi_ar_data_id       ),  
  .swi_word_count      ( AR_PKT_WC            ),  
  .a2l_valid           ( ar_a2l_valid         ),  
  .a2l_ready           ( ar_a2l_ready         ),  
  .a2l_data            ( ar_a2l_data          ),  
  .l2a_valid           ( ar_l2a_valid         ),  
  .l2a_accept          ( ar_l2a_accept        ),  
  .l2a_data            ( ar_l2a_data          ),  
  .tx_fifo_empty       (                      ),  //output - 1              
  .rx_fifo_empty       (                      ),  //output - 1              
  .link_clk            ( link_clk             ),          
  .link_reset          ( link_reset           ),          
  .nack_sent           (                      ),  //output - 1              
  .nack_seen           (                      ),  //output - 1              
  .tx_sop              ( ar_tx_sop            ),  
  .tx_data_id          ( ar_tx_data_id        ),  
  .tx_word_count       ( ar_tx_word_count     ),  
  .tx_app_data         ( ar_tx_app_data       ),               
  .tx_advance          ( ar_tx_advance        ),  
  .rx_sop              ( ar_rx_sop            ),  
  .rx_data_id          ( ar_rx_data_id        ),  
  .rx_word_count       ( ar_rx_word_count     ),  
  .rx_app_data         ( ar_rx_app_data       ),           
  .rx_valid            ( ar_rx_valid          ),  
  .rx_crc_corrupted    ( ar_rx_crc_corrupted  )); 



//------------------------------------------
// READ Data Channel
//------------------------------------------
wire                           r_tx_sop;
wire [7:0]                     r_tx_data_id;
wire [15:0]                    r_tx_word_count;
wire [TX_APP_DATA_WIDTH-1:0]   r_tx_app_data;
wire                           r_tx_advance;

wire                           r_rx_sop;
wire [7:0]                     r_rx_data_id;
wire [15:0]                    r_rx_word_count;
wire [RX_APP_DATA_WIDTH-1:0]   r_rx_app_data;
wire                           r_rx_valid;
wire                           r_rx_crc_corrupted;

wire                           r_a2l_valid;
wire                           r_a2l_ready;
wire [RDATA_CHANNEL_WIDTH-1:0] r_a2l_data;

wire                           r_l2a_valid;
wire                           r_l2a_accept;
wire [RDATA_CHANNEL_WIDTH-1:0] r_l2a_data;


assign r_a2l_data   = {ini_rdata,
                       ini_rlast,
                       ini_rresp,
                       ini_rid};
assign ini_rready   = r_a2l_ready;

assign r_a2l_valid  = ini_rvalid;

assign tgt_rvalid   = r_l2a_valid;
assign tgt_rdata    = r_l2a_data[RDATA_CHANNEL_WIDTH-1:11];
assign tgt_rlast    = r_l2a_data[10];
assign tgt_rresp    = r_l2a_data[ 9: 8];
assign tgt_rid      = r_l2a_data[ 7: 0];

assign r_l2a_accept = tgt_rready;

slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( RDATA_CHANNEL_WIDTH     ),
  .A2L_DEPTH          ( DATA_CH_APP_DEPTH       ),
  .L2A_DATA_WIDTH     ( RDATA_CHANNEL_WIDTH     ),
  .L2A_DEPTH          ( DATA_CH_APP_DEPTH       ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       ),
  .USE_HARDCODED_DTWC ( 1                       )
) u_slink_generic_fc_sm_R_CHANNEL (
  .app_clk             ( axi_clk              ),       
  .app_reset           ( axi_reset            ),       
  .enable              ( enable               ),       
  .swi_cr_id           ( swi_r_cr_id          ),  
  .swi_crack_id        ( swi_r_crack_id       ),  
  .swi_ack_id          ( swi_r_ack_id         ),  
  .swi_nack_id         ( swi_r_nack_id        ),  
  .swi_data_id         ( swi_r_data_id        ),  
  .swi_word_count      ( R_PKT_WC             ),  
  .a2l_valid           ( r_a2l_valid          ),  
  .a2l_ready           ( r_a2l_ready          ),  
  .a2l_data            ( r_a2l_data           ),  
  .l2a_valid           ( r_l2a_valid          ),  
  .l2a_accept          ( r_l2a_accept         ),  
  .l2a_data            ( r_l2a_data           ),  
  .tx_fifo_empty       (                      ),  //output - 1              
  .rx_fifo_empty       (                      ),  //output - 1              
  .link_clk            ( link_clk             ),          
  .link_reset          ( link_reset           ),          
  .nack_sent           (                      ),  //output - 1              
  .nack_seen           (                      ),  //output - 1              
  .tx_sop              ( r_tx_sop             ),  
  .tx_data_id          ( r_tx_data_id         ),  
  .tx_word_count       ( r_tx_word_count      ),  
  .tx_app_data         ( r_tx_app_data        ),              
  .tx_advance          ( r_tx_advance         ),  
  .rx_sop              ( r_rx_sop             ),  
  .rx_data_id          ( r_rx_data_id         ),  
  .rx_word_count       ( r_rx_word_count      ),  
  .rx_app_data         ( r_rx_app_data        ),          
  .rx_valid            ( r_rx_valid           ),  
  .rx_crc_corrupted    ( r_rx_crc_corrupted   )); 





//------------------------------------------
// Routing
//------------------------------------------
slink_generic_tx_router #(
  //parameters
  .NUM_CHANNELS       ( 5                 ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH )
) u_slink_generic_tx_router (
  .clk                 ( link_clk             ),     
  .reset               ( link_reset           ),     
  .enable              ( enable               ),  
  .tx_sop_ch           ( {r_tx_sop,
                          ar_tx_sop,
                          b_tx_sop,
                          w_tx_sop,
                          aw_tx_sop}          ),  
  .tx_data_id_ch       ( {r_tx_data_id,
                          ar_tx_data_id,
                          b_tx_data_id,
                          w_tx_data_id,
                          aw_tx_data_id}      ),  
  .tx_word_count_ch    ( {r_tx_word_count,
                          ar_tx_word_count,
                          b_tx_word_count,
                          w_tx_word_count,
                          aw_tx_word_count}   ),  
  .tx_app_data_ch      ( {r_tx_app_data,
                          ar_tx_app_data,
                          b_tx_app_data,
                          w_tx_app_data,
                          aw_tx_app_data}     ),    
  .tx_advance_ch       ( {r_tx_advance,
                          ar_tx_advance,
                          b_tx_advance,
                          w_tx_advance,
                          aw_tx_advance}      ),  
  .tx_sop              ( tx_sop               ),  
  .tx_data_id          ( tx_data_id           ),  
  .tx_word_count       ( tx_word_count        ),  
  .tx_app_data         ( tx_app_data          ),       
  .tx_advance          ( tx_advance           )); 


slink_generic_rx_router #(
  //parameters
  .NUM_CHANNELS       ( 5                 ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH )
) u_slink_generic_rx_router (
  .clk                 ( link_clk             ),     
  .reset               ( link_reset           ),     
  .rx_sop              ( rx_sop               ),  
  .rx_data_id          ( rx_data_id           ),  
  .rx_word_count       ( rx_word_count        ),  
  .rx_app_data         ( rx_app_data          ),       
  .rx_valid            ( rx_valid             ),  
  .rx_crc_corrupted    ( rx_crc_corrupted     ),  
  .swi_ch_sp_min       ( {5{8'h10}}           ),  //input -  [(NUM_CHANNELS*8)-1:0]              
  .swi_ch_sp_max       ( {5{8'h10}}           ),  //input -  [(NUM_CHANNELS*8)-1:0]              
  .swi_ch_lp_min       ( {swi_r_cr_id,
                          swi_ar_cr_id,
                          swi_b_cr_id,
                          swi_w_cr_id,
                          swi_aw_cr_id}       ),  //input -  [(NUM_CHANNELS*8)-1:0]              
  .swi_ch_lp_max       ( {swi_r_data_id,
                          swi_ar_data_id,
                          swi_b_data_id,
                          swi_w_data_id,
                          swi_aw_data_id}     ),  //input -  [(NUM_CHANNELS*8)-1:0]              
  .rx_sop_ch           ( {r_rx_sop,
                          ar_rx_sop,
                          b_rx_sop,
                          w_rx_sop,
                          aw_rx_sop}          ),  
  .rx_data_id_ch       ( {r_rx_data_id,
                          ar_rx_data_id,
                          b_rx_data_id,
                          w_rx_data_id,
                          aw_rx_data_id}      ),  
  .rx_word_count_ch    ( {r_rx_word_count,
                          ar_rx_word_count,
                          b_rx_word_count,
                          w_rx_word_count,
                          aw_rx_word_count}   ),  
  .rx_app_data_ch      ( {r_rx_app_data,
                          ar_rx_app_data,
                          b_rx_app_data,
                          w_rx_app_data,
                          aw_rx_app_data}     ),  
  .rx_valid_ch         ( {r_rx_valid,
                          ar_rx_valid,
                          b_rx_valid,
                          w_rx_valid,
                          aw_rx_valid}        ),  
  .rx_crc_corrupted_ch ( {r_rx_crc_corrupted,
                          ar_rx_crc_corrupted,
                          b_rx_crc_corrupted,
                          w_rx_crc_corrupted,
                          aw_rx_crc_corrupted})); 

endmodule

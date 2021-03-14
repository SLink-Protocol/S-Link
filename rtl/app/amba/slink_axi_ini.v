module slink_axi_ini #(
  parameter   AXI_ADDR_WIDTH          = 32,       //8/16/24/32/40/48/56/64 (I hope to be retired by the time we need 128)
  parameter   AXI_DATA_WIDTH          = 64,       //32/64/128/256/512/1024
  parameter   APPLICATION_DEPTH       = 8,
  parameter   SEPARATE_AXI_CHANNELS   = 0,        //0 - One main main for all transmit traffic, 1 - Each channel has it's own traffic path
  
  parameter   TX_APP_DATA_WIDTH       = 32,
  parameter   RX_APP_DATA_WIDTH       = 32,
  
  
  parameter   AW_PKT_DT               = 8'h20,
  parameter   W_PKT_DT                = 8'h21,
  parameter   B_PKT_DT                = 8'h22,
  parameter   AR_PKT_DT               = 8'h23,
  parameter   R_PKT_DT                = 8'h24
)(
  input  wire                           axi_clk,
  input  wire                           axi_reset,
  
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
  
  input  wire                           enable,
  
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

localparam  DATA_CHANNEL_WIDTH      = 1 + 8 + AXI_DATA_WIDTH + (AXI_DATA_WIDTH/8);      //W channel is always larger than R/B due to WSTRB's
localparam  ADDR_CHANNEL_WIDTH      = 38 + AXI_ADDR_WIDTH;                              //AW/AR are same size

localparam  AW_PKT_WC   = 6 + (AXI_ADDR_WIDTH/8);
localparam  WSTRB_WC    = AXI_DATA_WIDTH == 8   ? 1 :
                          AXI_DATA_WIDTH == 16  ? 1 :
                          AXI_DATA_WIDTH == 32  ? 1 :
                          AXI_DATA_WIDTH == 64  ? 1 :
                          AXI_DATA_WIDTH == 128 ? 2 :
                          AXI_DATA_WIDTH == 256 ? 4 :
                          AXI_DATA_WIDTH == 512 ? 8 : 16;
localparam  W_PKT_WC    = 2 + (AXI_DATA_WIDTH/8) + WSTRB_WC;
localparam  B_PKT_WC    = 3;
localparam  AR_PKT_WC   = 6 + (AXI_ADDR_WIDTH/8);
localparam  R_PKT_WC    = 2 + (AXI_DATA_WIDTH/8);


generate
  if(SEPARATE_AXI_CHANNELS == 0) begin : gen_single_axi_channel
    localparam  DATA_IS_LARGER          = DATA_CHANNEL_WIDTH >= ADDR_CHANNEL_WIDTH;
    
    //Swapped from Target
    localparam  L2A_FC_DATA_PATH_WIDTH  = DATA_IS_LARGER ? DATA_CHANNEL_WIDTH + 24 :
                                                           ADDR_CHANNEL_WIDTH + 24;
    localparam  A2L_FC_DATA_PATH_WIDTH  = 2 + 8 + AXI_DATA_WIDTH + 24;                           //Read Data channel
  
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         ini_b_data;
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         ini_r_data;
  
    wire                                      a2l_valid;
    wire                                      a2l_ready;
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         a2l_data;
    
    wire                                      l2a_valid;
    wire                                      l2a_accept;
    wire [L2A_FC_DATA_PATH_WIDTH-1:0]         l2a_data;

    assign ini_b_data   = {{(A2L_FC_DATA_PATH_WIDTH-24-8-2){1'b0}},
                           ini_bresp,
                           ini_bid,
                           B_PKT_WC[15:0],
                           B_PKT_DT}; 
    
    assign ini_r_data   = {ini_rdata,
                           ini_rlast,
                           ini_rresp,
                           ini_rid,
                           B_PKT_WC[15:0],
                           B_PKT_DT}; 
    
    
    assign ini_bready   = a2l_ready;
    assign ini_rready   = a2l_ready & ~ini_bready;
    
    assign a2l_data     = (ini_bready && ini_bvalid) ? ini_b_data :
                          (ini_rready && ini_rvalid) ? ini_r_data  :{A2L_FC_DATA_PATH_WIDTH{1'b0}};
    assign a2l_valid    = (ini_bready && ini_bvalid) ||
                          (ini_rready && ini_rvalid);
    
    

    assign ini_awid     = l2a_data[31:24];
    assign ini_awlen    = l2a_data[39:32];
    assign ini_awsize   = l2a_data[42:40];
    assign ini_awburst  = l2a_data[44:43];
    assign ini_awlock   = l2a_data[46:45];
    assign ini_awcache  = l2a_data[50:47];
    assign ini_awprot   = l2a_data[53:51];
    assign ini_awqos    = l2a_data[57:54];
    assign ini_awregion = l2a_data[61:58];
    assign ini_awaddr   = l2a_data[62+AXI_ADDR_WIDTH:62];
    assign ini_awvalid  = (l2a_data[ 7: 0] == AW_PKT_DT) && l2a_valid;
    
    
    assign ini_wid      = l2a_data[31:24];
    assign ini_wlast    = l2a_data[32];
    assign ini_wstrb    = l2a_data[33+(AXI_DATA_WIDTH/8)-1:33];
    assign ini_wdata    = l2a_data[33+(AXI_DATA_WIDTH/8)+1+AXI_DATA_WIDTH-1 : 33+(AXI_DATA_WIDTH/8)];
    assign ini_wvalid   = (l2a_data[ 7: 0] == W_PKT_DT) && l2a_valid;
    
    assign ini_arid     = l2a_data[31:24];
    assign ini_arlen    = l2a_data[39:32];
    assign ini_arsize   = l2a_data[42:40];
    assign ini_arburst  = l2a_data[44:43];
    assign ini_arlock   = l2a_data[46:45];
    assign ini_arcache  = l2a_data[50:47];
    assign ini_arprot   = l2a_data[53:51];
    assign ini_arqos    = l2a_data[57:54];
    assign ini_arregion = l2a_data[61:58];
    assign ini_araddr   = l2a_data[62+AXI_ADDR_WIDTH:62];
    assign ini_arvalid  = (l2a_data[ 7: 0] == AR_PKT_DT) && l2a_valid;
    
    assign l2a_accept   = ini_awvalid ? ini_awready :
                          ini_wvalid  ? ini_wready  :
                          ini_arvalid ? ini_arready : 1'b0;
    
    slink_generic_fc_sm #(
      //parameters
      .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH       ),
      .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH       ),
      .A2L_DEPTH          ( APPLICATION_DEPTH       ),
      .A2L_DATA_WIDTH     ( A2L_FC_DATA_PATH_WIDTH  ),
      .L2A_DEPTH          ( APPLICATION_DEPTH       ),
      .L2A_DATA_WIDTH     ( L2A_FC_DATA_PATH_WIDTH  )
    ) u_slink_generic_fc_sm (
      .app_clk           ( axi_clk            ),    
      .app_reset         ( axi_reset          ),    
      .enable            ( enable             ),
          
      .swi_cr_id         ( 8'h12              ),
      .swi_crack_id      ( 8'h13              ),
      .swi_ack_id        ( 8'h10              ),
      .swi_nack_id       ( 8'h11              ),
      
      .a2l_valid         ( a2l_valid          ),  
      .a2l_ready         ( a2l_ready          ),  
      .a2l_data          ( a2l_data           ),     
      
      .l2a_valid         ( l2a_valid          ),  
      .l2a_accept        ( l2a_accept         ),  
      .l2a_data          ( l2a_data           ),  
      
      .tx_fifo_empty     ( ),
      .rx_fifo_empty     ( ),
              
      .link_clk          ( link_clk           ),  
      .link_reset        ( link_reset         ),  
      .tx_sop            ( tx_sop             ),  
      .tx_data_id        ( tx_data_id         ),  
      .tx_word_count     ( tx_word_count      ),  
      .tx_app_data       ( tx_app_data        ),  
      .tx_advance        ( tx_advance         ),  
      .rx_sop            ( rx_sop             ),  
      .rx_data_id        ( rx_data_id         ),  
      .rx_word_count     ( rx_word_count      ),  
      .rx_app_data       ( rx_app_data        ),  
      .rx_valid          ( rx_valid           ),  
      .rx_crc_corrupted  ( rx_crc_corrupted   )); 
      
  end else begin : gen_multi_axi_channel
  
  end
endgenerate

endmodule

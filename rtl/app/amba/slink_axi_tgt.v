module slink_axi_tgt #(
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

    localparam  A2L_FC_DATA_PATH_WIDTH  = DATA_IS_LARGER ? DATA_CHANNEL_WIDTH + 24 :
                                                           ADDR_CHANNEL_WIDTH + 24;
    localparam  L2A_FC_DATA_PATH_WIDTH  = 2 + 8 + AXI_DATA_WIDTH + 24;                           //Read Data channel
    
    localparam  AX_TIEOFF_LENGTH        = DATA_IS_LARGER ? DATA_CHANNEL_WIDTH-ADDR_CHANNEL_WIDTH : 0;
    localparam  W_TIEOFF_LENGTH         = DATA_IS_LARGER ? 0                                     : ADDR_CHANNEL_WIDTH-DATA_CHANNEL_WIDTH;
  
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         tgt_aw_data;
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         tgt_w_data;
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         tgt_ar_data;
  
    wire                                      a2l_valid;
    wire                                      a2l_ready;
    wire [A2L_FC_DATA_PATH_WIDTH-1:0]         a2l_data;
    
    wire                                      l2a_valid;
    wire                                      l2a_accept;
    wire [L2A_FC_DATA_PATH_WIDTH-1:0]         l2a_data;
    
    
    assign tgt_aw_data  = DATA_IS_LARGER ? 
                          {{AX_TIEOFF_LENGTH{1'b0}},
                           tgt_awaddr,
                           tgt_awregion,
                           tgt_awqos,
                           tgt_awprot,
                           tgt_awcache,
                           tgt_awlock,
                           tgt_awburst,
                           tgt_awsize,
                           tgt_awlen,
                           tgt_awid,
                           AW_PKT_WC[15:0],
                           AW_PKT_DT[7:0]} : 
                          {tgt_awaddr,
                           tgt_awregion,
                           tgt_awqos,
                           tgt_awprot,
                           tgt_awcache,
                           tgt_awlock,
                           tgt_awburst,
                           tgt_awsize,
                           tgt_awlen,
                           tgt_awid,
                           AW_PKT_WC[15:0],
                           AW_PKT_DT[7:0]};


    assign tgt_ar_data  = DATA_IS_LARGER ? 
                          {{AX_TIEOFF_LENGTH{1'b0}},
                           tgt_araddr,
                           tgt_arregion,
                           tgt_arqos,
                           tgt_arprot,
                           tgt_arcache,
                           tgt_arlock,
                           tgt_arburst,
                           tgt_arsize,
                           tgt_arlen,
                           tgt_arid,
                           AR_PKT_WC[15:0],
                           AR_PKT_DT[7:0]} : 
                          {tgt_araddr,
                           tgt_arregion,
                           tgt_arqos,
                           tgt_arprot,
                           tgt_arcache,
                           tgt_arlock,
                           tgt_arburst,
                           tgt_arsize,
                           tgt_arlen,
                           tgt_arid,
                           AR_PKT_WC,
                           AR_PKT_DT[7:0]};

    assign tgt_w_data   = DATA_IS_LARGER ?
                          {tgt_wdata,
                           tgt_wstrb,
                           tgt_wlast,
                           tgt_wid,
                           W_PKT_WC[15:0],
                           W_PKT_DT[7:0]} :
                          {{W_TIEOFF_LENGTH{1'b0}},
                           tgt_wdata,
                           tgt_wstrb,
                           tgt_wlast,
                           tgt_wid,
                           W_PKT_WC[15:0],
                           W_PKT_DT[7:0]};  
  
    assign tgt_awready  = a2l_ready;
    assign tgt_wready   = a2l_ready & ~tgt_awvalid;
    assign tgt_arready  = a2l_ready & ~tgt_awvalid & ~tgt_wvalid;

    assign a2l_data     = (tgt_awready && tgt_awvalid) ? tgt_aw_data :
                          (tgt_wready  && tgt_wvalid)  ? tgt_w_data  :
                          (tgt_arready && tgt_arvalid) ? tgt_ar_data : {A2L_FC_DATA_PATH_WIDTH{1'b0}};
    assign a2l_valid    = (tgt_awready && tgt_awvalid) ||
                          (tgt_wready  && tgt_wvalid)  ||
                          (tgt_arready && tgt_arvalid);           

    
    assign tgt_bid      = l2a_data[31:24];
    assign tgt_bresp    = l2a_data[33:32];
    assign tgt_bvalid   = (l2a_data[ 7: 0] == B_PKT_DT) && l2a_valid;
    
    assign tgt_rid      = l2a_data[31:24];
    assign tgt_rresp    = l2a_data[33:32];
    assign tgt_rlast    = l2a_data[34];
    assign tgt_rdata    = l2a_data[L2A_FC_DATA_PATH_WIDTH-1:40];
    assign tgt_rvalid   = (l2a_data[ 7: 0] == R_PKT_DT) && l2a_valid;
    
    assign l2a_accept   = tgt_bvalid ? tgt_bready :
                          tgt_rvalid ? tgt_rready : 1'b0;
    
    
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

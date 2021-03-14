

//-------------------------
// Clocks / Reset
//-------------------------
reg main_reset = 0;

reg apb_clk = 0;
reg refclk  = 0;

always #5     apb_clk <= ~apb_clk;
always #13.02 refclk  <= ~refclk;


wire [8:0]                          mst_apb_paddr;
wire                                mst_apb_pwrite;
wire                                mst_apb_psel;
wire                                mst_apb_penable;
wire [31:0]                         mst_apb_pwdata;
wire [31:0]                         mst_apb_prdata;
wire                                mst_apb_pready;
wire                                mst_apb_pslverr;

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

wire                                mst_p1_req;
wire                                mst_p2_req;
wire                                mst_p3_req;
wire                                mst_in_px_state;
wire                                mst_in_reset_state;

assign mst_p1_req = 1'b0;
assign mst_p2_req = 1'b0;
assign mst_p3_req = 1'b0;



wire [8:0]                          slv_apb_paddr;
wire                                slv_apb_pwrite;
wire                                slv_apb_psel;
wire                                slv_apb_penable;
wire [31:0]                         slv_apb_pwdata;
wire [31:0]                         slv_apb_prdata;
wire                                slv_apb_pready;
wire                                slv_apb_pslverr;

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

wire                                slv_p1_req;
wire                                slv_p2_req;
wire                                slv_p3_req;
wire                                slv_in_px_state;
wire                                slv_in_reset_state;

assign slv_p1_req = 1'b0;
assign slv_p2_req = 1'b0;
assign slv_p3_req = 1'b0;

slink_b2b_tb_wrapper #(
  //parameters
  .MST_TX_APP_DATA_WIDTH  ( MST_TX_APP_DATA_WIDTH ),
  .MST_RX_APP_DATA_WIDTH  ( MST_RX_APP_DATA_WIDTH ),
  .NUM_TX_LANES           ( NUM_TX_LANES          ),
  .NUM_RX_LANES           ( NUM_RX_LANES          ),
  .MST_PHY_DATA_WIDTH     ( MST_PHY_DATA_WIDTH    ),
  
  .SLV_TX_APP_DATA_WIDTH  ( SLV_TX_APP_DATA_WIDTH ),
  .SLV_RX_APP_DATA_WIDTH  ( SLV_RX_APP_DATA_WIDTH ),
  .SLV_PHY_DATA_WIDTH     ( SLV_PHY_DATA_WIDTH    ),
  
  .SERDES_MODE            ( SERDES_MODE           )
) u_slink_b2b_tb_wrapper (
  .main_reset              ( main_reset               ),  
  .mst_apb_clk             ( apb_clk                  ),  
  .mst_apb_reset           ( main_reset               ),  
  .mst_apb_paddr           ( mst_apb_paddr            ),  
  .mst_apb_pwrite          ( mst_apb_pwrite           ),  
  .mst_apb_psel            ( mst_apb_psel             ),  
  .mst_apb_penable         ( mst_apb_penable          ),  
  .mst_apb_pwdata          ( mst_apb_pwdata           ),  
  .mst_apb_prdata          ( mst_apb_prdata           ),  
  .mst_apb_pready          ( mst_apb_pready           ),  
  .mst_apb_pslverr         ( mst_apb_pslverr          ),  
  .mst_link_clk            ( mst_link_clk             ),  
  .mst_link_reset          ( mst_link_reset           ),  
  .mst_tx_sop              ( mst_tx_sop               ),  
  .mst_tx_data_id          ( mst_tx_data_id           ),  
  .mst_tx_word_count       ( mst_tx_word_count        ),  
  .mst_tx_app_data         ( mst_tx_app_data          ),  
  .mst_tx_advance          ( mst_tx_advance           ),  
  .mst_rx_sop              ( mst_rx_sop               ),  
  .mst_rx_data_id          ( mst_rx_data_id           ),  
  .mst_rx_word_count       ( mst_rx_word_count        ),  
  .mst_rx_app_data         ( mst_rx_app_data          ),  
  .mst_rx_valid            ( mst_rx_valid             ),  
  .mst_rx_crc_corrupted    ( mst_rx_crc_corrupted     ),  
  .mst_interrupt           ( mst_interrupt            ),  
  .mst_p1_req              ( mst_p1_req               ),  
  .mst_p2_req              ( mst_p2_req               ),  
  .mst_p3_req              ( mst_p3_req               ),  
  .mst_in_px_state         ( mst_in_px_state          ),  
  .mst_in_reset_state      ( mst_in_reset_state       ),  
  
  
  .slv_apb_clk             ( apb_clk                  ),  
  .slv_apb_reset           ( main_reset               ),  
  .slv_apb_paddr           ( slv_apb_paddr            ),  
  .slv_apb_pwrite          ( slv_apb_pwrite           ),  
  .slv_apb_psel            ( slv_apb_psel             ),  
  .slv_apb_penable         ( slv_apb_penable          ),  
  .slv_apb_pwdata          ( slv_apb_pwdata           ),  
  .slv_apb_prdata          ( slv_apb_prdata           ),  
  .slv_apb_pready          ( slv_apb_pready           ),  
  .slv_apb_pslverr         ( slv_apb_pslverr          ),  
  .slv_link_clk            ( slv_link_clk             ),
  .slv_link_reset          ( slv_link_reset           ),
  .slv_tx_sop              ( slv_tx_sop               ),  
  .slv_tx_data_id          ( slv_tx_data_id           ),  
  .slv_tx_word_count       ( slv_tx_word_count        ),  
  .slv_tx_app_data         ( slv_tx_app_data          ),  
  .slv_tx_advance          ( slv_tx_advance           ),  
  .slv_rx_sop              ( slv_rx_sop               ),  
  .slv_rx_data_id          ( slv_rx_data_id           ),  
  .slv_rx_word_count       ( slv_rx_word_count        ),  
  .slv_rx_app_data         ( slv_rx_app_data          ),  
  .slv_rx_valid            ( slv_rx_valid             ),  
  .slv_rx_crc_corrupted    ( slv_rx_crc_corrupted     ),  
  .slv_interrupt           ( slv_interrupt            ),  
  .slv_p1_req              ( slv_p1_req               ),  
  .slv_p2_req              ( slv_p2_req               ),  
  .slv_p3_req              ( slv_p3_req               ),  
  .slv_in_px_state         ( slv_in_px_state          ),  
  .slv_in_reset_state      ( slv_in_reset_state       ),  
  .refclk                  ( refclk                   )); 



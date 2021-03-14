module slink_simple_io_phy_model #(
  parameter IS_MASTER     = 1,
  parameter CLK_PER_NS    = 2,
  parameter DATA_WIDTH    = 8,
  parameter NUM_TX_LANES  = 4,
  parameter NUM_RX_LANES  = 4
)(
  input  wire                                   clk_enable,
  input  wire                                   clk_idle,
  output wire                                   clk_ready,
  inout  wire                                   clk_byteclk,
  
  output wire                                   parclk,
  
  input  wire [NUM_TX_LANES-1:0]                tx_enable,
  input  wire [(NUM_TX_LANES*DATA_WIDTH)-1:0]   tx_data,
  input  wire                                   tx_data_ctrl,
  input  wire [NUM_TX_LANES-1:0]                tx_reset,
  output wire [NUM_TX_LANES-1:0]                tx_dirdy,
  output wire [NUM_TX_LANES-1:0]                tx_ready,
  
  input  wire [NUM_RX_LANES-1:0]                rx_enable,
  output reg  [(NUM_RX_LANES*DATA_WIDTH)-1:0]   rx_data,
  output reg                                    rx_data_ctrl,
  input  wire [NUM_RX_LANES-1:0]                rx_reset,
  output wire [NUM_RX_LANES-1:0]                rx_dordy,
  output wire [NUM_RX_LANES-1:0]                rx_ready,
  
  output reg  [(NUM_TX_LANES*DATA_WIDTH)-1:0]   tx,  
  output reg                                    tx_ctrl,
  input  wire [(NUM_RX_LANES*DATA_WIDTH)-1:0]   rx,
  input  wire                                   rx_ctrl
);

wire bitclk;


serdes_clk_model #(
  //parameters
  .IS_MASTER          ( IS_MASTER   ),
  .CLK_PER_NS         ( CLK_PER_NS  )
) u_serdes_clk_model (
  .enable    ( clk_enable     ),       
  .idle      ( clk_idle       ),       
  .ready     ( clk_ready      ),         
  .bitclk    ( bitclk         )); //really a byteclk here
  
assign clk_byteclk = IS_MASTER ? bitclk : 1'bz;

assign parclk      = clk_byteclk;

// TODO CLEAN UP THESE RESETS!
always @(negedge clk_byteclk or posedge tx_reset) begin
  if(tx_reset) begin
    tx      <= {NUM_TX_LANES*DATA_WIDTH{1'b0}};
    tx_ctrl <= 1'b0;
  end else begin
    tx      <= tx_data;
    tx_ctrl <= tx_data_ctrl;
  end
end


always @(posedge clk_byteclk or posedge rx_reset) begin
  if(rx_reset) begin
    rx_data         <= {NUM_RX_LANES*DATA_WIDTH{1'b0}};
    rx_data_ctrl    <= 1'b0;  
  end else begin
    rx_data         <= rx;
    rx_data_ctrl    <= rx_ctrl;
  end
end


//temp
assign tx_ready = {NUM_TX_LANES{1'b1}};
assign rx_ready = {NUM_TX_LANES{1'b1}};

endmodule

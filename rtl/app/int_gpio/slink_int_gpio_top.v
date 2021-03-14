module slink_int_gpio_top #(
  parameter     TX_APP_DATA_WIDTH   = 128,
  parameter     RX_APP_DATA_WIDTH   = 128,
  
  //Look, to keep this simple, just make this a factor of 8 please
  //I mean really, I'm giving you all these components. Now, would you kindly
  //just keep it a factor of 8?
  parameter     NUM_INTS            = 16,
  parameter     NUM_GPIOS           = 8
)(
  input  wire                           app_clk,
  input  wire                           app_reset,
  
  //-------------------------------
  // Configs
  //-------------------------------
  input  wire                           enable,
  
  input  wire [7:0]                     swi_cr_id,
  input  wire [7:0]                     swi_crack_id, 
  input  wire [7:0]                     swi_ack_id,
  input  wire [7:0]                     swi_nack_id,
  input  wire [7:0]                     swi_data_id,
  input  wire [15:0]                    swi_word_count,
  
  output wire                           nack_sent,
  output wire                           nack_seen,

  
  //-------------------------------
  // Interrupts / GPIOs
  //-------------------------------
  input  wire [NUM_INTS-1:0]            i_interrupt,
  output wire [NUM_INTS-1:0]            o_interrupt,
  input  wire [NUM_GPIOS-1:0]           i_gpio,
  output wire [NUM_GPIOS-1:0]           o_gpio,
  
  //-------------------------------
  // Link Layer
  //-------------------------------
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


localparam A2L_DATA_WIDTH = NUM_INTS+NUM_GPIOS;
localparam L2A_DATA_WIDTH = NUM_INTS+NUM_GPIOS;

wire [A2L_DATA_WIDTH-1:0]     a2l_data;
reg                           a2l_valid;
wire                          a2l_valid_in;
wire                          a2l_ready;

wire [L2A_DATA_WIDTH-1:0]     l2a_data;
reg  [L2A_DATA_WIDTH-1:0]     l2a_data_reg;
wire                          l2a_valid;
wire                          l2a_ready;


wire                            enable_app_clk;

wire  [NUM_INTS+NUM_GPIOS-1:0]  ig_ff2;  
reg   [NUM_INTS+NUM_GPIOS-1:0]  ig_ff3; 
wire  [NUM_INTS+NUM_GPIOS-1:0]  ig_diff; 
wire                            diff_seen;

slink_demet_reset u_slink_demet_reset_enable (
  .clk     ( app_clk        ),  
  .reset   ( app_reset      ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_app_clk )); 

//------------------------
// Input side
//------------------------
slink_demet_reset u_slink_demet_reset_ints_gpios[NUM_INTS+NUM_GPIOS-1:0] (
  .clk     ( app_clk        ),  
  .reset   ( app_reset      ),  
  .sig_in  ( {i_gpio,
              i_interrupt}  ),  
  .sig_out ( ig_ff2         )); 

always @(posedge app_clk or posedge app_reset) begin
  if(app_reset) begin
    ig_ff3    <= {NUM_INTS+NUM_GPIOS{1'b0}};
    a2l_valid <= 1'b1;    //Force a send on the first one
  end else begin
    ig_ff3    <= ig_ff2;
    a2l_valid <= a2l_valid_in;
  end
end

assign ig_diff      = ig_ff2 ^ ig_ff3;
assign diff_seen    = |ig_diff;

//diff_seen check should protect against missing a transition
//when we also see the acceptance in the link layer
assign a2l_valid_in = a2l_ready && ~diff_seen ? 1'b0 : (diff_seen ? 1'b1 : a2l_valid);
assign a2l_data     = ig_ff2;

//------------------------
// Output Side
//------------------------
always @(posedge app_clk or posedge app_reset) begin
  if(app_reset) begin
    l2a_data_reg    <= {L2A_DATA_WIDTH{1'b0}};
  end else begin
    l2a_data_reg    <= l2a_valid ? l2a_data : l2a_data_reg;
  end
end

assign l2a_accept = enable_app_clk;

assign {o_gpio, o_interrupt} = l2a_data_reg;


slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( A2L_DATA_WIDTH      ),
  .A2L_DEPTH          ( 2                   ),
  .L2A_DATA_WIDTH     ( L2A_DATA_WIDTH      ),
  .L2A_DEPTH          ( 2                   ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH   ),
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH   ),
  .USE_HARDCODED_DTWC ( 1                   )
) u_slink_generic_fc_sm (
  .app_clk             ( app_clk              ),              
  .app_reset           ( app_reset            ),              
  .enable              ( enable_app_clk       ), 
  .swi_cr_id           ( swi_cr_id            ),     
  .swi_crack_id        ( swi_crack_id         ),     
  .swi_ack_id          ( swi_ack_id           ),     
  .swi_nack_id         ( swi_nack_id          ), 
  .swi_data_id         ( swi_data_id          ),     
  .swi_word_count      ( swi_word_count       ),      
  .a2l_valid           ( a2l_valid            ),  
  .a2l_ready           ( a2l_ready            ),  
  .a2l_data            ( a2l_data             ),       
  .l2a_valid           ( l2a_valid            ),  
  .l2a_accept          ( l2a_accept           ),  
  .l2a_data            ( l2a_data             ),       
  .tx_fifo_empty       ( tx_fifo_empty        ),         
  .rx_fifo_empty       ( rx_fifo_empty        ),         
  .link_clk            ( link_clk             ),   
  .link_reset          ( link_reset           ),   
  .nack_sent           ( nack_sent            ), 
  .nack_seen           ( nack_seen            ), 
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


endmodule

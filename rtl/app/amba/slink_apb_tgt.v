module slink_apb_tgt #(
  parameter       TX_APP_DATA_WIDTH     = 128,
  parameter       RX_APP_DATA_WIDTH     = 128,
  
  parameter [7:0] APB_READ_DT           = 8'h24,
  parameter [7:0] APB_READ_RSP_DT       = 8'h25,
  parameter [7:0] APB_WRITE_DT          = 8'h26,
  parameter [7:0] APB_WRITE_RSP_DT      = 8'h27
)(
  input  wire                           apb_clk,
  input  wire                           apb_reset,
  input  wire [31:0]                    apb_paddr,
  input  wire                           apb_pwrite,
  input  wire                           apb_psel,
  input  wire                           apb_penable,
  input  wire [31:0]                    apb_pwdata,
  output reg  [31:0]                    apb_prdata,
  output reg                            apb_pready,
  output reg                            apb_pslverr,

  input  wire                           enable,
  
  input  wire [7:0]                     swi_cr_id,
  input  wire [7:0]                     swi_crack_id, 
  input  wire [7:0]                     swi_ack_id,
  input  wire [7:0]                     swi_nack_id,
  
  output wire                           nack_sent,
  output wire                           nack_seen,
  output reg                            invalid_resp_pkt,
  
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

localparam  A2L_DATA_WIDTH  = 64 + 24;
localparam  L2A_DATA_WIDTH  = 33 + 24;   

localparam  [15:0] APB_READ_WC     = 4;
localparam  [15:0] APB_WRITE_WC    = 8;

localparam  IDLE        = 'd0,
            APB_READ    = 'd1,
            APB_WRITE   = 'd2,
            APB_STALL   = 'd3;


/*
Byte                [ 7: 0] | [15: 8] | [23:16] | [31:24] | [39:32] | [47:40] | [55:48] | [63:56] | [71:64]
APB READ            [               ADDR                ]
APB READ Response   [               DATA                ]  [SLVERR]
APB WRITE           [               ADDR                ]  [                DATA                ] [PSTRB??]
APB WRITE Response  [SLVERR]
*/

reg   [2:0]                     state, nstate;
wire                            enable_apb_clk;

reg   [A2L_DATA_WIDTH-1:0]      a2l_data;               
reg   [A2L_DATA_WIDTH-24-1:0]   a2l_data_dtwc_stripped; 
reg                             a2l_valid;              
wire                            a2l_ready;              

wire  [L2A_DATA_WIDTH-1:0]      l2a_data;
wire  [L2A_DATA_WIDTH-24-1:0]   l2a_data_dtwc_stripped;
wire                            l2a_valid;
reg                             l2a_accept;

wire                            read_rsp_pkt;
wire                            write_rsp_pkt;

slink_demet_reset u_slink_demet_reset_enable (
  .clk     ( apb_clk        ),  
  .reset   ( apb_reset      ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_apb_clk )); 

always @(posedge apb_clk or posedge apb_reset) begin
  if(apb_reset) begin
    state         <= IDLE;
  end else begin
    state         <= nstate;
  end
end

assign write_rsp_pkt          = l2a_data[7:0] == APB_WRITE_RSP_DT;
assign read_rsp_pkt           = l2a_data[7:0] == APB_READ_RSP_DT;
assign l2a_data_dtwc_stripped = l2a_data[L2A_DATA_WIDTH-1:24];


always @(*) begin
  nstate                  = state;
  apb_prdata              = 32'd0;
  apb_pready              = 1'b0;
  apb_pslverr             = 1'b0;
  a2l_data_dtwc_stripped  = {A2L_DATA_WIDTH-24{1'b0}};
  a2l_data                = {A2L_DATA_WIDTH{1'b0}};
  a2l_valid               = 1'b0;
  
  l2a_accept              = 1'b0;
  invalid_resp_pkt        = 1'b0;
  
  case(state)
    //---------------------------------
    IDLE : begin
      if(enable_apb_clk) begin
        if(apb_psel && ~apb_penable) begin    //should I add an error for psel and enable?
          if(apb_pwrite) begin
            a2l_data_dtwc_stripped  = {apb_pwdata, apb_paddr};
            a2l_data                = {a2l_data_dtwc_stripped, APB_WRITE_WC, APB_WRITE_DT};
            a2l_valid               = 1'b1;
            nstate                  = a2l_ready ? APB_WRITE : APB_STALL;
          end else begin
            a2l_data_dtwc_stripped  = {32'd0, apb_paddr};
            a2l_data                = {a2l_data_dtwc_stripped, APB_READ_WC, APB_READ_DT};
            a2l_valid               = 1'b1;
            nstate                  = a2l_ready ? APB_READ  : APB_STALL;
          end
        end
      end
    end
    
    //---------------------------------
    //If a2l_ready is not asserted just wait here until we are good to go
    APB_STALL : begin
      if(apb_pwrite) begin
        a2l_data_dtwc_stripped  = {apb_pwdata, apb_paddr};
        a2l_data                = {a2l_data_dtwc_stripped, APB_WRITE_WC, APB_WRITE_DT};
        a2l_valid               = 1'b1;
        nstate                  = a2l_ready ? APB_WRITE : APB_STALL;
      end else begin
        a2l_data_dtwc_stripped  = {32'd0, apb_paddr};
        a2l_data                = {a2l_data_dtwc_stripped, APB_READ_WC, APB_READ_DT};
        a2l_valid               = 1'b1;
        nstate                  = a2l_ready ? APB_READ  : APB_STALL;
      end
    end
    
    //---------------------------------
    APB_WRITE : begin
      if(l2a_valid) begin
        if(write_rsp_pkt) begin
          apb_pready      = 1'b1;
          apb_pslverr     = l2a_data_dtwc_stripped[0];
          l2a_accept      = 1'b1;
          nstate          = IDLE;
        end else begin
          invalid_resp_pkt= 1'b1;
        end
      end
    end
    
    
    //---------------------------------
    APB_READ : begin
      if(l2a_valid) begin
        if(read_rsp_pkt) begin
          apb_pready      = 1'b1;
          apb_prdata      = l2a_data_dtwc_stripped[31:0];
          apb_pslverr     = l2a_data_dtwc_stripped[32];
          l2a_accept      = 1'b1;
          nstate          = IDLE;
        end else begin
          invalid_resp_pkt= 1'b1;
        end
      end
    end
    
    default : begin
      nstate              = IDLE;
    end
    
  endcase
  
  if(~enable_apb_clk) begin
    nstate                = IDLE;
  end
end



slink_generic_fc_sm #(
  //parameters
  .A2L_DATA_WIDTH     ( A2L_DATA_WIDTH     ),
  .A2L_DEPTH          ( 2                  ),
  .L2A_DATA_WIDTH     ( L2A_DATA_WIDTH     ),
  .L2A_DEPTH          ( 2                  ),  //see if 2 works
  .TX_APP_DATA_WIDTH  ( TX_APP_DATA_WIDTH  ),
  .RX_APP_DATA_WIDTH  ( RX_APP_DATA_WIDTH  )
  
) u_slink_generic_fc_sm (
  .app_clk             ( apb_clk              ),            
  .app_reset           ( apb_reset            ),            
  .enable              ( enable               ),         
  .swi_cr_id           ( swi_cr_id            ),
  .swi_crack_id        ( swi_crack_id         ),
  .swi_ack_id          ( swi_ack_id           ),
  .swi_nack_id         ( swi_nack_id          ), 
  .swi_data_id         ( 8'hff                ),
  .swi_word_count      ( 16'd0                ),
  .a2l_valid           ( a2l_valid            ),  
  .a2l_ready           ( a2l_ready            ),  
  .a2l_data            ( a2l_data             ),      
  .l2a_valid           ( l2a_valid            ),  
  .l2a_accept          ( l2a_accept           ),  
  .l2a_data            ( l2a_data             ),      
  .tx_fifo_empty       (                      ),  
  .rx_fifo_empty       (                      ),  
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

module slink_apb_ini #(
  parameter       TX_APP_DATA_WIDTH     = 128,
  parameter       RX_APP_DATA_WIDTH     = 128,
  
  parameter [7:0] APB_READ_DT           = 8'h30,
  parameter [7:0] APB_READ_RSP_DT       = 8'h31,
  parameter [7:0] APB_WRITE_DT          = 8'h32,
  parameter [7:0] APB_WRITE_RSP_DT      = 8'h33
)(
  input  wire                           apb_clk,
  input  wire                           apb_reset,
  output reg  [31:0]                    apb_paddr,
  output reg                            apb_pwrite,
  output reg                            apb_psel,
  output reg                            apb_penable,
  output reg  [31:0]                    apb_pwdata,
  input  wire [31:0]                    apb_prdata,
  input  wire                           apb_pready,
  input  wire                           apb_pslverr,

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

//localparam  A2L_DATA_WIDTH  = 64 + 24;
localparam  A2L_DATA_WIDTH  = 33 + 24;
localparam  L2A_DATA_WIDTH  = 64 + 24;   

localparam  [15:0] APB_READ_RSP_WC     = 5;
localparam  [15:0] APB_WRITE_RSP_WC    = 1;

localparam  IDLE        = 'd0,
            APB_READ    = 'd1,
            APB_WRITE   = 'd2,
            HOLD_STATE  = 'd3;

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
reg                             a2l_valid;
wire                            a2l_ready;

wire  [L2A_DATA_WIDTH-1:0]      l2a_data;
wire  [L2A_DATA_WIDTH-24-1:0]   l2a_data_dtwc_stripped;
wire                            l2a_valid;
reg                             l2a_accept;

wire                            read_data_pkt;
wire                            write_data_pkt;
reg                             was_write, was_write_in;

reg   [31:0]                    apb_prdata_reg, apb_prdata_reg_in;
reg                             apb_pslverr_reg, apb_pslverr_reg_in;


slink_demet_reset u_slink_demet_reset_enable (
  .clk     ( apb_clk        ),  
  .reset   ( apb_reset      ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_apb_clk )); 

always @(posedge apb_clk or posedge apb_reset) begin
  if(apb_reset) begin
    state           <= IDLE;
    was_write       <= 1'b0;
    apb_prdata_reg  <= 32'd0;
    apb_pslverr_reg <= 1'b0;
  end else begin
    state           <= nstate;
    was_write       <= was_write_in;
    apb_prdata_reg  <= apb_prdata_reg_in;
    apb_pslverr_reg <= apb_pslverr_reg_in;
  end
end

assign write_data_pkt         = l2a_data[7:0] == APB_WRITE_DT;
assign read_data_pkt          = l2a_data[7:0] == APB_READ_DT;
assign l2a_data_dtwc_stripped = l2a_data[L2A_DATA_WIDTH-1:24];

always @(*) begin
  nstate                = IDLE;
  apb_psel              = 1'b0;
  apb_penable           = 1'b0;
  apb_pwrite            = 1'b0;
  apb_paddr             = 32'd0;
  apb_pwdata            = 32'd0;
  l2a_accept            = 1'b0;
  a2l_data              = {A2L_DATA_WIDTH{1'b0}};
  a2l_valid             = 1'b0;
  was_write_in          = was_write;
  apb_prdata_reg_in     = apb_prdata_reg;
  apb_pslverr_reg_in    = apb_pslverr_reg;
  
  case(state)
    //---------------------------------
    IDLE : begin
      if(enable_apb_clk) begin
        if(l2a_valid) begin
          if(write_data_pkt) begin
            apb_psel          = 1'b1;
            apb_paddr         = l2a_data_dtwc_stripped[31:0];
            apb_pwdata        = l2a_data_dtwc_stripped[63:32];
            apb_pwrite        = 1'b1;
            nstate            = APB_WRITE;
          end else if(read_data_pkt) begin
            apb_psel          = 1'b1;
            apb_paddr         = l2a_data_dtwc_stripped[31:0];
            nstate            = APB_READ;
          end else begin
            //ADD ERROR
          end
        end
      end
    end
    
    //---------------------------------
    APB_WRITE : begin
      apb_psel                = 1'b1;
      apb_paddr               = l2a_data_dtwc_stripped[31:0];
      apb_pwdata              = l2a_data_dtwc_stripped[63:32];
      apb_pwrite              = 1'b1;
      apb_penable             = 1'b1;
      was_write_in            = 1'b1;
      
      if(apb_pready) begin    //should it check pslverr here?
        l2a_accept            = 1'b1;
        if(a2l_ready) begin
          a2l_data            = {{A2L_DATA_WIDTH-25{1'b0}}, apb_pslverr, APB_WRITE_RSP_WC, APB_WRITE_RSP_DT};
          a2l_valid           = 1'b1;
          nstate              = IDLE;
        end else begin
          apb_pslverr_reg_in  = apb_pslverr;
          nstate              = HOLD_STATE;
        end
      end
    end
    
    //---------------------------------
    APB_READ : begin
      apb_psel                = 1'b1;
      apb_paddr               = l2a_data_dtwc_stripped[31:0];
      apb_pwrite              = 1'b0;
      apb_penable             = 1'b1;
      was_write_in            = 1'b0;
      
      if(apb_pready) begin    //should it check pslverr here?
        l2a_accept            = 1'b1;
        if(a2l_ready) begin
          a2l_data            = {{A2L_DATA_WIDTH-57{1'b0}}, apb_pslverr, apb_prdata, APB_READ_RSP_WC, APB_READ_RSP_DT};
          a2l_valid           = 1'b1;
          nstate              = IDLE;
        end else begin
          apb_pslverr_reg_in  = apb_pslverr;
          apb_prdata_reg_in   = apb_prdata;
          nstate              = HOLD_STATE;
        end
      end
    end
    
    //HOLD STATE for cases where we need to stop the transaction
    //but can't send the data back
    HOLD_STATE : begin
      if(a2l_ready) begin
        if(was_write) begin
          a2l_data            = {{A2L_DATA_WIDTH-25{1'b0}}, apb_pslverr_reg, APB_WRITE_RSP_WC, APB_WRITE_RSP_DT};
          a2l_valid           = 1'b1;
        end else begin
          a2l_data            = {{A2L_DATA_WIDTH-57{1'b0}}, apb_pslverr_reg, apb_prdata_reg, APB_READ_RSP_WC, APB_READ_RSP_DT};
          a2l_valid           = 1'b1;
        end
        nstate                = IDLE;
      end
    end
    
    
    default : begin
      nstate        = IDLE;
    end
  endcase
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
  .swi_cr_id           ( 8'h12                ),
  .swi_crack_id        ( 8'h13                ),
  .swi_ack_id          ( 8'h10                ),
  .swi_nack_id         ( 8'h11                ),          
  .a2l_valid           ( a2l_valid            ),  
  .a2l_ready           ( a2l_ready            ),  
  .a2l_data            ( a2l_data             ),      
  .l2a_valid           ( l2a_valid            ),  
  .l2a_accept          ( l2a_accept           ),  
  .l2a_data            ( l2a_data             ),      
  .tx_fifo_empty       (                      ),  //connme          
  .rx_fifo_empty       (                      ),  //connme          
  .link_clk            ( link_clk             ),          
  .link_reset          ( link_reset           ),          
  .nack_sent           (                      ),  //connme       
  .nack_seen           (                      ),  //connme       
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

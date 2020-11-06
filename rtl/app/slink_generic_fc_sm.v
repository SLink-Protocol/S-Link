module slink_generic_fc_sm #(
  //-----------------------------
  // App -> Link layer
  //-----------------------------
  parameter     A2L_DATA_WIDTH    = 32,         //Width of the data entry (includes WC+DT)
  parameter     A2L_DEPTH         = 8,          //Number of FIFO entires
  parameter     A2L_ADDR_WDITH    = $clog2(A2L_DEPTH),
  
  parameter     TX_APP_DATA_WIDTH = 64,
  parameter     RX_APP_DATA_WIDTH = 64
)(
  input  wire                           app_clk,
  input  wire                           app_reset,
  
  input  wire                           enable,
  
  input  wire                           a2l_valid,
  output wire                           a2l_ready,
  input  wire [A2L_DATA_WIDTH-1:0]      a2l_data,
  
  input  wire                           link_clk,
  input  wire                           link_reset,
  
  output reg                            tx_sop,
  output reg  [7:0]                     tx_data_id,
  output reg  [15:0]                    tx_word_count,
  output reg  [TX_APP_DATA_WIDTH-1:0]   tx_app_data,
  input  wire                           tx_advance,
  
  input  wire                           rx_sop,
  input  wire [7:0]                     rx_data_id,
  input  wire [15:0]                    rx_word_count,
  input  wire [RX_APP_DATA_WIDTH-1:0]   rx_app_data,
  input  wire                           rx_valid,
  input  wire                           rx_crc_corrupted
);

localparam  GENERIC_ACK   = 8'h10,
            GENERIC_NACK  = 8'h11,
            GENERIC_SCRD  = 8'h12,
            GENERIC_CR_ACK= 8'h15;

localparam  IDLE              = 'd0,
            SEND_CREDITS1     = 'd1,
            SEND_CREDITS2     = 'd2,
            LINK_IDLE         = 'd3,
            LINK_DATA         = 'd4,
            SEND_ACK          = 'd5,
            SEND_NACK         = 'd6;
            

reg   [2:0]     state, nstate;
wire            enable_link_clk;
reg             recv_credits, recv_credits_in;
reg             recv_resp_credits, recv_resp_credits_in;
reg   [7:0]     fe_credit_max, fe_credit_max_in;
wire  [7:0]     ne_credit_max;
reg   [7:0]     exp_pkt_num;
wire  [7:0]     exp_pkt_num_in;
wire            exp_pkt_seen;
wire            exp_pkt_not_seen;
reg   [7:0]     last_good_pkt;
wire  [7:0]     last_good_pkt_in;
reg   [7:0]     last_ack_pkt_sent;
reg   [7:0]     last_ack_pkt_sent_in;
reg             send_ack_req;
reg             send_ack_req_in;
reg             send_nack_req;
wire            send_nack_req_in;
reg   [7:0]     nack_pkt_num;
wire  [7:0]     nack_pkt_num_in;

wire            credit_pkt_recv;
wire            resp_credit_pkt_recv;
wire            valid_rx_pkt;
wire            valid_rx_pkt_crc_err;

wire                      link_ack_update;
wire [A2L_ADDR_WDITH:0]   link_ack_addr;
wire [A2L_ADDR_WDITH:0]   link_cur_addr;
wire [7:0]                link_cur_addr_8bit;
wire [A2L_DATA_WIDTH-1:0] link_data_replay;
wire                      link_valid_replay;
reg                       link_advance_replay;


reg             tx_sop_in;
reg   [7:0]     tx_data_id_in;
reg   [15:0]    tx_word_count_in;
reg   [TX_APP_DATA_WIDTH-1:0] tx_app_data_in;

slink_demet_reset u_slink_demet_reset_enable_link_clk (
  .clk     ( link_clk       ),  
  .reset   ( link_reset     ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_link_clk)); 


always @(posedge link_clk or posedge link_reset) begin
  if(link_reset) begin
    state               <= IDLE;
    recv_credits        <= 1'b0;
    fe_credit_max       <= 8'd0;
    recv_resp_credits   <= 1'b0;
    exp_pkt_num         <= 8'd0;
    last_good_pkt       <= 8'd0;
    last_ack_pkt_sent   <= 8'd0;
    send_ack_req        <= 1'b0;
    send_nack_req       <= 1'b0;
    nack_pkt_num        <= 8'd0;
    tx_sop              <= 1'b0;
    tx_data_id          <= 8'd0;
    tx_word_count       <= 16'd0;
    tx_app_data         <= {TX_APP_DATA_WIDTH{1'b0}};
  end else begin
    state               <= nstate;
    recv_credits        <= recv_credits_in;
    fe_credit_max       <= fe_credit_max_in;
    recv_resp_credits   <= recv_resp_credits_in;
    exp_pkt_num         <= (state == IDLE) ? 8'd0 : exp_pkt_num_in;
    last_good_pkt       <= (state == IDLE) ? 8'd0 : last_good_pkt_in;
    last_ack_pkt_sent   <= (state == IDLE) ? 8'd0 : last_ack_pkt_sent_in;
    send_ack_req        <= (state == IDLE) ? 1'b0 : send_ack_req_in;
    send_nack_req       <= (state == IDLE) ? 1'b0 : send_nack_req_in;
    nack_pkt_num        <= (state == IDLE) ? 8'd0 : nack_pkt_num_in;
    
    tx_sop              <= tx_sop_in;
    tx_data_id          <= tx_data_id_in;
    tx_word_count       <= tx_word_count_in;
    tx_app_data         <= tx_app_data_in;
  end
end




slink_generic_fc_replay #(
  //parameters
  .A2L_DATA_WIDTH     ( A2L_DATA_WIDTH  ),
  .A2L_DEPTH          ( A2L_DEPTH       )
) u_slink_generic_fc_replay (
  .app_clk             ( app_clk              ),   
  .app_reset           ( app_reset            ),   
  .link_clk            ( link_clk             ),  
  .link_reset          ( link_reset           ),  
  .enable              ( enable               ),  
  .a2l_valid           ( a2l_valid            ),  
  .a2l_ready           ( a2l_ready            ),  
  .a2l_data            ( a2l_data             ),  
  .link_ack_update     ( link_ack_update      ),  
  .link_ack_addr       ( link_ack_addr        ),  
  .link_cur_addr       ( link_cur_addr        ),  
  .link_data           ( link_data_replay     ),  
  .link_valid          ( link_valid_replay    ),  
  .link_advance        ( link_advance_replay  )); 


assign link_ack_update      = valid_rx_pkt && (rx_data_id == GENERIC_ACK);
assign link_ack_addr        = rx_word_count[7:0];

assign link_cur_addr_8bit   = {{(7-A2L_ADDR_WDITH){1'b0}}, link_cur_addr};

assign ne_credit_max        = {{(7-A2L_ADDR_WDITH){1'b0}}, {A2L_ADDR_WDITH+1{1'b1}}};

assign valid_rx_pkt         = rx_sop && rx_valid && ~rx_crc_corrupted;
assign valid_rx_pkt_crc_err = rx_sop && rx_valid &&  rx_crc_corrupted;

assign credit_pkt_recv      = valid_rx_pkt && (rx_data_id == GENERIC_SCRD);
assign resp_credit_pkt_recv = valid_rx_pkt && (rx_data_id == GENERIC_CR_ACK);




always @(*) begin
  nstate                    = state;
  recv_credits_in           = recv_credits;
  recv_resp_credits_in      = recv_resp_credits;
  fe_credit_max_in          = fe_credit_max;
  tx_sop_in                 = tx_sop;       
  tx_data_id_in             = tx_data_id;   
  tx_word_count_in          = tx_word_count;
  tx_app_data_in            = tx_app_data;  
  link_advance_replay       = 1'b0;
  last_ack_pkt_sent_in      = last_ack_pkt_sent;
  send_ack_req_in           = send_ack_req ? 1'b1 : (exp_pkt_seen);
  
  case(state)
    //--------------------------------------------
    IDLE : begin
      recv_credits_in       = 1'b0;
      fe_credit_max_in      = 8'd0;
      recv_resp_credits_in  = 1'b0;
      if(enable_link_clk) begin
        nstate              = SEND_CREDITS1;
      end
    end
    
    //--------------------------------------------
    // We will send the number of credits we have and wait for
    // a packet that describes the number of credits on the other side
    //--------------------------------------------
    SEND_CREDITS1 : begin
      tx_sop_in             = 1'b1;
      tx_data_id_in         = GENERIC_SCRD;
      tx_word_count_in      = {8'd0, ne_credit_max};
      tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
      
      if(resp_credit_pkt_recv) begin
        recv_resp_credits_in= 1'b1;
      end 
      
      if(credit_pkt_recv) begin
        recv_credits_in     = 1'b1;
        fe_credit_max_in    = rx_word_count[7:0];
      end
      
      if(tx_advance) begin
        if(recv_credits_in) begin
          tx_sop_in         = 1'b1;
          tx_data_id_in     = GENERIC_CR_ACK;
          tx_word_count_in  = {8'd0, ne_credit_max};
          tx_app_data_in    = {TX_APP_DATA_WIDTH{1'b0}};
          nstate            = SEND_CREDITS2;
        end
      end
    end
    
    //--------------------------------------------
    SEND_CREDITS2 : begin
      tx_sop_in             = 1'b1;
      tx_data_id_in         = GENERIC_CR_ACK;
      tx_word_count_in      = {8'd0, ne_credit_max};
      tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
      
      if(resp_credit_pkt_recv) begin
        recv_resp_credits_in= 1'b1;
      end 
      
      if(tx_advance) begin
        if(recv_resp_credits_in) begin
          tx_sop_in         = 1'b0;
          tx_data_id_in     = 8'd0;
          tx_word_count_in  = 16'd0;
          tx_app_data_in    = {TX_APP_DATA_WIDTH{1'b0}};
          nstate            = LINK_IDLE;
        end
      end
    end
    
    //--------------------------------------------
    // Priority is NACK -> ACK -> DATA
    // 
    LINK_IDLE : begin
      if(link_valid_replay) begin
        tx_sop_in             = 1'b1;
        tx_data_id_in         = link_data_replay[ 7: 0];
        tx_word_count_in      = link_data_replay[15: 8];
        tx_app_data_in        = {{TX_APP_DATA_WIDTH-A2L_DATA_WIDTH-32{1'b0}}, link_data_replay[A2L_DATA_WIDTH-1:0], link_cur_addr_8bit};
        link_advance_replay   = 1'b1;     //go ahead and clear this one
        nstate                = LINK_DATA;
      end
      
      if(send_ack_req_in) begin
        //Capture the most recent good packet and send that as part of the ACK
        last_ack_pkt_sent_in  = last_good_pkt_in;
        tx_sop_in             = 1'b1;
        tx_data_id_in         = GENERIC_ACK;
        tx_word_count_in      = {8'd0, last_ack_pkt_sent_in};
        tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
        nstate                = SEND_ACK;
      end
      
    end
    
    //--------------------------------------------
    // 
    LINK_DATA : begin
      if(tx_advance) begin
        if(~send_ack_req_in && link_valid_replay) begin
          tx_sop_in             = 1'b1;
          tx_data_id_in         = link_data_replay[ 7: 0];
          tx_word_count_in      = link_data_replay[15: 8];
          tx_app_data_in        = {{TX_APP_DATA_WIDTH-A2L_DATA_WIDTH-32{1'b0}}, link_data_replay[A2L_DATA_WIDTH-1:0], link_cur_addr_8bit};
          link_advance_replay   = 1'b1;     
        end else begin
          tx_sop_in           = 1'b0;
          nstate              = LINK_IDLE;
        end
      end
    end
    
    //--------------------------------------------
    // Add check for valid data or NACK
    SEND_ACK : begin
      if(tx_advance) begin
        tx_sop_in         = 1'b0;
        send_ack_req_in   = 1'b0;
        nstate            = LINK_IDLE;
      end
    end
    

      
    
    default : begin
      nstate              = IDLE;
    end
  endcase
end

//assign send_ack_req_in  = send_ack_req ? 1'b1 : (exp_pkt_seen);


//you want to ignore credits and ACKs/nacks
assign exp_pkt_not_seen = valid_rx_pkt && ~(credit_pkt_recv || resp_credit_pkt_recv || link_ack_update) && (rx_app_data[7:0] != exp_pkt_num);
assign exp_pkt_seen     = valid_rx_pkt && ~(credit_pkt_recv || resp_credit_pkt_recv || link_ack_update) && (rx_app_data[7:0] == exp_pkt_num);
assign exp_pkt_num_in   = exp_pkt_seen ? (exp_pkt_num == fe_credit_max) ? 8'd0 : exp_pkt_num + 'd1 : exp_pkt_num;

assign last_good_pkt_in = exp_pkt_seen ? exp_pkt_num_in : last_good_pkt;



`ifdef SIMULATION
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    IDLE          : state_name = "IDLE";
    SEND_CREDITS1 : state_name = "SEND_CREDITS1";
    SEND_CREDITS2 : state_name = "SEND_CREDITS2";
    LINK_IDLE     : state_name = "LINK_IDLE";
    LINK_DATA     : state_name = "LINK_DATA";
    SEND_ACK      : state_name = "SEND_ACK";
    SEND_NACK     : state_name = "SEND_NACK";
  endcase
end

`endif

endmodule

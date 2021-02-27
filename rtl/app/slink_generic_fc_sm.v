/*
.rst_start
slink_generic_fc_sm
-------------------
This block, known also as "FC block", handles several flow control related items when communicating across S-Link. It houses a 
"generic" flow control mechanism that should serve well for the majority of applications. While there
may be some improvements that can be acheived by spinning your own flow control block, this provides
a component for creating larger systems. Several of these can be placed for an application, with the idea
being that you would use a ref:`slink_generic_tx_router` and ref:`slink_generic_rx_router` to route traffic
appropriately.


The block has two conceptual directions, Application-to-Link Layer (A2L) and Link Layer-to-Application (L2A). The
data width and FIFO depth are parameters which can be chosen based on the needs of the protocol/data supported.
``A2L_DEPTH`` and ``L2A_DEPTH`` represent the number of FIFO entries for the respective directions. 

.. note ::

  The ``A2L_DEPTH`` and ``L2A_DEPTH`` values should be a power of 2 and should not exceed 256.


Flow Control Training
++++++++++++++++++++++
Upon enabling the FC block, the FC will communicate with the far-end FC, exchanging information regarding
the available credits for each side. Each side of the link will advertise it's maximum TX (A2L) and RX (L2A)
credits. These credits are essentially the number of available entries in each FIFO.

The link begins by sending a ``GENERIC_SCRD`` packet which is a two byte count Slink long packet with Byte1
representing the Near-End TX credits and Byte2 representing the Near-End RX credits.

After recieving a ``GENERIC_SCRD`` packet, the FC block will beging to send a ``GENERIC_CR_ACK`` packet
which indicates to the other side that it has received the credit advertisement.

After sending `and` recieving a ``GENERIC_CR_ACK`` packet, the FC block will transition to the LINK_IDLE
state and wait for valid data to be transmitted.

Replay Buffer
+++++++++++++++++
The A2L direction of the FC block includes replayability features to compensate for any link degradation
resulting in loss of packets. Any time data is sent to the far end, a packet number is prefixed. This packet
number is used to ensure the receiving side did not miss a packet, and the receiving side can inform the 
transmitting side that a packet has been missed, resulting in a replay.

During FC Training, the packet number initializes to zero and increments by one for each packet sent. When 
a packet is received an ``ACK`` FC packet is scheduled to be sent. To indicate to the transmitter that the
packet was received in order, and without error. In the event a packet was either received out of order or
with an error in the packet, a ``NACK`` FC packet is scheduled with the last good packet number. Upon reception
by the transmitter of the ``NACK`` with the last good packet number, the TX will start replaying packets starting
after the last good packet number.


.rst_end
*/
module slink_generic_fc_sm #(
  //-----------------------------
  // App -> Link layer
  //-----------------------------
  parameter     A2L_DATA_WIDTH      = 32,         //Width of the data entry (includes WC+DT)
  parameter     A2L_DEPTH           = 8,          //Number of FIFO entires (MAX 256 ?)
  parameter     A2L_ADDR_WDITH      = $clog2(A2L_DEPTH),
  parameter     L2A_DATA_WIDTH      = 32,         //Width of the data entry (includes WC+DT)
  parameter     L2A_DEPTH           = 8,          //Number of FIFO entires (MAX 128)
  parameter     L2A_ADDR_WDITH      = $clog2(L2A_DEPTH),
  
  //When hardcoded, we don't send the DT/WC through the replay. Generally
  //used for multi-channel systems. Saves area in the REPLAY buffer
  parameter     USE_HARDCODED_DTWC  = 0,
  //parameter     HARDCODED_DT        = 8'h20,
  //parameter     HARDCODED_WC        = 16'h8,
  
  parameter     TX_APP_DATA_WIDTH   = 64,
  parameter     RX_APP_DATA_WIDTH   = 64
)(
  input  wire                           app_clk,
  input  wire                           app_reset,
  
  input  wire                           enable,
  
  input  wire [7:0]                     swi_cr_id,
  input  wire [7:0]                     swi_crack_id,
  input  wire [7:0]                     swi_ack_id,
  input  wire [7:0]                     swi_nack_id,
  
  input  wire [7:0]                     swi_data_id,
  input  wire [15:0]                    swi_word_count,
  
  input  wire                           a2l_valid,
  output wire                           a2l_ready,
  input  wire [A2L_DATA_WIDTH-1:0]      a2l_data,
  
  output wire                           l2a_valid,
  input  wire                           l2a_accept,
  output wire [L2A_DATA_WIDTH-1:0]      l2a_data,
  
  output wire                           tx_fifo_empty,    
  output wire                           rx_fifo_empty,    
  
  input  wire                           link_clk,
  input  wire                           link_reset,
  
  output wire                           nack_sent,        //on link_clk
  output wire                           nack_seen,        //on link_clk
  
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

localparam  IDLE              = 'd0,
            SEND_CREDITS1     = 'd1,
            SEND_CREDITS2     = 'd2,
            LINK_IDLE         = 'd3,
            LINK_DATA         = 'd4,
            SEND_ACK          = 'd5,
            SEND_NACK         = 'd6;


wire [7:0]  GENERIC_ACK   = swi_ack_id;
wire [7:0]  GENERIC_NACK  = swi_nack_id;
wire [7:0]  GENERIC_SCRD  = swi_cr_id;
wire [7:0]  GENERIC_CR_ACK= swi_crack_id;

reg   [2:0]     state, nstate;
wire            enable_link_clk;
reg             recv_credits, recv_credits_in;
reg             recv_resp_credits, recv_resp_credits_in;
reg   [7:0]     fe_tx_credit_max, fe_tx_credit_max_in;
reg   [7:0]     fe_rx_credit_max, fe_rx_credit_max_in;
reg             fe_rx_is_full;
reg   [2:0]     fe_rx_ptr_msb;
wire  [7:0]     ne_tx_credit_max;
wire  [7:0]     ne_rx_credit_max;
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
reg             send_nack_req_in;
//reg   [7:0]     nack_pkt_num;
//wire  [7:0]     nack_pkt_num_in;

wire            credit_pkt_recv;
wire            resp_credit_pkt_recv;
wire            valid_rx_pkt;
wire            valid_rx_pkt_crc_err;

reg             ack_seen_before;
wire            ack_seen_before_in;

reg   [7:0]     fe_rx_ptr;
wire  [7:0]     fe_rx_ptr_in;
reg   [7:0]     ne_rx_ptr;
reg   [7:0]     ne_rx_ptr_in;
wire  [7:0]     ne_rx_ptr_next;


wire                          link_ack_update;
wire [A2L_ADDR_WDITH:0]       link_ack_addr;
wire [A2L_ADDR_WDITH:0]       link_cur_addr;
wire [7:0]                    link_cur_addr_8bit;
wire [A2L_DATA_WIDTH-1:0]     link_data_replay;
wire                          link_valid_replay;
reg                           link_advance_replay;


wire                          rempty;
wire                          wfull;
wire [L2A_DATA_WIDTH-1:0]     fifo_wdata;
wire [L2A_ADDR_WDITH:0]       fifo_rbin_ptr;
reg  [L2A_ADDR_WDITH:0]       fifo_rbin_ptr_prev;
wire                          fifo_rbin_ptr_update;
wire [L2A_ADDR_WDITH:0]       fifo_rbin_ptr_link_clk;

wire                          link_revert;
wire [A2L_ADDR_WDITH:0]       link_revert_addr;


reg                           tx_sop_in;
reg   [7:0]                   tx_data_id_in;
reg   [15:0]                  tx_word_count_in;
reg   [TX_APP_DATA_WIDTH-1:0] tx_app_data_in;

wire  [7:0]                   tx_data_id_sel;
wire  [15:0]                  tx_word_count_sel;
wire  [TX_APP_DATA_WIDTH-1:0] tx_app_data_sel;



slink_demet_reset u_slink_demet_reset_enable_link_clk (
  .clk     ( link_clk       ),  
  .reset   ( link_reset     ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_link_clk)); 


always @(posedge link_clk or posedge link_reset) begin
  if(link_reset) begin
    state               <= IDLE;
    recv_credits        <= 1'b0;
    fe_tx_credit_max    <= 8'd0;
    fe_rx_credit_max    <= 8'd0;
    fe_rx_ptr           <= 8'd0;
    ne_rx_ptr           <= 8'd0;
    recv_resp_credits   <= 1'b0;
    exp_pkt_num         <= 8'd0;
    last_good_pkt       <= 8'd0;
    last_ack_pkt_sent   <= 8'd0;
    send_ack_req        <= 1'b0;
    send_nack_req       <= 1'b0;
    tx_sop              <= 1'b0;
    tx_data_id          <= 8'd0;
    tx_word_count       <= 16'd0;
    tx_app_data         <= {TX_APP_DATA_WIDTH{1'b0}};
    fifo_rbin_ptr_prev  <= {L2A_ADDR_WDITH+1{1'b0}};
    ack_seen_before     <= 1'b0;
  end else begin
    state               <= nstate;
    recv_credits        <= recv_credits_in;
    fe_tx_credit_max    <= fe_tx_credit_max_in;
    fe_rx_credit_max    <= fe_rx_credit_max_in;
    fe_rx_ptr           <= fe_rx_ptr_in;
    //ne_rx_ptr           <= ne_rx_ptr_in;       
    //On a link revert, we need to refresh the current ne_rx_ptr
    ne_rx_ptr           <= link_revert ? rx_word_count[15:8] : ne_rx_ptr_in;       
    recv_resp_credits   <= recv_resp_credits_in;
    exp_pkt_num         <= (state == IDLE) ? 8'd0 : exp_pkt_num_in;
    last_good_pkt       <= (state == IDLE) ? 8'd0 : last_good_pkt_in;
    last_ack_pkt_sent   <= (state == IDLE) ? 8'd0 : last_ack_pkt_sent_in;
    send_ack_req        <= (state == IDLE) ? 1'b0 : send_ack_req_in;
    send_nack_req       <= (state == IDLE) ? 1'b0 : send_nack_req_in;
    
    tx_sop              <= tx_sop_in;
    tx_data_id          <= tx_data_id_in;
    tx_word_count       <= tx_word_count_in;
    tx_app_data         <= tx_app_data_in;
    fifo_rbin_ptr_prev  <= fifo_rbin_ptr_link_clk;
    ack_seen_before     <= ack_seen_before_in;
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
  .empty               ( tx_fifo_empty        ),
  .link_ack_update     ( link_ack_update      ),  
  .link_ack_addr       ( link_ack_addr        ),  
  .link_revert         ( link_revert          ),
  .link_revert_addr    ( link_revert_addr     ),
  .link_cur_addr       ( link_cur_addr        ),  
  .link_data           ( link_data_replay     ),  
  .link_valid          ( link_valid_replay    ),  
  .link_advance        ( link_advance_replay  )); 


assign nack_sent            = (state == SEND_NACK) && (nstate != SEND_NACK);
assign nack_seen            = link_revert;


assign link_ack_update      = valid_rx_pkt && (rx_data_id == GENERIC_ACK);
assign link_ack_addr        = rx_word_count[A2L_ADDR_WDITH:0];
assign link_revert          = valid_rx_pkt && (rx_data_id == GENERIC_NACK);

//We will get back the last good packet, so we need to do the last good +1
//There is an issue however where if you get an error on the first packet and the far end sends
//back a NACK, pkt number 0 is really what you need to replay, not 1. So ensure that we
//know the far end has received at least one packet sucessfully to ensure we don't mess up the sequence
assign link_revert_addr     = ack_seen_before ? ((rx_word_count[A2L_ADDR_WDITH:0] == ne_tx_credit_max) ? 'd0 : rx_word_count[A2L_ADDR_WDITH:0] + 'd1) : 'd0;

assign link_cur_addr_8bit   = {{(7-A2L_ADDR_WDITH){1'b0}}, link_cur_addr};

assign ne_tx_credit_max     = {{(7-A2L_ADDR_WDITH){1'b0}}, {A2L_ADDR_WDITH+1{1'b1}}};    
assign ne_rx_credit_max     = {{(7-L2A_ADDR_WDITH){1'b0}}, {L2A_ADDR_WDITH+1{1'b1}}};    

assign valid_rx_pkt         = rx_sop && rx_valid && ~rx_crc_corrupted;

//We want to block crc errors during credits as we don't have a packet sequence yet
//Stop reverts if the ACK/NACK has a CRC error. We should let the far side just resend.
//
assign valid_rx_pkt_crc_err = rx_sop && rx_valid &&  rx_crc_corrupted;

assign credit_pkt_recv      = valid_rx_pkt && (rx_data_id == GENERIC_SCRD);
assign resp_credit_pkt_recv = valid_rx_pkt && (rx_data_id == GENERIC_CR_ACK);


assign fe_rx_ptr_in         = (state == IDLE) ? 8'd0 : (link_ack_update || link_revert) ? rx_word_count[15:8] : fe_rx_ptr;
assign ne_rx_ptr_next       = (ne_rx_ptr == fe_rx_credit_max) ? 8'd0 : ne_rx_ptr + 8'd1; 

assign fifo_rbin_ptr_update = fifo_rbin_ptr_link_clk != fifo_rbin_ptr_prev;


assign ack_seen_before_in   = (state == IDLE) ? 1'b0 : (link_ack_update ? 1'b1 : ack_seen_before);


integer i;
always @(*) begin
  fe_rx_ptr_msb = 3'd0;
  for(i=0; i < 8; i = i + 1) begin
    if(fe_rx_credit_max[i]) begin
      fe_rx_ptr_msb = i;
    end
  end
  
  
  //Default to FULL and check for conditions that aren't full
  // msb's should be != and all lower bits == for full
  //See about optimizing this? I think we can get one more entry
  fe_rx_is_full = 1'b1;
  for(i=0; i < fe_rx_ptr_msb; i = i + 1) begin
    //if(ne_rx_ptr[i] != fe_rx_ptr[i]) begin
    if(ne_rx_ptr_next[i] != fe_rx_ptr[i]) begin
      fe_rx_is_full = 1'b0;
    end
  end
  //if(ne_rx_ptr[fe_rx_ptr_msb] == fe_rx_ptr[fe_rx_ptr_msb]) begin
  if(ne_rx_ptr_next[fe_rx_ptr_msb] == fe_rx_ptr[fe_rx_ptr_msb]) begin
    fe_rx_is_full = 1'b0;
  end
  
end


//Picks between the hardcorded and passed through method
generate
  if(USE_HARDCODED_DTWC == 1) begin : gen_hardcoded_dtwc
    assign tx_data_id_sel     = swi_data_id;
    assign tx_word_count_sel  = swi_word_count + 16'h1;   //note the +1 for the packet num
    assign tx_app_data_sel    = {{TX_APP_DATA_WIDTH-A2L_DATA_WIDTH-8{1'b0}},  link_data_replay[A2L_DATA_WIDTH-1:0],  link_cur_addr_8bit};
  end else begin : gen_app_dtwc
    assign tx_data_id_sel     = link_data_replay[ 7: 0];
    assign tx_word_count_sel  = link_data_replay[23: 8] + 16'h1;
    assign tx_app_data_sel    = {{TX_APP_DATA_WIDTH-A2L_DATA_WIDTH-32{1'b0}}, link_data_replay[A2L_DATA_WIDTH-1:24], link_cur_addr_8bit};
  end
endgenerate



always @(*) begin
  nstate                    = state;
  recv_credits_in           = recv_credits;
  recv_resp_credits_in      = recv_resp_credits;
  fe_tx_credit_max_in       = fe_tx_credit_max;
  fe_rx_credit_max_in       = fe_rx_credit_max;
  ne_rx_ptr_in              = ne_rx_ptr;
  tx_sop_in                 = tx_sop;       
  tx_data_id_in             = tx_data_id;   
  tx_word_count_in          = tx_word_count;
  tx_app_data_in            = tx_app_data;  
  link_advance_replay       = 1'b0;
  last_ack_pkt_sent_in      = last_ack_pkt_sent;
  send_ack_req_in           = send_ack_req  ? 1'b1 : (exp_pkt_seen | fifo_rbin_ptr_update);
  send_nack_req_in          = send_nack_req ? 1'b1 : (valid_rx_pkt_crc_err | exp_pkt_not_seen);
  
  
  case(state)
    //--------------------------------------------
    IDLE : begin
      recv_credits_in       = 1'b0;
      fe_tx_credit_max_in   = 8'd0;
      fe_rx_credit_max_in   = 8'd0;
      ne_rx_ptr_in          = 8'd0;   
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
      //tx_word_count_in      = 16'd2;
      //tx_app_data_in        = {{TX_APP_DATA_WIDTH-16{1'b0}}, ne_rx_credit_max, ne_tx_credit_max};
      tx_word_count_in      = {ne_rx_credit_max, ne_tx_credit_max};
      tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
      
      if(resp_credit_pkt_recv) begin
        recv_resp_credits_in= 1'b1;
      end 
      
      if(credit_pkt_recv) begin
        recv_credits_in     = 1'b1;
        fe_tx_credit_max_in = rx_word_count[7:0];
        fe_rx_credit_max_in = rx_word_count[15:8];
      end
      
      if(tx_advance) begin
        if(recv_credits_in) begin
          tx_sop_in         = 1'b1;
          tx_data_id_in     = GENERIC_CR_ACK;
          //tx_word_count_in      = 16'd2;
          //tx_app_data_in        = {{TX_APP_DATA_WIDTH-16{1'b0}}, ne_rx_credit_max, ne_tx_credit_max};
          tx_word_count_in  = {ne_rx_credit_max, ne_tx_credit_max};
          tx_app_data_in    = {TX_APP_DATA_WIDTH{1'b0}};
          nstate            = SEND_CREDITS2;
        end
      end
    end
    
    //--------------------------------------------
    SEND_CREDITS2 : begin
      tx_sop_in             = 1'b1;
      tx_data_id_in         = GENERIC_CR_ACK;
      //tx_word_count_in      = 16'd2;
      //tx_app_data_in        = {{TX_APP_DATA_WIDTH-16{1'b0}}, ne_rx_credit_max, ne_tx_credit_max};
      tx_word_count_in      = {ne_rx_credit_max, ne_tx_credit_max};
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
      if(send_nack_req) begin
        //Capture the most recent good packet and the current RX pointer and send that as part of the NACK
        tx_sop_in             = 1'b1;
        tx_data_id_in         = GENERIC_NACK;
        //tx_word_count_in      = 16'd2;
        //tx_app_data_in        = {{TX_APP_DATA_WIDTH-16{1'b0}}, fifo_rbin_ptr_link_clk, last_ack_pkt_sent};
        tx_word_count_in      = {fifo_rbin_ptr_link_clk, last_ack_pkt_sent};
        tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
        send_nack_req_in      = 1'b0;       //Clear this now to protect against missing another NACK request
        nstate                = SEND_NACK;
      end else if(send_ack_req) begin
        //Capture the most recent good packet and the current RX pointer and send that as part of the ACK
        last_ack_pkt_sent_in  = last_good_pkt_in;
        tx_sop_in             = 1'b1;
        tx_data_id_in         = GENERIC_ACK;
        //tx_word_count_in      = 16'd2;
        //tx_app_data_in        = {{TX_APP_DATA_WIDTH-16{1'b0}}, fifo_rbin_ptr_link_clk, last_ack_pkt_sent};
        tx_word_count_in      = {fifo_rbin_ptr_link_clk, last_ack_pkt_sent};
        tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
        send_ack_req_in       = 1'b0;       //Clear this now to protect against missing another ACK request
        nstate                = SEND_ACK;
      end else if(link_valid_replay && ~fe_rx_is_full) begin
        tx_sop_in             = 1'b1;
        tx_data_id_in         = tx_data_id_sel;
        tx_word_count_in      = tx_word_count_sel; 
        tx_app_data_in        = tx_app_data_sel;
        link_advance_replay   = 1'b1;     //go ahead and clear this one
        ne_rx_ptr_in          = ne_rx_ptr_next;
        nstate                = LINK_DATA;
      end
    end
    
    //--------------------------------------------
    // 
    LINK_DATA : begin
      if(tx_advance) begin
        if(send_nack_req) begin
          tx_sop_in             = 1'b1;
          tx_data_id_in         = GENERIC_NACK;
          //tx_word_count_in      = 16'd2;
          //tx_app_data_in        = {{TX_APP_DATA_WIDTH-16{1'b0}}, fifo_rbin_ptr_link_clk, last_ack_pkt_sent};
          tx_word_count_in      = {fifo_rbin_ptr_link_clk, last_ack_pkt_sent};
          tx_app_data_in        = {TX_APP_DATA_WIDTH{1'b0}};
          send_nack_req_in      = 1'b0;       
          nstate                = SEND_NACK;
        end else if(~send_ack_req && link_valid_replay && ~fe_rx_is_full) begin
          tx_sop_in             = 1'b1;
          tx_data_id_in         = tx_data_id_sel;
          tx_word_count_in      = tx_word_count_sel;
          tx_app_data_in        = tx_app_data_sel;
          link_advance_replay   = 1'b1;     
          ne_rx_ptr_in          = ne_rx_ptr_next;
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
        nstate            = LINK_IDLE;
      end
    end
    
    //--------------------------------------------
    SEND_NACK : begin
      if(tx_advance) begin
        tx_sop_in         = 1'b0;
        nstate            = LINK_IDLE;
      end
    end
      
    
    default : begin
      nstate              = IDLE;
    end
  endcase
  
  if(~enable_link_clk) begin
    nstate                = IDLE;
  end
end


//you want to ignore credits and ACKs/nacks
assign exp_pkt_not_seen = valid_rx_pkt && ~(credit_pkt_recv || resp_credit_pkt_recv || link_ack_update || link_revert) && (rx_app_data[7:0] != exp_pkt_num);
assign exp_pkt_seen     = valid_rx_pkt && ~(credit_pkt_recv || resp_credit_pkt_recv || link_ack_update || link_revert) && (rx_app_data[7:0] == exp_pkt_num);
assign exp_pkt_num_in   = exp_pkt_seen ? (exp_pkt_num == fe_tx_credit_max) ? 8'd0 : exp_pkt_num + 'd1 : exp_pkt_num;

//assign last_good_pkt_in = exp_pkt_seen ? exp_pkt_num_in : last_good_pkt;
assign last_good_pkt_in = exp_pkt_seen ? exp_pkt_num : last_good_pkt;





generate
  if(USE_HARDCODED_DTWC == 1) begin : gen_hardcoded_rxdata
    assign fifo_wdata = rx_app_data[L2A_DATA_WIDTH+7:8];
  end else begin : gen_app_rxdata
    assign fifo_wdata = {rx_app_data[L2A_DATA_WIDTH-15:8], rx_word_count, rx_data_id};
  end
endgenerate

slink_fc_replay_addr_sync #(
  //parameters
  .ADDR_WIDTH         ( L2A_ADDR_WDITH+1 )
) u_slink_fc_replay_addr_sync (
  .wclk    ( app_clk                ),  
  .wreset  ( app_reset              ),  
  .waddr   ( fifo_rbin_ptr          ),         
  .rclk    ( link_clk               ),  
  .rreset  ( link_reset             ),  
  .raddr   ( fifo_rbin_ptr_link_clk )); 



// Using this backwards for now
// app is the link
// link is the app
wire [L2A_ADDR_WDITH:0] receive_dp_addr;
slink_generic_fc_replay #(
  //parameters
  .A2L_DEPTH          ( L2A_DEPTH       ),
  .A2L_DATA_WIDTH     ( L2A_DATA_WIDTH  )
) u_receive_dpram (
  .app_clk             ( link_clk                 ),           
  .app_reset           ( link_reset               ),           
  .link_clk            ( app_clk                  ),  
  .link_reset          ( app_reset                ),  
  .enable              ( enable                   ),  
  .a2l_valid           ( exp_pkt_seen             ),  
  .a2l_ready           (                          ),  //need to check this     
  .a2l_data            ( fifo_wdata               ),
  .empty               ( rx_fifo_empty            ),
  .link_ack_update     ( 1'b1                     ),   
  .link_ack_addr       ( fifo_rbin_ptr            ),  
  .link_cur_addr       ( fifo_rbin_ptr            ),  
  .link_revert         ( 1'b0                     ),
  .link_revert_addr    ( {L2A_ADDR_WDITH+1{1'b0}} ),
  .link_data           ( l2a_data                 ),    
  .link_valid          ( l2a_valid                ),  
  .link_advance        ( l2a_accept               )); 



//assign l2a_valid  = ~rx_fifo_empty;


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


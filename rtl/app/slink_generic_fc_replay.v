module slink_generic_fc_replay #(
  // Application Side
  parameter     A2L_DATA_WIDTH    = 32,
  parameter     A2L_DEPTH         = 8,                    //up to 128
  parameter     A2L_ADDR_WDITH    = $clog2(A2L_DEPTH)  
)(
  input  wire                         app_clk,
  input  wire                         app_reset,
  
  input  wire                         link_clk,
  input  wire                         link_reset,
  
  input  wire                         enable,
  
  //--------------------------
  // Application Side
  //--------------------------
  input  wire                         a2l_valid,
  output wire                         a2l_ready,
  input  wire [A2L_DATA_WIDTH-1:0]    a2l_data,
  
  output wire                         empty,
    
  //--------------------------
  // Link Side
  //--------------------------
  input  wire                         link_ack_update,
  input  wire [A2L_ADDR_WDITH:0]      link_ack_addr,
  
  input  wire                         link_revert,
  input  wire [A2L_ADDR_WDITH:0]      link_revert_addr,
  
  output wire [A2L_ADDR_WDITH:0]      link_cur_addr,
  output wire [A2L_DATA_WIDTH-1:0]    link_data,
  output wire                         link_valid,
  input  wire                         link_advance

  

);

wire                        enable_app_clk;
reg   [A2L_ADDR_WDITH:0]    a2l_app_addr;
wire  [A2L_ADDR_WDITH:0]    a2l_app_addr_in;
wire                        a2l_write;

wire  [A2L_ADDR_WDITH:0]    a2l_link_addr_app_clk;
wire                        a2l_link_addr_app_clk_ready;
wire                        a2l_full;

wire  [A2L_ADDR_WDITH:0]    a2l_app_addr_link_clk;
wire                        a2l_app_addr_link_clk_ready;



wire                        enable_link_clk;
reg   [A2L_ADDR_WDITH:0]    a2l_link_addr;
wire  [A2L_ADDR_WDITH:0]    a2l_link_addr_in;
wire                        a2l_read;
wire                        a2l_empty;
reg   [A2L_ADDR_WDITH:0]    a2l_link_addr_real;
wire  [A2L_ADDR_WDITH:0]    a2l_link_addr_real_in;


//---------------------------
// App Side A2L
//---------------------------

slink_demet_reset u_slink_demet_reset_enable_app_clk (
  .clk     ( app_clk        ),  
  .reset   ( app_reset      ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_app_clk )); 

always @(posedge app_clk or posedge app_reset) begin
  if(app_reset) begin
    a2l_app_addr        <= {A2L_ADDR_WDITH+1{1'b0}};
  end else begin
    a2l_app_addr        <= a2l_app_addr_in;
  end
end




assign a2l_full         = (a2l_app_addr[A2L_ADDR_WDITH]     != a2l_link_addr_app_clk[A2L_ADDR_WDITH]) &&
                          (a2l_app_addr[A2L_ADDR_WDITH-1:0] == a2l_link_addr_app_clk[A2L_ADDR_WDITH-1:0]);
assign a2l_ready        = ~a2l_full && enable_app_clk;
assign a2l_write        = a2l_ready && a2l_valid;
assign a2l_app_addr_in  = enable_app_clk ? (a2l_write ? a2l_app_addr + 'd1 : a2l_app_addr) : {A2L_ADDR_WDITH+1{1'b0}};


//-------------------------------
// Moving the addr pointers between the clock domains
//-------------------------------

slink_fc_replay_addr_sync #(
  //parameters
  .ADDR_WIDTH         ( A2L_ADDR_WDITH+1 )
) u_slink_fc_replay_addr_sync_app_addr_to_link_clk (
  .wclk    ( app_clk                ),  
  .wreset  ( app_reset              ),  
  .waddr   ( a2l_app_addr           ),  
  .rclk    ( link_clk               ),  
  .rreset  ( link_reset             ),  
  .raddr   ( a2l_app_addr_link_clk  )); 


slink_fc_replay_addr_sync #(
  //parameters
  .ADDR_WIDTH         ( A2L_ADDR_WDITH+1 )
) u_slink_fc_replay_addr_sync_link_addr_to_app_clk (
  .wclk    ( link_clk               ),  
  .wreset  ( link_reset             ),  
  .waddr   ( a2l_link_addr          ),  
  .rclk    ( app_clk                ),  
  .rreset  ( app_reset              ),  
  .raddr   ( a2l_link_addr_app_clk  )); 
  
  
//---------------------------
// Link Side A2L
//---------------------------

slink_demet_reset u_slink_demet_reset_enable_link_clk (
  .clk     ( link_clk       ),  
  .reset   ( link_reset     ),  
  .sig_in  ( enable         ),  
  .sig_out ( enable_link_clk)); 

always @(posedge link_clk or posedge link_reset) begin
  if(link_reset) begin
    a2l_link_addr_real  <= {A2L_ADDR_WDITH+1{1'b0}};
    a2l_link_addr       <= {A2L_ADDR_WDITH+1{1'b0}};
  end else begin
    a2l_link_addr_real  <= a2l_link_addr_real_in;
    a2l_link_addr       <= a2l_link_addr_in;
  end
end


//This is on the link_clk_domain
assign a2l_empty          = (a2l_link_addr_real[A2L_ADDR_WDITH]     == a2l_app_addr_link_clk[A2L_ADDR_WDITH]) &&
                            (a2l_link_addr_real[A2L_ADDR_WDITH-1:0] == a2l_app_addr_link_clk[A2L_ADDR_WDITH-1:0]);
assign empty              = a2l_empty;  
//The "REAL" link address is what we are actually reading from in the FIFO
//BUT we send the last known good packet address back to the APP layer, this way
//if we need to do a replay, we can and the app hasn't overwritten the packet

//The revert will take precedence over the link_advance (since we are going to re-transmit anyways)
assign a2l_link_addr_real_in  = enable_link_clk ? link_revert ? link_revert_addr : (link_advance && link_valid ? a2l_link_addr_real + 'd1 : a2l_link_addr_real) : {A2L_ADDR_WDITH+1{1'b0}};
assign a2l_link_addr_in       = link_ack_update ? link_ack_addr : a2l_link_addr;
assign link_valid             = enable_link_clk ? ~a2l_empty : 1'b0;

assign a2l_read               = link_valid;


assign link_cur_addr          = a2l_link_addr_real;
slink_dp_ram #(
  //parameters
  .SIZE               ( A2L_DEPTH       ),
  .DWIDTH             ( A2L_DATA_WIDTH  )
) u_a2l_dp_ram (
  .clk_0     ( app_clk                                ),  
  .addr_0    ( a2l_app_addr[A2L_ADDR_WDITH-1:0]       ),  
  .en_0      ( a2l_write                              ),  
  .we_0      ( a2l_write                              ),  
  .be_0      ( {A2L_DATA_WIDTH/8{1'b1}}               ),  
  .wdata_0   ( a2l_data                               ),  
  .rdata_0   (                                        ),  
  
  .clk_1     ( link_clk                               ),
  .addr_1    ( a2l_link_addr_real[A2L_ADDR_WDITH-1:0] ),  
  .en_1      ( a2l_read                               ),  
  .we_1      ( 1'b0                                   ),  
  .be_1      ( {A2L_DATA_WIDTH/8{1'b1}}               ),  
  .wdata_1   ( {A2L_DATA_WIDTH{1'b0}}                 ),  
  .rdata_1   ( link_data                              )); 


endmodule


/**
  *   This will handle the update in each direction. We will essentially
  *   always write/read and only update the output when the rready is set
  */
module slink_fc_replay_addr_sync #(
  parameter ADDR_WIDTH = 4
)(
  input  wire                   wclk,
  input  wire                   wreset,
  input  wire [ADDR_WIDTH-1:0]  waddr,
  
  input  wire                   rclk,
  input  wire                   rreset,
  output wire [ADDR_WIDTH-1:0]  raddr
);

wire      wready;
wire      rready;

wire  [ADDR_WIDTH-1:0]  raddr_fifo;
reg   [ADDR_WIDTH-1:0]  raddr_reg;


always @(posedge rclk or posedge rreset) begin
  if(rreset) begin
    raddr_reg <= {ADDR_WIDTH{1'b0}};
  end else begin
    raddr_reg <= rready ? raddr_fifo : raddr_reg;
  end
end

assign raddr = rready ? raddr_fifo : raddr_reg;

slink_multibit_sync #(.DATA_SIZE(ADDR_WIDTH)) u_slink_multibit_sync (
  .wclk    ( wclk       ),                      
  .wreset  ( wreset     ),                      
  .winc    ( 1'b1       ),                      
  .wready  (            ),                      
  .wdata   ( waddr      ),                      
            
  .rclk    ( rclk       ),                  
  .rreset  ( rreset     ),                  
  .rinc    ( 1'b1       ),                  
  .rready  ( rready     ),      
  .rdata   ( raddr_fifo ));     

endmodule

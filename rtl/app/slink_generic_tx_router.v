/*
.rst_start
slink_generic_tx_router
-----------------------

This "generic" router will arbitrate between N channels for TX data. Priority is given to the lowest
channel number, however a lower channel will not preempt a higher channel if the higher channel started
it's transaction first. In addition, a lower channel must wait until all of the higher channels have
completed, similar to most round robin arbitration schemes. Here is an example:

  **Example 1:**
  Channels 0, 1, and 4 all assert ``tx_sop`` on the same cycle. Channel 0 will have priority, then Channel 1, 
  then Channel 4. If Channel 0 wants to start another packet on the following cycle, it will be blocked until *after*
  Channel 4 has sent.
  
  **Example 2:**
  Channels 1 and 2 all assert ``tx_sop`` on the same cycle. Channel 1 will have priority and start sending data. Channel 0
  then wants to send another packet (1+ cycles after Channel 1 and 2 started), Channel 1 and 2 will both complete before
  Channel 0 is allowed through.

The selected channel defaults to 0 when not active. If a Channel other than 0 starts a transmission, there is no
cycle delay to swtich to that channel. 
  
.rst_end
*/

module slink_generic_tx_router #(
  parameter NUM_CHANNELS      = 8,
  parameter TX_APP_DATA_WIDTH = 64
)(
  input  wire                           clk,
  input  wire                           reset,
  input  wire                           enable,
    
  input  wire [NUM_CHANNELS-1:0]        tx_sop_ch,
  input  wire [(NUM_CHANNELS*8)-1:0]    tx_data_id_ch,
  input  wire [(NUM_CHANNELS*16)-1:0]   tx_word_count_ch,
  input  wire [(NUM_CHANNELS*
                TX_APP_DATA_WIDTH)-1:0] tx_app_data_ch,
  output wire [NUM_CHANNELS-1:0]        tx_advance_ch,
  
  output wire                           tx_sop,
  output wire [7:0]                     tx_data_id,
  output wire [15:0]                    tx_word_count,
  output wire [TX_APP_DATA_WIDTH-1:0]   tx_app_data,
  input  wire                           tx_advance
);

localparam  NUM_CHANNELS_CLOG2  = $clog2(NUM_CHANNELS);

reg   [NUM_CHANNELS_CLOG2-1:0]  curr_ch;
reg   [NUM_CHANNELS_CLOG2-1:0]  curr_ch_reg;
reg   [NUM_CHANNELS_CLOG2-1:0]  curr_ch_reg_in;
wire  [NUM_CHANNELS_CLOG2-1:0]  curr_ch_next;
wire                            enable_ff2;

wire  [NUM_CHANNELS-1:0]        higher_index_sel;
reg   [NUM_CHANNELS_CLOG2-1:0]  higher_index_pri;
wire  [NUM_CHANNELS-1:0]        lower_index_sel;
reg   [NUM_CHANNELS_CLOG2-1:0]  lower_index_pri;

wire                            tx_sop_sel        [NUM_CHANNELS-1:0];
wire  [7:0]                     tx_data_id_sel    [NUM_CHANNELS-1:0];
wire  [15:0]                    tx_word_count_sel [NUM_CHANNELS-1:0];
wire  [TX_APP_DATA_WIDTH-1:0]   tx_app_data_sel   [NUM_CHANNELS-1:0];

slink_demet_reset u_slink_demet_reset_enable (
  .clk     ( clk        ),  
  .reset   ( reset      ),  
  .sig_in  ( enable     ),  
  .sig_out ( enable_ff2 )); 


always @(posedge clk or posedge reset) begin
  if(reset) begin
    curr_ch_reg       <= {NUM_CHANNELS_CLOG2{1'b0}};
  end else begin
    curr_ch_reg       <= enable_ff2 ? curr_ch_reg_in : {NUM_CHANNELS_CLOG2{1'b0}};
  end
end


genvar index;
generate
  for(index = 0; index < NUM_CHANNELS; index = index + 1) begin : gen_indexes
    assign higher_index_sel[index]  = (index > curr_ch_reg)  && tx_sop_ch[index];
    assign lower_index_sel[index]   = (index <= curr_ch_reg) && tx_sop_ch[index];
    
    assign tx_advance_ch[index]     = tx_advance && (curr_ch == index);
    
    assign tx_sop_sel[index]        = tx_sop_ch[index];
    assign tx_data_id_sel[index]    = tx_data_id_ch[((index+1)*8)-1:(index*8)];
    assign tx_word_count_sel[index] = tx_word_count_ch[((index+1)*16)-1:(index*16)];
    assign tx_app_data_sel[index]   = tx_app_data_ch[((index+1)*TX_APP_DATA_WIDTH)-1:(index*TX_APP_DATA_WIDTH)];
  end
endgenerate


integer i;
always @(*) begin
  higher_index_pri  = {NUM_CHANNELS_CLOG2{1'b0}};
  for(i = (NUM_CHANNELS-1); i >= 0; i = i - 1) begin
    if((i > curr_ch_reg)  && tx_sop_ch[i]) begin
      higher_index_pri  = i;
    end
  end
end

integer j;
always @(*) begin
  lower_index_pri  = {NUM_CHANNELS_CLOG2{1'b0}};
  for(j = (NUM_CHANNELS-1); j >= 0; j = j - 1) begin
    //if((j <= curr_ch_reg) && tx_sop_ch[j]) begin
    if((j < curr_ch_reg) && tx_sop_ch[j]) begin
      lower_index_pri  = j;
    end
  end
end



always @(*) begin
  curr_ch_reg_in      = curr_ch_reg;
  curr_ch             = curr_ch_reg;
  
  if((curr_ch_reg != higher_index_pri) && ~(|lower_index_sel)) begin
    curr_ch_reg_in    = higher_index_pri;
    curr_ch           = higher_index_pri;
  end else begin
    if(tx_advance) begin
      curr_ch_reg_in  = |higher_index_sel ? higher_index_pri :
                        |lower_index_sel  ? lower_index_pri  : {NUM_CHANNELS_CLOG2{1'b0}};
    end  
  end
  
end

assign tx_sop           = tx_sop_sel       [curr_ch];
assign tx_data_id       = tx_data_id_sel   [curr_ch];
assign tx_word_count    = tx_word_count_sel[curr_ch];
assign tx_app_data      = tx_app_data_sel  [curr_ch];


endmodule

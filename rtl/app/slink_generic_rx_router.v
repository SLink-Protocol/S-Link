/*
.rst_start
slink_generic_rx_router
-----------------------

This "generic" router will send RX data to the repsective channel based on 
``rx_data_id`` windows. A user would set ``SP_CH_MIN``, ``SP_CH_MAX``, ``LP_CH_MIN``, 
and ``LP_CH_MAX`` for each channel and the start of a packet would enable that channel until the start
of the next received packet. The channel windows are exclusive, meaning
separate channels cannot share the same data IDs.
  
.rst_end
*/

module slink_generic_rx_router #(
  parameter NUM_CHANNELS      = 8,
  parameter RX_APP_DATA_WIDTH = 64
)(
  input  wire                           clk,
  input  wire                           reset,
  
  input  wire                           rx_sop,
  input  wire [7:0]                     rx_data_id,
  input  wire [15:0]                    rx_word_count,
  input  wire [RX_APP_DATA_WIDTH-1:0]   rx_app_data,
  input  wire                           rx_valid,
  input  wire                           rx_crc_corrupted,
  
  input  wire [(NUM_CHANNELS*8)-1:0]    swi_ch_sp_min,
  input  wire [(NUM_CHANNELS*8)-1:0]    swi_ch_sp_max,
  input  wire [(NUM_CHANNELS*8)-1:0]    swi_ch_lp_min,
  input  wire [(NUM_CHANNELS*8)-1:0]    swi_ch_lp_max,
  
  output wire [NUM_CHANNELS-1:0]        rx_sop_ch,
  output wire [(NUM_CHANNELS*8)-1:0]    rx_data_id_ch,
  output wire [(NUM_CHANNELS*16)-1:0]   rx_word_count_ch,
  output wire [(NUM_CHANNELS*
                RX_APP_DATA_WIDTH)-1:0] rx_app_data_ch,
  output wire [NUM_CHANNELS-1:0]        rx_valid_ch,
  output wire [NUM_CHANNELS-1:0]        rx_crc_corrupted_ch
);

localparam  NUM_CHANNELS_CLOG2  = $clog2(NUM_CHANNELS);

reg   [NUM_CHANNELS-1:0]  ch_sel;
wire  [NUM_CHANNELS-1:0]  ch_sel_in;
wire                      ch_update;
wire                      enable_ff2;


always @(posedge clk or posedge reset) begin
  if(reset) begin
    ch_sel       <= {NUM_CHANNELS_CLOG2{1'b0}};
  end else begin
    ch_sel       <= ch_sel_in;
  end
end


assign ch_update  = rx_sop && rx_valid;

genvar index;
generate
  for(index = 0; index < NUM_CHANNELS; index = index + 1) begin : gen_indexes
    assign ch_sel_in[index]        = ch_update ?  ((rx_data_id >= swi_ch_sp_min[((index+1)*8)-1:(index*8)]) &&
                                                   (rx_data_id <= swi_ch_sp_max[((index+1)*8)-1:(index*8)])) ||
                                                  ((rx_data_id >= swi_ch_lp_min[((index+1)*8)-1:(index*8)]) &&
                                                   (rx_data_id <= swi_ch_lp_max[((index+1)*8)-1:(index*8)]))   : ch_sel[index];
  
    assign rx_sop_ch[index]                                                               = rx_sop            && ch_sel_in[index];
    assign rx_valid_ch[index]                                                             = rx_valid          && ch_sel_in[index];
    assign rx_crc_corrupted_ch[index]                                                     = rx_crc_corrupted  && ch_sel_in[index];
    assign rx_data_id_ch[((index+1)*8)-1:(index*8)]                                       = rx_data_id;
    assign rx_word_count_ch[((index+1)*16)-1:(index*16)]                                  = rx_word_count;
    assign rx_app_data_ch[((index+1)*RX_APP_DATA_WIDTH)-1:(index*RX_APP_DATA_WIDTH)]      = rx_app_data;
  end
endgenerate

endmodule


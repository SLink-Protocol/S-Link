module slink_ll_rx_pkt_filt (
  input  wire             clk,
  input  wire             reset,

  input  wire             sop,
  input  wire [7:0]       data_id,
  input  wire [15:0]      word_count,
  input  wire             valid,
  
  
  output wire             sop_app,
  output wire             valid_app
  
);

`include "slink_includes.vh"

wire  pkt_is_internal;
wire  attr_addr_pkt;
wire  attr_data_pkt;
wire  attr_req_pkt;


assign pkt_is_internal  = (data_id == NOP_DATAID)  ||
                          (data_id == IDL_SYM);


assign sop_app          = ~pkt_is_internal && sop;
assign valid_app        = ~pkt_is_internal && valid;


endmodule

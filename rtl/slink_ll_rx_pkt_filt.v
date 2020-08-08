module slink_ll_rx_pkt_filt (
  input  wire             clk,
  input  wire             reset,

  input  wire             sop,
  input  wire [7:0]       data_id,
  input  wire [15:0]      word_count,
  input  wire             valid,
  
  
  output wire             sop_app,
  output wire             valid_app,
  
  input  wire             link_inactive,
  
  input  wire [7:0]       pkt_min_filter,
  input  wire [7:0]       pkt_max_filter,
  
  //Attribute Update
  output reg  [15:0]      attr_addr,
  output wire [15:0]      attr_data,
  output wire             attr_shadow_update,
  output reg              attr_read_req,
  
  //P State Receiption
  output wire             px_req_pkt,
  output reg  [2:0]       px_req_state,
  output wire             px_rej_pkt,
  output wire             px_start_pkt,
    
  output wire             aux_fifo_winc,
  output wire [23:0]      aux_fifo_data
);

`include "slink_includes.vh"

wire  pkt_is_internal;
wire  attr_addr_pkt;
wire  attr_data_pkt;
wire  attr_req_pkt;


assign pkt_is_internal  = (data_id == NOP_DATAID)  ||
                          (data_id == IDL_SYM)     ||
                          (data_id == ATTR_ADDR)   ||
                          (data_id == ATTR_DATA)   ||
                          (data_id == ATTR_REQ)    ||
                          (data_id == ATTR_RSP)    ||
                          (data_id == PX_REQ)      ||
                          (data_id == PX_START);


assign sop_app          = ~pkt_is_internal && sop;
assign valid_app        = ~pkt_is_internal && valid;


assign attr_addr_pkt    = (data_id == ATTR_ADDR) && sop && valid;
assign attr_data_pkt    = (data_id == ATTR_DATA) && sop && valid;
assign attr_req_pkt     = (data_id == ATTR_REQ)  && sop && valid;

always @(posedge clk or posedge reset) begin
  if(reset) begin
    attr_addr           <= 16'd0;
    attr_read_req       <= 1'b0;
  end else begin
    attr_addr           <= attr_addr_pkt || attr_req_pkt ? word_count : attr_addr;
    attr_read_req       <= attr_req_pkt;
  end
end

assign attr_data          = attr_data_pkt ? word_count : 16'd0;
assign attr_shadow_update = attr_data_pkt;


assign aux_fifo_winc      = (data_id >= pkt_min_filter) && (data_id <= pkt_max_filter) && sop & valid;
assign aux_fifo_data      = aux_fifo_winc ? {word_count, data_id} : 24'd0;




always @(posedge clk or posedge reset) begin
  if(reset) begin
    px_req_state          <= 16'd0;
  end else begin
    px_req_state          <= px_req_pkt ? word_count[2:0] : (link_inactive ? 3'd0 : px_req_state);
  end
end

assign px_req_pkt         = (data_id == PX_REQ)   && sop && valid;
assign px_rej_pkt         = 1'b0;//(data_id == PX_REJ)   && sop && valid;
assign px_start_pkt       = (data_id == PX_START) && sop && valid;

endmodule

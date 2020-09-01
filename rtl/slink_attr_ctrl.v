module slink_attr_ctrl #(
  parameter SW_ATTR_FIFO_DEPTH = 2
)(
  input  wire         link_clk,
  input  wire         link_reset,
  
  input  wire         apb_clk,
  input  wire         apb_reset,
  
  // Sending from APB -> Link
  input  wire [15:0]  apb_attr_addr,
  input  wire [15:0]  apb_attr_wdata,
  input  wire         apb_attr_wr,
  input  wire         apb_send_fifo_winc,  
  input  wire         apb_send_fifo_rinc,
  output wire         apb_send_fifo_full,
  output wire         apb_send_fifo_empty,
  
  output wire [15:0]  send_attr_addr,
  output wire [15:0]  send_attr_wdata,
  output wire         send_attr_wr,
  
  // Receiving from Link -> APB
  // From Link on Attribute Responses
  input  wire [15:0]  recv_attr_rdata,
  input  wire         apb_recv_fifo_winc,
  input  wire         apb_recv_fifo_rinc,
  output wire         apb_recv_fifo_full,
  output wire         apb_recv_fifo_empty,
  
  output wire [15:0]  apb_recv_attr_rdata
  
  
);



slink_fifo_top #(
  //parameters
  .ADDR_SIZE          ( SW_ATTR_FIFO_DEPTH ),
  .DATA_SIZE          ( 33                 )
) u_apb_send_fifo (
  .wclk                ( apb_clk                    ),              
  .wreset              ( apb_reset                  ),              
  .winc                ( apb_send_fifo_winc         ),  
  .rclk                ( link_clk                   ),       
  .rreset              ( link_reset                 ),       
  .rinc                ( apb_send_fifo_rinc         ),  
  .wdata               ( {apb_attr_wr,
                          apb_attr_wdata,
                          apb_attr_addr}            ),    
  .rdata               ( {send_attr_wr,
                          send_attr_wdata,
                          send_attr_addr}           ),    
  .wfull               ( apb_send_fifo_full         ),         
  .rempty              ( apb_send_fifo_empty        ),         
  .rbin_ptr            (                            ),  
  .rdiff               (                            ),  
  .wbin_ptr            (                            ),  
  .wdiff               (                            ),  
  .swi_almost_empty    ( {SW_ATTR_FIFO_DEPTH{1'b0}} ),  
  .swi_almost_full     ( {SW_ATTR_FIFO_DEPTH{1'b1}} ),  
  .half_full           (                            ),  
  .almost_empty        (                            ),  
  .almost_full         (                            )); 


slink_fifo_top #(
  //parameters
  .ADDR_SIZE          ( SW_ATTR_FIFO_DEPTH ),
  .DATA_SIZE          ( 16                 )
) u_apb_recv_fifo (
  .wclk                ( link_clk                   ),              
  .wreset              ( link_reset                 ),              
  .winc                ( apb_recv_fifo_winc         ),  
  .rclk                ( link_clk                   ),       
  .rreset              ( link_reset                 ),       
  .rinc                ( apb_recv_fifo_rinc         ),  
  .wdata               ( recv_attr_rdata            ),    
  .rdata               ( apb_recv_attr_rdata        ),    
  .wfull               ( apb_recv_fifo_full         ),         
  .rempty              ( apb_recv_fifo_empty        ),         
  .rbin_ptr            (                            ),  
  .rdiff               (                            ),  
  .wbin_ptr            (                            ),  
  .wdiff               (                            ),  
  .swi_almost_empty    ( {SW_ATTR_FIFO_DEPTH{1'b0}} ),  
  .swi_almost_full     ( {SW_ATTR_FIFO_DEPTH{1'b1}} ),  
  .half_full           (                            ),  
  .almost_empty        (                            ),  
  .almost_full         (                            )); 

endmodule

`timescale 1ns/1ps

module slink_apb_tb_top;


`define MAX_TX_LANES 1
`define MAX_RX_LANES 1

`define MST_PHY_DATA_WIDTH 8
`define SLV_PHY_DATA_WIDTH 8


`define MST_TX_APP_DATA_WIDTH 128
`define MST_RX_APP_DATA_WIDTH 128
`define SLV_TX_APP_DATA_WIDTH 128
`define SLV_RX_APP_DATA_WIDTH 128
`define SERDES_MODE 0

parameter APB_ADDR_WIDTH = 32;

`include "slink_cfg_params.vh"

`include "slink_msg.v"

//Usually shared
`include "slink_inst.vh"

wire                  app_apb_clk;
wire                  app_apb_reset;
wire  [APB_ADDR_WIDTH-1:0]  app_apb_paddr;
wire                  app_apb_pwrite;
wire                  app_apb_psel;
wire                  app_apb_penable;
wire  [31:0]          app_apb_pwdata;
wire [31:0]           app_apb_prdata;
wire                  app_apb_pready;
wire                  app_apb_pslverr;

assign app_apb_clk    = apb_clk;
assign app_apb_reset  = main_reset;


slink_apb_app_driver_monitor #(
  //parameters
  .APB_ADDR_WIDTH     ( 32        )
) u_slink_apb_app_driver_monitor_mst (         
  .interrupt         ( 1'b0          ),  //input -  1              
  .app_apb_clk       ( app_apb_clk        ),  
  .app_apb_reset     ( app_apb_reset      ),  
  .app_apb_paddr     ( app_apb_paddr      ),          
  .app_apb_pwrite    ( app_apb_pwrite     ),  
  .app_apb_psel      ( app_apb_psel       ),  
  .app_apb_penable   ( app_apb_penable    ),  
  .app_apb_pwdata    ( app_apb_pwdata     ),  
  .app_apb_prdata    ( app_apb_prdata     ),  
  .app_apb_pready    ( app_apb_pready     ),  
  .app_apb_pslverr   ( app_apb_pslverr    ),  
      
  .link_apb_clk      ( apb_clk            ),  
  .link_apb_reset    ( mst_apb_reset      ),  
  .link_apb_paddr    ( mst_apb_paddr      ),  
  .link_apb_pwrite   ( mst_apb_pwrite     ),  
  .link_apb_psel     ( mst_apb_psel       ),  
  .link_apb_penable  ( mst_apb_penable    ),  
  .link_apb_pwdata   ( mst_apb_pwdata     ),  
  .link_apb_prdata   ( mst_apb_prdata     ),  
  .link_apb_pready   ( mst_apb_pready     ),  
  .link_apb_pslverr  ( mst_apb_pslverr    )); 


slink_apb_app_driver_monitor #(
  //parameters
  .APB_ADDR_WIDTH     ( 32        )
) u_slink_apb_app_driver_monitor_slv (         
  .interrupt         ( 1'b0          ),  //input -  1              
  .app_apb_clk       (     ),  
  .app_apb_reset     (     ),  
  .app_apb_paddr     (     ),          
  .app_apb_pwrite    (     ),  
  .app_apb_psel      (     ),  
  .app_apb_penable   (     ),  
  .app_apb_pwdata    (     ),  
  .app_apb_prdata    (     ),  
  .app_apb_pready    (     ),  
  .app_apb_pslverr   (     ),  
      
  .link_apb_clk      ( apb_clk            ),  
  .link_apb_reset    ( slv_apb_reset      ),  
  .link_apb_paddr    ( slv_apb_paddr      ),  
  .link_apb_pwrite   ( slv_apb_pwrite     ),  
  .link_apb_psel     ( slv_apb_psel       ),  
  .link_apb_penable  ( slv_apb_penable    ),  
  .link_apb_pwdata   ( slv_apb_pwdata     ),  
  .link_apb_prdata   ( slv_apb_prdata     ),  
  .link_apb_pready   ( slv_apb_pready     ),  
  .link_apb_pslverr  ( slv_apb_pslverr    )); 


slink_apb_tgt #(
  //parameters
  .TX_APP_DATA_WIDTH  ( 128       ),
  .RX_APP_DATA_WIDTH  ( 128       ),
  .APB_WRITE_RSP_DT   ( 8'h33     ),
  .APB_WRITE_DT       ( 8'h32     ),
  .APB_READ_RSP_DT    ( 8'h31     ),
  .APB_READ_DT        ( 8'h30     )
) u_slink_apb_tgt (
  .apb_clk           ( app_apb_clk            ),  
  .apb_reset         ( app_apb_reset          ),  
  .apb_paddr         ( app_apb_paddr          ),  
  .apb_pwrite        ( app_apb_pwrite         ),  
  .apb_psel          ( app_apb_psel           ),  
  .apb_penable       ( app_apb_penable        ),  
  .apb_pwdata        ( app_apb_pwdata         ),  
  .apb_prdata        ( app_apb_prdata         ),    
  .apb_pready        ( app_apb_pready         ),  
  .apb_pslverr       ( app_apb_pslverr        ),  
  .enable            ( ~main_reset            ),  
  .link_clk          ( mst_link_clk           ),  
  .link_reset        ( mst_link_reset         ),  
  .tx_sop            ( mst_tx_sop             ),  
  .tx_data_id        ( mst_tx_data_id         ),  
  .tx_word_count     ( mst_tx_word_count      ),  
  .tx_app_data       ( mst_tx_app_data        ),  
  .tx_advance        ( mst_tx_advance         ),  
  .rx_sop            ( mst_rx_sop             ),  
  .rx_data_id        ( mst_rx_data_id         ),  
  .rx_word_count     ( mst_rx_word_count      ),  
  .rx_app_data       ( mst_rx_app_data        ),  
  .rx_valid          ( mst_rx_valid           ),  
  .rx_crc_corrupted  ( mst_rx_crc_corrupted   )); 


slink_apb_ini #(
  //parameters
  .TX_APP_DATA_WIDTH  ( 128       ),
  .RX_APP_DATA_WIDTH  ( 128       ),
  .APB_WRITE_RSP_DT   ( 8'h33     ),
  .APB_WRITE_DT       ( 8'h32     ),
  .APB_READ_RSP_DT    ( 8'h31     ),
  .APB_READ_DT        ( 8'h30     )
) u_slink_apb_ini (
  .apb_clk           ( app_apb_clk            ),  //input -  1              
  .apb_reset         ( app_apb_reset          ),  //input -  1              
  .apb_paddr         (                        ),  //output - reg [31:0]              
  .apb_pwrite        (                        ),  //output - reg              
  .apb_psel          (                        ),  //output - reg              
  .apb_penable       (                        ),  //output - reg              
  .apb_pwdata        (                        ),  //output - reg [31:0]              
  .apb_prdata        ( 32'hdeadbeef           ),  //input -  [31:0]              
  .apb_pready        ( 1'b1                   ),  //input -  1              
  .apb_pslverr       ( 1'b0                   ),  //input -  1              
  .enable            ( ~main_reset            ),  //input -  1              
  .link_clk          ( slv_link_clk           ),  //input -  1              
  .link_reset        ( slv_link_reset         ),  //input -  1              
  .tx_sop            ( slv_tx_sop             ),  //output - 1              
  .tx_data_id        ( slv_tx_data_id         ),  //output - [7:0]              
  .tx_word_count     ( slv_tx_word_count      ),  //output - [15:0]              
  .tx_app_data       ( slv_tx_app_data        ),  //output - [TX_APP_DATA_WIDTH-1:0]              
  .tx_advance        ( slv_tx_advance         ),  //input -  1              
  .rx_sop            ( slv_rx_sop             ),  //input -  1              
  .rx_data_id        ( slv_rx_data_id         ),  //input -  [7:0]              
  .rx_word_count     ( slv_rx_word_count      ),  //input -  [15:0]              
  .rx_app_data       ( slv_rx_app_data        ),  //input -  [RX_APP_DATA_WIDTH-1:0]              
  .rx_valid          ( slv_rx_valid           ),  //input -  1              
  .rx_crc_corrupted  ( slv_rx_crc_corrupted   )); //input -  1        


bit [31:0] val;
initial begin  
  #1ps;
  main_reset = 1;
  #30ns;
  
  main_reset = 0;
  
  #20ns;  
  //slink_test_select;
  u_slink_apb_app_driver_monitor_mst.link_driver.clr_swreset;
  u_slink_apb_app_driver_monitor_slv.link_driver.clr_swreset;
  u_slink_apb_app_driver_monitor_mst.link_driver.en_slink;
  u_slink_apb_app_driver_monitor_slv.link_driver.en_slink;
  
  #5us;
  
  u_slink_apb_app_driver_monitor_mst.send_apb_write(32'h1234_5678, 32'h4552_abef);
  
  u_slink_apb_app_driver_monitor_mst.send_apb_read(32'hbaba_cdcd, val);
  
  #100ns;
  
  $finish();
end


initial begin
  if($test$plusargs("NO_WAVES")) begin
    `sim_info($display("No waveform saving this sim"))
  end else begin
    $dumpvars(0);
    
  end
  #1ms;
  `sim_fatal($display("sim timeout"));
  $finish();
end



endmodule

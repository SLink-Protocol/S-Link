module slink_apb_app_driver_monitor #(
  parameter APB_ADDR_WIDTH      = 32
) (
  input  wire                        interrupt,
  
  input  wire                        app_apb_clk,
  input  wire                        app_apb_reset,
  output reg  [APB_ADDR_WIDTH-1:0]   app_apb_paddr,
  output reg                         app_apb_pwrite,
  output reg                         app_apb_psel,
  output reg                         app_apb_penable,
  output reg  [31:0]                 app_apb_pwdata,
  input  wire [31:0]                 app_apb_prdata,
  input  wire                        app_apb_pready,
  input  wire                        app_apb_pslverr,
  
  input  wire                        link_apb_clk,
  input  wire                        link_apb_reset,
  output wire [8:0]                  link_apb_paddr,
  output wire                        link_apb_pwrite,
  output wire                        link_apb_psel,
  output wire                        link_apb_penable,
  output wire [31:0]                 link_apb_pwdata,
  input  wire [31:0]                 link_apb_prdata,
  input  wire                        link_apb_pready,
  input  wire                        link_apb_pslverr

);


initial begin
  app_apb_paddr   <= 'd0;
  app_apb_pwrite  <= 1'b0;
  app_apb_psel    <= 1'b0;
  app_apb_penable <= 1'b0;
  app_apb_pwdata  <= 32'd0;
end

task send_apb_write(input bit[APB_ADDR_WIDTH-1:0] addr, input bit[31:0] wdata);
  @(posedge app_apb_clk);
  app_apb_paddr     <= addr;
  app_apb_pwdata    <= wdata;
  app_apb_pwrite    <= 1;
  app_apb_psel      <= 1;
  @(posedge app_apb_clk);
  app_apb_penable   <= 1;
  while(~app_apb_pready) begin
    @(posedge app_apb_clk);
  end
  app_apb_psel      <= 0;
  app_apb_penable   <= 0;
  app_apb_pwrite    <= 0;
endtask


task send_apb_read(input bit[APB_ADDR_WIDTH-1:0] addr, output bit[31:0] rdata);
  @(posedge app_apb_clk);
  app_apb_paddr     <= addr;
  app_apb_psel      <= 1;
  @(posedge app_apb_clk);
  app_apb_penable   <= 1;
  while(~app_apb_pready) begin
    @(posedge app_apb_clk);
  end
  app_apb_psel      <= 0;
  app_apb_penable   <= 0;
  rdata              = app_apb_prdata;    //ensure non-blocking
endtask


// This is just for the software tasks
slink_app_driver #(
  //parameters
  .DRIVER_APP_DATA_WIDTH    ( 32  ),
  .MONITOR_APP_DATA_WIDTH   ( 32  )
) link_driver (
  .link_clk          ( 1'b0                           ), 
  .link_reset        ( 1'b1                           ), 
  .tx_sop            (                                ), 
  .tx_data_id        (                                ), 
  .tx_word_count     (                                ), 
  .tx_app_data       (                                ), 
  .tx_valid          (                                ), 
  .tx_advance        ( 1'b0                           ),
  
  
  .rx_link_clk       ( 1'b0                           ), 
  .rx_link_reset     ( 1'b1                           ),
  .rx_sop            ( 1'b0                           ), 
  .rx_data_id        ( 8'd0                           ), 
  .rx_word_count     ( 16'd0                          ), 
  .rx_app_data       ( {32{1'b0}}                     ),             
  .rx_valid          ( 1'b0                           ),
  .rx_crc_corrupted  ( 1'b0                           ),
  
  .interrupt         ( interrupt                      ),
  
  .apb_clk           ( link_apb_clk                   ), 
  .apb_reset         ( link_apb_reset                 ), 
  .apb_paddr         ( link_apb_paddr                 ), 
  .apb_pwrite        ( link_apb_pwrite                ), 
  .apb_psel          ( link_apb_psel                  ), 
  .apb_penable       ( link_apb_penable               ), 
  .apb_pwdata        ( link_apb_pwdata                ), 
  .apb_prdata        ( link_apb_prdata                ), 
  .apb_pready        ( link_apb_pready                ), 
  .apb_pslverr       ( link_apb_pslverr               ));


endmodule

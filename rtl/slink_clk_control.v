module slink_clk_control #(
  parameter   NUM_RX_LANES  = 4
)(
  input  wire         core_scan_mode,
  input  wire         core_scan_clk,
  input  wire         core_scan_asyncrst_ctrl,
  
  input  wire         apb_clk,
  input  wire         apb_reset,
  
  output wire         apb_clk_scan,
  output wire         apb_reset_scan,
  
  input  wire         refclk,
  input  wire         phy_clk,
  
  input  wire         main_reset,
  input  wire         use_phy_clk,
  
  output wire         refclk_scan,
  output wire         refclk_scan_reset,
  
  input  wire [NUM_RX_LANES-1:0]  rxclk_in,
  output wire [NUM_RX_LANES-1:0]  rxclk_out,
  output wire [NUM_RX_LANES-1:0]  rxclk_reset_out,
  
  output wire         link_clk,
  output wire         link_clk_reset
  
);


slink_clock_mux u_slink_clock_mux_apb_clk (
  .clk0    ( apb_clk            ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( apb_clk_scan       )); 

slink_reset_sync u_slink_reset_sync_apb_reset (
  .clk           ( apb_clk_scan             ),      
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),      
  .reset_in      ( apb_reset                ),      
  .reset_out     ( apb_reset_scan           )); 


//wire refclk_scan;
slink_clock_mux u_slink_clock_mux_ref_clk (
  .clk0    ( refclk             ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( refclk_scan        )); 

//wire main_reset_ref_clk_scan;
slink_reset_sync u_slink_reset_sync_main_reset_ref_clk (
  .clk           ( refclk_scan              ),      
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),      
  .reset_in      ( main_reset               ),      
  .reset_out     ( refclk_scan_reset        )); 


wire phy_clk_scan;
slink_clock_mux u_slink_clock_mux_phy_clk (
  .clk0    ( phy_clk            ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( phy_clk_scan       )); 

wire main_reset_phy_clk_scan;
slink_reset_sync u_slink_reset_sync_main_reset_phy_clk (
  .clk           ( phy_clk_scan             ),      
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),      
  .reset_in      ( main_reset               ),      
  .reset_out     ( main_reset_phy_clk_scan  )); 



genvar laneindex;
generate
  for(laneindex = 0; laneindex < NUM_RX_LANES; laneindex = laneindex + 1) begin : gen_rx_clock_muxes
    slink_clock_mux u_slink_clock_mux_rxclk (
      .clk0    ( rxclk_in[laneindex]  ),   
      .clk1    ( core_scan_clk        ),   
      .sel     ( core_scan_mode       ),   
      .clk_out ( rxclk_out[laneindex] )); 

    slink_reset_sync u_slink_reset_sync_rxclk_reset (
      .clk           ( rxclk_out[laneindex]       ),      
      .scan_ctrl     ( core_scan_asyncrst_ctrl    ),      
      .reset_in      ( main_reset                 ),      
      .reset_out     ( rxclk_reset_out[laneindex] )); 
  end
endgenerate


wire link_clk_pre_scan;
slink_clock_mux_sync u_slink_clock_mux_sync (
  .reset0    ( refclk_scan_reset           ),               
  .reset1    ( main_reset_phy_clk_scan     ),               
  .sel       ( use_phy_clk                 ),               
  .clk0      ( refclk_scan                 ),               
  .clk1      ( phy_clk_scan                ),               
  .clk_out   ( link_clk_pre_scan           )); 


slink_clock_mux u_slink_clock_mux_link_clk (
  .clk0    ( link_clk_pre_scan  ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( link_clk           )); 

slink_reset_sync u_slink_reset_sync_link_clk_reset (
  .clk           ( link_clk                 ),      
  .scan_ctrl     ( core_scan_asyncrst_ctrl  ),      
  .reset_in      ( main_reset               ),      
  .reset_out     ( link_clk_reset           )); 

endmodule

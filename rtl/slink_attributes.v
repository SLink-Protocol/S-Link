


module slink_attribute_base #(
  parameter ADDR      = 16'h0,
  parameter WIDTH     = 1,
  parameter RESET_VAL = {WIDTH{1'b0}},
  parameter NAME      = "unNamed",
  parameter IS_RO     = 0
)(
  input  wire             clk,
  input  wire             reset,
  
  input  wire             hard_reset_cond,
  
  input  wire [15:0]      link_attr_addr,
  input  wire [15:0]      link_attr_data,
  input  wire             link_shadow_update,        //Asserts to take the addr/data check
  
  input  wire [15:0]      app_attr_addr,
  input  wire [15:0]      app_attr_data,
  input  wire             app_shadow_update,
  
  input  wire [15:0]      sw_attr_addr,
  input  wire [15:0]      sw_attr_data,
  input  wire             sw_shadow_update,
  
  
  input  wire             effective_update,     //Asserts to update effective to shadow value
  
  output reg  [WIDTH-1:0] shadow_reg,
  output reg  [WIDTH-1:0] effective_reg
);

generate

  if(IS_RO==1) begin
    //"_int" variables just to keep iverilog warnings about no sensitivity list items
    wire [WIDTH-1:0] shadow_reg_int;
    wire [WIDTH-1:0] effective_reg_int;
    
    assign shadow_reg_int     = RESET_VAL;
    assign effective_reg_int  = RESET_VAL;
    
    always @(*) begin
      shadow_reg    = shadow_reg_int;
      effective_reg = effective_reg_int;
    end
  end else begin
    wire link_attr_update;
    wire app_attr_update;
    wire sw_attr_update;

    assign link_attr_update = link_shadow_update  && (link_attr_addr == ADDR);
    assign app_attr_update  = app_shadow_update   && (app_attr_addr  == ADDR);
    assign sw_attr_update   = sw_shadow_update    && (sw_attr_addr   == ADDR);

    always @(posedge clk or posedge reset) begin
      if(reset) begin
        effective_reg     <= RESET_VAL;
        shadow_reg        <= RESET_VAL;
      end else begin
        effective_reg     <= hard_reset_cond  ? RESET_VAL      : 
                             effective_update ? shadow_reg     : effective_reg;

        shadow_reg        <= hard_reset_cond  ? RESET_VAL      :
                             link_attr_update ? link_attr_data : 
                             app_attr_update  ? app_attr_data  :
                             sw_attr_update   ? sw_attr_data   : shadow_reg;

        `ifdef SIMULATION
          if(link_attr_update) begin
            $display("SLink Attribute Shadow Update (link): %s -> %4h", NAME, link_attr_data);
          end else if(app_attr_update) begin
            $display("SLink Attribute Shadow Update (app): %s -> %4h", NAME,  app_attr_data);
          end else if(sw_attr_update) begin
            $display("SLink Attribute Shadow Update (sw): %s -> %4h", NAME,   sw_attr_data);
          end
        `endif
      end
    end
  end
endgenerate


endmodule

module slink_attributes #(
  parameter NUM_TX_LANES_CLOG2 = 2,
  parameter NUM_RX_LANES_CLOG2 = 2
)(
  //Attributes
  output wire [2:0]   attr_max_txs,
  output wire [2:0]   attr_max_rxs,
  output wire [2:0]   attr_active_txs,
  output wire [2:0]   attr_active_rxs,
  output wire [9:0]   attr_hard_reset_us,
  output wire [7:0]   attr_px_clk_trail,
  output wire [15:0]  attr_p1_ts1_tx,
  output wire [15:0]  attr_p1_ts1_rx,
  output wire [15:0]  attr_p1_ts2_tx,
  output wire [15:0]  attr_p1_ts2_rx,
  output wire [15:0]  attr_p2_ts1_tx,
  output wire [15:0]  attr_p2_ts1_rx,
  output wire [15:0]  attr_p2_ts2_tx,
  output wire [15:0]  attr_p2_ts2_rx,
  output wire [15:0]  attr_p3r_ts1_tx,
  output wire [15:0]  attr_p3r_ts1_rx,
  output wire [15:0]  attr_p3r_ts2_tx,
  output wire [15:0]  attr_p3r_ts2_rx,
  output wire [7:0]   attr_sync_freq,

  
  input  wire         clk,
  input  wire         reset,
  input  wire         hard_reset_cond,
  input  wire [15:0]  link_attr_addr,
  input  wire [15:0]  link_attr_data,
  input  wire         link_shadow_update,
  output reg  [15:0]  link_attr_data_read,
  
  input  wire [15:0]  app_attr_addr,
  input  wire [15:0]  app_attr_data,
  input  wire         app_shadow_update,
  output reg  [15:0]  app_attr_data_read,
  
  input  wire [15:0]  sw_attr_addr,
  input  wire [15:0]  sw_attr_data,
  input  wire         sw_shadow_update,
  output reg  [15:0]  sw_attr_data_read,
  
  input  wire         effective_update
);

  
wire [2:0] max_txs_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h0                      ),
  .NAME                ( "max_txs"                ),
  .WIDTH               ( 3                        ),
  .RESET_VAL           ( NUM_TX_LANES_CLOG2       ),
  .IS_RO               (                        1 )
) u_slink_attribute_base_max_txs (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( max_txs_shadow           ),       
  .effective_reg       ( attr_max_txs             )); 

  
wire [2:0] max_rxs_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h1                      ),
  .NAME                ( "max_rxs"                ),
  .WIDTH               ( 3                        ),
  .RESET_VAL           ( NUM_RX_LANES_CLOG2       ),
  .IS_RO               (                        1 )
) u_slink_attribute_base_max_rxs (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( max_rxs_shadow           ),       
  .effective_reg       ( attr_max_rxs             )); 

  
wire [2:0] active_txs_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h2                      ),
  .NAME                ( "active_txs"             ),
  .WIDTH               ( 3                        ),
  .RESET_VAL           ( NUM_TX_LANES_CLOG2       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_active_txs (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( active_txs_shadow        ),       
  .effective_reg       ( attr_active_txs          )); 

  
wire [2:0] active_rxs_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h3                      ),
  .NAME                ( "active_rxs"             ),
  .WIDTH               ( 3                        ),
  .RESET_VAL           ( NUM_RX_LANES_CLOG2       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_active_rxs (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( active_rxs_shadow        ),       
  .effective_reg       ( attr_active_rxs          )); 

  
wire [9:0] hard_reset_us_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h8                      ),
  .NAME                ( "hard_reset_us"          ),
  .WIDTH               ( 10                       ),
  .RESET_VAL           ( 100                      ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_hard_reset_us (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( hard_reset_us_shadow     ),       
  .effective_reg       ( attr_hard_reset_us       )); 

  
wire [7:0] px_clk_trail_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h10                     ),
  .NAME                ( "px_clk_trail"           ),
  .WIDTH               ( 8                        ),
  .RESET_VAL           ( 32                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_px_clk_trail (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( px_clk_trail_shadow      ),       
  .effective_reg       ( attr_px_clk_trail        )); 

  
wire [15:0] p1_ts1_tx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h20                     ),
  .NAME                ( "p1_ts1_tx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 32                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p1_ts1_tx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p1_ts1_tx_shadow         ),       
  .effective_reg       ( attr_p1_ts1_tx           )); 

  
wire [15:0] p1_ts1_rx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h21                     ),
  .NAME                ( "p1_ts1_rx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 32                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p1_ts1_rx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p1_ts1_rx_shadow         ),       
  .effective_reg       ( attr_p1_ts1_rx           )); 

  
wire [15:0] p1_ts2_tx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h22                     ),
  .NAME                ( "p1_ts2_tx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 4                        ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p1_ts2_tx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p1_ts2_tx_shadow         ),       
  .effective_reg       ( attr_p1_ts2_tx           )); 

  
wire [15:0] p1_ts2_rx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h23                     ),
  .NAME                ( "p1_ts2_rx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 4                        ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p1_ts2_rx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p1_ts2_rx_shadow         ),       
  .effective_reg       ( attr_p1_ts2_rx           )); 

  
wire [15:0] p2_ts1_tx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h24                     ),
  .NAME                ( "p2_ts1_tx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 64                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p2_ts1_tx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p2_ts1_tx_shadow         ),       
  .effective_reg       ( attr_p2_ts1_tx           )); 

  
wire [15:0] p2_ts1_rx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h25                     ),
  .NAME                ( "p2_ts1_rx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 64                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p2_ts1_rx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p2_ts1_rx_shadow         ),       
  .effective_reg       ( attr_p2_ts1_rx           )); 

  
wire [15:0] p2_ts2_tx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h26                     ),
  .NAME                ( "p2_ts2_tx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 8                        ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p2_ts2_tx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p2_ts2_tx_shadow         ),       
  .effective_reg       ( attr_p2_ts2_tx           )); 

  
wire [15:0] p2_ts2_rx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h27                     ),
  .NAME                ( "p2_ts2_rx"              ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 8                        ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p2_ts2_rx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p2_ts2_rx_shadow         ),       
  .effective_reg       ( attr_p2_ts2_rx           )); 

  
wire [15:0] p3r_ts1_tx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h28                     ),
  .NAME                ( "p3r_ts1_tx"             ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 128                      ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p3r_ts1_tx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p3r_ts1_tx_shadow        ),       
  .effective_reg       ( attr_p3r_ts1_tx          )); 

  
wire [15:0] p3r_ts1_rx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h29                     ),
  .NAME                ( "p3r_ts1_rx"             ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 128                      ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p3r_ts1_rx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p3r_ts1_rx_shadow        ),       
  .effective_reg       ( attr_p3r_ts1_rx          )); 

  
wire [15:0] p3r_ts2_tx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h2a                     ),
  .NAME                ( "p3r_ts2_tx"             ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 16                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p3r_ts2_tx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p3r_ts2_tx_shadow        ),       
  .effective_reg       ( attr_p3r_ts2_tx          )); 

  
wire [15:0] p3r_ts2_rx_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h2b                     ),
  .NAME                ( "p3r_ts2_rx"             ),
  .WIDTH               ( 16                       ),
  .RESET_VAL           ( 16                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_p3r_ts2_rx (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( p3r_ts2_rx_shadow        ),       
  .effective_reg       ( attr_p3r_ts2_rx          )); 

  
wire [7:0] sync_freq_shadow;
slink_attribute_base #(
  //parameters
  .ADDR                ( 'h30                     ),
  .NAME                ( "sync_freq"              ),
  .WIDTH               ( 8                        ),
  .RESET_VAL           ( 15                       ),
  .IS_RO               (                        0 )
) u_slink_attribute_base_sync_freq (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( sync_freq_shadow         ),       
  .effective_reg       ( attr_sync_freq           )); 

always @(*) begin
  case(link_attr_addr)
    16'h0    : link_attr_data_read = {13'd0, max_txs_shadow};
    16'h1    : link_attr_data_read = {13'd0, max_rxs_shadow};
    16'h2    : link_attr_data_read = {13'd0, active_txs_shadow};
    16'h3    : link_attr_data_read = {13'd0, active_rxs_shadow};
    16'h8    : link_attr_data_read = {6'd0, hard_reset_us_shadow};
    16'h10   : link_attr_data_read = {8'd0, px_clk_trail_shadow};
    16'h20   : link_attr_data_read = {p1_ts1_tx_shadow};
    16'h21   : link_attr_data_read = {p1_ts1_rx_shadow};
    16'h22   : link_attr_data_read = {p1_ts2_tx_shadow};
    16'h23   : link_attr_data_read = {p1_ts2_rx_shadow};
    16'h24   : link_attr_data_read = {p2_ts1_tx_shadow};
    16'h25   : link_attr_data_read = {p2_ts1_rx_shadow};
    16'h26   : link_attr_data_read = {p2_ts2_tx_shadow};
    16'h27   : link_attr_data_read = {p2_ts2_rx_shadow};
    16'h28   : link_attr_data_read = {p3r_ts1_tx_shadow};
    16'h29   : link_attr_data_read = {p3r_ts1_rx_shadow};
    16'h2a   : link_attr_data_read = {p3r_ts2_tx_shadow};
    16'h2b   : link_attr_data_read = {p3r_ts2_rx_shadow};
    16'h30   : link_attr_data_read = {8'd0, sync_freq_shadow};
    default  : link_attr_data_read = 16'd0;
  endcase
end

always @(*) begin
  case(app_attr_addr)
    16'h0    : app_attr_data_read = {13'd0, max_txs_shadow};
    16'h1    : app_attr_data_read = {13'd0, max_rxs_shadow};
    16'h2    : app_attr_data_read = {13'd0, active_txs_shadow};
    16'h3    : app_attr_data_read = {13'd0, active_rxs_shadow};
    16'h8    : app_attr_data_read = {6'd0, hard_reset_us_shadow};
    16'h10   : app_attr_data_read = {8'd0, px_clk_trail_shadow};
    16'h20   : app_attr_data_read = {p1_ts1_tx_shadow};
    16'h21   : app_attr_data_read = {p1_ts1_rx_shadow};
    16'h22   : app_attr_data_read = {p1_ts2_tx_shadow};
    16'h23   : app_attr_data_read = {p1_ts2_rx_shadow};
    16'h24   : app_attr_data_read = {p2_ts1_tx_shadow};
    16'h25   : app_attr_data_read = {p2_ts1_rx_shadow};
    16'h26   : app_attr_data_read = {p2_ts2_tx_shadow};
    16'h27   : app_attr_data_read = {p2_ts2_rx_shadow};
    16'h28   : app_attr_data_read = {p3r_ts1_tx_shadow};
    16'h29   : app_attr_data_read = {p3r_ts1_rx_shadow};
    16'h2a   : app_attr_data_read = {p3r_ts2_tx_shadow};
    16'h2b   : app_attr_data_read = {p3r_ts2_rx_shadow};
    16'h30   : app_attr_data_read = {8'd0, sync_freq_shadow};
    default  : app_attr_data_read = 16'd0;
  endcase
end

always @(*) begin
  case(sw_attr_addr)
    16'h0    : sw_attr_data_read = {13'd0, max_txs_shadow};
    16'h1    : sw_attr_data_read = {13'd0, max_rxs_shadow};
    16'h2    : sw_attr_data_read = {13'd0, active_txs_shadow};
    16'h3    : sw_attr_data_read = {13'd0, active_rxs_shadow};
    16'h8    : sw_attr_data_read = {6'd0, hard_reset_us_shadow};
    16'h10   : sw_attr_data_read = {8'd0, px_clk_trail_shadow};
    16'h20   : sw_attr_data_read = {p1_ts1_tx_shadow};
    16'h21   : sw_attr_data_read = {p1_ts1_rx_shadow};
    16'h22   : sw_attr_data_read = {p1_ts2_tx_shadow};
    16'h23   : sw_attr_data_read = {p1_ts2_rx_shadow};
    16'h24   : sw_attr_data_read = {p2_ts1_tx_shadow};
    16'h25   : sw_attr_data_read = {p2_ts1_rx_shadow};
    16'h26   : sw_attr_data_read = {p2_ts2_tx_shadow};
    16'h27   : sw_attr_data_read = {p2_ts2_rx_shadow};
    16'h28   : sw_attr_data_read = {p3r_ts1_tx_shadow};
    16'h29   : sw_attr_data_read = {p3r_ts1_rx_shadow};
    16'h2a   : sw_attr_data_read = {p3r_ts2_tx_shadow};
    16'h2b   : sw_attr_data_read = {p3r_ts2_rx_shadow};
    16'h30   : sw_attr_data_read = {8'd0, sync_freq_shadow};
    default  : sw_attr_data_read = 16'd0;
  endcase
end
endmodule
/*
.rst_start
slink_generic_pstate_ctrl
-------------------------
Implements a simple timer-based Pstate controller. Link activity resets the timer. If 
timer expires then the link goes into the lowest selected PState.

.rst_end
*/


module slink_generic_pstate_ctrl(
  input  wire             refclk,               
  input  wire             refclk_reset,
  input  wire             enable,
  
  input  wire             link_clk,               
  input  wire             link_clk_reset,
  input  wire             link_active,
  input  wire             in_px_state,
  
  input  wire [7:0]       swi_1us_tick_count,
  input  wire [7:0]       swi_inactivity_count,
  input  wire [2:0]       swi_pstate_req,
  
  output reg              p1_req,
  output reg              p2_req,
  output reg              p3_req
);

wire              enable_ff2;
wire              in_px_state_ff2;
reg               in_px_state_ff3;
wire              px_state_exit;
reg   [7:0]       count_1us;
wire  [7:0]       count_1us_in;
wire              count_1us_tick;
reg   [7:0]       inactivity_count;
wire  [7:0]       inactivity_count_in;
wire              inactivity_time_reached;
wire              p1_req_in;
wire              p2_req_in;
wire              p3_req_in;


slink_demet_reset u_slink_demet_reset (
  .clk     ( refclk           ),  
  .reset   ( refclk_reset     ),  
  .sig_in  ( enable           ),  
  .sig_out ( enable_ff2       ));

slink_demet_reset u_slink_demet_reset_in_px_state (
  .clk     ( refclk           ),  
  .reset   ( refclk_reset     ),  
  .sig_in  ( in_px_state      ),  
  .sig_out ( in_px_state_ff2  ));


wire link_acitve_sync;
wire link_acitve_valid;
wire link_acitve_refclk;

slink_multibit_sync #(.DATA_SIZE(1)) u_slink_multibit_sync (
  .wclk    ( link_clk         ),                      
  .wreset  ( link_clk_reset   ),                      
  .winc    ( link_active      ),                      
  .wready  (                  ),                      
  .wdata   ( link_active      ),                      
            
  .rclk    ( refclk           ),                  
  .rreset  ( refclk_reset     ),                  
  .rinc    ( 1'b1             ),                  
  .rready  ( link_acitve_valid),      
  .rdata   ( link_acitve_sync )); 

assign link_acitve_refclk = (link_acitve_valid && link_acitve_sync) || px_state_exit;


always @(posedge refclk or posedge refclk_reset) begin
  if(refclk_reset) begin
    count_1us         <= 8'd0;
    inactivity_count  <= 8'd0;
    p1_req            <= 1'b0;
    p2_req            <= 1'b0;
    p3_req            <= 1'b0;
    in_px_state_ff3   <= 1'b0;
  end else begin
    count_1us         <= count_1us_in;
    inactivity_count  <= inactivity_count_in;
    p1_req            <= p1_req_in;
    p2_req            <= p2_req_in;
    p3_req            <= p3_req_in;
    in_px_state_ff3   <= in_px_state_ff2;
  end
end

assign px_state_exit = ~in_px_state_ff2 & in_px_state_ff3;

assign count_1us_tick           = count_1us == swi_1us_tick_count;
assign count_1us_in             = ~enable_ff2 ? 8'd0 : count_1us_tick ? 8'd0 : count_1us + 8'd1;
assign inactivity_time_reached  = (inactivity_count == swi_inactivity_count);
assign inactivity_count_in      = ~enable_ff2 || link_acitve_refclk ? 8'd0 : count_1us_tick ? (inactivity_time_reached ? inactivity_count : inactivity_count + 8'd1) : inactivity_count;


assign p3_req_in                = inactivity_time_reached && swi_pstate_req[2];
assign p2_req_in                = inactivity_time_reached && swi_pstate_req[1] && ~p3_req_in;
assign p1_req_in                = inactivity_time_reached && swi_pstate_req[0] && ~p2_req_in;

endmodule

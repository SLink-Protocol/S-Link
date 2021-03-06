module slink_ltssm #(
  parameter DATA_WIDTH      = 8,
  parameter NUM_TX_LANES    = 4,
  parameter NUM_RX_LANES    = 4,
  parameter REGISTER_TXDATA = 1                       //registers output data to phy for timing
)(
  input  wire                                 clk,
  input  wire                                 reset,
  
  input  wire                                 refclk,
  input  wire                                 refclk_reset,
  
  input  wire                                 enable,
  
  input  wire [15:0]                          p1_ts1_tx_count,
  input  wire [15:0]                          p1_ts1_rx_count,
  input  wire [15:0]                          p1_ts2_tx_count,
  input  wire [15:0]                          p1_ts2_rx_count,
  input  wire [15:0]                          p2_ts1_tx_count,
  input  wire [15:0]                          p2_ts1_rx_count,
  input  wire [15:0]                          p2_ts2_tx_count,
  input  wire [15:0]                          p2_ts2_rx_count,
  input  wire [15:0]                          p3r_ts1_tx_count,
  input  wire [15:0]                          p3r_ts1_rx_count,
  input  wire [15:0]                          p3r_ts2_tx_count,
  input  wire [15:0]                          p3r_ts2_rx_count,
  input  wire [15:0]                          px_clk_trail,
  input  wire [15:0]                          swi_clk_switch_time,
  input  wire [15:0]                          swi_p0_exit_time,
  input  wire [7:0]                           attr_sync_freq,
  
  input  wire [2:0]                           active_rx_lanes,
  input  wire [2:0]                           active_tx_lanes,
  
  output reg                                  use_phy_clk,
  
  input  wire [NUM_RX_LANES-1:0]              rx_ts1_seen,
  input  wire [NUM_RX_LANES-1:0]              rx_ts2_seen,
  input  wire [NUM_RX_LANES-1:0]              rx_sds_seen,
  output reg                                  sds_sent,
  output reg                                  deskew_enable,
  
  
  input  wire                                 link_p1_req,
  input  wire                                 link_p2_req,
  input  wire                                 link_p3_req,
  input  wire                                 link_px_req_pkt,
  input  wire                                 link_px_start_pkt,
  output reg                                  in_px_state,
  output reg                                  effect_update,
  
  input  wire                                 link_active_req,
  output reg                                  link_wake_n,
  input  wire                                 link_reset_req,
  input  wire                                 link_reset_req_local,
  output reg                                  link_reset_n,
  input  wire [9:0]                           swi_count_val_1us,
  input  wire [9:0]                           attr_hard_reset_us,
  output wire                                 link_hard_reset_cond,
  output reg                                  in_reset_state,
  
  // Attribute
  input  wire                                 attr_ready,
  input  wire [15:0]                          attr_addr,
  input  wire [15:0]                          attr_wdata,
  input  wire                                 attr_write,
  output reg                                  attr_sent,
  
    
  // SerDes Controls
  output reg                                  phy_clk_en,
  output reg                                  phy_clk_idle,     //Clock up but not transmitting
  input  wire                                 phy_clk_ready,    //Clock 
  
  output wire [NUM_TX_LANES-1:0]              phy_tx_en,
  
  input  wire [NUM_TX_LANES-1:0]              phy_tx_ready,     //indicates the TX is up and ready to start data transmission
  input  wire [NUM_TX_LANES-1:0]              phy_tx_dirdy,     //Data can be accepted this cycle
  
  output wire [NUM_RX_LANES-1:0]              phy_rx_en,
  input  wire [NUM_RX_LANES-1:0]              phy_rx_ready,     //indicates the RX is up and ready to start data reception
  input  wire [NUM_RX_LANES-1:0]              phy_rx_valid,     //byte lock has been acquired
  input  wire [NUM_RX_LANES-1:0]              phy_rx_dordy,     //Data is valid this cycle ( should this be here?)
  output wire [NUM_RX_LANES-1:0]              phy_rx_align,     //perform byte alignment alignment
  
  // Data from Link Layer
  input  wire [(NUM_TX_LANES*DATA_WIDTH)-1:0] link_data,
  input  wire                                 ll_tx_idle,
  output wire                                 ll_tx_valid,     
  output reg                                  ll_enable,
  
  // Data to Lane Stripe
  output wire [(NUM_TX_LANES*DATA_WIDTH)-1:0] ltssm_data,
  output wire [4:0]                           ltssm_state
);


`include "slink_includes.vh"

localparam    IDLE            = 'd0,
              WAIT_CLK        = 'd1,
              SWITCH          = 'd2,
              P0_TS1          = 'd3,
              P0_TS2          = 'd4,
              P0_SDS          = 'd5,
              P0              = 'd6,
              P0_EXIT         = 'd7,
              P1              = 'd8,
              P1_EXIT         = 'd9,
              P0_P2_CLK_TRAIL = 'd10,
              P2              = 'd11,
              P2_EXIT         = 'd12,
              P0_P3_CLK_TRAIL = 'd13,
              P3              = 'd14,
              RESET_ENTER     = 'd15,
              RESET_ST        = 'd16,
              PX_REQ_ST       = 'd17,
              PX_START_ST     = 'd18,
              ATTR_ST         = 'd19;




reg   [4:0]               state, nstate;
wire                      enable_ff2;
reg                       use_phy_clk_in;
wire                      phy_clk_ready_ff2;
wire  [NUM_TX_LANES-1:0]  phy_tx_ready_ff2;
wire  [NUM_RX_LANES-1:0]  phy_rx_ready_ff2;
reg   [15:0]              count, count_in;
reg   [3:0]               byte_count, byte_count_in;
wire                      byte_count_end;
reg                       ltssm_data_active, ltssm_data_active_in;
reg   [DATA_WIDTH-1:0]    ltssm_lane_data;
reg                       phy_rx_align_reg, phy_rx_align_reg_in;

reg   [15:0]              rx_ts1_count;
wire  [15:0]              rx_ts1_count_in;
reg   [15:0]              rx_ts2_count;
wire  [15:0]              rx_ts2_count_in;
reg                       rx_sds_seen_reg, rx_sds_seen_reg_in;
wire                      rx_p0_sds_qualifier;
wire                      rx_p0_ts2_qualifier;
reg                       deskew_enable_in;
reg                       link_wake_n_in;    
reg                       link_reset_n_in;
reg   [1:0]               px_exit_state, px_exit_state_in;


wire [15:0]               px_ts1_tx_count;
wire [15:0]               px_ts1_rx_count;
wire [15:0]               px_ts2_tx_count;
wire [15:0]               px_ts2_rx_count;

reg                       phy_clk_en_in;
reg                       phy_clk_idle_in;
reg                       enable_lanes, enable_lanes_in;
reg                       effect_update_in;

reg   [3:0]               block_count;
reg   [3:0]               block_count_in;
wire                      block_count_end;
reg   [7:0]               sync_count;
reg   [7:0]               sync_count_in;
reg                       stall_cycle;
reg                       stall_cycle_in;
reg                       sending_sync;
reg                       sending_sync_in;
wire                      enable_gearbox;
reg   [1:0]               tx_syncheader;
reg                       ll_enable_in;

reg                       link_px_req_recv, link_px_req_recv_in;
reg                       link_px_start_recv, link_px_start_recv_in;
reg   [2:0]               link_px_req_reg, link_px_req_reg_in;


slink_demet_reset u_slink_demet_reset_enable (
  .clk     ( clk         ),          
  .reset   ( reset       ),          
  .sig_in  ( enable      ),          
  .sig_out ( enable_ff2  )); 

slink_demet_reset u_slink_demet_reset_phy_clk_ready (
  .clk     ( clk                ),          
  .reset   ( reset              ),          
  .sig_in  ( phy_clk_ready      ),          
  .sig_out ( phy_clk_ready_ff2  )); 

wire                      all_tx_ready;
wire  [NUM_TX_LANES-1:0]  tx_lane_active;
wire                      all_rx_ready;
wire  [NUM_RX_LANES-1:0]  rx_lane_active;

slink_demet_reset u_slink_demet_reset_phy_tx_ready[NUM_TX_LANES-1:0] (
  .clk     ( clk                ),          
  .reset   ( reset              ),          
  .sig_in  ( phy_tx_ready       ),          
  .sig_out ( phy_tx_ready_ff2   )); 
  
slink_demet_reset u_slink_demet_reset_phy_rx_ready[NUM_RX_LANES-1:0] (
  .clk     ( clk                ),          
  .reset   ( reset              ),          
  .sig_in  ( phy_rx_ready       ),          
  .sig_out ( phy_rx_ready_ff2   )); 
  

genvar txlaneindex;
genvar rxlaneindex;
generate
  for(txlaneindex = 0; txlaneindex < NUM_TX_LANES; txlaneindex = txlaneindex + 1) begin : ltssm_tx_ready_gen
    assign tx_lane_active[txlaneindex] = txlaneindex < (1 << active_tx_lanes);
  end
  
  for(rxlaneindex = 0; rxlaneindex < NUM_RX_LANES; rxlaneindex = rxlaneindex + 1) begin : ltssm_rx_ready_gen
    assign rx_lane_active[rxlaneindex] = rxlaneindex < (1 << active_rx_lanes);
  end
endgenerate

assign all_tx_ready = tx_lane_active == phy_tx_ready_ff2;
assign all_rx_ready = rx_lane_active == phy_rx_ready_ff2;


assign phy_tx_en    = tx_lane_active & {NUM_TX_LANES{enable_lanes}};
assign phy_rx_en    = rx_lane_active & {NUM_RX_LANES{enable_lanes}};


always @(posedge clk or posedge reset) begin
  if(reset) begin
    state               <= IDLE;
    use_phy_clk         <= 1'b0;
    count               <= 'd0;
    byte_count          <= 'd0;
    ltssm_data_active   <= 1'b1;
    phy_rx_align_reg    <= 1'b0;
    rx_ts1_count        <= 'd0;
    rx_ts2_count        <= 'd0;
    rx_sds_seen_reg     <= 1'b0;
    deskew_enable       <= 1'b0;
    link_wake_n         <= 1'b1;
    link_reset_n        <= 1'b1;
    px_exit_state       <= 2'd0;
    phy_clk_en          <= 1'b0;
    phy_clk_idle        <= 1'b0;
    enable_lanes        <= 1'b0;
    effect_update       <= 1'b0;
    in_px_state         <= 1'b0;
    in_reset_state      <= 1'b0;
    block_count         <= 'd0;
    sync_count          <= 'd0;
    stall_cycle         <= 1'b0;
    sending_sync        <= 1'b0;
    ll_enable           <= 1'b0;
    link_px_req_recv    <= 1'b0;
    link_px_start_recv  <= 1'b0;
    link_px_req_reg     <= 3'd0;
  end else begin
    state               <= nstate;
    use_phy_clk         <= use_phy_clk_in;
    count               <= count_in;
    byte_count          <= byte_count_in;
    ltssm_data_active   <= ltssm_data_active_in;
    phy_rx_align_reg    <= phy_rx_align_reg_in;
    rx_ts1_count        <= rx_ts1_count_in;
    rx_ts2_count        <= rx_ts2_count_in;
    rx_sds_seen_reg     <= rx_sds_seen_reg_in;
    deskew_enable       <= deskew_enable_in;
    link_wake_n         <= link_wake_n_in;
    link_reset_n        <= link_reset_n_in;
    px_exit_state       <= px_exit_state_in;
    phy_clk_en          <= phy_clk_en_in;
    phy_clk_idle        <= phy_clk_idle_in;
    enable_lanes        <= enable_lanes_in;
    effect_update       <= effect_update_in;
    in_px_state         <= (state == P1) || (state == P2) || (state == P3);
    in_reset_state      <= (state == RESET_ENTER) || (state == RESET_ST);
    block_count         <= block_count_in;
    sync_count          <= sync_count_in;
    stall_cycle         <= stall_cycle_in;
    sending_sync        <= sending_sync_in;
    ll_enable           <= ll_enable_in;
    link_px_req_recv    <= link_px_req_recv_in;
    link_px_start_recv  <= link_px_start_recv_in;
    link_px_req_reg     <= link_px_req_reg_in;
  end
end 

assign ltssm_state        = state;


assign enable_gearbox = (state == P0_TS1)       ||
                        (state == P0_TS2)       ||
                        (state == P0_SDS)       ||
                        (state == P0)           || 
                        (state == PX_REQ_ST)    ||
                        (state == PX_START_ST)  ||
                        (state == ATTR_ST)      ||
                        (state == P0_EXIT);

always @(*) begin
  if(enable_gearbox) begin
    if(stall_cycle) begin
      stall_cycle_in    = 1'b0;
      byte_count_in     = 'd0;
      block_count_in    = 'd0;
    end else begin
      byte_count_in     = byte_count_end ? 'd0 :
                          (DATA_WIDTH ==  8) ? byte_count + 'd1 :
                          (DATA_WIDTH == 16) ? byte_count + 'd2 : byte_count + 'd4;
      block_count_in    = byte_count_end ? (block_count_end ? 'd0 : block_count + 'd1) : block_count;
      stall_cycle_in    = byte_count_end && block_count_end;
    end
  end else begin
    byte_count_in       = 'd0;
    block_count_in      = 'd0;
    stall_cycle_in      = 1'b0;
  end
end
                                    
assign byte_count_end   = (DATA_WIDTH == 8)  ? (byte_count == 'd15) :
                          (DATA_WIDTH == 16) ? (byte_count == 'd14) : (byte_count == 'd12);

assign block_count_end  = (DATA_WIDTH == 8)  ? block_count == 'd3 :                  
                          (DATA_WIDTH == 16) ? block_count == 'd7 : 'd15;

assign tx_startblock    = enable_gearbox && (byte_count == 'd0) && ~stall_cycle;
assign tx_datavalid     = enable_gearbox && ~stall_cycle;

assign ll_tx_valid      = (tx_datavalid && (state == P0)) || sds_sent; //needs more than this?



assign rx_ts1_count_in  = (state == P0_TS1)                      ? (&rx_ts1_seen ? &rx_ts1_count ? rx_ts1_count : rx_ts1_count + 'd1 : rx_ts1_count) : 'd0;
assign rx_ts2_count_in  = (state == P0_TS1) || (state == P0_TS2) ? (&rx_ts2_seen ? &rx_ts2_count ? rx_ts2_count : rx_ts2_count + 'd1 : rx_ts2_count) : 'd0;

assign rx_p0_sds_qualifier = rx_sds_seen_reg_in || rx_sds_seen_reg;
assign rx_p0_ts2_qualifier = (|rx_ts2_count);


assign px_ts1_tx_count  = px_exit_state == 2'b01  ? p1_ts1_tx_count :
                          px_exit_state == 2'b10  ? p2_ts1_tx_count : p3r_ts1_tx_count;
assign px_ts1_rx_count  = px_exit_state == 2'b01  ? p1_ts1_rx_count :
                          px_exit_state == 2'b10  ? p2_ts1_rx_count : p3r_ts1_rx_count;
assign px_ts2_tx_count  = px_exit_state == 2'b01  ? p1_ts2_tx_count :
                          px_exit_state == 2'b10  ? p2_ts2_tx_count : p3r_ts2_tx_count;
assign px_ts2_rx_count  = px_exit_state == 2'b01  ? p1_ts2_rx_count :
                          px_exit_state == 2'b10  ? p2_ts2_rx_count : p3r_ts2_rx_count;

always @(*) begin
  nstate                    = state;
  use_phy_clk_in            = use_phy_clk;
  count_in                  = count;
  ltssm_data_active_in      = ltssm_data_active;
  phy_rx_align_reg_in       = 'd0;
  rx_sds_seen_reg_in        = rx_sds_seen_reg;
  deskew_enable_in          = deskew_enable;
  link_wake_n_in            = 1'b0;
  link_reset_n_in           = 1'b1;
  px_exit_state_in          = px_exit_state;
  phy_clk_en_in             = phy_clk_en;
  phy_clk_idle_in           = 1'b0;
  enable_lanes_in           = enable_lanes;
  effect_update_in          = 1'b0;
  ltssm_lane_data           = {DATA_WIDTH{1'b0}};
  sync_count_in             = sync_count;
  sending_sync_in           = sending_sync;
  tx_syncheader             = SH_DATA;
  ll_enable_in              = 1'b0;
  attr_sent                 = 1'b0;
  link_px_req_recv_in       = 1'b0;
  link_px_start_recv_in     = 1'b0;
  sds_sent                  = 1'b0;
  link_px_req_reg_in        = link_px_req_reg;
  
  case(state)
    //--------------------------------------
    IDLE : begin
      link_reset_n_in           = 1'b1;
      link_wake_n_in            = 1'b1;
      phy_clk_en_in             = 1'b0;
      enable_lanes_in           = 1'b0;
      if(enable_ff2) begin
        link_reset_n_in         = 1'b1;
        phy_clk_en_in           = 1'b1;
        link_wake_n_in          = 1'b0;
        nstate                  = WAIT_CLK;
        ltssm_data_active_in    = 1'b1;
        deskew_enable_in        = 1'b0;
      end
    end
    
    //--------------------------------------
    WAIT_CLK : begin
      deskew_enable_in          = 1'b0;
      if(phy_clk_ready_ff2) begin
        nstate                  = SWITCH;
        use_phy_clk_in          = 1'b1;
      end
    end
    
    //--------------------------------------
    SWITCH : begin
      deskew_enable_in          = 1'b0;
      if(count == swi_clk_switch_time) begin
        enable_lanes_in         = 1'b1;
        if(all_tx_ready && all_rx_ready) begin
          //need to add a check for P3 exit when we get to it
          nstate                = P0_TS1;   
          sending_sync_in       = 1'b1;   //start with SYNC
          rx_sds_seen_reg_in    = 1'b0;
          phy_rx_align_reg_in   = 1'b1;
          count_in              = 'd0;
        end
      end else begin
        count_in                = count + 'd1;
      end
    end
    
    //We may want to add in some delay to enable the rx_align?
    
    //--------------------------------------
    P0_TS1 : begin
      deskew_enable_in            = 1'b1;
      phy_rx_align_reg_in         = 1'b1;
      if(byte_count_end) begin
        sending_sync_in           = sync_count == attr_sync_freq;
        if(~sending_sync) begin
          sync_count_in         = sync_count + 'd1;
          if((count >= px_ts1_tx_count) || rx_p0_ts2_qualifier) begin
            if((rx_ts1_count >= px_ts1_rx_count) || rx_p0_ts2_qualifier) begin    //if we have seen N TS1 OR any TS2
              nstate              = P0_TS2;
              phy_rx_align_reg_in = 1'b0;
              count_in            = 'd0;
            end else begin
              count_in            = count;
            end
          end else begin
            count_in              = count + 'd1;
          end
        end else begin
          sending_sync_in         = 1'b0;
          sync_count_in           = 'd1;
        end
      end 
      
      tx_syncheader               = SH_CTRL;
      if(sending_sync) begin
        if(DATA_WIDTH==8) begin
          ltssm_lane_data = byte_count[0] ? SNYC_B1 : SNYC_B0;
        end
        
        if(DATA_WIDTH==16) begin
          ltssm_lane_data = {SNYC_B1, SNYC_B0};
        end
      end else begin
        if(DATA_WIDTH==8) begin
          case(byte_count)
            0       : ltssm_lane_data = TS1_BYTE0;
            default : ltssm_lane_data = TS1_BYTEX;
          endcase
        end
        
        if(DATA_WIDTH==16) begin
          case(byte_count)
            0       : ltssm_lane_data = {TS1_BYTEX, TS1_BYTE0};
            default : ltssm_lane_data = {2{TS1_BYTEX}};
          endcase
        end
      end
    end
    
    
    //--------------------------------------
    P0_TS2 : begin
      ll_enable_in              = 1'b1;
      if(byte_count_end) begin
        sending_sync_in         = sync_count == attr_sync_freq;
        if(~sending_sync) begin
          sync_count_in         = sync_count + 'd1;
          if(count >= px_ts2_tx_count || rx_p0_sds_qualifier) begin
            if((rx_ts2_count >= px_ts2_rx_count) || rx_p0_sds_qualifier) begin    //if we have seen N TS2 OR the SDS
              nstate            = P0_SDS;
              count_in          = 'd0;
              //rx_sds_seen_reg_in  = 1'b0; 
            end else begin
              count_in          = count;
            end
          end else begin
            count_in            = count + 'd1;
          end 
        end else begin
          sending_sync_in       = 1'b0;
          sync_count_in         = 'd1;
        end
      end
      
      
      tx_syncheader               = SH_CTRL;
      if(sending_sync) begin
        if(DATA_WIDTH==8) begin
          ltssm_lane_data = byte_count[0] ? SNYC_B1 : SNYC_B0;
        end
        
        if(DATA_WIDTH==16) begin
          ltssm_lane_data = {SNYC_B1, SNYC_B0};
        end
      end else begin
        if(DATA_WIDTH==8) begin
          case(byte_count)
            0       : ltssm_lane_data = TS2_BYTE0;
            default : ltssm_lane_data = TS2_BYTEX;
          endcase
        end
        
        if(DATA_WIDTH==16) begin
          case(byte_count)
            0       : ltssm_lane_data = {TS2_BYTEX, TS2_BYTE0};
            default : ltssm_lane_data = {2{TS2_BYTEX}};
          endcase
        end
      end
      
      
      if(rx_sds_seen[0]) begin //FIXME
        rx_sds_seen_reg_in      = 1'b1;
      end
    end
    
    //--------------------------------------
    P0_SDS : begin
      ll_enable_in                = 1'b1;
      tx_syncheader               = SH_CTRL;
      if(DATA_WIDTH==8) begin
        case(byte_count)
          0       : ltssm_lane_data = SDS_BYTE0;
          default : ltssm_lane_data = SDS_BYTEX;
        endcase
      end

      if(DATA_WIDTH==16) begin
        case(byte_count)
          0       : ltssm_lane_data = {SDS_BYTEX, SDS_BYTE0};
          default : ltssm_lane_data = {2{SDS_BYTEX}};
        endcase
      end
    
      if(byte_count_end) begin
        sds_sent                = 1'b1;
        nstate                  = P0;
      end
    end
    
    //--------------------------------------
    P0 : begin
      link_wake_n_in            = 1'b1;
      px_exit_state_in          = 2'd0;
      ll_enable_in              = 1'b1;
      nstate                    = P0;
      
      //Don't start until new startblock
      if(byte_count_end) begin
        if(attr_ready && ll_tx_idle) begin
          nstate                = ATTR_ST;
        end else if(((link_p3_req || link_p2_req || link_p1_req) && ll_tx_idle) && ~link_active_req) begin
          link_px_req_reg_in    = {link_p3_req, link_p2_req, link_p1_req}; //capture now as it can deassert later
          nstate                = PX_REQ_ST;
        end
      end
    end
    
    //--------------------------------------
    ATTR_ST : begin
      link_wake_n_in            = 1'b1;
      ll_enable_in              = 1'b1;
      
      tx_syncheader             = SH_CTRL;
      case(byte_count)
        'd0 : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = attr_write ? ATTR_WR_B0 : ATTR_RD_B0;
          end 
          if(DATA_WIDTH==16) begin
            ltssm_lane_data[7:0]  = attr_write ? ATTR_WR_B0 : ATTR_RD_B0;
            ltssm_lane_data[15:8] = attr_addr[7:0];
          end 
        end
        
        'd1 : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = attr_addr[7:0];
          end 
        end
        
        'd2 : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = attr_addr[15:8];
          end 
          if(DATA_WIDTH==16) begin
            ltssm_lane_data[7:0]  = attr_addr[15:8];
            ltssm_lane_data[15:8] = attr_write ? attr_wdata[7:0] : ATTR_FILLER;
          end 
        end
        
        'd3 : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = attr_write ? attr_wdata[7:0] : ATTR_FILLER;
          end 
        end
        
        'd4 : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = attr_write ? attr_wdata[15:8] : ATTR_FILLER;
          end 
          if(DATA_WIDTH==16) begin
            ltssm_lane_data[7:0]  = attr_write ? attr_wdata[15:8] : ATTR_FILLER;
            ltssm_lane_data[15:8] = ATTR_FILLER;
          end 
        end
        
        
        default : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = ATTR_FILLER;
          end
          if(DATA_WIDTH==16) begin
            ltssm_lane_data       = {2{ATTR_FILLER}};
          end
        end
      endcase
      
      //Should we allow for continued Attributes?
      if(byte_count_end) begin
        attr_sent                 = 1'b1;
        nstate                    = P0;
      end
    end
    
    //--------------------------------------
    PX_REQ_ST : begin
      link_wake_n_in            = 1'b1;
      ll_enable_in              = 1'b1;
      tx_syncheader             = SH_CTRL;
      link_px_req_recv_in       = link_px_req_pkt   ? 1'b1 : link_px_req_recv;
      link_px_start_recv_in     = link_px_start_pkt ? 1'b1 : link_px_start_recv;
      
      case(byte_count)
        'd0 : begin
          if(DATA_WIDTH==8) begin
            if(link_px_req_reg[2]) begin
              ltssm_lane_data     = P3_REQ_B0;
            end else if(link_px_req_reg[1]) begin
              ltssm_lane_data     = P2_REQ_B0;
            end else begin
              ltssm_lane_data     = P1_REQ_B0;
            end          
          end 
          if(DATA_WIDTH==16) begin
            if(link_px_req_reg[2]) begin
              ltssm_lane_data     = {PX_FILLER, P3_REQ_B0};
            end else if(link_px_req_reg[1]) begin
              ltssm_lane_data     = {PX_FILLER, P2_REQ_B0};
            end else begin
              ltssm_lane_data     = {PX_FILLER, P1_REQ_B0};
            end
          end 
        end
        
        default : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data       = PX_FILLER;
          end
          if(DATA_WIDTH==16) begin
            ltssm_lane_data       = {2{PX_FILLER}};
          end
        end
      endcase
            
      if(byte_count_end && link_px_req_recv_in) begin
        px_exit_state_in          = link_px_req_reg[2] ? 'd3 :
                                    link_px_req_reg[1] ? 'd2 : 'd1;
        nstate                    = PX_START_ST;
      end
    end
    
    //--------------------------------------
    PX_START_ST : begin
      link_wake_n_in            = 1'b1;
      tx_syncheader             = SH_CTRL;
      link_px_start_recv_in     = link_px_start_pkt ? 1'b1 : link_px_start_recv;
      
      case(byte_count)
        'd0 : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data     = P_START_B0;
          end 
          if(DATA_WIDTH==16) begin
            ltssm_lane_data     = {PX_FILLER, P_START_B0};
          end 
        end
        
        default : begin
          if(DATA_WIDTH==8) begin
            ltssm_lane_data     = PX_FILLER;
          end
          if(DATA_WIDTH==16) begin
            ltssm_lane_data     = {2{PX_FILLER}};
          end
        end
      endcase
            
      if(byte_count_end && link_px_start_recv_in) begin
        count_in                = 'd0;
        nstate                  = P0_EXIT;
      end
    end
    
    //--------------------------------------
    P0_EXIT : begin
      link_wake_n_in            = 1'b1;
      if(count == swi_p0_exit_time) begin
        enable_lanes_in         = 1'b0;
        deskew_enable_in        = 1'b0;
        phy_rx_align_reg_in     = 1'b0;
        count_in                = 'd0;
        effect_update_in        = 1'b1;
        nstate                  = px_exit_state == 'd3 ? P0_P3_CLK_TRAIL :
                                  px_exit_state == 'd2 ? P0_P2_CLK_TRAIL : P1;
      end else begin
        count_in                = count + 'd1;
      end
    end
    
    
    //--------------------------------------
    P1 : begin
      link_wake_n_in            = 1'b1;
      if(link_active_req) begin
        enable_lanes_in         = 1'b1;
        deskew_enable_in        = 1'b1;
        phy_rx_align_reg_in     = 1'b1;
        link_wake_n_in          = 1'b0;
        nstate                  = P1_EXIT;
      end
    end
    
    
    //--------------------------------------
    P1_EXIT : begin
      if(all_tx_ready && all_rx_ready) begin
        rx_sds_seen_reg_in      = 1'b0;
        phy_rx_align_reg_in     = 1'b1;
        sending_sync_in         = 1'b1;   //start with SYNC
        count_in                = 'd0;
        nstate                  = P0_TS1;
      end
    end
    
    //--------------------------------------
    P0_P2_CLK_TRAIL : begin
      use_phy_clk_in            = 1'b0;
      link_wake_n_in            = 1'b1;
      if(count == px_clk_trail) begin
        phy_clk_idle_in         = 1'b1;
        count_in                = 'd0;
        nstate                  = P2;
      end else begin
        count_in                = count + 'd1;
      end
    end
    
    //--------------------------------------
    P2 : begin
      phy_clk_idle_in           = 1'b1;
      link_wake_n_in            = 1'b1;
      if(link_active_req) begin
        link_wake_n_in          = 1'b0;
        count_in                = 'd0;
        nstate                  = WAIT_CLK;
      end
    end
    
    //--------------------------------------
    P0_P3_CLK_TRAIL : begin
      use_phy_clk_in            = 1'b0;
      link_wake_n_in            = 1'b1;
      if(count == px_clk_trail) begin
        phy_clk_en_in           = 1'b0;
        count_in                = 'd0;
        nstate                  = P3;
      end else begin
        count_in                = count + 'd1;
      end
    end
    
    //--------------------------------------
    P3 : begin
      link_wake_n_in            = 1'b1;
      if(link_active_req) begin
        link_wake_n_in          = 1'b0;
        phy_clk_en_in           = 1'b1;
        count_in                = 'd0;
        nstate                  = WAIT_CLK;
      end
    end
    
    
    //--------------------------------------
    RESET_ENTER : begin
      link_reset_n_in           = 1'b0;
      if(count == px_clk_trail) begin
        phy_clk_idle_in         = 1'b0; //should we add an extra state?
        phy_clk_en_in           = 1'b0;
        count_in                = 'd0;
        nstate                  = RESET_ST;
      end else begin
        count_in                = count + 'd1;
      end
    end
    
    //--------------------------------------
    //Use the local indication to drive the main reset. 
    //So if we didn't request the reset, don't drive
    RESET_ST : begin
      link_reset_n_in           = ~link_reset_req_local;
      if(~link_reset_req) begin
        nstate                  = IDLE;
      end
    end
    
    default : begin
      nstate                    = IDLE;
    end
  endcase
  
  //Catch all for reset conditions
  if(link_reset_req) begin
    if((state != RESET_ENTER) && (state != RESET_ST)) begin
      enable_lanes_in           = 1'b0;
      use_phy_clk_in            = 1'b0;
      link_reset_n_in           = ~link_reset_req_local;
      count_in                  = 'd0;
      nstate                    = RESET_ENTER;
    end
  end
  
  
  //Final enable disable
  if(~enable_ff2) begin
    use_phy_clk_in              = 1'b0;
    nstate                      = IDLE;
  end
end

assign phy_rx_align     = {NUM_RX_LANES{phy_rx_align_reg}};

//assign sds_sent         = (state == P0_SDS) && (nstate == P0);




wire [(NUM_TX_LANES*DATA_WIDTH)-1:0]    tx_gearbox_data;
wire [(NUM_TX_LANES*DATA_WIDTH)-1:0]    ltssm_data_sel;

genvar laneindex;
generate
  for(laneindex = 0; laneindex < NUM_TX_LANES; laneindex = laneindex + 1) begin : gen_gearboxes
    assign ltssm_data_sel[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] = laneindex < (1 << active_tx_lanes) ?  
                                                                                 ((state != P0) && (state != P0_EXIT) ? ltssm_lane_data : link_data[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)]) : {DATA_WIDTH{1'b0}};
  
    slink_tx_gearbox_128b13xb #(
      //parameters
      .DATA_WIDTH         ( DATA_WIDTH )
    ) u_slink_tx_gearbox_128b13xb (
      .clk           ( clk                                                                ),  
      .reset         ( reset                                                              ),  
      .tx_data_in    ( ltssm_data_sel[((laneindex+1)*DATA_WIDTH)-1:laneindex*DATA_WIDTH]  ),
      .tx_syncheader ( {2'b00, tx_syncheader}                                             ),  
      .tx_startblock ( tx_startblock                                                      ),   
      .tx_datavalid  ( tx_datavalid                                                       ),   
      .enable        ( (enable_gearbox && phy_tx_en[laneindex])                           ),  
      .encode_mode   ( 1'b0                                                               ),  
      .tx_data_out   ( tx_gearbox_data[((laneindex+1)*DATA_WIDTH)-1:laneindex*DATA_WIDTH] ));  
  end
endgenerate





reg  [(NUM_TX_LANES*DATA_WIDTH)-1:0]    tx_gearbox_data_reg;

generate
  for(laneindex = 0; laneindex < NUM_TX_LANES; laneindex = laneindex + 1) begin : ltssm_data_select
    if(REGISTER_TXDATA) begin
      always @(posedge clk or posedge reset) begin
        if(reset) begin
          tx_gearbox_data_reg     <= {(NUM_TX_LANES*DATA_WIDTH){1'b0}};
        end else begin
          tx_gearbox_data_reg     <= tx_gearbox_data;
        end
      end
      
    end
  end
  
  if(REGISTER_TXDATA) begin
    assign ltssm_data   = tx_gearbox_data_reg;
  end else begin
    assign ltssm_data   = tx_gearbox_data;
  end
  
endgenerate





//----------------------------------
// Hard Reset Detection logic
//----------------------------------
reg   [9:0]               count_1us;
wire  [9:0]               count_1us_in;
reg   [9:0]               count_hardreset;
wire  [9:0]               count_hardreset_in;
wire                      tick_1us;
wire                      link_reset_req_refclk;
wire                      hard_reset_cond;
wire                      hard_reset_cond_ff2;
reg                       hard_reset_cond_ff3;


slink_demet_reset u_slink_demet_in_reset_state_refclk (
  .clk     ( refclk                 ),          
  .reset   ( refclk_reset           ),          
  .sig_in  ( link_reset_req         ),          
  .sig_out ( link_reset_req_refclk  )); 


always @(posedge refclk or posedge refclk_reset) begin
  if(refclk_reset) begin
    count_1us       <= 'd0;
    count_hardreset <= 'd0;
  end else begin
    count_1us       <= count_1us_in;
    count_hardreset <= count_hardreset_in;
  end
end

assign tick_1us           = count_1us == swi_count_val_1us;
assign count_1us_in       = link_reset_req_refclk ? (tick_1us ? 'd0 : count_1us + 'd1) : 'd0;

assign hard_reset_cond    = count_hardreset == attr_hard_reset_us;
assign count_hardreset_in = link_reset_req_refclk ? (hard_reset_cond ? count_hardreset : tick_1us ? count_hardreset + 'd1 : count_hardreset) : 'd0;



slink_demet_reset u_slink_demet_hard_reset_cond_link_clk (
  .clk     ( clk                    ),          
  .reset   ( reset                  ),          
  .sig_in  ( hard_reset_cond        ),          
  .sig_out ( hard_reset_cond_ff2    )); 
  
always @(posedge clk or posedge reset) begin
  if(reset) begin
    hard_reset_cond_ff3 <= 1'b0;
  end else begin
    hard_reset_cond_ff3 <= hard_reset_cond_ff2;
  end
end

assign link_hard_reset_cond = hard_reset_cond_ff2 && ~hard_reset_cond_ff3;


`ifdef SIMULATION
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    IDLE            : state_name = "IDLE";
    WAIT_CLK        : state_name = "WAIT_CLK";
    SWITCH          : state_name = "SWITCH";
    P0_TS1          : state_name = "P0_TS1";
    P0_TS2          : state_name = "P0_TS2";
    P0_SDS          : state_name = "P0_SDS";
    P0              : state_name = "P0";
    P0_EXIT         : state_name = "P0_EXIT";
    P1              : state_name = "P1";
    P1_EXIT         : state_name = "P1_EXIT";
    P0_P2_CLK_TRAIL : state_name = "P0_P2_CLK_TRAIL";
    P2              : state_name = "P2";
    P2_EXIT         : state_name = "P2_EXIT";
    P0_P3_CLK_TRAIL : state_name = "P0_P3_CLK_TRAIL";
    P3              : state_name = "P3";
    RESET_ENTER     : state_name = "RESET_ENTER";
    RESET_ST        : state_name = "RESET_ST";
    PX_REQ_ST       : state_name = "PX_REQ_ST";
    PX_START_ST     : state_name = "PX_START_ST";
    ATTR_ST         : state_name = "ATTR_ST";
  endcase
end
`endif

endmodule



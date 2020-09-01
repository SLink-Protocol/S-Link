/*
  ADD PARAMETER TO RIP OUT THE FOLLOWING:
  
  blockalign  - if using strobe-based PHY
  deskew      - if using strobe-based PHY
  retime      - if using strobe-based PHY OR phy where all RX clocks are same
*/
module slink_rx_align_deskew #(
  parameter         FIFO_DEPTH        = 4,
  parameter         FIFO_CLOG2        = $clog2(FIFO_DEPTH),
  parameter         DATA_WIDTH        = 8,
  parameter         NUM_LANES         = 4,
  parameter         RETIME_FIFO_DEPTH = 3
)(
  input  wire                                 clk,
  input  wire                                 reset,
  input  wire                                 enable,
  input  wire                                 blockalign,
  
  input  wire [NUM_LANES-1:0]                 rxclk,
  input  wire [NUM_LANES-1:0]                 rxclk_reset,
  input  wire [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_in,
  
  input  wire [2:0]                           active_lanes,
  output wire [(NUM_LANES*FIFO_CLOG2)-1:0]    fifo_ptr_status,
  output reg  [NUM_LANES-1:0]                 rx_ts1_seen,
  output reg  [NUM_LANES-1:0]                 rx_ts2_seen,
  output reg  [NUM_LANES-1:0]                 rx_sds_seen,
  output wire [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_out,
  output wire                                 ll_rx_datavalid,
  
  //Control Signals
  output wire                                 rx_px_req_pkt,
  output wire [2:0]                           rx_px_req_state,
  output wire                                 rx_px_start_pkt,
  
  output wire [15:0]                          attr_addr,                         
  output wire [15:0]                          attr_data,
  output wire                                 attr_update,
  output wire                                 attr_rd_req,
  
  output wire [1:0]                           deskew_state
);


wire  [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_aligned;
wire  [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_aligned_retime;
wire  [NUM_LANES-1:0]                 rx_datavalid;
wire  [NUM_LANES-1:0]                 rx_datavalid_retime;
wire  [NUM_LANES-1:0]                 rx_startblock;
wire  [NUM_LANES-1:0]                 rx_startblock_retime;
wire  [(NUM_LANES*2)-1:0]             rx_syncheader;
wire  [(NUM_LANES*2)-1:0]             rx_syncheader_retime;

wire  [NUM_LANES-1:0]                 rx_valid;

wire  [NUM_LANES-1:0]                 bad_syncheader;
wire  [NUM_LANES-1:0]                 locked;
wire  [NUM_LANES-1:0]                 rx_locked_retime;



slink_rx_deskew #(
  //parameters
  .FIFO_DEPTH         ( FIFO_DEPTH ),
  .DATA_WIDTH         ( DATA_WIDTH ),
  .NUM_LANES          ( NUM_LANES  )
) u_slink_rx_deskew (
  .clk                 ( clk                      ),           
  .reset               ( reset                    ),           
  .enable              ( enable                   ),  //May need to hold this until all are active?
  .rx_data_in          ( rx_data_aligned_retime   ),  
  .rx_data_valid_in    ( rx_datavalid_retime      ),
  .rx_syncheader_in    ( rx_syncheader_retime     ),
  .rx_startblock_in    ( rx_startblock_retime     ),
  .rx_locked           ( rx_locked_retime         ),
  .active_lanes        ( active_lanes             ),  
  .fifo_ptr_status     ( /*connect me??*/         ),  //output - [(NUM_LANES*FIFO_CLOG2)-1:0]              
  .rx_ts1_seen         ( rx_ts1_seen              ),  
  .rx_ts2_seen         ( rx_ts2_seen              ),  
  .rx_sds_seen         ( rx_sds_seen              ),  
  .rx_data_out         ( rx_data_out              ),  
  .rx_data_valid_out   (                          ),  
  .ll_rx_datavalid     ( ll_rx_datavalid          ),
  
  .rx_px_req           ( rx_px_req_pkt            ),
  .rx_px_req_state     ( rx_px_req_state          ),
  .rx_px_start         ( rx_px_start_pkt          ),
  .attr_addr           ( attr_addr                ),
  .attr_data           ( attr_data                ),
  .attr_update         ( attr_update              ),
  .attr_rd_req         ( attr_rd_req              ),
  
  .deskew_state        ( deskew_state             ));  


genvar laneindex;

generate
  for(laneindex = 0; laneindex < NUM_LANES; laneindex = laneindex + 1) begin : gen_block_align
    
    
    wire        enable_local;
    wire        blockalign_local;
    wire        lane_is_active;
    wire [1:0]  sh_noconn;
    
    //Use this to gate inactive lanes
    assign lane_is_active = laneindex < (1 << active_lanes);
    
    slink_demet_reset u_slink_demet_reset_rx_en_ba[1:0] (
      .clk     ( rxclk[laneindex]             ),           
      .reset   ( rxclk_reset[laneindex]       ),           
      .sig_in  ( {blockalign,
                  (enable && lane_is_active)} ),           
      .sig_out ( {blockalign_local,
                  enable_local}               )); 
  
    slink_rx_blockalign_128b13xb #(
      //parameters
      .DATA_WIDTH         ( DATA_WIDTH )
    ) u_slink_rx_blockalign_128b13xb (
      .clk                 ( rxclk[laneindex]                                                   ),  
      .reset               ( rxclk_reset[laneindex]                                             ),  
      .enable              ( enable_local                                                       ), 
      .blockalign          ( blockalign_local                                                   ), 
      .encode_mode         ( 2'b00                                                              ),  
      .custom_sync_pat     ( {DATA_WIDTH{1'b0}}                                                 ),  
      .rx_data_in          ( rx_data_in[((laneindex+1)*DATA_WIDTH)-1:laneindex*DATA_WIDTH]      ),  
      .rx_data_out         ( rx_data_aligned[((laneindex+1)*DATA_WIDTH)-1:laneindex*DATA_WIDTH] ),  
      .rx_syncheader       ( {sh_noconn, rx_syncheader[((laneindex+1)*2)-1:laneindex*2]}        ),
      .rx_valid            ( rx_valid[laneindex]                                                ),           
      .rx_datavalid        ( rx_datavalid[laneindex]                                            ),           
      .rx_startblock       ( rx_startblock[laneindex]                                           ),           
      .bad_syncheader      ( bad_syncheader[laneindex]                                          ),           
      .eios_seen           (                                                                    ),  
      .locked              ( locked[laneindex]                                                  )); 

    
    wire rempty;
    
    //NEED TO SEE HOW WE CLEAR THIS FIFO AFTER INACTIVE
    
    assign rx_locked_retime[laneindex] = ~rempty;
    
    slink_fifo_top #(
      //parameters
      .DATA_SIZE          ( DATA_WIDTH + 2 + 1 + 1 ), //DATA_WIDTH + SyncHeader + DataValid + Startblock
      .ADDR_SIZE          ( RETIME_FIFO_DEPTH      )
    ) u_retime_fifo (
      .wclk                ( rxclk[laneindex]                   ),             
      .wreset              ( rxclk_reset[laneindex]             ),             
      .winc                ( locked[laneindex]                  ),  //do we need other gates?
                    
      .rclk                ( clk                                ),  
      .rreset              ( reset                              ),           
      .rinc                ( ~rempty                            ),  //need anything else? 
           
      .wdata               ( {rx_datavalid[laneindex],
                              rx_startblock[laneindex],
                              rx_syncheader[((laneindex+1)*2)-1:laneindex*2],
                              rx_data_aligned[((laneindex+1)*DATA_WIDTH)-1:laneindex*DATA_WIDTH]}                  ),  
      .rdata               ( {rx_datavalid_retime[laneindex],
                              rx_startblock_retime[laneindex],
                              rx_syncheader_retime[((laneindex+1)*2)-1:laneindex*2],
                              rx_data_aligned_retime[((laneindex+1)*DATA_WIDTH)-1:laneindex*DATA_WIDTH]}           ),  
      .wfull               (                                    ),  
      .rempty              ( rempty                             ),  
      .rbin_ptr            (                                    ),  
      .rdiff               (                                    ),  
      .wbin_ptr            (                                    ),  
      .wdiff               (                                    ),  
      .swi_almost_empty    ( {{RETIME_FIFO_DEPTH-1{1'b0}}, 1'b1}),          
      .swi_almost_full     ( {{RETIME_FIFO_DEPTH-1{1'b1}}, 1'b0}),          
      .half_full           (                                    ),  
      .almost_empty        (                                    ),  
      .almost_full         (                                    )); 

  end
endgenerate

endmodule

module slink_rx_deskew #(
  parameter         FIFO_DEPTH      = 4,                    //upto 15 is a requirement
  parameter         FIFO_CLOG2      = $clog2(FIFO_DEPTH),
  parameter         DATA_WIDTH      = 8,
  parameter         NUM_LANES       = 4
)(
  input  wire                                 clk,
  input  wire                                 reset,
  input  wire                                 enable,
  
  input  wire [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_in,
  input  wire [NUM_LANES-1:0]                 rx_data_valid_in,
  input  wire [(NUM_LANES*2)-1:0]             rx_syncheader_in,
  input  wire [NUM_LANES-1:0]                 rx_startblock_in,
  input  wire [NUM_LANES-1:0]                 rx_locked,
  
  input  wire [2:0]                           active_lanes,
  output wire [(NUM_LANES*FIFO_CLOG2)-1:0]    fifo_ptr_status,
  output reg  [NUM_LANES-1:0]                 rx_ts1_seen,
  output reg  [NUM_LANES-1:0]                 rx_ts2_seen,
  output reg  [NUM_LANES-1:0]                 rx_sds_seen,
  output wire [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_out,
  output wire [NUM_LANES-1:0]                 rx_data_valid_out,
  output wire [(NUM_LANES*2)-1:0]             rx_syncheader_out,
  output wire [NUM_LANES-1:0]                 rx_starblock_out,
  
  output wire                                 ll_rx_datavalid,
  
  output reg                                  rx_px_req,
  output reg  [2:0]                           rx_px_req_state,
  output reg                                  rx_px_start,      
  
  output reg  [15:0]                          attr_addr,                         
  output reg  [15:0]                          attr_data,
  output reg                                  attr_update,
  output reg                                  attr_rd_req,
  
  output wire [1:0]                           deskew_state
);

`include "slink_includes.vh"

localparam      IDLE    = 'd0,
                TRAIN   = 'd1,
                LOCKED  = 'd2;


reg   [1:0]             state, nstate;
reg   [DATA_WIDTH+3:0]  data_fifo         [NUM_LANES-1:0] [FIFO_DEPTH-1:0];   //data storage
reg   [FIFO_CLOG2:0]    fifo_ptr          [NUM_LANES-1:0];                    //keeps up with the com location and has a valid signal
reg   [FIFO_CLOG2:0]    fifo_ptr_in       [NUM_LANES-1:0];                    //
wire  [DATA_WIDTH-1:0]  sync_value;
wire  [NUM_LANES-1:0]   sync_seen;
wire                    sync_all_lanes;
reg   [3:0]             ts1_byte_count     [NUM_LANES-1:0];
reg   [3:0]             ts1_byte_count_in  [NUM_LANES-1:0];
reg   [3:0]             ts2_byte_count     [NUM_LANES-1:0];
reg   [3:0]             ts2_byte_count_in  [NUM_LANES-1:0];

reg   [3:0]             sds_byte_count     [NUM_LANES-1:0];
reg   [3:0]             sds_byte_count_in  [NUM_LANES-1:0];
reg   [NUM_LANES-1:0]   rx_ts2_seen_prev;


wire  [NUM_LANES-1:0]   lane_active;

assign sync_value = (DATA_WIDTH == 8)  ? SNYC_B0    :
                    (DATA_WIDTH == 16) ? {SNYC_B1, SNYC_B0} : {SNYC_B1, SNYC_B0, SNYC_B1, SNYC_B0};



genvar laneindex;
genvar fifoindex;
generate 
  for(laneindex = 0; laneindex < NUM_LANES; laneindex = laneindex + 1) begin : lane_specific_logic
    
    assign lane_active[laneindex] = laneindex < (1 << active_lanes);
    
    //FIFO component for each lane
    for(fifoindex = 0; fifoindex < FIFO_DEPTH; fifoindex = fifoindex + 1) begin : lane_specific_fifo
      always @(posedge clk or posedge reset) begin
        if(reset) begin
          data_fifo[laneindex][fifoindex]       <= 'd0;
          //fifo_ptr[laneindex]                   <= 'd0;
        end else begin
          if(fifoindex == 0) begin
            data_fifo[laneindex][fifoindex]     <= lane_active[laneindex] && enable && rx_locked[laneindex] ? {rx_data_valid_in[laneindex], 
                                                                                                               rx_startblock_in[laneindex],
                                                                                                               rx_syncheader_in[((laneindex+1)*2)-1:(laneindex*2)],
                                                                                                               rx_data_in[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)]} : 'd0;
          end else begin
            data_fifo[laneindex][fifoindex]     <= lane_active[laneindex] && enable && rx_locked[laneindex] ? data_fifo[laneindex][fifoindex-1] : 'd0;
          end
          
          //fifo_ptr[laneindex]                   <=  (state == IDLE)   ? {FIFO_CLOG2+1{1'b0}} : 
          //                                          (state == TRAIN)  ? fifo_ptr_in[laneindex] : fifo_ptr[laneindex];
        end
      end
                       
    end 
    
    
    always @(posedge clk or posedge reset) begin
      if(reset) begin
        fifo_ptr[laneindex]                   <= 'd0;
      end else begin
        fifo_ptr[laneindex]                   <=  (state == IDLE)   ? {FIFO_CLOG2+1{1'b0}} : 
                                                  (state == TRAIN)  ? fifo_ptr_in[laneindex] : fifo_ptr[laneindex];
      end
    end
    
    
    //Make this up to 16 entries?
    //Figure out a way to incorporate in the generate loop
    always@(*) begin
      case({(data_fifo[laneindex][3][DATA_WIDTH+2]) && (data_fifo[laneindex][3][DATA_WIDTH-1:0] == sync_value) && ((data_fifo[laneindex][3][DATA_WIDTH+1:DATA_WIDTH]) == SH_CTRL) && (data_fifo[laneindex][3][DATA_WIDTH+3]),
            (data_fifo[laneindex][2][DATA_WIDTH+2]) && (data_fifo[laneindex][2][DATA_WIDTH-1:0] == sync_value) && ((data_fifo[laneindex][2][DATA_WIDTH+1:DATA_WIDTH]) == SH_CTRL) && (data_fifo[laneindex][2][DATA_WIDTH+3]),
            (data_fifo[laneindex][1][DATA_WIDTH+2]) && (data_fifo[laneindex][1][DATA_WIDTH-1:0] == sync_value) && ((data_fifo[laneindex][1][DATA_WIDTH+1:DATA_WIDTH]) == SH_CTRL) && (data_fifo[laneindex][1][DATA_WIDTH+3]),
            (data_fifo[laneindex][0][DATA_WIDTH+2]) && (data_fifo[laneindex][0][DATA_WIDTH-1:0] == sync_value) && ((data_fifo[laneindex][0][DATA_WIDTH+1:DATA_WIDTH]) == SH_CTRL) && (data_fifo[laneindex][0][DATA_WIDTH+3])})
        4'b0001 : fifo_ptr_in[laneindex] = {1'b1, 2'd0};
        4'b0010 : fifo_ptr_in[laneindex] = {1'b1, 2'd1};
        4'b0100 : fifo_ptr_in[laneindex] = {1'b1, 2'd2};
        4'b1000 : fifo_ptr_in[laneindex] = {1'b1, 2'd3};
        default : fifo_ptr_in[laneindex] = 'd0;
      endcase            
    end
    
   
    assign rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)]     = lane_active[laneindex] ? data_fifo[laneindex][fifo_ptr[laneindex][FIFO_CLOG2-1:0]][DATA_WIDTH-1:0]          : {DATA_WIDTH{1'b0}};
    assign rx_data_valid_out[laneindex]                                         = lane_active[laneindex] ? data_fifo[laneindex][fifo_ptr[laneindex][FIFO_CLOG2-1:0]][DATA_WIDTH+3]            : 1'b0;
    assign rx_syncheader_out[((laneindex+1)*2)-1:(laneindex*2)]                 = lane_active[laneindex] ? data_fifo[laneindex][fifo_ptr[laneindex][FIFO_CLOG2-1:0]][DATA_WIDTH+1:DATA_WIDTH] : 1'b0;
    assign rx_starblock_out[laneindex]                                          = lane_active[laneindex] ? data_fifo[laneindex][fifo_ptr[laneindex][FIFO_CLOG2-1:0]][DATA_WIDTH+2]            : 1'b0;
        
    assign fifo_ptr_status[((laneindex+1)*FIFO_CLOG2)-1:(laneindex*FIFO_CLOG2)] = lane_active[laneindex] ? fifo_ptr[laneindex][FIFO_CLOG2-1:0] : {FIFO_CLOG2{1'b0}};
    
    assign sync_seen[laneindex]                                                 = fifo_ptr[laneindex][FIFO_CLOG2] || ~lane_active[laneindex];
    
  end
endgenerate


assign deskew_state = state;


always @(posedge clk or posedge reset) begin
  if(reset) begin
    state           <= IDLE;
  end else begin
    state           <= nstate;
  end
end


assign sync_all_lanes = &sync_seen;

always @(*) begin
  nstate            = state;
  
  case(state)
    IDLE : begin
      if(enable) begin
        nstate      = TRAIN;
      end
    end
    
    TRAIN : begin
      if(sync_all_lanes) begin
        nstate      = LOCKED;
      end
    end
    
    LOCKED : begin
      nstate        = LOCKED;
    end
  
    default : begin
      nstate        = IDLE;
    end
  endcase
  
  if(~enable) begin
    nstate          = IDLE;
  end
end


//TS/SDS Detection Logic
generate 
  for(laneindex = 0; laneindex < NUM_LANES; laneindex = laneindex + 1) begin : lane_ts_counter
  
    always @(posedge clk or posedge reset) begin
      if(reset) begin
        ts1_byte_count[laneindex]   <= 'd0;
        ts2_byte_count[laneindex]   <= 'd0;
        sds_byte_count[laneindex]   <= 'd0;
        rx_ts2_seen_prev[laneindex] <= 'd0;
      end else begin
        ts1_byte_count[laneindex]   <= ts1_byte_count_in[laneindex];
        ts2_byte_count[laneindex]   <= ts2_byte_count_in[laneindex];
        sds_byte_count[laneindex]   <= sds_byte_count_in[laneindex];
        rx_ts2_seen_prev[laneindex] <= rx_ts2_seen[laneindex];
      end
    end
  
    reg ctrl_sb_sym;
    
    always @(*) begin
      ctrl_sb_sym                     = 1'b0;
      ts1_byte_count_in[laneindex]    = ts1_byte_count[laneindex];
      ts2_byte_count_in[laneindex]    = ts2_byte_count[laneindex];
      sds_byte_count_in[laneindex]    = sds_byte_count[laneindex];
      
      if(state == LOCKED) begin
        
        //Indicates the start of a control block
        ctrl_sb_sym = rx_starblock_out[laneindex] && rx_data_valid_out[laneindex] && (rx_syncheader_out[((laneindex+1)*2)-1:(laneindex*2)] == SH_CTRL);
        
        case(ts1_byte_count[laneindex])
          4'd0 : begin
            if(ctrl_sb_sym) begin
              ts1_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TS1_BYTE0                    ? 'd1 : 'd0) :
                                             (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {TS1_BYTEX, TS1_BYTE0}       ? 'd2 : 'd0) : 
                                                                  (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {{3{TS1_BYTEX}}, TS1_BYTE0}  ? 'd4 : 'd0);
            end
          end

          default : begin
            ts1_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TS1_BYTEX       ? ts1_byte_count[laneindex] + 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {2{TS1_BYTEX}}  ? ts1_byte_count[laneindex] + 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {4{TS1_BYTEX}}  ? ts1_byte_count[laneindex] + 'd4 : 'd0);
          end 
        endcase

        case(ts2_byte_count[laneindex])
          4'd0 : begin
            if(ctrl_sb_sym) begin
              ts2_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TS2_BYTE0                    ? 'd1 : 'd0) :
                                             (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {TS2_BYTEX, TS2_BYTE0}       ? 'd2 : 'd0) : 
                                                                  (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {{3{TS2_BYTEX}}, TS2_BYTE0}  ? 'd4 : 'd0);
            end
          end

          default : begin
            ts2_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TS2_BYTEX       ? ts2_byte_count[laneindex] + 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {2{TS2_BYTEX}}  ? ts2_byte_count[laneindex] + 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {4{TS2_BYTEX}}  ? ts2_byte_count[laneindex] + 'd4 : 'd0);
          end 
        endcase


        case(sds_byte_count[laneindex])
          4'd0 : begin
            if(ctrl_sb_sym) begin
              sds_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == SDS_BYTE0                    ? 'd1 : 'd0) :
                                             (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {SDS_BYTEX, SDS_BYTE0}       ? 'd2 : 'd0) : 
                                                                  (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {{3{SDS_BYTEX}}, SDS_BYTE0}  ? 'd4 : 'd0);
            end
          end

          default : begin
            sds_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == SDS_BYTEX       ? sds_byte_count[laneindex] + 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {2{SDS_BYTEX}}  ? sds_byte_count[laneindex] + 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {4{SDS_BYTEX}}  ? sds_byte_count[laneindex] + 'd4 : 'd0);
          end 
        endcase
      end else begin
        ts1_byte_count_in[laneindex]     = 'd0;
        ts2_byte_count_in[laneindex]     = 'd0;
        sds_byte_count_in[laneindex]     = 'd0;
      end
    end
    
    //If the Lane is not active, then just assert the *_seen for that lane and it will be gated by the others
    always @(*) begin
      rx_ts1_seen[laneindex] = lane_active[laneindex] ? ((DATA_WIDTH == 8)  ? ts1_byte_count[laneindex] == 'd15 : 
                                                         (DATA_WIDTH == 16) ? ts1_byte_count[laneindex] == 'd14 : ts1_byte_count[laneindex] == 'd12) : 1'b1;
      rx_ts2_seen[laneindex] = lane_active[laneindex] ? ((DATA_WIDTH == 8)  ? ts2_byte_count[laneindex] == 'd15 : 
                                                         (DATA_WIDTH == 16) ? ts2_byte_count[laneindex] == 'd14 : ts2_byte_count[laneindex] == 'd12) : 1'b1;
      rx_sds_seen[laneindex] = lane_active[laneindex] ? ((DATA_WIDTH == 8)  ? sds_byte_count[laneindex] == 'd15 : 
                                                         (DATA_WIDTH == 16) ? sds_byte_count[laneindex] == 'd14 : sds_byte_count[laneindex] == 'd12) : 1'b1;
    end
    
  end
endgenerate


//Other Control OS Detection
reg [3:0]   ctrl_byte_count, ctrl_byte_count_in;
reg         ctrl_byte_active, ctrl_byte_active_in;
wire        ctrl_byte_start;
wire        data_byte_start;

reg         rx_px_req_in;
reg [2:0]   rx_px_req_state_in;
reg         rx_px_start_in;
reg         cur_attr_wr_req, cur_attr_wr_req_in;
reg         cur_attr_rd_req, cur_attr_rd_req_in;
reg         cur_attr_rsp_req, cur_attr_rsp_req_in;

reg  [15:0] attr_addr_in;
reg  [15:0] attr_data_in;
reg         attr_update_in;

always @(posedge clk or posedge reset) begin
  if(reset) begin
    ctrl_byte_count   <= 'd0;
    ctrl_byte_active  <= 1'b0;
    rx_px_req         <= 1'b0;
    rx_px_req_state   <= 'd0;
    rx_px_start       <= 1'b0;
    cur_attr_wr_req   <= 1'b0;
    cur_attr_rd_req   <= 1'b0;
    cur_attr_rsp_req  <= 1'b0;
    attr_addr         <= 16'd0;
    attr_data         <= 16'd0;
    attr_update       <= 1'b0;
  end else begin
    ctrl_byte_count   <= ctrl_byte_count_in;
    ctrl_byte_active  <= ctrl_byte_active_in;
    rx_px_req         <= rx_px_req_in;
    rx_px_req_state   <= rx_px_req_state_in;
    rx_px_start       <= rx_px_start_in;
    cur_attr_wr_req   <= cur_attr_wr_req_in;
    cur_attr_rd_req   <= cur_attr_rd_req_in;
    cur_attr_rsp_req  <= cur_attr_rsp_req_in;
    attr_addr         <= attr_addr_in;
    attr_data         <= attr_data_in;
    attr_update       <= attr_update_in;
  end
end

assign ctrl_byte_start = rx_starblock_out[0] && rx_data_valid_out[0] && (rx_syncheader_out[1:0] == SH_CTRL);
assign data_byte_start = rx_starblock_out[0] && rx_data_valid_out[0] && (rx_syncheader_out[1:0] == SH_DATA);


// For control OS's we will only look on Lane0. This will save some logic
// and no need to deal with checking each lane.
always @(*) begin
  rx_px_req_in        = rx_px_req;
  rx_px_req_state_in  = rx_px_req_state;
  rx_px_start_in      = rx_px_start;
  ctrl_byte_active_in = ctrl_byte_active;
  ctrl_byte_count_in  = ctrl_byte_count;
  
  cur_attr_wr_req_in  = cur_attr_wr_req;
  cur_attr_rd_req_in  = cur_attr_rd_req;
  cur_attr_rsp_req_in = cur_attr_rsp_req;
  
  attr_addr_in        = attr_addr;
  attr_data_in        = attr_data;
  
  attr_update_in      = 1'b0;
  
  if(enable && (state == LOCKED)) begin
    ctrl_byte_active_in   = ctrl_byte_start ? 1'b1 : data_byte_start ? 1'b0 : ctrl_byte_active;
    
    case(ctrl_byte_count)
      //--------------------
      'd0 : begin
        if(ctrl_byte_start) begin
          ctrl_byte_count_in    = DATA_WIDTH/8;
          rx_px_req_in          =  (rx_data_out[7:0] == P3_REQ_B0) ||
                                   (rx_data_out[7:0] == P2_REQ_B0) ||
                                   (rx_data_out[7:0] == P1_REQ_B0);
          rx_px_req_state_in    = {(rx_data_out[7:0] == P3_REQ_B0),
                                   (rx_data_out[7:0] == P2_REQ_B0),
                                   (rx_data_out[7:0] == P1_REQ_B0)};
          rx_px_start_in        =  (rx_data_out[7:0] == P_START_B0);
                    
          cur_attr_rd_req_in    = (rx_data_out[7:0] == ATTR_RD_B0);
          cur_attr_wr_req_in    = (rx_data_out[7:0] == ATTR_WR_B0);
          
          
          if(DATA_WIDTH==16) begin
            //Attribute
            if(cur_attr_rd_req_in || cur_attr_wr_req_in) begin
              attr_addr_in[7:0] = rx_data_out[15:8];
            end
          end
        end
      end
      
      //--------------------
      'd1 : begin
        ctrl_byte_count_in      = ctrl_byte_count + 'd1;
        attr_addr_in[7:0]       = rx_data_out[7:0];
      end
      
      //--------------------
      'd2 : begin
        ctrl_byte_count_in      = ctrl_byte_count + (DATA_WIDTH/8);
        if(DATA_WIDTH==8) begin
          attr_addr_in[15:8]    = rx_data_out[7:0];
        end
        if(DATA_WIDTH==16) begin
          attr_addr_in[15:8]    = rx_data_out[7:0];
          attr_data_in[ 7:0]    = rx_data_out[15:8];
        end
      end
      
      //--------------------
      'd3 : begin
        ctrl_byte_count_in      = ctrl_byte_count + 'd1;
        attr_data_in[ 7:0]      = rx_data_out[7:0];
      end
      
      //--------------------
      'd4 : begin
        ctrl_byte_count_in      = ctrl_byte_count + (DATA_WIDTH/8);
        if(DATA_WIDTH==8) begin
          attr_data_in[15:8]    = rx_data_out[7:0];
        end
        if(DATA_WIDTH==16) begin
          attr_data_in[15:8]    = rx_data_out[7:0];
        end
        attr_update_in          = cur_attr_wr_req;
      end
      
      default : begin
        ctrl_byte_count_in = ctrl_byte_count + (DATA_WIDTH/8);
        if(ctrl_byte_count_in == 'd0) begin
          cur_attr_wr_req_in  = 1'b0;
          cur_attr_rd_req_in  = 1'b0;
          cur_attr_rsp_req_in = 1'b0;
        end
      end
    endcase
  end else begin
    ctrl_byte_count_in    = 'd0;
    ctrl_byte_active_in   = 'd0;
    rx_px_req_in          = 'd0;
    rx_px_req_state_in    = 'd0;
    rx_px_start_in        = 'd0;   
    
    cur_attr_wr_req_in    = 1'b0;
    cur_attr_rd_req_in    = 1'b0;
    cur_attr_rsp_req_in   = 1'b0; 
  end
end


//assign ll_rx_datavalid = ~ctrl_byte_active_in && (&rx_data_valid_out);
assign ll_rx_datavalid = ~ctrl_byte_active_in && (&(rx_data_valid_out | ~lane_active));

endmodule

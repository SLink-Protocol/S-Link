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
  
  input  wire [2:0]                           active_lanes,
  output wire [(NUM_LANES*FIFO_CLOG2)-1:0]    fifo_ptr_status,
  output reg  [NUM_LANES-1:0]                 rx_ts1_seen,
  output reg  [NUM_LANES-1:0]                 rx_ts2_seen,
  output reg  [NUM_LANES-1:0]                 rx_sds_seen,
  output wire [(NUM_LANES*DATA_WIDTH)-1:0]    rx_data_out,
  output wire                                 rx_data_valid_out,
  
  output wire [1:0]                           deskew_state
);

`include "slink_includes.vh"

localparam      IDLE    = 'd0,
                TRAIN   = 'd1,
                LOCKED  = 'd2;


reg   [1:0]             state, nstate;
reg   [DATA_WIDTH-1:0]  data_fifo         [NUM_LANES-1:0] [FIFO_DEPTH-1:0];   //data storage
reg   [FIFO_CLOG2:0]    fifo_ptr          [NUM_LANES-1:0];                    //keeps up with the com location and has a valid signal
reg   [FIFO_CLOG2:0]    fifo_ptr_in       [NUM_LANES-1:0];                    //
wire  [DATA_WIDTH-1:0]  com_value;
wire  [NUM_LANES-1:0]   com_seen;
wire                    com_all_lanes;
reg   [3:0]             ts1_byte_count     [NUM_LANES-1:0];
reg   [3:0]             ts1_byte_count_in  [NUM_LANES-1:0];
reg   [3:0]             ts2_byte_count     [NUM_LANES-1:0];
reg   [3:0]             ts2_byte_count_in  [NUM_LANES-1:0];

reg   [3:0]             sds_byte_count     [NUM_LANES-1:0];
reg   [3:0]             sds_byte_count_in  [NUM_LANES-1:0];
reg   [NUM_LANES-1:0]   rx_ts2_seen_prev;


wire  [NUM_LANES-1:0]   lane_active;

assign com_value = (DATA_WIDTH == 8)  ? 8'hbc    :
                   (DATA_WIDTH == 16) ? 16'h55bc : 32'h5555_55bc;



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
          fifo_ptr[laneindex]                   <= 'd0;
        end else begin
          if(fifoindex == 0) begin
            data_fifo[laneindex][fifoindex]     <= rx_data_in[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)];
          end else begin
            data_fifo[laneindex][fifoindex]     <= data_fifo[laneindex][fifoindex-1];
          end
          
          fifo_ptr[laneindex]                   <=  (state == IDLE)   ? {FIFO_CLOG2+1{1'b0}} : 
                                                    (state == TRAIN)  ? fifo_ptr_in[laneindex] : fifo_ptr[laneindex];
        end
      end
                       
    end //for
    
    //Make this up to 16 entries?
    
    always@(*) begin
      case({data_fifo[laneindex][3] == com_value,
            data_fifo[laneindex][2] == com_value,
            data_fifo[laneindex][1] == com_value,
            data_fifo[laneindex][0] == com_value})
        4'b0001 : fifo_ptr_in[laneindex] = {1'b1, 2'd0};
        4'b0010 : fifo_ptr_in[laneindex] = {1'b1, 2'd1};
        4'b0100 : fifo_ptr_in[laneindex] = {1'b1, 2'd2};
        4'b1000 : fifo_ptr_in[laneindex] = {1'b1, 2'd3};
        default : fifo_ptr_in[laneindex] = 'd0;
      endcase            
    end
    
   
    assign rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)]     = lane_active[laneindex] ? data_fifo[laneindex][fifo_ptr[laneindex][FIFO_CLOG2-1:0]] : {DATA_WIDTH{1'b0}};
        
    assign fifo_ptr_status[((laneindex+1)*FIFO_CLOG2)-1:(laneindex*FIFO_CLOG2)] = lane_active[laneindex] ? fifo_ptr[laneindex][FIFO_CLOG2-1:0] : {FIFO_CLOG2{1'b0}};
    
    assign com_seen[laneindex]                                                  = fifo_ptr[laneindex][FIFO_CLOG2] || ~lane_active[laneindex];
    
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


assign com_all_lanes = &com_seen;

always @(*) begin
  nstate            = state;
  
  case(state)
    IDLE : begin
      if(enable) begin
        nstate      = TRAIN;
      end
    end
    
    TRAIN : begin
      if(com_all_lanes) begin
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

assign rx_data_valid_out = state == LOCKED;



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
  
    
    always @(*) begin
      if(state == LOCKED) begin
        case(ts1_byte_count[laneindex])
          4'd0 : begin
            ts1_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TSX_BYTE0                    ? 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {TS1_BYTEX, TSX_BYTE0}       ? 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {{3{TS1_BYTEX}}, TSX_BYTE0}  ? 'd4 : 'd0);
          end

          default : begin
            ts1_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TS1_BYTEX       ? ts1_byte_count[laneindex] + 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {2{TS1_BYTEX}}  ? ts1_byte_count[laneindex] + 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {4{TS1_BYTEX}}  ? ts1_byte_count[laneindex] + 'd4 : 'd0);
          end 
        endcase
        
        case(ts2_byte_count[laneindex])
          4'd0 : begin
            ts2_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TSX_BYTE0                    ? 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {TS2_BYTEX, TSX_BYTE0}       ? 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {{3{TS2_BYTEX}}, TSX_BYTE0}  ? 'd4 : 'd0);
          end

          default : begin
            ts2_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == TS2_BYTEX       ? ts2_byte_count[laneindex] + 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {2{TS2_BYTEX}}  ? ts2_byte_count[laneindex] + 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {4{TS2_BYTEX}}  ? ts2_byte_count[laneindex] + 'd4 : 'd0);
          end 
        endcase
        
        
        case(sds_byte_count[laneindex])
          4'd0 : begin
            sds_byte_count_in[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == SDS_BYTE0                    ? 'd1 : 'd0) :
                                           (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {SDS_BYTEX, SDS_BYTE0}       ? 'd2 : 'd0) : 
                                                                (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == {{3{SDS_BYTEX}}, SDS_BYTE0}  ? 'd4 : 'd0);
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
    
    
    always @(*) begin
      rx_ts1_seen[laneindex] = lane_active[laneindex] ? ((DATA_WIDTH == 8)  ? ts1_byte_count[laneindex] == 'd15 : 
                                                         (DATA_WIDTH == 16) ? ts1_byte_count[laneindex] == 'd14 : ts1_byte_count[laneindex] == 'd12) : 1'b1;
      rx_ts2_seen[laneindex] = lane_active[laneindex] ? ((DATA_WIDTH == 8)  ? ts2_byte_count[laneindex] == 'd15 : 
                                                         (DATA_WIDTH == 16) ? ts2_byte_count[laneindex] == 'd14 : ts2_byte_count[laneindex] == 'd12) : 1'b1;
      rx_sds_seen[laneindex] = lane_active[laneindex] ? ((DATA_WIDTH == 8)  ? sds_byte_count[laneindex] == 'd15 : 
                                                         (DATA_WIDTH == 16) ? sds_byte_count[laneindex] == 'd14 : sds_byte_count[laneindex] == 'd12) : 1'b1;
    
//       rx_sds_seen[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)]  == 8'hdc && rx_ts2_seen_prev[laneindex]) :
//                                (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-9:(laneindex*DATA_WIDTH)]  == 8'hdc && rx_ts2_seen_prev[laneindex]) :
//                                                     (rx_data_out[((laneindex+1)*DATA_WIDTH)-25:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]);
    end
    
    
// //     assign rx_sds_seen[laneindex] = (DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]) :
// //                                     (DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-9:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]) :
// //                                                          (rx_data_out[((laneindex+1)*DATA_WIDTH)-25:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]);
//     assign rx_sds_seen[laneindex] = (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]);//(DATA_WIDTH == 8)  ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-1:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]) :
//                                     //(DATA_WIDTH == 16) ? (rx_data_out[((laneindex+1)*DATA_WIDTH)-9:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]) :
//                                     //                     (rx_data_out[((laneindex+1)*DATA_WIDTH)-25:(laneindex*DATA_WIDTH)] == 8'hdc && rx_ts2_seen_prev[laneindex]);
  end
endgenerate




endmodule

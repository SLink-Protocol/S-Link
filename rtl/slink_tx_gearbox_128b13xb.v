module slink_tx_gearbox_128b13xb #(
  parameter DATA_WIDTH  = 16
)(
  input  wire                   clk,
  input  wire                   reset,
  input  wire [DATA_WIDTH-1:0]  tx_data_in,
  input  wire [3:0]             tx_syncheader,
  input  wire                   tx_startblock,
  input  wire                   tx_datavalid,
  input  wire                   enable,
  input  wire                   encode_mode,      //0 - 128b130b, 1 - 128b132b
  
  output reg  [DATA_WIDTH-1:0]  tx_data_out  
);

localparam COUNT_WIDTH = $clog2(DATA_WIDTH)-1;
localparam BIT_COUNT_WIDTH = $clog2(DATA_WIDTH);

reg   [DATA_WIDTH-1:0]          data_buffer;
reg   [DATA_WIDTH-1:0]          data_buffer_in;
reg   [COUNT_WIDTH-1:0]         count;
wire  [COUNT_WIDTH-1:0]         count_in;
wire  [BIT_COUNT_WIDTH-1:0]     bit_count;

always @(posedge clk or posedge reset) begin
  if(reset) begin
    data_buffer     <= {DATA_WIDTH{1'b0}};
    count           <= {COUNT_WIDTH{1'b1}};
  end else begin
    data_buffer     <= data_buffer_in;
    count           <= count_in;
  end
end



 
assign count_in       = enable ? (tx_startblock && tx_datavalid) ? (encode_mode ? count + 'd2 : count + 'd1) : count : (encode_mode ? {{COUNT_WIDTH-1{1'b1}}, 1'b0} : {COUNT_WIDTH{1'b1}});
assign bit_count      = count_in << 1;




always @(*) begin
  data_buffer_in      = 'd0;
  if(encode_mode) begin
    //-----------------------------
    //128b / 132b
    //-----------------------------
    if(DATA_WIDTH == 8) begin
      case(bit_count) 
        'h0  : data_buffer_in[ 3: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-4];
        'h4  : data_buffer_in[ 7: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-8];
        default : data_buffer_in     = 'd0;
      endcase
    end

    if(DATA_WIDTH == 16) begin
      case(bit_count) 
        'h0  : data_buffer_in[ 3: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-4];
        'h4  : data_buffer_in[ 7: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-8];
        'h8  : data_buffer_in[11: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-12];
        'hc  : data_buffer_in[15: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-16];
        default : data_buffer_in     = 'd0;
      endcase
    end

    if(DATA_WIDTH == 32) begin
      case(bit_count) 
        'h0  : data_buffer_in[ 3: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-4];
        'h4  : data_buffer_in[ 7: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-8];
        'h8  : data_buffer_in[11: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-12];
        'hc  : data_buffer_in[15: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-16];
        
        'h10 : data_buffer_in[19: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-20];
        'h14 : data_buffer_in[23: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-24];
        'h18 : data_buffer_in[27: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-28];
        'h1c : data_buffer_in[31: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-32];
        default : data_buffer_in     = 'd0;
      endcase
    end
  end else begin
    //-----------------------------
    //128b / 130b
    //-----------------------------
    if(DATA_WIDTH == 8) begin
      case(bit_count) 
        'h0  : data_buffer_in[ 1: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-2];
        'h2  : data_buffer_in[ 3: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-4];
        'h4  : data_buffer_in[ 5: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-6];
        'h6  : data_buffer_in[ 7: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-8];
        default : data_buffer_in     = 'd0;
      endcase
    end

    if(DATA_WIDTH == 16) begin
      case(bit_count) 
        'h0  : data_buffer_in[ 1: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-2];
        'h2  : data_buffer_in[ 3: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-4];
        'h4  : data_buffer_in[ 5: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-6];
        'h6  : data_buffer_in[ 7: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-8];
        'h8  : data_buffer_in[ 9: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-10];
        'ha  : data_buffer_in[11: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-12];
        'hc  : data_buffer_in[13: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-14];
        'he  : data_buffer_in[15: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-16];
        default : data_buffer_in     = 'd0;
      endcase
    end

    if(DATA_WIDTH == 32) begin
      case(bit_count) 
        'h0  : data_buffer_in[ 1: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-2];
        'h2  : data_buffer_in[ 3: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-4];
        'h4  : data_buffer_in[ 5: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-6];
        'h6  : data_buffer_in[ 7: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-8];
        'h8  : data_buffer_in[ 9: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-10];
        'ha  : data_buffer_in[11: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-12];
        'hc  : data_buffer_in[13: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-14];
        'he  : data_buffer_in[15: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-16];
        'h10 : data_buffer_in[17: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-18];
        'h12 : data_buffer_in[19: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-20];
        'h14 : data_buffer_in[21: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-22];
        'h16 : data_buffer_in[23: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-24];
        'h18 : data_buffer_in[25: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-26];
        'h1a : data_buffer_in[27: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-28];
        'h1c : data_buffer_in[29: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-30];
        'h1e : data_buffer_in[31: 0] = tx_data_in[DATA_WIDTH-1 : DATA_WIDTH-32];
        default : data_buffer_in     = 'd0;
      endcase
    end
  end

end

always @(*) begin
  if(encode_mode) begin
    //-----------------------------
    //128b / 132b
    //-----------------------------
    if(DATA_WIDTH == 8) begin
      case(bit_count)
        'h0 : tx_data_out = tx_startblock ? {tx_data_in[ 3: 0], tx_syncheader[3:0]}                     : {tx_data_in[ 3: 0], data_buffer[ 3: 0]};
        'h4 : tx_data_out = tx_startblock ? {                   tx_syncheader[3:0], data_buffer[ 3: 0]} : {                   data_buffer[ 7: 0]};
        default : tx_data_out = 'd0;
      endcase
    end

    if(DATA_WIDTH == 16) begin
      case(bit_count)
        'h0 : tx_data_out = tx_startblock ? {tx_data_in[11: 0], tx_syncheader[3:0]}                     : {tx_data_in[11: 0], data_buffer[ 3: 0]};
        'h4 : tx_data_out = tx_startblock ? {tx_data_in[ 7: 0], tx_syncheader[3:0], data_buffer[ 3: 0]} : {tx_data_in[ 7: 0], data_buffer[ 7: 0]};
        'h8 : tx_data_out = tx_startblock ? {tx_data_in[ 3: 0], tx_syncheader[3:0], data_buffer[ 7: 0]} : {tx_data_in[ 3: 0], data_buffer[11: 0]};
        'hc : tx_data_out = tx_startblock ? {                   tx_syncheader[3:0], data_buffer[11: 0]} : {                   data_buffer[15: 0]};
        default : tx_data_out = 'd0;
      endcase
    end

    if(DATA_WIDTH == 32) begin
      case(bit_count)
        'h0  : tx_data_out = tx_startblock ? {tx_data_in[27: 0], tx_syncheader[3:0]}                     : {tx_data_in[27: 0], data_buffer[ 3: 0]};
        'h4  : tx_data_out = tx_startblock ? {tx_data_in[23: 0], tx_syncheader[3:0], data_buffer[ 3: 0]} : {tx_data_in[23: 0], data_buffer[ 7: 0]};
        'h8  : tx_data_out = tx_startblock ? {tx_data_in[19: 0], tx_syncheader[3:0], data_buffer[ 7: 0]} : {tx_data_in[19: 0], data_buffer[11: 0]};
        'hc  : tx_data_out = tx_startblock ? {tx_data_in[15: 0], tx_syncheader[3:0], data_buffer[11: 0]} : {tx_data_in[15: 0], data_buffer[15: 0]};
        
        'h10 : tx_data_out = tx_startblock ? {tx_data_in[11: 0], tx_syncheader[3:0], data_buffer[15: 0]} : {tx_data_in[11: 0], data_buffer[19: 0]};
        'h14 : tx_data_out = tx_startblock ? {tx_data_in[ 7: 0], tx_syncheader[3:0], data_buffer[19: 0]} : {tx_data_in[ 7: 0], data_buffer[23: 0]};
        'h18 : tx_data_out = tx_startblock ? {tx_data_in[ 3: 0], tx_syncheader[3:0], data_buffer[23: 0]} : {tx_data_in[ 3: 0], data_buffer[27: 0]};
        'h1c : tx_data_out = tx_startblock ? {                   tx_syncheader[3:0], data_buffer[27: 0]} : {                   data_buffer[31: 0]};
        default : tx_data_out = 'd0;
      endcase
    end
  end else begin
    //-----------------------------
    //128b / 130b
    //-----------------------------
    if(DATA_WIDTH == 8) begin
      case(bit_count)
        'h0 : tx_data_out = tx_startblock ? {tx_data_in[ 5: 0], tx_syncheader[1:0]}                     : {tx_data_in[ 5: 0], data_buffer[1 : 0]};
        'h2 : tx_data_out = tx_startblock ? {tx_data_in[ 3: 0], tx_syncheader[1:0], data_buffer[ 1: 0]} : {tx_data_in[ 3: 0], data_buffer[3 : 0]};
        'h4 : tx_data_out = tx_startblock ? {tx_data_in[ 1: 0], tx_syncheader[1:0], data_buffer[ 3: 0]} : {tx_data_in[ 1: 0], data_buffer[5 : 0]};

        'h6 : tx_data_out = tx_startblock ? {                   tx_syncheader[1:0], data_buffer[ 5: 0]} : {                   data_buffer[7 : 0]};
        default : tx_data_out = 'd0;
      endcase
    end

    if(DATA_WIDTH == 16) begin
      case(bit_count)
        'h0 : tx_data_out = tx_startblock ? {tx_data_in[13: 0], tx_syncheader[1:0]}                     : {tx_data_in[13: 0], data_buffer[1 : 0]};
        'h2 : tx_data_out = tx_startblock ? {tx_data_in[11: 0], tx_syncheader[1:0], data_buffer[ 1: 0]} : {tx_data_in[11: 0], data_buffer[3 : 0]};
        'h4 : tx_data_out = tx_startblock ? {tx_data_in[ 9: 0], tx_syncheader[1:0], data_buffer[ 3: 0]} : {tx_data_in[ 9: 0], data_buffer[5 : 0]};

        'h6 : tx_data_out = tx_startblock ? {tx_data_in[ 7: 0], tx_syncheader[1:0], data_buffer[ 5: 0]} : {tx_data_in[ 7: 0], data_buffer[7 : 0]};
        'h8 : tx_data_out = tx_startblock ? {tx_data_in[ 5: 0], tx_syncheader[1:0], data_buffer[ 7: 0]} : {tx_data_in[ 5: 0], data_buffer[9 : 0]};
        'ha : tx_data_out = tx_startblock ? {tx_data_in[ 3: 0], tx_syncheader[1:0], data_buffer[ 9: 0]} : {tx_data_in[ 3: 0], data_buffer[11: 0]};
        'hc : tx_data_out = tx_startblock ? {tx_data_in[ 1: 0], tx_syncheader[1:0], data_buffer[11: 0]} : {tx_data_in[ 1: 0], data_buffer[13: 0]};

        'he : tx_data_out = tx_startblock ? {                   tx_syncheader[1:0], data_buffer[13: 0]} : {                   data_buffer[15: 0]};
        default : tx_data_out = 'd0;
      endcase
    end

    if(DATA_WIDTH == 32) begin
      case(bit_count)
        'h0  : tx_data_out = tx_startblock ? {tx_data_in[29: 0], tx_syncheader[1:0]}                     : {tx_data_in[29: 0], data_buffer[ 1: 0]};
        'h2  : tx_data_out = tx_startblock ? {tx_data_in[27: 0], tx_syncheader[1:0], data_buffer[ 1: 0]} : {tx_data_in[27: 0], data_buffer[ 3: 0]};
        'h4  : tx_data_out = tx_startblock ? {tx_data_in[25: 0], tx_syncheader[1:0], data_buffer[ 3: 0]} : {tx_data_in[25: 0], data_buffer[ 5: 0]};
        'h6  : tx_data_out = tx_startblock ? {tx_data_in[23: 0], tx_syncheader[1:0], data_buffer[ 5: 0]} : {tx_data_in[23: 0], data_buffer[ 7: 0]};
        'h8  : tx_data_out = tx_startblock ? {tx_data_in[21: 0], tx_syncheader[1:0], data_buffer[ 7: 0]} : {tx_data_in[21: 0], data_buffer[ 9: 0]};
        'ha  : tx_data_out = tx_startblock ? {tx_data_in[19: 0], tx_syncheader[1:0], data_buffer[ 9: 0]} : {tx_data_in[19: 0], data_buffer[11: 0]};
        'hc  : tx_data_out = tx_startblock ? {tx_data_in[17: 0], tx_syncheader[1:0], data_buffer[11: 0]} : {tx_data_in[17: 0], data_buffer[13: 0]};
        'he  : tx_data_out = tx_startblock ? {tx_data_in[15: 0], tx_syncheader[1:0], data_buffer[13: 0]} : {tx_data_in[15: 0], data_buffer[15: 0]};

        'h10 : tx_data_out = tx_startblock ? {tx_data_in[13: 0], tx_syncheader[1:0], data_buffer[15: 0]} : {tx_data_in[13: 0], data_buffer[17: 0]};
        'h12 : tx_data_out = tx_startblock ? {tx_data_in[11: 0], tx_syncheader[1:0], data_buffer[17: 0]} : {tx_data_in[11: 0], data_buffer[19: 0]};
        'h14 : tx_data_out = tx_startblock ? {tx_data_in[ 9: 0], tx_syncheader[1:0], data_buffer[19: 0]} : {tx_data_in[ 9: 0], data_buffer[21: 0]};
        'h16 : tx_data_out = tx_startblock ? {tx_data_in[ 7: 0], tx_syncheader[1:0], data_buffer[21: 0]} : {tx_data_in[ 7: 0], data_buffer[23: 0]};
        'h18 : tx_data_out = tx_startblock ? {tx_data_in[ 5: 0], tx_syncheader[1:0], data_buffer[23: 0]} : {tx_data_in[ 5: 0], data_buffer[25: 0]};
        'h1a : tx_data_out = tx_startblock ? {tx_data_in[ 3: 0], tx_syncheader[1:0], data_buffer[25: 0]} : {tx_data_in[ 3: 0], data_buffer[27: 0]};
        'h1c : tx_data_out = tx_startblock ? {tx_data_in[ 1: 0], tx_syncheader[1:0], data_buffer[27: 0]} : {tx_data_in[ 1: 0], data_buffer[29: 0]};
        'h1e : tx_data_out = tx_startblock ? {                   tx_syncheader[1:0], data_buffer[29: 0]} : {                   data_buffer[31: 0]};

        default : tx_data_out = 'd0;
      endcase
    end
  
  end
end
                   

endmodule

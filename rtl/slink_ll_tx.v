module slink_ll_tx #(
  parameter     NUM_LANES             = 4,
  parameter     DATA_WIDTH            = 8,
  parameter     APP_DATA_WIDTH        = 32,         //Must be >= NUM_LANES * DATA_WIDTH
  parameter     APP_DATA_BYTES        = APP_DATA_WIDTH >> 3,
  parameter     APP_DATA_BYTES_CLOG2  = APP_DATA_BYTES == 1 ? 1 : $clog2(APP_DATA_BYTES), //protect against byte based app datas in 1lane mode
  parameter     AUX_FIFO_ADDR_WIDTH   = 3
)(
  input  wire                                 clk,
  input  wire                                 reset,
  input  wire                                 enable,
  
  input  wire [7:0]                           swi_short_packet_max,
  
  //Interface to App
  input  wire                                 sop,
  input  wire [7:0]                           data_id,
  input  wire [15:0]                          word_count,
  input  wire [(APP_DATA_BYTES*8)-1:0]        app_data,
  input  wire                                 valid,
  output wire                                 advance,
  
  input  wire [1:0]                           delimeter,  
  
  // Configuration Based Settings
  input  wire [2:0]                           active_lanes,
  
  //
  input  wire                                 sds_sent,
  
  //To PHY/LTSSM
  input  wire                                 ll_tx_valid,
  output wire [(NUM_LANES*DATA_WIDTH)-1:0]    link_data,
  output reg                                  link_idle,
  
  output wire [3:0]                           ll_tx_state
  
);

`include "slink_includes.vh"


localparam      WAIT_SDS      = 'd0,
                IDLE          = 'd1,
                HEADER_DI     = 'd2,
                HEADER_WC0    = 'd3,
                HEADER_WC1    = 'd4,
                HEADER_ECC    = 'd5,
                LONG_DATA     = 'd6,
                CRC0          = 'd7,
                CRC1          = 'd8,
                IDL_SYM_ST    = 'd9;
                

reg   [3:0]                               state, nstate;
wire  [3:0]                               nstate_idle_check;

reg   [(NUM_LANES*DATA_WIDTH)-1:0]        link_data_reg, link_data_reg_in;
reg   [15:0]                              byte_count, byte_count_in;
wire  [7:0]                               calculated_ecc;
reg   [23:0]                              packet_header_syn_in;
reg                                       advance_in;
reg   [15:0]                              word_count_reg, word_count_reg_in;
reg   [7:0]                               data_id_reg, data_id_reg_in;
wire                                      is_short_pkt;
reg                                       is_short_pkt_reg;
reg                                       is_short_pkt_reg_in;


reg                                           crc_init;
reg   [(NUM_LANES * (DATA_WIDTH/8))-1:0]      crc_valid;
wire  [((NUM_LANES * (DATA_WIDTH/8))*16)-1:0] crc_next, crc_prev, crc_reg;
reg   [(NUM_LANES * DATA_WIDTH)-1:0]          crc_input;

reg   [1:0]                               delim_count;
wire  [1:0]                               delim_count_in;
wire                                      delim_adv;
wire                                      delim_start;

localparam  APP_DATA_SAVED_SIZE = ((NUM_LANES*DATA_WIDTH) - 32) == 0 ? 1 : 32;
reg   [APP_DATA_SAVED_SIZE-1:0] app_data_saved, app_data_saved_in;
reg                             advance_prev;


always @(posedge clk or posedge reset) begin
  if(reset) begin
    state               <= WAIT_SDS;
    link_data_reg       <= {(NUM_LANES*DATA_WIDTH){1'b0}};
    byte_count          <= 16'd0;
    word_count_reg      <= 16'd0;
    data_id_reg         <= 8'd0;
    delim_count         <= 'd0;
    app_data_saved      <= {APP_DATA_SAVED_SIZE{1'b0}};
    advance_prev        <= 1'b0;
    is_short_pkt_reg    <= 1'b0;
  end else begin
    state               <= nstate;
    link_data_reg       <= link_data_reg_in;
    byte_count          <= byte_count_in;
    word_count_reg      <= word_count_reg_in;
    data_id_reg         <= data_id_reg_in;
    delim_count         <= delim_count_in;
    app_data_saved      <= app_data_saved_in;
    advance_prev        <= ~ll_tx_valid ? advance_prev : advance; //need to save this if we don't have a valid data cycle
    is_short_pkt_reg    <= is_short_pkt_reg_in;
  end
end

//Error injection for sims
`ifndef SYNTHESIS
reg ecc_error_injected,   ecc_error_injected_in;
reg crc_error_injected,   crc_error_injected_in;
int ecc_bit_error1;
int ecc_bit_error2;
int crc_bit_error;
int error_wait_count;
int error_wait_count_pa;
always @(posedge clk or posedge reset) begin
  if(reset) begin
    ecc_error_injected  <= 0;
    crc_error_injected  <= 0;
  end else begin
    ecc_error_injected  <= ecc_error_injected_in;
    crc_error_injected  <= crc_error_injected_in;
  end
end

initial begin
  if($value$plusargs("SLINK_ERR_WAIT_COUNT=%d", error_wait_count_pa)) begin
  end else begin
    error_wait_count_pa = 50; //every 50 packets
  end
end

`endif

assign ll_tx_state        = state;

assign is_short_pkt       = data_id <= swi_short_packet_max;

//Delimeter is used to force packets to start when each LANE has sent 32bits.
//This combats vaious lane widths (8/16/32) without the need to have some complicated scheme.
//This does have a bandwidth impact, but we can likely disable this through the delimeter 
//value in the attributes if we know both sides are the same data width 
assign delim_count_in     = enable ? ll_tx_valid ? (nstate == WAIT_SDS) || delim_adv ? 'd0 : delim_count + 'd1 : delim_count : 'd0;
assign delim_adv          = delim_count == delimeter;
assign nstate_idle_check  = delim_adv ? IDLE : IDL_SYM_ST;
assign delim_start        = delim_count == 'd0;

always @(*) begin
  nstate                  = state;
  link_data_reg_in        = link_data_reg;
  byte_count_in           = byte_count;
  advance_in              = 1'b0;
  word_count_reg_in       = word_count_reg;
  data_id_reg_in          = data_id_reg;
  crc_valid               = {(NUM_LANES * (DATA_WIDTH/8)){1'b0}};
  crc_init                = 1'b0;
  packet_header_syn_in    = {word_count_reg, data_id_reg};
  app_data_saved_in       = app_data_saved;
  crc_input               = {(NUM_LANES * DATA_WIDTH){1'b0}};
  link_idle               = 1'b0;
  is_short_pkt_reg_in     = is_short_pkt_reg;
  
  
  `ifndef SYNTHESIS
  ecc_error_injected_in   = ecc_error_injected;
  crc_error_injected_in   = crc_error_injected;
  `endif
  
  case(state)
    //-------------------------------------------
    WAIT_SDS : begin      
      crc_init                        = 1'b1;
      packet_header_syn_in            = {NOP_WC1, NOP_WC0, NOP_DATAID};
      link_data_reg_in                = {(NUM_LANES * DATA_WIDTH){1'b0}};
      if(sds_sent) begin  //it should not be possible for tx_datavalid to be low when sds_sent is see
        nstate                        = IDLE;
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, NOP_DATAID};
              byte_count_in         = 'd1;
            end

            if(DATA_WIDTH==16) begin
              link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, NOP_WC0, NOP_DATAID};
              byte_count_in         = 'd2;
            end
          end
          
          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in      = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, NOP_WC0, NOP_DATAID};
                byte_count_in         = 'd1;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in      = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, calculated_ecc, NOP_WC0, NOP_WC1, NOP_DATAID};
                byte_count_in         = 'd0;
              end
            end
          end
          
          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in      = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, calculated_ecc, NOP_WC1, NOP_WC0, NOP_DATAID};
                byte_count_in         = 'd0;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in      = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, {2{calculated_ecc}}, {2{NOP_WC1}}, {2{NOP_WC0}}, {2{NOP_DATAID}}};
                byte_count_in         = 'd0;
              end
            end
          end
          
          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in      = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {2{calculated_ecc, NOP_WC1, NOP_WC0, NOP_DATAID}}};
                byte_count_in         = 'd0;
              end
              
              if(DATA_WIDTH==16) begin
                link_data_reg_in      = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {2{calculated_ecc}}, {2{NOP_WC1}}, {2{NOP_WC0}}, {2{NOP_DATAID}},
                                                                             {2{calculated_ecc}}, {2{NOP_WC1}}, {2{NOP_WC0}}, {2{NOP_DATAID}}};
                byte_count_in         = 'd0;
              end
            end
          end                    
        endcase
      end
    end
    
    //-------------------------------------------
    IDLE : begin
      crc_init                        = 1'b1;
      packet_header_syn_in            = {NOP_WC1, NOP_WC0, NOP_DATAID};
      if(ll_tx_valid) begin
        if(byte_count) begin
          //In NOP (this is only possible for 1/2 lane modes)
          case(active_lanes)
            ONE_LANE : begin
              if(DATA_WIDTH==8) begin
                case(byte_count)
                  'd1 : begin
                    link_data_reg_in = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, NOP_WC0};
                    byte_count_in    = 'd2;
                  end
                  'd2 : begin
                    link_data_reg_in = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, NOP_WC1};
                    byte_count_in    = 'd3;
                  end
                  'd3 : begin
                    link_data_reg_in = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, calculated_ecc};
                    byte_count_in    = 'd0;
                  end
                endcase
              end

              if(DATA_WIDTH==16) begin
                case(byte_count)
                  'd2 : begin
                    link_data_reg_in = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, calculated_ecc, NOP_WC1};
                    byte_count_in    = 'd0;
                  end
                endcase
              end              
            end


            TWO_LANE : begin
              if(NUM_LANES >= 2) begin
                if(DATA_WIDTH==8) begin
                  link_data_reg_in    = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, calculated_ecc, NOP_WC1};
                  byte_count_in       = 'd0;
                end
              end
            end
          endcase

        end else if(sop && delim_start) begin
          //End of NOP and sop data to send
          data_id_reg_in                = data_id;
          word_count_reg_in             = word_count;
          crc_init                      = 1'b1;
          packet_header_syn_in          = {word_count_reg_in, data_id_reg_in};
          is_short_pkt_reg_in           = is_short_pkt;

          case(active_lanes)
            ONE_LANE : begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, data_id};
                byte_count_in         = 'd0;
                nstate                = HEADER_WC0;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, word_count[ 7: 0], data_id};
                byte_count_in         = 'd1;
                nstate                = HEADER_WC1;
              end
            end


            TWO_LANE : begin
              if(NUM_LANES >= 2) begin
                if(DATA_WIDTH==8) begin
                  link_data_reg_in      = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, word_count[ 7: 0], data_id};
                  byte_count_in         = 'd1;
                  nstate                = HEADER_WC1;
                end

                if(DATA_WIDTH==16) begin
                  link_data_reg_in      = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, calculated_ecc, word_count_reg_in[ 7: 0],   word_count_reg_in[15: 8],   data_id};
                  byte_count_in         = 'd0;
                  advance_in            = is_short_pkt;
                  nstate                = is_short_pkt ? IDLE : LONG_DATA;
                end
              end
            end


            FOUR_LANE : begin            
              if(NUM_LANES >= 4) begin
                if(DATA_WIDTH==8) begin
                  link_data_reg_in      = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, calculated_ecc, word_count[15: 0],          data_id};
                  byte_count_in         = 'd0;
                  advance_in            = is_short_pkt;
                  nstate                = is_short_pkt ? IDLE : LONG_DATA;
                end

                if(DATA_WIDTH==16) begin
                  if(is_short_pkt) begin
                    link_data_reg_in    = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, IDL_SYM, calculated_ecc, IDL_SYM, word_count[15: 8], IDL_SYM, word_count[ 7: 0], IDL_SYM, data_id};
                    advance_in          = 1'b1;
                    nstate              = IDLE;
                  end else begin
                    crc_init            = 1'b0;
                    byte_count_in       = 'd4;
                    advance_in          = (APP_DATA_BYTES - byte_count_in[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;

                    //Since we have setup the CRC  input based on the Bytes sent out, bytes 0-3 are the packet header and we
                    //need to effectively start this on the top 4 bytes. 
                    //If we are in a short packet, we also need to take from the respective CRC output (i.e. if only 1 byte, take from byte 4 CRC output)
                    //crc_input           = {{((NUM_LANES-4) * DATA_WIDTH){1'b0}}, app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 32], 32'h0};
                    crc_input           = {{((NUM_LANES-4) * DATA_WIDTH){1'b0}}, app_data[31:0], 32'h0};
                    if(byte_count_in >= word_count) begin
                      advance_in        = 1'b1;
                      case(word_count)
                        'd1 : begin
                          crc_valid         = 'h10;
                          link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   calculated_ecc, 
                                                                                   crc_next  [79:72],
                                                                                   word_count[15: 8],  
                                                                                   crc_next  [71:64],  
                                                                                   word_count[ 7: 0],  
                                                                                   app_data  [ 7: 0],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd2 : begin
                          crc_valid         = 'h30;
                          link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, crc_next  [95:88],
                                                                                   calculated_ecc, 
                                                                                   crc_next  [87:80],
                                                                                   word_count[15: 8],  
                                                                                   app_data  [15: 8], 
                                                                                   word_count[ 7: 0],  
                                                                                   app_data  [ 7: 0],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end


                        'd3 : begin
                          crc_valid         = 'h70;
                          link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, crc_next  [103:96],
                                                                                   calculated_ecc, 
                                                                                   app_data  [23:16],
                                                                                   word_count[15: 8],  
                                                                                   app_data  [15: 8], 
                                                                                   word_count[ 7: 0],  
                                                                                   app_data  [ 7: 0],
                                                                                   data_id};
                          nstate            = CRC1;
                        end

                        'd4 : begin
                          crc_valid         = 'hf0;
                          link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, app_data  [31:24],
                                                                                   calculated_ecc, 
                                                                                   app_data  [23:16],
                                                                                   word_count[15: 8],  
                                                                                   app_data  [15: 8], 
                                                                                   word_count[ 7: 0],  
                                                                                   app_data  [ 7: 0],
                                                                                   data_id};
                          nstate            = CRC0;
                        end

                      endcase
                    end else begin
                      crc_valid         = 'hf0;
                      link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, app_data  [31:24],
                                                                               calculated_ecc, 
                                                                               app_data  [23:16],
                                                                               word_count[15: 8],  
                                                                               app_data  [15: 8], 
                                                                               word_count[ 7: 0],  
                                                                               app_data  [ 7: 0],  
                                                                               data_id};
                      if(advance_in) begin
                        app_data_saved_in = app_data[APP_DATA_WIDTH-1 -: APP_DATA_SAVED_SIZE];
                      end
                      nstate            = LONG_DATA;
                    end
                  end

                end
              end
            end


            EIGHT_LANE : begin
              if(NUM_LANES >= 8) begin
                if(DATA_WIDTH==8) begin
                  if(is_short_pkt) begin
                    link_data_reg_in    = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {4{IDL_SYM}}, calculated_ecc, word_count, data_id};
                    advance_in          = 1'b1;
                    nstate              = IDLE;
                  end else begin
                    crc_init            = 1'b0;
                    byte_count_in       = 'd4;
                    advance_in          = (APP_DATA_BYTES - byte_count_in[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                    crc_input           = {{((NUM_LANES-8) * DATA_WIDTH){1'b0}}, app_data[31:0], 32'h0};

                    if(word_count <= 'd4) begin
                      advance_in        = 1'b1;
                      case(word_count)
                        'd1 : begin
                          crc_valid         = 'h10;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   crc_next  [79:72],
                                                                                   crc_next  [71:64],
                                                                                   app_data  [ 7: 0],
                                                                                   calculated_ecc, 
                                                                                   word_count[15: 8],  
                                                                                   word_count[ 7: 0], 
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd2 : begin
                          crc_valid         = 'h30;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, crc_next  [95:88],
                                                                                   crc_next  [87:80],
                                                                                   app_data  [15: 8],
                                                                                   app_data  [ 7: 0],
                                                                                   calculated_ecc, 
                                                                                   word_count[15: 8],  
                                                                                   word_count[ 7: 0], 
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd3 : begin
                          crc_valid         = 'h70;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, crc_next  [103:96],
                                                                                   app_data  [23:16],
                                                                                   app_data  [15: 8],
                                                                                   app_data  [ 7: 0],
                                                                                   calculated_ecc, 
                                                                                   word_count[15: 8],  
                                                                                   word_count[ 7: 0], 
                                                                                   data_id};
                          nstate            = CRC1;
                        end

                        'd4 : begin
                          crc_valid         = 'hf0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, app_data  [31:24],
                                                                                   app_data  [23:16],
                                                                                   app_data  [15: 8],
                                                                                   app_data  [ 7: 0],
                                                                                   calculated_ecc, 
                                                                                   word_count[15: 8],  
                                                                                   word_count[ 7: 0], 
                                                                                   data_id};
                          nstate            = CRC0;
                        end
                      endcase
                    end else begin
                      crc_valid             = 'hff0;
                      link_data_reg_in      = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, app_data  [31:24],
                                                                                   app_data  [23:16],
                                                                                   app_data  [15: 8],
                                                                                   app_data  [ 7: 0],
                                                                                   calculated_ecc, 
                                                                                   word_count[15: 8],  
                                                                                   word_count[ 7: 0], 
                                                                                   data_id};

                      app_data_saved_in = app_data[APP_DATA_WIDTH-1 -: APP_DATA_SAVED_SIZE];
                      nstate            = LONG_DATA;
                    end
                  end

                end

                if(DATA_WIDTH==16) begin
                  if(is_short_pkt) begin
                    link_data_reg_in    = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {5{IDL_SYM}}, calculated_ecc, IDL_SYM, word_count[15:8], IDL_SYM, word_count[7:0], IDL_SYM, data_id};
                    advance_in          = 1'b1;
                    nstate              = IDLE;
                  end else begin
                    crc_init            = 1'b0;
                    byte_count_in       = 'd12;
                    advance_in          = (APP_DATA_BYTES - byte_count_in[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                    crc_input           = {{((NUM_LANES-8) * DATA_WIDTH){1'b0}}, app_data[95:0], 32'h0};

                    if(word_count <= 'd12) begin
                      advance_in        = 1'b1;
                      case(word_count) 
                        'd1 : begin
                          crc_valid         = 'h10;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   IDL_SYM,
                                                                                   IDL_SYM,
                                                                                   crc_next[79:72],
                                                                                   IDL_SYM,
                                                                                   crc_next[71:64],
                                                                                   IDL_SYM,
                                                                                   app_data[ 7: 0],
                                                                                   IDL_SYM,
                                                                                   calculated_ecc, 
                                                                                   IDL_SYM,
                                                                                   word_count[15: 8],  
                                                                                   IDL_SYM,
                                                                                   word_count[ 7: 0], 
                                                                                   IDL_SYM,
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd2 : begin
                          crc_valid         = 'h30;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   crc_next[95:88],
                                                                                   IDL_SYM,
                                                                                   crc_next[87:80],
                                                                                   IDL_SYM,
                                                                                   app_data[15: 8],
                                                                                   IDL_SYM,
                                                                                   app_data[ 7: 0],
                                                                                   IDL_SYM,
                                                                                   calculated_ecc, 
                                                                                   IDL_SYM,
                                                                                   word_count[15: 8],  
                                                                                   IDL_SYM,
                                                                                   word_count[ 7: 0], 
                                                                                   IDL_SYM,
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd3 : begin
                          crc_valid         = 'h70;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   crc_next[103:96],
                                                                                   IDL_SYM,
                                                                                   app_data[23:16],
                                                                                   IDL_SYM,
                                                                                   app_data[15: 8],
                                                                                   IDL_SYM,
                                                                                   app_data[ 7: 0],
                                                                                   IDL_SYM,
                                                                                   calculated_ecc, 
                                                                                   IDL_SYM,
                                                                                   word_count[15: 8],  
                                                                                   IDL_SYM,
                                                                                   word_count[ 7: 0], 
                                                                                   crc_next[111:104],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd4 : begin
                          crc_valid         = 'hf0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   app_data[31:24],
                                                                                   IDL_SYM,
                                                                                   app_data[23:16],
                                                                                   IDL_SYM,
                                                                                   app_data[15: 8],
                                                                                   IDL_SYM,
                                                                                   app_data[ 7: 0],
                                                                                   IDL_SYM,
                                                                                   calculated_ecc, 
                                                                                   IDL_SYM,
                                                                                   word_count[15: 8],  
                                                                                   crc_next[127:120],
                                                                                   word_count[ 7: 0], 
                                                                                   crc_next[119:112],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd5 : begin
                          crc_valid         = 'h1f0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   app_data[31:24],
                                                                                   IDL_SYM,
                                                                                   app_data[23:16],
                                                                                   IDL_SYM,
                                                                                   app_data[15: 8],
                                                                                   IDL_SYM,
                                                                                   app_data[ 7: 0],
                                                                                   IDL_SYM,
                                                                                   calculated_ecc, 
                                                                                   crc_next[143:136],
                                                                                   word_count[15: 8],  
                                                                                   crc_next[135:128],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd6 : begin
                          crc_valid         = 'h3f0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   app_data[31:24],
                                                                                   IDL_SYM,
                                                                                   app_data[23:16],
                                                                                   IDL_SYM,
                                                                                   app_data[15: 8],
                                                                                   IDL_SYM,
                                                                                   app_data[ 7: 0],
                                                                                   crc_next[159:152],
                                                                                   calculated_ecc, 
                                                                                   crc_next[151:144],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd7 : begin
                          crc_valid         = 'h7f0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   app_data[31:24],
                                                                                   IDL_SYM,
                                                                                   app_data[23:16],
                                                                                   IDL_SYM,
                                                                                   app_data[15: 8],
                                                                                   crc_next[175:168],
                                                                                   app_data[ 7: 0],
                                                                                   crc_next[167:160],
                                                                                   calculated_ecc, 
                                                                                   app_data[55:48],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd8 : begin
                          crc_valid         = 'hff0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   app_data[31:24],
                                                                                   IDL_SYM,
                                                                                   app_data[23:16],
                                                                                   crc_next[191:184],
                                                                                   app_data[15: 8],
                                                                                   crc_next[183:176],
                                                                                   app_data[ 7: 0],
                                                                                   app_data[63:56],
                                                                                   calculated_ecc, 
                                                                                   app_data[55:48],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd9 : begin
                          crc_valid         = 'h1ff0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                                   app_data[31:24],
                                                                                   crc_next[207:200],
                                                                                   app_data[23:16],
                                                                                   crc_next[199:192],
                                                                                   app_data[15: 8],
                                                                                   app_data[71:64],
                                                                                   app_data[ 7: 0],
                                                                                   app_data[63:56],
                                                                                   calculated_ecc, 
                                                                                   app_data[55:48],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd10 : begin
                          crc_valid         = 'h3ff0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, crc_next[223:216],
                                                                                   app_data[31:24],
                                                                                   crc_next[215:208],
                                                                                   app_data[23:16],
                                                                                   app_data[79:72],
                                                                                   app_data[15: 8],
                                                                                   app_data[71:64],
                                                                                   app_data[ 7: 0],
                                                                                   app_data[63:56],
                                                                                   calculated_ecc, 
                                                                                   app_data[55:48],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = nstate_idle_check;
                          byte_count_in     = 'd0;
                        end

                        'd11 : begin
                          crc_valid         = 'h7ff0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, crc_next[231:224],
                                                                                   app_data[31:24],
                                                                                   app_data[87:80],
                                                                                   app_data[23:16],
                                                                                   app_data[79:72],
                                                                                   app_data[15: 8],
                                                                                   app_data[71:64],
                                                                                   app_data[ 7: 0],
                                                                                   app_data[63:56],
                                                                                   calculated_ecc, 
                                                                                   app_data[55:48],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = CRC1;
                          byte_count_in     = 'd0;
                        end

                        'd12 : begin
                          crc_valid         = 'hfff0;
                          link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, app_data[95:88],
                                                                                   app_data[31:24],
                                                                                   app_data[87:80],
                                                                                   app_data[23:16],
                                                                                   app_data[79:72],
                                                                                   app_data[15: 8],
                                                                                   app_data[71:64],
                                                                                   app_data[ 7: 0],
                                                                                   app_data[63:56],
                                                                                   calculated_ecc, 
                                                                                   app_data[55:48],
                                                                                   word_count[15: 8],  
                                                                                   app_data[47:40],
                                                                                   word_count[ 7: 0], 
                                                                                   app_data[39:32],
                                                                                   data_id};
                          nstate            = CRC0;
                          byte_count_in     = 'd0;
                        end
                      endcase
                    end else begin
                      crc_valid         = 'hfff0;
                      link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, app_data[95:88],
                                                                               app_data[31:24],
                                                                               app_data[87:80],
                                                                               app_data[23:16],
                                                                               app_data[79:72],
                                                                               app_data[15: 8],
                                                                               app_data[71:64],
                                                                               app_data[ 7: 0],
                                                                               app_data[63:56],
                                                                               calculated_ecc, 
                                                                               app_data[55:48],
                                                                               word_count[15: 8],  
                                                                               app_data[47:40],
                                                                               word_count[ 7: 0], 
                                                                               app_data[39:32],
                                                                               data_id};
                      if(advance_in) begin
                        app_data_saved_in = app_data[APP_DATA_WIDTH-1 -: APP_DATA_SAVED_SIZE];
                      end
                      nstate            = LONG_DATA;
                    end
                  end
                end
              end
            end

          endcase

        end else begin
          //End of NOP, no data
          link_idle                   = 1'b1;
          case(active_lanes)
            ONE_LANE : begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, NOP_DATAID};
                byte_count_in         = 'd1;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, NOP_WC0, NOP_DATAID};
                byte_count_in         = 'd2;
              end
            end

            TWO_LANE : begin
              if(NUM_LANES >= 2) begin
                if(DATA_WIDTH==8) begin
                  link_data_reg_in      = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, NOP_WC0, NOP_DATAID};
                  byte_count_in         = 'd1;
                end

                if(DATA_WIDTH==16) begin
                  link_data_reg_in      = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, calculated_ecc, NOP_WC0, NOP_WC1, NOP_DATAID};
                  byte_count_in         = 'd0;
                end
              end
            end    

            FOUR_LANE : begin
              if(NUM_LANES >= 4) begin
                if(DATA_WIDTH==8) begin
                  link_data_reg_in    = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, calculated_ecc, NOP_WC1, NOP_WC0, NOP_DATAID};
                  byte_count_in       = 'd0;
                end

                if(DATA_WIDTH==16) begin
                  link_data_reg_in    = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, {2{calculated_ecc}}, {2{NOP_WC1}}, {2{NOP_WC0}}, {2{NOP_DATAID}}};
                  byte_count_in       = 'd0;
                end
              end
            end        

            EIGHT_LANE : begin
              if(NUM_LANES >= 8) begin
                if(DATA_WIDTH==8) begin
                  link_data_reg_in      = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {2{calculated_ecc, NOP_WC1, NOP_WC0, NOP_DATAID}}};
                  byte_count_in         = 'd0;
                end

                if(DATA_WIDTH==16) begin
                  link_data_reg_in      = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {2{calculated_ecc}}, {2{NOP_WC1}}, {2{NOP_WC0}}, {2{NOP_DATAID}},
                                                                               {2{calculated_ecc}}, {2{NOP_WC1}}, {2{NOP_WC0}}, {2{NOP_DATAID}}};
                  byte_count_in         = 'd0;
                end
              end
            end
          endcase

        end
      end//ll_tx_valid
    end
    
    //-------------------------------------------
    //We can only come here in ONE_LANE 8bit mode
    HEADER_WC0 : begin
      crc_init                  = 1'b1;
      if(ll_tx_valid) begin
        if(DATA_WIDTH==8) begin
          link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, word_count[ 7: 0]};
          nstate                = HEADER_WC1;
        end
      end
    end
    
    //-------------------------------------------
    //We can only come here in ONE_LANE or TWO_LANE mode
    HEADER_WC1 : begin
      crc_init                  = 1'b1;
      if(ll_tx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              link_data_reg_in  = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, word_count[15: 8]};
              nstate            = HEADER_ECC;
              advance_in        = is_short_pkt_reg;
            end


            if(DATA_WIDTH==16) begin
              link_data_reg_in  = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, calculated_ecc, word_count[15: 8]};
              nstate            = is_short_pkt_reg ? IDLE : LONG_DATA;
              advance_in        = is_short_pkt_reg;
              byte_count_in     = 'd0;
            end
          end

          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, calculated_ecc, word_count[15: 8]};
                nstate            = is_short_pkt_reg ? IDLE : LONG_DATA;
                advance_in        = is_short_pkt_reg;
                byte_count_in     = 'd0;
              end
            end
          end
        endcase
      end
    end
    
    //-------------------------------------------
    //Only ONE_LANE and 8bit
    HEADER_ECC : begin
      crc_init                  = 1'b1;
      if(ll_tx_valid) begin
        if(DATA_WIDTH==8) begin
          link_data_reg_in      = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, calculated_ecc};
          nstate                = is_short_pkt_reg ? IDLE : (~(|word_count_reg) ? CRC0 : LONG_DATA);
          //advance_in            = word_count_reg == 'd0;
          advance_in            = 1'b0; //done in WC1
          byte_count_in         = 'd0;
        end
      end
    end
    
    
    //-------------------------------------------
    // The advance_in will essentially be based on the end of the number of bytes in the app data and num active lanes.
    // Once the count in the number of total bytes in the app data - active lanes, advance will assert.
    LONG_DATA : begin
      if(ll_tx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              crc_valid         = 'd1;
              link_data_reg_in  = APP_DATA_BYTES == 1 ? {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, app_data[ 7: 0]} :
                                                        {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 8]};
              crc_input         = link_data_reg_in;
              byte_count_in     = byte_count + 'd1;
              advance_in        = APP_DATA_BYTES == 1 ? 1'b1 : &byte_count[APP_DATA_BYTES_CLOG2-1:0]; //special case for single byte...it happens
              if(byte_count_in >= word_count_reg) begin
                nstate          = CRC0;
                advance_in      = 1'b1;
              end
            end


            if(DATA_WIDTH==16) begin
              crc_valid         = 'h3;
              link_data_reg_in  = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 16]};
              crc_input         = link_data_reg_in;
              byte_count_in     = byte_count + 'd2;
              advance_in        = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-1{1'b1}}, 1'b0} ;
              if(byte_count_in >= word_count_reg) begin   
                advance_in      = 1'b1;
                nstate          = CRC0;
                if(word_count_reg[0]) begin //odd bytecount
                  link_data_reg_in  = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, crc_next[ 7: 0], app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 8]};
                  nstate            = CRC1;
                end
              end
            end
          end

          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                crc_valid         = 'h3;
                link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 16]};
                crc_input         = link_data_reg_in;
                byte_count_in     = byte_count + 'd2;
                advance_in        = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-1{1'b1}}, 1'b0} ;//byte_count[1];
                //advance_in        = byte_count_in[1:0] ==  'd2;
                if(byte_count_in >= word_count_reg) begin   
                  advance_in      = 1'b1;
                  nstate          = CRC0;
                  if(word_count_reg[0]) begin //odd bytecount
                    link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, crc_next[ 7: 0], app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 8]};
                    nstate            = CRC1;
                  end
                end
              end

              if(DATA_WIDTH==16) begin
                crc_valid         = 'hf;

                link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8],
                                                                         app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8],
                                                                         app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8],
                                                                         app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8]};
                crc_input         = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8],   //note the different order
                                                                         app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8],
                                                                         app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8],
                                                                         app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8]};
                byte_count_in     = byte_count + 'd4;
                advance_in        = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-2{1'b1}}, 2'b00};
                if(byte_count_in >= word_count_reg) begin   
                  advance_in      = 1'b1;
                  nstate          = CRC0;
                  case(word_count_reg[1:0]) 
                    2'b00 : begin
                      //nothing to do since boundary
                      link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8]};
                      byte_count_in     = 'd0;
                      nstate            = CRC0;
                    end
                    2'b01 : begin //3 free bytes
                      crc_valid         = 'h1;
                      link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, IDL_SYM,
                                                                               crc_next[ 7: 0],
                                                                               crc_next[15: 8],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8]};
                      byte_count_in     = 'd0;
                      nstate            = nstate_idle_check;
                    end
                    2'b10 : begin //2 free bytes
                      crc_valid         = 'h3;
                      link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, crc_next[31:24],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8],
                                                                               crc_next[23:16],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8]};
                      byte_count_in     = 'd0;
                      nstate            = nstate_idle_check;
                    end
                    2'b11 : begin //1 free byte
                      crc_valid         = 'h7;
                      link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, crc_next[39:32],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8],
                                                                               app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8]};
                      nstate            = CRC1;
                    end
                  endcase
                end 
              end
            end
          end


          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                crc_valid         = 'hf;
                link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32]};
                crc_input         = link_data_reg_in;
                byte_count_in     = byte_count + 'd4;
                advance_in        = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-2{1'b1}}, 2'b00};
                if(byte_count_in >= word_count_reg) begin   
                  advance_in      = 1'b1;
                  nstate          = CRC0;
                  case(word_count_reg[1:0])
                    2'b00 : begin
                      //nothing to do since boundary
                      link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32]};
                      byte_count_in     = 'd0;
                      nstate            = CRC0;
                    end
                    2'b01 : begin //3 free bytes
                      crc_valid         = 'h1;
                      link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, IDL_SYM, crc_next[15:0], app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 8]};
                      byte_count_in     = 'd0;
                      nstate            = nstate_idle_check;
                    end
                    2'b10 : begin //2 free bytes
                      crc_valid         = 'h3;
                      link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, crc_next[31:16], app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 16]};
                      byte_count_in     = 'd0;
                      nstate            = nstate_idle_check;
                    end
                    2'b11 : begin //1 free byte
                      crc_valid         = 'h7;
                      link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, crc_next[39:32], app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 24]};
                      nstate            = CRC1;
                    end
                  endcase
                end 
              end

              if(DATA_WIDTH==16) begin
                crc_valid         = 'hff;
                link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}},(advance_prev ? app_data      [31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+7)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8]),
                                                                        (advance_prev ? app_data      [23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+6)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8]),
                                                                        (advance_prev ? app_data      [15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+5)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8]),
                                                                        (advance_prev ? app_data      [ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+4)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8])};

                crc_input         = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}},(advance_prev ? app_data      [31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+7)*8) +: 8]),
                                                                        (advance_prev ? app_data      [23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+6)*8) +: 8]),
                                                                        (advance_prev ? app_data      [15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+5)*8) +: 8]),
                                                                        (advance_prev ? app_data      [ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+4)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8])};

                byte_count_in     = byte_count + 'd8;
                advance_in          = (APP_DATA_BYTES - byte_count_in[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                if(advance_in) begin
                  app_data_saved_in = app_data[APP_DATA_WIDTH-1 -: APP_DATA_SAVED_SIZE];
                end
                if(byte_count_in >= word_count_reg) begin   
                  //advance_in      = 1'b1;
                  advance_in      = advance_prev && (word_count_reg - byte_count <= 'd4) ? 1'b0 : 1'b1;
                  case(byte_count_in - word_count_reg)    //this means number of bytes that are not data in this cycle or free bytes for CRC/IDL
                    'd0 : begin 
                      nstate                    = CRC0;
                    end

                    'd1 : begin
                      crc_input[63:56]          = 8'd0;
                      link_data_reg_in[63:56]   = crc_next[103:96];
                      nstate                    = CRC1;
                    end

                    'd2 : begin
                      crc_input[63:48]          = 16'd0;
                      link_data_reg_in[63:56]   = crc_next[95:88];
                      link_data_reg_in[47:40]   = crc_next[87:80];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd3 : begin
                      crc_input[63:40]          = 24'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[47:40]   = crc_next[79:72];
                      link_data_reg_in[31:24]   = crc_next[71:64];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd4 : begin
                      crc_input[63:32]          = 32'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[31:24]   = crc_next[63:56];
                      link_data_reg_in[15: 8]   = crc_next[55:48];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd5 : begin
                      crc_input[63:24]          = 40'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[31:24]   = IDL_SYM;
                      link_data_reg_in[15: 8]   = crc_next[47:40];

                      link_data_reg_in[55:48]   = crc_next[39:32];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd6 : begin
                      crc_input[63:16]          = 48'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[31:24]   = IDL_SYM;
                      link_data_reg_in[15: 8]   = IDL_SYM;

                      link_data_reg_in[55:48]   = crc_next[31:24];
                      link_data_reg_in[39:32]   = crc_next[23:16];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd7 : begin
                      crc_input[63: 8]          = 56'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[31:24]   = IDL_SYM;
                      link_data_reg_in[15: 8]   = IDL_SYM;

                      link_data_reg_in[55:48]   = IDL_SYM;
                      link_data_reg_in[39:32]   = crc_next[15: 8];
                      link_data_reg_in[23:16]   = crc_next[ 7: 0];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end
                  endcase
                end

              end
            end
          end

          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                crc_valid         = 'hff;
                link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}},(advance_prev ? app_data      [31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+7)*8) +: 8]),
                                                                        (advance_prev ? app_data      [23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+6)*8) +: 8]),
                                                                        (advance_prev ? app_data      [15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+5)*8) +: 8]),
                                                                        (advance_prev ? app_data      [ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+4)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8])};

                crc_input         = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}},(advance_prev ? app_data      [31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+7)*8) +: 8]),
                                                                        (advance_prev ? app_data      [23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+6)*8) +: 8]),
                                                                        (advance_prev ? app_data      [15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+5)*8) +: 8]),
                                                                        (advance_prev ? app_data      [ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+4)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8])};
                byte_count_in     = byte_count + 'd8;
                advance_in          = (APP_DATA_BYTES - byte_count_in[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                if(advance_in) begin
                  app_data_saved_in = app_data[APP_DATA_WIDTH-1 -: APP_DATA_SAVED_SIZE];
                end
                if(byte_count_in >= word_count_reg) begin   
                  //advance_in      = 1'b1;
                  advance_in      = advance_prev && (word_count_reg - byte_count <= 'd4) ? 1'b0 : 1'b1;
                  case(byte_count_in - word_count_reg)    //num free bytes
                    'd0 : begin 
                      nstate                    = CRC0;
                    end

                    'd1 : begin
                      crc_input[63:56]          = 8'd0;
                      link_data_reg_in[63:56]   = crc_next[103:96];
                      nstate                    = CRC1;
                    end

                    'd2 : begin
                      crc_input[63:48]          = 16'd0;
                      link_data_reg_in[63:56]   = crc_next[95:88];
                      link_data_reg_in[55:48]   = crc_next[87:80];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd3 : begin
                      crc_input[63:40]          = 24'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[55:48]   = crc_next[79:72];
                      link_data_reg_in[47:40]   = crc_next[71:64];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd4 : begin
                      crc_input[63:32]          = 32'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[55:48]   = IDL_SYM;
                      link_data_reg_in[47:40]   = crc_next[63:56];
                      link_data_reg_in[39:32]   = crc_next[55:48];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd5 : begin
                      crc_input[63:24]          = 40'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[55:48]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[39:32]   = crc_next[47:40];

                      link_data_reg_in[31:24]   = crc_next[39:32];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd6 : begin
                      crc_input[63:16]          = 48'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[55:48]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[39:32]   = IDL_SYM;

                      link_data_reg_in[31:24]   = crc_next[31:24];
                      link_data_reg_in[23:16]   = crc_next[23:16];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd7 : begin
                      crc_input[63: 8]          = 56'd0;
                      link_data_reg_in[63:56]   = IDL_SYM;
                      link_data_reg_in[55:48]   = IDL_SYM;
                      link_data_reg_in[47:40]   = IDL_SYM;
                      link_data_reg_in[39:32]   = IDL_SYM;

                      link_data_reg_in[31:24]   = IDL_SYM;
                      link_data_reg_in[23:16]   = crc_next[15: 8];
                      link_data_reg_in[15: 8]   = crc_next[ 7: 0];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end
                  endcase
                end              
              end

              if(DATA_WIDTH==16) begin
                crc_valid         = 'hffff;
                link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}},(advance_prev ? app_data      [95:88] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+15)*8) +: 8]),
                                                                        (advance_prev ? app_data      [31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 7)*8) +: 8]),
                                                                        (advance_prev ? app_data      [87:80] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+14)*8) +: 8]),
                                                                        (advance_prev ? app_data      [23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 6)*8) +: 8]),
                                                                        (advance_prev ? app_data      [79:72] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+13)*8) +: 8]),
                                                                        (advance_prev ? app_data      [15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 5)*8) +: 8]),
                                                                        (advance_prev ? app_data      [71:64] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+12)*8) +: 8]),
                                                                        (advance_prev ? app_data      [ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 4)*8) +: 8]),
                                                                        (advance_prev ? app_data      [63:56] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+11)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 3)*8) +: 8]),
                                                                        (advance_prev ? app_data      [55:48] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+10)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 2)*8) +: 8]),
                                                                        (advance_prev ? app_data      [47:40] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 9)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 1)*8) +: 8]),
                                                                        (advance_prev ? app_data      [39:32] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 8)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 0)*8) +: 8])};

                crc_input         = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}},(advance_prev ? app_data      [95:88] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+15)*8) +: 8]),
                                                                        (advance_prev ? app_data      [87:80] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+14)*8) +: 8]),
                                                                        (advance_prev ? app_data      [79:72] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+13)*8) +: 8]),
                                                                        (advance_prev ? app_data      [71:64] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+12)*8) +: 8]),
                                                                        (advance_prev ? app_data      [63:56] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+11)*8) +: 8]),
                                                                        (advance_prev ? app_data      [55:48] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+10)*8) +: 8]),
                                                                        (advance_prev ? app_data      [47:40] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 9)*8) +: 8]),
                                                                        (advance_prev ? app_data      [39:32] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 8)*8) +: 8]),

                                                                        (advance_prev ? app_data      [31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 7)*8) +: 8]),
                                                                        (advance_prev ? app_data      [23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 6)*8) +: 8]),
                                                                        (advance_prev ? app_data      [15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 5)*8) +: 8]),
                                                                        (advance_prev ? app_data      [ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 4)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[31:24] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 3)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[23:16] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 2)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[15: 8] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 1)*8) +: 8]),
                                                                        (advance_prev ? app_data_saved[ 7: 0] : app_data[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 0)*8) +: 8])};
                byte_count_in     = byte_count + 'd16;
                advance_in          = (APP_DATA_BYTES - byte_count_in[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                if(advance_in) begin
                  app_data_saved_in = app_data[APP_DATA_WIDTH-1 -: APP_DATA_SAVED_SIZE];
                end
                if(byte_count_in >= word_count_reg) begin
                  //advance_in      = 1'b1;
                  //Only asser the advance if we had more than 4 bytes to grab this cycle
                  //DOES THIS NEED TO TAKE INTO ACCOUNT THE advance_prev??????
                  advance_in      = advance_prev && (word_count_reg - byte_count <= 'd4) ? 1'b0 : 1'b1;  //this handles if we did an advnace on the prev cycle in IDLE
                  case(byte_count_in - word_count_reg)
                    'd0 : begin
                      nstate                    = CRC0;
                    end

                    'd1 : begin
                      crc_input[127:120]        = 8'd0;
                      link_data_reg_in[127:120] = crc_next[231:224];
                      nstate                    = CRC1;
                    end

                    'd2 : begin
                      crc_input[127:112]        = 16'd0;
                      link_data_reg_in[127:120] = crc_next[223:216];
                      link_data_reg_in[111:104] = crc_next[215:208];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd3 : begin
                      crc_input[127:104]        = 24'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = crc_next[207:200];
                      link_data_reg_in[ 95: 88] = crc_next[199:192];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd4 : begin
                      crc_input[127: 96]        = 32'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = crc_next[191:184];
                      link_data_reg_in[ 79: 72] = crc_next[183:176];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd5 : begin
                      crc_input[127: 88]        = 40'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = crc_next[175:168];
                      link_data_reg_in[ 63: 56] = crc_next[167:160];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd6 : begin
                      crc_input[127: 80]        = 48'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = crc_next[159:152];
                      link_data_reg_in[ 47: 40] = crc_next[151:144];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd7 : begin
                      crc_input[127: 72]        = 56'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = crc_next[143:136];
                      link_data_reg_in[ 31: 24] = crc_next[135:128];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd8 : begin
                      crc_input[127: 64]        = 64'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = crc_next[127:120];
                      link_data_reg_in[ 15:  8] = crc_next[119:112];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd9 : begin
                      crc_input[127: 56]        = 72'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = crc_next[111:104];

                      link_data_reg_in[119:112] = crc_next[103: 96];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd10 : begin
                      crc_input[127: 48]        = 80'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = IDL_SYM;

                      link_data_reg_in[119:112] = crc_next[ 95: 88];
                      link_data_reg_in[103: 96] = crc_next[ 87: 80];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd11 : begin
                      crc_input[127: 40]        = 88'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = IDL_SYM;

                      link_data_reg_in[119:112] = IDL_SYM;
                      link_data_reg_in[103: 96] = crc_next[ 79: 72];
                      link_data_reg_in[ 87: 80] = crc_next[ 71: 64];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd12 : begin
                      crc_input[127: 32]        = 96'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = IDL_SYM;

                      link_data_reg_in[119:112] = IDL_SYM;
                      link_data_reg_in[103: 96] = IDL_SYM;
                      link_data_reg_in[ 87: 80] = crc_next[ 63: 56];
                      link_data_reg_in[ 71: 64] = crc_next[ 55: 48];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd13 : begin
                      crc_input[127: 24]        = 104'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = IDL_SYM;

                      link_data_reg_in[119:112] = IDL_SYM;
                      link_data_reg_in[103: 96] = IDL_SYM;
                      link_data_reg_in[ 87: 80] = IDL_SYM;
                      link_data_reg_in[ 71: 64] = crc_next[ 47: 40];
                      link_data_reg_in[ 55: 48] = crc_next[ 39: 32];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd14 : begin
                      crc_input[127: 16]        = 112'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = IDL_SYM;

                      link_data_reg_in[119:112] = IDL_SYM;
                      link_data_reg_in[103: 96] = IDL_SYM;
                      link_data_reg_in[ 87: 80] = IDL_SYM;
                      link_data_reg_in[ 71: 64] = IDL_SYM;
                      link_data_reg_in[ 55: 48] = crc_next[ 31: 24];
                      link_data_reg_in[ 39: 32] = crc_next[ 23: 16];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end

                    'd15 : begin
                      crc_input[127:  8]        = 120'd0;
                      link_data_reg_in[127:120] = IDL_SYM;
                      link_data_reg_in[111:104] = IDL_SYM;
                      link_data_reg_in[ 95: 88] = IDL_SYM;
                      link_data_reg_in[ 79: 72] = IDL_SYM;
                      link_data_reg_in[ 63: 56] = IDL_SYM;
                      link_data_reg_in[ 47: 40] = IDL_SYM;
                      link_data_reg_in[ 31: 24] = IDL_SYM;
                      link_data_reg_in[ 15:  8] = IDL_SYM;

                      link_data_reg_in[119:112] = IDL_SYM;
                      link_data_reg_in[103: 96] = IDL_SYM;
                      link_data_reg_in[ 87: 80] = IDL_SYM;
                      link_data_reg_in[ 71: 64] = IDL_SYM;
                      link_data_reg_in[ 55: 48] = IDL_SYM;
                      link_data_reg_in[ 39: 32] = crc_next[ 15:  8];
                      link_data_reg_in[ 23: 16] = crc_next[  7:  0];
                      byte_count_in             = 'd0;
                      nstate                    = IDLE;
                    end
                  endcase
                end
              end
            end
          end

        endcase
      end
    end
    
    //-------------------------------------------
    CRC0 : begin
      byte_count_in     = 'd0;
      if(ll_tx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              link_data_reg_in  = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, crc_reg[7:0]};    
              nstate            = CRC1;
            end

            if(DATA_WIDTH==16) begin
              link_data_reg_in  = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, crc_reg[31:16]}; 
              nstate            = nstate_idle_check;
            end
          end

          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, crc_reg[31:16]}; 
                nstate            = nstate_idle_check;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in  = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, IDL_SYM, crc_reg[63:56], IDL_SYM, crc_reg[55:48]}; 
                nstate            = nstate_idle_check;
              end
            end
          end

          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, {2{IDL_SYM}}, crc_reg[63:48]}; 
                nstate            = nstate_idle_check;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in  = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, {4{IDL_SYM}}, IDL_SYM, crc_reg[127:120], IDL_SYM, crc_reg[119:112]}; 
                nstate            = nstate_idle_check;                
              end 
            end
          end

          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {6{IDL_SYM}}, crc_reg[127:112]}; 
                nstate            = nstate_idle_check;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in  = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {13{IDL_SYM}}, crc_reg[255:248], IDL_SYM, crc_reg[247:240]}; 
                nstate            = nstate_idle_check;
              end
            end
          end

        endcase
      end
    end
    
    //-------------------------------------------
    CRC1 : begin
      if(ll_tx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              link_data_reg_in    = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, crc_reg[15:8]};  
              nstate              = nstate_idle_check;
              byte_count_in       = 'd0;
            end

            if(DATA_WIDTH==16) begin
              link_data_reg_in    = {{(NUM_LANES-1)*(DATA_WIDTH){1'b0}}, crc_reg[15:8]};  
              nstate              = nstate_idle_check;
              byte_count_in       = 'd0;
            end
          end


          //Only come here if odd number of bytes
          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in    = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, crc_reg[15:8]};  
                nstate              = nstate_idle_check;
                byte_count_in       = 'd0;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in    = {{(NUM_LANES-2)*(DATA_WIDTH){1'b0}}, {3{IDL_SYM}}, crc_reg[47:40]};
                nstate              = nstate_idle_check;
                byte_count_in       = 'd0;
              end
            end
          end

          //Only come here if some amount of 1 remaining CRC byte
          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in    = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, {3{IDL_SYM}}, crc_reg[47:40]};
                nstate              = nstate_idle_check;
                byte_count_in       = 'd0;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in    = {{(NUM_LANES-4)*(DATA_WIDTH){1'b0}}, {7{IDL_SYM}}, crc_reg[111:104]};
                nstate              = nstate_idle_check;
                byte_count_in       = 'd0;
              end
            end
          end

          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                link_data_reg_in    = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {7{IDL_SYM}}, crc_reg[111:104]};
                nstate              = nstate_idle_check;
                byte_count_in       = 'd0;
              end

              if(DATA_WIDTH==16) begin
                link_data_reg_in    = {{(NUM_LANES-8)*(DATA_WIDTH){1'b0}}, {15{IDL_SYM}}, crc_reg[239:232]};
                nstate              = nstate_idle_check;
                byte_count_in       = 'd0;
              end
            end
          end
        endcase
      end
    end
    
    //-------------------------------------------
    // Due to data width differences we want to have the ability to "PAD" 
    // the start boundaries
    IDL_SYM_ST : begin
      if(ll_tx_valid) begin
        nstate                      = nstate_idle_check;
        link_data_reg_in            = {(NUM_LANES*(DATA_WIDTH/8)){IDL_SYM}};
      end
    end
    
    default : begin
      nstate              = WAIT_SDS;
    end
  endcase
  
  if(~enable) begin
    nstate                = WAIT_SDS;
  end
  
  //If data is X this can cause the CRC to prop X, resulting in CRCs
  //failing, so add this to force the X to something
  `ifndef SYNTHESIS
  for(int jj=0; jj<(NUM_LANES * DATA_WIDTH); jj++) begin
    if(crc_input[jj] === 1'bx) begin
      crc_input[jj] = 1'b0;
    end
    if(link_data_reg_in[jj] === 1'bx) begin
      link_data_reg_in[jj] = 1'b0;
    end
  end
  
  //ECC injection
  if($value$plusargs("SLINK_ECC_BIT_ERR1=%d", ecc_bit_error1)) begin
    if(~ecc_error_injected) begin
      case(ecc_bit_error1)
        0,1,2,3,4,5,6,7 : begin
          case(active_lanes)
            ONE_LANE : begin
              if(state==IDLE && nstate==HEADER_WC0) begin
                if(error_wait_count < error_wait_count_pa) begin
                  error_wait_count++;
                end else begin
                  for(int jj=0; jj<8; jj++) begin
                    if(jj==ecc_bit_error1) begin
                      link_data_reg_in[jj]  = ~link_data_reg_in[jj];
                      ecc_error_injected_in = 1;
                      error_wait_count      = 0;
                    end
                  end
                end
              end
            end
          endcase
        end
      endcase
    end 
  end
  
  //ECC injection
  if($value$plusargs("SLINK_CRC_BIT_ERR=%d", crc_bit_error)) begin
    if(~crc_error_injected) begin
      case(crc_bit_error)
        0,1,2,3,4,5,6,7 : begin
          case(active_lanes)
            ONE_LANE : begin
              if(state==CRC0 && nstate==CRC1) begin
                if(error_wait_count < error_wait_count_pa) begin
                  error_wait_count++;
                end else begin
                  for(int jj=0; jj<8; jj++) begin
                    if(jj==crc_bit_error) begin
                      link_data_reg_in[jj]  = ~link_data_reg_in[jj];
                      crc_error_injected_in = 0;  //temp
                      error_wait_count      = 0;
                    end
                  end
                end
              end
            end
          endcase
        end
      endcase
    end
  end
  `endif
end



assign advance          = advance_in;

assign link_data        = link_data_reg;

                    
                               
slink_ecc_syndrome u_slink_ecc_syndrome (
  .ph_in           ( packet_header_syn_in ),     
  .rx_ecc          ( 8'd0                 ),    
  .calc_ecc        ( calculated_ecc       ),  
  .corrected_ph    (                      ),          
  .corrected       (                      ),   
  .corrupt         (                      )); 
 


//assign crc_input = app_data[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: (NUM_LANES * DATA_WIDTH)];

genvar genloop;
generate
  for(genloop = 0; genloop < (NUM_LANES * (DATA_WIDTH/8)); genloop = genloop + 1) begin : crc_calc_gen
    // One for each 8bits of data. Need to go in and rip out the 16bit logic when time permits
    
    // prev is connected to the "previous" crc, with next connected to the "next" crc block
    // These are effectively daisy-chained in a loop with the LSByte (genloop == 0) being used
    // if there was only one byte of data
    //
    // 'crc' is the final output that should be inserted to the link. "next" is the crc value
    // on this cycle (in case you need to go ahead and send the CRC with the link data in the
    // event you say are running 4lanes at 8bits and the CRC needs to be on lane 1/2 if you 
    // had some odd number for the word count
    
    slink_crc_8_16bit_compute u_slink_crc_8_16bit_compute (
      .clk         ( clk                                          ),  
      .reset       ( reset                                        ),  
      .data_in     ( crc_input[((genloop+1)*8)-1 : genloop*8]     ),  
      .valid       ( crc_valid[genloop]                           ),  
      .init        ( crc_init                                     ),  
      .crc_prev    ( crc_prev[((genloop+1)*16)-1 : (genloop*16)]  ),    
      .crc_next    ( crc_next[((genloop+1)*16)-1 : (genloop*16)]  ),    
      .crc         ( crc_reg [((genloop+1)*16)-1 : (genloop*16)]  )); 
    
    
    // Depending on the number of active lanes, we will need to set the lowest CRC input to be 
    // the output reg of the last one
    if(genloop == 0) begin
      assign crc_prev[15:0] = (state == IDLE) ? 16'hffff : crc_reg[(((DATA_WIDTH/8) << active_lanes)-1) * 16 +: 16];
    end else begin
      assign crc_prev[((genloop+1)*16)-1 : (genloop*16)] = crc_next[(genloop*16)-1 : ((genloop-1)*16)];
    end
  end
endgenerate




`ifdef SIMULATION
reg [8*40:1] state_name;
always @(*) begin
  case(state)
    WAIT_SDS    : state_name = "WAIT_SDS";
    IDLE        : state_name = "IDLE";
    HEADER_DI   : state_name = "HEADER_DI";
    HEADER_WC0  : state_name = "HEADER_WC0";
    HEADER_WC1  : state_name = "HEADER_WC1";
    HEADER_ECC  : state_name = "HEADER_ECC";
    LONG_DATA   : state_name = "LONG_DATA";
    CRC0        : state_name = "CRC0";
    CRC1        : state_name = "CRC1";
    IDL_SYM_ST  : state_name = "IDL_SYM_ST";
  endcase
end

wire [APP_DATA_BYTES_CLOG2-1:0] byte_count_app_dbg;
assign byte_count_app_dbg = byte_count[APP_DATA_BYTES_CLOG2-1:0];

wire [15:0] byte_count_wc_remain = byte_count_in - word_count_reg;

`endif





endmodule


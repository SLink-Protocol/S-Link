module slink_ll_rx #(
  parameter     NUM_LANES             = 4,
  parameter     DATA_WIDTH            = 8,
  parameter     APP_DATA_WIDTH        = 32,         //Must be >= NUM_LANES * DATA_WIDTH
  parameter     APP_DATA_BYTES        = APP_DATA_WIDTH >> 3,
  parameter     APP_DATA_BYTES_CLOG2  = APP_DATA_BYTES == 1 ? 1 : $clog2(APP_DATA_BYTES),
  parameter     AUX_FIFO_ADDR_WIDTH   = 3
)(
  input  wire                               clk,
  input  wire                               reset,
  input  wire                               enable,
  
  //Interface to App
  output reg                                sop,
  output wire [7:0]                         data_id,
  output wire [15:0]                        word_count,
  output wire [(APP_DATA_BYTES*8)-1:0]      app_data,
  output reg                                valid,
  
  //Configuration based settings
  input  wire [2:0]                         active_lanes,
  input  wire [1:0]                         delimeter,
  
  input  wire                               swi_allow_ecc_corrected,
  input  wire                               swi_ecc_corrected_causes_reset,
  input  wire                               swi_ecc_corrupted_causes_reset,
  input  wire                               swi_crc_corrupted_causes_reset,
  
  //
  input  wire                               sds_received,
  
  output wire                               ecc_corrected,
  output wire                               ecc_corrupted,
  output reg                                crc_corrupted,
  input  wire                               external_link_reset_condition,
  output reg                                link_reset_condition,
  
  input  wire [(NUM_LANES*DATA_WIDTH)-1:0]  link_data,
  input  wire                               ll_rx_valid,
  output wire [3:0]                         ll_rx_state
);


`include "slink_includes.vh"

localparam    WAIT_SDS      = 'd0,
              IDLE          = 'd1,
              HEADER_DI     = 'd2,
              HEADER_WC0    = 'd3,
              HEADER_WC1    = 'd4,
              HEADER_ECC    = 'd5,
              LONG_DATA     = 'd6,
              CRC0          = 'd7,
              CRC1          = 'd8;

reg   [3:0]                           state, nstate;
reg   [(APP_DATA_BYTES*8)-1:0]        app_data_reg, app_data_reg_in;
reg   [15:0]                          byte_count, byte_count_in;
wire  [7:0]                           calculated_ecc;
reg   [7:0]                           data_id_reg, data_id_reg_in;
reg                                   is_short_pkt, is_short_pkt_in;
wire                                  short_pkt_check;
reg   [15:0]                          word_count_reg, word_count_reg_in;
reg   [7:0]                           rx_ecc;
reg   [23:0]                          ph_check;
wire  [23:0]                          corrected_ph;
wire                                  corrected;
wire                                  corrupt;
reg                                   sop_in;
reg                                   valid_in;
reg                                   sop_sent, sop_sent_in;

wire                                  sop_app;
wire                                  valid_app;

reg                                           crc_init;
reg   [(NUM_LANES * (DATA_WIDTH/8))-1:0]      crc_valid;
wire  [((NUM_LANES * (DATA_WIDTH/8))*16)-1:0] crc_next, crc_prev, crc_reg;
reg                                           crc_corr_prev, crc_corr_prev_in;
reg                                           crc_corrupted_in;
reg   [(NUM_LANES * DATA_WIDTH)-1:0]          crc_input;

wire                                  block_app_for_ecc_error;
wire                                  ecc_corrected_cond;
wire                                  link_reset_condition_in;

reg   [1:0]                           delim_count;
wire  [1:0]                           delim_count_in;
wire                                  delim_adv;

localparam  APP_DATA_SAVED_SIZE = ((NUM_LANES*DATA_WIDTH) - 32) <= 0 ? 1 : (NUM_LANES*DATA_WIDTH) - 32;
reg   [APP_DATA_SAVED_SIZE-1:0] app_data_saved, app_data_saved_in;
reg                             send_saved, send_saved_in;
reg                             send_saved_sop, send_saved_sop_in;
reg   [7:0]                     send_saved_di, send_saved_di_in;
reg   [15:0]                    send_saved_wc, send_saved_wc_in;
reg                             valid_prev;
wire                            valid_cond;
wire                            short_pkt_corrected_cond;

always @(posedge clk or posedge reset) begin
  if(reset) begin
    state               <= WAIT_SDS;
    app_data_reg        <= {(APP_DATA_BYTES*8){1'b0}};
    is_short_pkt        <= 1'b0;
    data_id_reg         <= 8'd0;
    word_count_reg      <= 16'd0;
    sop                 <= 1'b0;
    valid               <= 1'b0;
    byte_count          <= 16'd0;
    sop_sent            <= 1'b0;
    crc_corr_prev       <= 1'b0;
    crc_corrupted       <= 1'b0;
    link_reset_condition<= 1'b0;
    delim_count         <= 'd0;
    app_data_saved      <= {APP_DATA_SAVED_SIZE{1'b0}};
    send_saved          <= 1'b0;
    send_saved_sop      <= 1'b0;
    send_saved_di       <= 8'd0;
    send_saved_wc       <= 16'd0;
    valid_prev          <= 1'b0;
  end else begin
    state               <= nstate;
    app_data_reg        <= app_data_reg_in;
    is_short_pkt        <= is_short_pkt_in;
    data_id_reg         <= data_id_reg_in;
    word_count_reg      <= word_count_reg_in;
    sop                 <= sop_app;
    valid               <= valid_app;
    byte_count          <= byte_count_in;
    sop_sent            <= sop_sent_in;
    crc_corr_prev       <= crc_corr_prev_in;
    crc_corrupted       <= crc_corrupted_in;
    link_reset_condition<= link_reset_condition_in;
    delim_count         <= delim_count_in;
    app_data_saved      <= app_data_saved_in;
    send_saved          <= send_saved_in;
    send_saved_sop      <= send_saved_sop_in;
    send_saved_di       <= send_saved_di_in;
    send_saved_wc       <= send_saved_wc_in;
    valid_prev          <= ~ll_rx_valid ? valid_prev : valid_app;
  end
end


assign delim_count_in             = enable ? ll_rx_valid ? ((state == WAIT_SDS) || (delim_count == delimeter) ? 'd0 : delim_count + 'd1) : delim_count : 'd0;
assign delim_adv                  = delim_count == 'd0;//delim_count_in == delimeter;

assign ll_rx_state                = state;

assign short_pkt_check            = link_data[7:0]    <= 'h1f;
assign short_pkt_check_corrected  = corrected_ph[7:0] <= 'h1f;

assign block_app_for_ecc_error    = ecc_corrupted || (ecc_corrected && ~swi_allow_ecc_corrected);
assign ecc_corrected_cond         = ecc_corrected && swi_allow_ecc_corrected;
assign link_reset_condition_in    = (swi_ecc_corrected_causes_reset && ecc_corrected) ||
                                    (swi_ecc_corrupted_causes_reset && ecc_corrupted) ||
                                    (swi_crc_corrupted_causes_reset && crc_corrupted);


assign valid_cond                 = (state == LONG_DATA) && ((APP_DATA_BYTES - byte_count[APP_DATA_BYTES_CLOG2-1:0]) == 'd4);

assign short_pkt_corrected_cond   = short_pkt_check_corrected && ~block_app_for_ecc_error;

always @(*) begin
  nstate                = state;
  is_short_pkt_in       = is_short_pkt;
  app_data_reg_in       = app_data_reg;
  data_id_reg_in        = data_id_reg;
  word_count_reg_in     = word_count_reg;
  ph_check              = 24'd0;
  rx_ecc                = 8'd0;
  sop_in                = 1'b0;
  valid_in              = 1'b0;
  byte_count_in         = byte_count;
  sop_sent_in           = sop_sent;
  crc_init              = 1'b1;
  crc_valid             = {(NUM_LANES * (DATA_WIDTH/8)){1'b0}};
  crc_corrupted_in      = 1'b0;
  crc_corr_prev_in      = crc_corr_prev;
  app_data_saved_in     = app_data_saved;
  send_saved_in         = 1'b0;
  send_saved_sop_in     = 1'b0;
  send_saved_di_in      = send_saved_di;
  send_saved_wc_in      = send_saved_wc;
  crc_input             = {(NUM_LANES * DATA_WIDTH){1'b0}};
  
  case(state)
    //-------------------------------------------
    WAIT_SDS : begin
      if(sds_received) begin
        nstate          = IDLE;
      end
    end
    
    //-------------------------------------------
    // A note on ``send_saved``:
    // If a packet ends on a boundary such that you need an additional app data
    // cycle, the logic will assert ``send_saved`` and save the remaining data in the app_data_saved registers.
    // The next state would be IDLE, but we still need to send this app data, so that is the send_saved check you see below. The
    // difficult part is we still need to be able to catch the start of the next packet, so we will save the current
    // application data (current meaning the start of the new packet) in the app_data_saved register.
    //
    // ``send_saved`` is essentially a "delayed" version of the data. It will stay in this state until you have
    // a cycle in which it can flush this app data out. Even if the data ran in this way forever, you wouldn't
    // have to worry about some type of "overflow".
    //
    // This situation could be bypassed if we forced the TX to send some IDL/NOP packets after boundaries like this,
    // however this would cause a bandwidth reduction and increase the latency.
    IDLE : begin
      crc_corr_prev_in                = 1'b0;
      sop_sent_in                     = 1'b0;
      byte_count_in                   = 'd0;
      app_data_reg_in                 = {APP_DATA_BYTES{8'h00}};
      
      
      if(send_saved) begin
        valid_in                      = 1'b1;
        sop_in                        = send_saved_sop;
        crc_corrupted_in              = crc_corr_prev;
        case(active_lanes)
          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==16) begin
                app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                app_data_reg_in[23:16]  = app_data_saved[23:16];
                app_data_reg_in[31:24]  = app_data_saved[31:24];
              end
            end
          end
        
          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin 
                app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                app_data_reg_in[23:16]  = app_data_saved[23:16];
                app_data_reg_in[31:24]  = app_data_saved[31:24];
              end
            
              if(DATA_WIDTH==16) begin
                app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                app_data_reg_in[23:16]  = app_data_saved[23:16];
                app_data_reg_in[31:24]  = app_data_saved[31:24];

                app_data_reg_in[39:32]  = app_data_saved[39:32];
                app_data_reg_in[47:40]  = app_data_saved[47:40];
                app_data_reg_in[55:48]  = app_data_saved[55:48];
                app_data_reg_in[63:56]  = app_data_saved[63:56];

                app_data_reg_in[71:64]  = app_data_saved[71:64];
                app_data_reg_in[79:72]  = app_data_saved[79:72];
                app_data_reg_in[87:80]  = app_data_saved[87:80];
                app_data_reg_in[95:88]  = app_data_saved[95:88];
              end
            end
          end
        endcase
      end
      
      
      
      if(delim_adv && ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              data_id_reg_in          = link_data[7:0];
              is_short_pkt_in         = short_pkt_check;
              nstate                  = HEADER_WC0;
            end

            if(DATA_WIDTH==16) begin
              data_id_reg_in          = link_data[7:0];
              word_count_reg_in       = {8'd0, link_data[15:8]};
              is_short_pkt_in         = short_pkt_check;
              nstate                  = HEADER_WC1;
            end
          end

          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                data_id_reg_in          = link_data[7:0];
                word_count_reg_in       = {8'd0, link_data[15:8]};
                is_short_pkt_in         = short_pkt_check;
                nstate                  = HEADER_WC1;
              end


              if(DATA_WIDTH==16) begin
                ph_check                = {link_data[15:8], link_data[23:16], link_data[7:0]};
                data_id_reg_in          = corrected_ph[ 7:0];
                word_count_reg_in       = corrected_ph[23:8];
                rx_ecc                  = link_data[31:24];
                is_short_pkt_in         = short_pkt_corrected_cond;
                sop_in                  = short_pkt_corrected_cond;
                valid_in                = short_pkt_corrected_cond;
                nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
              end
            end
          end

          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                ph_check                = link_data[23:0];
                data_id_reg_in          = corrected_ph[ 7:0];
                word_count_reg_in       = corrected_ph[23:8];
                rx_ecc                  = link_data[31:24];
                is_short_pkt_in         = short_pkt_corrected_cond;
                sop_in                  = short_pkt_corrected_cond;
                valid_in                = short_pkt_corrected_cond;
                nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
              end

              if(DATA_WIDTH==16) begin
                ph_check                = {link_data[39:32], link_data[23:16], link_data[7:0]};
                rx_ecc                  = link_data[55:48];
                data_id_reg_in          = corrected_ph[ 7:0];
                word_count_reg_in       = corrected_ph[23:8];
                is_short_pkt_in         = short_pkt_corrected_cond;
                
                send_saved_di_in        = corrected_ph[ 7:0];
                send_saved_wc_in        = corrected_ph[23:8];
                if(send_saved) begin
                  send_saved_sop_in     = short_pkt_corrected_cond;
                  send_saved_in         = short_pkt_corrected_cond;
                end else begin
                  sop_in                = short_pkt_corrected_cond;
                  valid_in              = short_pkt_corrected_cond;
                end
                nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;

                crc_input[63:32]        = {link_data[63:56],
                                           link_data[47:40],
                                           link_data[31:24],
                                           link_data[15: 8]};
                                           
                byte_count_in           = 'd4;
                if(~short_pkt_check_corrected) begin
                  crc_init              = 1'b0;
                  
                  if(send_saved) begin
                    app_data_saved_in[ 7: 0] = link_data[15: 8];
                    app_data_saved_in[15: 8] = link_data[31:24];
                    app_data_saved_in[23:16] = link_data[47:40];
                    app_data_saved_in[31:24] = link_data[63:56];
                  end else begin
                    app_data_reg_in[ 7: 0] = link_data[15: 8];
                    app_data_reg_in[15: 8] = link_data[31:24];
                    app_data_reg_in[23:16] = link_data[47:40];
                    app_data_reg_in[31:24] = link_data[63:56];
                  end
                  
                  case(word_count_reg_in)
                    'd1 : begin //1 byte and CRC should be here
                      crc_valid           = 'h10;
                      if(send_saved) begin
                        send_saved_in     = 1'b1;
                        send_saved_sop_in = 1'b1;
                        crc_corr_prev_in  = crc_next[79:64] != {link_data[47:40], link_data[31:24]};
                      end else begin
                        valid_in          = 1'b1;
                        sop_in            = 1'b1;
                        crc_corrupted_in  = crc_next[79:64] != {link_data[47:40], link_data[31:24]};
                      end
                      nstate              = IDLE;
                    end

                    'd2 : begin //2 bytes and CRC should be here
                      crc_valid           = 'h30;
                      if(send_saved) begin
                        send_saved_in     = 1'b1;
                        send_saved_sop_in = 1'b1;
                        crc_corr_prev_in  = crc_next[95:80] != {link_data[63:56], link_data[47:40]};
                      end else begin
                        valid_in          = 1'b1;
                        sop_in            = 1'b1;
                        crc_corrupted_in  = crc_next[95:80] != {link_data[63:56], link_data[47:40]};
                      end
                      nstate              = IDLE;
                    end

                    'd3 : begin //3 bytes and CRC low byte, next cycle has high CRC
                      crc_valid           = 'h70;
                      crc_corr_prev_in    = crc_next[103:96] != link_data[63:56];
                      nstate              = CRC1;
                    end

                    'd4 : begin //4 bytes and CRC is start of next
                      crc_valid           = 'hf0;
                      nstate              = CRC0;
                    end

                    default : begin
                      //moving on
                      crc_valid         = 'hf0;
                    end
                  endcase
                end
              end
            end
          end
          
          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                ph_check                = link_data[23:0];
                data_id_reg_in          = corrected_ph[ 7:0];
                word_count_reg_in       = corrected_ph[23:8];
                rx_ecc                  = link_data[31:24];
                is_short_pkt_in         = short_pkt_corrected_cond;
                
                send_saved_di_in        = corrected_ph[ 7:0];
                send_saved_wc_in        = corrected_ph[23:8];
                if(send_saved) begin
                  send_saved_sop_in     = short_pkt_corrected_cond;
                  send_saved_in         = short_pkt_corrected_cond;
                end else begin
                  sop_in                = short_pkt_corrected_cond;
                  valid_in              = short_pkt_corrected_cond;
                end
                nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
                
                crc_input[63:32]        = {link_data[63:32]};
                byte_count_in           = 'd4;
                if(~short_pkt_check_corrected) begin
                  crc_init              = 1'b0;
                  crc_valid             = 'hf0;
                  
                  if(send_saved) begin
                    app_data_saved_in [31: 0] = link_data[63:32];
                  end else begin
                    app_data_reg_in   [31: 0] = link_data[63:32];
                  end
                  
                  case(word_count_reg_in)
                    'd1 : begin
                      crc_valid           = 'h10;
                      if(send_saved) begin
                        send_saved_in     = 1'b1;
                        send_saved_sop_in = 1'b1;
                        crc_corr_prev_in  = crc_next[79:64] != link_data[55:40];
                      end else begin
                        valid_in          = 1'b1;
                        sop_in            = 1'b1;
                        crc_corrupted_in  = crc_next[79:64] != link_data[55:40];
                      end
                      nstate              = IDLE;
                    end
                    
                    'd2 : begin
                      crc_valid           = 'h30;
                      if(send_saved) begin
                        send_saved_in     = 1'b1;
                        send_saved_sop_in = 1'b1;
                        crc_corr_prev_in  = crc_next[95:80] != link_data[63:48];
                      end else begin
                        valid_in          = 1'b1;
                        sop_in            = 1'b1;
                        crc_corrupted_in  = crc_next[95:80] != link_data[63:48];
                      end
                      nstate              = IDLE;
                    end
                    
                    'd3 : begin
                      crc_valid           = 'h70;
                      crc_corr_prev_in    = crc_next[103:96] != link_data[63:56];
                      nstate              = CRC1;
                    end
                    
                    'd4 : begin
                      crc_valid           = 'hf0;
                      nstate              = CRC0;
                    end
                    
                    default : begin
                      crc_valid           = 'hf0;
                    end
                  endcase
                end
              end
              
              if(DATA_WIDTH==16) begin
                ph_check                = {link_data[39:32], link_data[23:16], link_data[7:0]};
                rx_ecc                  = link_data[55:48];
                data_id_reg_in          = corrected_ph[ 7:0];
                word_count_reg_in       = corrected_ph[23:8];
                is_short_pkt_in         = short_pkt_corrected_cond;
                
                send_saved_di_in        = corrected_ph[ 7:0];
                send_saved_wc_in        = corrected_ph[23:8];
                if(send_saved) begin
                  send_saved_sop_in     = short_pkt_corrected_cond;
                  send_saved_in         = short_pkt_corrected_cond;
                end else begin
                  sop_in                = short_pkt_corrected_cond;
                  valid_in              = short_pkt_corrected_cond;
                end
                nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
                
                
                crc_input[127: 32]      = {link_data[127:120],
                                           link_data[111:104],
                                           link_data[ 95: 88],
                                           link_data[ 79: 72],
                                           link_data[ 63: 56],
                                           link_data[ 47: 40],
                                           link_data[ 31: 24],
                                           link_data[ 15:  8],
                                           link_data[119:112],
                                           link_data[103: 96],
                                           link_data[ 87: 80],
                                           link_data[ 71: 64]};
                byte_count_in           = 'd12;
                if(~short_pkt_check_corrected) begin
                  crc_init              = 1'b0;
                  
                  if(send_saved) begin
                    app_data_saved_in[  7:  0]  = link_data[ 71: 64];
                    app_data_saved_in[ 15:  8]  = link_data[ 87: 80];
                    app_data_saved_in[ 23: 16]  = link_data[103: 96];
                    app_data_saved_in[ 31: 24]  = link_data[119:112];
                    app_data_saved_in[ 39: 32]  = link_data[ 15:  8];
                    app_data_saved_in[ 47: 40]  = link_data[ 31: 24];
                    app_data_saved_in[ 55: 48]  = link_data[ 47: 40];
                    app_data_saved_in[ 63: 56]  = link_data[ 63: 56];
                    app_data_saved_in[ 71: 64]  = link_data[ 79: 72];
                    app_data_saved_in[ 79: 72]  = link_data[ 95: 88];
                    app_data_saved_in[ 87: 80]  = link_data[111:104];
                    app_data_saved_in[ 95: 88]  = link_data[127:120];
                  end else begin
                    app_data_reg_in[  7:  0]    =                              link_data[ 71: 64];
                    app_data_reg_in[ 15:  8]    = (word_count_reg_in >  'd1) ? link_data[ 87: 80] : 8'd0;
                    app_data_reg_in[ 23: 16]    = (word_count_reg_in >  'd2) ? link_data[103: 96] : 8'd0;
                    app_data_reg_in[ 31: 24]    = (word_count_reg_in >  'd3) ? link_data[119:112] : 8'd0;
                    app_data_reg_in[ 39: 32]    = (word_count_reg_in >  'd4) ? link_data[ 15:  8] : 8'd0;
                    app_data_reg_in[ 47: 40]    = (word_count_reg_in >  'd5) ? link_data[ 31: 24] : 8'd0;
                    app_data_reg_in[ 55: 48]    = (word_count_reg_in >  'd6) ? link_data[ 47: 40] : 8'd0;
                    app_data_reg_in[ 63: 56]    = (word_count_reg_in >  'd7) ? link_data[ 63: 56] : 8'd0;
                    app_data_reg_in[ 71: 64]    = (word_count_reg_in >  'd8) ? link_data[ 79: 72] : 8'd0;
                    app_data_reg_in[ 79: 72]    = (word_count_reg_in >  'd9) ? link_data[ 95: 88] : 8'd0;
                    app_data_reg_in[ 87: 80]    = (word_count_reg_in >  'd0) ? link_data[111:104] : 8'd0;
                    app_data_reg_in[ 95: 88]    = (word_count_reg_in >  'd11)? link_data[127:120] : 8'd0;
                  end
                  
                  case(word_count_reg_in) 
                    'd1 : begin
                      crc_valid                 = 'h10;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[ 79: 64] != {link_data[103:96], link_data[ 87: 80]};
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[ 79: 64] != {link_data[103:96], link_data[ 87: 80]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd2 : begin
                      crc_valid                 = 'h30;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[ 95: 80] != {link_data[119:112], link_data[103: 96]};
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[ 95: 80] != {link_data[119:112], link_data[103: 96]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd3 : begin
                      crc_valid                 = 'h70;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[111: 96] != {link_data[ 15:  8], link_data[119:112]};
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[111: 96] != {link_data[ 15:  8], link_data[119:112]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd4 : begin
                      crc_valid                 = 'hf0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[127:112] != {link_data[ 31: 24], link_data[ 15:  8]};    
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[127:112] != {link_data[ 31: 24], link_data[ 15:  8]};                    
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd5 : begin
                      crc_valid                 = 'h1f0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[143:128] != {link_data[ 47: 40], link_data[ 31: 24]};                      
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[143:128] != {link_data[ 47: 40], link_data[ 31: 24]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd6 : begin
                      crc_valid                 = 'h3f0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[159:144] != {link_data[ 63: 56], link_data[ 47: 40]}; 
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[159:144] != {link_data[ 63: 56], link_data[ 47: 40]};                      
                      end                      
                      nstate                    = IDLE;                      
                    end
                    
                    'd7 : begin
                      crc_valid                 = 'h7f0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[175:160] != {link_data[ 79: 72], link_data[ 63: 56]}; 
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[175:160] != {link_data[ 79: 72], link_data[ 63: 56]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd8 : begin
                      crc_valid                 = 'hff0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[191:176] != {link_data[ 95: 88], link_data[ 79: 72]};
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[191:176] != {link_data[ 95: 88], link_data[ 79: 72]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd9 : begin
                      crc_valid                 = 'h1ff0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[207:192] != {link_data[111:104], link_data[ 95: 88]};
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[207:192] != {link_data[111:104], link_data[ 95: 88]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd10 : begin
                      crc_valid                 = 'h3ff0;
                      if(send_saved) begin
                        send_saved_in           = 1'b1;
                        send_saved_sop_in       = 1'b1;
                        crc_corr_prev_in        = crc_next[223:208] != {link_data[127:120], link_data[111:104]};
                      end else begin
                        valid_in                = 1'b1;
                        sop_in                  = 1'b1;
                        crc_corrupted_in        = crc_next[223:208] != {link_data[127:120], link_data[111:104]};
                      end
                      nstate                    = IDLE;                      
                    end
                    
                    'd11 : begin
                      crc_valid                 = 'h7ff0;
                      crc_corr_prev_in          = crc_next[231:224] != link_data[127:120];
                      nstate                    = CRC1;                      
                    end
                    
                    'd12 : begin
                      crc_valid                 = 'hfff0;
                      nstate                    = CRC0;                      
                    end
                    
                    default : begin
                      crc_valid                 = 'hfff0;
                      nstate                    = LONG_DATA;   
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
    //We can only come here in ONE_LANE mode and 8bit
    HEADER_WC0 : begin
      if(ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              word_count_reg_in       = {8'd0, link_data[7:0]};
              nstate                  = HEADER_WC1;
            end
          end
        endcase
      end
    end
    
    //-------------------------------------------
    //We can only come here in ONE_LANE or TWO_LANE 8bit mode
    HEADER_WC1 : begin
      if(ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              word_count_reg_in       = {link_data[7:0], word_count_reg[7:0]};
              nstate                  = HEADER_ECC;
            end

            if(DATA_WIDTH==16) begin
              ph_check                = {link_data[7:0], word_count_reg[7:0], data_id_reg};
              rx_ecc                  = link_data[15:8];
              data_id_reg_in          = corrected_ph[7:0];
              word_count_reg_in       = corrected_ph[23:8];
              nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
              sop_in                  = short_pkt_corrected_cond;
              valid_in                = short_pkt_corrected_cond;
              byte_count_in           = 'd0;
            end
          end

          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                ph_check                = {link_data[7:0], word_count_reg[7:0], data_id_reg};
                rx_ecc                  = link_data[15:8];
                data_id_reg_in          = corrected_ph[7:0];
                word_count_reg_in       = corrected_ph[23:8];
                nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
                sop_in                  = short_pkt_corrected_cond;
                valid_in                = short_pkt_corrected_cond;
                byte_count_in           = 'd0;
              end
            end
          end
        endcase
      end
    end
    
    
    //-------------------------------------------
    //Only in ONE_LANE mode and 8bit
    HEADER_ECC : begin
      if(ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              ph_check                = {word_count_reg, data_id_reg};
              rx_ecc                  = link_data[7:0];
              data_id_reg_in          = corrected_ph[7:0];
              word_count_reg_in       = corrected_ph[23:8];
              nstate                  = short_pkt_check_corrected ? IDLE : LONG_DATA;
              sop_in                  = short_pkt_corrected_cond;
              valid_in                = short_pkt_corrected_cond;
              byte_count_in           = 'd0;
            end
          end
        endcase
      end
    end
    
    
    //-------------------------------------------
    LONG_DATA : begin
      crc_init                        = 1'b0;
      if(ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              crc_valid               = 'h1;
              if(APP_DATA_BYTES == 1) begin
                app_data_reg_in[7:0] = link_data[7:0];
              end else begin
                app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 8] = link_data[7:0];
              end
              crc_input[ 7: 0]        = link_data[7:0];
              valid_in                = APP_DATA_BYTES == 1 ? 1'b1 : &byte_count[APP_DATA_BYTES_CLOG2-1:0];
              byte_count_in           = byte_count + 'd1;
              //if(byte_count == ending_byte_count) begin
              if(byte_count_in >= word_count_reg) begin
                nstate                = CRC0;
                valid_in              = 1'b0;
              end
            end



            if(DATA_WIDTH==16) begin
              crc_valid               = 'h3;
              app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 16] = link_data[15:0];
              crc_input[15: 0]        = link_data[15:0];
              valid_in                = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-1{1'b1}}, 1'b0};
              byte_count_in           = byte_count + 'd2;
              if(byte_count_in >= word_count_reg) begin
                valid_in              = 1'b0;
                if(word_count_reg[0]) begin
                  //check lower byte CRC
                  nstate              = CRC1;
                  //crc_valid           = 'd1;
                  crc_corrupted_in    = link_data[15:8] != crc_next[7:0];
                end else begin
                  nstate              = CRC0;
                end
                byte_count_in         = 'd0;
              end
            end
          end


          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                crc_valid               = 'h3;
                app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 16] = link_data[15:0];
                crc_input[15: 0]        = link_data[15:0];
                valid_in                = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-1{1'b1}}, 1'b0};//byte_count[1];
                byte_count_in           = byte_count + 'd2;
                if(byte_count_in >= word_count_reg) begin

                  valid_in              = 1'b0;
                  if(word_count_reg[0]) begin
                    //check lower byte CRC
                    nstate              = CRC1;
                    crc_valid           = 'd1;
                    crc_corrupted_in    = link_data[15:8] != crc_next[7:0];
                  end else begin
                    nstate              = CRC0;
                  end
                  byte_count_in         = 'd0;
                end
              end


              if(DATA_WIDTH==16) begin
                crc_valid               = 'hf;
                app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32] = {link_data[31:24],
                                                                                   link_data[15: 8],
                                                                                   link_data[23:16],
                                                                                   link_data[ 7: 0]};
                crc_input[31: 0]        = {link_data[31:24],
                                           link_data[15: 8],
                                           link_data[23:16],
                                           link_data[ 7: 0]};

                valid_in                = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-2{1'b1}}, 2'b00};
                byte_count_in           = byte_count + 'd4;
                if(byte_count_in >= word_count_reg) begin
                  //valid_in              = 1'b1;
                  case(word_count_reg[1:0]) 
                    2'b00 : begin   //even boundary
                      nstate            = CRC0;
                      valid_in          = 1'b0;
                    end
                    2'b01 : begin   //crc should be in bytes 2/1, byte 3 all zero
                      crc_corrupted_in  = crc_next[15:0] != {link_data[15:8], link_data[23:16]};
                      valid_in          = 1'b1;
                      nstate            = IDLE;
                      app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8] = 8'd0;
                      app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8] = 8'd0;
                      app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8] = 8'd0;
                    end
                    2'b10 : begin   //crc should be in bytes 3/2
                      crc_corrupted_in  = crc_next[31:16] != {link_data[31:24], link_data[15:8]};
                      valid_in          = 1'b1;
                      nstate            = IDLE;
                      app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8] = 8'd0;
                      app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8] = 8'd0;
                    end
                    2'b11 : begin   //lower CRC in byte3
                      crc_corr_prev_in  = crc_next[39:32] != link_data[31:24];
                      valid_in          = 1'b0;
                      nstate            = CRC1;
                      app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8] = 8'd0;
                    end
                  endcase 
                  byte_count_in         = 'd0;
                end
              end
            end
          end


          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                crc_valid               = 'hf;
                app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32] = link_data[31:0];
                crc_input[31: 0]        = link_data[31:0];
                valid_in                = byte_count[APP_DATA_BYTES_CLOG2-1:0] == {{APP_DATA_BYTES_CLOG2-2{1'b1}}, 2'b00};
                byte_count_in           = byte_count + 'd4;
                if(byte_count_in >= word_count_reg) begin
                  //valid_in              = 1'b1;
                  case(word_count_reg[1:0]) 
                    2'b00 : begin   //even boundary
                      nstate            = CRC0;
                      valid_in          = 1'b0;
                    end
                    2'b01 : begin   //crc should be in bytes 2/1, byte 3 all zero
                      crc_corrupted_in  = crc_next[15:0] != link_data[23:8];
                      valid_in          = 1'b1;
                      nstate            = IDLE;
                      app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32] = {24'd0, link_data[7:0]};
                    end
                    2'b10 : begin   //crc should be in bytes 3/2
                      crc_corrupted_in  = crc_next[31:16] != link_data[31:16];
                      valid_in          = 1'b1;
                      nstate            = IDLE;
                      app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32] = {16'd0, link_data[15:0]};
                    end
                    2'b11 : begin   //lower CRC in byte3
                      crc_corr_prev_in  = crc_next[39:32] != link_data[31:24];
                      valid_in          = 1'b0;
                      nstate            = CRC1;
                      app_data_reg_in[(byte_count[APP_DATA_BYTES_CLOG2-1:0]*8) +: 32] = {8'd0, link_data[23:0]};
                    end
                  endcase 
                  byte_count_in         = 'd0;
                end
              end


              if(DATA_WIDTH==16) begin
                crc_valid               = 'hff;
                byte_count_in           = byte_count + 'd8;
                crc_input[63: 0]        = {link_data[63:56],
                                           link_data[47:40],
                                           link_data[31:24],
                                           link_data[15: 8],
                                           link_data[55:48],
                                           link_data[39:32],
                                           link_data[23:16],
                                           link_data[ 7: 0]};
                valid_in                = (APP_DATA_BYTES - byte_count[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                if(valid_prev) begin
                  app_data_reg_in        = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0] = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8] = app_data_saved[15: 8];
                  app_data_reg_in[23:16] = app_data_saved[23:16];
                  app_data_reg_in[31:24] = app_data_saved[31:24];
                end 

                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 8] = link_data[ 7: 0];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+1)*8) +: 8] = link_data[23:16];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+2)*8) +: 8] = link_data[39:32];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+3)*8) +: 8] = link_data[55:48];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+4)*8) +: 8] = link_data[15: 8];  
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+5)*8) +: 8] = link_data[31:24];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+6)*8) +: 8] = link_data[47:40];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+7)*8) +: 8] = link_data[63:56];

                if(valid_in) begin
                  app_data_saved_in[ 7: 0] = link_data[15: 8];
                  app_data_saved_in[15: 8] = link_data[31:24];
                  app_data_saved_in[23:16] = link_data[47:40];
                  app_data_saved_in[31:24] = link_data[63:56];
                end


                if(byte_count_in >= word_count_reg) begin
                  //If we have more than 4bytes of data in this cycle, we need to send an updated
                  //app data now, then the next cycle we do the CRC update with the final 1-4 bytes
                  //from the saved data.
                  valid_in                  = 1'b1;
                  case(byte_count_in - word_count_reg)
                    'd0 : begin //all 8bytes are data
                      nstate                = CRC0;
                    end

                    'd1 : begin //7bytes are data
                      crc_corr_prev_in      = crc_next[103:96] != link_data[63:56];
                      nstate                = CRC1;
                    end

                    'd2 : begin
                      crc_corr_prev_in      = crc_next[95:80] != {link_data[63:56], link_data[47:40]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd3 : begin
                      crc_corr_prev_in      = crc_next[79:64] != {link_data[47:40], link_data[31:24]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd4 : begin
                      crc_corrupted_in      = crc_next[63:48] != {link_data[31:24], link_data[15: 8]};
                      nstate                = IDLE;
                    end

                    'd5 : begin
                      crc_corrupted_in      = crc_next[47:32] != {link_data[15: 8], link_data[55:48]};
                      nstate                = IDLE;
                    end

                    'd6 : begin
                      crc_corrupted_in      = crc_next[31:16] != {link_data[55:48], link_data[39:32]};
                      nstate                = IDLE;
                    end

                    'd7 : begin
                      crc_corrupted_in      = crc_next[15: 0] != {link_data[39:32], link_data[23:16]};
                      nstate                = IDLE;
                    end
                  endcase
                  byte_count_in             = 'd0;
                end
              end
            end
          end

          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                crc_valid               = 'hff;
                byte_count_in           = byte_count + 'd8;
                crc_input[63: 0]        = link_data[63: 0];

                valid_in                = (APP_DATA_BYTES - byte_count[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;
                if(valid_prev) begin
                  app_data_reg_in        = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0] = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8] = app_data_saved[15: 8];
                  app_data_reg_in[23:16] = app_data_saved[23:16];
                  app_data_reg_in[31:24] = app_data_saved[31:24];
                end 

                //Lower 32bits always updated, upper only if not valid_in
                //app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 64] = link_data[63: 0];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+0)*8) +: 32] = link_data[31: 0];

                if(valid_in) begin
                  app_data_saved_in[31: 0] = link_data[63:32];
                end else begin
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+4)*8) +: 32] = link_data[63:32];
                end

                if(byte_count_in >= word_count_reg) begin
                  valid_in                  = 1'b1;
                  case(byte_count_in - word_count_reg)
                    'd0 : begin //all 8bytes are data
                      //valid_in              = 1'b0;
                      nstate                = CRC0;
                    end

                    'd1 : begin //7bytes are data
                      crc_corr_prev_in      = crc_next[103:96] != link_data[63:56];
                      nstate                = CRC1;
                    end

                    'd2 : begin
                      crc_corr_prev_in      = crc_next[95:80] != link_data[63:48];
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd3 : begin
                      crc_corr_prev_in      = crc_next[79:64] != link_data[55:40];
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd4 : begin
                      crc_corrupted_in      = crc_next[63:48] != link_data[47:32];
                      nstate                = IDLE;
                    end

                    'd5 : begin
                      crc_corrupted_in      = crc_next[47:32] != link_data[39:24];
                      nstate                = IDLE;
                    end

                    'd6 : begin
                      crc_corrupted_in      = crc_next[31:16] != link_data[31:16];
                      nstate                = IDLE;
                    end

                    'd7 : begin
                      crc_corrupted_in      = crc_next[15: 0] != link_data[23: 8];
                      nstate                = IDLE;
                    end
                  endcase
                  byte_count_in         = 'd0;
                end              
              end

              if(DATA_WIDTH==16) begin
                crc_valid               = 'hffff;
                byte_count_in           = byte_count + 'd16;
                crc_input[127:  0]      = {link_data[127:120],   
                                           link_data[111:104],   
                                           link_data[ 95: 88],   
                                           link_data[ 79: 72],   
                                           link_data[ 63: 56],   
                                           link_data[ 47: 40],   
                                           link_data[ 31: 24],   
                                           link_data[ 15:  8],   
                                           link_data[119:112],   
                                           link_data[103: 96],   
                                           link_data[ 87: 80],   
                                           link_data[ 71: 64],   
                                           link_data[ 55: 48],   
                                           link_data[ 39: 32],   
                                           link_data[ 23: 16],   
                                           link_data[  7:  0]};  

                valid_in                = (APP_DATA_BYTES - byte_count[APP_DATA_BYTES_CLOG2-1:0]) == 'd4;


                if(valid_prev) begin
                  app_data_reg_in        = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[95: 0] = app_data_saved[95: 0];
                end

                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 0)*8) +: 8] = link_data[  7:  0];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 1)*8) +: 8] = link_data[ 23: 16];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 2)*8) +: 8] = link_data[ 39: 32];
                app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 3)*8) +: 8] = link_data[ 55: 48];


                if(valid_in) begin
                  app_data_saved_in[ 7: 0]  = link_data[ 71: 64];
                  app_data_saved_in[15: 8]  = link_data[ 87: 80];
                  app_data_saved_in[23:16]  = link_data[103: 96];
                  app_data_saved_in[31:24]  = link_data[119:112];

                  app_data_saved_in[39:32]  = link_data[ 15:  8];
                  app_data_saved_in[47:40]  = link_data[ 31: 24];
                  app_data_saved_in[55:48]  = link_data[ 47: 40];
                  app_data_saved_in[63:56]  = link_data[ 63: 56];

                  app_data_saved_in[71:64]  = link_data[ 79: 72];
                  app_data_saved_in[79:72]  = link_data[ 95: 88];
                  app_data_saved_in[87:80]  = link_data[111:104];
                  app_data_saved_in[95:88]  = link_data[127:120];
                end else begin
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 4)*8) +: 8] = link_data[ 71: 64];  
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 5)*8) +: 8] = link_data[ 87: 80];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 6)*8) +: 8] = link_data[103: 96];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 7)*8) +: 8] = link_data[119:112];

                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 8)*8) +: 8] = link_data[ 15:  8];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+ 9)*8) +: 8] = link_data[ 31: 24];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+10)*8) +: 8] = link_data[ 47: 40];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+11)*8) +: 8] = link_data[ 63: 56];

                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+12)*8) +: 8] = link_data[ 79: 72];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+13)*8) +: 8] = link_data[ 95: 88];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+14)*8) +: 8] = link_data[111:104];
                  app_data_reg_in[((byte_count[APP_DATA_BYTES_CLOG2-1:0]+15)*8) +: 8] = link_data[127:120];
                end
                //--------------------


                //--------------------

                if(byte_count_in >= word_count_reg) begin
                  valid_in                  = 1'b1;
                  case(byte_count_in - word_count_reg)
                    'd0 : begin
                      nstate                = CRC0;
                    end

                    'd1 : begin
                      crc_corr_prev_in      = crc_next[231:224] != link_data[127:120];
                      nstate                = CRC1;
                    end

                    'd2 : begin
                      crc_corr_prev_in      = crc_next[223:208] != {link_data[127:120], link_data[111:104]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd3 : begin
                      crc_corr_prev_in      = crc_next[207:192] != {link_data[111:104], link_data[ 95: 88]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd4 : begin
                      crc_corr_prev_in      = crc_next[191:176] != {link_data[ 95: 88], link_data[ 79: 72]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd5 : begin
                      crc_corr_prev_in      = crc_next[175:160] != {link_data[ 79: 72], link_data[ 63: 56]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd6 : begin
                      crc_corr_prev_in      = crc_next[159:144] != {link_data[ 63: 56], link_data[ 47: 40]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd7 : begin
                      crc_corr_prev_in      = crc_next[143:128] != {link_data[ 47: 40], link_data[ 31: 24]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd8 : begin
                      crc_corr_prev_in      = crc_next[127:112] != {link_data[ 31: 24], link_data[ 15:  8]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd9 : begin
                      crc_corr_prev_in      = crc_next[111: 96] != {link_data[ 15:  8], link_data[119:112]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd10 : begin
                      crc_corr_prev_in      = crc_next[ 95: 80] != {link_data[119:112], link_data[103: 96]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd11 : begin
                      crc_corr_prev_in      = crc_next[ 79: 64] != {link_data[103: 96], link_data[ 87: 80]};
                      nstate                = IDLE;
                      send_saved_in         = valid_cond;
                    end

                    'd12 : begin
                      crc_corrupted_in      = crc_next[ 63: 48] != {link_data[ 87: 80], link_data[ 71: 64]};
                      nstate                = IDLE;
                    end

                    'd13 : begin
                      crc_corrupted_in      = crc_next[ 47: 32] != {link_data[ 71: 64], link_data[ 55: 48]};
                      nstate                = IDLE;
                    end

                    'd14 : begin
                      crc_corrupted_in      = crc_next[ 31: 16] != {link_data[ 55: 48], link_data[ 39: 32]};
                      nstate                = IDLE;
                    end

                    'd15 : begin
                      crc_corrupted_in      = crc_next[ 15:  0] != {link_data[ 39: 32], link_data[ 23: 16]};
                      nstate                = IDLE;
                    end
                  endcase
                  byte_count_in             = 'd0;
                end
              end
            end
          end

        endcase
        sop_in                  = valid_in && ~sop_sent;
        sop_sent_in             = valid_in ? 1'b1 : sop_sent;
      end
    end
    
    //-------------------------------------------
    CRC0 : begin
      crc_init                        = 1'b0;
      if(ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              nstate                  = CRC1;
              crc_corr_prev_in        = crc_reg[ 7: 0] != link_data[ 7: 0];
            end

            if(DATA_WIDTH==16) begin
              nstate                  = IDLE;
              crc_corrupted_in        = crc_reg[31:16] != link_data[15: 0];
              valid_in                = 1'b1;
            end
          end

          //Come here in TWO_LANEs IF the word count is even
          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                nstate                  = IDLE;
                crc_corrupted_in        = crc_reg[31:16] != link_data[15: 0];
                valid_in                = 1'b1;
              end

              if(DATA_WIDTH==16) begin
                nstate                  = IDLE;
                crc_corrupted_in        = crc_reg[63:48] != {link_data[23:16], link_data[7: 0]};
                valid_in                = 1'b1;
              end
            end
          end

          //Come here if on boundary
          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                nstate                    = IDLE;
                crc_corrupted_in          = crc_reg[63:48] != link_data[15: 0];
                valid_in                  = 1'b1;
              end

              if(DATA_WIDTH==16) begin
                nstate                    = IDLE;
                crc_corrupted_in          = crc_reg[127:112] != {link_data[23:16], link_data[7: 0]};
                valid_in                  = 1'b1;
                if(valid_prev) begin
                  app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                  app_data_reg_in[23:16]  = app_data_saved[23:16];
                  app_data_reg_in[31:24]  = app_data_saved[31:24];
                end
              end
            end
          end

          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                nstate                    = IDLE;
                crc_corrupted_in          = crc_reg[127:112] != link_data[15: 0];
                valid_in                  = 1'b1;
                if(valid_prev) begin
                  app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                  app_data_reg_in[23:16]  = app_data_saved[23:16];
                  app_data_reg_in[31:24]  = app_data_saved[31:24];
                end
              end

              if(DATA_WIDTH==16) begin
                nstate                    = IDLE;
                crc_corrupted_in          = crc_reg[255:240] != {link_data[23:16], link_data[ 7: 0]};
                valid_in                  = 1'b1;
                if(valid_prev) begin  //this should ALSO handle the send_saved situations
                  app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                  app_data_reg_in[23:16]  = app_data_saved[23:16];
                  app_data_reg_in[31:24]  = app_data_saved[31:24];

                  app_data_reg_in[39:32]  = app_data_saved[39:32];
                  app_data_reg_in[47:40]  = app_data_saved[47:40];
                  app_data_reg_in[55:48]  = app_data_saved[55:48];
                  app_data_reg_in[63:56]  = app_data_saved[63:56];

                  app_data_reg_in[71:64]  = app_data_saved[71:64];
                  app_data_reg_in[79:72]  = app_data_saved[79:72];
                  app_data_reg_in[87:80]  = app_data_saved[87:80];
                  app_data_reg_in[95:88]  = app_data_saved[95:88];
                end
              end
            end
          end
        endcase
        //In the case of small long packets, we could come here before ever sending SOP
        //so this check will ensure the SOP has been sent properly
        sop_in                  = valid_in && ~sop_sent;
        sop_sent_in             = valid_in ? 1'b1 : sop_sent;
      end else begin
        crc_init                = 1'b0;
      end
    end
    
    //-------------------------------------------
    CRC1 : begin
      if(ll_rx_valid) begin
        case(active_lanes)
          ONE_LANE : begin
            if(DATA_WIDTH==8) begin
              nstate                  = IDLE;
              crc_corrupted_in        = (crc_reg[15: 8] != link_data[ 7: 0]) || crc_corr_prev;
              valid_in                = 1'b1;
            end

            if(DATA_WIDTH==16) begin
              nstate                  = IDLE;
              crc_corrupted_in        = (crc_reg[15: 8] != link_data[ 7: 0]) || crc_corr_prev;
              valid_in                = 1'b1;
            end
          end

          TWO_LANE : begin
            if(NUM_LANES >= 2) begin
              if(DATA_WIDTH==8) begin
                nstate                  = IDLE;
                crc_corrupted_in        = (crc_reg[15: 8] != link_data[ 7: 0]) || crc_corr_prev;
                valid_in                = 1'b1;
              end

              if(DATA_WIDTH==16) begin
                nstate                = IDLE;
                crc_corrupted_in      = (crc_reg[47:40] != link_data[ 7: 0]) || crc_corr_prev;
                valid_in              = 1'b1;
              end
            end
          end

          //Come here only if a single byte remaining
          FOUR_LANE : begin
            if(NUM_LANES >= 4) begin
              if(DATA_WIDTH==8) begin
                nstate                = IDLE;
                crc_corrupted_in      = (crc_reg[47:40] != link_data[ 7: 0]) || crc_corr_prev;
                valid_in              = 1'b1;
              end

              if(DATA_WIDTH==16) begin
                nstate                = IDLE;
                crc_corrupted_in      = (crc_reg[111:104] != link_data[ 7: 0]) || crc_corr_prev;
                valid_in              = 1'b1;
                if(valid_prev) begin
                  app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                  app_data_reg_in[23:16]  = app_data_saved[23:16];
                  app_data_reg_in[31:24]  = app_data_saved[31:24];
                end
              end
            end
          end

          EIGHT_LANE : begin
            if(NUM_LANES >= 8) begin
              if(DATA_WIDTH==8) begin
                nstate                = IDLE;
                crc_corrupted_in      = (crc_reg[111:104] != link_data[ 7: 0]) || crc_corr_prev;      
                valid_in              = 1'b1;
                if(valid_prev) begin
                  app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                  app_data_reg_in[23:16]  = app_data_saved[23:16];
                  app_data_reg_in[31:24]  = app_data_saved[31:24];
                end
              end

              if(DATA_WIDTH==16) begin
                nstate                = IDLE;
                crc_corrupted_in      = (crc_reg[239:232] != link_data[ 7: 0]) || crc_corr_prev;
                valid_in              = 1'b1;
                if(valid_prev) begin
                  app_data_reg_in         = {APP_DATA_BYTES{8'h00}};
                  app_data_reg_in[ 7: 0]  = app_data_saved[ 7: 0];
                  app_data_reg_in[15: 8]  = app_data_saved[15: 8];
                  app_data_reg_in[23:16]  = app_data_saved[23:16];
                  app_data_reg_in[31:24]  = app_data_saved[31:24];

                  app_data_reg_in[39:32]  = app_data_saved[39:32];
                  app_data_reg_in[47:40]  = app_data_saved[47:40];
                  app_data_reg_in[55:48]  = app_data_saved[55:48];
                  app_data_reg_in[63:56]  = app_data_saved[63:56];

                  app_data_reg_in[71:64]  = app_data_saved[71:64];
                  app_data_reg_in[79:72]  = app_data_saved[79:72];
                  app_data_reg_in[87:80]  = app_data_saved[87:80];
                  app_data_reg_in[95:88]  = app_data_saved[95:88];
                end
              end
            end
          end

        endcase
        //In the case of small long packets, we could come here before ever sending SOP
        //so this check will ensure the SOP has been sent properly
        sop_in                  = valid_in && ~sop_sent;
        sop_sent_in             = valid_in ? 1'b1 : sop_sent;
      end else begin
        crc_init                = 1'b0;
      end
    end 
    
    
    default : begin
      nstate    = WAIT_SDS;
    end
  endcase
  
  if(link_reset_condition || external_link_reset_condition || ~enable) begin
    nstate      = WAIT_SDS;
  end
end

//temp 
assign data_id        = data_id_reg;
assign word_count     = word_count_reg;
assign app_data       = app_data_reg;


wire [7:0]  data_id_sel;
wire [15:0] word_count_sel;

assign data_id_sel      = send_saved ? send_saved_di : data_id_reg_in;
assign word_count_sel   = send_saved ? send_saved_wc : word_count_reg_in;

slink_ll_rx_pkt_filt u_slink_ll_rx_pkt_filt (
  .clk                  ( clk             ),
  .reset                ( reset           ),
  .sop                  ( sop_in          ), 
  .data_id              ( data_id_sel     ),  
  .word_count           ( word_count_sel  ), 
  
  .valid                ( valid_in        ), 
  .sop_app              ( sop_app         ), 
  .valid_app            ( valid_app       ));
  
                        
assign ecc_corrected  = active_lanes == ONE_LANE ? corrected && ((state == HEADER_ECC && DATA_WIDTH==8) || (state == HEADER_WC1 && DATA_WIDTH==16)) && (nstate != WAIT_SDS) :
                        active_lanes == TWO_LANE ? corrected && ((state == HEADER_WC1 && DATA_WIDTH==8) || (state == IDLE       && DATA_WIDTH==16)) && (nstate != WAIT_SDS) : corrected && (state == IDLE);
assign ecc_corrupted  = active_lanes == ONE_LANE ? corrupt   && ((state == HEADER_ECC && DATA_WIDTH==8) || (state == HEADER_WC1 && DATA_WIDTH==16)) && (nstate != WAIT_SDS) :
                        active_lanes == TWO_LANE ? corrupt   && ((state == HEADER_WC1 && DATA_WIDTH==8) || (state == IDLE       && DATA_WIDTH==16)) && (nstate != WAIT_SDS) : corrupt   && (state == IDLE);

slink_ecc_syndrome u_slink_ecc_syndrome (
  .ph_in           ( ph_check         ),               
  .rx_ecc          ( rx_ecc           ),              
  .calc_ecc        (                  ),              
  .corrected_ph    ( corrected_ph     ),  
  .corrected       ( corrected        ),  
  .corrupt         ( corrupt          )); 



genvar genloop;
generate
  for(genloop = 0; genloop < (NUM_LANES * (DATA_WIDTH/8)); genloop = genloop + 1) begin : crc_calc_gen
    // See the LL TX for a better description of why this is this way
    
    slink_crc_8_16bit_compute u_slink_crc_8_16bit_compute (
      .clk         ( clk                                          ),  
      .reset       ( reset                                        ),  
      .data_in     ( crc_input[((genloop+1)*8)-1 : genloop*8]     ),  
      .valid       ( crc_valid[genloop]                           ),  
      .init        ( crc_init                                     ),  
      .crc_prev    ( crc_prev[((genloop+1)*16)-1 : (genloop*16)]  ),    
      .crc_next    ( crc_next[((genloop+1)*16)-1 : (genloop*16)]  ),    
      .crc         ( crc_reg [((genloop+1)*16)-1 : (genloop*16)]  )); 
    
    
    if(genloop == 0) begin
      if(DATA_WIDTH == 8) begin
        assign crc_prev[15:0] = crc_reg[((1 << active_lanes)-1) * 16 +: 16];
      end else begin
        assign crc_prev[15:0] = crc_reg[((2 << active_lanes)-1) * 16 +: 16];
      end
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
  endcase
end

wire [APP_DATA_BYTES_CLOG2-1:0] byte_count_app_dbg;
assign byte_count_app_dbg = byte_count[APP_DATA_BYTES_CLOG2-1:0];
wire [15:0] byte_count_wc_remain = byte_count_in - word_count_reg;
`endif



endmodule

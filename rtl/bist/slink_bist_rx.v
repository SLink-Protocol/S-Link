module slink_bist_rx #(
  parameter APP_DATA_WIDTH  = 32,
  parameter APP_DATA_BYTES  = APP_DATA_WIDTH >> 3
)(
  input  wire                       clk,
  input  wire                       reset,
  
  input  wire                       swi_bist_en,
  input  wire                       swi_bist_reset,
  input  wire [3:0]                 swi_bist_mode_payload,
  input  wire                       swi_bist_mode_wc,
  input  wire [15:0]                swi_bist_wc_min,
  input  wire [15:0]                swi_bist_wc_max,
  input  wire                       swi_bist_mode_di,
  input  wire [7:0]                 swi_bist_di_min,
  input  wire [7:0]                 swi_bist_di_max, 
  
  output reg  [15:0]                bist_errors,
  output reg                        bist_locked,
  output wire                       bist_unrec,

  input  wire                       sop,
  input  wire [7:0]                 data_id,
  input  wire [15:0]                word_count,
  input  wire [APP_DATA_WIDTH-1:0]  app_data,
  input  wire                       valid
);

`include "slink_includes.vh"

localparam  IDLE      = 'd0,
            PAYLOAD   = 'd1,
            SOP_ST    = 'd2,
            UNREC     = 'd3;

reg   [1:0]       state, nstate;
reg   [16:0]      byte_count, byte_count_in;
wire              bist_en_ff2;

reg   [15:0]      word_count_save, word_count_save_in;
reg   [7:0]       data_id_save, data_id_save_in;
reg   [7:0]       data_id_xor;
reg   [APP_DATA_WIDTH-1:0]  app_data_xor;

wire  [15:0]      word_count_next;
wire  [7:0]       data_id_next;

reg   [15:0]      bist_errors_in;
reg               bist_error_cond;
reg   [$clog2(APP_DATA_WIDTH+8)-1:0]  bist_bit_errors;  
reg               bist_locked_in;

slink_demet_reset u_slink_demet_reset_bist_en (
  .clk     ( clk          ),       
  .reset   ( reset        ),       
  .sig_in  ( swi_bist_en  ),       
  .sig_out ( bist_en_ff2  )); 
  
wire bist_reset_ff2;
slink_demet_reset u_slink_demet_reset_bist_reset (
  .clk     ( clk             ),       
  .reset   ( reset           ),       
  .sig_in  ( swi_bist_reset  ),       
  .sig_out ( bist_reset_ff2  )); 


always @(posedge clk or posedge reset) begin
  if(reset) begin
    state           <= IDLE;
    byte_count      <= 'd0;
    word_count_save <= 'd0;
    data_id_save    <= 'd0;
    bist_errors     <= 'd0;
    bist_locked     <= 1'b0;
  end else begin
    state           <= nstate;
    byte_count      <= byte_count_in;
    word_count_save <= word_count_save_in;
    data_id_save    <= data_id_save_in;
    bist_errors     <= bist_reset_ff2 ? 'd0 : bist_errors_in;
    bist_locked     <= bist_locked_in;
  end
end


assign word_count_next  = swi_bist_mode_wc ? (word_count_save == swi_bist_wc_max ? swi_bist_wc_min : word_count_save + 'd1) : word_count_save;
assign data_id_next     = swi_bist_mode_di ? (data_id_save    == swi_bist_di_max ? swi_bist_di_min : data_id_save    + 'd1) : data_id_save;


assign bist_unrec       = (state == UNREC);

always @(*) begin
  nstate                      = state;
  byte_count_in               = byte_count;
  bist_errors_in              = bist_errors;
  word_count_save_in          = word_count_save;
  data_id_save_in             = data_id_save;
  bist_error_cond             = 1'b0;
  data_id_xor                 = 'd0;
  app_data_xor                = {APP_DATA_WIDTH{1'b0}};
  bist_bit_errors             = {$clog2(APP_DATA_WIDTH){1'b0}};
  bist_locked_in              = bist_locked;
  
  case(state)
    IDLE : begin
      if(bist_en_ff2) begin
        if(sop) begin
          byte_count_in       = APP_DATA_BYTES;
          word_count_save_in  = word_count;
          data_id_save_in     = data_id;
          
          data_id_xor         = data_id ^ swi_bist_di_min;
          for(int j = 0; j < 8; j = j + 1) begin
            if(data_id_xor[j]) begin
              bist_bit_errors  = bist_bit_errors + 'd1;
            end
          end
          
          bist_errors_in      = (bist_errors + bist_bit_errors >= 16'hffff) ? 16'hffff : bist_errors + bist_bit_errors;
          
          bist_locked_in      = 1'b1;
          //If word count is off, we are probably hosed
          nstate              = (word_count != swi_bist_wc_min) ? UNREC  : 
                                (byte_count_in >= word_count)   ? SOP_ST : PAYLOAD;
        end
      end else begin
        bist_locked_in      = 1'b0;
      end
    end
    
    PAYLOAD : begin
      if(valid) begin
        byte_count_in         = byte_count + APP_DATA_BYTES;
        
        case(swi_bist_mode_payload)
          BIST_PAYLOAD_1010 : begin
            for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count_save); i = i + 1) begin
              app_data_xor[(i*8) +: 8] = 8'haa ^ app_data[(i*8) +: 8];
            end
          end
          BIST_PAYLOAD_1100 : begin
            for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count_save); i = i + 1) begin
              app_data_xor[(i*8) +: 8] = 8'hcc ^ app_data[(i*8) +: 8];
            end
          end
          BIST_PAYLOAD_1111_0000 : begin
            for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count_save); i = i + 1) begin
              app_data_xor[(i*8) +: 8] = 8'hf0 ^ app_data[(i*8) +: 8];
            end
          end
          BIST_PAYLOAD_COUNT : begin
            for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count_save); i = i + 1) begin
              app_data_xor[(i*8) +: 8] = (byte_count + i) ^ app_data[(i*8) +: 8];
            end
          end
          default : begin
            for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count_save); i = i + 1) begin
              app_data_xor[(i*8) +: 8] = 8'hd0 ^ app_data[(i*8) +: 8];
            end
          end
        endcase
        
        //
        for(int j = 0; j < APP_DATA_WIDTH; j = j + 1) begin
          if(app_data_xor[j]) begin
            bist_bit_errors  = bist_bit_errors + 'd1;
          end
        end
        
        bist_errors_in      = (bist_errors + bist_bit_errors >= 16'hffff) ? 16'hffff : bist_errors + bist_bit_errors;
        
        if(byte_count_in >= word_count) begin
          byte_count_in     = 'd0;
          nstate            = SOP_ST;
        end
      end
    end
    
    
    SOP_ST : begin
      if(bist_en_ff2) begin
        if(sop) begin
          byte_count_in       = APP_DATA_BYTES;
          word_count_save_in  = word_count;
          data_id_save_in     = data_id;
          
          nstate              = (word_count != word_count_next) ? UNREC  : 
                                (byte_count_in >= word_count)   ? SOP_ST : PAYLOAD;
          
          case(swi_bist_mode_payload)
            BIST_PAYLOAD_1010 : begin
              for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count/*word_count_save*/); i = i + 1) begin
                app_data_xor[(i*8) +: 8] = 8'haa ^ app_data[(i*8) +: 8];
              end
            end
            BIST_PAYLOAD_1100 : begin
              for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count/*word_count_save*/); i = i + 1) begin
                app_data_xor[(i*8) +: 8] = 8'hcc ^ app_data[(i*8) +: 8];
              end
            end
            BIST_PAYLOAD_1111_0000 : begin
              for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count/*word_count_save*/); i = i + 1) begin
                app_data_xor[(i*8) +: 8] = 8'hf0 ^ app_data[(i*8) +: 8];
              end
            end
            BIST_PAYLOAD_COUNT : begin
              for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count/*word_count_save*/); i = i + 1) begin
                //app_data_xor[(i*8) +: 8] = (byte_count + i) ^ app_data[(i*8) +: 8];
                app_data_xor[(i*8) +: 8] =  i ^ app_data[(i*8) +: 8];
              end
            end
            default : begin
            for(int i = 0; (i < APP_DATA_BYTES) && ((i + byte_count) < word_count/*word_count_save*/); i = i + 1) begin
              app_data_xor[(i*8) +: 8] = 8'hd0 ^ app_data[(i*8) +: 8];
            end
          end
          endcase

          //
          for(int j = 0; j < APP_DATA_WIDTH; j = j + 1) begin
            if(app_data_xor[j]) begin
              bist_bit_errors  = bist_bit_errors + 'd1;
            end
          end

          bist_errors_in      = (bist_errors + bist_bit_errors >= 16'hffff) ? 16'hffff : bist_errors + bist_bit_errors;
        end
      end else begin
        bist_locked_in        = 1'b0;
        nstate                = IDLE;
      end
    end
    
    
    //Stay here until disabled
    UNREC : begin
      bist_locked_in        = 1'b0;
      if(~bist_en_ff2) begin
        nstate              = IDLE;
      end
    end
    
    default : begin
      nstate  = IDLE;
    end
  endcase
  
  if(~bist_en_ff2 || bist_reset_ff2) begin
    nstate    = IDLE;
  end
end

endmodule

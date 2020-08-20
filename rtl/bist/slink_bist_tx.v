module slink_bist_tx #(
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
  
  input  wire [31:0]                swi_bist_seed,
  
  //To LL TX
  output reg                        sop,
  output reg  [7:0]                 data_id,
  output reg  [15:0]                word_count,
  output reg  [APP_DATA_WIDTH-1:0]  app_data,
  input  wire                       advance
);

`include "slink_includes.vh"

localparam  IDLE      = 'd0,
            SOP_ST    = 'd1,
            PAYLOAD   = 'd2;


reg   [1:0]                 state, nstate;
reg   [16:0]                byte_count, byte_count_in;
wire                        bist_en_ff2;

reg                         sop_in;
reg   [7:0]                 data_id_in;
reg   [15:0]                word_count_in;
reg   [APP_DATA_WIDTH-1:0]  app_data_in;

wire  [15:0]                word_count_next;
wire  [7:0]                 data_id_next;

reg                         prbs9_init;
reg                         prbs9_advance;
wire  [APP_DATA_WIDTH-1:0]  prbs9;
wire  [(APP_DATA_BYTES*9)-1:0] prbs9_prev, prbs9_next, prbs9_next_reg;


slink_demet_reset u_slink_demet_reset_bist_en (
  .clk     ( clk          ),       
  .reset   ( reset        ),       
  .sig_in  ( swi_bist_en  ),       
  .sig_out ( bist_en_ff2  )); 



always @(posedge clk or posedge reset) begin
  if(reset) begin
    state         <= IDLE;
    byte_count    <= 'd0;
    sop           <= 1'b0;
    data_id       <= 'd0;
    word_count    <= 'd0;
    app_data      <= {APP_DATA_WIDTH{1'b0}};
  end else begin
    state         <= nstate;
    byte_count    <= byte_count_in;
    sop           <= sop_in;
    data_id       <= data_id_in;
    word_count    <= word_count_in;
    app_data      <= app_data_in;
  end
end


assign word_count_next  = swi_bist_mode_wc ? (word_count == swi_bist_wc_max ? swi_bist_wc_min : word_count + 'd1) : word_count;
assign data_id_next     = swi_bist_mode_di ? (data_id    == swi_bist_di_max ? swi_bist_di_min : data_id    + 'd1) : data_id;




always @(*) begin
  nstate                  = state;
  byte_count_in           = byte_count;
  sop_in                  = 1'b0;
  data_id_in              = data_id;
  word_count_in           = word_count;
  app_data_in             = app_data;
  prbs9_init              = 1'b1;
  prbs9_advance           = 1'b0;
  
  case(state)
    IDLE : begin
      if(bist_en_ff2) begin
        nstate            = SOP_ST;
        sop_in            = 1'b1;
        data_id_in        = swi_bist_di_min;
        word_count_in     = swi_bist_wc_min;
        byte_count_in     = APP_DATA_BYTES;
        
        case(swi_bist_mode_payload)
          BIST_PAYLOAD_1010 : begin
            app_data_in   = {APP_DATA_BYTES{8'haa}};
          end
          BIST_PAYLOAD_1100 : begin
            app_data_in   = {APP_DATA_BYTES{8'hcc}};
          end
          BIST_PAYLOAD_1111_0000 : begin
            app_data_in   = {APP_DATA_BYTES{8'hf0}};
          end
          BIST_PAYLOAD_COUNT : begin
            for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
              app_data_in[(i*8) +: 8] = i;
            end
          end
          
          BIST_PAYLOAD_PRBS9 : begin
            prbs9_init    = 1'b0;
            prbs9_advance = 1'b1;
            for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
              app_data_in[(i*8) +: 8] = prbs9[(i*8) +: 8];
            end
          end
          
          default : begin
            app_data_in   = {APP_DATA_BYTES{8'hd0}};
          end
        endcase
      end
    end
    
    
    SOP_ST : begin
      sop_in              = 1'b1;
      prbs9_init          = 1'b0;
      if(advance) begin
        if(byte_count >= word_count) begin
          sop_in          = 1'b1;
          data_id_in      = data_id_next;
          word_count_in   = word_count_next;
          byte_count_in   = APP_DATA_BYTES;
          nstate          = SOP_ST;
        end else begin
          sop_in          = 1'b0;
          byte_count_in   = byte_count + APP_DATA_BYTES;
          case(swi_bist_mode_payload)
            BIST_PAYLOAD_COUNT : begin
              for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
                app_data_in[(i*8) +: 8] = byte_count + i;
              end
            end
            
            BIST_PAYLOAD_PRBS9 : begin
              prbs9_advance = 1'b1;
              for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
                app_data_in[(i*8) +: 8] = prbs9[(i*8) +: 8];
              end
            end
          endcase
          nstate          = PAYLOAD;
        end
      end
    end
    
    
    PAYLOAD : begin
      prbs9_init    = 1'b0;
      
      if(advance) begin
        if(byte_count >= word_count) begin
          sop_in          = 1'b1;
          data_id_in      = data_id_next;
          word_count_in   = word_count_next;
          byte_count_in   = APP_DATA_BYTES;
          nstate          = SOP_ST;
          case(swi_bist_mode_payload)
            BIST_PAYLOAD_COUNT : begin
              for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
                app_data_in[(i*8) +: 8] = i;
              end
            end
          endcase
          
          if(~bist_en_ff2) begin
            sop_in        = 1'b0;
            nstate        = IDLE;
          end
        end else begin
          byte_count_in   = byte_count + APP_DATA_BYTES;
          case(swi_bist_mode_payload)
            BIST_PAYLOAD_COUNT : begin
              for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
                app_data_in[(i*8) +: 8] = byte_count + i;
              end
            end
            
            BIST_PAYLOAD_PRBS9 : begin
              prbs9_advance = 1'b1;
              for(int i = 0; i < APP_DATA_BYTES; i = i + 1) begin
                app_data_in[(i*8) +: 8] = prbs9[(i*8) +: 8];
              end
            end
          endcase
        end
      end
    end
    
    default : begin
      nstate  = IDLE;
    end
    
  endcase
end


genvar byteindex;
generate
  for(byteindex = 0; byteindex < APP_DATA_BYTES; byteindex = byteindex + 1) begin : gen_prbs
    slink_prbs9 u_slink_prbs9 (
      .clk     ( clk                        ), 
      .reset   ( reset                      ),     
      .advance ( prbs9_advance || prbs9_init             ),
      .prev    ( prbs9_prev[byteindex*9+:9] ),
      .next    ( prbs9_next[byteindex*9+:9] ),
      .next_reg( prbs9_next_reg[byteindex*9+:9] ),
      .prbs    ( prbs9[byteindex*8+:8]      )); 
      
    if(byteindex == 0) begin
      assign prbs9_prev[8:0]  = prbs9_init ? swi_bist_seed[8:0] : prbs9_next_reg[(APP_DATA_BYTES*9)-1:((APP_DATA_BYTES-1)*9)];
    end else begin
      assign prbs9_prev[byteindex*9+:9] = prbs9_next[(byteindex-1)*9+:9];
    end
  end
endgenerate


endmodule

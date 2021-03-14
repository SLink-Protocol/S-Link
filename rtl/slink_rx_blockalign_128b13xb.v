/*
.rst_start
slink_rx_blockalign_128b13xb
-----------------------------
Aligns data for PCIe/USB/Custom protocols that use 128/130b or 128/132b encoding.

This allows 8/16/32bit data widths by setting the ``DATA_WIDTH`` Parameter.

.rst_end
*/
module slink_rx_blockalign_128b13xb #(
  parameter DATA_WIDTH  = 16
)(
  input  wire                     clk,
  input  wire                     reset,
  input  wire                     enable,                 //demet external if needed
  input  wire                     blockalign,             //demet external if needed
  input  wire [1:0]               encode_mode,
  input  wire [DATA_WIDTH-1:0]    custom_sync_pat,
  input  wire [DATA_WIDTH-1:0]    rx_data_in,
  
  output wire [DATA_WIDTH-1:0]    rx_data_out,
  output wire [3:0]               rx_syncheader,
  output wire                     rx_valid,
  output wire                     rx_datavalid,
  output wire                     rx_startblock,
  output wire                     bad_syncheader,
  output reg                      eios_seen,
  output wire                     locked
);

localparam  IDLE        = 'd0,
            UNALIGNED   = 'd1,
            PRE_ALIGNED = 'd2,
            ALIGNED     = 'd3,
            STALL       = 'd4;


localparam  SYNC_PAT_130   = DATA_WIDTH == 8  ? 16'hff00 :
                             DATA_WIDTH == 16 ? 32'hff00_ff00 : 64'hff00_ff00_ff00_ff00;
localparam  SYNC_PAT_130_B = DATA_WIDTH == 8  ? 15'h7f00 :
                             DATA_WIDTH == 16 ? 31'h7f00_ff00 : 63'h7f00_ff00_ff00_ff00;
                             
localparam  SYNC_PAT_132   = DATA_WIDTH == 8  ? 16'hff00 :
                             DATA_WIDTH == 16 ? 32'hff00_ff00 : 64'hff00_ff00_ff00_ff00;
//Data width - 3
localparam  SYNC_PAT_132_B = DATA_WIDTH == 8  ? 15'h7f00 :
                             DATA_WIDTH == 16 ? 31'h7f00_ff00 : 63'h7f00_ff00_ff00_ff00;
//Data width - 2
localparam  SYNC_PAT_132_C = DATA_WIDTH == 8  ? 14'h3f00 :
                             DATA_WIDTH == 16 ? 30'h3f00_ff00 : 62'h3f00_ff00_ff00_ff00;
//Data width - 1
localparam  SYNC_PAT_132_D = DATA_WIDTH == 8  ? 13'h1f00 :
                             DATA_WIDTH == 16 ? 29'h1f00_ff00 : 61'h1f00_ff00_ff00_ff00;

//encode mode 
localparam  PCIE_MODE       = 2'b00,
            USB_MODE        = 2'b01,
            CUSTOM_MODE_130 = 2'b10;

localparam  USB_SKP         = DATA_WIDTH == 8  ? {8'hcc, 4'b1100}     :
                              DATA_WIDTH == 16 ? {16'hcccc, 4'b1100}  : {32'hcccc_cccc, 4'b1100};
localparam  USB_SKP_END     = 8'h33;

localparam  PCIE_SKP        = DATA_WIDTH == 8  ? {8'haa, 2'b01}       :
                              DATA_WIDTH == 16 ? {16'haaaa, 2'b01}    : {32'haaaa_aaaa, 2'b01};
localparam  PCIE_SKP_END    = 8'he1;


reg   [DATA_WIDTH-1:0]          rxdata1, rxdata2;
reg   [3:0]                     rxdata3;
wire  [(DATA_WIDTH*3)-1:0]      data_comp;
wire  [DATA_WIDTH+3:0]          data_out_sel [(DATA_WIDTH*2)-1:0];

wire  [DATA_WIDTH-1:0]          aligned_data_index_check;

reg   [$clog2(DATA_WIDTH)-1:0]  aligned_data_index;
reg   [$clog2(DATA_WIDTH)-1:0]  aligned_data_index_in;
reg                             aligned_data_index_check_valid;
reg   [$clog2(DATA_WIDTH):0]    current_alignment, current_alignment_in;
reg   [$clog2(DATA_WIDTH):0]    start_alignment, start_alignment_in;
reg   [3:0]                     byte_count, byte_count_in;
wire  [3:0]                     byte_count_inc;
wire  [3:0]                     byte_count_max;
wire  [3:0]                     byte_count_skp_end;
reg   [3:0]                     os_count, os_count_in;
wire  [3:0]                     os_count_max;

wire                            startblock_cond;
wire                            skp_seen;
reg                             in_skp;
wire                            skp_end_seen;
wire                            skp_end_seen_usb_zero_skp;

wire                            eios_seen_in;

wire                            nstate_is_align;

reg   [2:0]                     state, nstate;

always @(posedge clk or posedge reset) begin
  if(reset) begin
    state               <= IDLE;
    rxdata1             <= {DATA_WIDTH{1'b0}};
    rxdata2             <= {DATA_WIDTH{1'b0}};
    rxdata3             <= 'd0;
    aligned_data_index  <= 'd0;
    current_alignment   <= 'd0;
    start_alignment     <= 'd0;
    byte_count          <= 'd0;
    os_count            <= 'd0;
    in_skp              <= 1'b0;
    eios_seen           <= 1'b0;
  end else begin
    state               <= nstate;
    rxdata1             <= enable ? rx_data_in : {DATA_WIDTH{1'b0}};
    rxdata2             <= enable ? rxdata1    : {DATA_WIDTH{1'b0}};
    rxdata3             <= enable ? rxdata2[DATA_WIDTH-1:DATA_WIDTH-4] : 4'd0;
    aligned_data_index  <= aligned_data_index_in;
    current_alignment   <= current_alignment_in;
    start_alignment     <= start_alignment_in;
    byte_count          <= byte_count_in;
    os_count            <= os_count_in;
    in_skp              <= (state == STALL) ? 1'b0 : skp_seen ? 1'b1 : skp_end_seen ? 1'b0 : in_skp;
    eios_seen           <= (state == IDLE) || (state == UNALIGNED) ? 1'b0 : eios_seen ? 1'b1 : eios_seen_in;
  end
end


/*
.rst_start
``data_comp`` is three cycles of data allowing us to see the SyncHeader as well as 2 cycles of data. This gives more robustness with 
respect to finding the correct alignment, particularly with 8bit data widths.

``aligned_dat_index_check`` is a one-hot encoded vector that distinguishes what bit location starts the alignment. This includes
the sync header as well as the DATA_WIDTH. So if the pattern is seen starting at bit2, ``aligned_data_index_check`` would be 'h4 for that cycle.

``data_out_sel`` is a 2D vector that is the data+sync header from the respective alignment offset. i.e. data_out_sel[0] starts from
data_comp[0], data_out_sel[1] starts at data_comp[1], etc. The output of this block is the ``data_out_sel`` based on the current alignment.

.rst_end
*/

assign data_comp = {rx_data_in, rxdata1, rxdata2};

genvar genloop;
generate
  for(genloop = 0; genloop < DATA_WIDTH; genloop = genloop + 1) begin : gen_data_comp_check
    //On the last index (130, last 3 on 132), we actually cannot hit the full 2xDATA_WIDTH + SyncHeader. e.g. DATA_WIDTH == 16 128/130
    //data_comp is 48bits. genloop = 15 would be searching for data_comp[48:15], so the top bit would be missed.
    //So on the highest one, we just check one less bit. I'm assuming this should be sufficient, especially since we are
    //already looking at twice the data
    if(genloop == (DATA_WIDTH-1)) begin
      assign aligned_data_index_check[genloop] = blockalign ? encode_mode == PCIE_MODE ? {SYNC_PAT_130_B, 2'b01}   == data_comp[genloop+(2*DATA_WIDTH)+0:genloop] :
                                                                                         {SYNC_PAT_132_D, 4'b1100} == data_comp[genloop+(2*DATA_WIDTH)+0:genloop] : 'd0;
    end else if(genloop == (DATA_WIDTH-2)) begin
      assign aligned_data_index_check[genloop] = blockalign ? encode_mode == PCIE_MODE ? {SYNC_PAT_130, 2'b01}     == data_comp[genloop+(2*DATA_WIDTH)+1:genloop] :
                                                                                         {SYNC_PAT_132_C, 4'b1100} == data_comp[genloop+(2*DATA_WIDTH)+1:genloop] : 'd0;
    end else if(genloop == (DATA_WIDTH-3)) begin
      assign aligned_data_index_check[genloop] = blockalign ? encode_mode == PCIE_MODE ? {SYNC_PAT_130, 2'b01}     == data_comp[genloop+(2*DATA_WIDTH)+1:genloop] :
                                                                                         {SYNC_PAT_132_B, 4'b1100} == data_comp[genloop+(2*DATA_WIDTH)+2:genloop] : 'd0;
    end else begin
      assign aligned_data_index_check[genloop] = blockalign ? encode_mode == PCIE_MODE ? {SYNC_PAT_130, 2'b01}     == data_comp[genloop+(2*DATA_WIDTH)+1:genloop] :
                                                                                         {SYNC_PAT_132, 4'b1100}   == data_comp[genloop+(2*DATA_WIDTH)+3:genloop] : 'd0;
    end
  end
  
  for(genloop = 0; genloop < (DATA_WIDTH*2); genloop = genloop + 1) begin : gen_data_out_sel
    //Similar to above, the last one for 130 and the last 3 for 132 are not really possible to hit
    if(genloop == ((DATA_WIDTH*2)-1)) begin
      assign data_out_sel[genloop]             = {DATA_WIDTH+4{1'b0}};
    end else if(genloop == ((DATA_WIDTH*2)-2)) begin
      assign data_out_sel[genloop]             = encode_mode == USB_MODE  ? {DATA_WIDTH+4{1'b0}} :
                                                                            {2'b00, data_comp[genloop+DATA_WIDTH+1:genloop]};
    end else if(genloop == ((DATA_WIDTH*2)-3)) begin
      assign data_out_sel[genloop]             = encode_mode == USB_MODE  ? {DATA_WIDTH+4{1'b0}} :
                                                                            {2'b00, data_comp[genloop+DATA_WIDTH+1:genloop]};
    end else begin
      assign data_out_sel[genloop]             = encode_mode == USB_MODE  ?         data_comp[genloop+DATA_WIDTH+3:genloop] :
                                                                            {2'b00, data_comp[genloop+DATA_WIDTH+1:genloop]};
    end
  end
  
endgenerate

always @(*) begin

  if(DATA_WIDTH == 8) begin
    aligned_data_index_check_valid     = 1'b1;
    case({enable, aligned_data_index_check})
      'h0_00 : begin 
        aligned_data_index_in          = 'd0;
        aligned_data_index_check_valid = 1'b0;
      end
      'h1_00 : begin
        aligned_data_index_in          = aligned_data_index;
        aligned_data_index_check_valid = 1'b0;
      end

      'h1_01 : aligned_data_index_in = 'd0;
      'h1_02 : aligned_data_index_in = 'd1;
      'h1_04 : aligned_data_index_in = 'd2;
      'h1_08 : aligned_data_index_in = 'd3;

      'h1_10 : aligned_data_index_in = 'd4;
      'h1_20 : aligned_data_index_in = 'd5;
      'h1_40 : aligned_data_index_in = 'd6;
      'h1_80 : aligned_data_index_in = 'd7;

      default       : begin
        aligned_data_index_in          = 'd0;
        aligned_data_index_check_valid = 1'b0;
      end
    endcase
  end

  if(DATA_WIDTH == 16) begin
    aligned_data_index_check_valid     = 1'b1;
    case({enable, aligned_data_index_check})
      'h0_0000 : begin 
        aligned_data_index_in          = 'd0;
        aligned_data_index_check_valid = 1'b0;
      end
      'h1_0000 : begin
        aligned_data_index_in          = aligned_data_index;
        aligned_data_index_check_valid = 1'b0;
      end

      'h1_0001 : aligned_data_index_in = 'd0;
      'h1_0002 : aligned_data_index_in = 'd1;
      'h1_0004 : aligned_data_index_in = 'd2;
      'h1_0008 : aligned_data_index_in = 'd3;

      'h1_0010 : aligned_data_index_in = 'd4;
      'h1_0020 : aligned_data_index_in = 'd5;
      'h1_0040 : aligned_data_index_in = 'd6;
      'h1_0080 : aligned_data_index_in = 'd7;

      'h1_0100 : aligned_data_index_in = 'd8;
      'h1_0200 : aligned_data_index_in = 'd9;
      'h1_0400 : aligned_data_index_in = 'd10;
      'h1_0800 : aligned_data_index_in = 'd11;

      'h1_1000 : aligned_data_index_in = 'd12;
      'h1_2000 : aligned_data_index_in = 'd13;
      'h1_4000 : aligned_data_index_in = 'd14;
      'h1_8000 : aligned_data_index_in = 'd15;

      default       : begin
        aligned_data_index_in               = 'd0;
        aligned_data_index_check_valid      = 1'b0;
      end
    endcase
  end

  if(DATA_WIDTH == 32) begin
    aligned_data_index_check_valid          = 1'b1;
    case({enable, aligned_data_index_check})
      33'h0_0000_0000 : begin 
        aligned_data_index_in               = 'd0;
        aligned_data_index_check_valid      = 1'b0;
      end
      33'h1_0000_0000 : begin
        aligned_data_index_in               = aligned_data_index;
        aligned_data_index_check_valid      = 1'b0;
      end

      33'h1_0000_0001 : aligned_data_index_in = 'd0;
      33'h1_0000_0002 : aligned_data_index_in = 'd1;
      33'h1_0000_0004 : aligned_data_index_in = 'd2;
      33'h1_0000_0008 : aligned_data_index_in = 'd3;

      33'h1_0000_0010 : aligned_data_index_in = 'd4;
      33'h1_0000_0020 : aligned_data_index_in = 'd5;
      33'h1_0000_0040 : aligned_data_index_in = 'd6;
      33'h1_0000_0080 : aligned_data_index_in = 'd7;

      33'h1_0000_0100 : aligned_data_index_in = 'd8;
      33'h1_0000_0200 : aligned_data_index_in = 'd9;
      33'h1_0000_0400 : aligned_data_index_in = 'd10;
      33'h1_0000_0800 : aligned_data_index_in = 'd11;

      33'h1_0000_1000 : aligned_data_index_in = 'd12;
      33'h1_0000_2000 : aligned_data_index_in = 'd13;
      33'h1_0000_4000 : aligned_data_index_in = 'd14;
      33'h1_0000_8000 : aligned_data_index_in = 'd15;

      33'h1_0001_0000 : aligned_data_index_in = 'd16;
      33'h1_0002_0000 : aligned_data_index_in = 'd17;
      33'h1_0004_0000 : aligned_data_index_in = 'd18;
      33'h1_0008_0000 : aligned_data_index_in = 'd19;

      33'h1_0010_0000 : aligned_data_index_in = 'd20;
      33'h1_0020_0000 : aligned_data_index_in = 'd21;
      33'h1_0040_0000 : aligned_data_index_in = 'd22;
      33'h1_0080_0000 : aligned_data_index_in = 'd23;

      33'h1_0100_0000 : aligned_data_index_in = 'd24;
      33'h1_0200_0000 : aligned_data_index_in = 'd25;
      33'h1_0400_0000 : aligned_data_index_in = 'd26;
      33'h1_0800_0000 : aligned_data_index_in = 'd27;

      33'h1_1000_0000 : aligned_data_index_in = 'd28;
      33'h1_2000_0000 : aligned_data_index_in = 'd29;
      33'h1_4000_0000 : aligned_data_index_in = 'd30;
      33'h1_8000_0000 : aligned_data_index_in = 'd31;

      default       : begin
        aligned_data_index_in               = 'd0;
        aligned_data_index_check_valid      = 1'b0;
      end
    endcase
  end
end


assign byte_count_inc     = (DATA_WIDTH == 8)  ? byte_count + 'd1 :
                            (DATA_WIDTH == 16) ? byte_count + 'd2 : byte_count + 'd4;
assign byte_count_max     = (DATA_WIDTH == 8)  ? 'd15 :
                            (DATA_WIDTH == 16) ? 'd14 : 'd12;
assign byte_count_skp_end = 'd14; 
assign os_count_max       = (DATA_WIDTH == 8)  ? encode_mode == USB_MODE ? 'd1 : 'd3 :
                            (DATA_WIDTH == 16) ? encode_mode == USB_MODE ? 'd3 : 'd7 : encode_mode == USB_MODE ? 'd7 : 'd15;




always @(*) begin
  nstate                        = state;
  current_alignment_in          = current_alignment;
  start_alignment_in            = start_alignment;
  byte_count_in                 = byte_count;
  os_count_in                   = os_count;
  
  case(state)
    //----------------------------------
    IDLE : begin
      byte_count_in             = 'd0;
      os_count_in               = 'd0;
      if(enable) begin
        nstate                  = UNALIGNED;
      end
    end
    
    //----------------------------------
    UNALIGNED : begin
      if((|aligned_data_index_check) && aligned_data_index_check_valid) begin
        current_alignment_in    = aligned_data_index_in;
        start_alignment_in      = aligned_data_index_in;
        byte_count_in           = byte_count_inc;
        nstate                  = ALIGNED;
      end
    end
    
    // ----------------------------------
    // Hokay, so here is how this works
    // We have the `start_alignment` that keeps up with the INITIAL bit alignment. We double the size of the data_out_sel
    // so we can accomodate the worst case bit alignment of 15bits away. Now, you could just have the current_alignment be 4 bits
    // and rotate, however the issue is that the rotation has to happen when the current_alignment "rolls over". Ideally, you want
    // the first block you send out to be the cycle after data_valid has deasserted. So this requires you to only do the
    // rotation after the OS count equals the number of blocks to send (4/8/16 depending on DATA_WIDTH). So we are 
    // taking up a little more logic to handle that case.
    //
    // This is really done to ease the implementation of the deskew block. You can be assured that when the data is coming in, it's 
    // always started relative to the other lanes datavalid's. This prevents you from having to accomodate deasserted data valids
    // throughout various locations in the data stream.
    //
    ALIGNED : begin
      if((byte_count == byte_count_max) ||
         (skp_end_seen && DATA_WIDTH == 32) ) begin //if skp_end seen and 32 bits then this is the end of the OS
        os_count_in             = os_count + 'd1;
        byte_count_in           = 'd0;
        current_alignment_in    = encode_mode == USB_MODE ? current_alignment + 'd4 : current_alignment + 'd2;
        
        if(os_count == os_count_max) begin
          os_count_in           = 'd0;
          nstate                = STALL;
        end
      end else begin
        byte_count_in           = ((skp_seen | in_skp) && ~skp_end_seen) ? byte_count : (skp_end_seen ? byte_count_skp_end : byte_count_inc);
      end
      
      
      //We can only get here if the blockalign is asserted and would re-align the data
      //this should not change the actual alignment unless something was off
      if((|aligned_data_index_check) && aligned_data_index_check_valid && 
         (aligned_data_index_in != current_alignment)) begin
        current_alignment_in    = aligned_data_index_in;
        byte_count_in           = (DATA_WIDTH == 8)  ? 'd1 :
                                  (DATA_WIDTH == 16) ? 'd2 : 'd4;
        os_count_in             = 'd0;
      end
    end
    
    //----------------------------------
    STALL : begin
      current_alignment_in      = start_alignment;
      nstate                    = ALIGNED;
    end
    
    default : begin
      nstate                    = IDLE;
    end
  
  endcase
  
  if(~enable) begin
    current_alignment_in        = 'd0;
    start_alignment_in          = 'd0;
    nstate                      = IDLE;
  end
end


assign skp_seen       = encode_mode == USB_MODE ? (data_out_sel[current_alignment][DATA_WIDTH+3:0] == USB_SKP)  && startblock_cond :
                                                  (data_out_sel[current_alignment][DATA_WIDTH+1:0] == PCIE_SKP) && startblock_cond;
                                                  
assign skp_end_seen   = in_skp ? (encode_mode == USB_MODE ? data_out_sel[current_alignment][11:4] == USB_SKP_END :
                                                            data_out_sel[current_alignment][9:2]  == PCIE_SKP_END) :  skp_end_seen_usb_zero_skp ? 1'b1 : 1'b0;
                                                            
assign skp_end_seen_usb_zero_skp = (encode_mode == USB_MODE) && (data_out_sel[current_alignment][11:0] == {USB_SKP_END, 4'b1100}) && startblock_cond;



assign eios_seen_in     = 1'b0; //add this

assign nstate_is_align  = (state == UNALIGNED && nstate == ALIGNED);

assign rx_data_out      = encode_mode == USB_MODE ? (nstate_is_align ? data_out_sel[current_alignment_in][4 +:DATA_WIDTH] : data_out_sel[current_alignment][4 +:DATA_WIDTH]) : 
                                                    (nstate_is_align ? data_out_sel[current_alignment_in][2 +:DATA_WIDTH] : data_out_sel[current_alignment][2 +:DATA_WIDTH]);
assign rx_syncheader    = encode_mode == USB_MODE ? (nstate_is_align ? data_out_sel[current_alignment_in][3:0] : data_out_sel[current_alignment][3:0]) : 
                                                    (nstate_is_align ? {2'b00, data_out_sel[current_alignment_in][1:0]} : {2'b00, data_out_sel[current_alignment][1:0]});
assign rx_datavalid     = (state == ALIGNED) || nstate_is_align;
assign startblock_cond  = (((state == ALIGNED) && (byte_count == 'd0)) || nstate_is_align) && ~in_skp;
assign rx_startblock    = startblock_cond;
assign rx_valid         = (state == ALIGNED) || nstate_is_align || (state == STALL);

assign locked           = rx_valid;
assign bad_syncheader   = encode_mode == USB_MODE ? startblock_cond && ~nstate_is_align && ((data_out_sel[current_alignment][3:0] != 4'b0011) && (data_out_sel[current_alignment][3:0] != 4'b1100)) :
                                                    startblock_cond && ~nstate_is_align && ((data_out_sel[current_alignment][1:0] != 2'b01)   && (data_out_sel[current_alignment][1:0] != 2'b10));

endmodule

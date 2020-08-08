module slink_ecc_syndrome(
  input  wire [23:0]      ph_in,            //Received Packet Header
  input  wire [7:0]       rx_ecc,           //Received ECC Value
  output wire [7:0]       calc_ecc,         //Calculated (if TX)
  output reg  [23:0]      corrected_ph,     //Corrected Packet Header
  output reg              corrected,        //1 - Single Bit was corrected
  output reg              corrupt           //1 - More than single bit so cannot fix
);

wire [7:0]      ecc;    //generated value
wire [7:0]      syndrome;

assign ecc[0]   = ph_in[0] ^ 
                  ph_in[1] ^ 
                  ph_in[2] ^ 
                  ph_in[4] ^ 
                  ph_in[5] ^ 
                  ph_in[7] ^ 
                  ph_in[10] ^ 
                  ph_in[11] ^ 
                  ph_in[13] ^ 
                  ph_in[16] ^ 
                  ph_in[20] ^ 
                  ph_in[21] ^ 
                  ph_in[22] ^ 
                  ph_in[23];

assign ecc[1]   = ph_in[0] ^ 
                  ph_in[1] ^ 
                  ph_in[3] ^ 
                  ph_in[4] ^ 
                  ph_in[6] ^ 
                  ph_in[8] ^ 
                  ph_in[10] ^ 
                  ph_in[12] ^ 
                  ph_in[14] ^ 
                  ph_in[17] ^ 
                  ph_in[20] ^ 
                  ph_in[21] ^ 
                  ph_in[22] ^ 
                  ph_in[23];

assign ecc[2]   = ph_in[0] ^ 
                  ph_in[2] ^ 
                  ph_in[3] ^ 
                  ph_in[5] ^ 
                  ph_in[6] ^ 
                  ph_in[9] ^ 
                  ph_in[11] ^ 
                  ph_in[12] ^ 
                  ph_in[15] ^ 
                  ph_in[18] ^ 
                  ph_in[20] ^ 
                  ph_in[21] ^ 
                  ph_in[22];

assign ecc[3]   = ph_in[1] ^ 
                  ph_in[2] ^ 
                  ph_in[3] ^ 
                  ph_in[7] ^ 
                  ph_in[8] ^ 
                  ph_in[9] ^ 
                  ph_in[13] ^ 
                  ph_in[14] ^ 
                  ph_in[15] ^ 
                  ph_in[19] ^ 
                  ph_in[20] ^ 
                  ph_in[21] ^ 
                  ph_in[23];

assign ecc[4]   = ph_in[4] ^ 
                  ph_in[5] ^ 
                  ph_in[6] ^ 
                  ph_in[7] ^ 
                  ph_in[8] ^ 
                  ph_in[9] ^ 
                  ph_in[16] ^ 
                  ph_in[17] ^ 
                  ph_in[18] ^ 
                  ph_in[19] ^ 
                  ph_in[20] ^ 
                  ph_in[22] ^ 
                  ph_in[23];

assign ecc[5]   = ph_in[10] ^ 
                  ph_in[11] ^ 
                  ph_in[12] ^ 
                  ph_in[13] ^ 
                  ph_in[14] ^ 
                  ph_in[15] ^ 
                  ph_in[16] ^ 
                  ph_in[17] ^ 
                  ph_in[18] ^ 
                  ph_in[19] ^ 
                  ph_in[21] ^ 
                  ph_in[22] ^ 
                  ph_in[23];

assign ecc[7:6] = 2'b00;

assign syndrome = ecc ^ rx_ecc;
assign calc_ecc = ecc;


always @(*) begin
  corrected = 1'b0; 
  corrupt   = 1'b0;
  
  case(syndrome[5:0])
    'h00 : corrected_ph = ph_in; 
    
    //Single Bit Error
    6'h07 : begin corrected_ph = {ph_in[23:1],  ~ph_in[0]              }; corrected = 1'b1; end
    6'h0B : begin corrected_ph = {ph_in[23:2],  ~ph_in[1],  ph_in[0]   }; corrected = 1'b1; end
    6'h0D : begin corrected_ph = {ph_in[23:3],  ~ph_in[2],  ph_in[1:0] }; corrected = 1'b1; end
    6'h0E : begin corrected_ph = {ph_in[23:4],  ~ph_in[3],  ph_in[2:0] }; corrected = 1'b1; end
    6'h13 : begin corrected_ph = {ph_in[23:5],  ~ph_in[4],  ph_in[3:0] }; corrected = 1'b1; end
    6'h15 : begin corrected_ph = {ph_in[23:6],  ~ph_in[5],  ph_in[4:0] }; corrected = 1'b1; end
    6'h16 : begin corrected_ph = {ph_in[23:7],  ~ph_in[6],  ph_in[5:0] }; corrected = 1'b1; end
    6'h19 : begin corrected_ph = {ph_in[23:8],  ~ph_in[7],  ph_in[6:0] }; corrected = 1'b1; end
    6'h1A : begin corrected_ph = {ph_in[23:9],  ~ph_in[8],  ph_in[7:0] }; corrected = 1'b1; end
    6'h1C : begin corrected_ph = {ph_in[23:10], ~ph_in[9],  ph_in[8:0] }; corrected = 1'b1; end
    6'h23 : begin corrected_ph = {ph_in[23:11], ~ph_in[10], ph_in[9:0] }; corrected = 1'b1; end
    6'h25 : begin corrected_ph = {ph_in[23:12], ~ph_in[11], ph_in[10:0]}; corrected = 1'b1; end
    6'h26 : begin corrected_ph = {ph_in[23:13], ~ph_in[12], ph_in[11:0]}; corrected = 1'b1; end
    6'h29 : begin corrected_ph = {ph_in[23:14], ~ph_in[13], ph_in[12:0]}; corrected = 1'b1; end
    6'h2A : begin corrected_ph = {ph_in[23:15], ~ph_in[14], ph_in[13:0]}; corrected = 1'b1; end
    6'h2C : begin corrected_ph = {ph_in[23:16], ~ph_in[15], ph_in[14:0]}; corrected = 1'b1; end
    6'h31 : begin corrected_ph = {ph_in[23:17], ~ph_in[16], ph_in[15:0]}; corrected = 1'b1; end
    6'h32 : begin corrected_ph = {ph_in[23:18], ~ph_in[17], ph_in[16:0]}; corrected = 1'b1; end
    6'h34 : begin corrected_ph = {ph_in[23:19], ~ph_in[18], ph_in[17:0]}; corrected = 1'b1; end
    6'h38 : begin corrected_ph = {ph_in[23:20], ~ph_in[19], ph_in[18:0]}; corrected = 1'b1; end
    6'h1F : begin corrected_ph = {ph_in[23:21], ~ph_in[20], ph_in[19:0]}; corrected = 1'b1; end
    6'h2F : begin corrected_ph = {ph_in[23:22], ~ph_in[21], ph_in[20:0]}; corrected = 1'b1; end
    6'h37 : begin corrected_ph = {ph_in[23],    ~ph_in[22], ph_in[21:0]}; corrected = 1'b1; end
    6'h3B : begin corrected_ph = {              ~ph_in[23], ph_in[22:0]}; corrected = 1'b1; end
    
    //Ecc has error
    6'h01 : begin corrected_ph = ph_in; corrected = 1'b1; end
    6'h02 : begin corrected_ph = ph_in; corrected = 1'b1; end
    6'h04 : begin corrected_ph = ph_in; corrected = 1'b1; end
    6'h08 : begin corrected_ph = ph_in; corrected = 1'b1; end
    6'h10 : begin corrected_ph = ph_in; corrected = 1'b1; end
    6'h20 : begin corrected_ph = ph_in; corrected = 1'b1; end
    
    default : begin
      begin corrected_ph = ph_in; corrupt = 1'b1; end
    end
  endcase
end



endmodule

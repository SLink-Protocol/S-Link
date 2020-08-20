/*
CRC calculation matching CSI/DSI with 16bit CRC.
data_in is the data from the link
Should match CRC-16/MCRF44X (crccalc.com)
FF 00 00 00 1E F0 1E C7 4F 82 78 C5 82 E0 8C 70 D2 3C 78 E9 FF 00 00 01
^^^^this pattern should give you a xE569 as result
*/
module slink_crc_8_16bit_compute(
  input  wire           clk,
  input  wire           reset,
  input  wire [7:0]     data_in,
  input  wire           valid,
  input  wire           init,
  input  wire [15:0]    crc_prev,
  output wire [15:0]    crc_next,
  output reg  [15:0]    crc

);

wire  [15:0] crc_in16;
wire  [15:0] crc_in8;

always @(posedge clk or posedge reset) begin
  if(reset) begin
    crc       <= 16'hffff;
  end else begin
    crc       <= init   ? 16'hffff : 
                 valid  ? crc_in8  : crc;
  end
end

assign crc_next = valid ? crc_in8  : 16'hffff;


//Can this be more optimzed?
assign crc_in8[15] = data_in[7] ^ data_in[3] ^ crc_prev[3] ^ crc_prev[7];
assign crc_in8[14] = data_in[6] ^ data_in[2] ^ crc_prev[2] ^ crc_prev[6];
assign crc_in8[13] = data_in[5] ^ data_in[1] ^ crc_prev[1] ^ crc_prev[5];
assign crc_in8[12] = data_in[4] ^ data_in[0] ^ crc_prev[0] ^ crc_prev[4];
assign crc_in8[11] = data_in[3] ^ crc_prev[3];
assign crc_in8[10] = data_in[7] ^ data_in[3] ^ crc_prev[3] ^ crc_prev[7] ^ data_in[2] ^ crc_prev[2];
assign crc_in8[ 9] = data_in[6] ^ data_in[2] ^ crc_prev[2] ^ crc_prev[6] ^ data_in[1] ^ crc_prev[1];
assign crc_in8[ 8] = data_in[5] ^ data_in[1] ^ crc_prev[1] ^ crc_prev[5] ^ data_in[0] ^ crc_prev[0];
assign crc_in8[ 7] = data_in[4] ^ data_in[0] ^ crc_prev[0] ^ crc_prev[4] ^ crc_prev[15];
assign crc_in8[ 6] = data_in[3] ^ crc_prev[3] ^ crc_prev[14];
assign crc_in8[ 5] = data_in[2] ^ crc_prev[2] ^ crc_prev[13];
assign crc_in8[ 4] = data_in[1] ^ crc_prev[1] ^ crc_prev[12];
assign crc_in8[ 3] = data_in[7] ^ data_in[3] ^ crc_prev[3] ^ crc_prev[7] ^ data_in[0] ^ crc_prev[0] ^ crc_prev[11];
assign crc_in8[ 2] = data_in[6] ^ data_in[2] ^ crc_prev[2] ^ crc_prev[6] ^ crc_prev[10];
assign crc_in8[ 1] = data_in[5] ^ data_in[1] ^ crc_prev[1] ^ crc_prev[5] ^ crc_prev[9];
assign crc_in8[ 0] = data_in[4] ^ data_in[0] ^ crc_prev[0] ^ crc_prev[4] ^ crc_prev[8];


endmodule


module slink_prbs9(
  input  wire       clk,
  input  wire       reset,
  input  wire       advance,
  input  wire [8:0] prev,
  output wire [8:0] next,
  output wire [8:0] next_reg,
  
  output wire [7:0] prbs
);

reg [8:0]   LFSR;
wire[8:0]   LFSR_in;


always @(posedge clk or posedge reset) begin
  if(reset) begin
    LFSR      <= 9'd0;
  end else begin
    LFSR      <= LFSR_in;
  end
end


assign LFSR_in = advance  ? {prev[0],
                             prev[8] ^ prev[4],
                             prev[7] ^ prev[3],
                             prev[6] ^ prev[2],
                             prev[5] ^ prev[1],
                             prev[4] ^ prev[0],
                             prev[3] ^ prev[8] ^ prev[4],
                             prev[2] ^ prev[7] ^ prev[3],
                             prev[1] ^ prev[6] ^ prev[2]} : LFSR;




assign prbs = LFSR[7:0];

assign next     = advance ? LFSR_in : LFSR;
assign next_reg = LFSR;

endmodule

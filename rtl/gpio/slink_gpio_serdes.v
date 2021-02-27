/**
  * A generic "serdes" that uses a simple GPIO to convert the parallel data
  * to a lower width (must be a power of two)
  */
module slink_gpio_serdes #(
  parameter   PAR_DATA_WIDTH  = 8,
  parameter   IO_DATA_WIDTH   = 1
)(
  input  wire                       core_scan_mode,
  input  wire                       core_scan_clk,
  
  input  wire                       serial_clk,       //from pll/clk source in master, from pad in slave
  input  wire                       serial_reset,
  
  input  wire                       clk_en,
  input  wire                       clk_idle,
  output wire                       clk_ready,
  
  output wire                       phy_clk,
  
  input  wire                       tx_en,
  output wire                       tx_ready,
  input  wire [PAR_DATA_WIDTH-1:0]  tx_par_data,
  
  input  wire                       rx_en,
  output wire                       rx_ready,
  output reg  [PAR_DATA_WIDTH-1:0]  rx_par_data,
  
  output wire                       tx_ser_clk,
  output wire [IO_DATA_WIDTH-1:0]   tx_ser_data,
  input  wire [IO_DATA_WIDTH-1:0]   rx_ser_data
);


localparam  DIV_RATIO   = PAR_DATA_WIDTH / IO_DATA_WIDTH;   //You want this to be a power of 2
localparam  COUNT_CLOG2 = $clog2(DIV_RATIO);

wire                        clk_en_ff2;
wire                        clk_idle_ff2;
wire                        serial_clk_gated;


wire                        clk_active;
reg   [COUNT_CLOG2-1:0]     count;
wire  [COUNT_CLOG2-1:0]     count_in;
wire                        tx_en_ff2;
wire  [IO_DATA_WIDTH-1:0]   tx_ser_data_array [DIV_RATIO-1:0];

wire                        rx_en_ff2;
reg   [IO_DATA_WIDTH-1:0]   rx_ser_data_samp;

reg   [IO_DATA_WIDTH-1:0]   rx_par_data_reg [DIV_RATIO-1:0];
wire  [PAR_DATA_WIDTH-1:0]  rx_par_data_in;

slink_demet_reset u_slink_demet_reset[3:0] (
  .clk     ( serial_clk      ),  
  .reset   ( serial_reset    ),  
  .sig_in  ( {tx_en,
              rx_en,
              clk_en,
              clk_idle}         ),  
  .sig_out ( {tx_en_ff2,
              rx_en_ff2,
              clk_en_ff2,
              clk_idle_ff2}     )); 

assign clk_ready = clk_en_ff2;

assign clk_active = (clk_en_ff2 && ~clk_idle_ff2);
  

slink_clock_gate u_slink_clock_gate (
  .clk_in            ( serial_clk         ),    
  .reset             ( serial_reset       ),    
  .core_scan_mode    ( core_scan_mode     ),  
  .enable            ( clk_active         ),  
  .disable_clkgate   ( 1'b0               ),  
  .clk_out           ( serial_clk_gated   )); 

assign tx_ser_clk = serial_clk_gated;


//thanks ARM! 
//The clock gate latch seems to just let X prop
//when you default the clock high. This is probably
//better anyways, but I don't see where it really matters

always @(posedge serial_clk_gated or posedge serial_reset) begin
  if(serial_reset) begin
    //count     <= {COUNT_CLOG2{1'b0}};   
    count     <= {COUNT_CLOG2{1'b1}};
  end else begin
    count     <= count_in;
  end
end

assign phy_clk_pre  = ~count[COUNT_CLOG2-1];
//assign phy_clk_pre  = count[COUNT_CLOG2-1];




slink_clock_mux u_slink_clock_mux_phy_clk (
  .clk0    ( phy_clk_pre        ),   
  .clk1    ( core_scan_clk      ),   
  .sel     ( core_scan_mode     ),   
  .clk_out ( phy_clk            )); 


//assign count_in     = clk_active ? count + 'd1 : 'd0;
assign count_in     = clk_active ? count + 'd1 : {COUNT_CLOG2{1'b1}};
assign tx_ready     = tx_en_ff2;  
assign tx_ser_data  = tx_ser_data_array[count];

genvar index;
generate
  for(index = 0; index < DIV_RATIO; index = index + 1) begin
    assign tx_ser_data_array[index] = tx_par_data[((index+1)*IO_DATA_WIDTH)-1 : (index*IO_DATA_WIDTH)];
  end
endgenerate

assign rx_ready     = rx_en_ff2;  

always @(negedge serial_clk_gated or posedge serial_reset) begin
  if(serial_reset) begin
    rx_ser_data_samp  <= {PAR_DATA_WIDTH{1'b0}};
  end else begin
    rx_ser_data_samp  <= ~rx_en_ff2 ? {PAR_DATA_WIDTH{1'b0}} : rx_ser_data;
  end
end

genvar rxindex;
generate
  for(rxindex = 0; rxindex < DIV_RATIO; rxindex = rxindex + 1) begin
    always @(posedge serial_clk_gated or posedge serial_reset) begin
      if(serial_reset) begin
        rx_par_data_reg[rxindex] <= {IO_DATA_WIDTH{1'b0}};
      end else begin
        if(~rx_en_ff2) begin
          rx_par_data_reg[rxindex] <= {IO_DATA_WIDTH{1'b0}};
        end else if(count == rxindex) begin
          rx_par_data_reg[rxindex] <= rx_ser_data_samp;
        end else begin
          rx_par_data_reg[rxindex] <= rx_par_data_reg[rxindex];
        end
      end
    end
    
    assign rx_par_data_in[((rxindex+1)*IO_DATA_WIDTH)-1 : (rxindex*IO_DATA_WIDTH)] = rx_par_data_reg[rxindex];
  end
endgenerate

always @(posedge phy_clk) begin
  rx_par_data <= ~rx_en_ff2 ? {PAR_DATA_WIDTH{1'b0}} : rx_par_data_in;
end

endmodule

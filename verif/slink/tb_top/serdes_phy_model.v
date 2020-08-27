`timescale 1ps/1fs

/*
.rst_start

.rst_end
*/

 
//--------------------------------------------
module serdes_clk_model #(
  parameter IS_MASTER = 1
) (
  input  wire   enable,
  input  wire   idle,
  output reg    ready,
  output reg    bitclk
);

initial begin
  bitclk = 0;
end

always #0.0625ns bitclk <= enable && ~idle && IS_MASTER ? ~bitclk : 1'b0;

always @(*) begin
  if(enable) begin
    #2us;
    ready = 1'b1;
  end else begin
    ready = 1'b0;
  end
end

endmodule
 
 //--------------------------------------------
module serdes_tx_model #(
  parameter DATA_WIDTH = 8
)(
  input  wire                   bitclk,
  
  input  wire                   enable,
  output wire                   txclk,
  input  wire [DATA_WIDTH-1:0]  tx_data,
  input  wire                   tx_reset,
  output wire                   tx_dirdy,
  output reg                    tx_ready,
  
  output wire                   txp,  
  output wire                   txn
);

int random_delay;

int tx_count;
reg [DATA_WIDTH-1:0] tx_data_reg;

always @(posedge bitclk or posedge tx_reset) begin
  if(tx_reset) begin
    tx_count <= 0;
  end else begin
    tx_count <= tx_count == DATA_WIDTH-1 ? 0 : tx_count + 1;
  end
end

assign txclk = tx_count < (DATA_WIDTH/2);

always @(posedge txclk or posedge tx_reset) begin
  if(tx_reset) begin
    tx_data_reg <= {DATA_WIDTH{1'b0}};
  end else begin
    tx_data_reg <= tx_data;
  end
end

//assign #10ps txp   = tx_reset ? $random : tx_data_reg[tx_count];
assign txp   = tx_reset ? $urandom : tx_data_reg[tx_count];
assign txn   = ~txp;


//temp
//assign tx_ready = enable;
always @(*) begin
  if(enable) begin
    random_delay = 100 + {$urandom} % (200 - 100);
    #(random_delay * 1ns);
    tx_ready = 1'b1;
  end else begin
    random_delay = 1 + {$urandom} % (20 - 1);
    #(random_delay * 1ns);
    tx_ready = 1'b0;
  end
end
assign tx_dirdy = tx_ready;

endmodule


 //--------------------------------------------
module serdes_rx_model#(
  parameter DATA_WIDTH = 8
)(
  input  wire                   bitclk,
  
  input  wire                   enable,
  output reg                    rxclk,
  input  wire                   rx_align,
  output reg  [DATA_WIDTH-1:0]  rx_data,
  input  wire                   rx_reset,
  output wire                   rx_locked,
  output wire                   rx_valid,
  output wire                   rx_dordy,
  output reg                    rx_ready,
  
  input  wire                   rxp,
  input  wire                   rxn
);
int random_delay;

int rx_count;
always @(posedge bitclk or posedge rx_reset) begin
  if(rx_reset) begin
    rx_count <= 0;
  end else begin
    rx_count <= rx_count == DATA_WIDTH-1 ? 0 : rx_count + 1;
  end
end

//assign rxclk = rx_count < (DATA_WIDTH/2);
always @(*) begin
  rxclk <= rx_count < (DATA_WIDTH/2);
end

reg [DATA_WIDTH-1:0] rx_data_samp;

always @(posedge bitclk or posedge rx_reset) begin
  if(rx_reset) begin
    rx_data_samp <= 0;
  end else begin
    rx_data_samp[rx_count] <= rxp;
  end
end




//Alignment logic

// reg  [DATA_WIDTH-1:0] rx_data_align;
// 
// 
// reg  [(DATA_WIDTH*2)-1:0] data_comp;
// wire [DATA_WIDTH-1:0]     aligned_data_index_pre;
// reg  [DATA_WIDTH-1:0]     aligned_data_index;
// wire [DATA_WIDTH-1:0]     aligned_data_index_in;
// wire [DATA_WIDTH-1:0]     data_out_in [DATA_WIDTH-1:0];
// genvar genloop;
// generate
//   for(genloop = 0; genloop < DATA_WIDTH; genloop = genloop + 1) begin : data_alignment
//     assign aligned_data_index_pre[genloop] = data_comp[genloop+(DATA_WIDTH-1):genloop] == {{(DATA_WIDTH/8)-1{8'h55}}, 8'hbc};  //fix this
//     assign data_out_in[genloop]            = data_comp[genloop+(DATA_WIDTH-1):genloop];
//     
//     //Output data assignment
//     always @(*) begin
//       if(|aligned_data_index) begin
//         if(aligned_data_index[genloop]) begin
//           rx_data_align  = data_out_in[genloop];
//         end
//       end else begin
//         rx_data_align = 'd0;
//       end
//     end
//   end
//   
//   
//   
// endgenerate
// 
// assign aligned_data_index_in = rx_align && (|aligned_data_index_pre) ? aligned_data_index_pre : aligned_data_index;
// 
// always @(posedge rxclk or posedge rx_reset) begin
//   if(rx_reset) begin
//     data_comp           <= {DATA_WIDTH*2{1'b0}};
//     aligned_data_index  <= {DATA_WIDTH{1'b0}};
//   end else begin
//     data_comp           <= {rx_data_samp, data_comp[(DATA_WIDTH*2)-1: DATA_WIDTH]};
//     aligned_data_index  <= enable ? aligned_data_index_in : 'd0;
//   end
// end
// 
// assign rx_locked = (|aligned_data_index);
// assign rx_valid  = rx_locked;
// 
assign rx_dordy  = rx_valid;
//assign rx_ready  = enable;
always @(*) begin
  if(enable) begin
    random_delay = 100 + {$urandom} % (200 - 100);
    #(random_delay * 1ns);
    rx_ready = 1'b1;
  end else begin
    random_delay = 1 + {$urandom} % (20 - 1);
    #(random_delay * 1ns);
    rx_ready = 1'b0;
  end
end

assign rx_valid = rx_ready;

// always @(*) begin
//   rx_data = rx_data_align;
// end


always @(posedge rxclk or posedge rx_reset) begin
  if(rx_reset) begin
    rx_data <= 'd0;
  end else begin
    rx_data <= rx_data_samp;
  end
end

endmodule



 //--------------------------------------------
module serdes_phy_model #(
  parameter IS_MASTER     = 1,
  parameter DATA_WIDTH    = 8,
  parameter NUM_TX_LANES  = 4,
  parameter NUM_RX_LANES  = 4
)(
  input  wire                                   clk_enable,
  input  wire                                   clk_idle,
  output wire                                   clk_ready,
  inout  wire                                   clk_bitclk,
  
  input  wire [NUM_TX_LANES-1:0]                tx_enable,
  output wire [NUM_TX_LANES-1:0]                txclk,
  input  wire [(NUM_TX_LANES*DATA_WIDTH)-1:0]   tx_data,
  input  wire [NUM_TX_LANES-1:0]                tx_reset,
  output wire [NUM_TX_LANES-1:0]                tx_dirdy,
  output wire [NUM_TX_LANES-1:0]                tx_ready,
  
  input  wire [NUM_RX_LANES-1:0]                rx_enable,
  output wire [NUM_RX_LANES-1:0]                rxclk,
  input  wire [NUM_RX_LANES-1:0]                rx_align,
  output reg  [(NUM_RX_LANES*DATA_WIDTH)-1:0]   rx_data,
  input  wire [NUM_RX_LANES-1:0]                rx_reset,
  output wire [NUM_RX_LANES-1:0]                rx_locked,
  output wire [NUM_RX_LANES-1:0]                rx_valid,
  output wire [NUM_RX_LANES-1:0]                rx_dordy,
  output wire [NUM_RX_LANES-1:0]                rx_ready,
  
  output wire [NUM_TX_LANES-1:0]                txp,  
  output wire [NUM_TX_LANES-1:0]                txn,
  input  wire [NUM_RX_LANES-1:0]                rxp,
  input  wire [NUM_RX_LANES-1:0]                rxn
);





wire bitclk;

serdes_clk_model u_serdes_clk_model (
  .enable    ( clk_enable     ),   
  .idle      ( clk_idle       ),   
  .ready     ( clk_ready      ),   
  .bitclk    ( bitclk         )); 

assign clk_bitclk = IS_MASTER ? bitclk : 1'bz;


parameter MAX_DELAY_CYC = 16;

reg  [MAX_DELAY_CYC-1:0] delay_element_p      [NUM_RX_LANES-1:0];
reg  [MAX_DELAY_CYC-1:0] delay_element_n      [NUM_RX_LANES-1:0];
reg  [$clog2(MAX_DELAY_CYC)-1:0] delay_amount [NUM_RX_LANES];

initial begin
  foreach(delay_amount[i]) begin
    delay_amount[i] = $urandom;
    //delay_amount[i] = 0;
    $display("mst %0d -- %0d", i, delay_amount[i]);
  end
end



genvar txindex;
genvar rxindex;

wire [NUM_RX_LANES-1:0] rxp_dly;
wire [NUM_RX_LANES-1:0] rxn_dly;

generate 
  for(txindex = 0; txindex < NUM_TX_LANES; txindex = txindex + 1) begin : gen_tx_serdes_models
    serdes_tx_model #(
      //parameters
      .DATA_WIDTH         ( DATA_WIDTH )
    ) u_serdes_tx_model (
      .bitclk    ( clk_bitclk                           ),  
      .enable    ( tx_enable[txindex]                   ),  
      .txclk     ( txclk[txindex]                       ),  
      .tx_data   ( tx_data[((txindex+1)*DATA_WIDTH)-1:txindex*DATA_WIDTH] ),            
      .tx_reset  ( tx_reset[txindex]                    ),  
      .tx_dirdy  ( tx_dirdy[txindex]                    ),  
      .tx_ready  ( tx_ready[txindex]                    ),  
      .txp       ( txp[txindex]                         ),  
      .txn       ( txn[txindex]                         )); 
    
  end
  
  for(rxindex = 0; rxindex < NUM_RX_LANES; rxindex = rxindex + 1) begin : gen_rx_serdes_models
    serdes_rx_model #(
      //parameters
      .DATA_WIDTH         ( DATA_WIDTH )
    ) u_serdes_rx_model (
      .bitclk    ( clk_bitclk                           ),  
      .enable    ( rx_enable[rxindex]                   ),  
      .rxclk     ( rxclk[rxindex]                       ),  
      .rx_align  ( rx_align[rxindex]                    ),  
      .rx_data   ( rx_data[((rxindex+1)*DATA_WIDTH)-1:rxindex*DATA_WIDTH] ),          
      .rx_reset  ( rx_reset[rxindex]                    ),  
      .rx_locked ( rx_locked[rxindex]                   ),  
      .rx_valid  ( rx_valid[rxindex]                    ),  
      .rx_dordy  ( rx_dordy[rxindex]                    ),  
      .rx_ready  ( rx_ready[rxindex]                    ),  
      .rxp       ( rxp_dly[rxindex]                     ),  
      .rxn       ( rxn_dly[rxindex]                     )); 
    
    //Skew/Delay generation  
    always @(posedge bitclk) begin
      for(int i = 0; i < MAX_DELAY_CYC; i = i + 1) begin
        if(i == 0) begin
          delay_element_p[rxindex][0] <= rxp[rxindex];  
          delay_element_n[rxindex][0] <= rxn[rxindex];  
        end else begin
          delay_element_p[rxindex][i] <= delay_element_p[rxindex][i-1];
          delay_element_n[rxindex][i] <= delay_element_n[rxindex][i-1];
        end    
      end
    end
    
    assign rxp_dly[rxindex] = delay_element_p[rxindex][delay_amount[rxindex]];
    assign rxn_dly[rxindex] = delay_element_n[rxindex][delay_amount[rxindex]];
    
    
    
  end
endgenerate





endmodule

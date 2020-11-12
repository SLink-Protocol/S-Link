// Common RTL components that will require changes for various processes
// A user may want to change these for their specific requirements


module slink_demet_reset
  (
   input  wire   clk,
   input  wire   reset,
   input  wire   sig_in,
   output wire   sig_out
  );

  reg [1:0]      demet_flops;

  assign sig_out = demet_flops[0];

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      demet_flops      <= 2'b00;
    end else begin
      demet_flops      <= {sig_in, demet_flops[1]};
    end
  end

endmodule


module slink_demet_set
  (
   input  wire   clk,
   input  wire   set,
   input  wire   sig_in,
   output wire   sig_out
  );

  reg [1:0]      demet_flops;

  assign sig_out = demet_flops[0];

  always @(posedge clk or posedge set) begin
    if (set) begin
      demet_flops      <= 2'b11;
    end else begin
      demet_flops      <= {sig_in, demet_flops[1]};
    end
  end

endmodule

module slink_reset_sync
(
  input  wire     clk,
  input  wire     scan_ctrl,
  input  wire     reset_in,
  output wire     reset_out
);

  wire reset_in_ff2;
  wire reset_in_int;

  assign reset_in_int = ~scan_ctrl & reset_in;

  slink_demet_set u_demet_set(
    .clk          ( clk               ),
    .set          ( reset_in_int      ),
    .sig_in       ( 1'b0              ),
    .sig_out      ( reset_in_ff2      ));

  assign  reset_out = ~scan_ctrl & (reset_in | reset_in_ff2);

endmodule




module slink_clock_mux(
  input  wire   clk0,
  input  wire   clk1,
  input  wire   sel,
  output wire   clk_out
);

assign clk_out = sel ? clk1 : clk0;

endmodule


module slink_clock_inv(
  input  wire   clk_in,
  output wire   clk_out
);

assign clk_out = ~clk_in;

endmodule

module slink_clock_buf(
  input  wire   clk_in,
  output wire   clk_out
);

assign clk_out = clk_in;

endmodule


module slink_clock_gate(
  input  wire   clk_in,
  input  wire   reset,
  input  wire   core_scan_mode,
  input  wire   enable,
  input  wire   disable_clkgate,
  output wire   clk_out
);

wire clk_en;
wire enable_ff2;

slink_demet_reset u_slink_demet_reset (
  .clk     ( clk_in           ),      
  .reset   ( reset            ),      
  .sig_in  ( enable ||
             disable_clkgate  ),      
  .sig_out ( enable_ff2       )); 


assign clk_en = enable_ff2 | core_scan_mode;

assign clk_out = clk_en & clk_in;

endmodule

module slink_clock_or(
  input  wire   clk0,
  input  wire   clk1,
  output wire   clk_out
);

assign clk_out = clk0 | clk1;

endmodule


module slink_clock_mux_sync(
  input  wire           reset0,
  input  wire           reset1,
  input  wire           sel,
  input  wire           clk0,
  input  wire           clk1,
  output wire           clk_out
);

wire clk0_inv;
wire clk1_inv;
wire sel_inv;
wire sel0_in;
wire sel1_in;
wire clk0_out;
wire clk1_out;
wire clk_out_pre;

reg sel0_ff1, sel0_ff2;
reg sel1_ff1, sel1_ff2;

wire sel_buf;

//Google glichless clock mux and look for EETimes article

slink_clock_inv u_clk0_inv (
  .clk_in    ( clk0      ),  
  .clk_out   ( clk0_inv  )); 

slink_clock_inv u_clk1_inv (
  .clk_in    ( clk1      ),  
  .clk_out   ( clk1_inv  )); 

//for case_analysis settings
slink_clock_buf u_sel_buf(.clk_in(sel), .clk_out(sel_buf));

slink_clock_inv u_sel_inv(.clk_in(sel_buf), .clk_out(sel_inv));


//assign sel_inv = ~sel;
assign sel0_in = ~sel1_ff2 & sel_inv;
assign sel1_in = ~sel0_ff2 & sel;

assign clk0_out = sel0_ff2 & clk0;
assign clk1_out = sel1_ff2 & clk1;


always @(posedge clk0 or posedge reset0) begin
  if(reset0) sel0_ff1 <= 1'b0;
  else       sel0_ff1 <= sel0_in;
end

always @(posedge clk0_inv or posedge reset0) begin
  if(reset0) sel0_ff2 <= 1'b0;
  else       sel0_ff2 <= sel0_ff1;
end

always @(posedge clk1 or posedge reset1) begin
  if(reset1) sel1_ff1 <= 1'b0;
  else       sel1_ff1 <= sel1_in;
end

always @(posedge clk1_inv or posedge reset1) begin
  if(reset1) sel1_ff2 <= 1'b0;
  else       sel1_ff2 <= sel1_ff1;
end

//assign clk_out_pre = clk0_out | clk1_out;
slink_clock_or u_clk_or(.clk0(clk0_out), .clk1(clk1_out), .clk_out(clk_out_pre));

//Final buffer (declare clock here)
slink_clock_buf u_slink_clock_buf(.clk_in(clk_out_pre), .clk_out(clk_out));


endmodule



module slink_fifo_top #(
  parameter                   DATA_SIZE     = 40,
  parameter                   ADDR_SIZE     = 4
)(
  input  wire                 wclk,
  input  wire                 wreset,
  input  wire                 winc,
  input  wire                 rclk,
  input  wire                 rreset,
  input  wire                 rinc,
  input  wire [DATA_SIZE-1:0] wdata,
  output wire [DATA_SIZE-1:0] rdata,
  output wire                 wfull,
  output wire                 rempty,
  
  output wire [ADDR_SIZE:0]   rbin_ptr,
  output wire [ADDR_SIZE+1:0] rdiff,   
  output wire [ADDR_SIZE:0]   wbin_ptr,
  output wire [ADDR_SIZE+1:0] wdiff,   
  
  
  input  wire [ADDR_SIZE-1:0] swi_almost_empty,
  input  wire [ADDR_SIZE-1:0] swi_almost_full,
  output wire                 half_full,
  output wire                 almost_empty,
  output wire                 almost_full
);


wire [ADDR_SIZE-1:0]          waddr;
wire [ADDR_SIZE-1:0]          raddr;
wire [ADDR_SIZE:0]            wptr, sync_wptr;
wire [ADDR_SIZE:0]            rptr, sync_rptr;


 


//demets for ptr sync
slink_demet_reset u_rptr_to_wlogic_demet[ADDR_SIZE:0] (
  .clk      ( wclk        ),            
  .reset    ( wreset      ),            
  .sig_in   ( rptr        ),            
  .sig_out  ( sync_rptr   )             
);

slink_demet_reset u_wptr_to_rlogic_demet[ADDR_SIZE:0] (
  .clk      ( rclk        ),            
  .reset    ( rreset      ),            
  .sig_in   ( wptr        ),            
  .sig_out  ( sync_wptr   )             
);




//write logic
slink_fifo_ptr_logic #(
  .ADDR_SIZE          ( ADDR_SIZE ),
  .IS_WRITE_PTR       ( 1         )
) u_write_ptr_logic (
  .inc               ( winc                 ),  
  .clk               ( wclk                 ),  
  .reset             ( wreset               ),  
  .swi_almost_val    ( swi_almost_full      ),  
  .sync_ptr          ( sync_rptr            ),  
  .ptr               ( wptr                 ),  
  .bin_ptr           ( wbin_ptr             ),  
  .diff              ( wdiff                ),  
  .addr              ( waddr                ),  
  .flag              ( wfull                ),  
  .almost_fe         ( almost_full          ),  
  .half_full         ( half_full            )); 


//read logic
slink_fifo_ptr_logic #(
  .ADDR_SIZE          ( ADDR_SIZE ),
  .IS_WRITE_PTR       ( 0         )
) u_read_ptr_logic (
  .inc               ( rinc                 ),  
  .clk               ( rclk                 ),  
  .reset             ( rreset               ),  
  .swi_almost_val    ( swi_almost_empty     ),  
  .sync_ptr          ( sync_wptr            ),  
  .ptr               ( rptr                 ),  
  .bin_ptr           ( rbin_ptr             ),  
  .diff              ( rdiff                ),  
  .addr              ( raddr                ),  
  .flag              ( rempty               ),  
  .almost_fe         ( almost_empty         ),  
  .half_full         (                      )); 




//mem
slink_fifomem #(
  .DATA_SIZE  ( DATA_SIZE    ),                             
  .ADDR_SIZE  ( ADDR_SIZE    )                   
) u_mem (
  .wclk       ( wclk         ),                             
  .rclk       ( rclk         ),
  .wclken     ( winc         ),  
  .read_en    ( ~rempty      ),                           
  .wreset     ( wreset       ),                            
  .wfull      ( wfull        ),                             
  .waddr      ( waddr        ),                             
  .raddr      ( raddr        ),                             
  .wdata      ( wdata        ),                             
  .rdata      ( rdata        )                              
);



endmodule


/*
* Based on sunburst-design.com's fifo design. Removed the need for two separate blocks
* by using generate statements to produce full/empty flag. Also changed reset to active high,
* because active low resets just confuse me
*/


module slink_fifo_ptr_logic #(
  parameter                           IS_WRITE_PTR  = 1,      //Determines the output logic
  parameter                           ADDR_SIZE     = 4
)(
  input  wire                         inc,
  input  wire                         clk,
  input  wire                         reset,
  input  wire [ADDR_SIZE-1:0]         swi_almost_val,         //programmable value for almost full/empty. Set to the difference you wish
  input  wire [ADDR_SIZE:0]           sync_ptr,               //pointer from opposite logic block
  output reg  [ADDR_SIZE:0]           ptr,                    //this blocks gray-encoded pointer to opposite block
  output wire [ADDR_SIZE:0]           bin_ptr,                //this blocks binary pointer 
  output wire [ADDR_SIZE+1:0]         diff,                   //difference between pointers
  output wire [ADDR_SIZE-1:0]         addr,                   //addr to memory
  output reg                          flag,                   //empty/full flag            
  output reg                          almost_fe,              //almost full/empty flag, port representation is based on the setting
  output wire                         half_full               //1 when write pointer - read pointer is >= half of full val (you can think of it as half-empty if your one of those people)
);

reg  [ADDR_SIZE:0]      bin;
wire [ADDR_SIZE:0]      graynext;
wire [ADDR_SIZE:0]      binnext;


wire [ADDR_SIZE:0]      sync_bin;   //binary value of the sync ptr
//wire [ADDR_SIZE+1:0]    diff;



always @(posedge clk or posedge reset) begin
  if(reset) begin
    bin           <= {ADDR_SIZE+1{1'b0}};
    ptr           <= {ADDR_SIZE+1{1'b0}};
  end else begin
    bin           <= binnext;
    ptr           <= graynext;
  end
end


assign addr       = bin[ADDR_SIZE-1:0];
assign binnext    = bin + (inc & ~flag);
assign graynext   = (binnext>>1) ^ binnext;

//gray2bin conversion for size checking
assign sync_bin[ADDR_SIZE:0] = sync_ptr[ADDR_SIZE:0] ^ {1'b0, sync_bin[ADDR_SIZE:1]};


assign bin_ptr = bin;

 


// Full/Empty logic generation, need to comeback to add in something that describes the almost full/empty cases
// Can't break out the flag register as the reset value is different depending on the mode
generate
  if(IS_WRITE_PTR == 1) begin : gen_full_logic
    //2 MSBs should not equal, lower bits should for full indication
    wire    full_int, half_full_int, almost_fe_int;
    reg     half_full_reg;
    
    
    assign  diff            = bin + (~sync_bin + {{ADDR_SIZE-1{1'b0}}, 1'b1});
    assign  full_int        = (graynext == {~sync_ptr[ADDR_SIZE:ADDR_SIZE-1], sync_ptr[ADDR_SIZE-2:0]});
    assign  half_full_int   = (diff[ADDR_SIZE:0]   >= {2'b01, {ADDR_SIZE-1{1'b0}}});    //half of addr area
    assign  almost_fe_int   = (diff[ADDR_SIZE-1:0] >= swi_almost_val);                  //The higher you set this, the later it trips (stays high if full)
    assign  half_full       = half_full_reg;
    
    always @(posedge clk or posedge reset) begin
      if(reset) begin
        flag          <= 1'b0;
        half_full_reg <= 1'b0;
        almost_fe     <= 1'b0;
      end else begin
        flag          <= full_int;
        half_full_reg <= half_full_int;
        almost_fe     <= almost_fe_int;
      end          
    end 
    
  end else begin : gen_empty_logic
    //write pointer should equal read pointer for empty
    wire    empty_int, almost_fe_int;
    
    
    assign empty_int        = (graynext == sync_ptr);  
    assign half_full        = 1'b0;                                                     //half_full is invalid, so tieoff
    assign diff             = sync_bin + (~bin + {{ADDR_SIZE-1{1'b0}}, 1'b1});
    assign almost_fe_int    = (diff[ADDR_SIZE-1:0] <= swi_almost_val); 
    
    always @(posedge clk or posedge reset) begin
      if(reset) begin
        flag        <= 1'b1;
        almost_fe   <= 1'b1;
      end else begin          
        flag        <= empty_int;
        almost_fe   <= almost_fe_int;
      end
    end 
    
  end
endgenerate





endmodule



module slink_fifomem #(
  parameter                     DATA_SIZE        = 40,
  parameter                     ADDR_SIZE        = 4
)(
  input  wire                   wclk,
  input  wire                   rclk,
  input  wire                   wclken,
  input  wire                   read_en,
  input  wire                   wreset,       
  input  wire                   wfull,
  input  wire [ADDR_SIZE-1:0]   waddr,
  input  wire [ADDR_SIZE-1:0]   raddr,
  input  wire [DATA_SIZE-1:0]   wdata,
  output wire [DATA_SIZE-1:0]   rdata
);

localparam    DEPTH = 1<<ADDR_SIZE;
wire web;
wire reb;


reg [DATA_SIZE-1:0]   mem [0:DEPTH-1];

assign rdata  = mem[raddr];

integer i;
always @(posedge wclk or posedge wreset) begin
  if(wreset) begin
    for(i = 0; i< (1<<ADDR_SIZE); i = i + 1) begin
      mem[i]      <= {DATA_SIZE{1'b0}};
    end
  end else begin
    if(wclken & ~wfull) begin
      mem[waddr]  <= wdata;
    end
  end
end
  


 
endmodule



/**
  * Creates a 2-deep fifo for synchronizing multibit signals
  *
  * Literally stolen from http://www.sunburst-design.com/papers/CummingsSNUG2008Boston_CDC.pdf
  * I'm shameless
  */
module slink_multibit_sync #(
  parameter   DATA_SIZE = 8
)(
  input  wire                 wclk,
  input  wire                 wreset,
  input  wire                 winc,
  output wire                 wready,
  input  wire [DATA_SIZE-1:0] wdata,
  
  input  wire                 rclk,
  input  wire                 rreset,
  input  wire                 rinc,
  output wire                 rready,
  output wire [DATA_SIZE-1:0] rdata
);

reg [DATA_SIZE-1:0]   mem [2];

reg       wptr;
wire      wptr_in;
wire      we;
wire      rptr_wclk;

reg       rptr;
wire      rptr_in;
wire      wptr_rclk;


always @(posedge wclk or posedge wreset) begin
  if(wreset) begin
    wptr        <= 1'b0;
    mem[0]      <= {DATA_SIZE{1'b0}};
    mem[1]      <= {DATA_SIZE{1'b0}};
  end else begin
    wptr        <= wptr_in;
    if(we) begin
      mem[wptr] <= wdata;
    end
  end
end

slink_demet_reset u_slink_demet_rptr_wclk (
  .clk     ( wclk       ),  
  .reset   ( wreset     ),  
  .sig_in  ( rptr       ),  
  .sig_out ( rptr_wclk  )); 

assign wptr_in  = we ^ wptr;
assign wready   = ~(rptr_wclk ^ wptr);
assign we       = winc & wready;



always @(posedge rclk or posedge rreset) begin
  if(rreset) begin
    rptr    <= 1'b0;
  end else begin
    rptr    <= rptr_in;
  end
end


slink_demet_reset u_slink_demet_wptr_rclk (
  .clk     ( rclk       ),  
  .reset   ( rreset     ),  
  .sig_in  ( wptr       ),  
  .sig_out ( wptr_rclk  )); 

assign rready   = rptr ^ wptr_rclk;
assign rptr_in  = rptr ^ (rinc & rready);

assign rdata    = mem[rptr];

endmodule



module slink_dp_ram #(
   parameter DWIDTH = 32,              // Data width
   parameter SIZE   = 256,             // RAM size in DWIDTHs
   parameter AWIDTH = $clog2(SIZE)     // Address width
) (
   input  wire               clk_0,
   input  wire [AWIDTH-1:0]  addr_0,
   input  wire               en_0,
   input  wire               we_0,
   input  wire [DWIDTH-1:0]  wdata_0,
   output wire [DWIDTH-1:0]  rdata_0,

   input  wire               clk_1,
   input  wire [AWIDTH-1:0]  addr_1,
   input  wire               en_1,
   input  wire               we_1,
   input  wire [DWIDTH-1:0]  wdata_1,
   output wire [DWIDTH-1:0]  rdata_1
);

reg   [DWIDTH-1:0] mem [SIZE-1:0];
wire  write_0, read_0;
wire  write_1, read_1;
reg   [AWIDTH-1:0] addr_0_reg, addr_1_reg;

assign write_0 = en_0 &  we_0;
assign read_0  = en_0 & ~we_0;

integer i;
always @(posedge clk_0) begin
  if (write_0) begin
    mem[addr_0] <= wdata_0;
  end
end

always @(posedge clk_0) begin
  if (read_0) begin
    addr_0_reg <= addr_0;
  end
end

assign rdata_0 = read_0 ? mem[addr_0] : mem[addr_0_reg];

assign write_1 = en_1 &  we_1;
assign read_1  = en_1 & ~we_1;

integer j;
always @(posedge clk_1) begin
  if (write_1) begin
    mem[addr_1] <= wdata_1;
  end
end

always @(posedge clk_1) begin
  if (read_1) begin
    addr_1_reg <= addr_1;
  end
end

assign rdata_1 = read_1 ? mem[addr_1] : mem[addr_1_reg];
   
endmodule



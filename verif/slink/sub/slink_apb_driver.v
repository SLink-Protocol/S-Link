module slink_apb_driver #(
  parameter     ADDR_WIDTH  = 8,
  parameter     CLK_PER_NS  = 10
)(
  input  wire         apb_clk,
  input  wire         apb_reset,
  output reg  [7:0]   apb_paddr,
  output reg          apb_pwrite,
  output reg          apb_psel,
  output reg          apb_penable,
  output reg  [31:0]  apb_pwdata,
  input  wire [31:0]  apb_prdata,
  input  wire         apb_pready,
  input  wire         apb_pslverr
);

`include "slink_msg.v"

always @(posedge apb_reset) begin
  apb_paddr   <= 0;
  apb_pwrite  <= 0;
  apb_psel    <= 0;
  apb_penable <= 0;
  apb_pwdata  <= 0;
end


task write;
  input [ADDR_WIDTH-1:0] addr;
  input [31:0]           wdata;
  
  begin
    @(posedge apb_clk);
    apb_paddr     <= addr;
    apb_pwdata    <= wdata;
    apb_pwrite    <= 1;
    apb_psel      <= 1;
    @(posedge apb_clk);
    apb_penable   <= 1;
    @(posedge apb_clk);
    apb_psel      <= 0;
    apb_penable   <= 0;
    apb_pwrite    <= 0;
    
    //$display("REG_WRITE:  32'h%8h to       %4h", wdata, addr);
    //`sim_info($display("apb_write:  32'h%8h to       %4h", wdata, addr))
  end
endtask




task read(input bit[ADDR_WIDTH-1:0] addr, output bit[31:0] rdata);

  @(posedge apb_clk);
  apb_paddr     <= addr;
  apb_psel      <= 1;
  @(posedge apb_clk);
  apb_penable   <= 1;
  @(posedge apb_clk);
  apb_psel      <= 0;
  apb_penable   <= 0;
  rdata          = apb_prdata;    //ensure non-blocking

  //`sim_info($display("apb_read:   32'h%8h from     %4h", rdata, addr))
endtask

endmodule

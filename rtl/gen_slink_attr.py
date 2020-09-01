
import os
import sys
from collections import OrderedDict


sa_file = "slink_attributes.v"
doc_file = "../docs/source/slink_attributes.rst"

f     = open(sa_file,  "w")
rstf  = open(doc_file, "w")

#########################
def print_header(attrs):
  mod="""


module slink_attribute_base #(
  parameter ADDR      = 16'h0,
  parameter WIDTH     = 1,
  parameter RESET_VAL = {WIDTH{1'b0}},
  parameter NAME      = "unNamed",
  parameter IS_RO     = 0
)(
  input  wire             clk,
  input  wire             reset,
  
  input  wire             hard_reset_cond,
  
  input  wire [15:0]      link_attr_addr,
  input  wire [15:0]      link_attr_data,
  input  wire             link_shadow_update,        //Asserts to take the addr/data check
  
  input  wire [15:0]      app_attr_addr,
  input  wire [15:0]      app_attr_data,
  input  wire             app_shadow_update,
  
  input  wire [15:0]      sw_attr_addr,
  input  wire [15:0]      sw_attr_data,
  input  wire             sw_shadow_update,
  
  
  input  wire             effective_update,     //Asserts to update effective to shadow value
  
  output reg  [WIDTH-1:0] shadow_reg,
  output reg  [WIDTH-1:0] effective_reg
);

generate

  if(IS_RO==1) begin
    //"_int" variables just to keep iverilog warnings about no sensitivity list items
    wire [WIDTH-1:0] shadow_reg_int;
    wire [WIDTH-1:0] effective_reg_int;
    
    assign shadow_reg_int     = RESET_VAL;
    assign effective_reg_int  = RESET_VAL;
    
    always @(*) begin
      shadow_reg    = shadow_reg_int;
      effective_reg = effective_reg_int;
    end
  end else begin
    wire link_attr_update;
    wire app_attr_update;
    wire sw_attr_update;

    assign link_attr_update = link_shadow_update  && (link_attr_addr == ADDR);
    assign app_attr_update  = app_shadow_update   && (app_attr_addr  == ADDR);
    assign sw_attr_update   = sw_shadow_update    && (sw_attr_addr   == ADDR);

    always @(posedge clk or posedge reset) begin
      if(reset) begin
        effective_reg     <= RESET_VAL;
        shadow_reg        <= RESET_VAL;
      end else begin
        effective_reg     <= hard_reset_cond  ? RESET_VAL      : 
                             effective_update ? shadow_reg     : effective_reg;

        shadow_reg        <= hard_reset_cond  ? RESET_VAL      :
                             link_attr_update ? link_attr_data : 
                             app_attr_update  ? app_attr_data  :
                             sw_attr_update   ? sw_attr_data   : shadow_reg;

        `ifdef SIMULATION
          if(link_attr_update) begin
            $display("SLink Attribute Shadow Update (link): %s -> %4h", NAME, link_attr_data);
          end else if(app_attr_update) begin
            $display("SLink Attribute Shadow Update (app): %s -> %4h", NAME,  app_attr_data);
          end else if(sw_attr_update) begin
            $display("SLink Attribute Shadow Update (sw): %s -> %4h", NAME,   sw_attr_data);
          end
        `endif
      end
    end
  end
endgenerate


endmodule

module slink_attributes #(
  parameter NUM_TX_LANES_CLOG2 = 2,
  parameter NUM_RX_LANES_CLOG2 = 2
)(
  //Attributes
"""
  f.write(mod)
  
  for a in attrs:
    width = ""
    if attrs[a].width > 1:
      width = "[{}:0]".format(attrs[a].width - 1)
    #f.write("  output wire {0:7} {1}_shadow,\n".format(width, attrs[a][0]))
    f.write("  output wire {0:7} attr_{1},\n".format(width, attrs[a].name))

  mod="""
  
  input  wire         clk,
  input  wire         reset,
  input  wire         hard_reset_cond,
  input  wire [15:0]  link_attr_addr,
  input  wire [15:0]  link_attr_data,
  input  wire         link_shadow_update,
  output reg  [15:0]  link_attr_data_read,
  
  input  wire [15:0]  app_attr_addr,
  input  wire [15:0]  app_attr_data,
  input  wire         app_shadow_update,
  output reg  [15:0]  app_attr_data_read,
  
  input  wire [15:0]  sw_attr_addr,
  input  wire [15:0]  sw_attr_data,
  input  wire         sw_shadow_update,
  output reg  [15:0]  sw_attr_data_read,
  
  input  wire         effective_update
);
"""
  f.write(mod)


#########################
def print_attr_base(addr, name, reset, width, readonly):

  w_array = ""
  if width > 1:
    w_array = "[{}:0]".format(width-1)
  

  mod="""
  
wire {7} {4};
slink_attribute_base #(
  //parameters
  .ADDR                ( {0:24} ),
  .NAME                ( {1:24} ),
  .WIDTH               ( {2:24} ),
  .RESET_VAL           ( {3:24} ),
  .IS_RO               ( {8:24} )
) u_slink_attribute_base_{6} (
  .clk                 ( clk                      ),     
  .reset               ( reset                    ),  
  .hard_reset_cond     ( hard_reset_cond          ),
     
  .link_attr_addr      ( link_attr_addr           ),          
  .link_attr_data      ( link_attr_data           ),          
  .link_shadow_update  ( link_shadow_update       ),     
  
  .app_attr_addr       ( app_attr_addr            ),          
  .app_attr_data       ( app_attr_data            ),          
  .app_shadow_update   ( app_shadow_update        ),
  
  .sw_attr_addr        ( sw_attr_addr             ),          
  .sw_attr_data        ( sw_attr_data             ),          
  .sw_shadow_update    ( sw_shadow_update         ),
  
  .effective_update    ( effective_update         ),     
  .shadow_reg          ( {4:24} ),       
  .effective_reg       ( {5:24} )); 
""".format("'h"+str(format(addr, 'x')),
           '"'+name+'"',
           str(width), 
           str(reset), 
           name.lower()+"_shadow", 
           "attr_"+name.lower(), 
           name, 
           w_array,
           readonly)
  f.write(mod)
  

#########################
def print_read_data(typ, attrs):
  
  f.write("\n")
  f.write("always @(*) begin\n")
  f.write("  case({}_attr_addr)\n".format(typ))

  for a in attrs:
    tie = ""
    if attrs[a].width < 16:
      tie = "{}'d0, ".format(16-attrs[a].width)
    f.write("    16'h{0:4} : {3}_attr_data_read = {{{1}{2}}};\n".format(str(format(a, 'x')), tie, attrs[a].name.lower()+"_shadow", typ))

  f.write("    default  : {}_attr_data_read = 16'd0;\n".format(typ))
  f.write("  endcase\n")
  f.write("end\n")



#########################
def print_doc(attrs):
  """Returns a Markdown string to be used in Sphinx docs"""
  rstf.write("S-Link Attributes\n")
  rstf.write("-----------------\n")
  
  
  rstf.write(".. table::\n")
  rstf.write("  :widths: 10 30 10 10 20 50\n\n")
  
  addr_size   = len("Address ")
  name_size   = len("Name ")
  ro_size     = len("ReadOnly")
  width_size  = len("Width ")
  rst_size    = len("Reset ")
  desc_size   = len("Description ")
  
  
  for a in attrs:
    if(len(attrs[a].name)       > name_size):  name_size   = len(attrs[a].name)
    if(len(str(attrs[a].width)) > width_size): width_size  = len(str(attrs[a].width))
    if(len(str(attrs[a].reset)) > rst_size):   rst_size    = len(str(attrs[a].reset))
    if(len(attrs[a].desc)       > desc_size):  desc_size   = len(attrs[a].desc)
  
  rstf.write("  {0} {1} {2} {3} {4} {5}\n".format('='*addr_size, '='*name_size, '='*width_size, '='*ro_size, '='*rst_size, '='*desc_size))
  rstf.write("  %-*s %-*s %-*s %-*s %-*s %-*s\n" % (addr_size, "Address", name_size, "Name", width_size, "Width", ro_size, "ReadOnly",  rst_size, "Reset", desc_size, "Description"))
  rstf.write("  {0} {1} {2} {3} {4} {5}\n".format('='*addr_size, '='*name_size, '='*width_size, '='*ro_size, '='*rst_size, '='*desc_size))
  
  for a in attrs:
    rstf.write("  %-*s %-*s %-*s %-*s %-*s %-*s\n" % (addr_size, '0x'+str(format(a, 'x')), name_size, attrs[a].name, width_size, attrs[a].width, ro_size, str(attrs[a].ro), rst_size, attrs[a].reset, desc_size, attrs[a].desc))

  rstf.write("  {0} {1} {2} {3} {4} {5}\n".format('='*addr_size, '='*name_size, '='*width_size, '='*ro_size, '='*rst_size, '='*desc_size))
  

#########################
class SlinkAttr():

  def __init__(self, name, width, rst, ro=0, desc=""):
    self.name   = name
    self.width  = width
    self.reset  = rst
    self.desc   = desc
    self.ro     = ro



# Addr : [Name, Width, Default, Desc]

attr = OrderedDict()
attr = { 0x0  : SlinkAttr(name='max_txs',      width=3,  rst='NUM_TX_LANES_CLOG2', ro=1, desc='Maximum number of TX lanes this S-Link supports') ,
         0x1  : SlinkAttr(name='max_rxs',      width=3,  rst='NUM_RX_LANES_CLOG2', ro=1, desc='Maximum number of RX lanes this S-Link supports') ,
         0x2  : SlinkAttr(name='active_txs',   width=3,  rst='NUM_TX_LANES_CLOG2',       desc='Active TX lanes') ,
         0x3  : SlinkAttr(name='active_rxs',   width=3,  rst='NUM_RX_LANES_CLOG2',       desc='Active RX lanes') ,
         0x8  : SlinkAttr(name='hard_reset_us',width=10, rst=100,                        desc='Time (in us) at which a Hard Reset Condition is detected.') ,
         0x10 : SlinkAttr(name='px_clk_trail', width=8,  rst=32,                         desc='Number of clock cycles to run the bitclk when going to a P state that doesn\'t supply the bitclk') ,
         0x20 : SlinkAttr(name='p1_ts1_tx',    width=16, rst=32,                         desc='TS1s to send if exiting from P1'   ) ,
         0x21 : SlinkAttr(name='p1_ts1_rx',    width=16, rst=32,                         desc='TS1s to receive if exiting from P1') ,
         0x22 : SlinkAttr(name='p1_ts2_tx',    width=16, rst=4,                          desc='TS2s to send if exiting from P1'   ) ,
         0x23 : SlinkAttr(name='p1_ts2_rx',    width=16, rst=4,                          desc='TS2s to receive if exiting from P1') ,
         0x24 : SlinkAttr(name='p2_ts1_tx',    width=16, rst=64,                         desc='TS1s to send if exiting from P2'   ) ,
         0x25 : SlinkAttr(name='p2_ts1_rx',    width=16, rst=64,                         desc='TS1s to receive if exiting from P2') ,
         0x26 : SlinkAttr(name='p2_ts2_tx',    width=16, rst=8,                          desc='TS2s to send if exiting from P2'   ) ,
         0x27 : SlinkAttr(name='p2_ts2_rx',    width=16, rst=8,                          desc='TS2s to receive if exiting from P2') ,
         0x28 : SlinkAttr(name='p3r_ts1_tx',   width=16, rst=128,                        desc='TS1s to send if exiting from P3 or when coming out of reset'   ) ,
         0x29 : SlinkAttr(name='p3r_ts1_rx',   width=16, rst=128,                        desc='TS1s to receive if exiting from P3 or when coming out of reset') ,
         0x2a : SlinkAttr(name='p3r_ts2_tx',   width=16, rst=16,                         desc='TS2s to send if exiting from P3 or when coming out of reset'   ) ,
         0x2b : SlinkAttr(name='p3r_ts2_rx',   width=16, rst=16,                         desc='TS2s to receive if exiting from P3 or when coming out of reset') ,
         0x30 : SlinkAttr(name='sync_freq',    width=8,  rst=15,                         desc='How often SYNC Ordered Sets are sent during training') ,
       }

# Print it

print_header(attr)

for addr in attr:
  #print_attr_base(addr, attr[addr][0], attr[addr][2], attr[addr][1])
  print_attr_base(addr, attr[addr].name, attr[addr].reset, attr[addr].width, attr[addr].ro)
  
print_read_data("link", attr)
print_read_data("app",  attr)
print_read_data("sw",   attr)

f.write("endmodule")

print_doc(attr)
  

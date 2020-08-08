`timescale 1ns/1fs


/*
.rst_start
Testbench
================

The S-Link testbench allows testing of the S-Link controller with models for
the application layer, software stack, and SerDes. The testbench instantiates two S-Link
controllers, one as a Master and the other as a Slave. There are two driver/monitors and 
two SerDes models.

.. figure:: slink_tb_top_diagram.png
  :align:   center
  
  S-Link Testbench Diagram with SerDes Block Diagram

To be compatible with iverilog, the S-Link testbench is primarily Verilog based. Any
SystemVerilog constructs that are allowed by iverilog are used where applicable. Because
of this, there isn't as much class-based and constraint randomized testing as I would 
generally like. But that's ok. iverilog is still pretty damn neat and we can test quite
a bit with a few workarounds.

.. note ::

  If the project can obtain a license from Cadence/Mentor/Synopsys for thier simulators that
  support UVM, a UVM testenv will be created.
  
  I also looked into cocotb. Cocotb was really nice but I had a hard time figuring out
  how to deal with bitslicing which was really necessary for the way the application interface
  was designed. Supposedly cocotb 2.0 is to address these issues. I will keep an eye on this
  and cocotb would be a reasonable alternative to UVM if those issues are worked out. Or if
  you have a good way to deal with bitslicing in cocotb, please let me know.

simulate.sh
-----------
``simulate.sh`` is the main simulation script. It will compile the appropriate files using iverilog then run
them with vvp. There are several flags to use for running.

* ``-t <testname>`` - Selects which test to run. If not given, ``sanity_test`` is ran
* ``-c <args>`` - Compile time arguments
* ``-p <args>`` - Plusargs to send during simulation
* ``-l <logname)`` - Name of log to print. Defaults to ``vvp.log``
* ``-r`` - Regression flag. Not to be used during interactive sessions

Waveforms are currently saved in .vcd format and can be opened with GtkWave. The gtkwave read file ``waveform_signals.gtkw`` 
can be used to bring up a few signals. VCD filename is the standard ``dump.vcd`` iverilog uses.


Testbench Defines
-----------------
In order to test various configurations of S-Link, the ``simulate.sh`` script allows a user to
pass in some defines. Defines that can be set are listed below:

================================= ================================= ==================================================================
Define Name                       Acceptable Values                 Description
================================= ================================= ==================================================================
MAX_TX_LANES                      1/2/4                             Number of Master TX lanes and Slave RX lanes
MAX_RX_LANES                      1/2/4                             Number of Master RX lanes and Slave TX lanes
MST_PHY_DATA_WIDTH                8/16                              Phy interface width for Master
SLV_PHY_DATA_WIDTH                8/16                              Phy interface width for Slave
MST_TX_APP_DATA_WIDTH             (See doc for definition)          Application data width for Master TX
MST_RX_APP_DATA_WIDTH             (See doc for definition)          Application data width for Master RX
SLV_TX_APP_DATA_WIDTH             (See doc for definition)          Application data width for Slave TX
SLV_RX_APP_DATA_WIDTH             (See doc for definition)          Application data width for Slave RX
================================= ================================= ==================================================================

This would be an example of running the link_width_change test and indicating you want 4 lanes in each direction with a 64 bit
application data width for the TX and RX and a SEED value of 1234

::

  ./simulate.sh -t link_width_change -c "-DMAX_TX_LANES=4 -DMAX_RX_LANES=4 -DMST_TX_APP_DATA_WIDTH=64 \
    -DMST_RX_APP_DATA_WIDTH=64 -DSLV_TX_APP_DATA_WIDTH=64 -DSLV_RX_APP_DATA_WIDTH=64" -p "+SEED=1234"


SerDes Model
------------
The SerDes Model is a *very* generic SerDes that has 3 main subblocks:

* Clock - Drives or receives the bit clock based on ``IS_MASTER`` parameter
* TX - Creates the serial data from S-Link
* RX - Receives serial data from S-Link, and performs byte alignment.

Inside the RX there is also a ``delay_element`` which is used to skew the incomming RX data to exercise the deskew FIFO 
inside the S-Link controller.

This model is intended as a reference for SerDes that wish to operate with S-Link. The model handles the number of TX/RX pairs based
on the testbench configuration.

.. todo ::

  - Make the bitclk freq programmable.
  - Allow plusarg for RX deskew
  - Add 32 bit data width once controller supports.
  


.. include:: slink_app_driver.inc
.. include:: slink_app_monitor.inc
.. include:: slink_tests.inc


Regressions
-----------
Due to the various configurations of S-Link, there are many different simulations that need to be ran to exercise all
of the different possibilities. There is a small regression infrastructure set up where ``run_regression.py`` creates
tests based on different compile arguments listed above (number of lanes, phy/app data width, etc.). `Slurm <https://slurm.schedmd.com/documentation.html>`__
is used to assist with running mulitple jobs in parallel.

Currently with 1/2/4 lane, 8/16 phy data width support and testing with an application data width factor of 1x/2x/4x, there are 242 combinations for
S-Link! If you run just 5 different test for each combindation you have 1200+ tests! Due to this, regressions are really meant for checking
new changes and most users of S-Link shouldn't have to run them.

.rst_end
*/

`ifndef MAX_TX_LANES
  `define MAX_TX_LANES 4
`endif

`ifndef MAX_RX_LANES
  `define MAX_RX_LANES 4
`endif



`ifndef MST_PHY_DATA_WIDTH
  `define MST_PHY_DATA_WIDTH 8
`endif

`ifndef SLV_PHY_DATA_WIDTH
  `define SLV_PHY_DATA_WIDTH 8
`endif


`ifndef MST_TX_APP_DATA_WIDTH
  `define MST_TX_APP_DATA_WIDTH (`MAX_TX_LANES * `MST_PHY_DATA_WIDTH)
`endif
`ifndef MST_RX_APP_DATA_WIDTH
  `define MST_RX_APP_DATA_WIDTH (`MAX_RX_LANES * `MST_PHY_DATA_WIDTH)
`endif

`ifndef SLV_TX_APP_DATA_WIDTH
  `define SLV_TX_APP_DATA_WIDTH (`MAX_RX_LANES * `SLV_PHY_DATA_WIDTH)
`endif
`ifndef SLV_RX_APP_DATA_WIDTH
  `define SLV_RX_APP_DATA_WIDTH (`MAX_TX_LANES * `SLV_PHY_DATA_WIDTH)
`endif

module tb_top;

`include "slink_msg.v"

parameter MST_TX_APP_DATA_WIDTH   = `MST_TX_APP_DATA_WIDTH;
parameter MST_RX_APP_DATA_WIDTH   = `MST_RX_APP_DATA_WIDTH;
parameter SLV_TX_APP_DATA_WIDTH   = `SLV_TX_APP_DATA_WIDTH;
parameter SLV_RX_APP_DATA_WIDTH   = `SLV_RX_APP_DATA_WIDTH;
parameter NUM_TX_LANES            = `MAX_TX_LANES;
parameter NUM_RX_LANES            = `MAX_RX_LANES;
parameter MST_PHY_DATA_WIDTH      = `MST_PHY_DATA_WIDTH;
parameter SLV_PHY_DATA_WIDTH      = `SLV_PHY_DATA_WIDTH;

//App Data Width Check
initial begin
  if(MST_TX_APP_DATA_WIDTH < (NUM_TX_LANES * MST_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("MST_TX_APP_DATA_WIDTH is too small"))
  end
  if(MST_RX_APP_DATA_WIDTH < (NUM_RX_LANES * MST_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("MST_RX_APP_DATA_WIDTH is too small"))
  end
  
  if(SLV_TX_APP_DATA_WIDTH < (NUM_RX_LANES * SLV_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("SLV_TX_APP_DATA_WIDTH is too small"))
  end
  if(SLV_RX_APP_DATA_WIDTH < (NUM_TX_LANES * SLV_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("SLV_RX_APP_DATA_WIDTH is too small"))
  end
end

//-------------------------
// Clocks / Reset
//-------------------------
reg main_reset = 0;

reg apb_clk = 0;
reg refclk  = 0;
//reg phy_clk = 0;
wire [NUM_TX_LANES-1:0] mst_phy_clk;  //fix
wire [NUM_TX_LANES-1:0] slv_phy_clk;

always #5     apb_clk <= ~apb_clk;
always #13.02 refclk  <= ~refclk;


wire                                mst_link_clk;
wire                                mst_link_reset;

wire                                mst_tx_sop;
wire  [7:0]                         mst_tx_data_id;
wire  [15:0]                        mst_tx_word_count;
wire  [MST_TX_APP_DATA_WIDTH-1:0]   mst_tx_app_data;
wire                                mst_tx_valid;
wire                                mst_tx_advance;

wire                                mst_rx_sop;
wire  [7:0]                         mst_rx_data_id;
wire  [15:0]                        mst_rx_word_count;
wire  [MST_RX_APP_DATA_WIDTH-1:0]   mst_rx_app_data;
wire                                mst_rx_valid;
wire                                mst_rx_crc_corrupted;
wire                                mst_interrupt;

wire                                slv_link_clk;
wire                                slv_link_reset;

wire                                slv_tx_sop;
wire  [7:0]                         slv_tx_data_id;
wire  [15:0]                        slv_tx_word_count;
wire  [SLV_TX_APP_DATA_WIDTH-1:0]   slv_tx_app_data;
wire                                slv_tx_valid;
wire                                slv_tx_advance;

wire                                slv_rx_sop;
wire  [7:0]                         slv_rx_data_id;
wire  [15:0]                        slv_rx_word_count;
wire  [SLV_RX_APP_DATA_WIDTH-1:0]   slv_rx_app_data;
wire                                slv_rx_valid;
wire                                slv_rx_crc_corrupted;
wire                                slv_interrupt;


wire [NUM_TX_LANES-1:0]                       mst_phy_txclk;
wire                                          mst_phy_clk_en;
wire                                          mst_phy_clk_idle;
wire                                          mst_phy_clk_ready;
wire [NUM_TX_LANES-1:0]                       mst_phy_tx_en;
wire [NUM_TX_LANES-1:0]                       mst_phy_tx_ready;
wire [NUM_TX_LANES-1:0]                       mst_phy_tx_dirdy;
wire [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0]  mst_phy_tx_data;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_en;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_ready;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_valid;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_dordy;
wire [NUM_RX_LANES-1:0]                       mst_phy_rx_align;
wire [(NUM_RX_LANES*MST_PHY_DATA_WIDTH)-1:0]  mst_phy_rx_data;

wire [NUM_RX_LANES-1:0]                       slv_phy_txclk;
wire                                          slv_phy_clk_en;
wire                                          slv_phy_clk_idle;
wire                                          slv_phy_clk_ready;
wire [NUM_RX_LANES-1:0]                       slv_phy_tx_en;
wire [NUM_RX_LANES-1:0]                       slv_phy_tx_ready;
wire [NUM_RX_LANES-1:0]                       slv_phy_tx_dirdy;
wire [(NUM_RX_LANES*SLV_PHY_DATA_WIDTH)-1:0]  slv_phy_tx_data;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_en;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_ready;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_valid;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_dordy;
wire [NUM_TX_LANES-1:0]                       slv_phy_rx_align;
wire [(NUM_TX_LANES*SLV_PHY_DATA_WIDTH)-1:0]  slv_phy_rx_data;


bit pkt_type = 0;




`include "slink_tests.vh"

initial begin  
  #1ps;
  main_reset = 1;
  #30ns;
  
  main_reset = 0;
  
  #20ns;  
  slink_test_select;
  
  $finish();
end


wire [7:0]            apb_paddr;
wire                  apb_pwrite;
wire                  apb_psel;
wire                  apb_penable;
wire [31:0]           apb_pwdata;
wire [31:0]           apb_prdata;
wire                  apb_pready;
wire                  apb_pslverr;

wire [7:0]            slv_apb_paddr;
wire                  slv_apb_pwrite;
wire                  slv_apb_psel;
wire                  slv_apb_penable;
wire [31:0]           slv_apb_pwdata;
wire [31:0]           slv_apb_prdata;
wire                  slv_apb_pready;
wire                  slv_apb_pslverr;

wire mst_slink_gpio_reset_n_oen;
wire mst_slink_gpio_reset_n   ;
wire mst_slink_gpio_wake_n_oen;
wire mst_slink_gpio_wake_n    ;
wire slv_slink_gpio_reset_n_oen;
wire slv_slink_gpio_reset_n   ;
wire slv_slink_gpio_wake_n_oen;
wire slv_slink_gpio_wake_n    ;


slink_app_driver #(
  //parameters
  .DRIVER_APP_DATA_WIDTH    ( MST_TX_APP_DATA_WIDTH  ),
  .MONITOR_APP_DATA_WIDTH   ( SLV_RX_APP_DATA_WIDTH  )
) driver_m2s (
  .link_clk          ( mst_link_clk           ),  
  .link_reset        ( mst_link_reset         ),  
  .tx_sop            ( mst_tx_sop             ),  
  .tx_data_id        ( mst_tx_data_id         ),  
  .tx_word_count     ( mst_tx_word_count      ),  
  .tx_app_data       ( mst_tx_app_data        ),               
  .tx_valid          ( mst_tx_valid           ),  
  .tx_advance        ( mst_tx_advance         ),
  
  
  .rx_link_clk       ( slv_link_clk           ),  
  .rx_link_reset     ( slv_link_reset         ),
  .rx_sop            ( slv_rx_sop             ),  
  .rx_data_id        ( slv_rx_data_id         ),  
  .rx_word_count     ( slv_rx_word_count      ),  
  .rx_app_data       ( slv_rx_app_data        ),             
  .rx_valid          ( slv_rx_valid           ),
  .rx_crc_corrupted  ( slv_rx_crc_corrupted   ),
  
  .interrupt         ( mst_interrupt          ),
  
  .apb_clk           ( apb_clk                ), 
  .apb_reset         ( main_reset             ), 
  .apb_paddr         ( apb_paddr              ), 
  .apb_pwrite        ( apb_pwrite             ), 
  .apb_psel          ( apb_psel               ), 
  .apb_penable       ( apb_penable            ), 
  .apb_pwdata        ( apb_pwdata             ), 
  .apb_prdata        ( apb_prdata             ), 
  .apb_pready        ( apb_pready             ), 
  .apb_pslverr       ( apb_pslverr            ));


slink_app_driver #(
  //parameters
  .DRIVER_APP_DATA_WIDTH    ( SLV_TX_APP_DATA_WIDTH  ),
  .MONITOR_APP_DATA_WIDTH   ( MST_RX_APP_DATA_WIDTH  )
) driver_s2m (
  .link_clk          ( slv_link_clk           ),  
  .link_reset        ( slv_link_reset         ),  
  .tx_sop            ( slv_tx_sop             ),  
  .tx_data_id        ( slv_tx_data_id         ),  
  .tx_word_count     ( slv_tx_word_count      ),  
  .tx_app_data       ( slv_tx_app_data        ),               
  .tx_valid          ( slv_tx_valid           ),  
  .tx_advance        ( slv_tx_advance         ),
  
  .rx_link_clk       ( mst_link_clk           ),  
  .rx_link_reset     ( mst_link_reset         ),
  .rx_sop            ( mst_rx_sop             ),  
  .rx_data_id        ( mst_rx_data_id         ),  
  .rx_word_count     ( mst_rx_word_count      ),  
  .rx_app_data       ( mst_rx_app_data        ),             
  .rx_valid          ( mst_rx_valid           ),
  .rx_crc_corrupted  ( mst_rx_crc_corrupted   ),
  
  .interrupt         ( slv_interrupt          ),
  
  .apb_clk           ( apb_clk                ), 
  .apb_reset         ( main_reset             ), 
  .apb_paddr         ( slv_apb_paddr          ), 
  .apb_pwrite        ( slv_apb_pwrite         ), 
  .apb_psel          ( slv_apb_psel           ), 
  .apb_penable       ( slv_apb_penable        ), 
  .apb_pwdata        ( slv_apb_pwdata         ), 
  .apb_prdata        ( slv_apb_prdata         ), 
  .apb_pready        ( slv_apb_pready         ), 
  .apb_pslverr       ( slv_apb_pslverr        ));


slink #(
  //parameters
  .NUM_TX_LANES       ( NUM_TX_LANES          ),
  .NUM_RX_LANES       ( NUM_RX_LANES          ),
  .TX_APP_DATA_WIDTH  ( MST_TX_APP_DATA_WIDTH ),
  .RX_APP_DATA_WIDTH  ( MST_RX_APP_DATA_WIDTH ),
  .PHY_DATA_WIDTH     ( MST_PHY_DATA_WIDTH    ),
  .DESKEW_FIFO_DEPTH  ( 4         )
) u_slink_MASTER (
  .core_scan_mode              ( 1'b0                         ),  
  .core_scan_clk               ( 1'b0                         ),  
  .core_scan_asyncrst_ctrl     ( 1'b0                         ),  
  .apb_clk                     ( apb_clk                      ),  
  .apb_reset                   ( main_reset                   ),  
  .apb_paddr                   ( apb_paddr                    ),   
  .apb_pwrite                  ( apb_pwrite                   ),  
  .apb_psel                    ( apb_psel                     ),  
  .apb_penable                 ( apb_penable                  ),  
  .apb_pwdata                  ( apb_pwdata                   ),   
  .apb_prdata                  ( apb_prdata                   ),   
  .apb_pready                  ( apb_pready                   ),  
  .apb_pslverr                 ( apb_pslverr                  ),  
  .link_clk                    ( mst_link_clk                 ),  
  .link_reset                  ( mst_link_reset               ),  
  
  .app_attr_addr               ( 16'd0 ),
  .app_attr_data               ( 16'd0 ),
  .app_shadow_update           ( 1'b0  ),
  .app_attr_data_read          (       ),
               
  .tx_sop                      ( mst_tx_sop                   ),  
  .tx_data_id                  ( mst_tx_data_id               ),  
  .tx_word_count               ( mst_tx_word_count            ),  
  .tx_app_data                 ( mst_tx_app_data              ),   
  .tx_advance                  ( mst_tx_advance               ),  
  .rx_sop                      ( mst_rx_sop                   ),  
  .rx_data_id                  ( mst_rx_data_id               ),  
  .rx_word_count               ( mst_rx_word_count            ),  
  .rx_app_data                 ( mst_rx_app_data              ),   
  .rx_valid                    ( mst_rx_valid                 ),  
  .rx_crc_corrupted            ( mst_rx_crc_corrupted         ),
  .interrupt                   ( mst_interrupt                ),
  
  .p1_req                      ( 1'b0 ),
  .p2_req                      ( 1'b0 ),
  .p3_req                      ( 1'b0 ),
  
  .slink_gpio_reset_n_oen      ( mst_slink_gpio_reset_n_oen   ),
  .slink_gpio_reset_n          ( mst_slink_gpio_reset_n       ),
  .slink_gpio_wake_n_oen       ( mst_slink_gpio_wake_n_oen    ),
  .slink_gpio_wake_n           ( mst_slink_gpio_wake_n        ),
  
  .refclk                      ( refclk                       ),            
  .phy_clk                     ( mst_phy_txclk[0]             ),            
  .phy_clk_en                  ( mst_phy_clk_en               ),  
  .phy_clk_idle                ( mst_phy_clk_idle             ),
  .phy_clk_ready               ( mst_phy_clk_ready            ),  
  .phy_tx_en                   ( mst_phy_tx_en                ),  
  .phy_tx_ready                ( mst_phy_tx_ready             ),  
  .phy_tx_dirdy                ( mst_phy_tx_dirdy             ),
  .phy_tx_data                 ( mst_phy_tx_data              ),   
  .phy_rx_en                   ( mst_phy_rx_en                ),  
  .phy_rx_ready                ( mst_phy_rx_ready             ),  
  .phy_rx_valid                ( mst_phy_rx_valid             ), 
  .phy_rx_dordy                ( mst_phy_rx_dordy             ), 
  .phy_rx_align                ( mst_phy_rx_align             ),  
  .phy_rx_data                 ( mst_phy_rx_data              ));  



slink #(
  //parameters
  .NUM_TX_LANES       ( NUM_RX_LANES          ),
  .NUM_RX_LANES       ( NUM_TX_LANES          ),
  .TX_APP_DATA_WIDTH  ( SLV_TX_APP_DATA_WIDTH ),
  .RX_APP_DATA_WIDTH  ( SLV_RX_APP_DATA_WIDTH ),
  .PHY_DATA_WIDTH     ( SLV_PHY_DATA_WIDTH    ),
  .DESKEW_FIFO_DEPTH  ( 4         )
) u_slink_SLAVE (
  .core_scan_mode              ( 1'b0                         ),  
  .core_scan_clk               ( 1'b0                         ),  
  .core_scan_asyncrst_ctrl     ( 1'b0                         ),  
  //.main_reset                  ( main_reset                   ),  
  .apb_clk                     ( apb_clk                      ),  
  .apb_reset                   ( main_reset                   ),  
  .apb_paddr                   ( slv_apb_paddr                ),   
  .apb_pwrite                  ( slv_apb_pwrite               ),  
  .apb_psel                    ( slv_apb_psel                 ),  
  .apb_penable                 ( slv_apb_penable              ),  
  .apb_pwdata                  ( slv_apb_pwdata               ),    
  .apb_prdata                  ( slv_apb_prdata               ),    
  .apb_pready                  ( slv_apb_pready               ),  
  .apb_pslverr                 ( slv_apb_pslverr              ),  
  .link_clk                    ( slv_link_clk                 ),  
  .link_reset                  ( slv_link_reset               ),  
  
  .app_attr_addr               ( 16'd0 ),
  .app_attr_data               ( 16'd0 ),
  .app_shadow_update           ( 1'b0  ),
  .app_attr_data_read          (       ),        
  
  .tx_sop                      ( slv_tx_sop                   ),  
  .tx_data_id                  ( slv_tx_data_id               ),  
  .tx_word_count               ( slv_tx_word_count            ),  
  .tx_app_data                 ( slv_tx_app_data              ),    
  .tx_advance                  ( slv_tx_advance               ),  
  .rx_sop                      ( slv_rx_sop                   ),  
  .rx_data_id                  ( slv_rx_data_id               ),  
  .rx_word_count               ( slv_rx_word_count            ),  
  .rx_app_data                 ( slv_rx_app_data              ),      
  .rx_valid                    ( slv_rx_valid                 ),  
  .rx_crc_corrupted            ( slv_rx_crc_corrupted         ),
  .interrupt                   ( slv_interrupt                ),
  
  .p1_req                      ( 1'b0 ),
  .p2_req                      ( 1'b0 ),
  .p3_req                      ( 1'b0 ),
  
  .slink_gpio_reset_n_oen      ( slv_slink_gpio_reset_n_oen   ),
  .slink_gpio_reset_n          ( slv_slink_gpio_reset_n       ),
  .slink_gpio_wake_n_oen       ( slv_slink_gpio_wake_n_oen    ),
  .slink_gpio_wake_n           ( slv_slink_gpio_wake_n        ),
  
  .refclk                      ( refclk                       ),             
  .phy_clk                     ( slv_phy_txclk[0]             ),            
  .phy_clk_en                  ( slv_phy_clk_en               ),  
  .phy_clk_idle                ( slv_phy_clk_idle             ),
  .phy_clk_ready               ( slv_phy_clk_ready            ),  
  .phy_tx_en                   ( slv_phy_tx_en                ),  
  .phy_tx_ready                ( slv_phy_tx_ready             ),  
  .phy_tx_dirdy                ( slv_phy_tx_dirdy             ),
  .phy_tx_data                 ( slv_phy_tx_data              ),   
  .phy_rx_en                   ( slv_phy_rx_en                ),  
  .phy_rx_ready                ( slv_phy_rx_ready             ),  
  .phy_rx_valid                ( slv_phy_rx_valid             ), 
  .phy_rx_dordy                ( slv_phy_rx_dordy             ), 
  .phy_rx_align                ( slv_phy_rx_align             ),  
  .phy_rx_data                 ( slv_phy_rx_data              ));     


// Sideband signals
wire slink_reset_n_io;
wire slink_wake_n_io;
wire bla;

slink_gpio_model u_slink_gpio_model_MASTER[1:0] (
  .oen     ( {mst_slink_gpio_reset_n_oen,
              mst_slink_gpio_wake_n_oen}  ),      
  .sig_in  ( {mst_slink_gpio_reset_n,
              mst_slink_gpio_wake_n}      ),      
  .pad     ( {slink_reset_n_io,
              slink_wake_n_io}            )); 


slink_gpio_model u_slink_gpio_model_SLAVE[1:0] (
  .oen     ( {slv_slink_gpio_reset_n_oen,
              slv_slink_gpio_wake_n_oen}  ),      
  .sig_in  ( {slv_slink_gpio_reset_n,
              slv_slink_gpio_wake_n}      ),      
  .pad     ( {slink_reset_n_io,
              slink_wake_n_io}            )); 


initial begin
  if($test$plusargs("NO_WAVES")) begin
    `sim_info($display("No waveform saving this sim"))
  end else begin
    $dumpvars(0);
  end
  #1ms;
  `sim_fatal($display("sim timeout"));
  $finish();
end



wire [NUM_TX_LANES-1:0] txp, txn;
wire [NUM_RX_LANES-1:0] rxp, rxn;
wire                    clk_bitclk;

serdes_phy_model #(
  //parameters
  .IS_MASTER          ( 1                 ),
  .MAX_DELAY_CYC      ( 16                ),
  .DATA_WIDTH         ( MST_PHY_DATA_WIDTH),
  .NUM_TX_LANES       ( NUM_TX_LANES      ),
  .NUM_RX_LANES       ( NUM_RX_LANES      )
) u_serdes_phy_model_MASTER (
  .clk_enable    ( mst_phy_clk_en               ),  
  .clk_idle      ( mst_phy_clk_idle             ),  
  .clk_ready     ( mst_phy_clk_ready            ),  
  .clk_bitclk    ( clk_bitclk                   ),
  .tx_enable     ( mst_phy_tx_en                ),  
  .txclk         ( mst_phy_txclk                ),  
  .tx_data       ( mst_phy_tx_data              ),  
  .tx_reset      ( {NUM_TX_LANES{main_reset}}   ),  
  .tx_dirdy      ( mst_phy_tx_dirdy             ),  
  .tx_ready      ( mst_phy_tx_ready             ),  
  .rx_enable     ( mst_phy_rx_en                ),  
  .rxclk         (                              ),  
  .rx_align      ( mst_phy_rx_align             ),  
  .rx_data       ( mst_phy_rx_data              ),  
  .rx_reset      ( {NUM_RX_LANES{main_reset}}   ),  
  .rx_locked     (                              ),  
  .rx_valid      ( mst_phy_rx_valid             ),  
  .rx_dordy      ( mst_phy_rx_dordy             ),
  .rx_ready      ( mst_phy_rx_ready             ),
  .txp           ( txp                          ),  
  .txn           ( txn                          ),  
  .rxp           ( rxp                          ),  
  .rxn           ( rxn                          )); 

serdes_phy_model #(
  //parameters
  .IS_MASTER          ( 0                 ),
  .MAX_DELAY_CYC      ( 16                ),
  .DATA_WIDTH         ( SLV_PHY_DATA_WIDTH),
  .NUM_TX_LANES       ( NUM_RX_LANES      ),
  .NUM_RX_LANES       ( NUM_TX_LANES      )
) u_serdes_phy_model_SLAVE (
  .clk_enable    ( slv_phy_clk_en               ),  
  .clk_idle      ( slv_phy_clk_idle             ),  
  .clk_ready     ( slv_phy_clk_ready            ),  
  .clk_bitclk    ( clk_bitclk                   ),
  .tx_enable     ( slv_phy_tx_en                ),  
  .txclk         ( slv_phy_txclk                ),  
  .tx_data       ( slv_phy_tx_data              ),  
  .tx_reset      ( {NUM_RX_LANES{main_reset}}   ),  
  .tx_dirdy      ( slv_phy_tx_dirdy             ),  
  .tx_ready      ( slv_phy_tx_ready             ),  
  .rx_enable     ( slv_phy_rx_en                ),  
  .rxclk         (                              ),  
  .rx_align      ( slv_phy_rx_align             ),  
  .rx_data       ( slv_phy_rx_data              ),  
  .rx_reset      ( {NUM_TX_LANES{main_reset}}   ),  
  .rx_locked     (                              ),  
  .rx_valid      ( slv_phy_rx_valid             ),  
  .rx_dordy      ( slv_phy_rx_dordy             ),
  .rx_ready      ( slv_phy_rx_ready             ),
  .txp           ( rxp                          ),  
  .txn           ( rxn                          ),  
  .rxp           ( txp                          ),  
  .rxn           ( txn                          )); 


endmodule

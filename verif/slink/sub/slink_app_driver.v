/*
.rst_start
slink_app_driver
----------------
The S-Link App Driver is used to generate packets and holds software tasks. S-Link tests are
generally made up of calls to slink_app_driver tasks. The slink_app_driver also instantiates
the slink_app_monitor to allow for sending packet information (this is due to verilog
constraints, this will change if we can move to a traditional SV/UVM test env).

The ``tx_*`` signals should be connected to the S-Link that you wish to **drive** and
the ``rx_*`` signals should be connected to the S-Link that the packet should be received on.
So if if S-Link A is driving S-Link B, you would want to connects A's TX and B's RX to this
driver.

.rst_end
*/

module slink_app_driver #(
  parameter DRIVER_APP_DATA_WIDTH   = 32,
  parameter MONITOR_APP_DATA_WIDTH  = 32
) (
  input  wire                        link_clk,
  input  wire                        link_reset,
  
  output reg                         tx_sop,
  output reg  [7:0]                  tx_data_id,
  output reg  [15:0]                 tx_word_count,
  output reg  [DRIVER_APP_DATA_WIDTH-1:0]   tx_app_data,
  output reg                         tx_valid,
  input  wire                        tx_advance,
  
  
  input  wire                        rx_link_clk,
  input  wire                        rx_link_reset,
  input  wire                        rx_sop,
  input  wire [7:0]                  rx_data_id,
  input  wire [15:0]                 rx_word_count,
  input  wire [MONITOR_APP_DATA_WIDTH-1:0]   rx_app_data,
  input  wire                        rx_valid,
  input  wire                        rx_crc_corrupted,
  input  wire                        interrupt,
  
  input  wire                        apb_clk,
  input  wire                        apb_reset,
  output wire [7:0]                  apb_paddr,
  output wire                        apb_pwrite,
  output wire                        apb_psel,
  output wire                        apb_penable,
  output wire [31:0]                 apb_pwdata,
  input  wire [31:0]                 apb_prdata,
  input  wire                        apb_pready,
  input  wire                        apb_pslverr

);

`include "slink_msg.v"
`include "slink_ctrl_addr_defines.vh"
`include "slink_includes.vh"


bit ignore_crc_corrupt_errors = 0;
bit ignore_ecc_correct_errors = 0;
bit ignore_ecc_corrupt_errors = 0;


slink_app_monitor #(
  //parameters
  .APP_DATA_WIDTH     ( MONITOR_APP_DATA_WIDTH )
) monitor (
  .link_clk          ( rx_link_clk        ),  
  .link_reset        ( rx_link_reset      ),  
  .rx_sop            ( rx_sop             ),  
  .rx_data_id        ( rx_data_id         ),  
  .rx_word_count     ( rx_word_count      ),  
  .rx_app_data       ( rx_app_data        ),  
  .rx_valid          ( rx_valid           ),
  .rx_crc_corrupted  ( rx_crc_corrupted   )); 


initial begin
  tx_sop          <= 0;
  tx_data_id      <= 0;
  tx_word_count   <= 0;
  tx_app_data     <= 0;
end


initial begin
  //Monitor Fork
  fork
    monitorInterrupt;
  join_none
end


/*
.rst_start
sendRandomShortPacket
+++++++++++++++++++++
Sends a short packet with a random dataid and payload
.rst_end
*/
task sendRandomShortPacket;
  bit [ 7: 0] di;
  bit [15: 0] wc;
  
  di = 'ha + {$urandom} % ('h1f - 'ha);
  wc = $urandom;
  sendShortPacket(di, wc);
endtask


/*
.rst_start
sendRandomLongPacket
+++++++++++++++++++++
* ``input bit random_data`` - 1: Random data is send for each byte 0: byte data is a counter

Sends a long packet with a random dataid and payload
.rst_end
*/
task sendRandomLongPacket(input bit random_data=1);
  bit [ 7: 0] di;
  bit [15: 0] wc;
  
  di = 'h20 + {$urandom} % ('h3f - 'h20);
  wc = 1 + {$urandom} % (1024 - 1);      //NEED TO FIX THE 0 BYTE PAYLOAD
  //wc = 1 + {$urandom} % (20 - 1);      //NEED TO FIX THE 0 BYTE PAYLOAD
  sendLongPacket(di, wc, random_data);
endtask

/*
.rst_start
sendShortPacket
+++++++++++++++

* ``input bit[7:0] dataid`` - Data ID for this packet
* ``input bit[15:0] wc`` - Word Count/Payload for this packet

SendShortPacket will handle the sending of the desired short packet on the S-Link 
interface. If a data ID of >= 0x20 is attempted, it will error. The dataid, and payload
are send to the monitor for checking reception.

.rst_end
*/
task sendShortPacket(input bit[7:0] dataid, input bit[15:0] wc);
  bit tx_ad;
  
  `sim_info($display("Starting Short Packet Send with DI: %2h and WC: %4h", dataid, wc))
  
  if(dataid >= 'h20) begin
    `sim_error($display("DATA ID should be 0x0 <-> 0x1F. Not sending this packet"))
  end else begin
  
    @(posedge link_clk);
    tx_sop        <= 1;
    tx_data_id    <= dataid;
    tx_word_count <= wc;
    tx_app_data   <= 0;

    tx_ad         <= 0;
    do begin
      @(posedge link_clk);
      tx_ad       <= tx_advance;
      if(tx_advance) begin
        tx_sop     <= 0;
      end
    end while(~tx_ad);
    
    monitor.addByte(dataid   );
    monitor.addByte(wc[7 : 0]);
    monitor.addByte(wc[15: 8]);
    
  end
  
endtask

/*
.rst_start
sendLongPacket
++++++++++++++

* ``input bit[7:0] dataid`` - Data ID for this packet
* ``input bit[15:0] wc`` - Word Count for this packet
* ``input bit random_data`` - 1: Random data is send for each byte 0: byte data is a counter

sendLongPacket will handle the sending of the desired long packet on the S-Link 
interface. If a data ID of < 0x20 is attempted, it will error. The dataid, wc, and payload
are send to the monitor for checking reception.

Payload data is created based on the word count. The user can send random data for each byte by 
setting ``random_data=1``. If ``random_data==0``, each byte sent will be essentially a count value 
going from 0->255, rolling over back to 0. This can be useful for debugging.

.rst_end
*/
task sendLongPacket(input bit [7:0] dataid, input bit [15:0] wc, input bit random_data=0);
  bit tx_ad;
  bit [7:0] payload[$];
  int       curr_byte;
  
  curr_byte = 0;
  payload.delete();
  
  for(int i = 0; i < wc; i++) begin
    payload.push_back(random_data ? $urandom : i % 256);
  end
  
  
  `sim_info($display("Starting Long Packet Send with DI: %2h and WC: %4h", dataid, wc))
  
  if(dataid < 'h20) begin
    `sim_error($display("DATA ID should be > 0x1F. Not sending this packet"))
  end else begin
  
    //push to monitor for check
    monitor.addByte(dataid   );
    monitor.addByte(wc[7 : 0]);
    monitor.addByte(wc[15: 8]);
    if(wc) begin
      foreach(payload[i]) begin
        monitor.addByte(payload[i]);
      end
    end
  
    @(posedge link_clk);
    #1ps; //NOT SURE WHY I NEED THIS NOW?
    tx_sop        <= 1;
    tx_data_id    <= dataid;
    tx_word_count <= wc;
    
    `sim_debug($display("about to send the following payload with sop:"))
    for(int i = 0; i < DRIVER_APP_DATA_WIDTH/8; i++) begin
      if(((curr_byte + i) < wc) && (wc != 0)) begin
        `sim_debug($display("payload %0d : %2h", curr_byte + i, payload[curr_byte + i]))
        tx_app_data[i*8 +: 8] <= payload[curr_byte + i];
      end else begin
        tx_app_data[i*8 +: 8] <= 0;
      end
    end
    curr_byte += DRIVER_APP_DATA_WIDTH/8;

    while(~tx_advance) begin
      @(posedge link_clk);
    end
    tx_sop    <= 0;
    
    while(curr_byte < wc) begin
      
      `sim_debug($display("about to send the following payload:"))      
      for(int i = 0; i < DRIVER_APP_DATA_WIDTH/8; i++) begin
        if(((curr_byte + i) < wc) && (wc != 0)) begin
          `sim_debug($display("payload %0d : %2h", curr_byte + i, payload[curr_byte + i]))
          tx_app_data[i*8 +: 8] <= payload[curr_byte + i];
        end else begin
          tx_app_data[i*8 +: 8] <= 0;
        end
      end
      curr_byte += DRIVER_APP_DATA_WIDTH/8;
      
      
      @(posedge link_clk);  //
      while(~tx_advance) begin
        @(posedge link_clk);
        `sim_debug($display("waiting posedge long data"))
      end
      `sim_debug($display("have now sent %0d bytes", curr_byte))
    
    end //while(curr_byte)
    
     
    curr_byte = 0;
  end
endtask



task finalCheck;
  
  if(sim_errors) begin
    `sim_error($display("%0d errors seen", sim_errors))
  end
endtask


task monitorInterrupt;
  bit [31:0] val;
  
  forever begin
    @(posedge interrupt);
    `sim_info($display("interrupt seen"))
    apb.read(`SLINK_CTRL_INTERRUPT_STATUS, val);
    
    if(val[`SLINK_CTRL_INTERRUPT_STATUS__ECC_CORRUPTED]) begin
      `sim_error($display("ECC Corruption interrupt seen!"))
    end
    
    if(val[`SLINK_CTRL_INTERRUPT_STATUS__ECC_CORRECTED]) begin
      `sim_error($display("ECC Corrected interrupt seen!"))
    end
    
    if(val[`SLINK_CTRL_INTERRUPT_STATUS__CRC_CORRUPTED]) begin
      `sim_error($display("CRC Corrupted interrupt seen!"))
    end
    
    if(val[`SLINK_CTRL_INTERRUPT_STATUS__AUX_RX_FIFO_WRITE_FULL]) begin
      `sim_error($display("Aux RX FIFO Write FULL interrupt seen!"))
    end
    
  end
endtask


/**********************************************************************************
  ___  __      __    ___                      _     _                   
 / __| \ \    / /   | __|  _  _   _ _    __  | |_  (_)  ___   _ _    ___
 \__ \  \ \/\/ /    | _|  | || | | ' \  / _| |  _| | | / _ \ | ' \  (_-<
 |___/   \_/\_/     |_|    \_,_| |_||_| \__|  \__| |_| \___/ |_||_| /__/
                                                                       
**********************************************************************************/

slink_apb_driver apb (
  .apb_clk     ( apb_clk      ), 
  .apb_reset   ( apb_reset    ), 
  .apb_paddr   ( apb_paddr    ), 
  .apb_pwrite  ( apb_pwrite   ), 
  .apb_psel    ( apb_psel     ), 
  .apb_penable ( apb_penable  ), 
  .apb_pwdata  ( apb_pwdata   ), 
  .apb_prdata  ( apb_prdata   ), 
  .apb_pready  ( apb_pready   ), 
  .apb_pslverr ( apb_pslverr  ));



task clr_swreset;
  apb.write(`SLINK_CTRL_SWRESET, 0);
endtask

task en_slink;
  apb.write(`SLINK_CTRL_ENABLE, 1);
endtask

//-----------------------------
// Attributes
//-----------------------------


task write_link_sw_fifo(input bit[7:0]  id, input bit[15:0] data);
  bit[31:0] val;
  
  val[`SLINK_CTRL_AUX_LINK_TX_SHORT_PACKET__AUX_LINK_TX_WFULL] = 1;
  
  do begin
    apb.read(`SLINK_CTRL_AUX_LINK_TX_SHORT_PACKET, val);
  end while(val[`SLINK_CTRL_AUX_LINK_TX_SHORT_PACKET__AUX_LINK_TX_WFULL]);
  
  val[`SLINK_CTRL_AUX_LINK_TX_SHORT_PACKET__AUX_LINK_TX_SHORT_PACKET] = {data, id};
  
  apb.write(`SLINK_CTRL_AUX_LINK_TX_SHORT_PACKET, val);
  
endtask


task write_far_end_attr(input bit[15:0] addr, input bit[15:0] data);
  bit[31:0] val;
  
  `sim_info($display("Writing Attribute: %4h with value %4h", addr, data))
  
  write_link_sw_fifo(ATTR_ADDR, addr);
  write_link_sw_fifo(ATTR_DATA, data);
  
endtask


task read_aux_fifo(output bit[23:0] rdata);
  bit[31:0] val;
  
  val[`SLINK_CTRL_AUX_LINK_RX_SHORT_PACKET_STATUS__AUX_LINK_RX_REMPTY] = 1;
    
  do begin
    apb.read(`SLINK_CTRL_AUX_LINK_RX_SHORT_PACKET_STATUS, val);
  end while(val[`SLINK_CTRL_AUX_LINK_RX_SHORT_PACKET_STATUS__AUX_LINK_RX_REMPTY]);
  
  apb.read(`SLINK_CTRL_AUX_LINK_RX_SHORT_PACKET, val);
  rdata = val[`SLINK_CTRL_AUX_LINK_RX_SHORT_PACKET__AUX_LINK_RX_SHORT_PACKET];
  
  `sim_info($display("Read back Aux FIFO %6h", rdata))
  
endtask

task read_far_end_attr(input bit[15:0] addr, output bit[15:0] data);
  bit[31:0] val;
  
  write_link_sw_fifo(ATTR_REQ, addr);
  read_aux_fifo(val);
  data = val[23:8];

endtask

task write_local_attr(input bit[15:0] attr, input bit[15:0] data);
  bit[31:0] val;
  
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_ADDR] = attr;
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_DATA] = data;
  
  apb.write(`SLINK_CTRL_SW_ATTR_ADDR_DATA, val);
  
  val = 0;
  val[`SLINK_CTRL_SW_ATTR_SHADOW_UPDATE__SW_ATTR_SHADOW_UPDATE] = 1'b1;
  
  apb.write(`SLINK_CTRL_SW_ATTR_SHADOW_UPDATE, val);
  
  #100ns;
  
endtask

task update_local_effective;
  bit[31:0] val;
  
  val[`SLINK_CTRL_SW_ATTR_EFFECTIVE_UPDATE__SW_ATTR_EFFECTIVE_UPDATE] = 1'b1;
  apb.write(`SLINK_CTRL_SW_ATTR_EFFECTIVE_UPDATE, val);
endtask


task read_local_attr(input bit[15:0] attr, output bit[15:0] data);
  bit [31:0] val;
  
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_ADDR] = attr;
  apb.write(`SLINK_CTRL_SW_ATTR_ADDR_DATA, val);
  apb.read (`SLINK_CTRL_SW_ATTR_DATA_READ, val);
  
  data = val[`SLINK_CTRL_SW_ATTR_DATA_READ__SW_ATTR_DATA_READ];
  
endtask



// task program_slink_attributes(
//   input bit [2:0]   num_tx_lanes,
//   input bit [2:0]   num_rx_lanes
// );
//   write_local_attr(ATTR_ACTIVE_TXS, num_tx_lanes);
//   #100ns;
//   write_local_attr(ATTR_ACTIVE_RXS, num_rx_lanes);
//   
//   update_local_effective;
// endtask



task enterP1;
  bit [31:0] val;
  
  `sim_info($display("Entering P1"))
  
  val[`SLINK_CTRL_PSTATE_CONTROL__P1_STATE_ENTER] = 1;
  val[`SLINK_CTRL_PSTATE_CONTROL__P2_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P3_STATE_ENTER] = 0;
  apb.write(`SLINK_CTRL_PSTATE_CONTROL, val);
endtask

task enterP2;
  bit [31:0] val;
  
  `sim_info($display("Entering P2"))
  
  val[`SLINK_CTRL_PSTATE_CONTROL__P1_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P2_STATE_ENTER] = 1;
  val[`SLINK_CTRL_PSTATE_CONTROL__P3_STATE_ENTER] = 0;
  apb.write(`SLINK_CTRL_PSTATE_CONTROL, val);
endtask

task enterP3;
  bit [31:0] val;
  
  `sim_info($display("Entering P3"))
  
  val[`SLINK_CTRL_PSTATE_CONTROL__P1_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P2_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P3_STATE_ENTER] = 1;
  apb.write(`SLINK_CTRL_PSTATE_CONTROL, val);
endtask

task wakeup_link;
  bit [31:0] val;
  `sim_info($display("Waking Link through SW"))
  val[`SLINK_CTRL_PSTATE_CONTROL__LINK_RESET]     = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__LINK_WAKE]      = 1;
  
  val[`SLINK_CTRL_PSTATE_CONTROL__P1_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P2_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P3_STATE_ENTER] = 0;
  apb.write(`SLINK_CTRL_PSTATE_CONTROL, val);
endtask


task set_slink_reset;
  bit [31:0] val;
  `sim_info($display("Resetting Link through SW"))
  val[`SLINK_CTRL_PSTATE_CONTROL__LINK_RESET]     = 1;
  val[`SLINK_CTRL_PSTATE_CONTROL__LINK_WAKE]      = 0;
  
  val[`SLINK_CTRL_PSTATE_CONTROL__P1_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P2_STATE_ENTER] = 0;
  val[`SLINK_CTRL_PSTATE_CONTROL__P3_STATE_ENTER] = 0;
  apb.write(`SLINK_CTRL_PSTATE_CONTROL, val);
endtask


endmodule


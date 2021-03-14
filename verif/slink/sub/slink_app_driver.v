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
  output wire [8:0]                  apb_paddr,
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

int crc_corrupt_count;
int ecc_correct_count;
int ecc_corrupt_count;

bit disable_monitor = 0;

task en_monitor;
  disable_monitor =0;
  monitor.disable_monitor=0;
endtask

task dis_monitor;
  disable_monitor =1;
  monitor.disable_monitor=1;
endtask


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
  
  di = 'h2 + {$urandom} % ('h2f - 'h2);
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
  
  di = 'h30 + {$urandom} % ('hef - 'h30);
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
interface. If a data ID of >= 0x30 is attempted, it will error. The dataid, and payload
are send to the monitor for checking reception.

.rst_end
*/
task sendShortPacket(input bit[7:0] dataid, input bit[15:0] wc);
  bit tx_ad;
  
  `sim_info($display("Starting Short Packet Send with DI: %2h and WC: %4h", dataid, wc))
  
  if(dataid >= 'h30) begin
    `sim_error($display("DATA ID should be 0x0 <-> 0x2F. Not sending this packet"))
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
    
    if(~disable_monitor) begin
      monitor.addByte(dataid   );
      monitor.addByte(wc[7 : 0]);
      monitor.addByte(wc[15: 8]);
    end
    
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
interface. If a data ID of < 0x30 is attempted, it will error. The dataid, wc, and payload
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
  
  if(dataid < 'h30) begin
    `sim_error($display("DATA ID should be > 0x2F. Not sending this packet"))
  end else begin
  
    //push to monitor for check
    if(~disable_monitor) begin
      monitor.addByte(dataid   );
      monitor.addByte(wc[7 : 0]);
      monitor.addByte(wc[15: 8]);
      if(wc) begin
        foreach(payload[i]) begin
          monitor.addByte(payload[i]);
        end
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
      if(~ignore_ecc_corrupt_errors) begin
        `sim_error($display("ECC Corruption interrupt seen!"))
      end
      ecc_corrupt_count++;
    end
    
    if(val[`SLINK_CTRL_INTERRUPT_STATUS__ECC_CORRECTED]) begin
      if(~ignore_ecc_correct_errors) begin
        `sim_error($display("ECC Corrected iterrupt seen!"))
      end
      ecc_correct_count++;
    end
    
    if(val[`SLINK_CTRL_INTERRUPT_STATUS__CRC_CORRUPTED]) begin
      if(~ignore_crc_corrupt_errors) begin
        `sim_error($display("CRC Corrupted interrupt seen!"))
      end
      crc_corrupt_count++;
    end
    
//     if(val[`SLINK_CTRL_INTERRUPT_STATUS__AUX_RX_FIFO_WRITE_FULL]) begin
//       `sim_error($display("Aux RX FIFO Write FULL interrupt seen!"))
//     end
    
  end
endtask


/**********************************************************************************
  ___  __      __    ___                      _     _                   
 / __| \ \    / /   | __|  _  _   _ _    __  | |_  (_)  ___   _ _    ___
 \__ \  \ \/\/ /    | _|  | || | | ' \  / _| |  _| | | / _ \ | ' \  (_-<
 |___/   \_/\_/     |_|    \_,_| |_||_| \__|  \__| |_| \___/ |_||_| /__/

**********************************************************************************/

slink_apb_driver #(.ADDR_WIDTH(9)) apb (
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


/*

*/
task write_local_attr(input bit[15:0] attr, input bit[15:0] wdata);
  bit[31:0] val;
  
  `sim_info($display("Writing Local Attribute: %4h with value %4h", attr, wdata))
  
  // Set address and data to be written
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_ADDR]  = attr;
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_WDATA] = wdata;
  
  apb.write(`SLINK_CTRL_SW_ATTR_ADDR_DATA, val);
  
  // Set the command to WRITE and LOCAL
  val = 0;
  val[`SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_LOCAL]  = 1'b1;
  val[`SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_WRITE]  = 1'b1;
  
  apb.write(`SLINK_CTRL_SW_ATTR_CONTROLS, val);
  
  
  // Set shadow update
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
  
  //Set Addr
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_ADDR] = attr;
  apb.write(`SLINK_CTRL_SW_ATTR_ADDR_DATA, val);
  
  // Set the command to ~WRITE and LOCAL
  val = 0;
  val[`SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_LOCAL]  = 1'b1;
  val[`SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_WRITE]  = 1'b0;
  
  //Read the response
  apb.read (`SLINK_CTRL_SW_ATTR_DATA_READ, val);
  
  data = val[`SLINK_CTRL_SW_ATTR_DATA_READ__SW_ATTR_RDATA];
  
  `sim_info($display("Reading Local Attribute: %4h with value %4h", attr, data))
  
endtask



task write_far_end_attr(input bit[15:0] attr, input bit[15:0] wdata);
  bit[31:0] val;
  
  `sim_info($display("Writing Far-End Attribute: %4h with value %4h", attr, wdata))
  
  // Set address and data to be written
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_ADDR]  = attr;
  val[`SLINK_CTRL_SW_ATTR_ADDR_DATA__SW_ATTR_WDATA] = wdata;
  
  apb.write(`SLINK_CTRL_SW_ATTR_ADDR_DATA, val);
  
  // Set the command to WRITE and LOCAL
  val = 0;
  val[`SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_LOCAL]  = 1'b0;
  val[`SLINK_CTRL_SW_ATTR_CONTROLS__SW_ATTR_WRITE]  = 1'b1;
  
  apb.write(`SLINK_CTRL_SW_ATTR_CONTROLS, val);
  
  // Set shadow update
  val = 0;
  val[`SLINK_CTRL_SW_ATTR_SHADOW_UPDATE__SW_ATTR_SHADOW_UPDATE] = 1'b1;
  
  apb.write(`SLINK_CTRL_SW_ATTR_SHADOW_UPDATE, val);
  
  #100ns;
  
endtask


//-----------------------------
// P State Changes
//-----------------------------

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


//-----------------------------
// BIST
//-----------------------------

`include "slink_bist_addr_defines.vh"

task program_bist(
  input bit[3:0]  bist_mode_payload, 
  input bit       bist_mode_wc,
  input bit[15:0] bist_wc_min, 
  input bit[15:0] bist_wc_max,
  input bit       bist_mode_di,
  input bit[ 7:0] bist_di_min, 
  input bit[ 7:0] bist_di_max
);

  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_BIST_MODE, val);
  val[`SLINK_BIST_BIST_MODE__BIST_MODE_PAYLOAD] = bist_mode_payload;
  val[`SLINK_BIST_BIST_MODE__BIST_MODE_WC]      = bist_mode_wc;
  val[`SLINK_BIST_BIST_MODE__BIST_MODE_DI]      = bist_mode_di;
  apb.write('h100 + `SLINK_BIST_BIST_MODE, val);
  
  
  apb.read('h100 + `SLINK_BIST_BIST_WORD_COUNT_VALUES, val);
  val[`SLINK_BIST_BIST_WORD_COUNT_VALUES__BIST_WC_MIN]  = bist_wc_min;
  val[`SLINK_BIST_BIST_WORD_COUNT_VALUES__BIST_WC_MAX]  = bist_wc_max;
  apb.write('h100 + `SLINK_BIST_BIST_WORD_COUNT_VALUES, val);

  apb.read('h100 + `SLINK_BIST_BIST_DATA_ID_VALUES, val);
  val[`SLINK_BIST_BIST_DATA_ID_VALUES__BIST_DI_MIN]     = bist_di_min;
  val[`SLINK_BIST_BIST_DATA_ID_VALUES__BIST_DI_MIN]     = bist_di_max;
  apb.write('h100 + `SLINK_BIST_BIST_DATA_ID_VALUES, val);

endtask

task clr_bist_swreset;
  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_SWRESET, val);
  val[`SLINK_BIST_SWRESET__SWRESET] = 0;
  apb.write('h100 + `SLINK_BIST_SWRESET, val);
endtask

task set_bist_active;
  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
  val[`SLINK_BIST_BIST_MAIN_CONTROL__BIST_ACTIVE] = 1;
  apb.write('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
endtask

task disable_bist_active;
  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
  val[`SLINK_BIST_BIST_MAIN_CONTROL__BIST_ACTIVE] = 0;
  apb.write('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
endtask

task en_bist_tx;
  bit [31:0] val;
    
  apb.read('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
  val[`SLINK_BIST_BIST_MAIN_CONTROL__BIST_TX_EN]     = 1;
  apb.write('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);

endtask

task disable_bist_tx;
  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
  val[`SLINK_BIST_BIST_MAIN_CONTROL__BIST_TX_EN]     = 0;
  apb.write('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);

endtask

task en_bist_rx;
  bit [31:0] val;
    
  apb.read('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
  val[`SLINK_BIST_BIST_MAIN_CONTROL__BIST_RX_EN]     = 1;
  apb.write('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);

endtask

task disable_bist_rx;
  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);
  val[`SLINK_BIST_BIST_MAIN_CONTROL__BIST_RX_EN]     = 0;
  apb.write('h100 + `SLINK_BIST_BIST_MAIN_CONTROL, val);

endtask


task check_bist_locked;
  bit [31:0] val;
  
  apb.read('h100 + `SLINK_BIST_BIST_STATUS, val);
  
  if(val[`SLINK_BIST_BIST_STATUS__BIST_LOCKED]) begin
    `sim_info($display("Bist locked seen"))
  end else begin
    `sim_error($display("Bist locked NOT seen"))
    if(val[`SLINK_BIST_BIST_STATUS__BIST_UNRECOVER]) begin
      `sim_error($display("Bist un-recoverable situation seen"))
    end
  end
endtask


task check_bist_errors(input bit[15:0] exp_errors = 0);
  bit [31:0] val;
  bit [15:0] bist_errors;
  
  apb.read('h100 + `SLINK_BIST_BIST_STATUS, val);
  
  bist_errors = val[`SLINK_BIST_BIST_STATUS__BIST_ERRORS];
  
  if(bist_errors == exp_errors) begin
    `sim_info($display("Expected %0d errors and saw %0d errors", exp_errors, bist_errors))
  end else begin
    `sim_error($display("Expected %0d errors and saw %0d errors", exp_errors, bist_errors))
  end
  
endtask

endmodule


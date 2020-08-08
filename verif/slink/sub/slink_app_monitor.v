/*
.rst_start
slink_app_monitor
-----------------
The S-Link App Monitor is used to monitor the S-Link RX application interface and extract packet information
as it is received. When a packet is transmitted from the ``slink_app_driver``, the driver will push each packet
byte into the monitors ``pkt_array[]``. As packets are received the monitor will look for each respective packet
byte and indicate an error if something does not match.

.rst_end
*/

module slink_app_monitor #(
  parameter APP_DATA_WIDTH   = 32
) (
  input  wire                                     link_clk,
  input  wire                                     link_reset,
  
  input  wire                                     rx_sop,
  input  wire [7:0]                               rx_data_id,
  input  wire [15:0]                              rx_word_count,
  input  wire [APP_DATA_WIDTH-1:0]                rx_app_data,
  input  wire                                     rx_valid,
  input  wire                                     rx_crc_corrupted
);

`include "slink_msg.v"

bit [7:0] pkt[$];
bit [7:0] pkt_array[$];

task addByte(bit[7:0] b);
  `sim_debug($display("Pushing back byte %2h", b))
  pkt_array.push_back(b);
endtask


task printBytes;
  foreach(pkt_array[i]) begin
    `sim_debug($display("%0d: %2h", i, pkt_array[i]))
  end
endtask


initial begin
  //Monitor Fork
  fork
    monitorIntf;
  join_none
end

task monitorIntf;

  bit [7:0]   b;
  bit [15:0]  wc;
  int         remaining_bytes;

  forever begin
    @(posedge link_clk);
    
    if(rx_sop && rx_valid) begin
      //SOP
      if(rx_data_id <= 'h1f) begin
        //Short Packet
        `sim_info($display("Short packet Received ID: %2h WC: %4h", rx_data_id, rx_word_count))
        checkByte(rx_data_id);
        checkByte(rx_word_count[ 7: 0]);
        checkByte(rx_word_count[15: 8]);
      end else begin
        //Long Packet
        checkByte(rx_data_id);
        checkByte(rx_word_count[ 7: 0]);
        checkByte(rx_word_count[15: 8]);
        
        `sim_info($display("Long packet Received ID: %2h WC: %4h", rx_data_id, rx_word_count))
        
        wc              = rx_word_count;
        remaining_bytes = wc;
        
        for(int i = 0; i < APP_DATA_WIDTH/8; i++) begin
          if(remaining_bytes) begin
            checkByte(rx_app_data[i*8 +: 8]);
            remaining_bytes--;
          end
        end
        
      end
    end else if(~rx_sop && rx_valid) begin
      if(rx_crc_corrupted) begin
        `sim_error($display("CRC Corruption Seen!"))
      end
      //Rest of long data
      for(int i = 0; i < APP_DATA_WIDTH/8; i++) begin
        if(remaining_bytes) begin
          checkByte(rx_app_data[i*8 +: 8]);
          remaining_bytes--;
        end
      end
    end else if(rx_sop && ~rx_valid) begin
      `sim_error($display("RX_SOP seen but RX_VALID not asserted!"))
    end
    
  end
endtask

task checkByte(bit[7:0] b);
  bit [7:0] pkt_b;
  
  if(pkt_array.size() == 0) begin
    `sim_error($display("Went to check byte 0x%2h but pkt_array is empty!", b))
  end else begin
    pkt_b = pkt_array.pop_front();
    if(b != pkt_b) begin
      `sim_error($display("byte mismatch! Received 0x%2h but expecting 0x%2h", b, pkt_b))
    end else begin
      `sim_debug($display("byte match! Received 0x%2h and expecting 0x%2h", b, pkt_b))
    end
  end
endtask


task finalCheck;
  if(pkt_array.size()) begin
    `sim_error($display("Packet Array is not empty! Still contains %0d packets", pkt_array.size()))
    `sim_debug($display("Here are all the bytes still in the array"))
    foreach(pkt_array[i]) begin
      `sim_debug($display("%8d : 0x%2h",i, pkt_array[i]))
    end
  end
  
  if(sim_errors) begin
    `sim_error($display("%0d errors seen", sim_errors))
  end
endtask

endmodule

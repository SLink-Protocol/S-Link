Packets
==============

S-Link uses packets to communicate between application layers on each side.

There are two type of packets in S-Link, short packets and long packets. These packet types lean heavily on the CSI/DSI packet definitions
due to their simplicity as well as flexible packet lengths.

Short Packets
-------------

.. figure :: short_packet.png
  :align:    center
  
  Short Packet Structure

Short packets are 32bits in size and are generally used for intra-link communication and small data payloads. They comprise of the following:

* Data ID [7:0] - Denotes packet type. Data Id's 0x0 - 0x1f are short packets. 0x20 - 0xff are long packets
* Payload [23:8] - Optional payload for short packets
* ECC [31:24] - ECC used for packet error correction/detection.


Long Packets
------------

.. figure :: long_packet.png
  :align:    center
  
  Long Packet Structure

Long Packets have varying sizes dependent on the payload size. They compromise of a 4byte packet header and 2byte CRC. The make up of 
a long packet is defined by the following:

* Data ID [7:0] - Denotes packet type. Data Id's 0x0 - 0x1f are short packets. 0x20 - 0xff are long packets
* Word Count [23:8] - Number of bytes for this long packet
* ECC [31:24] - ECC used for packet error correction/detection. Same ECC as short packets
* Payload - Application specific payload
* CRC - CRC generated on the payload data. 



.. note ::

  A future revision of S-Link may allow the CRC to be bypassed/disabled to allow more bandwidth.


Reserved Data IDs
-----------------

Several data ids are reserved for S-Link internal use and/or S-Link communication. The applicaiton layer shall not use the following
data ids for application-specific data transfer.

.. note ::

  The applicaiton layer **can optionally** use some of these for communicating to the other S-Link controller. This is indicated
  by the table under the "App can use" column.
  
  This is allowed so hardware can perform attribute checks/updates.

============= ======================= ============= ======================= =======================================================================
Data ID       Packet Type             App can use?  Payload Data            Description
============= ======================= ============= ======================= =======================================================================
**Short Packets**
--------------------------------------------------------------------------------------------------------------------------------------------------- 
0x00/0x01     NOP                     N                                     | No Operation/IDLE packet that is used to keep the link alive but      
                                                                            | conveys no data                                                                                                    

**Long Packets**
--------------------------------------------------------------------------------------------------------------------------------------------------- 
0xf0-0xff     RESERVED                                                      Reserved for future use                                                 
============= ======================= ============= ======================= ======================================================================= 

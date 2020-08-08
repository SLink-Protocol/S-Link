Packets
==============

S-Link works almost exclusively on packets. All of the communication between both sides of the link occur through packet based operations.

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
0x01          NOP                     N                                     | No Operation/IDLE packet that is used to keep the link alive but      
                                                                            | conveys no data                                                       
0x02          Attribute Addr          Y             Attribute address[15:0]   Updates the far end S-Link attribute address selection                  
0x03          Attribute Data          Y             Attribute data[15:0]    | Updates the far end S-Link attribute data selection and writes        
                                                                            | the corresponding attribute address                                   
0x04          Attribute Request       Y             Attribute address[15:0] | Request for the far end S-Link to respond with the attribute shadow   
                                                                            | value at the provided address                                         
0x05          Attribute Response      Y             Attribute data[15:0]      Returned data value for the previous attribute request                      
0x06          P State Request         Y?            | [0] - P1                Request for a P state change.                                           
                                                    | [1] - P2                                                                                        
                                                    | [2] - P3                                                                                        
0x07          RESERVED                                                      Reserved for future use                                                 
0x08          P State Start           N                                     Indicates for the S-Link to enter the requested P state                 
0x09-0x0f     RESERVED                                                      Reserved for future use                                                 

**Long Packets**
--------------------------------------------------------------------------------------------------------------------------------------------------- 
0xf0-0xff     RESERVED                                                      Reserved for future use                                                 
============= ======================= ============= ======================= ======================================================================= 

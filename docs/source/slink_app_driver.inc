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


sendRandomShortPacket
+++++++++++++++++++++
Sends a short packet with a random dataid and payload

sendRandomLongPacket
+++++++++++++++++++++
* ``input bit random_data`` - 1: Random data is send for each byte 0: byte data is a counter

Sends a long packet with a random dataid and payload

sendShortPacket
+++++++++++++++

* ``input bit[7:0] dataid`` - Data ID for this packet
* ``input bit[15:0] wc`` - Word Count/Payload for this packet

SendShortPacket will handle the sending of the desired short packet on the S-Link 
interface. If a data ID of >= 0x20 is attempted, it will error. The dataid, and payload
are send to the monitor for checking reception.


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




  
.. generated using get_rst.py by steven at August/13/2020  12:15:12



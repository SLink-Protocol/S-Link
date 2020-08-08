Link Layer Logic
=================

``slink_ll_tx``
---------------
The ``slink_ll_tx`` (sometimes referred to as LL_TX) is the main packet creator for user transactions and internal link operations. It's goal is to take data
from the application layer and packetize the data for the link. It will also handle spanning the data across all of the active phy lanes.
It includes the following components:

* Main TX Link State machine for keeping up with conceptual packet and/or link states
* ECC Syndrome Generator for packet header ECC
* CRC Generator for Long Packet CRC values
* AUX Data FIFO for Software based/Response packets

The LL_TX is rather simple, with the only real complexity in the LL_TX being the byte striping and word count calculations. The exact details
are left for the curious to discover, but essentially the LL_TX will keep up with the ``byte_count`` indicating the `number of bytes sent` for this particular
cycle. Decisions are then made based on the number of bytes sent versus the total number of bytes to send for the current packet. At the end of the
application data for the current packet, the LL_TX will look to see how many bytes are free for that cycle and place the CRC in the respective locations.

``slink_ll_rx``
---------------
The ``slink_ll_rx`` (sometimes referred to as LL_RX) does the reverse of the LL_TX by destructing the link packet. It will take the received data from
the link, and extract the Data ID, Word Count, and application data. It will also check the ECC and CRC for any bit errors.

If any ECC/CRC errors are seen, the LL_RX can indicate this to the LTSSM to start a :ref:`Reset Condition`. Support for this can be set using the :ref:`ERROR_CONTROL`
register. Since S-Link works exclusively on packets, errors in the packet header (determined by ECC corruption) should generally be treated as unresolvable and cause a 
link reset condition. 


Byte Stripping
--------------
S-Link sends data bytes in order with each byte being stripped across based on the number of active lanes. 

.. figure :: byte_stripe.png
  :align:    center
  
When a packet ends not on a lane byte boundary, e.g. 4lanes at 8bit and the last cycle only requires 3 bytes, the remaining bytes are to be filled with
IDL (all zeros). The LL_RX does not check these bytes.


CRC
---
The CRC used in S-Link is the same version that is used in CSI/DSI. The initial seed is ``0xFFFF`` and is reset after each long packet data payload.

.. figure :: slinkcrc.png
  :align:    center


The CRC is implemented as a chain of 16bit CRC calculations based on each byte of possible transmission based on the number of lanes and data width. For example,
a 4lane with 8bit PHY_DATA_WIDTH would have 4 instances of the CRC calculation logic for each possible byte sent during each ``link_clk`` cycle. See the RTL for more
details on implementation.

.. note ::

  When experimenting on an FPGA, I noticed the CRC utilized quite a bit of LUTs. If many people want to use on FPGA we might can look into excluding the
  CRC logic with a parameter.


ECC
---
The S-Link ECC generation and checking implementation is the same as the MIPI CSI (Version 1.3, and probably later).

The inclusion ECC allows the following:
* Finding if the packet header (or entire packet if short) has any errors
* Checking if a single error has occurred, and if so, allowing a correction
* Determining if more than a single bit error has occurred and indicating that the packet header/packet is corrupt

It is advised that a user would issue a link retrain in the event of ECC/PH correction and certainly in the case of
corruption. Since S-Link uses the packet headers to keep up with active states, a reduced confidence in the payload
through a correction would be an indication that the link is experiencing some issues that need to be resolved.

.. todo::

  Add a block diagram of the ECC logic


.. note ::

  The MIPI CSI Spec Section 9.5 has a breakdown of the syndrome/ecc correction tables, and this logic 
  was just built from that table.


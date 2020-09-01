Peformance/Latency Calculations
===============================

S-Link total bandwidth for each direction is easily calculated as:

.. math ::

  Peak Bandwidth Gbps (TX) = NUM\_TX\_LANES * PHY\_DATA\_WIDTH * (1 / bit period ns)
  
  Peak Bandwidth Gbps (RX) = NUM\_RX\_LANES * PHY\_DATA\_WIDTH * (1 / bit period ns)


This bandwidth is max theoretical based on 100% utilzation. Naturally, 100% utilization is not possible. The S-Link Performance
Calculator can be used to see the overall packet/bandwidth efficiency.

Packet Efficiency is defined by:

.. math ::

  Packet Eff % = payload size / (payload size + 6)

As you can deduce, the larger the payload size for each packet, the higher the overall efficiency and thus higher bandwidth 
utilization.

.. note ::

  One could argue that the Data ID is also another form of payload data, depending on the use case of the Data ID. If so,
  this does increase the overall packet efficiency, however as a generalization we are not including this in the calculation.
  
  
Latency may be a higher priority depending on the use case. The S-Link latency through the controller is deterministic based on the current
settings and configuration of S-Link. For example, there are only two possible pipeline stages in the TX; one in the LL_TX and the other in the LTSSM
(which can optionally be removed through the ``LTSSM_REGISTER_TXDATA`` parameter). On the RX side, the latency is a byproduct of the maximum deskew (implementation
dependent), and a pipeline stage in the LL_RX. Additional latency based on the physical layer used is outside the scope of S-Link.

.. figure :: pipeline_stages.png
  :align:    center
  


The S-Link Performance Calculator allows a user to see the overall latency for the following paths:

* APP TX -> PHY - From the application layer to the PHY TX
* PHY -> APP RX - From the PHY RX to the application layer, with min/max based on maximum RX deskew possibilities
* Total End-to-End - From the application layer on one side of the link to the other, with min/max based on deskew

The user can input their expected TX/RX PHY latency which is included in the calculation. This can be used to see the overall packet latency **for
an entire packet to be sent**, e.g. the time to send all bytes of a packet. This does not indicate start of packet to start of packet latency.

This calculation takes into account the number of payload bytes, the number of active lanes, phy data width, and any optional latency pipeline stages which
can be selected by the user.

.. note ::

  The data width of the application layer is not taken into account for this measurement as it has no effect on the latency.


.. warning ::

  The S-Link Performance Calculator does not take into account any factors that would increase the latency such as another packet
  is currently being sent when the packet in question attempts to start.


The trade-off of bandwidth vs latency is application dependent, so these this calculator is provided to assist with design decisions. For example, multimedia
applications may be very tolerant of latency, so it may be advantageous to send long packets with high data payloads. In a memory application, the latency may
be a dominating factor, so smaller packets could allow for better performance.

LTSSM
======
The ``slink_ltssm`` handles the PHY control, training, and lower P state controls. The S-Link LTSSM 
is `loosely` based on the PCIe/USB LTSSM. Some liberties have been taken to reduce complexity and 
give a user more flexibilities with regards to link training time.

An overview of the ltssm states as well as the general flow diagram can be seen below

.. figure :: ltssm_states.png
  :align: center
..   :scale:    200%
  
  S-Link LTSSM State Digram  

LTSSM States
-----------------

IDLE
+++++++++++++++
Initial reset state of the link. In this mode, the PHY is completely disabled. 

  - Exit to WAIT_CLK when S-Link is enabled.

WAIT_CLK
+++++++++++++++
Once S-Link is enabled the PHY CLK will be enabled. Depending on the PHY layer used, the PLL (or other clock source)
should be enabled. The LTSSM will wait for ``phy_clk_ready`` to assert. This means that the PHY CLK is active and should
be actively transmitting from Master -> Slave.

  - Exit to SWITCH after PHY CLK is ready.

SWITCH
+++++++++++++++
This is an intermediate state where the ``link_clk`` is switched from the ``refclk`` to the ``phy_clk``. At the end of the
switch, the active lanes are enabled. The LTSSM then waits in this state until the TX and RX lanes are ready.

The TX/RX lanes enabled is determined by the active_txs and active_rxs attributes. i.e. if four TX lanes are active
and two RX lanes are active, then ``phy_tx_en == 'hf`` and ``phy_rx_en == 'h3``.
  
  - Exit to P0_TS1 after all active TX/RX lanes are ready.

P0_TS1
+++++++++++++++
In this state the LTSSM is sending TS1s to the far end. The RX's are indicated to begin byte/symbol alignment using
the TS1/2 sets. The RX Deskew FIFO is enabled to remove any lane-to-lane skew. 

The TS1s are actually recognized in the RX Deskew FIFO. The deskew logic observe for each byte of the TS1 to be
correct then assert a TS1 indication to the LTSSM, incrementing the TS1 counter.

  - Exit to P0_TS2 once ``ts1_tx_count`` TS1 are sent AND ``ts1_rx_count`` TS1 are seen, OR if any TS2s are seen.


P0_TS2
+++++++++++++++
Similar to P0_TS1 state except that we are sending TS2s.

  - Exit to P0_SDS once ``ts2_tx_count`` TS1 are sent AND `ts2_rx_count`` TS1 are seen, OR if the SDS is seen.


.. note ::

  The number of TSx sets required can be changed based on the P State that is being exited. This is done
  through the attributes.


P0_SDS
+++++++++++++++
This is a state in which the SDS is sent to the far end. After the SDS is sent, the link is considered up and starts to send packet data.

  - Exit to P0 after sending SDS.

P0
+++++++++++++++
This is the main data sending state. 

  - Exit to P1 when P1 request condition is seen
  - Exit to P2 when P2 request condition is seen
  - Exit to P3 when P3 request condition is seen
  - Exit to RESET when reset condition is seen

P1
+++++++++++++++
P1 state is a lower power state in which the TX/RX lanes are disabled for power savings. It is expected that a user would
try to enter P1 as much and often as possible to save power. 

  - Exit to P0_TS1 when wake condition is seen.
  - Exit to RESET when reset condition is seen.

P2
+++++++++++++++
P2 state is a low power state in which, the TX/RX lanes are disabled and the data rate clock from the Master is disabled. The clock source
in the master (PLL or other logic) should remain active to ensure P2 exit is short.

  - Exit to WAIT_CLK when wake condition is seen.
  - Exit to RESET when reset condition is seen.

P3
+++++++++++++++
P3 state is a low power state in which the TX/RX lanes are disabled as well as the data rate clock from the Master. P3 is similar to P2 with the
exception that in P3 the master is allowed to completely disable the clock source (PLL or other clock source) for additional power savings. From 
the slave perspective, there is no real difference between P2 and P3, except that it is understood that a longer exit latency is expected when exiting.

  - Exit to WAIT_CLK when wake condition is seen.
  - Exit to RESET when reset condition is seen.


RESET
+++++++++++++++
The RESET state is reachable by all other states and is entered when a reset request is seen from either side of the link. A local reset request happens
either by software intervention and/or through some link condition that warrents a reset (ECC/CRC corruption). Link conditions that warrant a reset
can be configured by the :ref:`ERROR_CONTROL` software register.

  - Exit to IDLE when reset condition is no longer valid. A wake condition will not take precedence over a reset condition.


.. note ::

  Inside the S-Link RTL there are additional transition states. These are not listed here for clarity.


Internal Ordered Sets
---------------------

TS1
+++


.. table::
  :widths: 10 10 50

  ======= ======== ================================================
  Byte    Value    Description                                     
  ======= ======== ================================================
  0       0xBC     Used to byte lock RX
  1-15    0x55     
  ======= ======== ================================================


TS2
+++
.. table::
  :widths: 10 10 50

  ======= ======== ================================================
  Byte    Value    Description                                     
  ======= ======== ================================================
  0       0xBC     | Used to byte lock RX if far end is no longer
                   | sending TS1s
  1-15    0xAA     
  ======= ======== ================================================
  
SDS
+++

.. table::
  :widths: 10 10 50

  ======= ======== ================================================
  Byte    Value    Description                                     
  ======= ======== ================================================
  0       0xDC     
  1-15    0xAB     
  ======= ======== ================================================


.. note ::

  When 128/130b encoding is enabled for S-Link, the above Ordered sets will remain the same.
  
  In the future, S-Link may determine to change bytes 1-15 to hold link specific information, similar to PCIe/USB.

Power State Handshake
---------------------
There are two ways in which a user can place S-Link into a lower power state; through hardware or software. For hardware, the user would assert the ``p1_req``, ``p2_req``,
or ``p3_req`` signals. For software, the user would write the :ref:`PSTATE_CONTROL` register with the respective bitfield. For both hardware and software methods, if
more than one P state is requested (e.g. you have ``p1_req`` and ``p2_req`` asserted) the `lowest` power state is taken (P2 in this example).

When a P State Request is seen, S-Link will continue to send any packet currently in flight, then, provided another packet does not need to start via ``tx_sop`` being asserted,
S-Link will start to send P state request packets to the far side S-Link. The far-side will see these packets, and once it has finished sending any packets in-flight `and` it
is not being requested to send another packet via it's ``tx_sop`` being asserted, it will proceed to begin sending P state request packets, mirroring the P State Request.

Once the request packets have been seen and sent on both sides of the S-Link, both sides will send a P State Start packet and the LTSSM for each S-Link controller will move
to the requested power state.


.. note ::

  Currently there is no way for either S-Link controller to "reject" a power state request. I did think about adding this but came up with a few conclusions:
  
  #. `Generally` from a chiplet perspective one side is handling the majority of the traffic handling and therefore would know it's acceptable
     to go into a lower power state, deciding the state based on the system wide requirements of exit latency and preferred power savings. Just
     making both sides force the acceptance simplified the handshake and need to check to see if the power state was accepted.
  #. I wasn't sure exactly how this would/should be implemented and so I took a simple approach to get going and will make changes once more
     use cases pop up.


P State Exit is handled by a wake request, reset condition, or if a packet at either end is set to be sent by ``tx_sop`` assertion.

.. note ::

  A somewhat neat feature can be exploited with regards to power states. If a user wants their link to always be attempting a lower power state, they
  can keep ``p[1|2|3]_req`` asserted at all times and when they wish to send packets, just send packets as required. This does incur an exit latency
  but can keep the user from having to create logic to constantly wakeup and sleep the link.


Reset / Wake Sideband Signals
-----------------------------
Protocols have implemented various different methods for signaling specific line state conditions to reset or wake up a link. Electrical Idle, LFPS, DIF-P/N/Z, DPHY LP States, etc.
These methods generally require additional analog logic to sense the line state and take appropriate action. This also causes additional logic in the PCS/controller to handle
such situations. S-Link decided to take a simpler approach in which we have two additional sideband signals:

* ``slink_reset_n``
* ``slink_wake_n``

Both signals are active low. Both sides of the S-Link share the same bump. When not asserted, a soft pullup should be used to keep each signal high. 


Reset Condition
+++++++++++++++++
A reset condition occurs any time that ``slink_reset_n`` is asserted. When the reset condition is seen, the LTSSM starts the transition to the RESET state
as described above.

Hard Reset Condition
++++++++++++++++++++
A Hard Reset occurs when a reset condition (``slink_reset_n`` asserted) for 100us+. During a hard reset, the attributes are reset to the original default values.

.. note ::

  The hard reset detect time can be set based on the ``hard_reset_us`` attribute. 
  
  .. warning ::
  
    Currently the ``hard_reset_us`` attribute will reset to the default of 100us if a hard reset is seen. A future version of S-Link may allow
    the ``hard_reset_us`` attribute to remain unaffected by the hard reset condition.

Wake Condition
+++++++++++++++++
``slink_wake_n`` is asserted anytime one side of the link wishes to send data and it is not in P0 state. The master or slave can assert 
``slink_wake_n`` and the other side is required to respond to the request. 

.. figure :: p1_exit_signal_ex.png
  :align:    center
..   :scale:    200%
  
  Example Wake Request for P1 State Exit

``slink_wake_n`` is deasserted anytime the link is in P0 or if the link is in a low power state and has no data to send (state P1 in the example above). When
data is requested to be sent the S-Link controller that is initiating the wake request will assert the ``slink_wake_n`` line. The other S-Link will see this request
and, begin the exit from it's lower power state, and both sides will begin link training.

Upon finishing link training (entering P0), both S-Link controllers will deassert ``slink_wake_n``. While in P0, the S-Link controller will ignore ``slink_wake_n`` as it
is already conceptually woken up.
  













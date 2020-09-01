High Level Overview
===================

.. figure :: slink_top_level_diagram.png
  :align:    center
  
  S-Link Top Level Block Diagram


S-Link is designed to operate as a clock forwarding architecture in the traditional master/slave format, where the master supplies the datarate
clock and the slave receives. The S-Link RTL is the same for both and treats the PHY as the same. The difference is in how the PHY would react
to clock changes (i.e. if the slave is told to disable the clock, that would mean ignoring and/or shutting down it's clock receiver).

.. note ::

  A future provision of S-Link may allow non-clock forwarding architectures.


S-Link provides an interface for various Application/Transaction layers  to easily interface with the link.
What defines an application layer in this sense is completely up to the user. If a user wanted to communicate with another chiplet via memory accesses,
the user may wish to have an AXI application layer. If the other chiplet is some sort of multi-media IP, the application layer may be specific
to camera/video data. 


Features
--------
S-Link supports the following features:

* Mult-lane support (provisions for upto 128+ lanes with asymmetric lane support)
* Parameterizable Applicaiton Data Widths
* Configurable Attributes for fine tuning link controls and/or active link managemnet
* Low Power (P states) for power savings
* ECC/CRC for error checking
* Parameterizable pipeline stages to optimze for frequency and/or power or based on physical layers

.. note ::
  
  128b/130b encoding is the *default* setting for S-Link and is generally meant to be used with typical SerDes where CDRs are used
  and/or bit alignment requires digital support. Support for a strobe-like interface (parallel, either low or high speed) is being
  added. The document may mention statements like "if 128b/130b is enabled...", the doc is being written with the strobe-like interface
  in mind to cut down on constantly changing the docs. So if you see this and 128/130b is the only mode, just be aware that this is why
  and give me some time to add it.


Multi-Lane Support
++++++++++++++++++
S-Link provides multi-lane support. Currently there are provisions for upto 128 lanes (currently the RTL only supports 1/2/4). S-Link also
has asymmetric lane support. This allows for a user to instatiate S-Link with a different number of TX/RX lanes according to their usecase. e.g.
A user has an application in which there are many memory writes, but very few memory reads. A user may wish to instantiate S-Link as a 8TX/2RX, with the
other side being a 2TX/8RX.

S-Link also support active link width changes. This means that during operation the number of active TX and RX lanes can be changed to accomodate
changes in desired bandwidth and/or for power savings.

Application Data Width
++++++++++++++++++++++
The data width to the application layer can be configured simplifying the logic in the application layer. The data width has a few requirements:

* Minimum PHY_DATA_WIDTH * NUM_LANES 

  * i.e. if 4TX and 2RX at 8bit, 8x4=32bit is minimum application data width for the TX and 8x2=16bit is the minimum application data width for the RX

* Can be an integer multiple of the minimum. 

  * i.e. using example above, could use 32/64/128/256/etc as application data width for the TX, and 16/32/64/128/etc for the RX
  

Link Attributes
+++++++++++++++
Since S-Link is designed with multiple physical layers in mind, there was a desire to allow a user to configure the link either at configuration
or while running to optimize link parameters. Borrowing from MPHY, S-Link has implemented "Attributes". Attributes describe various link parameters
such as number of active TXs/RXs, number of training sets for different states, etc. The goal is to have the ability to optimize tasks such as
link training for reduced speed based on the system requirements.

As an example, PCIe sends 1024 TS1s during Polling.Active. At Gen1 speeds this is 64us. S-Link allows training sets to be configured so a user
could reduce time for various states.


Low Power P States
++++++++++++++++++
S-Link provides four conceptual power states for operation:

* P0 - Highest power state, data is actively transmitting
* P1 - Lower power state with low exit latency. Data is not transmitting but clock should be sent/received
* P2 - Data/Clock are not being transmitted. Master should have clock/PLL ready to transmit.
* P3 - Data/Clock are not being transmitted. Clock/PLL can be completely shut down for most power savings.

Power states can be entered and exited through hardware or software based operations.



.. figure :: docs/source/slink_logo_white.png
  :align:    center

S-Link
======
S-Link is a simple, scalable, and flexible link controller protocol geared towards chiplets and chip-to-chip communication. S-Link defines
the link layer, and gives freedom for various application and physical layers. The ultimate goal of S-Link is to provide a simple alternative
for chiplet communication compared to other protocols.

S-Link supports the following features:

* Mult-lane support (provisions for upto 128+ lanes with asymmetric lane support, **up to 4lanes currently supported**)
* Parameterizable Applicaiton Data Widths
* Configurable Attributes for fine tuning link controls and/or active link managemnet
* Low Power (P states) for power savings
* ECC/CRC for error checking
* Parameterizable FIFO sizes for Deskew and AUX channels
* Parameterizable pipeline stages to optimze for frequency and/or power


Tools Required
--------------
Iverilog and Gtkwave are the main tools you would need to try out some simulations. Those can be installed using the following
steps (or just visit their repos/websites for more info).

iverilog
++++++++
::

  git clone git://github.com/steveicarus/iverilog.git
  sudo apt-get install bison flex gperf autoconf
  sh autoconf.sh (if compiling from git)
  ./configure
  make
  sudo make install

  which iverilog


gtkwave
+++++++
::

  git clone https://github.com/gtkwave/gtkwave.git
  cd gtkwave3 (pick your version)

  sudo apt-get update -y
  sudo apt-get install -y tcl-dev tk-dev libbz2-dev liblzma-dev
  sudo apt-get install gtk2.0   (you may or may not want this
  ./configure
  make sudo make install
  which gtkwave


.. note ::

  Verilator may be supported later, but due to serdes models it is unlikely.


Run your first sim
------------------
Ensure that iverilog and gtkwave are installed.

:: 

  cd verif/slink/run
  ./simulate.sh

This will run ``sanity_test`` which just sends a few packets from one side of S-Link to the other.

Synthesis/PnR
-------------
I had started using the experimental OpenROAD Flow for synthesis. Unfortunately as of Aug 1st 2020, the OpenROAD-flow repo has gone MIA so
it appears I need to setup this flow manually. Stay tuned for more information and some scripts to run S-Link with the OpenROAD tools.

S-Link has been synthesized with Yosys, and prior to the OpenROAD-flow going missing, had been ran through OpenRoad to GDS (no optimizations, just
flushing the flow out).

An initial 4TX/4RX 8bit PHY version of S-Link was tested on a Zedboard using Vivado 2019.2. This was tested using a simple AXI application
layer and allowed the built in ARM core to communicate with an on-chip BRAM via AXI.


Using S-Link
------------
Want to use S-Link? Download and integrate! You are free to use in commercial projects. If you do choose to use S-Link, I do ask that you
let me know with some (minor) details about the use case just so I can see how it's being used. Also, please star the repo if you don't mind.


Want to Support S-Link?
-----------------------
Try it out! Offer suggestions for improvement! I have tried to create S-Link using only open source tools, and would like to continue support
for those. That being said, it would be nice to have a commercial simulator and synthesis/PnR tools in order to check compatibility. Larger FPGAs
and accompanying licenses would also be nice to have to try out various PHY types. If you or your oranization wish to help in any of these regards, 
please contact me.

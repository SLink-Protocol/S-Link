Tests
-----

sanity_test
+++++++++++
Just brings up the link and send a few packets. Commonly
used for trying out specific usecases

pstate_sanity
+++++++++++++
Sends some packets and goes into each P state

random_packets
++++++++++++++
Brings up the link and sends a random number of packets

link_width_change
+++++++++++++++++
- Bring up link
- Send some packets
- Randomly change the link width while active
- Go to lower P1 state
- wakeup and send some random packets

slink_force_reset
+++++++++++++++++
Bring up slink and force a reset through SW. Wake link
back up and see if we can send packets again

slink_force_hard_reset
+++++++++++++++++++++++
- Bring up slink and send some packets
- Write some attributes to non-default values
- Perform a HARD reset
- Read those attributes to see if they are back to defaults
- Wake up link and send some packets

ecc_correction
++++++++++++++
Corrupts one of the Packet Header, looks to see if this error
was seen in the monitor. The receiving side should have receieved the
packet with no errors since one bit error should be resolvable.

ecc_corruption
++++++++++++++
Corrupts two bits of the Packet Header, looks to see if this error
was seen in the monitor. Allows the link to reset then checks to 
see if a valid packet can be sent to indicate recovery.



  
.. generated using get_rst.py by steven at September/01/2020  07:47:35



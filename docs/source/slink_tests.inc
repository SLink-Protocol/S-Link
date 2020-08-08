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



  
.. generated using get_rst.py by steven at August/06/2020  10:40:11



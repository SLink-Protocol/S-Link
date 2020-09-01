slink_app_monitor
-----------------
The S-Link App Monitor is used to monitor the S-Link RX application interface and extract packet information
as it is received. When a packet is transmitted from the ``slink_app_driver``, the driver will push each packet
byte into the monitors ``pkt_array[]``. As packets are received the monitor will look for each respective packet
byte and indicate an error if something does not match.




  
.. generated using get_rst.py by steven at September/01/2020  07:47:35



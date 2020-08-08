Attributes
==========

Attributes in S-Link take inspiration from the attributes found in M-PHY. The ability to "tune" the link seemed like a neat feature and for
chiplet based ecosystems, could possibly be leveraged. It also seemed like a necessity as different physical layers would require different
training algorithms. A serial die-to-die would need to train much longer than a GPIO based physical layer. A user could also use the attributes
to fine tune the settings for training to reduce latency. 


The attributes are used to change the link conditions, and can be done while the link is running. The attributes have two storage elements

* Effective - The currently active setting of the attribute
* Shadow - The staged setting to be activated the next time a lower P state is entered.

When performing an attribute update the user is actually writing the shadow value and is essentially staging both sides of the link for
the next link condition. These shadow attributes are applied to the effective state by setting the link to a lower power state (P1/2/3). 

.. include :: slink_attributes.rst


The test :ref:`link_width_change` has a good example of how we would use the attributes to change the link width of each S-Link direction.

.. note ::

  Either side of the link can change the attributes, in fact, both sides could have collision issues if they both attempt to write the same
  attributes. While this sounds like an issue, I believe that most of the time one side will ultimately be in charge of making the changes
  to the link attributes.
  
  If usecases arise where this methodology doesn't seem to work, we can revisit and make adjustments.

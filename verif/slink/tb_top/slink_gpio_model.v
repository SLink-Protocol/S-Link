module slink_gpio_model(
  input  wire     oen,
  output wire     sig_in,
  inout  wire     pad
);


assign pad    = oen ? 1'b0 : 1'bz;
pullup (weak1) pad_pu (pad);
assign sig_in = pad === 1'bz ? 1'b1 : pad; 

endmodule

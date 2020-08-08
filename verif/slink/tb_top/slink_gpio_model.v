module slink_gpio_model(
  input  wire     oen,
  output wire     sig_in,
  inout  wire     pad
);


assign pad    = oen ? 1'b0 : 1'bz;
assign sig_in = pad === 1'bz ? 1'b1 : pad; 

endmodule

#!/bin/bash

gen_regs_py -i slink_apb_axi_regs.txt -p slink -b apb_axi -cm slink_clock_mux -dm slink_demet_reset
#gen_regs_py -i slink_ctrl_regs.txt -p slink -b ctrl -sphinx > ../../docs/source/regs.rst
#gen_regs_py -i slink_ctrl_regs.txt -p slink -b ctrl -dv 
#mv slink_ctrl_addr_defines.vh ../../verif/slink/tests/
#rm slink_ctrl_dv.txt

gen_inst -t slink_apb_axi_regs_top -of ../slink_apb_axi_gpio_top.v -gen_wires -wire_only

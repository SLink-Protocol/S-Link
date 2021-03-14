#!/bin/bash

gen_regs_py -i slink_bist_regs.txt -p slink -b bist -cm slink_clock_mux -dm slink_demet_reset
gen_regs_py -i slink_bist_regs.txt -p slink -b bist -sphinx > ../../../docs/source/bist_regs.rst
gen_regs_py -i slink_bist_regs.txt -p slink -b bist -dv 
##mv slink_bist_addr_defines.vh ../../../verif/slink/tests/
##rm slink_bist_dv.txt

gen_inst -t slink_bist_regs_top -of ../slink_bist.v -gen_wires -wire_only

#!/bin/bash

# -t <test>, also creates the test_<seed>.log

log="-lvvp.log"
jobname="slink_test"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--test) test="$2"; shift ;;
        -c|--compile) compargs="$2"; shift ;;
        -p|--plusarg) plusargs="$2"; shift ;;
        -l|--log)     log="-l$2"; shift;  ;;
        -r|--regress)  regress="$2"; shift;  ;;
        -jn|--job_name) jobname="$2"; shift; ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done


if test $test; then
  echo "Running test $test"
else
  echo "No test defined! running sanity_test"
  test="sanity_test"
fi



VVP_FILE=slink_apb_tb
SLINK_TOP=../../..





rm -rf $VVP_FILE


#Compile
iverilog -g2012 \
  -DSIMULATION \
  -I$SLINK_TOP/rtl \
  $SLINK_TOP/rtl/*.v \
  $SLINK_TOP/rtl/bist/*.v \
  $SLINK_TOP/rtl/serdes/*.v \
  $SLINK_TOP/rtl/tech/*.v \
  $SLINK_TOP/rtl/app/*.v \
  $SLINK_TOP/rtl/app/amba/*apb*.v \
  $SLINK_TOP/verif/slink/sub/slink_cfg.v \
  $SLINK_TOP/verif/slink_apb/tb_top/slink_apb_tb_top.v \
  $SLINK_TOP/verif/slink/tb_top/serdes_phy_model.v \
  $SLINK_TOP/verif/slink/tb_top/slink_simple_io_phy_model.v \
  $SLINK_TOP/verif/slink/tb_top/slink_gpio_model.v \
  $SLINK_TOP/verif/slink/tb_top/slink_b2b_tb_wrapper.v \
  $SLINK_TOP/verif/slink/sub/slink_app_monitor.v \
  $SLINK_TOP/verif/slink/sub/slink_app_driver.v \
  $SLINK_TOP/verif/slink/sub/slink_apb_driver.v \
  $SLINK_TOP/verif/slink_apb/sub/slink_apb_app_driver_monitor.v \
  -I$SLINK_TOP/verif/slink/sub \
  -I$SLINK_TOP/verif/slink/tests \
  -I$SLINK_TOP/verif/slink/tb_top \
  $compargs \
  -o $VVP_FILE
  

if [ -z $regress ] 
then
  # Running local
  
  if test -f "$VVP_FILE"; then
    vvp -n $log $VVP_FILE +SLINK_TEST=$test $plusargs $nosave -lxt2-speed
  else
    echo "$VVP_FILE doesn't exists."
  fi
else 
  # Copies the vvp file to the dir and creates a run script to call
  
  echo "Saving $VVP_FILE to regress dir $regress"
  cp $VVP_FILE $regress/$VVP_FILE
  touch $regress/runme.sh
  echo "#!/bin/sh" >> $regress/runme.sh
  echo "#SBATCH --job-name=$jobname" >> $regress/runme.sh
  echo "#SBATCH --ntasks=1" >> $regress/runme.sh
  echo "#SBATCH --cpus-per-task=1" >> $regress/runme.sh
  echo "vvp -n $log $VVP_FILE +SLINK_TEST=$test $plusargs +NO_WAVES" >> $regress/runme.sh
  chmod +x $regress/runme.sh
fi

import os
import sys
import random
import datetime
import re
import subprocess

yr  = datetime.date.today().strftime("%Y")
day = datetime.date.today().strftime("%d")
mon = datetime.date.today().strftime("%B")
t   = datetime.datetime.now().strftime("%H:%M:%S")

rdir = './regressions/{}-{}-{}_{}'.format(mon, day, yr, t)

topdir = os.getcwd()


numlanes = [1, 2, 4, 8]               # Max number of lanes
phywidth = [8, 16]                    # Phy widht to Serdes/IO
appfact  = [1, 2]                     # App data width multiple factor (based on numlanes * phywidth)

#numlanes = [8]
#phywidth = [8]
#appfact  = [1]

compile_opts = []
# This makes a shit ton of tests and will grow as we add
# more lane and phy width support

# For the app width, we need to figure out the minimum then do the factors
# since one direction can be smaller than the other you can't just go on 
for txl in numlanes:
  for rxl in numlanes:
    for mphy in phywidth:       #MPHY BAD!!! lol jk........or am I?
      for sphy in phywidth:     #I called it first MIPI!
        for mapp in appfact:
          for sapp in appfact:
            comp  = '-DMAX_TX_LANES={} -DMAX_RX_LANES={} '.format(str(txl), str(rxl))
            comp += '-DMST_PHY_DATA_WIDTH={} -DSLV_PHY_DATA_WIDTH={} '.format(str(mphy), str(sphy))
            comp += '-DMST_TX_APP_DATA_WIDTH={} -DMST_RX_APP_DATA_WIDTH={} '.format(str(txl*mphy*mapp), str(rxl*mphy*mapp))
            comp += '-DSLV_TX_APP_DATA_WIDTH={} -DSLV_RX_APP_DATA_WIDTH={} '.format(str(rxl*sphy*sapp), str(txl*sphy*sapp))
            compile_opts.append(comp)

for c in compile_opts:
  print(c)
print(len(compile_opts))
#sys.exit()

tests = {'sanity_test'            : 1,
         'pstate_sanity'          : 1,
         #'random_packets'         : 1,
         'link_width_change'      : 1,
         'ecc_correction'         : 1,
         'ecc_corruption'         : 1,
         'slink_force_reset'      : 1,
         'slink_force_hard_reset' : 1}

#tests = {'sanity_test'            : 1}
tests = {'ecc_corruption'            : 3, 'ecc_corruption'            : 3}

for comp in compile_opts:
  csub = re.sub(r'[^0-9a-zA-Z]+', '_', comp)
  for test in tests:
    for i in range(tests[test]):
      test_dir = '{}/{}__{}___run{}'.format(rdir, test, csub, str(i))
      jobname  = test+'__'+csub
      os.makedirs(test_dir)
      
      # Now call simulate.sh with the regression flag passed to compile with
      # the options and save
      
      p = subprocess.Popen(['./simulate.sh', '-t', test, '-c', comp, '-r', test_dir, '-jn', jobname, '-p', '+SEED={}'.format(str(random.randint(0, 9999999)))], stdout=subprocess.PIPE)
      for l in p.stdout:
        print(l)
      p.wait()
      
      os.chdir(test_dir)
      
      p = subprocess.Popen(['sbatch','-c 1',  'runme.sh'])
      p.wait()

      os.chdir(topdir)
      




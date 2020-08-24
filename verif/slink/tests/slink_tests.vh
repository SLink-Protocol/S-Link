/*
.rst_start
Tests
-----
.rst_end
*/



//Collection of tasks that we would define as a "test"
//This will also hold some typical software routines

`include "slink_includes.vh"
`include "slink_ctrl_addr_defines.vh"


slink_cfg   cfg();

task clr_swreset;
  `sim_info($display("Clearing SW reset"))
  driver_m2s.clr_swreset;
  driver_s2m.clr_swreset;
endtask


task en_slink;
  `sim_info($display("Enabling S-Link"))
  driver_m2s.en_slink;
  driver_s2m.en_slink;
endtask




/*
Called at tb_top to "select" a test to run
*/
task slink_test_select;
  int seed_check;
  int bla;
 
  reg [8*40:1] mytest;
  mytest = "sanity_test";
  
  if($value$plusargs("SLINK_TEST=%s", mytest)) begin
  end
  
  if($value$plusargs("SEED=%d", seed_check)) begin
    `sim_info($display("Seed for this run is %d", seed_check))
    bla = $urandom(seed_check);    
  end
  
  //Pre-Test
  clr_swreset;
  #20ns;
  en_slink;
  
   
  case(mytest)
    "sanity_test"             : sanity_test;
    "pstate_sanity"           : pstate_sanity;
    "random_packets"          : random_packets;
    "link_width_change"       : link_width_change;
    "slink_force_reset"       : slink_force_reset;
    "slink_force_hard_reset"  : slink_force_hard_reset;
    "bist_test"               : bist_test;
    
    "ecc_correction"          : ecc_correction;
    "ecc_corruption"          : ecc_corruption;
    default                   : sanity_test;
  endcase
  
  #100ns;
  
  //Test Error Checking
  driver_m2s.monitor.finalCheck;
  driver_m2s.finalCheck;
  
  driver_s2m.monitor.finalCheck;
  driver_s2m.finalCheck;
  
  `sim_info($display("End of simulation"))
  
endtask



/****************************************
.rst_start
sanity_test
+++++++++++
Just brings up the link and send a few packets. Commonly
used for trying out specific usecases
.rst_end
/****************************************/
task sanity_test;
  bit [31:0] val;
  int        delay_ns;
  `sim_info($display("Starting sanity_test"))
  
  driver_m2s.sendShortPacket('ha, 'h1234);
    
  #10ns;
  driver_m2s.sendLongPacket('h22, 1);
  #10ns;
  driver_m2s.sendLongPacket('h22, 2);
  #10ns;
  driver_m2s.sendLongPacket('h22, 3);
  #10ns;
  driver_m2s.sendLongPacket('h22, 4);
  driver_m2s.sendLongPacket('h22, 5);
  
  #10ns;
  driver_m2s.sendLongPacket('h22, 16);
  driver_m2s.sendLongPacket('h22, 17);
  driver_m2s.sendLongPacket('h22, 18);
  
  #10ns;
  for(int i = 1; i < 53; i++) begin
    driver_m2s.sendLongPacket('h22, i);
    #1ps;
  end
  

endtask


/****************************************
.rst_start
pstate_sanity
+++++++++++++
Sends some packets and goes into each P state
.rst_end
/*****************************************/
task pstate_sanity;
  `sim_info($display("P-State Sanity"))
  driver_m2s.sendShortPacket('ha, 'h1234);
  
  driver_m2s.enterP1;
  
  #1us;
  
  driver_m2s.wakeup_link;
  
  driver_m2s.sendShortPacket('hb, 'h0001);
  #1us;
  driver_m2s.sendRandomLongPacket;
  #1us;
  driver_m2s.sendShortPacket('hb, 'hbeef);
  
  
  driver_m2s.enterP2;
  
  #10us;
  
  driver_m2s.wakeup_link;
  
  driver_m2s.sendShortPacket('hb, 'h0001);
  #1us;
  driver_m2s.sendRandomLongPacket;
  #1us;
  driver_m2s.sendShortPacket('hb, 'hbeef);
  
  
  driver_m2s.enterP3;
  
  #10us;
  
  driver_m2s.wakeup_link;
  
  driver_m2s.sendShortPacket('hb, 'h0001);
  #1us;
  driver_m2s.sendRandomLongPacket;
  #1us;
  driver_m2s.sendShortPacket('hb, 'hbeef);
  
  
endtask





int random_pkts;
int random_delay;

/****************************************
.rst_start
random_packets
++++++++++++++
Brings up the link and sends a random number of packets
.rst_end
/*****************************************/
task random_packets;

  `sim_info($display("Starting random_packets"))
  if($value$plusargs("PKTS=%d", random_pkts)) begin
  end else begin
    random_pkts = 20 + {$urandom} % (50 - 20);
  end
  
  //randomized
  repeat(random_pkts) begin
    fork
      driver_m2s.sendRandomShortPacket;
      driver_s2m.sendRandomShortPacket;
    join
  end

  #100ns;

  repeat(random_pkts) begin
    fork
      driver_m2s.sendRandomLongPacket;
      driver_s2m.sendRandomLongPacket;
    join
    random_delay = 1 + {$urandom} % (20 - 1);
    #(random_delay * 1ns);
  end
  
  #1us;

endtask


/****************************************
.rst_start
link_width_change
+++++++++++++++++
- Bring up link
- Send some packets
- Randomly change the link width while active
- Go to lower P1 state
- wakeup and send some random packets
.rst_end
/*****************************************/
task link_width_change;

  int tx_lanes_rand;
  int rx_lanes_rand;

  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join  
  
  
  repeat(5) begin
  
    tx_lanes_rand = 0 + {$urandom} % (($clog2(NUM_TX_LANES)+1) - 0);
    rx_lanes_rand = 0 + {$urandom} % (($clog2(NUM_RX_LANES)+1) - 0);
    
    `sim_info($display("Setting TX lanes to %2d and RX lanes to %2d", 1<<tx_lanes_rand, 1<<rx_lanes_rand))
    
    driver_m2s.write_far_end_attr(ATTR_ACTIVE_TXS, rx_lanes_rand);
    driver_m2s.write_far_end_attr(ATTR_ACTIVE_RXS, tx_lanes_rand);

    driver_m2s.write_local_attr  (ATTR_ACTIVE_TXS, tx_lanes_rand);
    driver_m2s.write_local_attr  (ATTR_ACTIVE_RXS, rx_lanes_rand);
    
    cfg.randomize_cfg();
    
    driver_m2s.write_local_attr  (ATTR_P1_TS1_TX, cfg.m_attr_p1_ts1_tx);
    driver_m2s.write_local_attr  (ATTR_P1_TS1_TX, cfg.m_attr_p1_ts1_rx);
    driver_m2s.write_local_attr  (ATTR_P1_TS2_TX, cfg.m_attr_p1_ts2_tx);
    driver_m2s.write_local_attr  (ATTR_P1_TS2_TX, cfg.m_attr_p1_ts2_rx);
    
    driver_m2s.write_far_end_attr(ATTR_P1_TS1_TX, cfg.s_attr_p1_ts1_tx);
    driver_m2s.write_far_end_attr(ATTR_P1_TS1_TX, cfg.s_attr_p1_ts1_rx);
    driver_m2s.write_far_end_attr(ATTR_P1_TS2_TX, cfg.s_attr_p1_ts2_tx);
    driver_m2s.write_far_end_attr(ATTR_P1_TS2_TX, cfg.s_attr_p1_ts2_rx);
    

    driver_m2s.enterP1;
    #1us;    
    driver_m2s.wakeup_link;


    fork
      begin
        //repeat(20) begin
        for(int i=0; i < 20; i++) begin
          if($urandom % 2) begin
            driver_m2s.sendRandomShortPacket;
          end else begin
            driver_m2s.sendRandomLongPacket;
          end
        end
      end
      
      begin
        //repeat(20) begin
        for(int i=0; i < 20; i++) begin
          if($urandom % 2) begin
            driver_s2m.sendRandomShortPacket;
          end else begin
            driver_s2m.sendRandomLongPacket;
          end
        end
      end
    join
    
  
  end
  
  
endtask


/****************************************
.rst_start
slink_force_reset
+++++++++++++++++
Bring up slink and force a reset through SW. Wake link
back up and see if we can send packets again
.rst_end
/*****************************************/
task slink_force_reset;
  
  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join  
  
  driver_m2s.set_slink_reset;
  
  #200ns;
  
  driver_m2s.wakeup_link;
  
  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join 
  
endtask



/****************************************
.rst_start
slink_force_hard_reset
+++++++++++++++++++++++
- Bring up slink and send some packets
- Write some attributes to non-default values
- Perform a HARD reset
- Read those attributes to see if they are back to defaults
- Wake up link and send some packets
.rst_end
/*****************************************/
task slink_force_hard_reset;
  bit [31:0] val;
  
  cfg.randomize_cfg();
  
  // Send some packets
  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join  
  
  driver_m2s.write_local_attr  (ATTR_P1_TS1_TX, 'd4);
  driver_m2s.write_local_attr  (ATTR_P1_TS1_RX, 'd4);
  driver_m2s.write_local_attr  (ATTR_P1_TS2_TX, 'd4);
  driver_m2s.write_local_attr  (ATTR_P1_TS2_RX, 'd4);
  
  driver_m2s.write_local_attr  (ATTR_HARD_RESET_US, cfg.hard_reset_time_us);
  driver_m2s.write_far_end_attr(ATTR_HARD_RESET_US, cfg.hard_reset_time_us);
  
  //go low power state to take new settings
  driver_m2s.enterP1;
  driver_m2s.wakeup_link;
  
  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join 
  
  
  //Perform HARD Reset and check
  driver_m2s.set_slink_reset;
  #((cfg.hard_reset_time_us+1) * 1us);
  
  // See if the attributes were reset MAKE THIS BETTER)
  driver_m2s.read_local_attr   (ATTR_P1_TS1_TX, val);
  if(val == 'd4) begin
    `sim_error($display("attr not reset!"))
  end
  
  
  driver_m2s.wakeup_link;
  
  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join 
  
endtask


/**********************************************************************************
  ___   ___   ___   _____ 
 | _ ) |_ _| / __| |_   _|
 | _ \  | |  \__ \   | |  
 |___/ |___| |___/   |_|  
                          
**********************************************************************************/
task bist_test;
  
  fork
    driver_m2s.sendRandomShortPacket;
    driver_s2m.sendRandomShortPacket;
  join
  fork
    driver_m2s.sendRandomLongPacket;
    driver_s2m.sendRandomLongPacket;
  join 
  
  cfg.randomize_cfg;
  
  #100ns;
  
  driver_m2s.clr_bist_swreset;
  driver_s2m.clr_bist_swreset;
  
  driver_m2s.set_bist_active;
  driver_s2m.set_bist_active;
  
  driver_m2s.program_bist('d9,
                          'd1,
                          'h10,
                          'h30,
                          'd1,
                          'h20,
                          'h30);
  driver_s2m.program_bist('d8,
                          'd1,
                          'h10,
                          'h30,
                          'd1,
                          'h20,
                          'h30);
  driver_m2s.en_bist_rx;
  driver_s2m.en_bist_rx;
  
  #250ns;
  
  driver_m2s.en_bist_tx;
  driver_s2m.en_bist_tx;
  
  #250ns;
  
  driver_m2s.check_bist_locked;
  driver_s2m.check_bist_locked;
  
  #10us;
  driver_m2s.check_bist_errors;
  driver_s2m.check_bist_errors;
  
endtask


/**********************************************************************************
  ___                             ___            _              _     _              
 | __|  _ _   _ _   ___   _ _    |_ _|  _ _     (_)  ___   __  | |_  (_)  ___   _ _  
 | _|  | '_| | '_| / _ \ | '_|    | |  | ' \    | | / -_) / _| |  _| | | / _ \ | ' \ 
 |___| |_|   |_|   \___/ |_|     |___| |_||_|  _/ | \___| \__|  \__| |_| \___/ |_||_|
                                              |__/                                  
**********************************************************************************/

/****************************************
.rst_start
ecc_correction
++++++++++++++
Corrupts one of the Packet Header, looks to see if this error
was seen in the monitor. The receiving side should have receieved the
packet with no errors since one bit error should be resolvable.
.rst_end
/*****************************************/
task ecc_correction;
  reg [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0] bit_corrupt;
  
  driver_s2m.ignore_ecc_correct_errors = 1;
  
  fork
    begin
      driver_m2s.sendRandomShortPacket;
    end
    begin
      wait((u_slink_MASTER.u_slink_ll_tx.state == 'd1) && 
           (u_slink_MASTER.u_slink_ll_tx.sop == 1'b1) &&
           (u_slink_MASTER.u_slink_ll_tx.delim_start == 1'b1)); //wait for it to not be idle
      #1ps;

      bit_corrupt = ph_err_inj(u_slink_MASTER.u_slink_ll_tx.link_data_reg_in, 0);
      force u_slink_MASTER.u_slink_ll_tx.link_data_reg_in = bit_corrupt;
      @(posedge u_slink_MASTER.u_slink_ll_tx.clk);
      release u_slink_MASTER.u_slink_ll_tx.link_data_reg_in;
      
    end
  join
  
  #1us;
  
  if(driver_s2m.ecc_correct_count != 1) begin
    `sim_info($display("ECC Correction was not seen in the montior!"))
  end
  
  //Try to send normal data
  driver_m2s.sendRandomShortPacket;
  driver_m2s.sendRandomLongPacket;
endtask


/****************************************
.rst_start
ecc_corruption
++++++++++++++
Corrupts two bits of the Packet Header, looks to see if this error
was seen in the monitor. Allows the link to reset then checks to 
see if a valid packet can be sent to indicate recovery.
.rst_end
/*****************************************/
task ecc_corruption;
  reg [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0] bit_corrupt;
  
  driver_s2m.ignore_ecc_corrupt_errors = 1;
  driver_m2s.dis_monitor;
  driver_s2m.dis_monitor;
  
  fork
    begin
      driver_m2s.sendRandomShortPacket;
    end
    begin
      wait((u_slink_MASTER.u_slink_ll_tx.state == 'd1) && 
           (u_slink_MASTER.u_slink_ll_tx.sop == 1'b1) &&
           (u_slink_MASTER.u_slink_ll_tx.delim_start == 1'b1)); //wait for it to not be idle
      #1ps;

      bit_corrupt = ph_err_inj(u_slink_MASTER.u_slink_ll_tx.link_data_reg_in, 1);
      force u_slink_MASTER.u_slink_ll_tx.link_data_reg_in = bit_corrupt;
      @(posedge u_slink_MASTER.u_slink_ll_tx.clk);
      release u_slink_MASTER.u_slink_ll_tx.link_data_reg_in;
      
    end
  join
  
  #1us;
  
  if(driver_s2m.ecc_corrupt_count != 1) begin
    `sim_info($display("ECC Corruption was not seen in the montior!"))
  end
  
  //Try to send a packet with no error to see recovery
  driver_s2m.ignore_ecc_corrupt_errors = 0;
  driver_m2s.en_monitor;
  driver_s2m.en_monitor;
  
  driver_m2s.sendRandomShortPacket;
  driver_m2s.sendRandomLongPacket;
  
endtask



function bit[(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0] ph_err_inj;
  input [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0] ph_orig;
  input                                         corr;     //0 - 1bit, 1 - 2 bits
  
  reg [(NUM_TX_LANES*MST_PHY_DATA_WIDTH)-1:0] bit_corrupt;
  
  case(NUM_TX_LANES)
    1 : begin
      case(MST_PHY_DATA_WIDTH)
        8  : bit_corrupt   = 0 + {$urandom} % ((8-corr) - 0);
        16 : bit_corrupt   = 0 + {$urandom} % ((16-corr) - 0);
        32 : bit_corrupt   = 0 + {$urandom} % ((32-corr) - 0);
      endcase
    end

    2 : begin
      case(MST_PHY_DATA_WIDTH)
        8  : bit_corrupt   = 0 + {$urandom} % ((16-corr) - 0);
        16 : bit_corrupt   = 0 + {$urandom} % ((32-corr) - 0);
        32 : begin
          case($urandom % 4) //ph byte select
            0,2 : bit_corrupt   = 0  + {$urandom} % ((16-corr) - 0);
            1,3 : bit_corrupt   = 32 + {$urandom} % ((48-corr) - 32);
          endcase
        end
      endcase
    end

    default : begin
      case(MST_PHY_DATA_WIDTH)
        8  : bit_corrupt   = 0 + {$urandom} % ((32-corr) - 0);
        16 : begin
          case($urandom % 4) //ph byte select
            0 : bit_corrupt   = 0  + {$urandom} % ((8-corr) - 0);
            1 : bit_corrupt   = 16 + {$urandom} % ((24-corr) - 16);
            2 : bit_corrupt   = 32 + {$urandom} % ((40-corr) - 32);
            3 : bit_corrupt   = 48 + {$urandom} % ((56-corr) - 48);
          endcase
        end
        32 : begin
          case($urandom % 4) //ph byte select
            0 : bit_corrupt   = 0  + {$urandom} % ((8-corr) - 0);
            1 : bit_corrupt   = 32 + {$urandom} % ((40-corr) - 32);
            2 : bit_corrupt   = 64 + {$urandom} % ((72-corr) - 64);
            3 : bit_corrupt   = 96 + {$urandom} % ((104-corr) - 96);
          endcase
        end
      endcase
    end
  endcase
  
  if(corr) begin
    `sim_info($display("Bits [%0d:%0d] of the Packet Header will be corrupted", bit_corrupt+1, bit_corrupt))
  end else begin
    `sim_info($display("Bit %0d of the Packet Header will be corrupted", bit_corrupt))
  end
  
  
  
  if(corr) begin
    bit_corrupt   = ph_orig ^ (3 << bit_corrupt);
  end else begin
    bit_corrupt   = ph_orig ^ (1 << bit_corrupt);
  end
  
  `sim_info($display("Original Packet Header: %h  New: %h", ph_orig, bit_corrupt))
  
  ph_err_inj = bit_corrupt;
  
endfunction

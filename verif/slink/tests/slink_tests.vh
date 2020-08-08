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
    
    //"ecc_correction"          : ecc_correction;
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
  
  #10ns;
  for(int i = 1; i < 25; i++) begin
    driver_m2s.sendLongPacket('h22, i);
    #10ns;
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
  
  //Perform hard reset  
  driver_m2s.set_slink_reset;
  
  #(cfg.hard_reset_time_us * 1ns);
  
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
  ___                             ___            _              _     _              
 | __|  _ _   _ _   ___   _ _    |_ _|  _ _     (_)  ___   __  | |_  (_)  ___   _ _  
 | _|  | '_| | '_| / _ \ | '_|    | |  | ' \    | | / -_) / _| |  _| | | / _ \ | ' \ 
 |___| |_|   |_|   \___/ |_|     |___| |_||_|  _/ | \___| \__|  \__| |_| \___/ |_||_|
                                              |__/                                  
**********************************************************************************/

// task ecc_correction;
//   reg [(NUM_TX_LANES*8)-1:0] bit_corrupt;
//   reg [(NUM_TX_LANES*8)-1:0] orig_bit_val;
//   
//   //For now just corrupting a single bit in lane0
//   fork
//     begin
//       driver_m2s.sendRandomShortPacket;
//     end
//     begin
//       wait((u_slink_MASTER.u_slink_ll_tx.state == 'd1) && 
//            (u_slink_MASTER.u_slink_ll_tx.sop == 1'b1)); //wait for it to not be idle
//       #1ps;
//       bit_corrupt   = 0 + {$urandom} % (8 - 0);
//       orig_bit_val  = u_slink_MASTER.u_slink_ll_tx.link_data_reg_in;
//       bit_corrupt   = orig_bit_val ^ (1 << bit_corrupt);
//       `sim_info($display("old: %2h new: %2h", orig_bit_val, bit_corrupt))
//       force u_slink_MASTER.u_slink_ll_tx.link_data_reg_in = bit_corrupt;
//       @(posedge u_slink_MASTER.u_slink_ll_tx.clk);
//       release u_slink_MASTER.u_slink_ll_tx.link_data_reg_in;
//     end
//   join
//   
//   #50us;
// endtask

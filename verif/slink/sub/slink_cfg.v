// Acts as a "config" object similar to UVM for holding
// randomized values

module slink_cfg;

`include "slink_msg.v"
`include "slink_includes.vh"

  localparam      MIN_TS1   = 'd16,
                  MAX_TS1   = 'd256,
                  MIN_TS2   = 'd4,
                  MAX_TS2   = 'd512;

  bit [15:0]      m_attr_p1_ts1_tx;
  bit [15:0]      m_attr_p1_ts1_rx;
  bit [15:0]      m_attr_p1_ts2_tx;
  bit [15:0]      m_attr_p1_ts2_rx;
  
  bit [15:0]      m_attr_p2_ts1_tx;
  bit [15:0]      m_attr_p2_ts1_rx;
  bit [15:0]      m_attr_p2_ts2_tx;
  bit [15:0]      m_attr_p2_ts2_rx;
  
  bit [15:0]      m_attr_p3r_ts1_tx;
  bit [15:0]      m_attr_p3r_ts1_rx;
  bit [15:0]      m_attr_p3r_ts2_tx;
  bit [15:0]      m_attr_p3r_ts2_rx;
  
  
  bit [15:0]      s_attr_p1_ts1_tx;
  bit [15:0]      s_attr_p1_ts1_rx;
  bit [15:0]      s_attr_p1_ts2_tx;
  bit [15:0]      s_attr_p1_ts2_rx;
  
  bit [15:0]      s_attr_p2_ts1_tx;
  bit [15:0]      s_attr_p2_ts1_rx;
  bit [15:0]      s_attr_p2_ts2_tx;
  bit [15:0]      s_attr_p2_ts2_rx;
  
  bit [15:0]      s_attr_p3r_ts1_tx;
  bit [15:0]      s_attr_p3r_ts1_rx;
  bit [15:0]      s_attr_p3r_ts2_tx;
  bit [15:0]      s_attr_p3r_ts2_rx;
  
  
  localparam      HARD_RESET_MIN  = 'd5,
                  HARD_RESET_MAX  = 'd150;
  
  bit [9:0]       hard_reset_time_us;
  
  bit [3:0]       bist_mode_payload;
  bit             bist_mode_wc;
  bit [15:0]      bist_wc_min;
  bit [15:0]      bist_wc_max;
  bit             bist_mode_di;
  bit [7:0]       bist_di_min;
  bit [7:0]       bist_di_max;
  
  
  task randomize_cfg;
    
    m_attr_p1_ts1_tx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    m_attr_p1_ts1_rx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    m_attr_p1_ts2_tx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);
    m_attr_p1_ts2_rx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);

    m_attr_p2_ts1_tx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    m_attr_p2_ts1_rx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    m_attr_p2_ts2_tx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);
    m_attr_p2_ts2_rx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);

    m_attr_p3r_ts1_tx = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    m_attr_p3r_ts1_rx = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    m_attr_p3r_ts2_tx = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);
    m_attr_p3r_ts2_rx = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);


    s_attr_p1_ts1_tx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    s_attr_p1_ts1_rx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    s_attr_p1_ts2_tx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);
    s_attr_p1_ts2_rx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);

    s_attr_p2_ts1_tx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    s_attr_p2_ts1_rx  = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    s_attr_p2_ts2_tx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);
    s_attr_p2_ts2_rx  = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);

    s_attr_p3r_ts1_tx = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    s_attr_p3r_ts1_rx = MIN_TS1 + {$urandom} % (MAX_TS1 - MIN_TS1);
    s_attr_p3r_ts2_tx = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);
    s_attr_p3r_ts2_rx = MIN_TS2 + {$urandom} % (MAX_TS2 - MIN_TS2);    
    
    hard_reset_time_us = HARD_RESET_MIN + {$urandom} % (HARD_RESET_MAX - HARD_RESET_MIN);
    
    
    $display("------------------------------------------");
    `sim_info($display("S-Link Config Parameters:"))
    $display("m_attr_p1_ts1_tx  = %6d",  m_attr_p1_ts1_tx );
    $display("m_attr_p1_ts1_rx  = %6d",  m_attr_p1_ts1_rx );
    $display("m_attr_p1_ts2_tx  = %6d",  m_attr_p1_ts2_tx );
    $display("m_attr_p1_ts2_rx  = %6d",  m_attr_p1_ts2_rx );

    $display("m_attr_p2_ts1_tx  = %6d",  m_attr_p2_ts1_tx );
    $display("m_attr_p2_ts1_rx  = %6d",  m_attr_p2_ts1_rx );
    $display("m_attr_p2_ts2_tx  = %6d",  m_attr_p2_ts2_tx );
    $display("m_attr_p2_ts2_rx  = %6d",  m_attr_p2_ts2_rx );

    $display("m_attr_p3r_ts1_tx = %6d",  m_attr_p3r_ts1_tx);
    $display("m_attr_p3r_ts1_rx = %6d",  m_attr_p3r_ts1_rx);
    $display("m_attr_p3r_ts2_tx = %6d",  m_attr_p3r_ts2_tx);
    $display("m_attr_p3r_ts2_rx = %6d",  m_attr_p3r_ts2_rx);


    $display("s_attr_p1_ts1_tx  = %6d",  s_attr_p1_ts1_tx );
    $display("s_attr_p1_ts1_rx  = %6d",  s_attr_p1_ts1_rx );
    $display("s_attr_p1_ts2_tx  = %6d",  s_attr_p1_ts2_tx );
    $display("s_attr_p1_ts2_rx  = %6d",  s_attr_p1_ts2_rx );

    $display("s_attr_p2_ts1_tx  = %6d",  s_attr_p2_ts1_tx );
    $display("s_attr_p2_ts1_rx  = %6d",  s_attr_p2_ts1_rx );
    $display("s_attr_p2_ts2_tx  = %6d",  s_attr_p2_ts2_tx );
    $display("s_attr_p2_ts2_rx  = %6d",  s_attr_p2_ts2_rx );

    $display("s_attr_p3r_ts1_tx = %6d",  s_attr_p3r_ts1_tx);
    $display("s_attr_p3r_ts1_rx = %6d",  s_attr_p3r_ts1_rx);
    $display("s_attr_p3r_ts2_tx = %6d",  s_attr_p3r_ts2_tx);
    $display("s_attr_p3r_ts2_rx = %6d",  s_attr_p3r_ts2_rx);
    
    $display("hard_reset_time_us = %6d(us)",  hard_reset_time_us);
    
    $display("------------------------------------------");
  
  endtask

endmodule

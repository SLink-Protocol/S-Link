// Includes to make life easier, I generally don't like include files but sometimes they make sense

localparam    TSX_BYTE0 = 8'hbc;
localparam    TS1_BYTEX = 8'h55;
localparam    TS2_BYTEX = 8'haa;
localparam    SDS_BYTE0 = 8'hdc;
localparam    SDS_BYTEX = 8'hab;


//Short NOP Packet
localparam    NOP_DATAID = 8'h01,
              NOP_WC0    = 8'hfe,
              NOP_WC1    = 8'hfd;

localparam    IDL_SYM    = 8'h00;

localparam    ONE_LANE       = 'd0,
              TWO_LANE       = 'd1,
              FOUR_LANE      = 'd2,
              EIGHT_LANE     = 'd3,
              SIXTEEN_LANE   = 'd4;

//Attribute Packet commands
localparam    ATTR_ADDR       = 8'h02,
              ATTR_DATA       = 8'h03,
              ATTR_REQ        = 8'h04,
              ATTR_RSP        = 8'h05;

//Pstate commands
//WC is the requested state
localparam    PX_REQ          = 8'h06,    //Request P State
              //PX_ACC          = 8'h06,    //Accept P State Request
              //PX_REJ          = 8'h07,    //Reject P State request
              PX_START        = 8'h08;    //Last packet before end of transmission


//Attribute addresses
localparam    ATTR_MAX_TXS    = 16'h0,
              ATTR_MAX_RXS    = 16'h1,
              ATTR_ACTIVE_TXS = 16'h2,
              ATTR_ACTIVE_RXS = 16'h3,
              
              ATTR_HARD_RESET_US  = 16'h8,
              
              ATTR_P1_TS1_TX  = 16'h20,
              ATTR_P1_TS1_RX  = 16'h21,
              ATTR_P1_TS2_TX  = 16'h22,
              ATTR_P1_TS2_RX  = 16'h23,
              
              ATTR_P2_TS1_TX  = 16'h24,
              ATTR_P2_TS1_RX  = 16'h25,
              ATTR_P2_TS2_TX  = 16'h26,
              ATTR_P2_TS2_RX  = 16'h27,
              
              ATTR_P3R_TS1_TX  = 16'h28,
              ATTR_P3R_TS1_RX  = 16'h29,
              ATTR_P3R_TS2_TX  = 16'h2a,
              ATTR_P3R_TS2_RX  = 16'h2b;

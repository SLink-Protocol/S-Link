// Includes to make life easier, I generally don't like include files but sometimes they make sense

localparam    TS1_BYTE0 = 8'h1e,
              TS1_BYTEX = 8'h55,  
              TS2_BYTE0 = 8'h2d,  
              TS2_BYTEX = 8'haa,  
              SDS_BYTE0 = 8'he1,  
              SDS_BYTEX = 8'hab;  


localparam    SNYC_B0   = 8'h00;
localparam    SNYC_B1   = 8'hff;


localparam    SH_DATA   = 2'b10;
localparam    SH_CTRL   = 2'b01;


//PState OS
localparam    P1_REQ_B0   = 8'hd1, 
              P2_REQ_B0   = 8'hd2,
              P3_REQ_B0   = 8'hd3,
              P_START_B0  = 8'hd8,
              PX_FILLER   = 8'h76;

//Attr OS
localparam    ATTR_RD_B0  = 8'ha0,
              ATTR_WR_B0  = 8'ha1,
              ATTR_RSP_B0 = 8'ha3,
              ATTR_FILLER = 8'h17;


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



localparam    BIST_PAYLOAD_1010       = 4'h0,
              BIST_PAYLOAD_1100       = 4'h1,
              BIST_PAYLOAD_1111_0000  = 4'h2,
              BIST_PAYLOAD_COUNT      = 4'h8,
              BIST_PAYLOAD_PRBS9      = 4'h9,
              BIST_PAYLOAD_PRBS11     = 4'ha,
              BIST_PAYLOAD_PRBS18     = 4'hb;


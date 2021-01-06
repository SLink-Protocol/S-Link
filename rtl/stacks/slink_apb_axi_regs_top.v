//===================================================================
//
// Created by sbridges on January/04/2021 at 15:54:32
//
// slink_apb_axi_regs_top.v
//
//===================================================================



module slink_apb_axi_regs_top #(
  parameter    PSTATE_CTRL_ENABLE_RESET_PARAM = 1'h1,
  parameter    ADDR_WIDTH = 8
)(
  //APB_APP_ENABLE
  input  wire         apb_app_enable,
  output wire         swi_apb_app_enable_muxed,
  //AXI_APP_ENABLE
  input  wire         axi_app_enable,
  output wire         swi_axi_app_enable_muxed,
  //INT_APP_ENABLE
  input  wire         int_app_enable,
  output wire         swi_int_app_enable_muxed,
  //INTERRUPT_STATUS
  input  wire         w1c_in_apb_nack_seen,
  output wire         w1c_out_apb_nack_seen,
  input  wire         w1c_in_apb_nack_sent,
  output wire         w1c_out_apb_nack_sent,
  input  wire         w1c_in_int_nack_seen,
  output wire         w1c_out_int_nack_seen,
  input  wire         w1c_in_int_nack_sent,
  output wire         w1c_out_int_nack_sent,
  //PSTATE_CONTROL
  output wire [7:0]   swi_tick_1us,
  output wire [7:0]   swi_inactivity_count,
  output wire [2:0]   swi_pstate_req,
  output wire         swi_pstate_ctrl_enable,
  //APB_APP_CREDIT_IDS
  output wire [7:0]   swi_apb_cr_id,
  output wire [7:0]   swi_apb_crack_id,
  output wire [7:0]   swi_apb_ack_id,
  output wire [7:0]   swi_apb_nack_id,
  //INT_APP_CREDIT_IDS
  output wire [7:0]   swi_int_cr_id,
  output wire [7:0]   swi_int_crack_id,
  output wire [7:0]   swi_int_ack_id,
  output wire [7:0]   swi_int_nack_id,
  //INT_APP_PKT_ID_WC
  output wire [7:0]   swi_int_data_id,
  output wire [15:0]  swi_int_word_count,
  //DEBUG_BUS_STATUS
  output reg  [31:0]  debug_bus_ctrl_status,

  //DFT Ports (if used)
  
  // APB Interface
  input  wire RegReset,
  input  wire RegClk,
  input  wire PSEL,
  input  wire PENABLE,
  input  wire PWRITE,
  output wire PSLVERR,
  output wire PREADY,
  input  wire [(ADDR_WIDTH-1):0] PADDR,
  input  wire [31:0] PWDATA,
  output wire [31:0] PRDATA
);
  
  //DFT Tieoffs (if not used)
  wire dft_core_scan_mode = 1'b0;
  wire dft_iddq_mode = 1'b0;
  wire dft_hiz_mode = 1'b0;
  wire dft_bscan_mode = 1'b0;

  //APB Setup/Access 
  wire [(ADDR_WIDTH-1):0] RegAddr_in;
  reg  [(ADDR_WIDTH-1):0] RegAddr;
  wire [31:0] RegWrData_in;
  reg  [31:0] RegWrData;
  wire RegWrEn_in;
  reg  RegWrEn_pq;
  wire RegWrEn;

  assign RegAddr_in = PSEL ? PADDR : RegAddr; 

  always @(posedge RegClk or posedge RegReset) begin
    if (RegReset) begin
      RegAddr <= {(ADDR_WIDTH){1'b0}};
    end else begin
      RegAddr <= RegAddr_in;
    end
  end

  assign RegWrData_in = PSEL ? PWDATA : RegWrData; 

  always @(posedge RegClk or posedge RegReset) begin
    if (RegReset) begin
      RegWrData <= 32'h00000000;
    end else begin
      RegWrData <= RegWrData_in;
    end
  end

  assign RegWrEn_in = PSEL & PWRITE;

  always @(posedge RegClk or posedge RegReset) begin
    if (RegReset) begin
      RegWrEn_pq <= 1'b0;
    end else begin
      RegWrEn_pq <= RegWrEn_in;
    end
  end

  assign RegWrEn = RegWrEn_pq & PENABLE;
  
  //assign PSLVERR = 1'b0;
  assign PREADY  = 1'b1;
  


  //Regs for Mux Override sel
  reg  reg_apb_app_enable_mux;
  reg  reg_axi_app_enable_mux;
  reg  reg_int_app_enable_mux;



  //---------------------------
  // APB_APP_ENABLE
  // apb_app_enable - Enables the APB Application Layer    
  // apb_app_enable_mux - 1 - Use regsiter, 0 - use external logic
  //---------------------------
  wire [31:0] APB_APP_ENABLE_reg_read;
  reg          reg_apb_app_enable;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_apb_app_enable                     <= 1'h0;
      reg_apb_app_enable_mux                 <= 1'h0;
    end else if(RegAddr == 'h0 && RegWrEn) begin
      reg_apb_app_enable                     <= RegWrData[0];
      reg_apb_app_enable_mux                 <= RegWrData[1];
    end else begin
      reg_apb_app_enable                     <= reg_apb_app_enable;
      reg_apb_app_enable_mux                 <= reg_apb_app_enable_mux;
    end
  end

  assign APB_APP_ENABLE_reg_read = {30'h0,
          reg_apb_app_enable_mux,
          reg_apb_app_enable};

  //-----------------------

  wire        swi_apb_app_enable_muxed_pre;
  slink_clock_mux u_slink_clock_mux_apb_app_enable (
    .clk0    ( apb_app_enable                     ),              
    .clk1    ( reg_apb_app_enable                 ),              
    .sel     ( reg_apb_app_enable_mux             ),      
    .clk_out ( swi_apb_app_enable_muxed_pre       )); 

  assign swi_apb_app_enable_muxed = swi_apb_app_enable_muxed_pre;

  //-----------------------




  //---------------------------
  // AXI_APP_ENABLE
  // axi_app_enable - Enables the AXI Application Layer
  // axi_app_enable_mux - 1 - Use regsiter, 0 - use external logic
  //---------------------------
  wire [31:0] AXI_APP_ENABLE_reg_read;
  reg          reg_axi_app_enable;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_axi_app_enable                     <= 1'h0;
      reg_axi_app_enable_mux                 <= 1'h0;
    end else if(RegAddr == 'h4 && RegWrEn) begin
      reg_axi_app_enable                     <= RegWrData[0];
      reg_axi_app_enable_mux                 <= RegWrData[1];
    end else begin
      reg_axi_app_enable                     <= reg_axi_app_enable;
      reg_axi_app_enable_mux                 <= reg_axi_app_enable_mux;
    end
  end

  assign AXI_APP_ENABLE_reg_read = {30'h0,
          reg_axi_app_enable_mux,
          reg_axi_app_enable};

  //-----------------------

  wire        swi_axi_app_enable_muxed_pre;
  slink_clock_mux u_slink_clock_mux_axi_app_enable (
    .clk0    ( axi_app_enable                     ),              
    .clk1    ( reg_axi_app_enable                 ),              
    .sel     ( reg_axi_app_enable_mux             ),      
    .clk_out ( swi_axi_app_enable_muxed_pre       )); 

  assign swi_axi_app_enable_muxed = swi_axi_app_enable_muxed_pre;

  //-----------------------




  //---------------------------
  // INT_APP_ENABLE
  // int_app_enable - Enables the Interrupt/GPIO Application Layer
  // int_app_enable_mux - 1 - Use regsiter, 0 - use external logic
  //---------------------------
  wire [31:0] INT_APP_ENABLE_reg_read;
  reg          reg_int_app_enable;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_int_app_enable                     <= 1'h0;
      reg_int_app_enable_mux                 <= 1'h0;
    end else if(RegAddr == 'h8 && RegWrEn) begin
      reg_int_app_enable                     <= RegWrData[0];
      reg_int_app_enable_mux                 <= RegWrData[1];
    end else begin
      reg_int_app_enable                     <= reg_int_app_enable;
      reg_int_app_enable_mux                 <= reg_int_app_enable_mux;
    end
  end

  assign INT_APP_ENABLE_reg_read = {30'h0,
          reg_int_app_enable_mux,
          reg_int_app_enable};

  //-----------------------

  wire        swi_int_app_enable_muxed_pre;
  slink_clock_mux u_slink_clock_mux_int_app_enable (
    .clk0    ( int_app_enable                     ),              
    .clk1    ( reg_int_app_enable                 ),              
    .sel     ( reg_int_app_enable_mux             ),      
    .clk_out ( swi_int_app_enable_muxed_pre       )); 

  assign swi_int_app_enable_muxed = swi_int_app_enable_muxed_pre;

  //-----------------------




  //---------------------------
  // INTERRUPT_STATUS
  // apb_nack_seen - APB Nack has been seen on this application layer (far-end saw an issue)
  // apb_nack_sent - APB Nack has been sent from this application layer (near-end saw an issue)
  // int_nack_seen - INT Nack has been seen on this application layer (far-end saw an issue)
  // int_nack_sent - INT Nack has been sent from this application layer (near-end saw an issue)
  //---------------------------
  wire [31:0] INTERRUPT_STATUS_reg_read;
  reg          reg_w1c_apb_nack_seen;
  wire         reg_w1c_in_apb_nack_seen_ff2;
  reg          reg_w1c_in_apb_nack_seen_ff3;
  reg          reg_w1c_apb_nack_sent;
  wire         reg_w1c_in_apb_nack_sent_ff2;
  reg          reg_w1c_in_apb_nack_sent_ff3;
  reg          reg_w1c_int_nack_seen;
  wire         reg_w1c_in_int_nack_seen_ff2;
  reg          reg_w1c_in_int_nack_seen_ff3;
  reg          reg_w1c_int_nack_sent;
  wire         reg_w1c_in_int_nack_sent_ff2;
  reg          reg_w1c_in_int_nack_sent_ff3;

  // apb_nack_seen W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_apb_nack_seen                     <= 1'h0;
      reg_w1c_in_apb_nack_seen_ff3              <= 1'h0;
    end else begin
      reg_w1c_apb_nack_seen                     <= RegWrData[0] && reg_w1c_apb_nack_seen && (RegAddr == 'hc) && RegWrEn ? 1'b0 : (reg_w1c_in_apb_nack_seen_ff2 & ~reg_w1c_in_apb_nack_seen_ff3 ? 1'b1 : reg_w1c_apb_nack_seen);
      reg_w1c_in_apb_nack_seen_ff3              <= reg_w1c_in_apb_nack_seen_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_apb_nack_seen (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_apb_nack_seen                       ),            
    .sig_out ( reg_w1c_in_apb_nack_seen_ff2               )); 


  // apb_nack_sent W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_apb_nack_sent                     <= 1'h0;
      reg_w1c_in_apb_nack_sent_ff3              <= 1'h0;
    end else begin
      reg_w1c_apb_nack_sent                     <= RegWrData[1] && reg_w1c_apb_nack_sent && (RegAddr == 'hc) && RegWrEn ? 1'b0 : (reg_w1c_in_apb_nack_sent_ff2 & ~reg_w1c_in_apb_nack_sent_ff3 ? 1'b1 : reg_w1c_apb_nack_sent);
      reg_w1c_in_apb_nack_sent_ff3              <= reg_w1c_in_apb_nack_sent_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_apb_nack_sent (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_apb_nack_sent                       ),            
    .sig_out ( reg_w1c_in_apb_nack_sent_ff2               )); 


  // int_nack_seen W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_int_nack_seen                     <= 1'h0;
      reg_w1c_in_int_nack_seen_ff3              <= 1'h0;
    end else begin
      reg_w1c_int_nack_seen                     <= RegWrData[2] && reg_w1c_int_nack_seen && (RegAddr == 'hc) && RegWrEn ? 1'b0 : (reg_w1c_in_int_nack_seen_ff2 & ~reg_w1c_in_int_nack_seen_ff3 ? 1'b1 : reg_w1c_int_nack_seen);
      reg_w1c_in_int_nack_seen_ff3              <= reg_w1c_in_int_nack_seen_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_int_nack_seen (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_int_nack_seen                       ),            
    .sig_out ( reg_w1c_in_int_nack_seen_ff2               )); 


  // int_nack_sent W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_int_nack_sent                     <= 1'h0;
      reg_w1c_in_int_nack_sent_ff3              <= 1'h0;
    end else begin
      reg_w1c_int_nack_sent                     <= RegWrData[3] && reg_w1c_int_nack_sent && (RegAddr == 'hc) && RegWrEn ? 1'b0 : (reg_w1c_in_int_nack_sent_ff2 & ~reg_w1c_in_int_nack_sent_ff3 ? 1'b1 : reg_w1c_int_nack_sent);
      reg_w1c_in_int_nack_sent_ff3              <= reg_w1c_in_int_nack_sent_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_int_nack_sent (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_int_nack_sent                       ),            
    .sig_out ( reg_w1c_in_int_nack_sent_ff2               )); 

  assign INTERRUPT_STATUS_reg_read = {28'h0,
          reg_w1c_int_nack_sent,
          reg_w1c_int_nack_seen,
          reg_w1c_apb_nack_sent,
          reg_w1c_apb_nack_seen};

  //-----------------------
  assign w1c_out_apb_nack_seen = reg_w1c_apb_nack_seen;
  //-----------------------
  assign w1c_out_apb_nack_sent = reg_w1c_apb_nack_sent;
  //-----------------------
  assign w1c_out_int_nack_seen = reg_w1c_int_nack_seen;
  //-----------------------
  assign w1c_out_int_nack_sent = reg_w1c_int_nack_sent;




  //---------------------------
  // PSTATE_CONTROL
  // tick_1us - Number of refclk cycles to equal 1us
  // inactivity_count - Number of microseconds before starting a PState transition
  // pstate_req - PState to transition to. If multiple bits are set, the lowest is used. [0] - P1, [1] - P2, [2] - P3.
  // pstate_ctrl_enable - Enables the PSTATE Controller
  //---------------------------
  wire [31:0] PSTATE_CONTROL_reg_read;
  reg [7:0]   reg_tick_1us;
  reg [7:0]   reg_inactivity_count;
  reg [2:0]   reg_pstate_req;
  reg         reg_pstate_ctrl_enable;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_tick_1us                           <= 8'h27;
      reg_inactivity_count                   <= 8'h5;
      reg_pstate_req                         <= 3'h2;
      reg_pstate_ctrl_enable                 <= PSTATE_CTRL_ENABLE_RESET_PARAM;
    end else if(RegAddr == 'h10 && RegWrEn) begin
      reg_tick_1us                           <= RegWrData[7:0];
      reg_inactivity_count                   <= RegWrData[15:8];
      reg_pstate_req                         <= RegWrData[18:16];
      reg_pstate_ctrl_enable                 <= RegWrData[19];
    end else begin
      reg_tick_1us                           <= reg_tick_1us;
      reg_inactivity_count                   <= reg_inactivity_count;
      reg_pstate_req                         <= reg_pstate_req;
      reg_pstate_ctrl_enable                 <= reg_pstate_ctrl_enable;
    end
  end

  assign PSTATE_CONTROL_reg_read = {12'h0,
          reg_pstate_ctrl_enable,
          reg_pstate_req,
          reg_inactivity_count,
          reg_tick_1us};

  //-----------------------
  assign swi_tick_1us = reg_tick_1us;

  //-----------------------
  assign swi_inactivity_count = reg_inactivity_count;

  //-----------------------
  assign swi_pstate_req = reg_pstate_req;

  //-----------------------
  assign swi_pstate_ctrl_enable = reg_pstate_ctrl_enable;





  //---------------------------
  // APB_APP_CREDIT_IDS
  // apb_cr_id - Credit Request Data ID for APB Application Channel
  // apb_crack_id - Credit Request Data Acknowledgement ID for APB Application Channel
  // apb_ack_id - Acknowledgement ID for APB Application Channel
  // apb_nack_id - Non-Acknowledgement ID for APB Application Channel
  //---------------------------
  wire [31:0] APB_APP_CREDIT_IDS_reg_read;
  reg [7:0]   reg_apb_cr_id;
  reg [7:0]   reg_apb_crack_id;
  reg [7:0]   reg_apb_ack_id;
  reg [7:0]   reg_apb_nack_id;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_apb_cr_id                          <= 8'h20;
      reg_apb_crack_id                       <= 8'h21;
      reg_apb_ack_id                         <= 8'h22;
      reg_apb_nack_id                        <= 8'h23;
    end else if(RegAddr == 'h14 && RegWrEn) begin
      reg_apb_cr_id                          <= RegWrData[7:0];
      reg_apb_crack_id                       <= RegWrData[15:8];
      reg_apb_ack_id                         <= RegWrData[23:16];
      reg_apb_nack_id                        <= RegWrData[31:24];
    end else begin
      reg_apb_cr_id                          <= reg_apb_cr_id;
      reg_apb_crack_id                       <= reg_apb_crack_id;
      reg_apb_ack_id                         <= reg_apb_ack_id;
      reg_apb_nack_id                        <= reg_apb_nack_id;
    end
  end

  assign APB_APP_CREDIT_IDS_reg_read = {          reg_apb_nack_id,
          reg_apb_ack_id,
          reg_apb_crack_id,
          reg_apb_cr_id};

  //-----------------------
  assign swi_apb_cr_id = reg_apb_cr_id;

  //-----------------------
  assign swi_apb_crack_id = reg_apb_crack_id;

  //-----------------------
  assign swi_apb_ack_id = reg_apb_ack_id;

  //-----------------------
  assign swi_apb_nack_id = reg_apb_nack_id;





  //---------------------------
  // INT_APP_CREDIT_IDS
  // int_cr_id - Credit Request Data ID for INT Application Channel
  // int_crack_id - Credit Request Data Acknowledgement ID for INT Application Channel
  // int_ack_id - Acknowledgement ID for INT Application Channel
  // int_nack_id - Non-Acknowledgement ID for INT Application Channel
  //---------------------------
  wire [31:0] INT_APP_CREDIT_IDS_reg_read;
  reg [7:0]   reg_int_cr_id;
  reg [7:0]   reg_int_crack_id;
  reg [7:0]   reg_int_ack_id;
  reg [7:0]   reg_int_nack_id;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_int_cr_id                          <= 8'h30;
      reg_int_crack_id                       <= 8'h31;
      reg_int_ack_id                         <= 8'h32;
      reg_int_nack_id                        <= 8'h33;
    end else if(RegAddr == 'h18 && RegWrEn) begin
      reg_int_cr_id                          <= RegWrData[7:0];
      reg_int_crack_id                       <= RegWrData[15:8];
      reg_int_ack_id                         <= RegWrData[23:16];
      reg_int_nack_id                        <= RegWrData[31:24];
    end else begin
      reg_int_cr_id                          <= reg_int_cr_id;
      reg_int_crack_id                       <= reg_int_crack_id;
      reg_int_ack_id                         <= reg_int_ack_id;
      reg_int_nack_id                        <= reg_int_nack_id;
    end
  end

  assign INT_APP_CREDIT_IDS_reg_read = {          reg_int_nack_id,
          reg_int_ack_id,
          reg_int_crack_id,
          reg_int_cr_id};

  //-----------------------
  assign swi_int_cr_id = reg_int_cr_id;

  //-----------------------
  assign swi_int_crack_id = reg_int_crack_id;

  //-----------------------
  assign swi_int_ack_id = reg_int_ack_id;

  //-----------------------
  assign swi_int_nack_id = reg_int_nack_id;





  //---------------------------
  // INT_APP_PKT_ID_WC
  // int_data_id - INT Data ID
  // int_word_count - INT Word Count
  //---------------------------
  wire [31:0] INT_APP_PKT_ID_WC_reg_read;
  reg [7:0]   reg_int_data_id;
  reg [15:0]  reg_int_word_count;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_int_data_id                        <= 8'h34;
      reg_int_word_count                     <= 16'h3;
    end else if(RegAddr == 'h1c && RegWrEn) begin
      reg_int_data_id                        <= RegWrData[7:0];
      reg_int_word_count                     <= RegWrData[23:8];
    end else begin
      reg_int_data_id                        <= reg_int_data_id;
      reg_int_word_count                     <= reg_int_word_count;
    end
  end

  assign INT_APP_PKT_ID_WC_reg_read = {8'h0,
          reg_int_word_count,
          reg_int_data_id};

  //-----------------------
  assign swi_int_data_id = reg_int_data_id;

  //-----------------------
  assign swi_int_word_count = reg_int_word_count;





  //---------------------------
  // DEBUG_BUS_CTRL
  // DEBUG_BUS_CTRL_SEL - Select signal for DEBUG_BUS_CTRL
  //---------------------------
  wire [31:0] DEBUG_BUS_CTRL_reg_read;
  reg [1:0]   reg_debug_bus_ctrl_sel;
  wire [1:0]   swi_debug_bus_ctrl_sel;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_debug_bus_ctrl_sel                 <= 2'h0;
    end else if(RegAddr == 'h20 && RegWrEn) begin
      reg_debug_bus_ctrl_sel                 <= RegWrData[1:0];
    end else begin
      reg_debug_bus_ctrl_sel                 <= reg_debug_bus_ctrl_sel;
    end
  end

  assign DEBUG_BUS_CTRL_reg_read = {30'h0,
          reg_debug_bus_ctrl_sel};

  //-----------------------
  assign swi_debug_bus_ctrl_sel = reg_debug_bus_ctrl_sel;





  //---------------------------
  // DEBUG_BUS_STATUS
  // DEBUG_BUS_CTRL_STATUS - Status output for DEBUG_BUS_STATUS
  //---------------------------
  wire [31:0] DEBUG_BUS_STATUS_reg_read;

  //Debug bus control logic  
  always @(*) begin
    case(swi_debug_bus_ctrl_sel)
      'd0 : debug_bus_ctrl_status = {31'd0, swi_apb_app_enable_muxed};
      'd1 : debug_bus_ctrl_status = {31'd0, swi_axi_app_enable_muxed};
      'd2 : debug_bus_ctrl_status = {31'd0, swi_int_app_enable_muxed};
      default : debug_bus_ctrl_status = 32'd0;
    endcase
  end 
  
  assign DEBUG_BUS_STATUS_reg_read = {          debug_bus_ctrl_status};

  //-----------------------


  
    
  //---------------------------
  // PRDATA Selection
  //---------------------------
  reg [31:0] prdata_sel;
  
  always @(*) begin
    case(RegAddr)
      'h0    : prdata_sel = APB_APP_ENABLE_reg_read;
      'h4    : prdata_sel = AXI_APP_ENABLE_reg_read;
      'h8    : prdata_sel = INT_APP_ENABLE_reg_read;
      'hc    : prdata_sel = INTERRUPT_STATUS_reg_read;
      'h10   : prdata_sel = PSTATE_CONTROL_reg_read;
      'h14   : prdata_sel = APB_APP_CREDIT_IDS_reg_read;
      'h18   : prdata_sel = INT_APP_CREDIT_IDS_reg_read;
      'h1c   : prdata_sel = INT_APP_PKT_ID_WC_reg_read;
      'h20   : prdata_sel = DEBUG_BUS_CTRL_reg_read;
      'h24   : prdata_sel = DEBUG_BUS_STATUS_reg_read;

      default : prdata_sel = 32'd0;
    endcase
  end
  
  assign PRDATA = prdata_sel;


  
    
  //---------------------------
  // PSLVERR Detection
  //---------------------------
  reg pslverr_pre;
  
  always @(*) begin
    case(RegAddr)
      'h0    : pslverr_pre = 1'b0;
      'h4    : pslverr_pre = 1'b0;
      'h8    : pslverr_pre = 1'b0;
      'hc    : pslverr_pre = 1'b0;
      'h10   : pslverr_pre = 1'b0;
      'h14   : pslverr_pre = 1'b0;
      'h18   : pslverr_pre = 1'b0;
      'h1c   : pslverr_pre = 1'b0;
      'h20   : pslverr_pre = 1'b0;
      'h24   : pslverr_pre = 1'b0;

      default : pslverr_pre = 1'b1;
    endcase
  end
  
  assign PSLVERR = pslverr_pre;

endmodule

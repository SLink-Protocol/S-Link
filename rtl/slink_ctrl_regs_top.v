//===================================================================
//
// Created by steven on August/30/2020 at 11:55:35
//
// slink_ctrl_regs_top.v
//
//===================================================================



module slink_ctrl_regs_top #(
  parameter    ADDR_WIDTH = 8
)(
  //SWRESET
  output wire         swi_swreset,
  //ENABLE
  output wire         swi_enable,
  //INTERRUPT_STATUS
  input  wire         w1c_in_ecc_corrupted,
  output wire         w1c_out_ecc_corrupted,
  input  wire         w1c_in_ecc_corrected,
  output wire         w1c_out_ecc_corrected,
  input  wire         w1c_in_crc_corrupted,
  output wire         w1c_out_crc_corrupted,
  input  wire         w1c_in_reset_seen,
  output wire         w1c_out_reset_seen,
  input  wire         w1c_in_wake_seen,
  output wire         w1c_out_wake_seen,
  input  wire         w1c_in_in_pstate,
  output wire         w1c_out_in_pstate,
  //INTERRUPT_ENABLE
  output wire         swi_ecc_corrupted_int_en,
  output wire         swi_ecc_corrected_int_en,
  output wire         swi_crc_corrupted_int_en,
  output wire         swi_reset_seen_int_en,
  output wire         swi_wake_seen_int_en,
  output wire         swi_in_pstate_int_en,
  //PSTATE_CONTROL
  output wire         swi_p1_state_enter,
  output wire         swi_p2_state_enter,
  output wire         swi_p3_state_enter,
  output wire         swi_link_reset,
  output wire         swi_link_wake,
  //ERROR_CONTROL
  output wire         swi_allow_ecc_corrected,
  output wire         swi_ecc_corrected_causes_reset,
  output wire         swi_ecc_corrupted_causes_reset,
  output wire         swi_crc_corrupted_causes_reset,
  //COUNT_VAL_1US
  output wire [9:0]   swi_count_val_1us,
  //SW_ATTR_ADDR_DATA
  output wire [15:0]  swi_sw_attr_addr,
  output wire [15:0]  swi_sw_attr_wdata,
  //SW_ATTR_CONTROLS
  output wire         swi_sw_attr_write,
  output wire         swi_sw_attr_local,
  //SW_ATTR_DATA_READ
  input  wire [15:0]  rfifo_sw_attr_rdata,
  output wire         rfifo_rinc_sw_attr_rdata,
  //SW_ATTR_FIFO_STATUS
  input  wire         sw_attr_send_fifo_full,
  input  wire         sw_attr_send_fifo_empty,
  input  wire         sw_attr_recv_fifo_full,
  input  wire         sw_attr_recv_fifo_empty,
  //SW_ATTR_SHADOW_UPDATE
  output wire         wfifo_sw_attr_shadow_update,
  output wire         wfifo_winc_sw_attr_shadow_update,
  //SW_ATTR_EFFECTIVE_UPDATE
  output wire         wfifo_sw_attr_effective_update,
  output wire         wfifo_winc_sw_attr_effective_update,
  //STATE_STATUS
  input  wire [4:0]   ltssm_state,
  input  wire [3:0]   ll_tx_state,
  input  wire [3:0]   ll_rx_state,
  input  wire [1:0]   deskew_state,
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



  //---------------------------
  // SWRESET
  // swreset - Main reset. Must be cleared prior to operation. 
  //---------------------------
  wire [31:0] SWRESET_reg_read;
  reg         reg_swreset;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_swreset                            <= 1'h1;
    end else if(RegAddr == 'h0 && RegWrEn) begin
      reg_swreset                            <= RegWrData[0];
    end else begin
      reg_swreset                            <= reg_swreset;
    end
  end

  assign SWRESET_reg_read = {31'h0,
          reg_swreset};

  //-----------------------
  assign swi_swreset = reg_swreset;





  //---------------------------
  // ENABLE
  // enable - Main enable. Must be set prior to operation. Any configurations should be performed prior to enabling.
  //---------------------------
  wire [31:0] ENABLE_reg_read;
  reg         reg_enable;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_enable                             <= 1'h0;
    end else if(RegAddr == 'h4 && RegWrEn) begin
      reg_enable                             <= RegWrData[0];
    end else begin
      reg_enable                             <= reg_enable;
    end
  end

  assign ENABLE_reg_read = {31'h0,
          reg_enable};

  //-----------------------
  assign swi_enable = reg_enable;





  //---------------------------
  // INTERRUPT_STATUS
  // ecc_corrupted - Indicates that a packet header was received with the ECC corrupted.
  // ecc_corrected - Indicates that a packet header was received with the ECC corrected.
  // crc_corrupted - Indicates that a long packet was received and the received CRC did not match the calculated CRC based on the payload.
  // reset_seen - Indicates a reset condition was seen
  // wake_seen - Indicates a wake condition was seen
  // in_pstate - Indicates the link has entered into a P state (only asserts on entry)
  //---------------------------
  wire [31:0] INTERRUPT_STATUS_reg_read;
  reg          reg_w1c_ecc_corrupted;
  wire         reg_w1c_in_ecc_corrupted_ff2;
  reg          reg_w1c_in_ecc_corrupted_ff3;
  reg          reg_w1c_ecc_corrected;
  wire         reg_w1c_in_ecc_corrected_ff2;
  reg          reg_w1c_in_ecc_corrected_ff3;
  reg          reg_w1c_crc_corrupted;
  wire         reg_w1c_in_crc_corrupted_ff2;
  reg          reg_w1c_in_crc_corrupted_ff3;
  reg          reg_w1c_reset_seen;
  wire         reg_w1c_in_reset_seen_ff2;
  reg          reg_w1c_in_reset_seen_ff3;
  reg          reg_w1c_wake_seen;
  wire         reg_w1c_in_wake_seen_ff2;
  reg          reg_w1c_in_wake_seen_ff3;
  reg          reg_w1c_in_pstate;
  wire         reg_w1c_in_in_pstate_ff2;
  reg          reg_w1c_in_in_pstate_ff3;

  // ecc_corrupted W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_ecc_corrupted                     <= 1'h0;
      reg_w1c_in_ecc_corrupted_ff3              <= 1'h0;
    end else begin
      reg_w1c_ecc_corrupted                     <= RegWrData[0] && reg_w1c_ecc_corrupted && (RegAddr == 'h8) && RegWrEn ? 1'b0 : (reg_w1c_in_ecc_corrupted_ff2 & ~reg_w1c_in_ecc_corrupted_ff3 ? 1'b1 : reg_w1c_ecc_corrupted);
      reg_w1c_in_ecc_corrupted_ff3              <= reg_w1c_in_ecc_corrupted_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_ecc_corrupted (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_ecc_corrupted                       ),            
    .sig_out ( reg_w1c_in_ecc_corrupted_ff2               )); 


  // ecc_corrected W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_ecc_corrected                     <= 1'h0;
      reg_w1c_in_ecc_corrected_ff3              <= 1'h0;
    end else begin
      reg_w1c_ecc_corrected                     <= RegWrData[1] && reg_w1c_ecc_corrected && (RegAddr == 'h8) && RegWrEn ? 1'b0 : (reg_w1c_in_ecc_corrected_ff2 & ~reg_w1c_in_ecc_corrected_ff3 ? 1'b1 : reg_w1c_ecc_corrected);
      reg_w1c_in_ecc_corrected_ff3              <= reg_w1c_in_ecc_corrected_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_ecc_corrected (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_ecc_corrected                       ),            
    .sig_out ( reg_w1c_in_ecc_corrected_ff2               )); 


  // crc_corrupted W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_crc_corrupted                     <= 1'h0;
      reg_w1c_in_crc_corrupted_ff3              <= 1'h0;
    end else begin
      reg_w1c_crc_corrupted                     <= RegWrData[2] && reg_w1c_crc_corrupted && (RegAddr == 'h8) && RegWrEn ? 1'b0 : (reg_w1c_in_crc_corrupted_ff2 & ~reg_w1c_in_crc_corrupted_ff3 ? 1'b1 : reg_w1c_crc_corrupted);
      reg_w1c_in_crc_corrupted_ff3              <= reg_w1c_in_crc_corrupted_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_crc_corrupted (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_crc_corrupted                       ),            
    .sig_out ( reg_w1c_in_crc_corrupted_ff2               )); 


  // reset_seen W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_reset_seen                        <= 1'h0;
      reg_w1c_in_reset_seen_ff3                 <= 1'h0;
    end else begin
      reg_w1c_reset_seen                        <= RegWrData[3] && reg_w1c_reset_seen && (RegAddr == 'h8) && RegWrEn ? 1'b0 : (reg_w1c_in_reset_seen_ff2 & ~reg_w1c_in_reset_seen_ff3 ? 1'b1 : reg_w1c_reset_seen);
      reg_w1c_in_reset_seen_ff3                 <= reg_w1c_in_reset_seen_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_reset_seen (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_reset_seen                          ),            
    .sig_out ( reg_w1c_in_reset_seen_ff2                  )); 


  // wake_seen W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_wake_seen                         <= 1'h0;
      reg_w1c_in_wake_seen_ff3                  <= 1'h0;
    end else begin
      reg_w1c_wake_seen                         <= RegWrData[4] && reg_w1c_wake_seen && (RegAddr == 'h8) && RegWrEn ? 1'b0 : (reg_w1c_in_wake_seen_ff2 & ~reg_w1c_in_wake_seen_ff3 ? 1'b1 : reg_w1c_wake_seen);
      reg_w1c_in_wake_seen_ff3                  <= reg_w1c_in_wake_seen_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_wake_seen (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_wake_seen                           ),            
    .sig_out ( reg_w1c_in_wake_seen_ff2                   )); 


  // in_pstate W1C Logic
  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_w1c_in_pstate                         <= 1'h0;
      reg_w1c_in_in_pstate_ff3                  <= 1'h0;
    end else begin
      reg_w1c_in_pstate                         <= RegWrData[5] && reg_w1c_in_pstate && (RegAddr == 'h8) && RegWrEn ? 1'b0 : (reg_w1c_in_in_pstate_ff2 & ~reg_w1c_in_in_pstate_ff3 ? 1'b1 : reg_w1c_in_pstate);
      reg_w1c_in_in_pstate_ff3                  <= reg_w1c_in_in_pstate_ff2;
    end
  end

  slink_demet_reset u_slink_demet_reset_in_pstate (
    .clk     ( RegClk                                     ),              
    .reset   ( RegReset                                   ),              
    .sig_in  ( w1c_in_in_pstate                           ),            
    .sig_out ( reg_w1c_in_in_pstate_ff2                   )); 

  assign INTERRUPT_STATUS_reg_read = {26'h0,
          reg_w1c_in_pstate,
          reg_w1c_wake_seen,
          reg_w1c_reset_seen,
          reg_w1c_crc_corrupted,
          reg_w1c_ecc_corrected,
          reg_w1c_ecc_corrupted};

  //-----------------------
  assign w1c_out_ecc_corrupted = reg_w1c_ecc_corrupted;
  //-----------------------
  assign w1c_out_ecc_corrected = reg_w1c_ecc_corrected;
  //-----------------------
  assign w1c_out_crc_corrupted = reg_w1c_crc_corrupted;
  //-----------------------
  assign w1c_out_reset_seen = reg_w1c_reset_seen;
  //-----------------------
  assign w1c_out_wake_seen = reg_w1c_wake_seen;
  //-----------------------
  assign w1c_out_in_pstate = reg_w1c_in_pstate;




  //---------------------------
  // INTERRUPT_ENABLE
  // ecc_corrupted_int_en - Enables the ecc_corrupted interrupt
  // ecc_corrected_int_en - Enables the ecc_corrected interrupt
  // crc_corrupted_int_en - Enables the crc_corrupted interrupt
  // reset_seen_int_en - Enables the reset_seen interrupt
  // wake_seen_int_en - Enables the wake_seen interrupt
  // in_pstate_int_en - Enables the in_pstate interrupt
  //---------------------------
  wire [31:0] INTERRUPT_ENABLE_reg_read;
  reg         reg_ecc_corrupted_int_en;
  reg         reg_ecc_corrected_int_en;
  reg         reg_crc_corrupted_int_en;
  reg         reg_reset_seen_int_en;
  reg         reg_wake_seen_int_en;
  reg         reg_in_pstate_int_en;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_ecc_corrupted_int_en               <= 1'h1;
      reg_ecc_corrected_int_en               <= 1'h1;
      reg_crc_corrupted_int_en               <= 1'h1;
      reg_reset_seen_int_en                  <= 1'h1;
      reg_wake_seen_int_en                   <= 1'h0;
      reg_in_pstate_int_en                   <= 1'h0;
    end else if(RegAddr == 'hc && RegWrEn) begin
      reg_ecc_corrupted_int_en               <= RegWrData[0];
      reg_ecc_corrected_int_en               <= RegWrData[1];
      reg_crc_corrupted_int_en               <= RegWrData[2];
      reg_reset_seen_int_en                  <= RegWrData[3];
      reg_wake_seen_int_en                   <= RegWrData[4];
      reg_in_pstate_int_en                   <= RegWrData[5];
    end else begin
      reg_ecc_corrupted_int_en               <= reg_ecc_corrupted_int_en;
      reg_ecc_corrected_int_en               <= reg_ecc_corrected_int_en;
      reg_crc_corrupted_int_en               <= reg_crc_corrupted_int_en;
      reg_reset_seen_int_en                  <= reg_reset_seen_int_en;
      reg_wake_seen_int_en                   <= reg_wake_seen_int_en;
      reg_in_pstate_int_en                   <= reg_in_pstate_int_en;
    end
  end

  assign INTERRUPT_ENABLE_reg_read = {26'h0,
          reg_in_pstate_int_en,
          reg_wake_seen_int_en,
          reg_reset_seen_int_en,
          reg_crc_corrupted_int_en,
          reg_ecc_corrected_int_en,
          reg_ecc_corrupted_int_en};

  //-----------------------
  assign swi_ecc_corrupted_int_en = reg_ecc_corrupted_int_en;

  //-----------------------
  assign swi_ecc_corrected_int_en = reg_ecc_corrected_int_en;

  //-----------------------
  assign swi_crc_corrupted_int_en = reg_crc_corrupted_int_en;

  //-----------------------
  assign swi_reset_seen_int_en = reg_reset_seen_int_en;

  //-----------------------
  assign swi_wake_seen_int_en = reg_wake_seen_int_en;

  //-----------------------
  assign swi_in_pstate_int_en = reg_in_pstate_int_en;





  //---------------------------
  // PSTATE_CONTROL
  // p1_state_enter - Set to enter P1 power state
  // p2_state_enter - Set to enter P2 power state
  // p3_state_enter - Set to enter P3 power state
  // reserved0 - 
  // link_reset - Forces the link to the reset state for both sides of the link
  // link_wake - Forces the link to wake up to P0 without a packet being available
  //---------------------------
  wire [31:0] PSTATE_CONTROL_reg_read;
  reg         reg_p1_state_enter;
  reg         reg_p2_state_enter;
  reg         reg_p3_state_enter;
  reg         reg_link_reset;
  reg         reg_link_wake;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_p1_state_enter                     <= 1'h0;
      reg_p2_state_enter                     <= 1'h0;
      reg_p3_state_enter                     <= 1'h0;
      reg_link_reset                         <= 1'h0;
      reg_link_wake                          <= 1'h0;
    end else if(RegAddr == 'h10 && RegWrEn) begin
      reg_p1_state_enter                     <= RegWrData[0];
      reg_p2_state_enter                     <= RegWrData[1];
      reg_p3_state_enter                     <= RegWrData[2];
      reg_link_reset                         <= RegWrData[30];
      reg_link_wake                          <= RegWrData[31];
    end else begin
      reg_p1_state_enter                     <= reg_p1_state_enter;
      reg_p2_state_enter                     <= reg_p2_state_enter;
      reg_p3_state_enter                     <= reg_p3_state_enter;
      reg_link_reset                         <= reg_link_reset;
      reg_link_wake                          <= reg_link_wake;
    end
  end

  assign PSTATE_CONTROL_reg_read = {          reg_link_wake,
          reg_link_reset,
          27'd0, //Reserved
          reg_p3_state_enter,
          reg_p2_state_enter,
          reg_p1_state_enter};

  //-----------------------
  assign swi_p1_state_enter = reg_p1_state_enter;

  //-----------------------
  assign swi_p2_state_enter = reg_p2_state_enter;

  //-----------------------
  assign swi_p3_state_enter = reg_p3_state_enter;

  //-----------------------
  //-----------------------
  assign swi_link_reset = reg_link_reset;

  //-----------------------
  assign swi_link_wake = reg_link_wake;





  //---------------------------
  // ERROR_CONTROL
  // allow_ecc_corrected - 1 - ECC Corrected conditions will not block the Packet Header from going to the application layer
  // ecc_corrected_causes_reset - 1 - ECC Corrected will cause S-Link to reset. This should not be set if allow_ecc_corrected is set
  // ecc_corrupted_causes_reset - 1 - ECC Corrupted condition will cause S-Link to reset.
  // crc_corrupted_causes_reset - 1 - CRC Corrupted condition will cause S-Link to reset.
  //---------------------------
  wire [31:0] ERROR_CONTROL_reg_read;
  reg         reg_allow_ecc_corrected;
  reg         reg_ecc_corrected_causes_reset;
  reg         reg_ecc_corrupted_causes_reset;
  reg         reg_crc_corrupted_causes_reset;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_allow_ecc_corrected                <= 1'h1;
      reg_ecc_corrected_causes_reset         <= 1'h0;
      reg_ecc_corrupted_causes_reset         <= 1'h1;
      reg_crc_corrupted_causes_reset         <= 1'h0;
    end else if(RegAddr == 'h14 && RegWrEn) begin
      reg_allow_ecc_corrected                <= RegWrData[0];
      reg_ecc_corrected_causes_reset         <= RegWrData[1];
      reg_ecc_corrupted_causes_reset         <= RegWrData[2];
      reg_crc_corrupted_causes_reset         <= RegWrData[3];
    end else begin
      reg_allow_ecc_corrected                <= reg_allow_ecc_corrected;
      reg_ecc_corrected_causes_reset         <= reg_ecc_corrected_causes_reset;
      reg_ecc_corrupted_causes_reset         <= reg_ecc_corrupted_causes_reset;
      reg_crc_corrupted_causes_reset         <= reg_crc_corrupted_causes_reset;
    end
  end

  assign ERROR_CONTROL_reg_read = {28'h0,
          reg_crc_corrupted_causes_reset,
          reg_ecc_corrupted_causes_reset,
          reg_ecc_corrected_causes_reset,
          reg_allow_ecc_corrected};

  //-----------------------
  assign swi_allow_ecc_corrected = reg_allow_ecc_corrected;

  //-----------------------
  assign swi_ecc_corrected_causes_reset = reg_ecc_corrected_causes_reset;

  //-----------------------
  assign swi_ecc_corrupted_causes_reset = reg_ecc_corrupted_causes_reset;

  //-----------------------
  assign swi_crc_corrupted_causes_reset = reg_crc_corrupted_causes_reset;





  //---------------------------
  // COUNT_VAL_1US
  // count_val_1us - Number of REFCLK cycles that equal 1us.
  //---------------------------
  wire [31:0] COUNT_VAL_1US_reg_read;
  reg [9:0]   reg_count_val_1us;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_count_val_1us                      <= 10'h26;
    end else if(RegAddr == 'h18 && RegWrEn) begin
      reg_count_val_1us                      <= RegWrData[9:0];
    end else begin
      reg_count_val_1us                      <= reg_count_val_1us;
    end
  end

  assign COUNT_VAL_1US_reg_read = {22'h0,
          reg_count_val_1us};

  //-----------------------
  assign swi_count_val_1us = reg_count_val_1us;





  //---------------------------
  // SW_ATTR_ADDR_DATA
  // sw_attr_addr - Address for software based attribute updates
  // sw_attr_wdata - Data for software based attribute updates
  //---------------------------
  wire [31:0] SW_ATTR_ADDR_DATA_reg_read;
  reg [15:0]  reg_sw_attr_addr;
  reg [15:0]  reg_sw_attr_wdata;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_sw_attr_addr                       <= 16'h0;
      reg_sw_attr_wdata                      <= 16'h0;
    end else if(RegAddr == 'h1c && RegWrEn) begin
      reg_sw_attr_addr                       <= RegWrData[15:0];
      reg_sw_attr_wdata                      <= RegWrData[31:16];
    end else begin
      reg_sw_attr_addr                       <= reg_sw_attr_addr;
      reg_sw_attr_wdata                      <= reg_sw_attr_wdata;
    end
  end

  assign SW_ATTR_ADDR_DATA_reg_read = {          reg_sw_attr_wdata,
          reg_sw_attr_addr};

  //-----------------------
  assign swi_sw_attr_addr = reg_sw_attr_addr;

  //-----------------------
  assign swi_sw_attr_wdata = reg_sw_attr_wdata;





  //---------------------------
  // SW_ATTR_CONTROLS
  // sw_attr_write - 0 - Perform a read command. 1 - Perform a write command
  // sw_attr_local - 0 - Write/Read to far end SLink. 1 - Write/Read to local SLink
  //---------------------------
  wire [31:0] SW_ATTR_CONTROLS_reg_read;
  reg         reg_sw_attr_write;
  reg         reg_sw_attr_local;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_sw_attr_write                      <= 1'h1;
      reg_sw_attr_local                      <= 1'h1;
    end else if(RegAddr == 'h20 && RegWrEn) begin
      reg_sw_attr_write                      <= RegWrData[0];
      reg_sw_attr_local                      <= RegWrData[1];
    end else begin
      reg_sw_attr_write                      <= reg_sw_attr_write;
      reg_sw_attr_local                      <= reg_sw_attr_local;
    end
  end

  assign SW_ATTR_CONTROLS_reg_read = {30'h0,
          reg_sw_attr_local,
          reg_sw_attr_write};

  //-----------------------
  assign swi_sw_attr_write = reg_sw_attr_write;

  //-----------------------
  assign swi_sw_attr_local = reg_sw_attr_local;





  //---------------------------
  // SW_ATTR_DATA_READ
  // sw_attr_rdata - Shadow attribute data based on the sw_attr_addr value. *The sw_attr_data_read is actually only the link_clk, so it is advised to set the sw_attr_addr for several cycles prior to reading*
  //---------------------------
  wire [31:0] SW_ATTR_DATA_READ_reg_read;

  assign rfifo_rinc_sw_attr_rdata = (RegAddr == 'h24 && PENABLE && PSEL && ~(PWRITE || RegWrEn));
  assign SW_ATTR_DATA_READ_reg_read = {16'h0,
          rfifo_sw_attr_rdata};

  //-----------------------




  //---------------------------
  // SW_ATTR_FIFO_STATUS
  // sw_attr_send_fifo_full - 
  // sw_attr_send_fifo_empty - 
  // sw_attr_recv_fifo_full - 
  // sw_attr_recv_fifo_empty - 
  //---------------------------
  wire [31:0] SW_ATTR_FIFO_STATUS_reg_read;
  assign SW_ATTR_FIFO_STATUS_reg_read = {28'h0,
          sw_attr_recv_fifo_empty,
          sw_attr_recv_fifo_full,
          sw_attr_send_fifo_empty,
          sw_attr_send_fifo_full};

  //-----------------------
  //-----------------------
  //-----------------------
  //-----------------------




  //---------------------------
  // SW_ATTR_SHADOW_UPDATE
  // sw_attr_shadow_update - Write a 1 to update the current sw_attr_addr with the current sw_attr_data. If set to local, this will handle a local write, else will create a transation to the other side
  //---------------------------
  wire [31:0] SW_ATTR_SHADOW_UPDATE_reg_read;

  assign wfifo_sw_attr_shadow_update      = (RegAddr == 'h2c && RegWrEn) ? RegWrData[0] : 'd0;
  assign wfifo_winc_sw_attr_shadow_update = (RegAddr == 'h2c && RegWrEn);
  assign SW_ATTR_SHADOW_UPDATE_reg_read = {31'h0,
          1'd0}; //Reserved

  //-----------------------




  //---------------------------
  // SW_ATTR_EFFECTIVE_UPDATE
  // sw_attr_effective_update - Write a 1 to set the shadow attribute values to the effective values. This should only be used prior to removing swreset for initial config.
  //---------------------------
  wire [31:0] SW_ATTR_EFFECTIVE_UPDATE_reg_read;

  assign wfifo_sw_attr_effective_update      = (RegAddr == 'h30 && RegWrEn) ? RegWrData[0] : 'd0;
  assign wfifo_winc_sw_attr_effective_update = (RegAddr == 'h30 && RegWrEn);
  assign SW_ATTR_EFFECTIVE_UPDATE_reg_read = {31'h0,
          1'd0}; //Reserved

  //-----------------------




  //---------------------------
  // STATE_STATUS
  // ltssm_state - LTSSM State
  // reserved0 - 
  // ll_tx_state - LL TX State
  // ll_rx_state - LL RX State
  // deskew_state - Deskew State
  //---------------------------
  wire [31:0] STATE_STATUS_reg_read;
  assign STATE_STATUS_reg_read = {14'h0,
          deskew_state,
          ll_rx_state,
          ll_tx_state,
          3'd0, //Reserved
          ltssm_state};

  //-----------------------
  //-----------------------
  //-----------------------
  //-----------------------
  //-----------------------




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
    end else if(RegAddr == 'h38 && RegWrEn) begin
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
      'd0 : debug_bus_ctrl_status = {28'd0, sw_attr_recv_fifo_empty, sw_attr_recv_fifo_full, sw_attr_send_fifo_empty, sw_attr_send_fifo_full};
      'd1 : debug_bus_ctrl_status = {14'd0, deskew_state, ll_rx_state, ll_tx_state, 3'd0, ltssm_state};
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
      'h0    : prdata_sel = SWRESET_reg_read;
      'h4    : prdata_sel = ENABLE_reg_read;
      'h8    : prdata_sel = INTERRUPT_STATUS_reg_read;
      'hc    : prdata_sel = INTERRUPT_ENABLE_reg_read;
      'h10   : prdata_sel = PSTATE_CONTROL_reg_read;
      'h14   : prdata_sel = ERROR_CONTROL_reg_read;
      'h18   : prdata_sel = COUNT_VAL_1US_reg_read;
      'h1c   : prdata_sel = SW_ATTR_ADDR_DATA_reg_read;
      'h20   : prdata_sel = SW_ATTR_CONTROLS_reg_read;
      'h24   : prdata_sel = SW_ATTR_DATA_READ_reg_read;
      'h28   : prdata_sel = SW_ATTR_FIFO_STATUS_reg_read;
      'h2c   : prdata_sel = SW_ATTR_SHADOW_UPDATE_reg_read;
      'h30   : prdata_sel = SW_ATTR_EFFECTIVE_UPDATE_reg_read;
      'h34   : prdata_sel = STATE_STATUS_reg_read;
      'h38   : prdata_sel = DEBUG_BUS_CTRL_reg_read;
      'h3c   : prdata_sel = DEBUG_BUS_STATUS_reg_read;

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
      'h28   : pslverr_pre = 1'b0;
      'h2c   : pslverr_pre = 1'b0;
      'h30   : pslverr_pre = 1'b0;
      'h34   : pslverr_pre = 1'b0;
      'h38   : pslverr_pre = 1'b0;
      'h3c   : pslverr_pre = 1'b0;

      default : pslverr_pre = 1'b1;
    endcase
  end
  
  assign PSLVERR = pslverr_pre;

endmodule

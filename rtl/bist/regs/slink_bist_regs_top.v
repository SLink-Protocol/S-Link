//===================================================================
//
// Created by sbridges on December/22/2020 at 13:54:40
//
// slink_bist_regs_top.v
//
//===================================================================



module slink_bist_regs_top #(
  parameter    ADDR_WIDTH = 8
)(
  //SWRESET
  output wire         swi_swreset,
  //BIST_MAIN_CONTROL
  output wire         swi_bist_tx_en,
  output wire         swi_bist_rx_en,
  output wire         swi_bist_reset,
  output wire         swi_bist_active,
  output wire         swi_disable_clkgate,
  //BIST_MODE
  output wire [3:0]   swi_bist_mode_payload,
  output wire         swi_bist_mode_wc,
  output wire         swi_bist_mode_di,
  //BIST_WORD_COUNT_VALUES
  output wire [15:0]  swi_bist_wc_min,
  output wire [15:0]  swi_bist_wc_max,
  //BIST_DATA_ID_VALUES
  output wire [7:0]   swi_bist_di_min,
  output wire [7:0]   swi_bist_di_max,
  //BIST_STATUS
  input  wire         bist_locked,
  input  wire         bist_unrecover,
  input  wire [15:0]  bist_errors,
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
  // swreset - Main software reset for BIST logic
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
  // BIST_MAIN_CONTROL
  // bist_tx_en - Main Enable for TX. Controls clock gate for BIST logic
  // bist_rx_en - Main Enable for RX. Controls clock gate for BIST logic
  // bist_reset - Reset for clearing BIST error counters
  // bist_active - Signal exits the BIST block and can be used to control an external mux for data path.
  // disable_clkgate - 
  //---------------------------
  wire [31:0] BIST_MAIN_CONTROL_reg_read;
  reg         reg_bist_tx_en;
  reg         reg_bist_rx_en;
  reg         reg_bist_reset;
  reg         reg_bist_active;
  reg         reg_disable_clkgate;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_bist_tx_en                         <= 1'h0;
      reg_bist_rx_en                         <= 1'h0;
      reg_bist_reset                         <= 1'h0;
      reg_bist_active                        <= 1'h0;
      reg_disable_clkgate                    <= 1'h0;
    end else if(RegAddr == 'h4 && RegWrEn) begin
      reg_bist_tx_en                         <= RegWrData[0];
      reg_bist_rx_en                         <= RegWrData[1];
      reg_bist_reset                         <= RegWrData[2];
      reg_bist_active                        <= RegWrData[3];
      reg_disable_clkgate                    <= RegWrData[4];
    end else begin
      reg_bist_tx_en                         <= reg_bist_tx_en;
      reg_bist_rx_en                         <= reg_bist_rx_en;
      reg_bist_reset                         <= reg_bist_reset;
      reg_bist_active                        <= reg_bist_active;
      reg_disable_clkgate                    <= reg_disable_clkgate;
    end
  end

  assign BIST_MAIN_CONTROL_reg_read = {27'h0,
          reg_disable_clkgate,
          reg_bist_active,
          reg_bist_reset,
          reg_bist_rx_en,
          reg_bist_tx_en};

  //-----------------------
  assign swi_bist_tx_en = reg_bist_tx_en;

  //-----------------------
  assign swi_bist_rx_en = reg_bist_rx_en;

  //-----------------------
  assign swi_bist_reset = reg_bist_reset;

  //-----------------------
  assign swi_bist_active = reg_bist_active;

  //-----------------------
  assign swi_disable_clkgate = reg_disable_clkgate;





  //---------------------------
  // BIST_MODE
  // bist_mode_payload - Denotes long data payload type. 0 - 1010, 1 - 1100, 2 - 1111_0000, 8 - counter, 9 - PRBS9
  // bist_mode_wc - 0 - Always use fixed word count (wc_min). 1 - Cycle through word counts (min -> max back to min)
  // bist_mode_di - 0 - Always use fixed data id (di_min). 1 - Cycle through data id (min -> max back to min)
  //---------------------------
  wire [31:0] BIST_MODE_reg_read;
  reg [3:0]   reg_bist_mode_payload;
  reg         reg_bist_mode_wc;
  reg         reg_bist_mode_di;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_bist_mode_payload                  <= 4'h0;
      reg_bist_mode_wc                       <= 1'h0;
      reg_bist_mode_di                       <= 1'h0;
    end else if(RegAddr == 'h8 && RegWrEn) begin
      reg_bist_mode_payload                  <= RegWrData[3:0];
      reg_bist_mode_wc                       <= RegWrData[4];
      reg_bist_mode_di                       <= RegWrData[5];
    end else begin
      reg_bist_mode_payload                  <= reg_bist_mode_payload;
      reg_bist_mode_wc                       <= reg_bist_mode_wc;
      reg_bist_mode_di                       <= reg_bist_mode_di;
    end
  end

  assign BIST_MODE_reg_read = {26'h0,
          reg_bist_mode_di,
          reg_bist_mode_wc,
          reg_bist_mode_payload};

  //-----------------------
  assign swi_bist_mode_payload = reg_bist_mode_payload;

  //-----------------------
  assign swi_bist_mode_wc = reg_bist_mode_wc;

  //-----------------------
  assign swi_bist_mode_di = reg_bist_mode_di;





  //---------------------------
  // BIST_WORD_COUNT_VALUES
  // bist_wc_min - Minimum number of bytes in payload
  // bist_wc_max - Maximum number of bytes in payload
  //---------------------------
  wire [31:0] BIST_WORD_COUNT_VALUES_reg_read;
  reg [15:0]  reg_bist_wc_min;
  reg [15:0]  reg_bist_wc_max;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_bist_wc_min                        <= 16'ha;
      reg_bist_wc_max                        <= 16'h64;
    end else if(RegAddr == 'hc && RegWrEn) begin
      reg_bist_wc_min                        <= RegWrData[15:0];
      reg_bist_wc_max                        <= RegWrData[31:16];
    end else begin
      reg_bist_wc_min                        <= reg_bist_wc_min;
      reg_bist_wc_max                        <= reg_bist_wc_max;
    end
  end

  assign BIST_WORD_COUNT_VALUES_reg_read = {          reg_bist_wc_max,
          reg_bist_wc_min};

  //-----------------------
  assign swi_bist_wc_min = reg_bist_wc_min;

  //-----------------------
  assign swi_bist_wc_max = reg_bist_wc_max;





  //---------------------------
  // BIST_DATA_ID_VALUES
  // bist_di_min - Minimum Data ID Value
  // bist_di_max - Maximum Data ID Value
  //---------------------------
  wire [31:0] BIST_DATA_ID_VALUES_reg_read;
  reg [7:0]   reg_bist_di_min;
  reg [7:0]   reg_bist_di_max;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_bist_di_min                        <= 8'h20;
      reg_bist_di_max                        <= 8'hf0;
    end else if(RegAddr == 'h10 && RegWrEn) begin
      reg_bist_di_min                        <= RegWrData[7:0];
      reg_bist_di_max                        <= RegWrData[15:8];
    end else begin
      reg_bist_di_min                        <= reg_bist_di_min;
      reg_bist_di_max                        <= reg_bist_di_max;
    end
  end

  assign BIST_DATA_ID_VALUES_reg_read = {16'h0,
          reg_bist_di_max,
          reg_bist_di_min};

  //-----------------------
  assign swi_bist_di_min = reg_bist_di_min;

  //-----------------------
  assign swi_bist_di_max = reg_bist_di_max;





  //---------------------------
  // BIST_STATUS
  // bist_locked - 1 - BIST RX has seen at least one start of packet and word count has not had an issue
  // bist_unrecover - 1 - BIST RX has received data in such a way that the remaining data stream is not likely to be observable.
  // reserved0 - 
  // bist_errors - Number of errors seen during this run. Saturates at all ones.
  //---------------------------
  wire [31:0] BIST_STATUS_reg_read;
  assign BIST_STATUS_reg_read = {          bist_errors,
          14'd0, //Reserved
          bist_unrecover,
          bist_locked};

  //-----------------------
  //-----------------------
  //-----------------------
  //-----------------------




  //---------------------------
  // DEBUG_BUS_CTRL
  // DEBUG_BUS_CTRL_SEL - Select signal for DEBUG_BUS_CTRL
  //---------------------------
  wire [31:0] DEBUG_BUS_CTRL_reg_read;
  reg         reg_debug_bus_ctrl_sel;
  wire         swi_debug_bus_ctrl_sel;

  always @(posedge RegClk or posedge RegReset) begin
    if(RegReset) begin
      reg_debug_bus_ctrl_sel                 <= 1'h0;
    end else if(RegAddr == 'h18 && RegWrEn) begin
      reg_debug_bus_ctrl_sel                 <= RegWrData[0];
    end else begin
      reg_debug_bus_ctrl_sel                 <= reg_debug_bus_ctrl_sel;
    end
  end

  assign DEBUG_BUS_CTRL_reg_read = {31'h0,
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
      'd0 : debug_bus_ctrl_status = {bist_errors, 14'd0, bist_unrecover, bist_locked};
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
      'h4    : prdata_sel = BIST_MAIN_CONTROL_reg_read;
      'h8    : prdata_sel = BIST_MODE_reg_read;
      'hc    : prdata_sel = BIST_WORD_COUNT_VALUES_reg_read;
      'h10   : prdata_sel = BIST_DATA_ID_VALUES_reg_read;
      'h14   : prdata_sel = BIST_STATUS_reg_read;
      'h18   : prdata_sel = DEBUG_BUS_CTRL_reg_read;
      'h1c   : prdata_sel = DEBUG_BUS_STATUS_reg_read;

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

      default : pslverr_pre = 1'b1;
    endcase
  end
  
  assign PSLVERR = pslverr_pre;

endmodule

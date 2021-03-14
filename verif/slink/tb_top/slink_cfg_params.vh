`ifndef MAX_TX_LANES
  `define MAX_TX_LANES 8
`endif

`ifndef MAX_RX_LANES
  `define MAX_RX_LANES 8
`endif



`ifndef MST_PHY_DATA_WIDTH
  `define MST_PHY_DATA_WIDTH 16
`endif

`ifndef SLV_PHY_DATA_WIDTH
  `define SLV_PHY_DATA_WIDTH 16
`endif


`ifndef MST_TX_APP_DATA_WIDTH
  `define MST_TX_APP_DATA_WIDTH (`MAX_TX_LANES * `MST_PHY_DATA_WIDTH)
`endif
`ifndef MST_RX_APP_DATA_WIDTH
  `define MST_RX_APP_DATA_WIDTH (`MAX_RX_LANES * `MST_PHY_DATA_WIDTH)
`endif

`ifndef SLV_TX_APP_DATA_WIDTH
  `define SLV_TX_APP_DATA_WIDTH (`MAX_RX_LANES * `SLV_PHY_DATA_WIDTH)
`endif
`ifndef SLV_RX_APP_DATA_WIDTH
  `define SLV_RX_APP_DATA_WIDTH (`MAX_TX_LANES * `SLV_PHY_DATA_WIDTH)
`endif

`ifndef SERDES_MODE
  `define SERDES_MODE 1
`endif
parameter SERDES_MODE             = `SERDES_MODE;

parameter MST_TX_APP_DATA_WIDTH   = `MST_TX_APP_DATA_WIDTH;
parameter MST_RX_APP_DATA_WIDTH   = `MST_RX_APP_DATA_WIDTH;
parameter SLV_TX_APP_DATA_WIDTH   = `SLV_TX_APP_DATA_WIDTH;
parameter SLV_RX_APP_DATA_WIDTH   = `SLV_RX_APP_DATA_WIDTH;
parameter NUM_TX_LANES            = `MAX_TX_LANES;
parameter NUM_RX_LANES            = `MAX_RX_LANES;
parameter MST_PHY_DATA_WIDTH      = `MST_PHY_DATA_WIDTH;
parameter SLV_PHY_DATA_WIDTH      = `SLV_PHY_DATA_WIDTH;

//App Data Width Check
initial begin
  if(MST_TX_APP_DATA_WIDTH < (NUM_TX_LANES * MST_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("MST_TX_APP_DATA_WIDTH is too small"))
  end
  if(MST_RX_APP_DATA_WIDTH < (NUM_RX_LANES * MST_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("MST_RX_APP_DATA_WIDTH is too small"))
  end
  
  if(SLV_TX_APP_DATA_WIDTH < (NUM_RX_LANES * SLV_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("SLV_TX_APP_DATA_WIDTH is too small"))
  end
  if(SLV_RX_APP_DATA_WIDTH < (NUM_TX_LANES * SLV_PHY_DATA_WIDTH)) begin
    `sim_fatal($display("SLV_RX_APP_DATA_WIDTH is too small"))
  end
end

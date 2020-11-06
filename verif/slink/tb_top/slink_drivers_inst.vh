slink_app_driver #(
  //parameters
  .DRIVER_APP_DATA_WIDTH    ( MST_TX_APP_DATA_WIDTH  ),
  .MONITOR_APP_DATA_WIDTH   ( SLV_RX_APP_DATA_WIDTH  )
) driver_m2s (
  .link_clk          ( mst_link_clk           ),  
  .link_reset        ( mst_link_reset         ),  
  .tx_sop            ( mst_tx_sop             ),  
  .tx_data_id        ( mst_tx_data_id         ),  
  .tx_word_count     ( mst_tx_word_count      ),  
  .tx_app_data       ( mst_tx_app_data        ),               
  .tx_valid          ( mst_tx_valid           ),  
  .tx_advance        ( mst_tx_advance         ),
  
  
  .rx_link_clk       ( slv_link_clk           ),  
  .rx_link_reset     ( slv_link_reset         ),
  .rx_sop            ( slv_rx_sop             ),  
  .rx_data_id        ( slv_rx_data_id         ),  
  .rx_word_count     ( slv_rx_word_count      ),  
  .rx_app_data       ( slv_rx_app_data        ),             
  .rx_valid          ( slv_rx_valid           ),
  .rx_crc_corrupted  ( slv_rx_crc_corrupted   ),
  
  .interrupt         ( mst_interrupt          ),
  
  .apb_clk           ( apb_clk                ), 
  .apb_reset         ( main_reset             ), 
  .apb_paddr         ( apb_paddr              ), 
  .apb_pwrite        ( apb_pwrite             ), 
  .apb_psel          ( apb_psel               ), 
  .apb_penable       ( apb_penable            ), 
  .apb_pwdata        ( apb_pwdata             ), 
  .apb_prdata        ( apb_prdata             ), 
  .apb_pready        ( apb_pready             ), 
  .apb_pslverr       ( apb_pslverr            ));


slink_app_driver #(
  //parameters
  .DRIVER_APP_DATA_WIDTH    ( SLV_TX_APP_DATA_WIDTH  ),
  .MONITOR_APP_DATA_WIDTH   ( MST_RX_APP_DATA_WIDTH  )
) driver_s2m (
  .link_clk          ( slv_link_clk           ),  
  .link_reset        ( slv_link_reset         ),  
  .tx_sop            ( slv_tx_sop             ),  
  .tx_data_id        ( slv_tx_data_id         ),  
  .tx_word_count     ( slv_tx_word_count      ),  
  .tx_app_data       ( slv_tx_app_data        ),               
  .tx_valid          ( slv_tx_valid           ),  
  .tx_advance        ( slv_tx_advance         ),
  
  .rx_link_clk       ( mst_link_clk           ),  
  .rx_link_reset     ( mst_link_reset         ),
  .rx_sop            ( mst_rx_sop             ),  
  .rx_data_id        ( mst_rx_data_id         ),  
  .rx_word_count     ( mst_rx_word_count      ),  
  .rx_app_data       ( mst_rx_app_data        ),             
  .rx_valid          ( mst_rx_valid           ),
  .rx_crc_corrupted  ( mst_rx_crc_corrupted   ),
  
  .interrupt         ( slv_interrupt          ),
  
  .apb_clk           ( apb_clk                ), 
  .apb_reset         ( main_reset             ), 
  .apb_paddr         ( slv_apb_paddr          ), 
  .apb_pwrite        ( slv_apb_pwrite         ), 
  .apb_psel          ( slv_apb_psel           ), 
  .apb_penable       ( slv_apb_penable        ), 
  .apb_pwdata        ( slv_apb_pwdata         ), 
  .apb_prdata        ( slv_apb_prdata         ), 
  .apb_pready        ( slv_apb_pready         ), 
  .apb_pslverr       ( slv_apb_pslverr        ));

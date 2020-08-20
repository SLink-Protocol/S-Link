//The message to be printed is ("%c[TYPE;COLOURm",27);. 

// 1 set bold
// 2 set half-bright (simulated with color on a color display)
// 4 set underscore (simulated with color on a color display)
// 5 set blink
// 7 set reverse video 

int sim_errors      = 0;
int sim_errors_max  = 50;  //Max errors to print (to keep big logs)
int sim_infos       = 0;
int sim_debugs      = 0;
initial begin
  $timeformat(-9, 3, "ns", 8);
end

`define sim_debug(STRING) \
  if($test$plusargs("SIM_DEBUG")) begin $write("%c[2:30m",27); $write("SIM_DEBUG:  %s:%0d %0t ns: ", `__FILE__, `__LINE__, $realtime); STRING; $write("%c[0m",27);  sim_debugs++; end

`define sim_info(STRING) \
  $write("SIM_INFO:  %m %s:%0d %0t ns: ", `__FILE__, `__LINE__, $realtime); STRING; sim_infos++;

`define sim_error(STRING) \
  $write("SIM_ERROR: %m %s:%0d %0t ns: ", `__FILE__, `__LINE__, $realtime); STRING; sim_errors++;  
  
`define sim_fatal(STRING) \
  $write("SIM_FATAL:  %s:%0d %0t ns: ", `__FILE__, `__LINE__, $realtime); STRING; $finish();



// Little convenience tasks for error tracking:
//   include within the testbench module (not above it)

reg ELOG_errors = 0;

task ELOG_ERROR;
    input [20*8:1] unit_name;
    input [80*8:1] message;
begin
    $display("ERROR* %t %m", $time);
    $display("ERROR: (%s) %s", unit_name, message);
    ELOG_errors = ELOG_errors + 1;
//  $stop();
end endtask

task ELOG_TALLY;
begin
    $display("\nERRORS: %0d\n", ELOG_errors);
end endtask

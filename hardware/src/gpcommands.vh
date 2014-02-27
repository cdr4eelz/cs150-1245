`ifndef _GP_COMMANDS_
`define _GP_COMMANDS_

// GraphicsProcessor macros
`define CMD_STOP    8'h00   //Terminates
`define CMD_FILL    8'h01   //Has color, initiates Fill immediately
`define CMD_LINE    8'h02   //Has color, followed by 2 x POINT (point can have TRIGGER)
`define CMD_PIXELS  8'h03   //Has color, followed by n x POINT (TRIGGER set on LAST)

`define IDX_CMD_OPCODE  31:24
`define IDX_CMD_COLOR   23:0
`define IDX_POINT_TRIG  31
`define IDX_POINT_X     25:16
`define IDX_POINT_Y     9:0

`endif //ifndef _GP_COMMANDS_

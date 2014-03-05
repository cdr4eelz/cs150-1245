`ifndef _GP_COMMANDS_
`define _GP_COMMANDS_

// GraphicsProcessor macros

`define GOP_STOP    8'h00   //Terminate processing GP_CODE block (also on unrecognized GOP)
`define GOP_FILL    8'h01   //w/color; auto-triggers fill
`define GOP_LINE    8'h02   //w/color; followed by 2 x POINT (each point has TRIGGER bit)
`define GOP_STAMP   8'h03   //w/color; followed by n x POINT (See "MORE" bit below)

`define IX_INST_GOP    31:24 //OpCode
`define IX_INST_COLOR  23:0  //So far, color only additonal field

`define IX_POINT_TRIG  31
`define IX_POINT_MORE  30 //TODO:Allow 2+ points (line/point series)
//Some unused bits could indicate "sprite/shape" to "stamp"
`define IX_POINT_X     25:16
`define IX_POINT_Y     9:0

`endif //ifndef _GP_COMMANDS_

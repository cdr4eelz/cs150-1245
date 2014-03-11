`ifndef _GP_COMMANDS_
`define _GP_COMMANDS_

// GraphicsProcessor macros

//Graphics-OPcode vocabulary (GOP)
`define GOP_STOP    8'h00   //Terminate processing GP_CODE block
`define GOP_FILL    8'h01   //w/color; auto-triggers fill
`define GOP_LINE    8'h02   //w/color; followed by 2 x POINT (2nd point auto-triggers line)
//`define GOP_LINE    8'h02   //w/color; followed by 2 x POINT (each point has TRIGGER bit)
//`define GOP_STAMP   8'h03   //w/color; followed by n x POINT (See "MORE" bit below)
`define GOP__LAST   2

//INSTruction-initiation (opcode & packed fields)
`define IX_INST_GOP    31:24 //Graphics-OpCode
`define IX_INST_COLOR  23:0  //So far, is only field packed in with opcode

//FIELDs in trailing INSTruction-slots (based on context)
`define IX_POINT_Y     9:0
`define IX_POINT_X     25:16
//`define IX_POINT_TRIG  31
//`define IX_POINT_MORE  30 //TODO:Allow 2+ points (line/point series)
//Some unused bits could indicate "sprite/shape" to "stamp"

//Utility to allow frame specification as full 32-bit address or frame#
`define FRAME_BITS(F32) ((|F32[31:28]) ? F32[27:22] : F32[5:0])

`endif //ifndef _GP_COMMANDS_

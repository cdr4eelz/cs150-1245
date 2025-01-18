`ifndef _GP_COMMANDS_
`define _GP_COMMANDS_

// GraphicsProcessor macros

//Graphics-OPcode vocabulary (GOP)
`define GOP_STOP    8'h00   //Terminate processing GP_CODE block
`define GOP_FILL    8'h01   //w/color; no trailer (auto-triggers fill)
`define GOP_LINE    8'h02   //w/color; then 2 x POINTs (2nd point triggers)
`define GOP_ELIP    8'h03   //w/color; then 2 x POINTs (2nd point triggers)
`define GOP_BACK    8'h04   //w/color; no trailer
`define GOP_CLIP    8'h05   //w/parms; then 2 x POINTs (2nd point triggers)
`define GOP__LAST   5

//INSTruction-initiation (opcode & packed fields)
`define IX_INST_GOP    31:24 //Graphics-OpCode
`define IX_INST_COLOR  23:0  //So far, is only field packed in with opcode

//FIELDs in trailing INSTruction-slots (based on context)
`define IX_POINT_Y     9:0
`define IX_POINT_X     25:16
//`define IX_POINT_TRIG  31
//`define IX_POINT_MORE  30 //TODO:Allow 2+ points (line/point series)
//Some unused bits could indicate "sprite/shape" to "stamp"

//Renumbered so FRAME0 is 0x10000000...but usually skip that one!
`define STD_FRAME0X 32'h1000_0000
`define STD_FRAME1  32'h1040_0000
`define STD_FRAME2  32'h1080_0000
`define STD_FRAME3  32'h10C0_0000
`define STD_FRAME4  32'h1100_0000
//...NOTE:Frame# (1,2,3,...) can also be used for PF_FRAME & GP_FRAME

//Utility to allow frame specification as full 32-bit address or frame#
//TODO:Write as a "task"
`define FRAME_BITS(F32) ((|F32[31:28]) ? F32[27:22] : F32[5:0])

`endif //ifndef _GP_COMMANDS_

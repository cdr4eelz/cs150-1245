`ifndef _GP_COMMANDS_
`define _GP_COMMANDS_

// GraphicsProcessor macros

//Graphics-OPcode vocabulary (GOP)
`define GOP_STOP    4'h0    //Terminate processing GP_CODE block
`define GOP_FILL    4'h1    //w/color; no trailer (auto-triggers fill)
`define GOP_LINE    4'h2    //w/color; then 2 x POINTs (2nd point triggers)
`define GOP_ELIP    4'h3    //w/color; then 2 x POINTs; then XRGB32 fill color
`define GOP_RECT    4'h4    //w/color; then 2 x POINTs; then XRGB32 fill color
`define GOP__LAST   4

//INSTruction-initiation (opcode & packed fields)
`define IX_INST_GOP     31:28   //Graphics-OpCode in a single nibble (4-bits)
`define IX_INST_COLOR28 27:0    //RGB plus an extra high nibble packed w/opcode
// Perhaps the high nibble could be a CLUT index???

//FIELDs in trailing INSTruction-slots (based on context):
//`define IX_POINT_TRIG  31
//`define IX_POINT_MORE  30 //TODO:Allow 2+ points (line/point series)
//Some unused bits could indicate "sprite/shape" to "stamp"
`define IX_POINT_XVAR   31:26   //Index into table of variable registers
`define IX_POINT_X      25:16   //X-coordinate of point (10-bits) OR "offset" if IX_POINT_XVAR is set
`define IX_POINT_YVAR   15:10   //Index into table of variable registers
`define IX_POINT_Y       9:0    //Y-coordinate of point (10-bits) OR "offset" if IX_POINT_YVAR is set
`define IX_XRGB32       31:0    //This variant holds a full 32-bit XRGB color value

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

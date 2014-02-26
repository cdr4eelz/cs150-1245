
/*
 Command procesor module that handles the logic for parsing the graphics commands
 Three graphics commands for line engine:
 1. Write start point
 2. Write end-point
 3. Write line color
 If trigger bit set in command, command will also fire on start or end point
 Frame buffer fill will trigger automatically
 
 */
`include "gpcommands.vh"

module GraphicsProcessor #(
    parameter LITTLEWORDIAN=0 //Ordering of 32-bit words within each 256-bit DDR block (not byte ordering)
)(
    input clk,
    input rst,

    //line engine processor interface
    input LE_ready,
    output [31:0] LE_color,
    output [9:0] LE_point,
    output LE_color_valid,
    output LE_x0_valid,
    output LE_y0_valid,
    output LE_x1_valid,
    output LE_y1_valid,

    output LE_trigger,
    output [31:0] LE_frame,

    //frame filler processor interface
    input FF_ready,
    output FF_valid,
    output [23:0] FF_color,
    output [31:0] FF_frame,

    //DRAM request controller interface
    input rdf_valid,
    input af_full,
    input [127:0] rdf_dout,
    output rdf_rd_en,
    output af_wr_en,
    output [30:0] af_addr_din,

    //processor interface
    input [31:0] GP_CODE,
    input [31:0] GP_FRAME,
    input GP_valid,
    output gpcode_interrupt
);


   //Your code goes here. GL HF.

    reg  [22:0] cmd_chunk;   //256-bit chunk # within 256MB range of DDR (8 x 32-bit words)
    reg  [ 2:0] cmd_index;   //Specific 32-bit word within 256-bit chunk
    reg  [ 5:0] framebits;   //Insist on aligning with multiples of 0x0040_0000

    localparam S_IDLE = 1'b0;
    localparam S_RUNNING = 1'b1;

    reg  state_next, state = S_IDLE;
    reg  do_launch, do_interrupt; //Individual action "strobes" (often just 1-cycle)

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            //No need to reset registers which are guarded by state
        end else begin
            state <= state_next;
            if (do_launch) begin
                cmd_chunk <= GP_CODE[27:5]; //Hi nibble ignored, reset is enough for 256-bit-chunk
                cmd_index = GP_CODE[4:2]; //Lo 2-bits would be byte, take next 3-bits for word-in-chunk
                framebits <= (|GP_FRAME[31:28]) ? GP_FRAME[27:22] : GP_FRAME[5:0]; //Either addr style
            end
        end
    end

    always @(*) begin
        state_next = state;
        {do_launch, do_interrupt} = 0;
        case (state)
            S_IDLE: if (GP_valid) begin
                state_next = S_RUNNING;
                do_launch = 1;
            end

            S_RUNNING: begin
                do_interrupt = 1;
            end

            default: state_next = S_IDLE;
        endcase
    end

    assign af_addr_din = {6'd0, framebits, cmd_chunk, 2'b00}; //Chunk DDR address
    assign gpcode_interrupt = do_interrupt;

   //output assignment placeholders - delete these later

   assign LE_color = 0;
   assign LE_point = 0;

   assign LE_color_valid = 0;
   assign LE_x0_valid = 0;
   assign LE_y0_valid = 0;
   assign LE_x1_valid = 0;
   assign LE_y1_valid = 0;

   assign LE_trigger = 0;
   assign LE_frame = 0;

   //frame filler processor interface
   assign FF_valid  = 0;
   assign FF_color = 0;
   assign FF_frame = 0;

   //DRAM request controller interface
   assign rdf_rd_en = 0;

   assign af_wr_en = 0;

endmodule

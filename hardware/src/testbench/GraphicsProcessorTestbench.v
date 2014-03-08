`timescale 1ns/1ps

module GraphicsProcessorTestbench();

    parameter ClockFreq = 50_000_000;
    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;
    reg  Clock, rst;
    initial Clock = 0;
    always #(HalfCycle) Clock= ~Clock;

    wire        GP_ready;
    reg         GP_valid;
    reg  [31:0] GP_code;
    reg  [31:0] GP_frame;
    wire [ 5:0] GP_procframe;
    wire        GP_interrupt;
//  wire bsel;

    reg         af_full;
    wire        af_wr_en;
    wire [30:0] af_addr_din;
    wire        rdf_rd_en;
    reg         rdf_valid;
    reg [127:0] rdf_dout;
//  wire        ready;

    reg         FF_ready;
    wire        FF_valid;
    wire [31:0] FF_color;
    wire [31:0] FF_frame;

    reg         LE_ready;
    wire        LE_color_valid;
    wire [31:0] LE_color;
    wire        LE_x0_valid;
    wire        LE_y0_valid;
    wire        LE_x1_valid;
    wire        LE_y1_valid;
    wire [ 9:0] LE_point;
    wire        LE_trigger;
    wire [31:0] LE_frame;


    GraphicsProcessor DUT(
        .clk(Clock),
        .rst(rst),
//      .bsel(bsel), ???What was this to be???
    //GraphicsProcessor control signals
        .GP_ready(GP_ready),
        .GP_valid(GP_valid),
        .GP_frame(GP_frame),
        .GP_code(GP_code),
        .GP_procframe(GP_procframe),
        .GP_interrupt(GP_interrupt),
    //DDR FIFOs
        .rdf_valid(rdf_valid),
        .af_full(af_full),
        .rdf_dout(rdf_dout),
        .rdf_rd_en(rdf_rd_en),
        .af_wr_en(af_wr_en),
        .af_addr_din(af_addr_din),
    //FrameFiller control signals
        .FF_ready(FF_ready),
        .FF_valid(FF_valid),
        .FF_color(FF_color),
        .FF_frame(FF_frame),
    //LineEngine control signals
        .LE_ready(LE_ready),
        .LE_color_valid(LE_color_valid),
        .LE_color(LE_color),
        .LE_x0_valid(LE_x0_valid),
        .LE_y0_valid(LE_y0_valid),
        .LE_x1_valid(LE_x1_valid),
        .LE_y1_valid(LE_y1_valid),
        .LE_point(LE_point),
        .LE_trigger(LE_trigger),
        .LE_frame(LE_frame)
    );

    initial begin
        #(Cycle);
        @(posedge Clock);
        {GP_valid, GP_code, GP_frame} = 0;
        {FF_ready, LE_ready} = 0;
        rst = 1'b1;
        #(10*Cycle);
        {FF_ready, LE_ready} = {2{1'b1}};
        rst = 1'b0;
        #(Cycle);
$monitor("gp-TB: procframe==%0h  interrupt==%b", GP_procframe, GP_interrupt);
        execGP( .codebase(32'h0000_4000), .framebase(1) );
        $finish();
    end

    task execGP;
        input [31:0] codebase;
        input [31:0] framebase;
    begin
        wait (posedge Clock);
        $display("gp-TB: Wait...");
        while (!GP_ready) #(Cycle); // wait for GP_ready
        GP_code = codebase;
        GP_frame = framebase;
        GP_valid = 1'b1;
        $strobe("gp-TB: code=%0h  frame=%0h", GP_code, GP_frame);
        #(Cycle);
        GP_valid = 1'b0;
        GP_code = 32'bz;
        GP_frame = 32'bz;
        while (!GP_ready) begin
//            if (wdf_wr_en && wdf_mask_din != 16'hFFFF) begin
//                $display("gp-TB: ...", x, y);
//            end
            #(Cycle);
        end
        $display("gp-TB: Done.");
    end

/*
*** SAMPLE-1 GPCODE block from checkpoint 4 ***
    0x4000:   0x0100_0000   # FILL: black
    0x4004:   0x0200_00FF   # LINE: blue
    0x4008:   0x0010_0020   #   first-endpoint  (0x10, 0x20)
    0x400C:   0x001A_002B   #   second-endpoint (0x1A, 0x2B)
    0x4010:   0x02FF_0000   # LINE: red
    0x4014:   0x0123_0124   #   first-endpoint  (0x123,0x124)
    0x4018:   0x00AA_00BB   #   second-endpoint (0xAA, 0xBB)
    0x401C:   0x0000_0000   # STOP.
*/

// Fake memory fetch/response, always fetches 2-parts of SAMPLE-1 ignoring address!
    localparam MS_DEAD=0, MS_IDLE=1, MS_OFFER1=2, MS_OFFER2=3;
    reg [1:0] mem_ns, mem_cs = MS_DEAD;
    always @(*) begin
        mem_ns = mem_cs;  //Default: Hold prior state
        af_full = 1'b1;   //Default: Pretend full like RequestController
        rdf_valid = 1'b0; //Default: Read value invalid
        rdf_dout = 128'bz;//Default: Obvious bad value
        case (mem_cs)
            MS_IDLE: begin
                af_full = 1'b0;
                if (af_wr_en) mem_ns = MS_OFFER1; //NOTE:IGNORES af_addr_din!
            end
            MS_OFFER1: begin
                rdf_valid = 1'b1; //First 128-bits from SAMPLE below
                rdf_dout = {32'h0100_0000,32'h0200_00FF,32'h0010_0020,32'h001A_002B};
                if (rdf_rd_en) mem_ns = MS_OFFER2;
            end
            MS_OFFER2: begin
                rdf_valid = 1'b1; //Second 128-bits from SAMPLE below
                rdf_dout = {32'h02FF_0000,32'h0123_0124,32'h00AA_00BB,32'h0000_0000};
                if (rdf_rd_en) mem_ns = MS_IDLE;
            end
            default: mem_ns = MS_DEAD;
        endcase
    end
    always @(posedge Clock) begin
        if (rst) mem_cs <= MS_IDLE;
        else mem_cs <= mem_ns;

        if (!af_full && af_wr_en) $display("gp-MEM: addr=%0h", af_addr_din);
        if (rdf_valid && rdf_rd_en) $display("gp-MEM: data=%0h", rdf_dout);
    end

endmodule

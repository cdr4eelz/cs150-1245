`timescale 1ns/1ps

module GraphicsProcessorTestbench;

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
    wire        GP_fault;
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

    reg         EL_ready;
    wire        EL_color_valid;
    wire [31:0] EL_color;
    wire        EL_x0_valid;
    wire        EL_y0_valid;
    wire        EL_x1_valid;
    wire        EL_y1_valid;
    wire [ 9:0] EL_point;
    wire        EL_trigger;
    wire [31:0] EL_frame;

    GraphicsProcessor #(
        .LITTLEWORDIAN(1)
    ) DUT(
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
        .GP_fault(GP_fault),
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
        .LE_frame(LE_frame),
    //ElipseEngine control signals
        .EL_ready(EL_ready),
        .EL_color_valid(EL_color_valid),
        .EL_color(EL_color),
        .EL_x0_valid(EL_x0_valid),
        .EL_y0_valid(EL_y0_valid),
        .EL_x1_valid(EL_x1_valid),
        .EL_y1_valid(EL_y1_valid),
        .EL_point(EL_point),
        .EL_trigger(EL_trigger),
        .EL_frame(EL_frame)
    );


// Little convenience tasks for error tracking

reg ELOG_errors = 0;

    task ELOG_ERROR;
        input [100*8:1] unit_name;
        input [256*8:1] message;
    begin
        $display("ERROR: (%s) %s", unit_name, message);
        ELOG_errors = ELOG_errors + 1;
    end endtask

    task ELOG_TALLY;
    begin
        $display("\nERRORS: %0d\n", ELOG_errors);
    end endtask


    wire ENGINES_ready;

    initial begin
        #(Cycle);
        @(posedge Clock);
        {GP_valid, GP_code, GP_frame} = 0;
        rst = 1'b1;
        #(10*Cycle);
        rst = 1'b0;
        #(Cycle);

        $display("GraphicsProcessor: Fake memory & engines...");
        execGP( 32'h0000_4000, 1 );

        @(posedge Clock);
        while (!ENGINES_ready) #(Cycle); // GP should have waited already
        $display("GraphicsProcessor: Done.");
        ELOG_TALLY;
        $finish();
    end

    task execGP;
        input [31:0] codebase;
        input [31:0] framebase;
    begin
        @(negedge Clock);
        $display("gp-TB: Wait...");
        while (!GP_ready) #(Cycle); // wait for GP_ready
        GP_code = codebase;
        GP_frame = framebase;
        GP_valid = 1'b1;
        $strobe("gp-TB: code=%h  frame=%h", GP_code, GP_frame);
        #(Cycle);
        GP_valid = 1'b0;
        GP_code = 32'bz;
        $monitor("gp-TB: procframe==%h  interrupt==%b  fault==%b",
                 GP_procframe, GP_interrupt, GP_fault);
        while (!GP_ready) begin
//            if (wdf_wr_en && wdf_mask_din != 16'hFFFF) begin
//                $display("gp-TB: ...", x, y);
//            end
            #(Cycle);
        end
        $monitor();
        if (GP_fault) ELOG_ERROR("GPCode", "Fault");
        $display("gp-TB: Done.");
    end endtask


/*
*** SAMPLE-1 GPCODE block from checkpoint 4 ***
    0x4000:   0x0100_0000   # FILL: black
    0x4004:   0x0200_00FF   # LINE: blue
    0x4008:   0x0010_0020   #   first-endpoint  (0x10, 0x20)
    0x400C:   0x001A_002B   #   second-endpoint (0x1A, 0x2B)
    0x4010:   0x02FF_0000   # LINE: red
    0x4014:   0x0123_0124   #   first-endpoint  (0x123,0x124)
    0x4018:   0x00AA_00BB   #   second-endpoint (0xAA, 0xBB)
    0x401C:   0x0300_FF00   # ELIP: green
    0x4020:   0x0143_0104   #   center-point    (0x143,0x104)
    0x4024:   0x0020_0032   #   second-endpoint (0x20, 0x32)
    0x4028:   0x0000_0000   # STOP.
    0x402C:   0xFFFF_FFFF   # ERR.
*/
reg  [0:1023] GPCODE_SAMPLE1 = { //Ascending bit order
    32'h0100_0000, 32'h0200_00FF, 32'h0010_0020, 32'h001A_002B,
    32'h02FF_0000, 32'h0123_0124, 32'h00AA_00BB, 32'h03FF_0000,
    32'h0143_0104, 32'h0020_0032, 32'h0000_0000, 32'hFFFF_FFFF,
    128'b0,
    128'b0,
    128'b0,
    128'b0,
    128'b0
};


// Fake memory fetch/response, always fetches 2-parts of SAMPLE-1 ignoring address!
    wire [0:1023] GPCODE;
    assign GPCODE[0:1023] = GPCODE_SAMPLE1;

    localparam MS_DEAD=0, MS_IDLE=1, MS_OFFER1=2, MS_OFFER2=3;
    reg [1:0] mem_ns, mem_cs = MS_DEAD;
    integer mem_offset;
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
            MS_OFFER1, MS_OFFER2: begin
                rdf_valid = 1'b1; //First 128-bits from SAMPLE below
                rdf_dout[127:0] = GPCODE[mem_offset +: 128];
                if (rdf_rd_en) mem_ns = (mem_cs==MS_OFFER1) ? MS_OFFER2 : MS_IDLE;
            end
            default: mem_ns = MS_DEAD;
        endcase
    end
    always @(posedge Clock) begin
        if (rst) mem_cs <= MS_IDLE;
        else mem_cs <= mem_ns;

        if (!af_full && af_wr_en) begin
            mem_offset <= ((af_addr_din * 64) % 1024);
            $strobe("gp-MEM: addr=%h offset=%0d", af_addr_din, mem_offset);
        end
        if (rdf_valid && rdf_rd_en) begin
            $display("gp-MEM: data=%h %h %h %h", rdf_dout[127:96],
                rdf_dout[95:64], rdf_dout[63:32], rdf_dout[31:0]);
            mem_offset <= mem_offset + 128;
        end
    end


//Fake ENGINEs to listen to GP actions
    integer FF__countdown, LE__countdown, EL__countdown;
    integer LE__frame, LE__color, LE__x0, LE__y0, LE__x1, LE__y1;
    integer EL__frame, EL__color, EL__x0, EL__y0, EL__x1, EL__y1;
    assign ENGINES_ready = (FF_ready && LE_ready && EL_ready);
    always @(posedge Clock) begin
        if (rst) begin
            {FF_ready, FF__countdown} <= 0;
            {LE_ready, LE__countdown} <= 0;
            {EL_ready, EL__countdown} <= 0;
        end else begin
            if (FF__countdown == 0) begin
                FF_ready <= 1'b1;
                if (!FF_ready) $display("[+FILL+] Ready!");
            end else FF__countdown <= (FF__countdown-1);
            if (LE__countdown == 0) begin
                LE_ready <= 1'b1;
                if (!LE_ready) $display("[+LINE+] Ready!");
            end else LE__countdown <= (LE__countdown-1);
            if (EL__countdown == 0) begin
                EL_ready <= 1'b1;
                if (!EL_ready) $display("[+ELIP+] Ready!");
            end else EL__countdown <= (EL__countdown-1);
        end

        if (FF_ready) begin
            if (FF_valid) begin
                if (!ENGINES_ready) ELOG_ERROR("FILL", "Overlap");
                $display("[=FILL=] frame=%h", FF_frame);
                $display("[-FILL-] color=%h (%0d,%0d,%0d)", FF_color,
                         FF_color[23:16], FF_color[15:8], FF_color[7:0]);
                FF_ready <= 0;
                FF__countdown <= 9;
            end
        end else begin
            if (FF_valid) ELOG_ERROR("FILL", "Premature");
        end

        if (LE_ready) begin
            if (LE_color_valid) begin
                $display(" LINE: color=%h (%0d,%0d,%0d)", LE_color,
                         LE_color[23:16], LE_color[15:8], LE_color[7:0]);
                LE__color <= LE_color;
            end
            if (LE_x0_valid) begin
                $display(" LINE: x0=%h (%0d)", LE_point, LE_point);
                LE__x0 <= LE_point;
            end
            if (LE_y0_valid) begin
                $display(" LINE: y0=%h (%0d)", LE_point, LE_point);
                LE__y0 <= LE_point;
            end
            if (LE_x1_valid) begin
                $display(" LINE: x1=%h (%0d)", LE_point, LE_point);
                LE__x1 <= LE_point;
            end
            if (LE_y1_valid) begin
                $display(" LINE: y1=%h (%0d)", LE_point, LE_point);
                LE__y1 <= LE_point;
            end
            if (LE_trigger) begin
                LE__frame <= LE_frame;
                if (!ENGINES_ready) ELOG_ERROR("LINE", "Overlap");
                #1; //Might have simultaneously assigned other values above!
                $display("[=LINE=] frame=%h", LE__frame);
                $display("[-LINE-] color=%h (%0d,%0d,%0d)", LE__color,
                         LE__color[23:16], LE__color[15:8], LE__color[7:0]);
                $display("[-LINE-] P0=%h,%h (%0d,%0d)",
                         LE__x0, LE__y0, LE__x0, LE__y0);
                $display("[-LINE-] P1=%h,%h (%0d,%0d)",
                         LE__x1, LE__y1, LE__x1, LE__y1);
                LE_ready <= 0;
                LE__countdown <= 3;
            end
        end else begin
            if (LE_color_valid || LE_x0_valid || LE_y0_valid
                    || LE_x1_valid || LE_y1_valid || LE_trigger)
                ELOG_ERROR("LINE", "Premature");
        end

        if (EL_ready) begin
            if (EL_color_valid) begin
                $display(" ELIP: color=%h (%0d,%0d,%0d)", EL_color,
                         EL_color[23:16], EL_color[15:8], EL_color[7:0]);
                EL__color <= EL_color;
            end
            if (EL_x0_valid) begin
                $display(" ELIP: x0=%h (%0d)", EL_point, EL_point);
                EL__x0 <= EL_point;
            end
            if (EL_y0_valid) begin
                $display(" ELIP: y0=%h (%0d)", EL_point, EL_point);
                EL__y0 <= EL_point;
            end
            if (EL_x1_valid) begin
                $display(" ELIP: x1=%h (%0d)", EL_point, EL_point);
                EL__x1 <= EL_point;
            end
            if (EL_y1_valid) begin
                $display(" ELIP: y1=%h (%0d)", EL_point, EL_point);
                EL__y1 <= EL_point;
            end
            if (EL_trigger) begin
                EL__frame <= EL_frame;
                if (!ENGINES_ready) ELOG_ERROR("ELIP", "Overlap");
                #1; //Might have simultaneously assigned other values above!
                $display("[=ELIP=] frame=%h", EL__frame);
                $display("[-ELIP-] color=%h (%0d,%0d,%0d)", EL__color,
                         EL__color[23:16], EL__color[15:8], EL__color[7:0]);
                $display("[-ELIP-] P0=%h,%h (%0d,%0d)",
                         EL__x0, EL__y0, EL__x0, EL__y0);
                $display("[-ELIP-] P1=%h,%h (%0d,%0d)",
                         EL__x1, EL__y1, EL__x1, EL__y1);
                EL_ready <= 0;
                EL__countdown <= 3;
            end
        end else begin
            if (EL_color_valid || EL_x0_valid || EL_y0_valid
                    || EL_x1_valid || EL_y1_valid || EL_trigger)
                ELOG_ERROR("ELIP", "Premature");
        end
    end

endmodule

`timescale 1ns/1ps

module GraphicsProcessorSLRTestbench;

    parameter LITTLEWORDIAN = 1;

    parameter ClockFreq = 50_000_000;
    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;
    reg  cpu_clk_g, rst_cpu_bus;
    initial cpu_clk_g = 0;
    always #(HalfCycle) cpu_clk_g= ~cpu_clk_g;

    wire        gp_ready;
    reg         cpu_gp_valid;
    reg  [31:0] cpu_gp_code;
    reg  [31:0] cpu_gp_frame;
    wire        gp_fault;
    wire [ 5:0] gp_procframe;
    wire        gp_interrupt;

    reg [127:0] rdf_dout;
    reg         cmd_af_full;
    reg         cmd_rdf_valid;

    wire         cmd_rdf_rd_en;
    wire         cmd_af_wr_en;
    wire [ 30:0] cmd_af_addr_din;

    // Graphics Command Processor <=> Frame Filler wires:
    wire [ 31:0] filler_color;
    wire         filler_ready;
    wire         filler_valid;
    wire [ 31:0] filler_frame;

    // Graphics Command Processor <=> Line Engine wires:
    wire         line_ready;
    wire [ 31:0] line_color;
    wire [  9:0] line_point;
    wire         line_color_valid;
    wire         line_x0_valid;
    wire         line_y0_valid;
    wire         line_x1_valid;
    wire         line_y1_valid;
    wire         line_trigger;
    wire [ 31:0] line_frame;

    // Graphics Command Processor <=> Elipse Engine wires:
    wire         elip_ready;
    wire [ 31:0] elip_color;
    wire [  9:0] elip_point;
    wire         elip_color_valid;
    wire         elip_xc_valid;
    wire         elip_yc_valid;
    wire         elip_a_valid;
    wire         elip_b_valid;
    wire         elip_trigger;
    wire [ 31:0] elip_frame;

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
        @(posedge cpu_clk_g);
        {cpu_gp_valid, cpu_gp_code, cpu_gp_frame} = 0;
        rst_cpu_bus = 1'b1;
        #(10*Cycle);
        rst_cpu_bus = 1'b0;
        #(Cycle);

        $display("GraphicsProcessor: Fake memory & engines...");
        execGP( 32'h0000_4000, 1 );

        @(posedge cpu_clk_g);
        while (!ENGINES_ready) #(Cycle); // GP should have waited already
        $display("GraphicsProcessor: Done.");
        ELOG_TALLY;
        $finish();
    end

    task execGP;
        input [31:0] codebase;
        input [31:0] framebase;
    begin
        @(negedge cpu_clk_g);
        $display("gp-TB: Wait...");
        while (!gp_ready) #(Cycle); // wait for gp_ready
        cpu_gp_code = codebase;
        cpu_gp_frame = framebase;
        cpu_gp_valid = 1'b1;
        $strobe("gp-TB: code=%h  frame=%h", cpu_gp_code, cpu_gp_frame);
        #(Cycle);
        cpu_gp_valid = 1'b0;
        cpu_gp_code = 32'bz;
        $monitor("gp-TB: procframe==%h  interrupt==%b  fault==%b",
                 gp_procframe, gp_interrupt, gp_fault);
        while (!gp_ready) begin
//            if (wdf_wr_en && wdf_mask_din != 16'hFFFF) begin
//                $display("gp-TB: ...", x, y);
//            end
            #(Cycle);
        end
        $monitor();
        if (gp_fault) ELOG_ERROR("GPCode", "Fault");
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
    0x4020:   0x0064_0064   #   center-point    (0x64, 0x64)
    0x4024:   0x000A_0014   #   second-endpoint (0x0A, 0x14)
    0x4028:   0x0000_0000   # STOP.
    0x402C:   0xFFFF_FFFF   # ERR.
*/
reg  [0:1023] GPCODE_SAMPLE1 = { //Ascending bit order
    32'h0100_0000, 32'h0200_00FF, 32'h0010_0020, 32'h001A_002B,
    32'h02FF_0000, 32'h0123_0124, 32'h00AA_00BB, 32'h03FF_0000,
    32'h0064_0064, 32'h000A_0014, 32'h0000_0000, 32'hFFFF_FFFF,
    128'b0,
    128'b0,
    128'b0,
    128'b0,
    128'b0
};
reg  [0:1023] GPCODE_SAMPLE2 = { //Ascending bit order
    32'h03FF_0000, 32'h0064_0064, 32'h000A_0014, 32'h0000_0000,
    128'b0,
    128'b0,
    128'b0,
    128'b0,
    128'b0,
    128'b0,
    128'b0
};


// Fake memory fetch/response, always fetches 2-parts of SAMPLE-1 ignoring address!
    wire [0:1023] GPCODE;
    assign GPCODE[0:1023] = GPCODE_SAMPLE2;

    localparam MS_DEAD=0, MS_IDLE=1, MS_OFFER1=2, MS_OFFER2=3;
    reg [1:0] mem_ns, mem_cs = MS_DEAD;
    integer mem_offset;
    always @(*) begin
        mem_ns = mem_cs;  //Default: Hold prior state
        cmd_af_full = 1'b1;   //Default: Pretend full like RequestController
        cmd_rdf_valid = 1'b0; //Default: Read value invalid
        rdf_dout = 128'bz;//Default: Obvious bad value
        case (mem_cs)
            MS_IDLE: begin
                cmd_af_full = 1'b0;
                if (cmd_af_wr_en) mem_ns = MS_OFFER1; //NOTE:IGNORES cmd_af_addr_din!
            end
            MS_OFFER1, MS_OFFER2: begin
                cmd_rdf_valid = 1'b1; //First 128-bits from SAMPLE below
                rdf_dout[127:0] = GPCODE[mem_offset +: 128];
                if (cmd_rdf_rd_en) mem_ns = (mem_cs==MS_OFFER1) ? MS_OFFER2 : MS_IDLE;
            end
            default: mem_ns = MS_DEAD;
        endcase
    end
    always @(posedge cpu_clk_g) begin
        if (rst_cpu_bus) mem_cs <= MS_IDLE;
        else mem_cs <= mem_ns;

        if (!cmd_af_full && cmd_af_wr_en) begin
            mem_offset <= ((cmd_af_addr_din * 64) % 1024);
            $strobe("gp-MEM: addr=%h offset=%0d", cmd_af_addr_din, mem_offset);
        end
        if (cmd_rdf_valid && cmd_rdf_rd_en) begin
            $display("gp-MEM: data=%h %h %h %h", rdf_dout[127:96],
                rdf_dout[95:64], rdf_dout[63:32], rdf_dout[31:0]);
            mem_offset <= mem_offset + 128;
        end
    end


//ENGINEs to listen to GP actions
    //For CP5:
    GraphicsProcessor #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) DUT (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    //DDR FIFOs (read-only):
        .rdf_valid(cmd_rdf_valid),
        .af_full(cmd_af_full),
        .rdf_dout(rdf_dout),
        .rdf_rd_en(cmd_rdf_rd_en),
        .af_wr_en(cmd_af_wr_en),
        .af_addr_din(cmd_af_addr_din),
    //FrameFiller interface:
        .FF_ready(filler_ready),
        .FF_valid(filler_valid),
        .FF_color(filler_color),
        .FF_frame(filler_frame),
    //LineEngine interface:
        .LE_ready(line_ready),
        .LE_color_valid(line_color_valid),
        .LE_color      (line_color),
        .LE_x0_valid(line_x0_valid),
        .LE_y0_valid(line_y0_valid),
        .LE_x1_valid(line_x1_valid),
        .LE_y1_valid(line_y1_valid),
        .LE_point   (line_point),
        .LE_trigger(line_trigger),
        .LE_frame  (line_frame),
    //ElipseEngine interface:
        .EL_ready(elip_ready),
        .EL_color_valid(elip_color_valid),
        .EL_color      (elip_color),
        .EL_xc_valid(elip_xc_valid),
        .EL_yc_valid(elip_yc_valid),
        .EL_a_valid (elip_a_valid),
        .EL_b_valid (elip_b_valid),
        .EL_point   (elip_point),
        .EL_trigger(elip_trigger),
        .EL_frame  (elip_frame),
    //CPU interface:
        .GP_ready(gp_ready),
        .GP_valid(cpu_gp_valid),
        .GP_frame(cpu_gp_frame),
        .GP_code (cpu_gp_code),
        .GP_fault(gp_fault),
        .GP_procframe(gp_procframe),
        .GP_interrupt(gp_interrupt)
    );

    localparam SLR_FF       = 0,
                SLR_LE      = 1,
                SLR_EL      = 2;
    localparam  SLR__CNT = 3;

    wire [(SLR__CNT)-1:0] SLRs_ready;
    wire [(SLR__CNT)-1:0] SLRs_valid;
    wire [(SLR__CNT*32)-1:0] SLRs_frame;
    wire [(SLR__CNT*32)-1:0] SLRs_color_edge;
    wire [(SLR__CNT*32)-1:0] SLRs_color_fill;
    wire [(SLR__CNT*10)-1:0] SLRs_row;
    wire [(SLR__CNT*10)-1:0] SLRs_col_start;
    wire [(SLR__CNT*10)-1:0] SLRs_col_finish;

    FrameFiller #(
        .SCANLINERUNNER(1),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) framefill (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    //Fill control <=> CPU:
        .FF_ready(filler_ready),
        .FF_valid (filler_valid),
        .FF_color (filler_color),
        .FF_frame (filler_frame),
    //DDR FIFOs (write-only):
        .af_full (1'b1), .wdf_full(1'b1),
        .af_wr_en    (), .wdf_wr_en   (),
        .af_addr_din (), .wdf_din     (),
        .wdf_mask_din(),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_FF]                    ),
        .SLR_valid(SLRs_valid           [SLR_FF]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_row       (SLRs_row       [(SLR_FF*10)+ 9:(SLR_FF*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_FF*10)+ 9:(SLR_FF*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_FF*10)+ 9:(SLR_FF*10)] )
    );

    // For CP5:
    LineEngine #(
        .SCANLINERUNNER(1),
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) le (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    //Line control <=> CPU:
        .LE_ready(line_ready),
        .LE_color_valid(line_color_valid),
        .LE_color      (line_color),
        .LE_x0_valid(line_x0_valid),
        .LE_y0_valid(line_y0_valid),
        .LE_x1_valid(line_x1_valid),
        .LE_y1_valid(line_y1_valid),
        .LE_point   (line_point),
        .LE_trigger(line_trigger),
        .LE_frame  (line_frame),
    //DDR FIFOs (write-only):
        .af_full (1'b1), .wdf_full(1'b1),
        .af_wr_en    (), .wdf_wr_en   (),
        .af_addr_din (), .wdf_din     (),
        .wdf_mask_din(),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_LE]                    ),
        .SLR_valid(SLRs_valid           [SLR_LE]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_row       (SLRs_row       [(SLR_LE*10)+ 9:(SLR_LE*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_LE*10)+ 9:(SLR_LE*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_LE*10)+ 9:(SLR_LE*10)] )
    );

    ElipseEngine #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) el (
        .clk(cpu_clk_g),
        .rst(rst_cpu_bus),
    //Elipse control <=> CPU:
        .EL_ready(elip_ready),
        .EL_color_valid(elip_color_valid),
        .EL_color      (elip_color),
        .EL_xc_valid(elip_xc_valid),
        .EL_yc_valid(elip_yc_valid),
        .EL_a_valid (elip_a_valid),
        .EL_b_valid (elip_b_valid),
        .EL_point   (elip_point),
        .EL_trigger(elip_trigger),
        .EL_frame  (elip_frame),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_EL]                    ),
        .SLR_valid(SLRs_valid           [SLR_EL]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_EL*32)+31:(SLR_EL*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_EL*32)+31:(SLR_EL*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_EL*32)+31:(SLR_EL*32)] ),
        .SLR_row       (SLRs_row       [(SLR_EL*10)+ 9:(SLR_EL*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_EL*10)+ 9:(SLR_EL*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_EL*10)+ 9:(SLR_EL*10)] )
    );


    assign SLRs_ready = {SLR__CNT{1'b1}};

    always @(posedge cpu_clk_g) begin:_WATCH_SLR_
        integer idx;
        for (idx = 0; idx < SLR__CNT; idx = idx+1) begin
            if (SLRs_valid[idx]) begin
                $display("%d SLR[%0d] row=%0d s=%0d f=%0d", $time, idx,
                         SLRs_row       [(idx*10)+ 9 -: 10],
                         SLRs_col_start [(idx*10)+ 9 -: 10],
                         SLRs_col_finish[(idx*10)+ 9 -: 10]
                );
            end
        end
    end

endmodule

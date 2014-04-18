
module GPU #(
    parameter SCREEN_WIDTH=800, SCREEN_HEIGHT=600,
    parameter LITTLEWORDIAN=1, WATCH_SLR=1
)(
    input clk,
    input rst,

//GraphicsProcessor interface:
    input           GP_valid,
    input   [ 31:0] GP_frame,
    input   [ 31:0] GP_code,
    output  [ 15:0] GP_status,
    output          GP_irq,

//DDR-FIFOs (Read-only for GraphicsProcessor):
    output          gcmd_caf_wren,
    output  [ 30:0] gcmd_caf_addr,
    input           gcmd_caf_full,
    output          gcmd_rdf_rden,
    input           gcmd_rdf_valid,
    input   [127:0] gcmd_rdf_data,

//DDR-FIFOs (Write-only for ScanLineRunner):
    input           slr_caf_full,
    input           slr_wdf_full,
    output          slr_caf_wren,
    output  [ 30:0] slr_caf_addr,
    output          slr_wdf_wren,
    output  [127:0] slr_wdf_data,
    output  [ 15:0] slr_wdf_mask
);

    // GraphicsProcessor <=> FrameFiller:
    wire [ 31:0] filler_color;
    wire         filler_ready;
    wire         filler_valid;
    wire [ 31:0] filler_frame;

    // GraphicsProcessor <=> LineEngine:
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

    // GraphicsProcessor <=> ElipseEngine:
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

    wire         gp_fault, gp_ready;
    wire [  5:0] gp_procframe;
    assign GP_status = {
        gp_fault, 1'b0, gp_procframe[5:0],
        4'b0000, elip_ready, line_ready, filler_ready, gp_ready
    };

    GraphicsProcessor #(
        .LITTLEWORDIAN(LITTLEWORDIAN)
    ) gp (
        .clk(clk),
        .rst(rst),
    //DDR FIFOs (read-only):
        .rdf_valid(gcmd_rdf_valid),
        .caf_full(gcmd_caf_full),
        .rdf_data(gcmd_rdf_data),
        .rdf_rden(gcmd_rdf_rden),
        .caf_wren(gcmd_caf_wren),
        .caf_addr(gcmd_caf_addr),
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
        .GP_valid(GP_valid),
        .GP_frame(GP_frame),
        .GP_code (GP_code),
        .GP_fault(gp_fault),
        .GP_procframe(gp_procframe),
        .GP_irq(GP_irq)
    ) /* synthesis syn_noprune=1 */;

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

    ScanLineRunner #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .LITTLEWORDIAN(LITTLEWORDIAN),
        .SLR_COUNT(SLR__CNT)
    ) slr (
        .clk(clk),
        .rst(rst),
    //DDR FIFOs (write-only):
        .caf_full (slr_caf_full),
        .wdf_full(slr_wdf_full),
        .caf_wren   (slr_caf_wren),
        .caf_addr(slr_caf_addr),
        .wdf_wren   (slr_wdf_wren),
        .wdf_data     (slr_wdf_data),
        .wdf_mask(slr_wdf_mask),
    //SLR interface:
        .SLRs_ready(SLRs_ready),
        .SLRs_valid     (SLRs_valid),
        .SLRs_frame     (SLRs_frame),
        .SLRs_color_fill(SLRs_color_fill),
        .SLRs_color_edge(SLRs_color_edge),
        .SLRs_row       (SLRs_row),
        .SLRs_col_start (SLRs_col_start),
        .SLRs_col_finish(SLRs_col_finish)
    ) /* synthesis syn_noprune=1 */;


    FrameFiller #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .SCANLINERUNNER(1)
    ) ff (
        .clk(clk),
        .rst(rst),
    //Fill control <=> CPU:
        .FF_ready(filler_ready),
        .FF_valid (filler_valid),
        .FF_color (filler_color),
        .FF_frame (filler_frame),
    //DDR FIFOs (write-only):
        .caf_full (1'b1), .wdf_full(1'b1),
        .caf_wren    (), .wdf_wren   (),
        .caf_addr (), .wdf_mask(),
        .wdf_data     (),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_FF]                    ),
        .SLR_valid(SLRs_valid           [SLR_FF]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_FF*32)+31:(SLR_FF*32)] ),
        .SLR_row       (SLRs_row       [(SLR_FF*10)+ 9:(SLR_FF*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_FF*10)+ 9:(SLR_FF*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_FF*10)+ 9:(SLR_FF*10)] )
    ) /* synthesis syn_noprune=1 */;


    LineEngine #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
        .SCANLINERUNNER(1), .LITTLEWORDIAN(0)
    ) le (
        .clk(clk),
        .rst(rst),
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
        .caf_full (1'b1), .wdf_full(1'b1),
        .caf_wren    (), .wdf_wren   (),
        .caf_addr (), .wdf_mask(),
        .wdf_data     (),
    //SLR interface (write-only):
        .SLR_ready(SLRs_ready           [SLR_LE]                    ),
        .SLR_valid(SLRs_valid           [SLR_LE]                    ),
        .SLR_frame     (SLRs_frame     [(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_color_fill(SLRs_color_fill[(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_color_edge(SLRs_color_edge[(SLR_LE*32)+31:(SLR_LE*32)] ),
        .SLR_row       (SLRs_row       [(SLR_LE*10)+ 9:(SLR_LE*10)] ),
        .SLR_col_start (SLRs_col_start [(SLR_LE*10)+ 9:(SLR_LE*10)] ),
        .SLR_col_finish(SLRs_col_finish[(SLR_LE*10)+ 9:(SLR_LE*10)] )
    ) /* synthesis syn_noprune=1 */;


    ElipseEngine #(
        .SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT)
    ) el (
        .clk(clk),
        .rst(rst),
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
    ) /* synthesis syn_noprune=1 */;


//synthesis translate_off

    always @(posedge clk) begin:_WATCH_SLR_
        integer idx;
        for (idx = 0; idx < SLR__CNT; idx = idx+1) begin
            if (SLRs_ready[idx] && SLRs_valid[idx] && WATCH_SLR) begin
                $display("%d SLR[%0d] ready=%b row=%0d s=%0d f=%0d",
                         $time, idx, SLRs_ready[idx],
                         SLRs_row       [(idx*10)+ 9 -: 10],
                         SLRs_col_start [(idx*10)+ 9 -: 10],
                         SLRs_col_finish[(idx*10)+ 9 -: 10]
                );
            end
        end
    end

//synthesis translate_on

endmodule

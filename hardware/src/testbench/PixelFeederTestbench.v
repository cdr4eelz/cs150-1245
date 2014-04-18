`timescale 1ns/1ns //NOTE: Very modest precision!

`include "../cpuglobal.vh"

module PixelFeederTestbench;

//Clocks driven at bottom (to encourage use of the clk*_g signals only)
wire clk29_g,   cpu_clk_g,  dvi_clk_g,  user_clk_g;
reg  rst_clk29, rst_clkCPU, rst_clkDVI, rst_clkUSER;

reg  rdf_valid, caf_full, video_ready;
reg  [127:0] rdf_data;
wire rdf_rden, caf_wren, video_valid, PF_irq;
wire [30:0]  caf_addr;
wire [23:0]  video;

PixelFeeder DUT (
    .cpu_clk_g(cpu_clk_g), .cpu_rst_g(rst_clkCPU),
    .dvi_clk_g(dvi_clk_g), .dvi_rst_g(rst_clkDVI),
    .rdf_valid(rdf_valid), .rdf_rden(rdf_rden), .rdf_data(rdf_data),
    .caf_full(caf_full), .caf_wren(caf_wren), .caf_addr(caf_addr),
    .video_ready(video_ready), .video_valid(video_valid), .video(video),
    .PF_valid(1'b1),
    .PF_frame(32'd1), //Use frame# & also "init" DURING reset
    .PF_irq(PF_irq),
    .PF_status()
);


reg [63:0] pixel_count, pixel_pace;
reg [23:0] pixel_value;

always @(posedge clk29_g) begin
    if (rst_clk29) pixel_pace <= 0;
    else pixel_pace <= pixel_pace + 1; //Value is used from dvi_clk_g domain (just sim anyway)
end

always @(posedge dvi_clk_g) begin
    if (rst_clkDVI) begin
        {video_ready, pixel_count} = 0; //pace incremented elsewhere!
    end else begin
        if (video_ready && video_valid) begin
            if ((pixel_count % (800*600/24)) == 0) begin
                $display("COLOR: %h (%0d,%0d,%0d)  #%0d", video,
                            video[23:16], video[15:8], video[7:0],
                            pixel_count);
            end
            pixel_count <= pixel_count + 1;
            pixel_value <= video;
        end
        video_ready <= (pixel_count < pixel_pace) ? 1'b1 : 1'b0;
    end
end


reg [31:0] frame_count;
reg [63:0] memory_request, memory_response;
reg memory_avail;

always @(posedge cpu_clk_g) begin
    if (rst_clkCPU) begin
        {frame_count, memory_request, memory_response, memory_avail} <= 0;
    end else begin
        if (PF_irq) frame_count <= frame_count + 1;
        if (caf_wren && !caf_full) memory_request <= memory_request + 2; //NOTE:2-to-1 ratio
        if (rdf_rden && rdf_valid) memory_response <= memory_response + 1;
        memory_avail <= 1'b1; //~memory_avail;
//TODO: Fiddle with memory_avail to mimic RequestController competition
    end
end

always @(*) begin //Each is sensitive to memory_* signals
    rdf_valid = (memory_avail && ((memory_request - memory_response) > 0));
    caf_full  = !(memory_avail && ((memory_request - memory_response) < 4));
    rdf_data = (!rdf_valid) ? {4{32'h00FFFFFF}} : {
                    memory_request[31:24], memory_response[21:0], 2'd0,
                    memory_request[23:16], memory_response[21:0], 2'd1,
                    memory_request[15: 8], memory_response[21:0], 2'd2,
                    memory_request[ 7: 0], memory_response[21:0], 2'd3
                };
end

reg  [31: 0] frameVal;
reg  [30:14] trigVal;
wire [30:14] trigWatch = caf_addr[30:14];

always @(posedge cpu_clk_g) begin
    if (frame_count !== frameVal) begin
        $display("\n*** Frame#%0d  PIX:%0d ***", frame_count, pixel_count);
        frameVal <= frame_count;
        if (frame_count >= 2) $finish();
    end

    if (trigWatch !== trigVal) begin //Frame w/Leading-zeros & upper 5-bits of Y
        $display("INT:%b F#%0d ADDR:%h  F:%b Y:%0d X:%0d",
                    PF_irq, frame_count, caf_addr,
                    caf_addr[20:19], //Frame (2-bits)
                    caf_addr[18:09], //Y (10-bits)
                    {caf_addr[08:00], 1'b0} //X (9-bits & a zero)
                );
        trigVal <= trigWatch;
    end
end


reg Clock, Reset;
initial Clock = 0;
always #(5) Clock <= ~Clock; //100MHz (board clock rate)

initial begin
    Reset = 1'b1;
    #(5 * 5);
    @(posedge user_clk_g);
    Reset = 1'b0;
    //Runs until framecount is sufficient (see $finish above)
end

    wire pll_fb, pll_lock, cpu_clk, dvi_clk, clk29;
    PLL_BASE
    #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(32),
        .CLKFBOUT_PHASE(0.0),
        .CLKIN_PERIOD(10.0),

        .CLKOUT0_DIVIDE(16), // 4 * 16/32 * 10ns = 20ns == 50MHz
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),

        .CLKOUT1_DIVIDE(16), // 4 * 16/32 * 10ns = 20ns == 50MHz
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(45.0), //NOTE:Out-of-phase with cpu_clk for testing

        .CLKOUT2_DIVIDE(3), // 4 * 3/32 * 10ns = 3.75ns ~= 26.7MHz (want 29MHz)
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT2_PHASE(90.0),

        .CLKOUT3_DIVIDE(4),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT3_PHASE(0.0),

        .CLKOUT4_DIVIDE(8),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT4_PHASE(0.0),

        .CLKOUT5_DIVIDE(16),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .CLKOUT5_PHASE(0.0),

        .COMPENSATION("SYSTEM_SYNCHRONOUS"),
        .DIVCLK_DIVIDE(4),
        .REF_JITTER(0.100)
    )
    user_clk_pll
    (
        .CLKFBOUT(pll_fb),
        .CLKOUT0(cpu_clk),
        .CLKOUT1(dvi_clk),
        .CLKOUT2(clk29),
        .CLKOUT3(),
        .CLKOUT4(),
        .CLKOUT5(),
        .LOCKED(pll_lock),
        .CLKFBIN(pll_fb),
        .CLKIN(user_clk_g),
        .RST(Reset)
    );

    IBUFG user_clk_buf ( .I(Clock),    .O(user_clk_g) );
    BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
    BUFG  dvi_clk_buf  ( .I(dvi_clk),  .O(dvi_clk_g)  );
    BUFG  clk29_buf    ( .I(clk29),    .O(clk29_g)    );

    always @(posedge user_clk_g or negedge pll_lock) begin
        if (!pll_lock) rst_clkUSER <= 1'b1;
        else rst_clkUSER <= 1'b0;
    end
    always @(posedge clk29_g   ) rst_clk29   <= rst_clkUSER;
    always @(posedge cpu_clk   ) rst_clkCPU  <= rst_clk29;
    always @(posedge dvi_clk   ) rst_clkDVI  <= rst_clk29;

endmodule

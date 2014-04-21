//*** Before include, must declare [local]param: ***
//      SLR__CNT, WATCH_NAME, LITTLEWORDIAN ***

    // FIFO connections
    reg             caf_full;
    wire            caf_wren;
    wire [ 30:0]    caf_addr;
    reg             wdf_full;
    wire            wdf_wren;
    wire [ 15:0]    wdf_mask;
    wire [127:0]    wdf_data;

    // FIFO Watcher
    wire [  9:0]    x, y;
    reg  [  2:0]    mask;
    always@(*) begin:_WATCH_FIFO_
        if(caf_wren == LITTLEWORDIAN) begin
            if(wdf_mask[15:12] == 4'h0) mask = 3'h0;
            else if(wdf_mask[11:8] == 4'h0) mask = 3'h1;
            else if(wdf_mask[7:4] == 4'h0) mask = 3'h2;
            else if(wdf_mask[3:0] == 4'h0) mask = 3'h3;
            else mask = 3'h0;
        end else begin
            if(wdf_mask[15:12] == 4'h0) mask = 3'h4;
            else if(wdf_mask[11:8] == 4'h0) mask = 3'h5;
            else if(wdf_mask[7:4] == 4'h0) mask = 3'h6;
            else if(wdf_mask[3:0] == 4'h0) mask = 3'h7;
            else mask = 3'h0;
        end
        if (!LITTLEWORDIAN) mask = ~mask;
    end
    assign x = {caf_addr[8:2], mask};
    assign y = caf_addr[18:9];
    always @(posedge Clock) begin:_WATCH_MASK_
        if (wdf_wren && (wdf_mask != 16'hFFFF)) begin
            $display("%d %s-TB: %4d %4d", $time, WATCH_NAME, x, y);
        end
    end

    //SLR Watcher
    wire [(SLR__CNT)-1:0] SLRs_ready;
    wire [(SLR__CNT)-1:0] SLRs_valid;
    wire [(SLR__CNT*32)-1:0] SLRs_frame;
    wire [(SLR__CNT*32)-1:0] SLRs_color_edge;
    wire [(SLR__CNT*32)-1:0] SLRs_color_fill;
    wire [(SLR__CNT*10)-1:0] SLRs_row;
    wire [(SLR__CNT*10)-1:0] SLRs_col_start;
    wire [(SLR__CNT*10)-1:0] SLRs_col_finish;
    assign SLRs_ready = {SLR__CNT{1'b1}};
    always @(posedge Clock) begin:_WATCH_SLR_
        integer idx;
        for (idx = 0; idx < SLR__CNT; idx = idx+1) begin
            if (SLRs_ready[idx] && SLRs_valid[idx]) begin
                $display("%d %s-SLR[%0d] ready=%b row=%0d s=%0d f=%0d",
                         $time, WATCH_NAME, idx, SLRs_ready[idx],
                         SLRs_row       [(idx*10)+ 9 -: 10],
                         SLRs_col_start [(idx*10)+ 9 -: 10],
                         SLRs_col_finish[(idx*10)+ 9 -: 10]
                );
            end
        end
    end

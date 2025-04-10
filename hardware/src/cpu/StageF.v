`include "../cpuglobal.vh"

//TODO: Check for misalignment (PC-FAULT) or just formally eliminate lower 2 bits
//TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
//TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)
//TODO: Watch for undesired circumstances such as missing delay-slots or back-to-back ISR

module StageF #(
    parameter PC_BOOT=32'h4000_0000, PC_ISR=32'hC000_0180,
    parameter PCWIDTH=32, INSTWIDTH=32, COUNTERWIDTH=32
)(
    input  wire clk, rst, stall,

    //Branch/Exception control to deviate from PC+4
    input  wire _DoBranch, _DoISR,
    input  wire[  (PCWIDTH-1):0] _PCBranch,

    //Outputs
    output wire[  (PCWIDTH-1):0] PC_, PCNEXT_,
    output wire[(INSTWIDTH-1):0] INST_,

    //Instruction memory taps
    output wire[  (PCWIDTH-1):0] IMEM_ADDR,
    input  wire[(INSTWIDTH-1):0] IMEM_Data,

    //Instruction related counters & reset (synchronous)
    input  wire _ResetCounters,
    output reg [(COUNTERWIDTH-1):0] CNT_CYCLE, CNT_INST, CNT_STALL, CNT_BRANCH, CNT_ISR,
    output reg WAS_RUNNING, WAS_INST, WAS_STALL, WAS_BRANCH, WAS_ISR
);

    reg [(PCWIDTH-1):0] REG_PC;
    always @(posedge clk) begin:_REG_PC_
        REG_PC <= IMEM_ADDR; //No need for reset or enable due to muxes
    end

    reg [(PCWIDTH-1):0] PC4;
    always @(*) begin:_INC_PC4_
        PC4 = (REG_PC+4); //Might sorta blend with PC into a counter w/set-reset-enable???
    end

    reg [(PCWIDTH-1):0] MUX_PCNEXT;
    always @(*) begin:_MUX_PCNEXT_
        //Encourage "flater" MUX style, despite obvious priority logic
        casex ({rst,stall,_DoBranch})
            3'b1xx: MUX_PCNEXT = PC_BOOT; //Normal boot
            3'b01x: MUX_PCNEXT = REG_PC; //Stall
            3'b001: MUX_PCNEXT = _PCBranch; //Branch
            3'b000: MUX_PCNEXT = PC4; //Next instruction
            default: MUX_PCNEXT = 0; //Fault in logic if reached
        endcase
    end

    reg [(PCWIDTH-1):0] REG_PCNEXT;
    always @(posedge clk) begin:_REG_PCNEXT_
        REG_PCNEXT <= MUX_PCNEXT; //After DoISR, remembers the "replaced" PC
    end

    assign PC_ = REG_PC, PCNEXT_ = REG_PCNEXT;
    assign INST_ = IMEM_Data;
    assign IMEM_ADDR = (_DoISR) ? PC_ISR : MUX_PCNEXT; //Fetch & advance to PC_ISR


    always @(posedge clk) begin:_REG_WAS_
        if (rst) begin
            {WAS_RUNNING,WAS_STALL,WAS_INST} <= 0;
            {WAS_BRANCH,WAS_ISR} <= 0;
        end else begin
            {WAS_RUNNING,WAS_STALL,WAS_INST} <= {1'b1,stall,!stall};
            if (!stall) {WAS_BRANCH,WAS_ISR} <= {_DoBranch,_DoISR};
        end
    end

    always @(posedge clk) begin:_COUNTERS_
        if (rst || _ResetCounters) begin
            {CNT_CYCLE,CNT_INST,CNT_STALL} <= 0;
            {CNT_BRANCH,CNT_ISR} <= 0;
        end else begin
            CNT_CYCLE <= CNT_CYCLE+1;
            if (!stall) CNT_INST <= CNT_INST+1;
            if (WAS_INST && stall) CNT_STALL <= CNT_STALL+1;
            if (!stall && _DoBranch) CNT_BRANCH <= CNT_BRANCH+1;
            if (!stall && _DoISR) CNT_ISR <= CNT_ISR+1;
        end
    end

endmodule

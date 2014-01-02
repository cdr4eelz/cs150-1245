`include "cpuglobal.vh"

module StageF #(
    parameter PCWIDTH=32, INSTWIDTH=32, COUNTERWIDTH=32,
    parameter BOOTPC=32'h4000_0000, // BIOS base address
    parameter ISR0PC=32'hC000_0000 // ISR handler base address (one shared for all causes)
)(
    input clk, rst, stall,

    //Branch/Exception control to deviate from PC+4
    input  _DoBranch, _DoException,
    input  [  (PCWIDTH-1):0] _PCBranch,

    //Outputs
    output [  (PCWIDTH-1):0] PC_,
    output [(INSTWIDTH-1):0] INST_,
    output                   DoneException_,

    //Instruction memory taps
    output [  (PCWIDTH-1):0] IMEM_ADDR,
    input  [(INSTWIDTH-1):0] IMEM_DATA,

    //Instruction related counters & reset (synchronous)
    output reg [(COUNTERWIDTH-1):0] CNT_Cycle, CNT_Stall, CNT_Step
);

    reg [(PCWIDTH-1):0] REG_PC, MUX_PCNEXT, PCp4;

    //Hoping imply nice FF & counters (could use utility modules instead)

    always @(posedge clk) begin:_REG_PC_
        if (rst) REG_PC <= BOOTPC; //PCNEXT must also match for I-Fetch
        else if (!stall) REG_PC <= MUX_PCNEXT;
    end

    always @(posedge clk) begin:_COUNT_CYCLE_
        if (rst) CNT_Cycle <= 0;
        else CNT_Cycle <= CNT_Cycle+1;
    end

    always @(posedge clk) begin:_COUNT_STALL_
        if (rst) CNT_Stall <= 0;
        else if (stall) CNT_Stall <= CNT_Stall+1;
    end

    always @(posedge clk) begin:_COUNT_STEP_
        if (rst) CNT_Step <= 0;
        else if (!stall) CNT_Step <= CNT_Step+1;
    end

    always @(*) begin:_ADD_PC_
        PCp4 = (REG_PC+4); //Could sorta blend with PC into a counter w/set-reset-enable???
    end

    always @(*) begin:_MUX_PCNEXT_
        //Encourage flat MUX despite priorities
        //3-selectors & 2 variable values -> 5-LUT hopefully!
        casex ({rst,stall,_DoBranch,_DoException})
            4'b1xxx: MUX_PCNEXT = BOOTPC; //Normal boot
            4'b01xx: MUX_PCNEXT = REG_PC;
            4'b001x: MUX_PCNEXT = _PCBranch;
            4'b0001: MUX_PCNEXT = ISR0PC;
            4'b0000: MUX_PCNEXT = PCp4;
            default: MUX_PCNEXT = BOOTPC; //Normal boot or fault in branch signals
        endcase
    end

    assign PC_ = REG_PC;
    assign INST_ = IMEM_DATA;
    assign IMEM_ADDR = MUX_PCNEXT;
    assign DoneException_ = 1'b0;

    //TODO: Check for misalignment (PC-FAULT) or just formally eliminate lower 2 bits
    //TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
    //TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)

endmodule

`include "cpuglobal.vh"

//TODO: Check for misalignment (PC-FAULT) or just formally eliminate lower 2 bits
//TODO: Detect a halt, a.k.a. a jump-to-self loop (great for software simulation termination)
//TODO: Keep small breakpoint table and give debug notification (and maybe trigger self-stall)

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
    output                   DONEEXCEPTION_,

    //Instruction memory taps
    output [  (PCWIDTH-1):0] IMEM_ADDR,
    input  [(INSTWIDTH-1):0] IMEM_Data,

    //Instruction related counters & reset (synchronous)
    input _ResetCNT,
    output reg [(COUNTERWIDTH-1):0] CNT_CYCLE, CNT_INST, CNT_STALL,
    output reg WAS_STALL, WAS_INST
);

    reg [(PCWIDTH-1):0] REG_PC, PC4, MUX_PCNEXT;

    always @(*) begin:_INC_PC4_
        PC4 = (REG_PC+4); //Could sorta blend with PC into a counter w/set-reset-enable???
    end

    always @(*) begin:_MUX_PCNEXT_
        //Encourage "flater" MUX style, despite obvious priority logic
        casex ({rst,stall,_DoBranch,_DoException})
            4'b1xxx: MUX_PCNEXT = BOOTPC; //Normal boot
            4'b01xx: MUX_PCNEXT = REG_PC; //Stall
            4'b001x: MUX_PCNEXT = _PCBranch; //Branch
            4'b0001: MUX_PCNEXT = ISR0PC; //Interrupt/Exception
            4'b0000: MUX_PCNEXT = PC4; //Next instruction
            default: MUX_PCNEXT = 0; //Fault in logic if reached
        endcase
    end

    always @(posedge clk) begin:_REG_PC_
        if (rst) REG_PC <= BOOTPC; //PCNEXT must also match for I-Fetch
        else if (!stall) REG_PC <= MUX_PCNEXT;
    end

    assign PC_ = REG_PC;
    assign INST_ = IMEM_Data;
    assign IMEM_ADDR = MUX_PCNEXT;
    assign DONEEXCEPTION_ = _DoException && !_DoBranch;


    always @(posedge clk) begin:_REG_WAS_
        if (rst || _ResetCNT) {WAS_STALL,WAS_INST} <= 0;
        else {WAS_STALL,WAS_INST} <= {stall,!stall};
    end

    always @(posedge clk) begin:_COUNT_CYCLE_
        if (rst || _ResetCNT) CNT_CYCLE <= 0;
        else CNT_CYCLE <= CNT_CYCLE+1;
    end

    always @(posedge clk) begin:_COUNT_INST_
        if (rst || _ResetCNT) CNT_INST <= 0;
        else if (!stall) CNT_INST <= CNT_INST+1;
    end

    always @(posedge clk) begin:_COUNT_STALL_
        if (rst || _ResetCNT) CNT_STALL <= 0;
        else if (WAS_INST && stall) CNT_STALL <= CNT_STALL+1;
    end

endmodule

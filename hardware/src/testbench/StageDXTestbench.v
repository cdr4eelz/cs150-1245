`timescale 1ns/1ps

`include "cpuglobal.vh"
`include "opcode.vh"

module StageDXTestbench;

    // No Clock Signal

    reg [31:0] REGFILE [0:31];

    //Ignoring control line outputs
    //Just focusing on datapath stuff
    reg [31:0] PC_DX;
    reg [31:0] INST_DX;
    wire [31:0] ALUOut;
    wire [31:0] RTValue;
    wire [31:0] JumpPC;
    wire        DoJump;

    wire [ 4:0 ] DestReg;
    wire [ 1:0 ] MemShift;
    wire MemSigned, MemToReg, MemWrite;

    wire [ 4: 0] REG_ra1, REG_ra2;
    wire [31: 0] #1 REG_rd1, REG_rd2;
    assign REG_rd1 = REGFILE[REG_ra1], REG_rd2 = REGFILE[REG_ra2];
    StageDX DUT
    ( //.clk(1'bx), .rst(1'bx), .stall(1'bx),
        .REG_R1_(REG_ra1),  .REG_D1_(REG_rd1),
        .REG_R2_(REG_ra2),  .REG_D2_(REG_rd2),
        .CopAddr(), .CopOut(32'd0), .CopInHot(),
        //Stage Inputs
        ._PC(PC_DX), ._INST(INST_DX),
        //Global control signals
        .DestReg_(DestReg),
        .MemShift_(MemShift), .MemSigned_(MemSigned),
        .MemToReg_(MemToReg), .MemWrite_(MemWrite),
        //Stage Outputs
        .MemAddr_(), .RegWValue_(ALUOut),
        .MemWValue_(RTValue),
        //Feedback outputs
        .DOBranch_(DoJump), .PCBranch_(JumpPC)
    );

    integer step = 0;

    task exec_inst;
        input [31:0] inst;
        reg [31:0] pc;
        begin
            step = step + 1;
            pc = PC_DX; PC_DX = 32'bz; INST_DX = 32'd0;
            #1;
            PC_DX = pc; INST_DX = inst;
            $display("DX>: PC_DX=%h  INST=%h", PC_DX, INST_DX);
            #9;
            $display("DX<: DEST=%d ALU=%h(%d) RT=%h(%d), JPC=%h",
            DestReg, ALUOut, ALUOut, RTValue, RTValue, JumpPC);
        end
    endtask

    initial REGFILE[0] = 0;
    task li;
        input [4:0] addr;
        input [31:0] value;
        begin
            $display("R[%h,%d] <= %h (%d)  was %h (%d)",
            addr, addr, value, value, REGFILE[addr], REGFILE[addr]);
            if (addr != 0) REGFILE[addr] = value;
        end
    endtask

    task check_alu;
        input [31:0] expected;
        if (expected !== ALUOut) begin
            $display("Expected ALUOut = %h, got %h", expected, ALUOut);
            $finish();
        end
    endtask

    task check_dout;
        input [31:0] expected;
        if (expected !== RTValue) begin
            $display("Expected mem-stage Din = %h, got %h", expected, RTValue);
            $finish();
        end
    endtask

    task check_jump;
        input [31:0] expected;
        if (expected !== JumpPC) begin
            $display("Expected jump/branch target address JumpPC = %h, got %h", expected, JumpPC);
            $finish();
        end
    endtask

    task check_jumping;
        input expected, expectlink;
        if ({expected,expectlink} !== {DoJump,(DestReg != 0)}) begin
            $display("Expected: J:%b,L:%b, but got J:%b,L:%b",
                expected,expectlink, DoJump,(DestReg != 0));
            $finish();
        end
    endtask


    reg [5:0] xx;
    // Testing logic:
    initial begin
        // Basic reset setup
        PC_DX = 0;
        exec_inst(32'd0);

        //Write to $r1 and $r2 and $ra
        li(5'd1, 32'hBABECAFE);
        li(5'd2, 32'h00000001);
        li(5'd31, 32'hFEDCBA98);

        $display("\nTesting add/sub:");

        $display("\nADDU $6, $1, $2  ($r1 + $r2)");
        exec_inst({`OP_SPECIAL,5'd1,5'd2,5'd6,5'b00000, `OF_ADDU});
        check_alu(32'hBABECAFF);

        $display("\nSUBU $6, $1, $2  ($r1 - $r2)");
        exec_inst({`OP_SPECIAL, 5'd1, 5'd2, 5'd6, 5'b00000, `OF_SUBU});
        check_alu(32'hBABECAFD);

        $display("\nADDIU $7, $1, 0xffff  ($r1 + (-1))");
        exec_inst({`OP_ADDIU, 5'd1, 5'd7, 16'hffff});
        check_alu(32'hBABECAFD);

        $display("\nADDIU $8, $1, 0x000A  ($r1 + 10)");
        exec_inst({`OP_ADDIU, 5'd1, 5'd8, 16'd10});
        check_alu(32'hBABECB08);

        $display("\nTesting shifts:");

        $display("\nSLL $10, $1, 4  ($r1 << 4)");
        exec_inst({`OP_SPECIAL, 5'b00000, 5'd1, 5'hA, 5'b00100, `OF_SLL});
        check_alu(32'hABECAFE0);

        $display("\nSRL $11, $1, 4  ($r1 >> 4, logical)");
        exec_inst({`OP_SPECIAL, 5'b00000, 5'd1, 5'hB, 5'b00100, `OF_SRL});
        check_alu(32'h0BABECAF);

        $display("\nSRA $12, $1, 4  ($r1 >>> 4, arithmetic)");
        exec_inst({`OP_SPECIAL, 5'b00000, 5'd1, 5'hC, 5'b00100, `OF_SRA});
        check_alu(32'hFBABECAF);

        //Let's do variable-bit shifts
        li(5'd2, 32'h00000008);

        $display("\nSLLV $13, $1, $2  ($r1 << $r2=8)");
        exec_inst({`OP_SPECIAL, 5'd2, 5'd1, 5'hD, 5'b00000, `OF_SLLV});
        check_alu(32'hBECAFE00);

        $display("\nSRLV $14, $1, $2  ($r1 >> $r2=8, logical)");
        exec_inst({`OP_SPECIAL, 5'd2, 5'd1, 5'hE, 5'b00000, `OF_SRLV});
        check_alu(32'h00BABECA);

        $display("\nSRAV $15, $1, $2  ($r1 >>> $r2=8, arithmetic)");
        exec_inst({`OP_SPECIAL, 5'd2, 5'd1, 5'hF, 5'b00000, `OF_SRAV});
        check_alu(32'hFFBABECA);

        //Set $r2 back to 1
        li(5'd2, 32'h00000001);


        $display("\nLUI $0, 0xBEEF (only ALU output, not reg value)");
        exec_inst({`OP_LUI, 5'b00000, 5'd0, 16'hBEEF});
        check_alu(32'hBEEF0000);

        $display("\nSLTI:");
        //positive comparison (1 vs 2)
        exec_inst({`OP_SLTI, 5'd2, 5'd0, 16'h0002});
        check_alu(32'h00000001);

        //negative comparison (1 vs -1)
        exec_inst({`OP_SLTI, 5'd2, 5'd0, 16'hFFFF});
        check_alu(32'h00000000);

        //Test loads
        li(5'd3, 32'hCEDE0004);

        $display("\nLB $r0, 0x0ABE($r3)");
        exec_inst({`OP_LB, 5'd3, 5'd9, 16'h0ABE});
        check_alu(32'hCEDE0AC2);

        $display("\nSB $r1, 0x0ABE($r3)");
        exec_inst({`OP_SB, 5'd3, 5'd1, 16'h0ABE});
        check_alu(32'hCEDE0AC2);
        check_dout(32'hBABECAFE);

        //Test branches
        li(5'd4, 32'hBABECAFE);
        li(5'd5, 32'hFFFFFFFF);

        $display("\nBEQ:");
        exec_inst({`OP_BEQ, 5'd1, 5'd4, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_BEQ, 5'd1, 5'd1, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_BEQ, 5'd1, 5'd2, 16'h0ABE});
        check_jumping(0, 0);

        $display("\nBNE:");
        exec_inst({`OP_BNE, 5'd1, 5'd4, 16'h0ABE});
        check_jumping(0, 0);

        exec_inst({`OP_BNE, 5'd1, 5'd2, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        $display("\nBLEZ:");
        xx = `OP_BLEZ;
        $display("BLEZ: %b %b %b %b %b", xx, xx[5:3], xx[2:1], ~|xx[5:3], ~^xx[2:1]);
        exec_inst({`OP_BLEZ, 5'd0, 5'b00000, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_BLEZ, 5'd5, 5'b00000, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_BLEZ, 5'd2, 5'b00000, 16'h0ABE});
        check_jumping(0, 0);

        $display("\nBGTZ:");
        exec_inst({`OP_BGTZ, 5'd0, 5'b00000, 16'h0ABE});
        check_jumping(0, 0);

        exec_inst({`OP_BGTZ, 5'd2, 5'b00000, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_BGTZ, 5'd5, 5'b00000, 16'h0ABE});
        check_jumping(0, 0);

        $display("\nBLTZ:");
        exec_inst({`OP_REGIMM, 5'd0, `OR_BLTZ, 16'h0ABE});
        check_jumping(0, 0);

        exec_inst({`OP_REGIMM, 5'd2, `OR_BLTZ, 16'h0ABE});
        check_jumping(0, 0);

        exec_inst({`OP_REGIMM, 5'd5, `OR_BLTZ, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        $display("\nBLTZAL:");
        exec_inst({`OP_REGIMM, 5'd2, `OR_BLTZAL, 16'h0ABE});
        check_jumping(0, 0);

        exec_inst({`OP_REGIMM, 5'd5, `OR_BLTZAL, 16'h0ABE});
        check_jumping(1, 1);
        check_jump(PC_DX + 4 + 16'h2AF8);

        $display("\nBGEZ:");
        exec_inst({`OP_REGIMM, 5'd0, `OR_BGEZ, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_REGIMM, 5'd2, `OR_BGEZ, 16'h0ABE});
        check_jumping(1, 0);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_REGIMM, 5'd5, `OR_BGEZ, 16'h0ABE});
        check_jumping(0, 0);

        $display("\nBGEZAL:");
        exec_inst({`OP_REGIMM, 5'd2, `OR_BGEZAL, 16'h0ABE});
        check_jumping(1, 1);
        check_jump(PC_DX + 4 + 16'h2AF8);

        exec_inst({`OP_REGIMM, 5'd5, `OR_BGEZAL, 16'h0ABE});
        check_jumping(0, 0);

        //Test jumps
        $display("\nJ:");
        exec_inst({`OP_J, 26'h0DEC0DE});
        check_jump({PC_DX[31:28], 28'h37B0378});
        check_jumping(1, 0);

        $display("\nJAL:");
        exec_inst({`OP_JAL, 26'h0DEC0DE});
        check_jump({PC_DX[31:28], 28'h37B0378});
        check_jumping(1, 1);

        $display("\nJR:");
        exec_inst({`OP_SPECIAL, 5'd1, 5'b00000, 5'b00000, 5'b00000, `OF_JR});
        check_jump(32'hBABECAFE);
        check_jumping(1, 0);
        exec_inst({`OP_SPECIAL, 5'd31, 5'b00000, 5'b00000, 5'b00000, `OF_JR});
        check_jump(32'hFEDCBA98);
        check_jumping(1, 0);

        $display("\nJALR:");
        exec_inst({`OP_SPECIAL, 5'd1, 5'b00000, 5'd0, 5'b00000, `OF_JALR});
        check_jump(32'hBABECAFE);
        check_jumping(1, 1);
        exec_inst({`OP_SPECIAL, 5'd31, 5'b00000, 5'd0, 5'b00000, `OF_JALR});
        check_jump(32'hFEDCBA98);
        check_jumping(1, 1);

        $display("All tests passed!");
        $finish();
    end
endmodule

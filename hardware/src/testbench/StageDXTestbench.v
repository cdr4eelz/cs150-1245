`timescale 1ns / 1ps

`include "Opcode.vh"
`include "CPUBusses.vh"

module StageDXTestbench;

    // No Clock Signal
    
    reg [31:0] REGFILE [0:31];
    `BUS_ICTL_type IControlDX_;
    `BUS_CPUGlobal_type CPUGlobal;
    
    //Ignoring control line outputs
    //Just focusing on datapath stuff
    reg [31:0] PC;
    reg [31:0] Inst;
    wire [31:0] ALUOut;
    wire [31:0] RTValue;
    wire [31:0] JumpPC;
    wire 		DoJump;
    
    wire [ 4: 0] REG_ra1, REG_ra2;
    wire [31: 0] #1 REG_rd1, REG_rd2;
    assign REG_rd1 = REGFILE[REG_ra1], REG_rd2 = REGFILE[REG_ra2];
    wire [31: 0] ALUOutDX_, R2ValueDX_, PCPLUS8DX_;
    StageDX DUT
    ( .CPUGlobal(CPUGlobal),
        .REG_R1_    (REG_ra1),          .REG_R2_    (REG_ra2),
        .REG_D1_    (REG_rd1),          .REG_D2_    (REG_rd2),
        //Inputs
        .PC         (PC),               .INST       (Inst),
        //Outputs
        .IControl_  (IControlDX_),
        .ALUOut_    (ALUOut),
        .R2Value_   (RTValue),
        .PCPLUS8_   (),
        //Feedbacks
        .PCNext_    (JumpPC) // Feedback to WF stage
    );
    assign DoJump = (JumpPC != (PC+4));
    
    integer step = 0;
    
    task exec_inst;
        input [31:0] inst;
        reg [31:0] pc;
        begin
            step = step + 1;
            pc = PC; PC = 32'bz; Inst = 32'bz;
            #1;
            PC = pc; Inst = inst;
            $display("DX>: PC=%h  INST=%h", PC, Inst);
            #9;
            $display("DX<: ALU=%h(%d) RT=%h(%d), JPC=%h",
            ALUOut, ALUOut, RTValue, RTValue, JumpPC);
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
        input expected;
        if (expected !== DoJump) begin
            if (expected)
                $display("Expected to jump, but got DoJump = %d instead", DoJump);
            else
                $display("Didn't expect to jump, but got DoJump = %d instead", DoJump);
            $finish();
        end
    endtask
    
    
    reg [5:0] xx;
    // Testing logic:
    initial begin
        // Basic reset setup
        PC = 0;
        exec_inst(32'd0);
        
        //Write to $r1 and $r2
        li(5'd1, 32'hBABECAFE);
        li(5'd2, 32'h00000001);
        
        $display("Testing addition");
        
        //Compute $r1 + $r2
        exec_inst({`RTYPE,5'd1,5'd2,5'd6,5'b00000,`ADDU});
        check_alu(32'hBABECAFF);
        
        //Compute $r1 - $r2
        exec_inst({`RTYPE, 5'd1, 5'd2, 5'd6, 5'b00000, `SUBU});
        check_alu(32'hBABECAFD);
        
        //Compute $r1 + (-1)
        exec_inst({`ADDIU, 5'd1, 5'd7, 16'hffff});
        check_alu(32'hBABECAFD);
        
        //Compute $r1 + 10
        exec_inst({`ADDIU, 5'd1, 5'd8, 16'd10});
        check_alu(32'hBABECB08);
        
        $display("Testing shifting");
        
        //Compute $r1 << 4
        exec_inst({`RTYPE, 5'b00000, 5'd1, 5'hA, 5'b00100, `SLL});
        check_alu(32'hABECAFE0);
        
        //Compute $r1 >> 4 (logical)
        exec_inst({`RTYPE, 5'b00000, 5'd1, 5'hB, 5'b00100, `SRL});
        check_alu(32'h0BABECAF);
        
        //Compute $r1 >>> 4 (arithmetic)
        exec_inst({`RTYPE, 5'b00000, 5'd1, 5'hC, 5'b00100, `SRA});
        check_alu(32'hFBABECAF);
        
        //Let's do variable-bit shifts
        li(5'd2, 32'h00000008);
        
        //Compute $r1 << $r2 (8)
        exec_inst({`RTYPE, 5'd2, 5'd1, 5'hD, 5'b00000, `SLLV});
        check_alu(32'hBECAFE00);
        
        //Compute $r1 >> $r2 (logical, 8)
        exec_inst({`RTYPE, 5'd2, 5'd1, 5'hE, 5'b00000, `SRLV});
        check_alu(32'h00BABECA);
        
        //Compute $r1 >>> $r2 (arithmetic, 8)
        exec_inst({`RTYPE, 5'd2, 5'd1, 5'hF, 5'b00000, `SRAV});
        check_alu(32'hFFBABECA);
        
        //Set $r2 back to 1
        li(5'd2, 32'h00000001);
        
        
        $display("Testing LUI");
        
        //Test LUI
        exec_inst({`LUI, 5'b00000, 5'd0, 16'hBEEF});
        check_alu(32'hBEEF0000);
        
        $display("Testing comparisons");
        
        //Test SLTI
        //positive comparison (1 vs 2)
        exec_inst({`SLTI, 5'd2, 5'd0, 16'h0002});
        check_alu(32'h00000001);
        
        //negative comparison (1 vs -1)
        exec_inst({`SLTI, 5'd2, 5'd0, 16'hFFFF});
        check_alu(32'h00000000);
        
        $display("Testing load/store");
        
        //Test loads
        li(5'd3, 32'hCEDE0004);
        
        //LB $r0, 0x0ABE($r3)
        exec_inst({`LB, 5'd3, 5'd9, 16'h0ABE});
        check_alu(32'hCEDE0AC2);
        
        //SB $r1, 0x0ABE($r3)
        exec_inst({`SB, 5'd3, 5'd1, 16'h0ABE});
        check_alu(32'hCEDE0AC2);
        check_dout(32'hBABECAFE);
        
        $display("Testing branches");
        
        //Test branches
        li(5'd4, 32'hBABECAFE);
        li(5'd5, 32'hFFFFFFFF);
        
        exec_inst({`BEQ, 5'd1, 5'd4, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        
        exec_inst({`BEQ, 5'd1, 5'd1, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        exec_inst({`BEQ, 5'd1, 5'd2, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BNE, 5'd1, 5'd4, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BNE, 5'd1, 5'd2, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        xx = `BLEZ;
        $display("BLEZ: %b %b %b %b %b", xx, xx[5:3], xx[2:1], ~|xx[5:3], ~^xx[2:1]);
        exec_inst({`BLEZ, 5'd0, 5'b00000, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        exec_inst({`BLEZ, 5'd5, 5'b00000, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        exec_inst({`BLEZ, 5'd2, 5'b00000, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BGTZ, 5'd0, 5'b00000, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BGTZ, 5'd2, 5'b00000, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        exec_inst({`BGTZ, 5'd5, 5'b00000, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BLTZ, 5'd0, 5'b00000, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BLTZ, 5'd2, 5'b00000, 16'h0ABE});
        check_jumping(0);
        
        exec_inst({`BLTZ, 5'd5, 5'b00000, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        //Really BGEZ
        exec_inst({`BLTZ, 5'd0, 5'b00001, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        exec_inst({`BLTZ, 5'd2, 5'b00001, 16'h0ABE});
        check_jumping(1);
        check_jump(PC + 4 + 16'h2AF8);
        
        exec_inst({`BLTZ, 5'd5, 5'b00001, 16'h0ABE});
        check_jumping(0);
        
        $display("Testing jumps");
        
        //Test jumps
        exec_inst({`J, 26'h0DEC0DE});
        check_jump({PC[31:28], 28'h37B0378});
        check_jumping(1);
        
        exec_inst({`RTYPE, 5'd1, 5'b00000, 5'b00000, 5'b00000, `JR});
        check_jump(32'hBABECAFE);
        check_jumping(1);
        
        exec_inst({`JAL, 26'h0DEC0DE});
        check_jump({PC[31:28], 28'h37B0378});
        check_jumping(1);
        
        exec_inst({`RTYPE, 5'd1, 5'b00000, 5'd0, 5'b00000, `JALR});
        check_jump(32'hBABECAFE);
        check_jumping(1);
        
        $display("All tests passed!");
        $finish();
    end
endmodule

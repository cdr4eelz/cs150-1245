`ifndef OPCODE
`define OPCODE

// OPCODES
`define OP_SPECIAL  6'b000_000  //CATEGORY: func-code [5:0]
`define OP_REGIMM   6'b000_001  //CATEGORY: rt-code [20:16]
`define OP_J        6'b000_010  //J: JUMP-simple
`define OP_JAL      6'b000_011  //J: JUMP-simple, LINK
`define OP_BEQ      6'b000_100  //I: BRANCH-simple
`define OP_BNE      6'b000_101  //I: BRANCH-simple
`define OP_BLEZ     6'b000_110  //I: BRANCH-zeroop
`define OP_BGTZ     6'b000_111  //I: BRANCH-zeroop
//  UNIMP: 000_none
`define OP_ADDI     6'b001_000  //I: ALU *might EXCEPTION
`define OP_ADDIU    6'b001_001  //I: ALU
`define OP_SLTI     6'b001_010  //I: ALU
`define OP_SLTIU    6'b001_011  //I: ALU
`define OP_ANDI     6'b001_100  //I: ALU
`define OP_ORI      6'b001_101  //I: ALU
`define OP_XORI     6'b001_110  //I: ALU
`define OP_LUI      6'b001_111  //I: ALU
//  UNIMP: 001_none
`define OP_COP0     6'b010_000  //COP0: rs-code [25:21]
//  UNIMP: !010_000 (coprocessor ops & branch-likely)
//  UNIMP: 011_xxx (double-word)
`define OP_LB       6'b100_000  //I: MEM-LOAD
`define OP_LH       6'b100_001  //I: MEM-LOAD
`define OP_LWL      6'b100_010  //I: MEM-LOAD *LEFT/RIGHT
`define OP_LW       6'b100_011  //I: MEM-LOAD
`define OP_LBU      6'b100_100  //I: MEM-LOAD
`define OP_LHU      6'b100_101  //I: MEM-LOAD
`define OP_LWR      6'b100_110  //I: MEM-LOAD *LEFT/RIGHT
//  UNIMP: 100_111 (double-word)
`define OP_SB       6'b101_000  //I: MEM-STORE
`define OP_SH       6'b101_001  //I: MEM-STORE
`define OP_SWL      6'b101_010  //I: MEM-STORE *LEFT/RIGHT
`define OP_SW       6'b101_011  //I: MEM-STORE
`define OP_SWR      6'b101_110  //I: MEM-STORE *LEFT/RIGHT
//  UNIMP: 101_10x && 101_111 (double-word)
//  UNIMP: 110_xxx (cache, coprocessors, double-word)
//  UNIMP: 111_xxx (cache, coprocessors, double-word)


// SPECIAL: func-code (usually R-type)
`define OF_SLL      6'b000_000  //R: ALU
`define OF_SRL      6'b000_010  //R: ALU
`define OF_SRA      6'b000_011  //R: ALU
`define OF_SLLV     6'b000_100  //R: ALU
`define OF_SRLV     6'b000_110  //R: ALU
`define OF_SRAV     6'b000_111  //R: ALU
//  UNIMP: 000_x01
`define OF_JR       6'b001_000  //R: JUMP-REG
`define OF_JALR     6'b001_001  //R: JUMP-REG
`define OF_SYSCALL  6'b001_100  //EXCEPTION: *syscall
`define OF_BREAK    6'b001_101  //EXCEPTION: *break
//  UNIMP: 001_x1x
`define OF_MFHI     6'b010_000  //R: *MATH
`define OF_MTHI     6'b010_001  //R: *MATH
`define OF_MFLO     6'b010_010  //R: *MATH
`define OF_MTLO     6'b010_011  //R: *MATH
//  UNIMP: 010_1xx
`define OF_MULT     6'b011_000  //R: *MATH
`define OF_MULTU    6'b011_001  //R: *MATH
`define OF_DIV      6'b011_010  //R: *MATH
`define OF_DIVU     6'b011_011  //R: *MATH
//  UNIMP: 011_1xx
`define OF_ADD      6'b100000   //R: ALU *EXCEPTION
`define OF_ADDU     6'b100001   //R: ALU
`define OF_SUB      6'b100010   //R: ALU *EXCEPTION
`define OF_SUBU     6'b100011   //R: ALU
`define OF_AND      6'b100100   //R: ALU
`define OF_OR       6'b100101   //R: ALU
`define OF_XOR      6'b100110   //R: ALU
`define OF_NOR      6'b100111   //R: ALU
//  UNIMP: none!
`define OF_SLT      6'b101010   //R: ALU
`define OF_SLTU     6'b101011   //R: ALU
//  UNIMP: 101_00x && 101_1xx
//  UNIMP: 110_xxx (trap-if)
//  UNIMP: 111_xxx (double-words)


// REGIMM rt-codes
`define OR_BLTZ     5'b00000
`define OR_BGEZ     5'b00001
`define OR_BLTZAL   5'b10000
`define OR_BGEZAL   5'b10001
//  UNIMP: all others (branch-likely, traps)


// COP0 moves from/to identified by $rs value:
`define OS_MFC0     5'b00000    //from (like load/read)
`define OS_MTC0     5'b00100    //to (like store/write)
//  UNIMP: all others


/*
OPCODE: op 6-bits INST[31:26]              [lo 3 bits across table]
000: SPECIAL,REGIMM,j,      jal,    beq,    bne,    blez,   bgtz
001: addi*, addiu,  slti,   sltiu,  andi,   ori,    xori,   lui
010: cop0,  cop1*,  cop2*,  cop1x*, @beql,  @bnel,  @blezl, @bgtzl
011: #daddi,#daddiu,#ldl,   #ldr,   *,      *,      *,      *
100: lb,    lh,     lwl,    lw,     lbu,    lhu,    lwr,    #lwu
101: sb,    sh,     swl,    sw,     #sdl,   #sdr,   swr,    *?
110: @ll,   lwc1*,  lwc2*,  @pref,  #@lld,  #ldc1,  #ldc2,  #@ld
111: @sc,   swc1*,  swc2*,  *,      #@scd,  #sdc1,  #sdc2,  #@sd

SPECIAL: func 6-bits INST[5:0]
000: sll,   @movci, srl,    sra,    sllv,   *,      srlv,   srav
001: jr,    jalr,   @movz,  @movn,  +syscall,+break,*,      @sync
010: +mfhi, +mthi,  +mflo,  +mtlo,  #dsllv, *,      #dsrlv, #dsrav
011: +mult, +multu, +div,   +divu,  #dmult, #dmultu,#ddiv,  #ddivu
100: +add*, addu,   +sub*,  subu,   and,    or,     xor,    nor
101: *,     *,      slt,    sltu,   #dadd,  #daddu, #dsub,  #dsubu
110: @tge,  @tgeu,  @tlt,   @tltu,  @teq,   *,      @tne,   *
111: #dsll, *,      #dsrl,  #dsra,  #dsll32,*,      #dsrl32,#dsra32

REGIMM: rt 5-bits INST[20:16]
00: bltz,   bgez,   @bltzl, @bgezl, *,      *,      *,      *
01: @tgei, @tgeiu,  @tlti,  @tltiu, @teqi,  *,      @tnei,  *
10: bltzal, bgezal, @bltzall,@bgezall,*,    *,      *,      *
11: *,      *,      *,      *,      *,      *,      *,      *

    [ * undefined/unimplemented ; # double-word ; @ beyond MIPS-I ]

::BEYOND CS150 but still in MIPS-I::
lwl,lwr,swl,swr         |op=10[l/s][l/r]01
syscall,break           |op=SPECIAL & func=00110[syscall/break]
mfhi,fthi,mflo,mtlo     |op=SPECIAL & func=0100[hi/lo][f/t]
mult,multu,div,divu     |op=SPECIAL & func=0110[mul/div][s/u]
bltzal, bgezal          |op=REGIMM  & rt=1000[lt/ge]
addi & add/sub          |op & special w/exception on overflow

::COP0 important::
Exception in delay slot resumes by repeating branch/jump instruction!
Things sw might use: features present (fpu, etc), coprocessor-enable (available),
    cpu-version, cache status (faked?)
Exceptions: coprocessor-useable, reserved-instruction, address-error, ...


::MIPS-I::
* Unaligned left/right words (can be sequential, in delay slot)

::MIPS-II::
* NO LOAD DELAY SLOTS ANYWHERE! (Might stall instead?) Branch delays?
beql,bnel,blezl,bgtzl, bltzl,bgezl,bltzall,bgezall
ll,sc,ldc1/3,sdc1/2/3,sync (atomic/cache)
tge,tgeu,tlt,tltu,teq,tne, tgei,tgeiu,tlti,tltiu,teqi,tnei
* Branch-Likely skips delay slot if not-branch! Any branch delays?
* Cache-ops plus some COP0 registers for cache?

::MIPS-III::
daddi,daddiu, dsllv,dsrlv,dsrav,dmult,dmultu,ddiv,ddivu
dadd,daddu,dsub,dsubu, dsll,dsrl,dsra,dsll32,dsrl32,dsra32
ldl,ldr,lwu,sdl,sdr, lld,ld,scd,sd

::MIPS-IV::
pref(etch), cop1x, movci,movz,movn

*/

`endif //OPCODE

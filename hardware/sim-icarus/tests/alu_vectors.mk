# ALU test vectors from ../sim/tests/testvectors.input (hardware/src/testbench/ALUTestVectorTestbench.v)
alu_vectors.TOP      := ALUTestVectorTestbench
alu_vectors.TB       := $(TBSRC)/ALUTestVectorTestbench.v
alu_vectors.YDIRS    := $(SRC_YDIRS)
alu_vectors.RUNFILES := ../sim/tests/testvectors.input
alu_vectors.PASS_RE  := ^ALL TESTS PASSED

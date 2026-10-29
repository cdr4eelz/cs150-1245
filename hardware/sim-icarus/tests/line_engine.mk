# gpu/LineEngine.v: pixel set of each line vs. the ideal line (count, coverage, <= 1/2 pixel off,
# connected), SLR fields, random back-pressure; original bench set + edge cases + random lines
line_engine.TOP  := LineEngine_check_tb
line_engine.TB   := tb/LineEngine_check_tb.v
line_engine.SRCS := $(SRC)/gpu/LineEngine.v
line_engine.QUIET_RE := ^\[=LINE=\]|^        : \(

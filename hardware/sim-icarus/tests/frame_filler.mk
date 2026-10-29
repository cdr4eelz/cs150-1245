# gpu/FrameFiller.v: one SLR request per row 0..599 spanning 0..799, frame clipping, colors,
# FF_ready handshake, random back-pressure (tb/FrameFiller_check_tb.v)
frame_filler.TOP      := FrameFiller_check_tb
frame_filler.TB       := tb/FrameFiller_check_tb.v
frame_filler.SRCS     := $(SRC)/gpu/FrameFiller.v
frame_filler.QUIET_RE := ^\[=FILL=\]

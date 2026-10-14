# Shared C/ISR constants. Keep offsets synchronized with struct SM_DATA in shared.h.
.equiv  K_SHBUF_SIZEB,      0x0100
.equiv  K_SHBUF_ROLLOVER,   0x00FF
.equiv  K_MAGIC_VERSION,    0xFEDBEEF1
.equiv  K_CPU_HZ,           50000000
.equiv  K_TIMER_HZ,         1
.equiv  K_TIMER_CYC,        (K_TIMER_HZ * K_CPU_HZ)

.equiv  SM_BASE,            0x50000000
.equiv  SMO_magic,          0x0000
.equiv  SMO_stash0,         0x0004
.equiv  SMO_stash1,         0x0008
.equiv  SMO_stash2,         0x000C
.equiv  SMO_stash3,         0x0010
.equiv  SMO_flags,          0x0014
.equiv  SMO_RTC_count,      0x0018
.equiv  SMO_seconds,        0x001C
.equiv  SMO_clock,          0x0020
.equiv  SMO_buff_size,      0x0024
.equiv  SMO_buff_head,      0x0028
.equiv  SMO_buff_tail,      0x002C
.equiv  SMO_buff_data,      0x0030

.equiv  SMA_magic,          (SM_BASE + SMO_magic)
.equiv  SMA_stash0,         (SM_BASE + SMO_stash0)
.equiv  SMA_stash1,         (SM_BASE + SMO_stash1)
.equiv  SMA_stash2,         (SM_BASE + SMO_stash2)
.equiv  SMA_stash3,         (SM_BASE + SMO_stash3)
.equiv  SMA_flags,          (SM_BASE + SMO_flags)
.equiv  SMA_RTC_count,      (SM_BASE + SMO_RTC_count)
.equiv  SMA_seconds,        (SM_BASE + SMO_seconds)
.equiv  SMA_clock,          (SM_BASE + SMO_clock)
.equiv  SMA_buff_size,      (SM_BASE + SMO_buff_size)
.equiv  SMA_buff_head,      (SM_BASE + SMO_buff_head)
.equiv  SMA_buff_tail,      (SM_BASE + SMO_buff_tail)
.equiv  SMA_buff_data,      (SM_BASE + SMO_buff_data)

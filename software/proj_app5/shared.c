#include "shared.h"

#define SM_CHECK_OFFSET(member, expected) \
    typedef char sm_offset_check_##member[ \
        (__builtin_offsetof(struct SM_DATA, member) == (expected)) ? 1 : -1]

SM_CHECK_OFFSET(magic, SMO_magic);
SM_CHECK_OFFSET(stash0, SMO_stash0);
SM_CHECK_OFFSET(stash1, SMO_stash1);
SM_CHECK_OFFSET(stash2, SMO_stash2);
SM_CHECK_OFFSET(stash3, SMO_stash3);
SM_CHECK_OFFSET(flags, SMO_flags);
SM_CHECK_OFFSET(RTC_count, SMO_RTC_count);
SM_CHECK_OFFSET(seconds, SMO_seconds);
SM_CHECK_OFFSET(clock, SMO_clock);
SM_CHECK_OFFSET(buff_size, SMO_buff_size);
SM_CHECK_OFFSET(buff_head, SMO_buff_head);
SM_CHECK_OFFSET(buff_tail, SMO_buff_tail);
SM_CHECK_OFFSET(buff_data, SMO_buff_data);
typedef char sm_size_check[(sizeof(struct SM_DATA) == SMO_buff_data + K_SHBUF_SIZEB) ? 1 : -1];

#ifdef VIZARD
struct SM_DATA vizard_shared;
#endif

void SM_INIT(struct SM_DATA *sm)
{
    sm->magic = K_MAGIC_VERSION;
    sm->stash0 = -1u;
    sm->stash1 = -1u;
    sm->stash2 = -1u;
    sm->stash3 = -1u;
    sm->flags = 0;
    sm->seconds = 0;
    sm->clock = 0;
    sm->buff_size = K_SHBUF_SIZEB;
    sm->buff_head = 0;
    sm->buff_tail = 0;
}
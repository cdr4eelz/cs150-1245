ENTRY (_start);

SECTIONS
{
  .text 0x60000000: /* AT(0x00000000) */
  {
    *(.start) *(.text) *(.text.*) *(.gnu.linkonce.t.*)
    . = ALIGN(4); _rodata = .; *(.rodata) *(.rodata.*) *(.gnu.linkonce.r.*)
  }
}

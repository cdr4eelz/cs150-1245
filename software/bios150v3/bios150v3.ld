SECTIONS
{
  . = 0x10000000;
  .data : { *(.data) }
  . = 0x40000000;
  .text : { *(.start); *(.text) *(.rodata.*); }
}

SECTIONS
{
  . = 0x10000000;
  .data : { *(.rodata.*) *(.data) }
  . = 0x20000000;
  .text : { *(.start); *(.text) }
}

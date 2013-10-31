SECTIONS
{
  . = 0x10003210;
  .text : { *(.start); *(.text) *(.rodata.*) *(.dss .data) }
}

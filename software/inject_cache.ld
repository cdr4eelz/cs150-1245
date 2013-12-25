SECTIONS
{
  . = 0x10000000;
  .text : { *(.start); *(.rodata.*) *(.dss .data) *(.text) }
}

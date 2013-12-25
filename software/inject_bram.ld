SECTIONS
{
  . = 0x10001000;
  .text : { *(.start); *(.rodata.*) *(.dss .data) *(.text) }
}

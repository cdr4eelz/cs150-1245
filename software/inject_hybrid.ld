SECTIONS
{
  . = 0x10000000;
  .text : { *(.start); *(.text)  *(.rodata.*) *(.dss .data) }
}

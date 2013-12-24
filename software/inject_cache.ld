SECTIONS
{
  . = 0x10002000;
  .text : { *(.start); *(.text) *(.rodata.*) *(.dss .data) }
}

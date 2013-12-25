SECTIONS
{
  . = 0x50001000;
  .text : { *(.start); *(.rodata.*) *(.dss .data) *(.text) }
}

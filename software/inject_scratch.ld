SECTIONS
{
  . = 0x50000000;
  .data : { *(.dss .data) }
  . = 0x60000000;
  .text : { *(.start); *(.text) *(.rodata.*) }
}

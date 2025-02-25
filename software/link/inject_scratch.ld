SECTIONS
{
  . = 0x60001000;
  .text : { *(.start); *(.rodata.*) *(.dss .data) *(.text) }
}

SECTIONS
{
  . = 0x60000000;
  .text : { *(.start); *(.rodata) *(.text)  *(.rodata.*) *(.dss .data) }
}

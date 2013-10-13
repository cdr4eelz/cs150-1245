SECTIONS
{
  . = 0x10001100;
  .data : { *(.rodata.*) *(.dss .data) }
  . = 0x20002200;
  .text : { *(.start); *(.text) }
}

SECTIONS
{
  . = 0x10000000; /* Don't bother with .data. unless you have initialized globals */
  .data : { *(.dss .data) }
  . = 0x20000000;
  .text : { *(.start); *(.text) *(.rodata.*) } /* INST BRAM */
}

SECTIONS
{
  . = 0x10000000; /* Don't bother with .data. unless you have initialized globals */
  .data : { *(.dss .data) }
  . = 0x40000000;
  .text : { *(.start); *(.text) *(.rodata.*) } /* BIOS BRAM instruction & read-only data */
}

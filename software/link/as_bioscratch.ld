SECTIONS
{
  . = 0x50000000; /* Don't bother with .data. unless you have initialized globals */
  .data : { *(.dss .data) }
  . = 0x40000000;
  .text : { /* Use the .inst. portion as BIOS BRAM */
    *(.start); *(.text);
    . = ALIGN(4); *(.rodata.*)
    . = ALIGN(4);
  }
}

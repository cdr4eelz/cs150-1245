SECTIONS
{
  . = 0x10000000;
  .data : { /* Would have to copy to data manually (or in _start) to initialize */
    *(.dss .data);
  }
  . = 0x40000000;
  .text : { /* Use the .inst. portion as BIOS BRAM */
    *(.start); *(.text);
    . = ALIGN(4); *(.rodata.*);
    . = ALIGN(4);
  }
}

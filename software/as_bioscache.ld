SECTIONS
{
  . = 0x10000000; /* Would have to copy to data manually (or in _start) to initialize */
  .data : { *(.dss .data) }
  . = 0x40000000;
  .text : { *(.start); *(.text) *(.rodata.*) } /* BIOS BRAM instruction & read-only data */
}

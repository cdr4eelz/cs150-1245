SECTIONS
{
  . = 0x10000000;
  .data : { *(.rodata.* .dss .data) } /* Use .data. portion as dmem_blk_ram */
  . = 0x20000000;
  .text : { *(.start); *(.text) } /* Use the .inst. portion as imem_blk_ram */
}

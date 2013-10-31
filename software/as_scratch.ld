SECTIONS
{
  . = 0x50000000;
  .data : { *(.rodata.* .dss .data) } /* Use .data. portion as dmem_blk_ram */
  . = 0x60000000;
  .text : { *(.start); *(.text) } /* Use the .inst. portion as imem_blk_ram */
}

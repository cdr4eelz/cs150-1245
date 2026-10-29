SECTIONS
{
  /* DATA not accessible for ISR block-ram */
  . = 0xC0000000;
  .text : { *(.text) }
  /* KEEP(*(.note.gnu.build-id)) */

  /* Not needed for bare metal; orphaned at VMA 0 they bloat the ELF */
  /DISCARD/ : { *(.MIPS.abiflags) *(.gnu.attributes) }
}

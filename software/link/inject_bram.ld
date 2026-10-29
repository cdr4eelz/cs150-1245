ENTRY(_start)
SECTIONS
{
  . = 0x10001000;
  .text : {
    KEEP(*(.start))
    *(.rodata .rodata.*)
    *(.dss .data .data.* .sdata .sdata.*)
    *(.text.startup .text.startup.*) *(.text) *(.text.*)
    *(.sbss .sbss.* .bss .bss.* COMMON)
  }

  /* Not needed for bare metal; orphaned at VMA 0 they bloat the ELF */
  /DISCARD/ : { *(.MIPS.abiflags) *(.gnu.attributes) }
}

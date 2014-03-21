     PHDRS { bios PT_LOAD ; }
SECTIONS
{
  .text 0x40000000: 
/* AT(0x00000000) */
{ /* Use the .inst. portion as BIOS BRAM */
    *(.start); *(.text);
    . = ALIGN(4); _rodata = .; *(.rodata .rodata.*);
    . = ALIGN(4); _dadata = .; *(.data);
    _gp = ALIGN(16) + 0x7ff0;
    . = ALIGN(4);              *(.got);
    . = ALIGN(4); _sadata = .; *(.sdata);
    . = ALIGN(4); _szdata = .; *(.sbss .sbss.*);
    . = ALIGN(4); _dzdata = .; *(.bss .bss.*);
    *(.reginfo);
    . = ALIGN(4);
  /* . = 0x00003FFC; LONG(1); */
  } : bios

}

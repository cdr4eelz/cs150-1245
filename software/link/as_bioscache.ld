SECTIONS
{
  . = 0x10000000;
  .data : { /* Unused .data. portion; Would have to copy to manually */
    *(.dss .data);
  }

  . = 0x40000000;
  .text : { /* Use the .inst. portion as BIOS BRAM */
    *(.start); *(.text);
    . = ALIGN(4); _rodata = .; *(.rodata .rodata.*);
    . = ALIGN(4); _dadata = .; *(.data);
    _gp = ALIGN(16) + 0x7ff0;
    . = ALIGN(4);              *(.got);
    . = ALIGN(4); _sadata = .; *(.sdata);
    . = ALIGN(4); _szdata = .; *(.sbss .sbss.*);
    . = ALIGN(4); _dzdata = .; *(.bss .bss.*);
    . = ALIGN(4);
  }

  .reginfo : { *(.reginfo) }
}

ENTRY (_start);

SECTIONS
{
  . = 0x10000000;
  .text : {
    *(.start);
    . = ALIGN(4);              *(.text);
    . = ALIGN(4);              *(.init);
    . = ALIGN(4); _rodata = .; *(.rodata .rodata.*);

    . = ALIGN(4); _dadata = .; *(.data);
    . = ALIGN(4); _sadata = .; *(.sdata);
    . = ALIGN(16);    _gp = .;
    . = ALIGN(4); _szdata = .; *(.sbss .sbss.*);
    . = ALIGN(4); _dzdata = .; *(.bss .bss.*);
  }
}

ENTRY (_start);

SECTIONS
{
  . = 0x10000000;
  .text : {
    *(.start) *(.text) *(.text.*) *(.gnu.linkonce.t.*)
    . = ALIGN(4); _rodata = .; *(.rodata) *(.rodata.*) *(.gnu.linkonce.r.*)
    _gp = ALIGN(16) + 0x7ff0;
    . = ALIGN(4);              *(.got) *(.got1) *(.got2) *(.jcr)
    . = ALIGN(4); _sadata = .; *(.sdata) *(.sdata.*) *(.gnu.linkonce.s.*)
    . = ALIGN(4); _szdata = .; *(.sbss) *(.sbss.*) *(.gnu.linkonce.sb.*)
    . = ALIGN(4); _tadata = .; *(.tdata) *(.tdata.*) *(.gnu.linkonce.td.*)
    . = ALIGN(4); _tzdata = .; *(.tbss) *(.tbss.*) *(.gnu.linkonce.tb.*)
    . = ALIGN(4); _dzdata = .; *(.bss) *(.bss.*) *(.gnu.linkonce.b.*)
    . = ALIGN(4);
  }

  .data : {
    . = ALIGN(4); _dadata = .; *(.data)
  }

  .reginfo : { *(.reginfo) }
  .comment : { *(.comment) }
  .pdr     : { *(.pdr)     }
}

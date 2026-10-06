PHDRS {
    bios PT_LOAD ;
    dmem PT_LOAD ;
}

ENTRY (_start_bios);

_sp = 0x1F000000;
_fp = 0x1F000000;

SECTIONS
{

.text 0x40000000:
{
    *(.start) KEEP(*(.text.run_and_time)) *(.text) *(.text.*) *(.gnu.linkonce.t.*)
    . = ALIGN(4); _rodata = .; *(.rodata) *(.rodata.*) *(.gnu.linkonce.r.*)
    _gp = ALIGN(16) + 0x7ff0;
    . = ALIGN(4);              *(.got) *(.got1) *(.got2) *(.jcr)
    . = ALIGN(4); _sadata = .; *(.sdata) *(.sdata.*) *(.gnu.linkonce.s.*)
    . = ALIGN(4); _szdata = .; *(.sbss) *(.sbss.*) *(.gnu.linkonce.sb.*) *(.scommon)
    . = ALIGN(4); _tadata = .; *(.tdata) *(.tdata.*) *(.gnu.linkonce.td.*)
    . = ALIGN(4); _tzdata = .; *(.tbss) *(.tbss.*) *(.gnu.linkonce.tb.*)
    . = ALIGN(4); _dzdata = .; *(.bss) *(.bss.*) *(.gnu.linkonce.b.*) *(COMMON)
    . = ALIGN(4);
} : bios

.data 0x50000000: {
    . = ALIGN(4); _dadata = .; *(.data)
} : dmem

/DISCARD/ : { *(.reginfo) }
/DISCARD/ : { *(.comment) }
/DISCARD/ : { *(.pdr) }

}
PHDRS {
    imem PT_LOAD ;
    dmem PT_LOAD ;
}

ENTRY (_start);

SECTIONS
{
    .text 0x60000000: /* AT(0x00000000) */
    { /* The .inst. portion is imem scratch BRAM. */
        _text = .;
        . = ALIGN(4);   _stimem = .;    *(.start)
        . = ALIGN(4);   _strttx = .;    *(.text.startup)
        . = ALIGN(4);   _texttx = .;    *(.text)
        . = ALIGN(4);                       *(.text.*)
        . = ALIGN(4);   _gnulot = .;    *(.gnu.linkonce.t.*)
        /* Stuff DATA into TEXT since later dump focuses on that. */
        . = ALIGN(16);  /* Big alignment at start of data... */
        _data = .;
        _gp = .;
                        _rodata = .;    *(.rodata)
        . = ALIGN(4);                       *(.rodata.*)
        . = ALIGN(4);                       *(.gnu.linkonce.r.*)
        . = ALIGN(4);   _dadata = .;    *(.data)
        . = ALIGN(4);   _daddss = .;    *(.dss)
        . = ALIGN(4);   _gottab = .;    *(.got) *(.got1) *(.got2) *(.jcr)
        . = ALIGN(4);   _sadata = .;    *(.sdata) *(.sdata.*) *(.gnu.linkonce.s.*)
        . = ALIGN(4);   _szdata = .;    *(.sbss) *(.sbss.*) *(.gnu.linkonce.sb.*) *(.scommon)
        . = ALIGN(4);   _tadata = .;    *(.tdata) *(.tdata.*) *(.gnu.linkonce.td.*)
        . = ALIGN(4);   _tzdata = .;    *(.tbss) *(.tbss.*) *(.gnu.linkonce.tb.*)
        . = ALIGN(4);   _dzdata = .;    *(.bss) *(.bss.*) *(.gnu.linkonce.b.*)
        . = ALIGN(4);   _common = .;    *(COMMON)
    /*  . = 0x00003FFC; LONG(1); Something broken about this! */
        _end_text = .;
    } : imem

    .data 0x50000000: /* The .data. portion empty but used... */
    { /* ...for stack pointer and friends used in .s _start code. */
        _dyn_data = .;
        _sp = 0x0004000; _fp = _sp;
/*      . = 0x00003FFC; LONG(1); THIS would make data binary output 0x4000 big! */
        _end_data = .;
    } : dmem

    /* Stuff that gets in the way */
    /DISCARD/ : { *(.reginfo) }
    /DISCARD/ : { *(.comment) }
    /DISCARD/ : { *(.pdr) }

}

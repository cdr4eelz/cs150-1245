SECTIONS
{
    . = 0x40000000;
    .text : {
        * (.start);
        * (.text);
        * (.rodata.*);
    }
    . = 0x30003000;
    .data : {
        * (.data .bss);
    }
}


SECTIONS
{
    . = 0x10000000;
    .data : {
        * (.data);
        * (.rodata.*);
    }
    . = 0x20000000;
    .text : {
        * (.start);
        * (.text);
    }
}

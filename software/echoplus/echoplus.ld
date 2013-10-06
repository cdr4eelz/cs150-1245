SECTIONS
{
    . = 0x00000000;
    .data : {
        * (.data);
    }
    . = 0x00000000;
    .text : {
        * (.start);
        * (.text);
        * (.rodata.*);
    }
}

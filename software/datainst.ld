/* Several (redundant) ways to make linker output appropriate,
   yet place things in convenient contiguous memory for the
   data2mem tool to be happier and the bss file to be cleaner.
   Despite all this, I ended up just having the makefile slap
   the two separate data/inst segments together manually!
   (So nothing special is actually needed like demonstrated here!)
*/

MEMORY 
{
  VDATA (r)   : ORIGIN = 0x10000000, LENGTH = 16K
  VINST (!rx) : ORIGIN = 0x20000000, LENGTH = 16K
  VBOTH (rx)  : ORIGIN = 0x00000000, LENGTH = 32K
}

PHDRS {
  PINST PT_LOAD AT (0x00000000) ;
  PDATA PT_LOAD AT (0x00004000) ;
}

SECTIONS
{
  . = 0x10000000;
  .data : AT ( 0x00000000 ) { *(.rodata.*) *(.data) } >VDATA :PDATA
  . = 0x20000000;
  .inst : AT ( 0x00004000 ) { *(.start)    *(.text) } >VINST :PINST
}

/****************************************************************/
/*             Linker command file for DSK5D.ASM                */
/****************************************************************/

-e reset
dsk5d.obj                       /* Specify object file to link  */
-o dsk5d.out                    /* Specify output file name     */
-m dsk5d.map                    /* Create memory map file       */
MEMORY
{
    PAGE 0:     PROG:           origin =   00800H,  length = 200h
    PAGE 1:     BLOCKB2:        origin =   060h,    length = 020h
                DATA:           origin =   0a00h,   length = 3dfch
}
SECTIONS
{
        .text :  { 
                   *  (.text)
                      .=200h; } = 08b00h > PROG    PAGE 0

        .bss  :  { } > BLOCKB2 PAGE 1
        .data :  {
                   * (.data)
                     .=3dfch; } = 081h > DATA    PAGE 1
}
                         

/* Linker command file for DSK test code               */
-o selftest.out             /* Specify output file     */
-m selftest.map             /* Generate map file       */

selftest.obj                /* Object file to link     */

MEMORY
{
      PAGE 0 : PROG:   origin = 00a00h, length = 0400h
      PAGE 0 : VECT:   origin = 00802h, length = 003eh
      PAGE 1 : B2  :   origin = 01000h, length = 0020h
               DAT :   origin = 01020h, length = 0400h
}

SECTIONS
{
	.text :   {} > PROG   PAGE 0
        vectors:  {} > VECT   PAGE 0
        .data :   {} > DAT    PAGE 1
        BLOCK2:   {} > B2     PAGE 1
}


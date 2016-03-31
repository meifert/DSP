 ;-----------------------------------------------------------;
 ; This is the source code for the DSK spectrum analyzer.    ;
 ; Assemble using the DSK5A assembler and execute the DSK    ;
 ; loader to load and run the application on your PC.        ;
 ;-----------------------------------------------------------;
             .mmregs
FFT_S        .set     1024
FFT_S-1      .set     1023
FFT_S/2      .set     512
(FFT_S/2)-1  .set     511

 ;-----------------------------------------------------------;
TA       .set     6               ;       Auxin -----+  +----- Loopback
RA       .set     6               ;       Synch --+  |  |  +-- BP Filter
TAp      .set     1               ;               |  |  |  |
RAp      .set     1               ;+------------+------------+
TB       .set     18              ;|00 00 G1 G0 | SY AX LB BP|
RB       .set     18              ;+------------+------------+
AIC_CMD  .set     080h            ;       GAIN
         .ds      0f00h
TEMP     .word    0               ;location of TEMPorary storage
ACCU_lo  .word    0               ;
ACCU_hi  .word    0               ;
STAT1    .word    0               ;STAT1 storage
;----------------------------------------------------------------
        .ps     080ah
        B       RINT         ;0A; Serial port receive interrupt RINT
        B       XINT         ;0C; Serial port transmit interrupt XINT
******************************************************************
* TMS32C05X INITIALIZATION					 *
* This routine initializes the C5x registers, internal RAM and	 *
* external RAM from xxxx to FFFF				 *
******************************************************************
         .ps     0a00h
         .entry
start    setc    INTM            ; Disable interrupts
         ldp     #0              ; Set data page pointer
         splk    #830h,PMST      ; 9K on-chip RAM as Data, No ROM
         lacl    #0              ; Set Wait State Control Regester
         samm    CWSR            ; for 0 waits in pgm & data memory
         samm    PDWSR           ;
*
* initalize and reset serial port
*
         splk    #20h,TCR
         splk    #1,PRD
         mar     *,AR0
         lacl    #08h             ; set FSM bit for FSX/FSR per frame
         samm    spc             ; Configure for 16 bit mode with
         lacl    #0C8h            ; external CLKX, reset tx and rx
         samm    spc
         lamm    drr             ; clear first int
         lacc    #0080h
         sach    dxr             ; clear first int
         sacl    GREG            ; Pulse AIC reset by setting it low
         lar     AR0,#0FFFFFh
         rpt     #10000          ; and taking it high after 1000 cycles
         lacc    *,0,AR0         ; (.5ms at 50ns)
         sach    GREG
         setc    SXM
         setc    OVM
         ;---------------------------------------------------------------
         lar     AR7,#0            ;Buffer initialy filled
         call    AIC_SET          ; DO NOT CHANGE DP WITHOUT RESTORING IT!
         lacl    #010h            ; RINT
         samm    IMR              ;
         ldp     #TEMP
FFT:     lar     AR0,#FFT_S/2      ;
         mar     *,AR0            ;start FFT with AR0=FFTSize
new_stg: lar     AR1,#_D_base      ;AR1 is the TOP BFLY address
         lar     AR2,#_D_base      ;AR2 is the BOT BFLY address
         lar     AR3,#_T_base+1    ;AR3 is the TWiddle pointer
         lar     AR4,#FFT_S/2      ;AR4 counts DFT blocks
         b       n_DFT2,*,AR1       ;
DFT:     mar     *BR0+,AR5        ;complete circular buffer for TW's
         lar     AR5,#1           ;set up DFT loop with *BR0+/BANZ
         mar     *BR0+,AR1        ;using 1 cuts *BR0+ loop in half!
	 ;----------------------------------------
         ; AR1=Top AR2=Bottom AR3=Twiddle
         ;----------------------------------------
BFLY:    lacc    * ,14,AR2        ;(imag1+imag2)/4
	 add     * ,14,AR1        ;
         sach    *+,1 ,AR2        ;store TOP imag
         sub     * ,15            ;(imag1-imag2)/2
         sach    *+,1 ,AR1        ;store BOT imag
         lacc    * ,14,AR2        ;(real1+real2)/4
         add     * ,14,AR1        ;
         sach    *+,1 ,AR2        ;store TOP real
         sub     * ,15            ;(real1-real2)/2
         sach    * ,1,AR5         ;store BOT real
         banz    OK,*BR0+,AR3     ;If at DFT end quit early
         ;------------------------
         mar     *+,AR2           ;clean up TW base (xxx0000+1)
         mar     *+               ;modify BOTom DATA pointer
         mar     *0+              ;
         mar     *0+,AR1          ;
n_DFT2:  mar     *0+              ;modify the TOP pointer
         mar     *0+,AR4          ;
         banz    DFT,*0-,AR3      ;dec DFT block count AR4 by OFFset
         mar     *,AR0            ;
         mar     *BR0+            ;
         banz    new_stg,*        ;if OFFset was 1, now cleared
	 b       endFFT           ;
         ;-------------------------
OK       lt      *-,AR2           ;TREG=TWR     *NOTE* Twiddles are Q15
         mpy     *-               ;PREG=REAL*TWR
         ltp     *+,AR3           ;TREG=IMAG     ACCU=REAL*TWR
         mpy     *                ;PREG=IMAG*TWI                AR2=R AR3=I
         lts     *+,AR2           ;TREG=TWI      ACCU=REAL*TWR-IMAG*TWI
         mpy     *                ;PREG=REAL*TWI
         sach    *-,1             ;
         ltp     * ,AR3           ;TREG=IMAG     ACCU=REAL*TWI
         mpy     *BR0+,AR2        ;PREG=IMAG*TWR
         apac                     ;              ACCU=IMAG*TWR+REAL*TWI
         sach    *+,1             ;
         b       BFLY,*+,AR1      ;
	 ;------------------------------------------------------------
endFFT:  mar     *,AR2            ;Transform REAL & IMAG to log magnitude
         lar     AR2,#_D_base     ;AR3=FFT data pointer
         lar     AR3,#FFT_S-1     ;AR5=FFT loop counter
more_MAG sqra    *+               ;PREG=IMAG^2
         ltp     *                ;TREG=REAL    ACCU=IMAG^2
         mpy     *,AR1            ;PREG=REAL^2
         apac                     ;ACCU=REAL^2+IMAG^2
         lar     AR1,#31          ;NORMalize the accumulator
         rpt     #30               ;use for other types of conversion
         norm    *-               ;
         nop
         nop
      ;; bnz     sig_NZ,*,AR2     ;if zero must return 0
         mar     *,AR2
         bcnd    sig_NZ,NEQ       ;if zero must return 0
         lar     AR1,#0           ;
sig_NZ   sach    *,2              ;clear explicit 1.0 from mantissa
         lacl    *                ;load into accumulator and
         and     #0FF80h       ;; clear LSB's for AIC
         sar     AR1,*            ;append the exponent (AR5)
         add     *,16             ;
         xor     #020h,15          ;change to 2's compliment
         rpt     #3                ;jam result to top of ACCU
         sfl                      ;
         sach    *+,7,AR3         ;
	 banz    more_MAG,*-,AR2  ;keep going until all done
         ;--------------------------------------------------------
BITREV:  lar     AR0,#FFT_S        ;Now perform Output bit reversal
         lar     AR1,#_D_base      ;by moving the magnitude, which
         lar     AR2,#_D_base+1    ;is in the REAL slots, into the
         lar     AR3,#FFT_S-1      ;IMAG slots of the FFT data array
more_BR: lacc    *+               ;load the magnitude
         mar     *+,AR1           ;
	 sacl    *BR0+,0,AR3      ;move it to an open IMAG slot
         banz    more_BR,*-,AR2   ;more data to move?
         ;--------------------------------------------------------
MOVE_IO: mar     *,AR7            ;wait until buffer is full
         banz    MOVE_IO,*,AR2    ;(AR7 is decremented by ISR)
         lar     AR3,#_D_base      ;AR3=FFT data pointer
         lar     AR4,#_B_base      ;AR4=BUFF data pointer
         lar     AR5,#(FFT_S/2)-1  ;AR5=FFT loop counter
         lar     AR6,#_B_base      ;AR6=ISR BUFF data pointer
         lacc    #07ffCh           ;send synch when BUFF is full
         samm    DXR              ;
         rpt     #00800h           ;
         nop                      ;
         lar     AR2,#_T_base+1    ;AR2=WIN data pointer
         lar     AR7,#FFT_S-1      ;AR7=ISR BUFF loop counter
         ;-------------------------
         lar     AR0,#FFT_S/2      ; Use twiddle table for raised
more_IO: lacc    #04000h,1         ; cosine window
         add     *BR0+,0,AR4      ;
         sfr                      ;
         sacl    TEMP             ;
         lt      TEMP             ;TREG=WIN
         mpy     * ,AR3           ;PREG=IN*WIN
         lacl    * ,AR4           ;ACCU=magnitude (put in Buffer)
	 sacl    *+,0,AR3         ;
         sach    *+               ;IMAG=0
         pac                      ;
         sach    *+,1,AR5         ;REAL=IN (windowed buffer)
         clrc    INTM             ;1st BUFF posn clr so enable INT's
         banz    more_IO,*-,AR2   ;
         lar     AR5,#(FFT_S/2)-1  ;AR5=FFT loop counter
more_IO2 lacc    #04000h,1         ; cosine window
	 add     *BR0-,0,AR4      ;
         sfr                      ;
         sacl    TEMP             ;
         lt      TEMP             ;TREG=IN
         mpy     * ,AR3           ;PREG=IN*WIN
         lacl    * ,AR4           ;ACCU=magnitude (put in Buffer)
         sacl    *+,0,AR3         ;
	 sach    *+               ;IMAG=0
         pac                      ;
         sach    *+,1,AR5         ;REAL=IN (windowed buffer)
         banz    more_IO2,*-,AR2  ;
	 b       FFT              ;
;-----------------------------------------------------------------
XINT     rete
;-----------------------------------------------------------------
RINT:                             ;Recover the ARP from ARB (MON26 only)
         mar     *,AR7            ;AR6 = current buffer position
         banz    more_buf,*-,AR6  ;if buffer is full RET w/o EINT
         lar     AR7,#0            ;
         reti                     ;
more_buf;
         lacc    *                ;
         or      #1
         samm    DXR              ;
         lamm    DRR              ;
         sacl    *+               ;store data from DRR
         rete                     ;
******************************************************************
AIC_SET: lacl   #020h
         samm   IMR               ;XMIT interrupt
         lacc   #AIC_CMD,2         ;
         add    #03h               ;
         call   AIC_2nd           ;
         ;------------------------
         lacc   #TB,9              ;
         add    #RB,2              ;
         add    #02h               ;
         call   AIC_2nd           ;
         ;------------------------
         lacc   #TA,9              ;
         add    #RA,2              ;
         call   AIC_2nd           ;
         ;------------------------
         ret                      ;
;----------------------------------------------------------------
AIC_2nd:                           ;
         sach   DXR               ;
         clrc   INTM            ;;;
         idle                     ;
         add    #6,15             ;0000 0000 0000 0011 XXXX XXXX XXXX XXXX b
         sach   DXR               ;
;        clrc   INTM            ;;;Unlike C2x, IDLE does NOT eint's!
         idle                     ;ACCU_hi requests 2nd XMIT
         samm   DXR               ;
;        clrc   INTM            ;;;
         idle                     ;ACCU_lo sets up registers
         lacl   #0                ;
         samm   DXR               ;make sure the word got sent
;        clrc   INTM            ;;;
         idle                     ;
         setc   INTM
         ret                      ;
;-----------------------------------------------------------------------
         .ds 01000h
         .listoff
         .include "dsk_twid.asm"  ;NOTE: Internal RAM block B2 is used
         .liston

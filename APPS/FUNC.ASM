****************************************************************
*   (C) COPYRIGHT TEXAS INSTRUMENTS, INC. 1992		       *
****************************************************************
*  MODULE NAME: DSK Test                                       *
*							       *
*  DESCRIPTION: This routine initializes the TMS320C50 and     *
*               TLC32040 on the C5x DSK.  Generating a 0.2     *
*               normalized frequency sinewave or random        *
*               noise.                                         *
*							       *
*  Random noise algorithm:                                     *
*                     a b c d  x x x x  x x x x  x x x x       *
*                     \ / \ /                                  *
*                   xor|   |xor                                *
*                       \ /                                    *
*                    xor +---------------------------------+   *
*                                                          |   *
*                        x x x x   x x x x  x x x x  x x x s   *
*                                                              *
****************************************************************
         .mmregs
*
;---------------------------------------------------------------;
; Bit definition of the control register in the AIC             ;
;---------------------------------------------------------------;

      ;+-------------------------+
      ;|LP xx G1 G0 | SY AX LB BP|              G1  G0  gain
      ;+------------+------------+             ---------------
      ; |     GAIN    |  |  |  +-- BP Filter    0   0    4
      ; |     Synch --+  |  +----- Loopback     1   1    4
      ; |     Auxin -----+                      0   1    2
      ; + (sinx)/x filter                       1   0    1


         .ds     0f00h           ;
TA       .word    24              ; Fcut = 8 KHz
RA       .word    24              ; Fcut = 8 KHz
TAp      .word    31              ;
RAp      .word    31              ;
TB       .word    18              ; Fs = 2*Fcut
RB       .word    18              ; Fs = 2*Fcut
AIC_CTR  .word    9h

ACC_lo   .word    0               ;
ACC_hi   .word    0               ;
STAT0    .word    0               ; STAT0 storage
STAT1    .word    0               ; STAT1 storage
TEMP     .word    0               ; location of TEMPorary storage
TEMP1    .word    0               ;
SIN_SW   .word    00000h          ; 0 -> random noise
                                  ; 1 -> sinewave
y        .word    0463ch          ; sin(fn*pi), where fn is normalized
y1       .word    00000h          ; frequency
seed     .word    07e6dh          ; seed for random noise generator

         .ds      01000h
coeff    .word    0678dh          ; cos(fn*pi)


****************************************************************
*   Set up the ISR vector                                      *
****************************************************************
         .ps     080ah
rint:    B       RECEIVE       ;0A; Serial prot receive interrupt RINT.
xint:    B       TRANSMIT      ;0C; Serial port transmit interrupt XINT.

*
******************************************************************
* TMS32C05X INITIALIZATION                                       *
*								 *
******************************************************************
         .ps 0a00h
         .entry
START:   SETC    INTM             ; Disable interrupts
         LDP     #0               ; Set data page pointer
         OPL     #0834h,PMST
         LACC    #0
         SAMM    CWSR             ; Set software wait state to 0
         SAMM    PDWSR            ;

* Reset AIC by writing to PA2 (address >52) to DSK

         SPLK    #022h,IMR        ; Using XINT syn TX & RX
         CALL    AICINIT          ; initialize AIC and enable interrupts
*
*******************************************************************
* This routine enables serial port rx interrupts & configures	  *
* TLC32040 for the frame sync. When RINT is triggered, read a     *
* dummy data word from the AIC then generate a sine wave to       *
* send out.                                                       *
*******************************************************************
;
         CLRC    OVM              ; OVM = 0
         SPM     0                ; PM = 0
         SPLK    #012h,IMR
         CLRC    INTM             ; enable

;
WAIT     NOP                      ; wait for a transmit or receive
         NOP
         NOP
         B       WAIT
;------- end of main program ----------;

;
; RECIEVER INTERRUPT SERVICE ROUTINE
;
RECEIVE:
         LDP     #TEMP
         LAMM    DRR              ; read data from DRR
         LDP     #SIN_SW
         BIT     SIN_SW,15
         BCND    SINEWAVE,TC
       ;------------------------------------
       ; random noise generator
       ;------------------------------------
         LACC    seed,1           ;
         XOR     seed             ;
         SACL    TEMP,2           ;
         XOR     TEMP             ;
         AND     #8000h           ;
         ADD     seed,16          ;
         SACH    seed,1           ; Reduce the output by at least 1/8
         LACC    seed,11          ; to prevent the overflow
         AND     #0FFFCh,15
         RPT     #14
         SFR
         SAMM    DXR
         RETE                      ; program
       ;------------------------------------
       ; sinewave generator
       ;------------------------------------
SINEWAVE:
         MPY     #0               ; clear P register
         LACC    y1,15            ; y1 ==> ACC shift left 15 bit
         NEG                      ; -ACC ==> ACC
         MACD    coeff,y          ; coeff * y
         APAC                     ;
         APAC                     ; 2*coeff*y - y1
         SACH    y,1              ; Reduce the output by at least 1/8
         LACC    y,15             ; to prevent the overflow
         AND     #0FFFCh,15       ; bit 0 & 1 has to be 0 for AIC
         RPT     #14
         SFR
         SAMM    DXR              ; to tell its data, not command
         RETE                     ; program
*
;
; TRANSMIT INTERRUPT SERVICE ROUTINE
;
TRANSMIT:
         RETE

*
******************************************************************
*  DESCRIPTION: This routine initializes the TLC320C40 for       *
*		a 8Khz sample rate with a gain setting of 1	 *
******************************************************************
* aic initialization data
*
AICINIT: SPLK    #20h,TCR           ; To generate 10 MHz from Tout
         SPLK    #01h,PRD           ; for AIC master clock
         MAR     *,AR0
         LACC    #0008h             ; Non continuous mode
         SACL    SPC                ; FSX as input
         LACC    #00c8h             ; 16 bit words
         SACL    SPC
         LACC    #080h            ; Pulse AIC reset by setting it low
         SACH    DXR
         SACL    GREG
         LAR     AR0,#0FFFFh
         RPT     #10000           ; and taking it high after 10000 cycles
         LACC    *,0,AR0          ; (.5ms at 50ns)
         SACH    GREG
         ;------------------------
         LDP     #TA              ;
         SETC    SXM              ;
         LACC    TA,9             ; Initialized TA and RA register
         ADD     RA,2             ;
         CALL    AIC_2ND          ;
         ;------------------------
         LDP     #TB
         LACC    TB,9             ; Initialized TB and RB register
         ADD     RB,2             ;
         ADD     #02h             ;
         CALL    AIC_2ND          ;
         ;------------------------
         LDP     #AIC_CTR
         LACC    AIC_CTR,2        ; Initialized control register
         ADD     #03h             ;
         CALL    AIC_2ND          ;
         RET                      ;

AIC_2ND:
         LDP     #0
         SACH    DXR              ;
         CLRC    INTM
         IDLE
         ADD     #6h,15           ; 0000 0000 0000 0011 XXXX XXXX XXXX XXXX b
         SACH    DXR              ;
         IDLE
         SACL    DXR              ;
         IDLE
         LACL    #0               ;
         SACL    DXR              ; make sure the word got sent
         IDLE
         SETC    INTM
         RET                      ;
	.end


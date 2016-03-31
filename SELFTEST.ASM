****************************************************************
*   (C) COPYRIGHT TEXAS INSTRUMENTS, INC. 1993                 *
****************************************************************
*  MODULE NAME: DSK selftest                                   *
*							       *
*  DESCRIPTION: This routine initializes the TMS320C50 and     *
*               TLC32040 on the C5x DSK.  Loopback the         *
*               signal on the AIC to test. Use the DSK loader  *
*               to perform the test.                           *
*							       *
*  HIST: 12-20-93 first copy by modifying the aic1.asm file    *
*        01-11-94 rewrite the document for production.         *
*                                                              *
*                                                              *
****************************************************************
         .title  "DSK TEST ROUTINE"
         .mmregs
*

;----------------------------------------------------------------
         .global  START, AICINIT, AIC_2ND, TRANSMIT, RECEIVE, xbuf
         .global  reset, int0, int1, int2, tint, rint, xint, trap, rbuf
;-------------------------------------------------------------------------


;---------------------------------------------------------------;
; The tables of TA, TA', and TB to set up the AIC sampling rate ;
; and cutoff frequency. ( Same set up for RA, RA', and RB)      ;
;---------------------------------------------------------------;

;------------------------------------------------------------;
; Fcut(KHz) | 16.0 | 10.3 |  9.0 |  8.0 |  6.8 |  5.0 |  4.6 ;
;------------------------------------------------------------;
;    TA     |  9   |  14  |  16  |  18  |  21  |  24  |  31  ;
;------------------------------------------------------------;

;-----------------------------------;
;  Fs/Fcut  |  6  |  4  |  3  |  2  ;
;-----------------------------------;
;    TB     |  6  |  9  | 12  | 18  ;
;-----------------------------------;

; Note: 1. Master clock = 10.368 MHz
;       2. The TA'(TB') was designed for the modem user, which will
;          not used in this application.
;       3. The multiplication of TB and (Fs/Fcut) always equals 36, and the
;          maximum value for TB is 63. Therefore, the Fs/Fcut may go
;          smaller than 2. If so, this will cause aliasing problem.
;       4. The following setup is Fcut = 8.0 KHz and Fs = 16 KHz

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


         .sect   "BLOCK2"        ;
TA       .word    24              ; Fcut = 8 KHz   Value of TA register
RA       .word    24              ; Fcut = 8 KHz   Value of RA register
TAp      .word    31              ;
RAp      .word    31              ;
TB       .word    18              ; Fs = 2*Fcut    Value of TB register
RB       .word    18              ; Fs = 2*Fcut    Value of RB register
AIC_CTR  .word    1ah

ACC_lo   .word    0               ;
ACC_hi   .word    0               ;
STAT0    .word    0               ; STAT0 storage
STAT1    .word    0               ; STAT1 storage
;TEMP     .word    0                 location of TEMPorary storage
TEMP1    .word    0               ;
SIN_SW   .word    00001h          ; 0 -> random noise
                                  ; 1 -> sinewave
y        .word    0463ch          ; sin(fn*pi), where fn is normalized
y1       .word    00000h          ; frequency
seed     .word    07e6dh          ; seed for random noise generator

         .data
coeff    .word    0678dh          ; cos(fn*pi)
TEMP     .word   0h
xbuf     .word   0b000h
rbuf     .space  32*16

****************************************************************
*   Set up the ISR vector                                      *
****************************************************************
        .sect    "vectors"
         .space  6 * 16        ;02;
         .space  2 * 16        ;08;
rint:    B       RECEIVE       ;0A; Serial prot receive interrupt RINT.
xint:    B       TRANSMIT      ;0C; Serial port transmit interrupt XINT.
         .space  22 * 16       ;0E;
         ;-------------------------------------------------------

*
******************************************************************
* TMS32C05X INITIALIZATION                                       *
*								 *
******************************************************************
	 .text
START:   CLRC    INTM             ; Disable interrupts
         LDP     #0               ; Set data page pointer
         OPL     #0834h,PMST
         LACC    #0
         SAMM    CWSR
         SAMM    PDWSR

        lacc    #rbuf
        samm    ar3
        samm    cbsr2
        add     #1fh
        samm    cber2
        splk    #0bah,cbcr
        lar     ar1,#TEMP
* Reset AIC by writing to PA2 (address >52) to DSK

         OPL     #030h,IMR        ; Using RINT syn TX & RX
         CALL    AICINIT          ; initialize AIC and enable interrupts
         SETC    INTM             ; enable interrupt
*
*******************************************************************
* This routine enables the serial port rx interrupts & configures *
* TLC32040 for the frame sync. When RINT is generated read a      *
* dummy data word from the AIC then generate a sine wave to       *
* send out.                                                       *
*******************************************************************
;
         CLRC    OVM              ; OVM = 0
         SPM     0                ; PM = 0
         LDP     #20h
         EINT                     ; enable

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
        MAR     *,AR3
        LAMM    DRR             ; read new sample
        SACL    *+
        LACC    xbuf
        SAMM    dxr             ; send it out
        RETE

TRANSMIT:
         RETE

*
******************************************************************
*  DESCRIPTION: This routine initializes the TLC320C40 for       *
*		a 8Khz sample rate with a gain setting of 1	 *
******************************************************************
*
*
AICINIT: SPLK    #420h,TCR
         SPLK    #01h,PRD
         MAR     *,AR0
         LACC    #1000000000001000b ; Non continuous mode
         SACL    SPC                ; FSX as input
         LACC    #1000000011001000b ; 16 bit words
         SACL    SPC
         LACC    #080h            ; Pulse AIC reset by setting it low
         SACH    DXR
         SACL    GREG
         LAR     AR0,#0FFFFh
         RPT     #10000             ; and taking it high after 10000 cycles
         LACC    *,0,AR0            ; (.5ms at 50ns)
         ;------------------------
         LDP     #TA              ;
         SSXM                     ;
         LAC     TA,9             ; Initialized TA and RA register
         ADD     RA,2             ;
         CALL    AIC_2ND          ;
         ;------------------------
         LDP     #TB
         LAC     TB,9             ; Initialized TB and RB register
         ADD     RB,2             ;
         ADDK    02h              ;
         CALL    AIC_2ND          ;
         ;------------------------
         LDP     #AIC_CTR
         LAC     AIC_CTR,2        ; Initialized control register
         ADDK    03h              ;
         CALL    AIC_2ND          ;
         RET                      ;
         ;-------------------------------------------------------------
AIC_2ND:
         LDP     #0
         IDLE
         SACH    DXR              ;
         ADLK    6,15             ; 0000 0000 0000 0011 XXXX XXXX XXXX XXXX b
         IDLE
         SACH    DXR              ;
         IDLE
         SACL    DXR              ;
         ZAC                      ;
         IDLE
         SACL    DXR              ; make sure the word got sent
         RET                      ;

	.end



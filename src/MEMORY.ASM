;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      MEMORY.ASM                      |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Memory Emulation                |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC

Emulate         segment common
                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

WriteNA         MACRO
                DoNext
                ENDM

;-------------------------------------------------------------------------------

WriteRAM        MACRO
                mov     [di],bh
                DoNext
                ENDM

;-------------------------------------------------------------------------------

WriteROM        MACRO
                DoNext
                ENDM

;-------------------------------------------------------------------------------

WriteDRAM       MACRO
                Local   WriteOnly,DoNotWrite
;;------------------------------------------------------\
        IFNDEF  DRAM_ModefyAdr                          ;;
DRAM_ModefyAdr  label   word                            ;;
DRAM_ReadWrite  =       3D88h                           ;; mov [di],bh
DRAM_WriteOnly  =       0EBh + (WriteOnly -$-2)*100h    ;; jmp short WriteOnly
DRAM_DoNotWrite =       0EBh + (DoNotWrite-$-2)*100h    ;; jmp short DoNotWrite
        ENDIF                                           ;;
                dw      DRAM_WriteOnly                  ;;
;;------------------------------------------------------/
;;ReadWrite:    mov     [di],bh
                DoNext
WriteOnly:      mov     SS:DRAM[di-0D000h],bh
DoNotWrite:     DoNext
                ENDM

;-------------------------------------------------------------------------------

WriteTEXT       MACRO   Page
                Local   TextMode,GrMode,MixedGrMode,MixedHgrMode,L10
VideoPage       =       Page/4                  ;; 1 or 2
;;------------------------------------------------------\
        IFNDEF  TEXT_ModefyAdr                          ;;
TEXT_ModefyAdr  label   word                            ;;
TEXT_TextMode   =       0EBh + (TextMode    -$-2)*100h  ;; jmp short TextMode
TEXT_GrMode     =       0EBh + (GrMode      -$-2)*100h  ;; jmp short GrMode
TEXT_MixedGrMode=       0EBh + (MixedGrMode -$-2)*100h  ;; jmp short MixedGrMode
TEXT_MixedHgrMode=      0EBh + (MixedHgrMode-$-2)*100h  ;; jmp short MixedHgrMode
TEXT_NA         =       3D88h                           ;; mov [di],bh
        ENDIF                                           ;;
        IF      VideoPage EQ 1                          ;;
                dw      TEXT_GrMode                     ;;
        ELSE                                            ;;
                dw      TEXT_NA                         ;;
        ENDIF                                           ;;
;;------------------------------------------------------/
;;              mov     [di],bh
                DoNext
TextMode:       mov     [di],bh
                lahf
                shl     di,1
                mov     di,SS:TEXTadr[di-2*VideoPage*400h]
L10:            xchg    bl,bh
                shl     bx,1
                sahf
                mov     ax,SS:TEXTchars[bx]
                stosw
                mov     bl,0
                DoNext
GrMode:         mov     [di],bh
                lahf
                shl     di,1
                mov     di,SS:TEXTadr[di-2*VideoPage*400h]
                inc     di
                sahf
                mov     al,bh
                mov     bx,offset GRcolors
                xlat    SS:[bx]
                stosb
                mov     bl,0
                DoNext
MixedGrMode:    mov     [di],bh
                lahf
                shl     di,1
                mov     di,SS:TEXTadr[di-2*VideoPage*400h]
                cmp     di,20*40*2
                jae     L10
                inc     di
                sahf
                mov     al,bh
                mov     bx,offset GRcolors
                xlat    SS:[bx]
                stosb
                mov     bl,0
                DoNext
MixedHgrMode:   mov     [di],bh
        IFE     VideoPage - 1
                jmp     MixedHgrMode1
        ELSE
                jmp     MixedHgrMode2
        ENDIF
                ENDM

;-------------------------------------------------------------------------------

WriteHGR        MACRO   Page
                Local   HgrMode,MixedMode,L10,L20
VideoPage       =       Page/20h             	;; 1 or 2
VideoPageAdr    =       (VideoPage-1)*4000h     ;; 0 or 4000h
;;------------------------------------------------------\
        IFNDEF  HGR_ModefyAdr                           ;;
HGR_ModefyAdr   label   word                            ;;
HGR_HgrMode     =       0EBh + (HgrMode  -$-2)*100h     ;; jmp short HgrMode
HGR_MixedMode   =       0EBh + (MixedMode-$-2)*100h     ;; jmp short MixedMode
HGR_NA          =       3D88h                           ;; mov [di],bh
        ENDIF                                           ;;
                dw      HGR_NA                          ;;
;;------------------------------------------------------/
;;              mov     [di],bh
                jmp     near ptr L20
;               DoNext
L10:            sahf
                mov     [di],bh
                jmp     near ptr L20
;               DoNext
MixedMode:      mov     ax,di
                lahf
                shl     al,1
                cmp     al,2*40*2
                jae     L10
                sahf
HgrMode:        mov     [di],bh
                Save    cx
                mov     ax,di
                lahf
                shl     di,1
                mov     di,SS:HGRadr[di-2*VideoPage*2000h]
                mov     bl,bh
                mov     bh,al
                and     bh,00000011b
		shl     bx,1
                mov     cx,SS:HGRcolors[bx]
                mov     bx,SS:HGRmasks [bx]
                mov     al,ES:[VideoPageAdr][di]
                and     al,bh
                xor     al,ch
                and     ch,bh
                xor     al,ch
                mov     ES:[VideoPageAdr][di],al
                shl     bh,2
		not     bh
                and     bx,ES:[VideoPageAdr][di+1]
                or      cx,bx
                mov     ES:[VideoPageAdr][di+1],cx
                sahf
                Restore cx
                mov     bl,0
L20:            DoNext
                ENDM

;-------------------------------------------------------------------------------

WriteIO         MACRO
                mov     ax,di
                lahf
                and     di,00FFh
                shl     di,1                    ;; AH - flags NZ, AL - Address
                jmp     SS:C0XXWrite[di]        ;; BH - save value
                ENDM

;===============================================================================

MemPage         MACRO   FromPage,ToPage,Type
Temp            =       FromPage
                REPT    ToPage+1 - FromPage
                WriteMem Temp
IF              0; (Temp GE 20h) and (Temp LT 60h)
                call    synchronize
ENDIF
                Write&Type Temp
                CheckAddress ;<Type %Temp>
Temp            =       Temp+1
                ENDM
                ENDM

;-------------------------------------------------------------------------------

                MemPage 00h,03h,RAM
                MemPage 04h,0Bh,TEXT
                MemPage 0Ch,1Fh,RAM

                MemPage 20h,5Fh,HGR

                MemPage 060h,0BFh,RAM

                MemPage 0C0h,0C0h,IO
                MemPage 0C1h,0C1h,NA
                MemPage 0C2h,0C2h,NA
                MemPage 0C3h,0C3h,NA
                MemPage 0C4h,0C4h,NA
                MemPage 0C5h,0C5h,NA
                MemPage 0C6h,0C6h,ROM
                MemPage 0C7h,0C7h,NA

                MemPage 0C8h,0CFh,RAM

                MemPage 0D0h,0FFh,DRAM

Emulate         ends

                End

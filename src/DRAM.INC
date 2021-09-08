;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      DRAM.INC                        |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   RAM Card Emulation              |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

;       This file is included in EMULATE.ASM

;-------------- DRAM emulation entries -----------------------------------------

                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

                UseNextFreeSpace

ResetDRAM       proc    far
                mov     ax,Apple
                mov     ds,ax
                mov     ax,Video
                mov     es,ax
                mov     al,82h
                mov     di,offset ResetDRAM_1
                jmp     C08Xr
ResetDRAM_1:    mov     al,82h
                mov     di,offset ResetDRAM_2
                jmp     C08Xr
ResetDRAM_2:    ret
ResetDRAM       endp

; Entry:
;   bx    - file handle
; Action:
;   load memory banks
; Exit:
;   CF: 0-ok, 1-error (don't close file)
DRAMLoad        proc    far
                push    ax cx dx ds
                mov     ax,seg Bank1
                mov     ds,ax
                mov     dx,offset Bank1
                mov     cx,4000h
                mov     ah,3Fh
                int     21h
                cmp     ax,cx
                pop     ds dx cx ax
                ret
DRAMLoad        endp

; Entry:
;   bx    - file handle
; Action:
;   save memory banks
; Exit:
;   CF: 0-ok, 1-error (don't close file)
DRAMSave        proc    far
                push    ax cx dx ds
                mov     ax,seg Bank1
                mov     ds,ax
                mov     dx,offset Bank1
                mov     cx,4000h
                mov     ah,40h
                int     21h
                cmp     ax,cx
                pop     ds dx cx ax
                ret
DRAMSave        endp
                CheckAddress

                UseNextFreeSpace
C08Xr:          and     al,0Fh
                mov     bx,offset C080readTbl
                xlat    CS:[bx]
                mov     bh,C080
                mov     bl,bh
                shl     bl,1
                or      bl,bh
                or      bl,00000111b
                and     bl,al
                mov     al,bl
                mov     C080,al
                xor     al,bh
                test    al,1011b
                jnz     C08Xr_10
                mov     bl,ch
                jmp     di

C08Xr_10:       push    cs
                push    di                      ; BH/BL - old/new C080 value
                jmp     SetDRAM                 ; AL - BH xor BL

C080readTbl     db      0010b,1100b,0000b,1110b,0010b,1100b,0000b,1110b
                db      0011b,1101b,0001b,1111b,0011b,1101b,0001b,1111b
                CheckAddress

                UseNextFreeSpace
C08Xw:          and     al,0Fh
                mov     bx,offset C080writeTbl
                xlat    CS:[bx]
                mov     bh,C080
                mov     bl,bh
                or      bl,00000111b
                and     bl,al
                mov     al,bl
                mov     C080,al
                xor     al,bh
                test    al,1011b
                jz      C08Xw_10
                Save    ax
                call    SetDRAM                 ; BH/BL - old/new C080 value
                Restore ax                      ; AL - BH xor BL
C08Xw_10:       sahf
                mov     bl,ch
                DoNext

C080writeTbl    db      0010b,1000b,0000b,1010b,0010b,1000b,0000b,1010b
                db      0011b,1001b,0001b,1011b,0011b,1001b,0001b,1011b
                CheckAddress

;-------------- DRAM emulation subroutines -------------------------------------

Peripher        segment public
                assume  CS:Peripher,DS:Nothing,ES:Nothing

SetDRAM         Proc    far
;               BH/BL - old/new C080 value, AL - BH xor BL

                test    al,0011b
                jz      SetDRAM_20

                Save    bx cx dx si bp ds es
                test    al,0001b
                jz      SetDRAM_10
                Save    ax
                test    bh,0010b                ; Swap Bank1<->Bank2
                mov     ax,offset Bank1
                mov     bx,offset Bank2
                mov     bp,seg Bank2
                mov     ds,bp
                jz      SetDRAM_05
                mov     bx,0D000h
                mov     bp,Apple
SetDRAM_05:     mov     dx,1000h/1000h
                call    SwapMem
                Restore ax
                test    al,0010b
                jz      SetDRAM_15

SetDRAM_10:     mov     ax,seg DRAM             ; Swap ROM<->RAM
                mov     ds,ax
                mov     ax,offset DRAM
                mov     bx,0D000h
                mov     bp,Apple
                mov     dx,3000h/1000h
                call    SwapMem
SetDRAM_15:     Restore bx cx dx si bp ds es

SetDRAM_20:     test    bl,1000b                ; Set write mode :
                mov     ax,DRAM_DoNotWrite      ;  1 - read/write
                jz      SetDRAM_25              ;  2 - write only
                test    bl,0010b                ;  3 - don't write
                mov     ax,DRAM_WriteOnly
                jz      SetDRAM_25
                mov     ax,DRAM_ReadWrite

SetDRAM_25:     mov     bx,ds
                mov     di,Emulate
                mov     ds,di
Temp            =       0
                REPT    100h-0D0h
                mov     DS:DRAM_ModefyAdr[Temp],ax
Temp            =       Temp+100h
                ENDM
                mov     ds,bx
                mov     bl,ch
                ret
SetDRAM         Endp


SwapMem         Proc    near
                cld
SwapMem_10:     mov     si,ax
                mov     di,offset Buffer1000h
                mov     cx,seg Buffer1000h
                mov     es,cx
                mov     cx,1000h/2
        rep     movsw
                mov     di,ax
                mov     ax,si
                mov     si,bx
                mov     cx,ds
                mov     es,cx
                mov     ds,bp
                mov     cx,1000h/2
        rep     movsw
                mov     di,bx
                mov     bx,si
                mov     si,offset Buffer1000h
                mov     bp,es
                mov     cx,ds
                mov     es,cx
                mov     cx,seg Buffer1000h
                mov     ds,cx
                mov     cx,1000h/2
        rep     movsw
                mov     ds,bp
                mov     bp,es
                dec     dx
                jnz     SwapMem_10
                ret
SwapMem         Endp

Data            segment stack 'stack'
                even
Bank1           db      1000h dup(0)
Bank2           Label   byte
DRAM            db      3000h dup(0)
Data            ends

Peripher        ends

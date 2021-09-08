;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      VIDEO.ASM                       |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Screen Emulation                |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

;       This file is included in EMULATE.ASM

;-------------- Video emulation entries ----------------------------------------

                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

                UseNextFreeSpace
ResetVideo      Proc    far
                ret
ResetVideo      Endp
                CheckAddress

C05X            MACRO   Adr,Table,Mask
                Local   l_r,l_w
                UseNextFreeSpace
Adr&r:          mov     al,C050
                mov     ah,al
IFE 0&Adr&h mod 2
                and     al,Mask
ELSE
                or      al,Mask
ENDIF
                cmp     al,ah
                je      l_r
                mov     C050,al
                cbw
                mov     bx,ax
                shl     bx,1
                push    di
                jmp     SS:Table[bx]
l_r:            xor     bl,bl
                jmp     di
Adr&w:          mov     al,C050
                mov     bh,al
IFE 0&Adr&h mod 2
                and     al,Mask
ELSE
                or      al,Mask
ENDIF
                cmp     al,bh
                je      l_w
                mov     C050,al
                Save    ax
                cbw
                mov     bx,ax
                shl     bx,1
                call    SS:Table[bx]
                Restore ax
                sahf
                DoNext
l_w:            sahf
                DoNext
                CheckAddress
                ENDM

                C05X    C050,C050table,1110b
                C05X    C051,C050table,0001b
                C05X    C052,C052table,1101b
                C05X    C053,C052table,0010b
                C05X    C054,C054table,1011b
                C05X    C055,C054table,0100b
                C05X    C056,C056table,0111b
                C05X    C057,C056table,1000b

;-------------- Video emulation subroutines ------------------------------------

SetTEXT         MACRO                           ;; Destroys DX
                mov     ax,0001h
                int     10h
                mov     ax,0606h
                mov     dx,3CEh
                out     dx,ax
                mov     cx,2000h
                mov     ah,01h
                int     10h
                mov     bl,1
                mov     ax,1003h
                int     10h
                mov     byte ptr SS:[TEXTchars+60h*2],0DBh
                ENDM

SetGR           MACRO                           ;; Destroys DX
                mov     ax,0001h
                int     10h
                mov     ax,0606h
                mov     dx,3CEh
                out     dx,ax
                mov     cx,2000h
                mov     ah,01h
                int     10h
                mov     bl,0
                mov     ax,1003h
                int     10h
                mov     byte ptr SS:[TEXTchars+60h*2],020h
                ENDM

SetPage         MACRO   VideoPage               ;; Destroys DX
                mov     dx,Port3?4h
                mov     ax,high(VideoPage)*100h+0Ch
                out     dx,ax
                jmp     short $+2
                mov     ax,low(VideoPage)*100h+0Dh
                out     dx,ax
		ENDM

SetHGR          MACRO   Page
                mov     ax,000Eh
                int     10h
                call    SetHGRpalette
		SetPage (Page-1)*4000h
		call    FillHGRpage
                ENDM

ShowTEXT        MACRO   Page                    ;; 1 or 2
                Local   Lab1,Lab2,Lab3,Lab4
                cld                             ;; Destroys DX, SI, DI
                mov     si,Page*400h
                xor     di,di
                mov     cx,di
                mov     dx,0800h+40

Lab1:           mov     cl,dl
Lab2:           lodsb
                mov     bl,al
                mov     bh,ch
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab2
                add     di,-40*2 + 8*40*2
                mov     cl,dl
Lab3:           lodsb
                mov     bl,al
                mov     bh,ch
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab3
                add     di,-40*2 + 8*40*2
                mov     cl,dl
Lab4:           lodsb
                mov     bl,al
                mov     bh,ch
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab4

                add     si,8
                add     di,-2*8*40*2
                dec     dh
                jnz     Lab1
		ENDM

ShowGR          MACRO   Page                    ;; 1 or 2
                Local   Lab1,Lab2,Lab3,Lab4
                cld                             ;; Destroys DX, SI, DI
                mov     si,Page*400h
                xor     di,di
                mov     bx,offset GRcolors
                mov     dx,0800h + GRchar

Lab1:           mov     cx,40
Lab2:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab2
                add     di,-40*2 + 8*40*2
                mov     cx,40
Lab3:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab3
                add     di,-40*2 + 8*40*2
                mov     cx,40
Lab4:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab4

                add     si,8
                add     di,-2*8*40*2
                dec     dh
                jnz     Lab1
                ENDM

ShowHGR         MACRO
                Save    bp                      ;; Destroys DX, SI, DI
                mov     si,2000h
                mov     bp,0
                call    ShowHGRsub
                mov     si,4000h
                mov     bp,4000h
                call    ShowHGRsub
                Restore bp
		ENDM

ShowGRmix       MACRO   Page                    ;; 1 or 2
                Local   Lab0,Lab1,Lab2,Lab3,Lab4,Lab5
                cld                             ;; Destroys DX, SI, DI
                mov     si,Page*400h
                xor     di,di
                mov     dx,702h

Lab0:           mov     bx,offset GRcolors
Lab1:           mov     cx,40
Lab2:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,GRchar
                stosw
                loop    Lab2

                add     di,-40*2 + 8*40*2
                dec     dl
                jz      Lab3
                jns     Lab1

                add     si,8
                add     di,-3*8*40*2 + 40*2
                sub     dx,01FFh-2
                jns     Lab1
                jmp     Lab5

Lab3:           cmp     dh,3
                ja      Lab1
                mov     cx,40
Lab4:           lodsb
                mov     bl,al
                mov     bh,ch
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab4

                add     si,8
                add     di,-2*8*40*2
                sub     dx,100h-2
                jns     Lab0
Lab5:
		ENDM

ShowHGRmix      MACRO
                Save    bp
                mov     si,2000h
                mov     bp,0
                call    ShowHgrMixSub
                mov     si,4000h
                mov     bp,4000h
                call    ShowHgrMixSub
                Restore bp
                ENDM

Show4TEXT       MACRO   Page                    ;; 1 or 2
                Local   Lab1,Lab2,Lab3,Lab4
                cld                             ;; Destroys DX, SI, DI
                mov     bx,offset GRcolors
                mov     dx,40
                mov     di,20*40*2

                mov     si,Page*400h+250h
                mov     cx,dx
Lab1:           lodsb
                mov     bl,al
                mov     bh,dh
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab1
                mov     si,Page*400h+2D0h
                mov     cx,dx
Lab2:           lodsb
                mov     bl,al
                mov     bh,dh
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab2
                mov     si,Page*400h+350h
                mov     cx,dx
Lab3:           lodsb
                mov     bl,al
                mov     bh,dh
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab3
                mov     si,Page*400h+3D0h
                mov     cx,dx
Lab4:           lodsb
                mov     bl,al
                mov     bh,dh
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab4
		ENDM

Show4GR         MACRO   Page                    ;; 1 or 2
                Local   Lab1,Lab2,Lab3,Lab4
                cld                             ;; Destroys DX, SI, DI
                mov     bx,offset GRcolors
                xor     cx,cx
                mov     dx,40*100h + GRchar
                mov     di,20*40*2

                mov     si,Page*400h+250h
                mov     cl,dh
Lab1:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab1
                mov     si,Page*400h+2D0h
                mov     cl,dh
Lab2:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab2
                mov     si,Page*400h+350h
                mov     cl,dh
Lab3:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab3
                mov     si,Page*400h+3D0h
                mov     cl,dh
Lab4:           lodsb
                xlat    SS:[bx]
                mov     ah,al
                mov     al,dl
                stosw
                loop    Lab4
		ENDM

Show4HGR        MACRO
                Save    bp
                mov     si,2000h
                mov     bp,0
                call    Show4HgrSub
                mov     si,4000h
                mov     bp,4000h
                call    Show4HgrSub
                Restore bp
                ENDM

Show4HgrText    MACRO
                Save    bp
                mov     si,400h
                mov     bp,0
                call    Show4HgrTextSub
                mov     si,800h
                mov     bp,4000h
                call    Show4HgrTextSub
                Restore bp
                ENDM

ShowGR12        MACRO   Page                    ;; 1 or 2
                Local   Lab1,Lab2,Lab3,Lab4
                cld                             ;; Destroys DX, SI, DI
                mov     si,Page*400h
                mov     di,1
                mov     bx,offset GRcolors
                xor     cx,cx
                mov     dx,800h+40

Lab1:           mov     cl,dl
Lab2:           lodsb
                xlat    SS:[bx]
                stosb
                inc     di
                loop    Lab2
                add     di,-40*2 + 8*40*2
                mov     cl,dl
Lab3:           lodsb
                xlat    SS:[bx]
                stosb
                inc     di
                loop    Lab3
                add     di,-40*2 + 8*40*2
                mov     cl,dl
Lab4:           lodsb
                xlat    SS:[bx]
                stosb
                inc     di
                loop    Lab4

                add     si,8
                add     di,-2*8*40*2
                dec     dh
                jnz     Lab1
		ENDM

ShowGRmix12     MACRO   Page                    ;; 1 or 2
                Local   Lab0,Lab1,Lab2,Lab3,Lab4,Lab5
                cld                             ;; Destroys DX, SI, DI
                mov     si,Page*400h
                xor     di,di
                mov     dx,702h

Lab0:           mov     bx,offset GRcolors
Lab1:           mov     cx,40
Lab2:           lodsb
                xlat    SS:[bx]
                inc     di
                stosb
                loop    Lab2

                add     di,-40*2 + 8*40*2
                dec     dl
                jz      Lab3
                jns     Lab1

                add     si,8
                add     di,-3*8*40*2 + 40*2
                sub     dx,01FFh-2
                jns     Lab1
                jmp     Lab5

Lab3:           cmp     dh,3
                ja      Lab1
                mov     cx,40
Lab4:           lodsb
                mov     bl,al
                mov     bh,ch
                shl     bx,1
                mov     ax,SS:TEXTchars[bx]
                stosw
                loop    Lab4

                add     si,8
                add     di,-2*8*40*2
                sub     dx,100h-2
                jns     Lab0
Lab5:
		ENDM


;-------------------------------------------------------------------------------

                UseNextFreeSpace
C050_0:         Save    cx dx si
		SetTEXT
		ShowTEXT 1
                mov     ax,TEXT_TextMode
                mov     bx,ax
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_1:         Save    cx dx si
		SetTEXT
		ShowTEXT 2
                mov     ax,TEXT_TextMode
                mov     bx,ax
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_A:         Save    cx dx si
		SetTEXT
		ShowTEXT 1
                mov     ax,HGR_NA
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                mov     ax,TEXT_TextMode
                mov     bx,ax
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_B:         Save    cx dx si
		SetTEXT
		ShowTEXT 2
                mov     ax,HGR_NA
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                mov     ax,TEXT_TextMode
                mov     bx,ax
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_2:         Save    cx dx si
                SetGR
		ShowGR  1
                mov     ax,TEXT_GrMode
                mov     bx,ax
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_3:         Save    cx dx si
		SetGR
		ShowGR  2
                mov     ax,TEXT_GrMode
                mov     bx,ax
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_4:         Save    cx dx si
                SetGR
                ShowGRmix 1
                mov     ax,TEXT_GrMode
                mov     bx,TEXT_MixedGrMode
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_5:         Save    cx dx si
		SetGR
                ShowGRmix 2
                mov     ax,TEXT_GrMode
                mov     bx,TEXT_MixedGrMode
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_6:         Save    cx dx si
                SetHGR  1
                ShowHGR
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage1
                mov     ax,HGR_HgrMode
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_7:         Save    cx dx si
		SetHGR  2
                ShowHGR
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage2
                mov     ax,HGR_HgrMode
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_8:         Save    cx dx si
		SetHGR  1
                ShowHGRmix
                mov     ax,TEXT_NA
                mov     bx,TEXT_MixedHgrMode
                call    SetTextWMpage1
                call    Set4TextWMpage2
                mov     ax,HGR_HgrMode
                mov     bx,HGR_MixedMode
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C050_9:         Save    cx dx si
		SetHGR  2
                ShowHGRmix
                mov     ax,TEXT_NA
                mov     bx,TEXT_MixedHgrMode
                call    SetTextWMpage2
                call    Set4TextWMpage1
                mov     ax,HGR_HgrMode
                mov     bx,HGR_MixedMode
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si

C052_0:
C052_1:         mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_2:         Save    cx dx si
                Show4GR 1
                mov     bx,TEXT_GrMode
                call    Set4TextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_3:         Save    cx dx si
                Show4GR 2
                mov     bx,TEXT_GrMode
                call    Set4TextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_4:         Save    cx dx si
                Show4TEXT 1
                mov     bx,TEXT_MixedGrMode
                call    Set4TextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_5:         Save    cx dx si
                Show4TEXT 2
                mov     bx,TEXT_MixedGrMode
                call    Set4TextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_6:         Save    cx dx si
                Show4HGR
                mov     bx,TEXT_NA
                call    Set4TextWMpage1
                call    Set4TextWMpage2
                mov     bx,HGR_HgrMode
                call    Set4HgrWMpage1
                call    Set4HgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_7:         Save    cx dx si
                Show4HGR
                mov     bx,TEXT_NA
                call    Set4TextWMpage1
                call    Set4TextWMpage2
                mov     bx,HGR_HgrMode
                call    Set4HgrWMpage1
                call    Set4HgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_8:         Save    cx dx si
                Show4HgrText
                mov     bx,HGR_MixedMode
                call    Set4HgrWMpage1
                call    Set4HgrWMpage2
                mov     bx,TEXT_MixedHgrMode
                call    Set4TextWMpage1
                call    Set4TextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C052_9:         Save    cx dx si
                Show4HgrText
                mov     bx,HGR_MixedMode
                call    Set4HgrWMpage1
                call    Set4HgrWMpage2
                mov     bx,TEXT_MixedHgrMode
                call    Set4TextWMpage1
                call    Set4TextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress


                UseNextFreeSpace
C054_0:         Save    cx dx si
		ShowTEXT 1
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage2
                mov     ax,TEXT_TextMode
                mov     bx,ax
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_1:         Save    cx dx si
		ShowTEXT 2
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage1
                mov     ax,TEXT_TextMode
                mov     bx,ax
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_2:         Save    cx dx si
                ShowGR12 1
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage2
                mov     ax,TEXT_GrMode
                mov     bx,ax
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_3:         Save    cx dx si
                ShowGR12 2
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage1
                mov     ax,TEXT_GrMode
                mov     bx,ax
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_4:         Save    cx dx si
                ShowGRmix12 1
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage2
                mov     ax,TEXT_GrMode
                mov     bx,TEXT_MixedGrMode
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_5:         Save    cx dx si
                ShowGRmix12 2
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage1
                mov     ax,TEXT_GrMode
                mov     bx,TEXT_MixedGrMode
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_6:         Save    cx dx si
		SetPage 0
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_7:         Save    cx dx si
		SetPage 4000h
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_8:         Save    cx dx si
                SetPage 0
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C054_9:         Save    cx dx si
                SetPage 4000h
                Restore cx dx si

C056_0:
C056_1:         mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_2:         Save    cx dx si
		SetGR
		ShowGR  1
                mov     ax,HGR_NA
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                mov     ax,TEXT_GrMode
                mov     bx,ax
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_3:         Save    cx dx si
		SetGR
		ShowGR  2
                mov     ax,HGR_NA
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                mov     ax,TEXT_GrMode
                mov     bx,ax
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_4:         Save    cx dx si
		SetGR
                ShowGRmix 1
                mov     ax,HGR_NA
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                mov     ax,TEXT_GrMode
                mov     bx,TEXT_MixedGrMode
                call    SetTextWMpage1
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_5:         Save    cx dx si
		SetGR
                ShowGRmix 2
                mov     ax,HGR_NA
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                mov     ax,TEXT_GrMode
                mov     bx,TEXT_MixedGrMode
                call    SetTextWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_6:         Save    cx dx si
		SetHGR  1
                ShowHGR
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage1
                mov     ax,HGR_HgrMode
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_7:         Save    cx dx si
		SetHGR  2
                ShowHGR
                mov     ax,TEXT_NA
                mov     bx,ax
                call    SetTextWMpage2
                mov     ax,HGR_HgrMode
                mov     bx,ax
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_8:         Save    cx dx si
		SetHGR  1
                ShowHGRmix
                mov     ax,TEXT_NA
                mov     bx,TEXT_MixedHgrMode
                call    SetTextWMpage1
                call    Set4TextWMpage2
                mov     ax,HGR_HgrMode
                mov     bx,HGR_MixedMode
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

                UseNextFreeSpace
C056_9:         Save    cx dx si
		SetHGR  2
                ShowHGRmix
                mov     ax,TEXT_NA
                mov     bx,TEXT_MixedHgrMode
                call    SetTextWMpage2
                call    Set4TextWMpage1
                mov     ax,HGR_HgrMode
                mov     bx,HGR_MixedMode
                call    SetHgrWMpage1
                call    SetHgrWMpage2
                Restore cx dx si
                mov     bl,0
                ret
                CheckAddress

;-------------------------------------------------------------------------------

                UseNextFreeSpace
MixedHgrMode1:  pushf
                cli
                shl     di,1
                mov     ax,di
                cmp     al,2*40*2
                jb      MixedHgrMode10
                mov     di,SS:HgrTextAdr[di-(1*400h+200h)*2]
                xchg    bl,bh
                shl     bx,1
Temp            =       0
                REPT    8
                mov     ax,SS:HGRchars[bx][Temp*100h*2]
                mov     ES:[di][Temp*40*2],ax
Temp            =       Temp+1
                ENDM
                mov     bl,0
MixedHgrMode10: popf
                DoNext
                CheckAddress

                UseNextFreeSpace
MixedHgrMode2:  pushf
                cli
                shl     di,1
                mov     ax,di
                cmp     al,2*40*2
                jb      MixedHgrMode20
                mov     di,SS:HgrTextAdr[di-(2*400h+200h)*2]
                xchg    bl,bh
                shl     bx,1
Temp            =       0
                REPT    8
                mov     ax,SS:HGRchars[bx][Temp*100h*2]
                mov     ES:[di+4000h][Temp*40*2],ax
Temp            =       Temp+1
                ENDM
                mov     bl,0
MixedHgrMode20: popf
                DoNext
                CheckAddress

                UseNextFreeSpace
SetHGRpalette   Proc    near
                Save    es
                mov     bx,0
                mov     cx,40h
                mov     dx,seg DACtable
                mov     es,dx
                mov     dx,offset DACtable
                mov     ax,1012h
                int     10h
                push    cs
		pop     es
		mov     dx,offset HGRpalettes
                mov     ax,1002h
                int     10h
                Restore es
                ret

HGRpalettes     db      2 dup(0,101100b,0,001011b,0,100011b,0,010110b),0
SetHGRpalette   Endp


FillHGRpage     Proc    near
		mov     di,0
                mov     dx,3C4h
                mov     ax,0402h                ; write to plane 2
                out     dx,ax
		mov     byte ptr ES:[di], 00110011b
                mov     ax,0202h                ; write to plane 1
                out     dx,ax
                mov     byte ptr ES:[di], 01010101b
                mov     ax,0F02h                ; write to all planes
                out     dx,ax
                mov     dx,3CEh
		mov     ax,0105h                ; write mode 1
                out     dx,ax
                mov     al,ES:[di]
                inc     di
		cld
		stosb
                mov     cx,8000h/2-1
	rep     stosw
                mov     ax,0005h                ; write mode 0
                out     dx,ax
                mov     ax,0004h                ; read from plane 0
		out     dx,ax
                mov     dx,3C4h
                mov     ax,0102h                ; write to plane 0
                out     dx,ax
		ret
FillHGRpage     Endp
                CheckAddress


                UseNextFreeSpace
SetTextWMpage1  Proc    near
                mov     CS:TEXT_ModefyAdr[000h],ax
                mov     CS:TEXT_ModefyAdr[100h],ax
Set4TextWMpage1 label   near
                mov     CS:TEXT_ModefyAdr[200h],bx
                mov     CS:TEXT_ModefyAdr[300h],bx
                ret
SetTextWMpage1  Endp

SetTextWMpage2  Proc    near
                mov     CS:TEXT_ModefyAdr[400h],ax
                mov     CS:TEXT_ModefyAdr[500h],ax
Set4TextWMpage2 label   near
                mov     CS:TEXT_ModefyAdr[600h],bx
                mov     CS:TEXT_ModefyAdr[700h],bx
                ret
SetTextWMpage2  Endp
                CheckAddress

                UseNextFreeSpace
SetHgrWMpage1   Proc    near
Temp            =       0
        REPT    20h/4
                mov     CS:HGR_ModefyAdr[Temp],ax
                mov     CS:HGR_ModefyAdr[Temp+100h],ax
Temp            =       Temp+400h
        ENDM
Set4HgrWMpage1  label   near
Temp            =       200h
        REPT    20h/4
                mov     CS:HGR_ModefyAdr[Temp],bx
                mov     CS:HGR_ModefyAdr[Temp+100h],bx
Temp            =       Temp+400h
        ENDM
                ret
SetHgrWMpage1   Endp
                CheckAddress

                UseNextFreeSpace
SetHgrWMpage2   Proc    near
Temp            =       2000h
        REPT    20h/4
                mov     CS:HGR_ModefyAdr[Temp],ax
                mov     CS:HGR_ModefyAdr[Temp+100h],ax
Temp            =       Temp+400h
        ENDM
Set4HgrWMpage2  label   near
Temp            =       2200h
        REPT    20h/4
                mov     CS:HGR_ModefyAdr[Temp],bx
                mov     CS:HGR_ModefyAdr[Temp+100h],bx
Temp            =       Temp+400h
        ENDM
                ret
SetHgrWMpage2   Endp
                CheckAddress

;-------------------------------------------------------------------------------

Peripher        segment public
                assume  CS:Peripher,DS:Nothing,ES:Nothing

ShowHGRsub      Proc    far                     ; SI - 2000h or 4000h
                cld                             ; BP - 0 or 4000h
                mov     di,[HGRadr]

ShowHGRsub1:    add     di,bp
                mov     dx,0200h+9

ShowHGRsub2:    mov     al,0

ShowHGRsub3:    mov     bh,0
                mov     bl,[si]
                inc     si
		shl     bx,1
                mov     cx,HGRcolors[bx]
		and     al,byte ptr HGRmasks[bx]+1
                or      al,ch
                stosb

		mov     bh,1
                mov     bl,[si]
                inc     si
		shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     ch,byte ptr HGRmasks[bx]+1
                and     cl,ch
                and     ch,ah
                xor     ah,ch
                or      ah,cl
		xchg    al,ah
                stosw

		mov     bh,2
                mov     bl,[si]
                inc     si
		shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     cl,byte ptr HGRmasks[bx]+1
                and     ch,cl
                and     cl,ah
                xor     ah,cl
                or      ah,ch
		xchg    al,ah
                stosw

		mov     bh,3
                mov     bl,[si]
                inc     si
		shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     ch,byte ptr HGRmasks[bx]+1
                and     cl,ch
                and     ch,ah
                xor     ah,ch
                or      ah,cl
		xchg    al,ah
                stosw
		mov     al,ch

                dec     dl
                jns     ShowHGRsub3

                add     di,-35*2 + 8*8*40*2
                sub     dx,01FFh-9
                jns     ShowHGRsub2

                add     si,8
                mov     di,si
                and     di,1FFFh
                jz      ShowHGRsub4
                shl     di,1
                mov     di,HGRadr[di]
		jmp     ShowHGRsub1
ShowHGRsub4:    ret
ShowHGRsub      Endp


ShowHgrMixSub   Proc    far                     ; SI - 2000h or 4000h
                Save    si bp                   ; BP - 0 or 4000h
                cld
                mov     di,[HGRadr]

ShowHgrMixSub1: add     di,bp
                mov     dx,0200h+9

ShowHgrMixSub2: mov     al,0

ShowHgrMixSub3: mov     bh,0
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     cx,HGRcolors[bx]
                and     al,byte ptr HGRmasks[bx]+1
                or      al,ch
                stosb

                mov     bh,1
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     ch,byte ptr HGRmasks[bx]+1
                and     cl,ch
                and     ch,ah
                xor     ah,ch
                or      ah,cl
                xchg    al,ah
                stosw

                mov     bh,2
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     cl,byte ptr HGRmasks[bx]+1
                and     ch,cl
                and     cl,ah
                xor     ah,cl
                or      ah,ch
                xchg    al,ah
                stosw

                mov     bh,3
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     ch,byte ptr HGRmasks[bx]+1
                and     cl,ch
                and     ch,ah
                xor     ah,ch
                or      ah,cl
                xchg    al,ah
                stosw
                mov     al,ch

                dec     dl
                jns     ShowHgrMixSub3

                add     di,-35*2 + 8*8*40*2
                sub     dx,01FFh-9
                js      ShowHgrMixSub5
                mov     ax,di
                sub     ax,bp
                cmp     ax,20*8*40*2
                jae     ShowHgrMixSub6
                jmp     ShowHgrMixSub2

ShowHgrMixSub6: add     si,40
ShowHgrMixSub5: add     si,8
                mov     di,si
                and     di,1FFFh
                jz      ShowHgrMixSub4
                shl     di,1
                mov     di,HGRadr[di]
                jmp     ShowHgrMixSub1
ShowHgrMixSub4: Restore si bp
                shr     si,3

Show4HgrTextSub label   far                     ; SI - 400h or 800h
                add     si,250h                 ; BP - 0 or 4000h
                lea     di,[bp+20*8*40*2]
                mov     dl,4
S4HT1:          mov     cx,40
S4HT2:          lodsb
                xor     ah,ah
                shl     ax,1
                mov     bx,ax
Temp            =       0
                REPT    8
                mov     ax,HGRchars[bx][Temp*100h*2]
                mov     ES:[di][Temp*40*2],ax
Temp            =       Temp+1
                ENDM
                add     di,2
                loop    S4HT2
                add     si,-40+80h
                add     di,-40*2+8*40*2
                dec     dl
                jnz     S4HT1
                ret
ShowHgrMixSub   Endp


Show4HgrSub     Proc    far                     ; SI - 2000h or 4000h
                add     si,250h                 ; BP - 0 or 4000h
                mov     di,HGRadr[250h*2]
                lea     di,[di+bp-(40*2-35*2)]

Show4HgrSub1:   mov     dx,0700h+9
Show4HgrSub2:   mov     cx,40*2-35*2
                mov     al,0
        rep     stosb
                mov     bx,di
                sub     bx,bp
                cmp     bx,24*8*40*2
                jae     Show4HgrSub4

Show4HgrSub3:   mov     bh,0
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     cx,HGRcolors[bx]
                and     al,byte ptr HGRmasks[bx]+1
                or      al,ch
                stosb

                mov     bh,1
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     ch,byte ptr HGRmasks[bx]+1
                and     cl,ch
                and     ch,ah
                xor     ah,ch
                or      ah,cl
                xchg    al,ah
                stosw

                mov     bh,2
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     cl,byte ptr HGRmasks[bx]+1
                and     ch,cl
                and     cl,ah
                xor     ah,cl
                or      ah,ch
                xchg    al,ah
                stosw

                mov     bh,3
                mov     bl,[si]
                inc     si
                shl     bx,1
                mov     ax,HGRcolors[bx]
                mov     ch,byte ptr HGRmasks[bx]+1
                and     cl,ch
                and     ch,ah
                xor     ah,ch
                or      ah,cl
                xchg    al,ah
                stosw
                mov     al,ch

                dec     dl
                jns     Show4HgrSub3

                add     si,-40+400h
                sub     dx,01FFh-9
                js      Show4HgrSub5
                jmp     Show4HgrSub2
Show4HgrSub4:   ret
Show4HgrSub5:   add     si,-8*400h+80h
                jmp     Show4HgrSub1
Show4HgrSub     Endp

Peripher        ends

Data            segment stack 'stack'

; 0/1 - TEXT Mode Page 1/2 (from  GR Mode)
; A/B - TEXT Mode Page 1/2 (from HGR Mode)
; 2/3 -   GR Mode Page 1/2
; 4/5 -   GR Mode Page 1/2, Mixed
; 6/7 -  HGR Mode Page 1/2
; 8/9 -  HGR Mode Page 1/2, Mixed
		even
C050table       dw      C050_2,C050_0,C050_4,C050_0,C050_3,C050_1,C050_5,C050_1
                dw      C050_6,C050_A,C050_8,C050_A,C050_7,C050_B,C050_9,C050_B
C052table       dw      C052_2,C052_0,C052_4,C052_0,C052_3,C052_1,C052_5,C052_1
                dw      C052_6,C052_0,C052_8,C052_0,C052_7,C052_1,C052_9,C052_1
C054table       dw      C054_2,C054_0,C054_4,C054_0,C054_3,C054_1,C054_5,C054_1
                dw      C054_6,C054_0,C054_8,C054_0,C054_7,C054_1,C054_9,C054_1
C056table       dw      C056_2,C056_0,C056_4,C056_0,C056_3,C056_1,C056_5,C056_1
                dw      C056_6,C056_0,C056_8,C056_0,C056_7,C056_1,C056_9,C056_1
Data            ends

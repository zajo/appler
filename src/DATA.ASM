;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      DATA.ASM                        |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Global Data                     |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC

Startup         segment
		assume  CS:Startup,DS:Data,ES:Data,SS:Data

InitData        Proc    near
                push    ss
                pop     ds
                push    ss
                pop     es
		cld
                call    InitTEXTadr
                call    InitHGRadr
                call    InitHGRcol_mask
                call    InitHgrTextAdr
                call    InitHGRchars
		ret
InitData	Endp


NotShownAdr     =       8000h-4

InitTEXTadr     Proc    near
                mov     di,offset TEXTadr
                xor     ax,ax

                mov     dh,8
InitTEXTadr1:   mov     dl,3
InitTEXTadr2:   mov     cx,40
InitTEXTadr3:   stosw
		add     ax,2
                loop    InitTEXTadr3

                add     ax,-40*2 + 8*40*2
                dec     dl
                jnz     InitTEXTadr2

                Save    ax
                mov     ax,NotShownAdr
                mov     cx,8
        rep     stosw
                Restore ax
                add     ax,-3*8*40*2 + 40*2
                dec     dh
                jnz     InitTEXTadr1

		ret
InitTEXTadr     Endp


InitHGRadr      Proc    near
                mov     di,offset HGRadr
                mov     ax,5

		mov     bl,8
InitHGRadr1:    mov     dh,8
InitHGRadr2:    mov     dl,3
InitHGRadr3:    mov     cx,10
InitHGRadr4:    stosw
                inc     ax
	      	stosw
		add     ax,2
	      	stosw
		add     ax,2
	      	stosw
		add     ax,2
                loop    InitHGRadr4

                add     ax,-35*2 + 8*8*40*2
                dec     dl
                jnz     InitHGRadr3

                Save    ax
                mov     ax,NotShownAdr
                mov     cx,8
        rep     stosw
                Restore ax
                add     ax,-3*8*8*40*2 + 8*40*2
                dec     dh
                jnz     InitHGRadr2

                add     ax,-8*8*40*2 + 40*2
                dec     bl
                jnz     InitHGRadr1

		ret
InitHGRadr      Endp


InitHGRmasks    dw      0000000000000011b
                dw      1000000000000001b
		dw	1111110000000000b
                dw      1111111000000000b
		dw	1111000000000000b
                dw      1111100000000000b
		dw	1100000000000000b
                dw      1110000000000000b

InitHGRcol_mask Proc    near
                mov     di,offset HGRcolors
		mov     ax,0000000000000000b
InitHGRc_m1:    mov     dx,1100000000000000b
                stosw
InitHGRc_m2:    xor     ax,dx
                test    ax,dx
                jnz     InitHGRc_m1
                shr     dx,2
		test    dx,0000000000000011b
                jz      InitHGRc_m2

                mov     si,offset HGRcolors
		mov     cx,80h
InitHGRc_m3:    lodsw
                shr     ax,1
                stosw
		loop    InitHGRc_m3

                mov     si,offset HGRcolors
                mov     cx,2*80h
InitHGRc_m4:    lodsw
                rol     ax,2
		xchg    al,ah
                stosw
		loop    InitHGRc_m4

                mov     cx,2*2*80h
InitHGRc_m5:    lodsw
                rol     ax,2
                stosw
                loop    InitHGRc_m5

		mov     si,offset InitHGRmasks
                mov     di,offset HGRmasks
		mov     bl,8
InitHGRc_m6:    lods    InitHGRmasks
                mov     cx,80h
	rep     stosw
                dec     bl
		jnz     InitHGRc_m6

                ret
InitHGRcol_mask Endp


InitHgrTextAdr  Proc    near
                mov     di,offset HgrTextAdr
                mov     ax,4*8*40*2

                mov     dh,4
InitH_Tadr1:    mov     dl,3
InitH_Tadr2:    mov     cx,40
InitH_Tadr3:    stosw
		add     ax,2
                loop    InitH_Tadr3

                add     ax,-40*2 + 8*8*40*2
                dec     dl
                jnz     InitH_Tadr2

                Save    ax
                mov     ax,NotShownAdr
                mov     cx,8
        rep     stosw
                Restore ax
                add     ax,-3*8*8*40*2 + 8*40*2
                dec     dh
                jnz     InitH_Tadr1

                ret
InitHgrTextAdr  Endp


InitHGRchars    Proc    near
                mov     ax,1130h
                mov     bh,3
                int     10h
                xor     bx,bx
InitHGRchars10: mov     ax,bx
                ror     ah,1
                cwd
                not     dx
                mov     di,dx
                mov     si,TEXTchars[BX]
                and     si,0FFh
                mov     cl,3
                shl     si,cl
                add     si,bp
InitHGRchars20: lods    byte ptr ES:[SI]
                mov     cx,8
InitHGRchars30: shr     al,1
                rcr     dx,1
                sar     dx,1
                loop    InitHGRchars30
                xchg    dl,dh
                xor     dx,di
                mov     HGRchars[BX],dx
                add     bh,10b
                cmp     bh,8*10b
                jb      InitHGRchars20
                add     bx,-8*10b*100h+2
                cmp     bx,100h*2
                jb      InitHGRchars10
                ret
InitHGRchars    Endp

Startup         ends

;===============================================================================

Data            segment stack 'stack'

		even
TEXTadr         dw      400h dup(0)

HGRadr          dw      2000h dup(0)

HGRcolors       dw      4*100h dup(0)
HGRmasks        dw      4*100h dup(0)

HgrTextAdr      dw      4*80h dup(0)
HGRchars        dw      8*100h dup(0)


TEXTchars       dw      7040h,7041h,7042h,7043h,7044h,7045h,7046h,7047h ;
                dw      7048h,7049h,704Ah,704Bh,704Ch,704Dh,704Eh,704Fh ; I
                dw      7050h,7051h,7052h,7053h,7054h,7055h,7056h,7057h ; N
                dw      7058h,7059h,705Ah,705Bh,705Ch,705Dh,705Eh,705Fh ; V
                dw      7020h,7021h,7022h,7023h,7024h,7025h,7026h,7027h ; E
                dw      7028h,7029h,702Ah,702Bh,702Ch,702Dh,702Eh,702Fh ; R
                dw      7030h,7031h,7032h,7033h,7034h,7035h,7036h,7037h ; S
                dw      7038h,7039h,703Ah,703Bh,703Ch,703Dh,703Eh,703Fh ; E

                dw      0F040h,0F041h,0F042h,0F043h,0F044h,0F045h,0F046h,0F047h ;
                dw      0F048h,0F049h,0F04Ah,0F04Bh,0F04Ch,0F04Dh,0F04Eh,0F04Fh ;
                dw      0F050h,0F051h,0F052h,0F053h,0F054h,0F055h,0F056h,0F057h ; F
                dw      0F058h,0F059h,0F05Ah,0F05Bh,0F05Ch,0F05Dh,0F05Eh,0F05Fh ; L
                dw      0F020h,0F021h,0F022h,0F023h,0F024h,0F025h,0F026h,0F027h ; A
                dw      0F028h,0F029h,0F02Ah,0F02Bh,0F02Ch,0F02Dh,0F02Eh,0F02Fh ; S
                dw      0F030h,0F031h,0F032h,0F033h,0F034h,0F035h,0F036h,0F037h ; H
                dw      0F038h,0F039h,0F03Ah,0F03Bh,0F03Ch,0F03Dh,0F03Eh,0F03Fh ;

                dw      0740h,0741h,0742h,0743h,0744h,0745h,0746h,0747h ; C
                dw      0748h,0749h,074Ah,074Bh,074Ch,074Dh,074Eh,074Fh ; T
                dw      0750h,0751h,0752h,0753h,0754h,0755h,0756h,0757h ; R
                dw      0758h,0759h,075Ah,075Bh,075Ch,075Dh,075Eh,075Fh ; L

                dw      0720h,0721h,0722h,0723h,0724h,0725h,0726h,0727h ;
                dw      0728h,0729h,072Ah,072Bh,072Ch,072Dh,072Eh,072Fh ;
                dw      0730h,0731h,0732h,0733h,0734h,0735h,0736h,0737h ;
                dw      0738h,0739h,073Ah,073Bh,073Ch,073Dh,073Eh,073Fh ; N
                dw      0740h,0741h,0742h,0743h,0744h,0745h,0746h,0747h ; O
                dw      0748h,0749h,074Ah,074Bh,074Ch,074Dh,074Eh,074Fh ; R
                dw      0750h,0751h,0752h,0753h,0754h,0755h,0756h,0757h ; M
                dw      0758h,0759h,075Ah,075Bh,075Ch,075Dh,075Eh,075Fh ; A
                dw      0760h,0761h,0762h,0763h,0764h,0765h,0766h,0767h ; L
                dw      0768h,0769h,076Ah,076Bh,076Ch,076Dh,076Eh,076Fh ;
                dw      0770h,0771h,0772h,0773h,0774h,0775h,0776h,0777h ;
                dw      0778h,0779h,077Ah,077Bh,077Ch,077Dh,077Eh,07B1h ;


GRcolors        db      000h,004h,001h,005h,003h,007h,002h,009h
                db      006h,00Dh,008h,00Ch,00Ah,00Eh,00Bh,00Fh
                db      040h,044h,041h,045h,043h,047h,042h,049h
                db      046h,04Dh,048h,04Ch,04Ah,04Eh,04Bh,04Fh
                db      010h,014h,011h,015h,013h,017h,012h,019h
                db      016h,01Dh,018h,01Ch,01Ah,01Eh,01Bh,01Fh
                db      050h,054h,051h,055h,053h,057h,052h,059h
                db      056h,05Dh,058h,05Ch,05Ah,05Eh,05Bh,05Fh
                db      030h,034h,031h,035h,033h,037h,032h,039h
                db      036h,03Dh,038h,03Ch,03Ah,03Eh,03Bh,03Fh
                db      070h,074h,071h,075h,073h,077h,072h,079h
                db      076h,07Dh,078h,07Ch,07Ah,07Eh,07Bh,07Fh
                db      020h,024h,021h,025h,023h,027h,022h,029h
                db      026h,02Dh,028h,02Ch,02Ah,02Eh,02Bh,02Fh
                db      090h,094h,091h,095h,093h,097h,092h,099h
                db      096h,09Dh,098h,09Ch,09Ah,09Eh,09Bh,09Fh
                db      060h,064h,061h,065h,063h,067h,062h,069h
                db      066h,06Dh,068h,06Ch,06Ah,06Eh,06Bh,06Fh
                db      0D0h,0D4h,0D1h,0D5h,0D3h,0D7h,0D2h,0D9h
                db      0D6h,0DDh,0D8h,0DCh,0DAh,0DEh,0DBh,0DFh
                db      080h,084h,081h,085h,083h,087h,082h,089h
                db      086h,08Dh,088h,08Ch,08Ah,08Eh,08Bh,08Fh
                db      0C0h,0C4h,0C1h,0C5h,0C3h,0C7h,0C2h,0C9h
                db      0C6h,0CDh,0C8h,0CCh,0CAh,0CEh,0CBh,0CFh
                db      0A0h,0A4h,0A1h,0A5h,0A3h,0A7h,0A2h,0A9h
                db      0A6h,0ADh,0A8h,0ACh,0AAh,0AEh,0ABh,0AFh
                db      0E0h,0E4h,0E1h,0E5h,0E3h,0E7h,0E2h,0E9h
                db      0E6h,0EDh,0E8h,0ECh,0EAh,0EEh,0EBh,0EFh
                db      0B0h,0B4h,0B1h,0B5h,0B3h,0B7h,0B2h,0B9h
                db      0B6h,0BDh,0B8h,0BCh,0BAh,0BEh,0BBh,0BFh
                db      0F0h,0F4h,0F1h,0F5h,0F3h,0F7h,0F2h,0F9h
                db      0F6h,0FDh,0F8h,0FCh,0FAh,0FEh,0FBh,0FFh

                even
DACtable        db      00h,00h,00h,00h,00h,2Ah,00h,2Ah,00h,00h,2Ah,2Ah,2Ah,00h,00h,2Ah
                db      00h,2Ah,2Ah,2Ah,00h,2Ah,2Ah,2Ah,00h,00h,15h,00h,00h,3Fh,00h,2Ah
                db      15h,00h,2Ah,3Fh,2Ah,00h,15h,2Ah,00h,3Fh,2Ah,2Ah,15h,2Ah,2Ah,3Fh
                db      00h,15h,00h,00h,15h,2Ah,00h,3Fh,00h,00h,3Fh,2Ah,2Ah,15h,00h,2Ah
                db      15h,2Ah,2Ah,3Fh,00h,2Ah,3Fh,2Ah,00h,15h,15h,00h,15h,3Fh,00h,3Fh
                db      15h,00h,3Fh,3Fh,2Ah,15h,15h,2Ah,15h,3Fh,2Ah,3Fh,15h,2Ah,3Fh,3Fh
                db      15h,00h,00h,15h,00h,2Ah,15h,2Ah,00h,15h,2Ah,2Ah,3Fh,00h,00h,3Fh
                db      00h,2Ah,3Fh,2Ah,00h,3Fh,2Ah,2Ah,15h,00h,15h,15h,00h,3Fh,15h,2Ah
                db      15h,15h,2Ah,3Fh,3Fh,00h,15h,3Fh,00h,3Fh,3Fh,2Ah,15h,3Fh,2Ah,3Fh
                db      15h,15h,00h,15h,15h,2Ah,15h,3Fh,00h,15h,3Fh,2Ah,3Fh,15h,00h,3Fh
                db      15h,2Ah,3Fh,3Fh,00h,3Fh,3Fh,2Ah,15h,15h,15h,15h,15h,3Fh,15h,3Fh
                db      15h,15h,3Fh,3Fh,3Fh,15h,15h,3Fh,15h,3Fh,3Fh,3Fh,15h,3Fh,3Fh,3Fh

Data            ends

                END

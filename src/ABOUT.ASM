;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      ABOUT.ASM                       |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   About Screen                    |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC

About           segment public
                assume  cs:About,ds:About,es:Emulate

ScreenIOParams  SIO_ParamStruc <1,About,0,0,offset Screen,seg Screen,1,0,1,1>
GetKeyParams    RK_ParamStruc  <1,Fkey,0,0,0,?,ShowAll,0>

Print           macro   y,x,Str
                gotoxy  y,x
                mov     bx,offset Str
                ScreenIOservice _STRINGPRINT
                endm


AboutInInit     proc    far
                cli
                push    ax ds es
                mov     ax,Emulate
                mov     es,ax
                mov     al,es:[C000]
                mov     cs:KeyPressed,al
                mov     es:[C000],0
                call    DebugKeysOn
                assume  ds:CONio
                mov     ax,CONio
                mov     ds,ax
                mov     SIO_ParamsOfs, offset ScreenIOParams
                mov     SIO_ParamsSeg, seg    ScreenIOParams
                mov     RK_ParamsOfs,  offset GetKeyParams
                mov     RK_ParamsSeg,  seg    GetKeyParams
                pop     es ds ax
                call    UnSetBreaks
                sti
                ret
AboutInInit     endp

KeyPressed      db      0
AboutOutInit    proc    far
                cli
                push    ax es
                mov     ax,Emulate
                mov     es,ax
                mov     al,KeyPressed
                mov     es:[C000],al
                mov     ax,seg T_Iflags
                mov     es,ax
		assume  es:seg T_Iflags
                mov     byte ptr es:T_Iflags,00000010b
                assume  es:Emulate
                pop     es ax
		call    AppleKeysOn
                call    SetBreaks
                ret
AboutOutInit    endp

                assume  cs:About,ds:About,es:Emulate

AboutMainRet:   push    cs
                pop     ds
AboutLoop:      call    ReadKey
                cmp     al,0Ch
                jne     AboutLoop
                call    GoAppleII
                jmp     AboutLoop



Fkey            proc    far
                cmp     al,8
                jne     FkeyRet
                call    GoAppleII
FkeyRet:        ret
Fkey            endp



ShowAll         proc    far
                push    ax bx cx dx si bp ds
                push    cs
                pop     ds
                call    ShowTitle
                call    ShowEmulation
                call    ShowAuthors
                call    ShowDistribute
                call    ShowLicense
                call    ShowFuncKeys
                pop     ds bp si dx cx bx ax
                ret
ShowAll         endp


; -- Draw box --------------------------
; Entry:
;  AH  = Active Flag Bit
;  CX  = HTAB & VTAB
;  BX  = Offset of the strings
;  DL  = Length of the box line - 1
;  DH  = Number of lines - 1
; Destroy:
;  AX,BX,CX,DX
DB_CX           dw      ?
DrawBox:        mov     ax,cx
                add     ax,80 * 2
                mov     cs:DB_CX,ax
                mov     ah,7
                ScreenIOservice _STRINGPRINT
                mov     bx,ScreenIOparams.SP_bx
                dec     dh
                mov     al,dh
                mov     dx,cs:DB_CX
DB_Loop1:       mov     cx,dx
                add     dx,80 * 2
                ScreenIOservice _STRINGPRINT
                dec     al
                jnz     DB_Loop1
                mov     cx,dx
                mov     bx,ScreenIOparams.SP_bx
                ScreenIOservice _STRINGPRINT
                ret



ST_Str          db      '                                  ABOUT APPLER                                  ',0
ShowTitle:      gotoxy  1,0
                mov     ah,1Fh
                mov     bx,offset ST_Str
                ScreenIOservice _STRINGPRINT
                gotoxy  2,0
                xor     ah,ah
                ScreenIOservice _STRINGPRINT
                ret

SE_Str          db      'ÚEmulationÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
SE_Str1         db      1,0Fh,'APPLER',1,7,' emulates:',0
SE_Str2         db      1,0Fh,'ş',1,7,' 65C02 Valid',1,0Fh,' Instructions',0
SE_Str3         db      1,0Fh,'ş',1,7,' APPLE ][',1,0Fh,' Video Modes',0
SE_Str4         db      1,0Fh,'ş',1,7,' APPLE ][',1,0Fh,' Keyboard',0
SE_Str5         db      1,0Fh,'ş',1,7,' APPLE ][',1,0Fh,' Internal Speaker',0
SE_Str6         db      1,0Fh,'ş',1,7,' APPLE ][',1,0Fh,' Floppy Disk Controller',0
SE_Str7         db      1,0Fh,'ş',1,7,' APPLE ][',1,0Fh,' Language Card',0
SE_Str8         db      1,0Fh,'ş',1,7,' APPLE ][',1,0Fh,' Digital Joystick',0
ShowEmulation:  gotoxy  3,0
                mov     bx,offset SE_Str
                mov     dh,10
                call    DrawBox
                print   5,2,SE_Str1
                print   6,3,SE_Str2
                print   7,3,SE_Str3
                print   8,3,SE_Str4
                print   9,3,SE_Str5
                print  10,3,SE_Str6
                print  11,3,SE_Str7
                print  12,3,SE_Str8
                ret



SA_Str          db      'ÚAuthorsÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                      ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SA_Str1         db      1,0Fh,'Emil Dotchevski',0
SA_Str2         db      1,0Fh,'Alexander Patalenski',0
ShowAuthors:    gotoxy  3,40
                mov     bx,offset SA_Str
                mov     dh,6
                call    DrawBox
                print   5,43,SA_Str1
                print   7,57,SA_Str2
                ret


ifndef LICENSE_NAME
SD_Str          db      'ÚDistributionÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                      ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SD_Str1         db      1,0Fh,'FREE:',1,7,' for non-comercial use only',0
else
SD_Str          db      'ÚRegistrationÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                      ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SD_Str1         db      1,0Fh
                db_LICENSE_NAME
                db      0
endif
ShowDistribute: gotoxy  10,40
                mov     bx,offset SD_Str
                mov     dh,3
                call    DrawBox
                print   12,43,SD_Str1
                ret



SL_Str          db      'ÚLicenseÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                                                              ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SL_Str1         db      'This is a Public Domain software: you are licensed to use and distribute',0
SL_Str2         db      'it absolutely free as long as no charge is made and program files are not',0
SL_Str3         db      'modified. Comments and bug reports are welcome.',0
SL_Str4         db      'Emil Dotchevski:       https://github.com/zajo',0
SL_Str5         db      'Alexander Patalenski:  alexp@unforgettable.com',0
SL_Str6         db      1,0Ah,'APPLE ][ FOREVER!',0
ShowLicense:    gotoxy  14,0
                mov     bx,offset SL_Str
                mov     dh,10
                call    DrawBox
                print   16,3,SL_Str1
                print   17,3,SL_Str2
                print   18,3,SL_Str3
                print   20,3,SL_Str4
                print   21,3,SL_Str5
                print   23,60,SL_Str6
                ret



SFK_Str         db      '1       2       3       4       5       '
                db      '6       7       8       9      10       ',0
SFK_FkeysMain   dw      SFK_None,SFK_None,SFK_None,SFK_None,SFK_None
                dw      SFK_None,SFK_None,SFK_None,SFK_Apple,SFK_None
SFK_None        db      '      ',0
SFK_Apple       db      1,1Fh,'Apple ',1,1Fh,0

ShowFuncKeys:   gotoxy  19h,0
                mov     bx,offset SFK_Str
                mov     ah,7
                ScreenIOservice _STRINGPRINT
                gotoxy  19h,1
                xor     si,si
                mov     ah,1Fh
SFK_Loop0:      mov     bx,cs:SFK_FkeysMain[si]
                ScreenIOservice _STRINGPRINT
                add     cx,4
                add     si,2
                cmp     si,20
                jb      SFK_Loop0
                ret

GoAppleII:      push    ax es
		mov     ax,Emulate
                mov     es,ax
                mov     al,C050
                ScreenIOservice _SetScreen
                SwitchToProcess PID_EMULATOR
                pop     es ax
                ret

About           ends

		END

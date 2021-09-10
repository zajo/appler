;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      HELP.ASM                        |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Help Screen                     |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC

Help            segment public
                assume  cs:Help,ds:Help,es:Emulate

ScreenIOParams  SIO_ParamStruc <1,Help,0,0,offset Screen,seg Screen,1,0,1,1>
GetKeyParams    RK_ParamStruc <1,Fkey,0,0,0,?,ShowAll,0>

Print           macro   y,x,Str
                gotoxy  y,x
                mov     bx,offset Str
                ScreenIOservice _STRINGPRINT
                endm


HelpInInit      proc    far
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
                mov     SIO_ParamsSeg, seg ScreenIOParams
                mov     RK_ParamsOfs, offset GetKeyParams
                mov     RK_ParamsSeg, seg GetKeyParams
                pop     es ds ax
                call    UnSetBreaks
                sti
                ret
HelpInInit      endp

KeyPressed      db      0
HelpOutInit     proc    far
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
HelpOutInit     endp

                assume  cs:Help,ds:Help,es:Emulate

HelpMainRet:    push    cs
                pop     ds
HelpLoop:       call    ReadKey
                cmp     al,0Ch
                jne     HelpLoop
                call    GoAppleII
                jmp     HelpLoop


Fkey            proc    far
                cmp     al,9
                jne     FkeyRet
                call    GoAppleII
FkeyRet:        ret
Fkey            endp



ShowAll         proc    far
                push    ax bx cx dx si bp ds es
                push    cs
                pop     ds
                ScreenIOservice _CLEARSCREEN
                call    ShowTitle
                call    ShowKeys
                call    ShowHints
                call    ShowFuncKeys
                pop     es ds bp si dx cx bx ax
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



STi_Str          db      1,3Fh,'                               APPLER HELP SCREEN                               ',0
ShowTitle:      print   1,0,STi_Str
                ret

ST_Str          db      'ÚKeysÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                     ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
ST_Str1         db      1,0Fh,'At any time:',0
ST_Str2         db      1,7,'<Alt+F1>     Debugger',0
ST_Str3         db      1,7,'<Alt+F2>     File Manager',0
ST_Str4         db      1,7,'<Alt+F3>     Disk Manager',0
ST_Str5         db      1,7,'<Alt+F4>     Keyboard Setup',0
ST_Str6         db      1,7,'<Alt+F9>     About Appler',0
ST_Str7         db      1,7,'<Alt+F10>    This Help Srceen',0
ST_Str8         db      1,7,'<Alt+Esc>    DOS Shell',0
ST_Str9         db      1,7,'<Alt+X>      Quit Appler',0
ST_Str10        db      1,0Fh,'While the Apple ][ is running:',0
ST_Str11        db      1,7,'<Ctrl+Del>   Apple ][ Reset',0
ST_Str12        db      1,7,'<F12>        Toggle Realtime Mode',0
ShowKeys:       gotoxy  3,0
                mov     bx,offset ST_Str
                mov     dh,17
                call    DrawBox
                print   5,2,ST_Str1
                print   7,4,ST_Str2
                print   8,4,ST_Str3
                print   9,4,ST_Str4
                print   10,4,ST_Str5
                print   11,4,ST_Str6
                print   12,4,ST_Str7
                print   13,4,ST_Str8
                print   14,4,ST_Str9
                print   16,2,ST_Str10
                print   18,4,ST_Str11
                print   19,4,ST_Str12
                ret

SE_Str          db      'ÚSome HintsÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                      ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SE_Str1         db      1,0Fh,'To boot a disk:',1,7,' Enter Disk Manager,',0
SE_Str2         db      1,7,'highlight the .DSK file you want to',0
SE_Str3         db      1,7,'boot, then press the <F1> key.',0
SE_Str4         db      1,0Fh,'To run a file:',1,7,' Enter File Manager,',0
SE_Str5         db      1,7,'highlight the .APL file you want to',0
SE_Str6         db      1,7,'run, then press the <F1> key.',0
SE_Str7         db      1,0Fh,'To remap a key: ',1,7,'Enter Keyboard Setup',0
SE_Str8         db      1,7,'hit the key you want remapped, then',0
SE_Str9         db      1,7,'pick an ASCII code to assign to it.',0
SE_Str10        db      1,0Fh,'Realtime Mode:',1,7,' When realtime mode is',0
SE_Str11        db      1,7,'ON, the emulator matches the speed',0
SE_Str12        db      1,7,'of a real Apple ][ at 1 MHz. This',0
SE_Str13        db      1,7,'requires at least a 386 CPU, or else',0
SE_Str14        db      1,7,'realtime mode turns OFF, and the',0
SE_Str15        db      1,7,'emulator will likely run faster.',0

ShowHints:      gotoxy  3,40
                mov     bx,offset SE_Str
                mov     dh,20
                call    DrawBox
                print   5,42,SE_Str1
                print   6,42,SE_Str2
                print   7,42,SE_Str3
                print   9,42,SE_Str4
                print   10,42,SE_Str5
                print   11,42,SE_Str6
                print   13,42,SE_Str7
                print   14,42,SE_Str8
                print   15,42,SE_Str9
                print   17,42,SE_Str10
                print   18,42,SE_Str11
                print   19,42,SE_Str12
                print   20,42,SE_Str13
                print   21,42,SE_Str14
                print   22,42,SE_Str15
                ret


SFK_Str         db      '1       2       3       4       5       '
                db      '6       7       8       9      10       ',0
SFK_FkeysMain   dw      SFK_None,SFK_None,SFK_None,SFK_None,SFK_None
                dw      SFK_None,SFK_None,SFK_None,SFK_None,SFK_Apple
SFK_None        db      '      ',0
SFK_Apple       db      1,3Fh,'Apple ',1,3Fh,0

ShowFuncKeys:   gotoxy  19h,0
                mov     bx,offset SFK_Str
                mov     ah,7
                ScreenIOservice _STRINGPRINT
                gotoxy  19h,1
                xor     si,si
                mov     ah,3Fh
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

Help            ends

                END

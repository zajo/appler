;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      KBDSETUP.ASM                    |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Keyboard Setup Utility          |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC

KBDsetup        segment public
                assume  cs:KBDsetup,ds:KBDsetup,es:Keyboard

GetLineParams   GL_ParamStruc  <?,0,1,1,5,0,0,20h,40h,2*80,?,?,0Bh,1,0,GetLineUser>
ScreenIOParams  SIO_ParamStruc <1,KBDsetup,0,0,offset Screen,seg Screen,1,0,1,1>
GetKeyParams    RK_ParamStruc  <1,Fkey,0,0,0,?,ShowAll,0>

KBDSetupInInit  proc    far
                cli
                push    ax ds es
                mov     ax,Emulate
                mov     es,ax
                assume  es:Emulate
                mov     al,es:[C000]
                mov     cs:KeyPressed,al
                mov     es:[C000],0
                assume  ds:CONio
                mov     ax,CONio
                mov     ds,ax
                mov     GL_ParamsOfs,  offset GetLineParams
                mov     GL_ParamsSeg,  seg    GetLineParams
                mov     SIO_ParamsOfs, offset ScreenIOParams
                mov     SIO_ParamsSeg, seg    ScreenIOParams
                mov     RK_ParamsOfs,  offset GetKeyParams
                mov     RK_ParamsSeg,  seg    GetKeyParams
                push    cs
                pop     ds
                assume  ds:KBDsetup
                mov     ax,Keyboard
                mov     es,ax
                assume  es:Keyboard
                mov     ax,OldKeys
                mov     es:k_Table,ax
                pop     es ds ax
                call    UnSetBreaks
                sti
                ret
KBDSetupInInit  endp

KeyPressed      db      0
OldKeys         dw      offset Keyboard:k_KbdSetupTable
KBDSetupOutInit proc    far
                cli
                push    ax ds es
                push    cs
                pop     ds
                mov     ax,Keyboard
                mov     es,ax
                assume  es:Keyboard
                mov     ax,es:k_Table
                mov     OldKeys,ax
                mov     ax,Emulate
                mov     es,ax
                assume  es:Emulate
                mov     al,KeyPressed
                mov     es:[C000],al
                mov     ax,seg T_Iflags
                mov     es,ax
		assume  es:seg T_Iflags
                mov     byte ptr es:T_Iflags,00000010b
                pop     es ds ax
		call    AppleKeysOn
                call    SetBreaks
                ret
KBDSetupOutInit endp

                assume  cs:KBDsetup,ds:KBDsetup,es:Keyboard

KBD_Keys        db      05h,06h,07h,08h,01h,02h,0Ah,18h,0Ch
KBD_Procs       dw      KBD_Left,KBD_Right,KBD_Up,KBD_Down,KBD_Home,KBD_End,KBD_Clear,KBD_Enter,KBD_Esc

KBDsetupRET:    push    cs
                pop     ds
                mov     ax,Keyboard
                mov     es,ax
KBDloop:        mov     cs:ActiveFlags,0000000000001000b
                mov     FkeysFlags,0000111111b
                mov     SA_Active,0
                mov     ShowASCII?,0
                mov     es:k_Table,offset k_KbdSetupTable
                mov     ScreenIOparams.CursorFlag,0
                mov     SA_MesFlag,1
                call    ReadKey
                mov     SA_MesFlag,0
                mov     es:k_Table,offset k_DebugTable
                mov     ShowASCII?,1
                xor     bx,bx
                mov     bl,ah
                mov     SA_Active,bx
                mov     si,es:k_Shifts
                mov     ST_Shifts,si
                mov     cs:ActiveFlags,0000000000010000b
                call    KBD_Home
                xchg    si,bx
                call    get_table_ofs
                mov     bx,es:k_AppleTable[bx]
                mov     bl,es:[si][bx]
                cmp     bl,85h
                ja      KBDloop1
KBDloop0:       mov     al,ST_Pos
                cmp     al,bl
                je      KBDloop1
                call    KBD_Down
                jmp     KBDloop0
KBDloop1:       mov     cx,100h
                call    ReadKey
                mov     di,offset KBD_Keys
                mov     cx,offset KBD_Procs- offset KBD_Keys
                call    CalcCommand
                jc      KBDloop1
                shl     di,1
                call    KBD_Procs[di]
                jnc     KBDloop1
                jmp     KBDloop

KBD_Left:       cmp     ST_Pos,16
                jb      KBD_LeftRet
                sub     ST_Pos,16
                mov     al,ST_Pos
                cmp     al,ST_BegPrint
                jae     KBD_LeftRet
                sub     ST_BegPrint,16
KBD_LeftRet:    clc
                ret

KBD_Right:      cmp     ST_Pos,86h-16
                jnb     KBD_RightRet
                add     ST_Pos,16
                mov     al,ST_Pos
                sub     al,ST_BegPrint
                cmp     al,16*4
                jb      KBD_RightRet
                add     ST_BegPrint,16
KBD_RightRet:   clc
                ret

KBD_Up:         cmp     ST_Pos,0
                jz      KBD_UpRet
                dec     ST_Pos
                mov     al,ST_Pos
                cmp     al,ST_BegPrint
                jae     KBD_UpRet
                sub     ST_BegPrint,16
KBD_UpRet:      clc
                ret

KBD_Down:       cmp     ST_Pos,85h
                jae     KBD_DownRet
                inc     ST_Pos
                mov     al,ST_Pos
                sub     al,ST_BegPrint
                cmp     al,16*4
                jb      KBD_DownRet
                add     ST_BegPrint,16
KBD_DownRet:    clc
                ret

KBD_Home:       mov     ST_Pos,0
                mov     ST_BegPrint,0
                clc
                ret

KBD_End:        mov     ST_Pos,07Fh
                mov     ST_BegPrint,4*16
                clc
                ret

KBD_Clear:      mov     dl,ST_Pos
                mov     ST_Pos,86h
                call    KBD_Enter
                mov     ST_Pos,dl
                ret

KBD_Enter:      mov     bx,ST_Shifts
                call    get_table_ofs
                mov     si,es:k_AppleTable[bx]
                mov     al,ST_Pos
                mov     bx,SA_Active
                cmp     si,offset Keyboard:a_AltTable
                jne     KBD_Enter1
                mov     es:a_CtrlTable[bx],al
KBD_Enter1:     cmp     si,offset Keyboard:a_CtrlTable
                jne     KBD_Enter2
                mov     es:a_AltTable[bx],al
KBD_Enter2:     mov     es:[si][bx],al
KBD_Esc:        stc
                ret



FkeyProcs       dw      Fkey_F1,Fkey_F2,Fkey_F3,Fkey_F4,Fkey_F5
                dw      Fkey_F6,Fkey_F7,Fkey_F8,Fkey_F9,Fkey_F0
FkeysMasks      dw      1b,10b,100b,1000b,10000b,100000b,1000000b,10000000b,100000000b,1000000000b
Fkey            proc    far
                push    ax bx cx dx si di bp ds es
                push    cs
                pop     ds
                mov     bx,Keyboard
                mov     es,bx
                push    [ActiveFlags]
                push    word ptr [ScreenIOparams.CursorFlag]
                push    word ptr [ScreenIOparams.CursorLen]
                push    word ptr [ScreenIOparams.CursorColor]
                push    [FkeysFlags]
                push    word ptr [SA_MesFlag]
                mov     SA_MesFlag,0
                push    es:k_Table
                mov     es:k_Table,offset k_DebugTable
                xor     bx,bx
                mov     bl,al
                shl     bx,1
                mov     ax,FkeysMasks[bx]
                mov     ScreenIOparams.CursorLen,1
                mov     ScreenIOparams.CursorFlag,1
                test    FkeysFlags,ax
                jz      Fkey_Ret
                mov     FkeysFlags,0000001000b
                call    FkeyProcs[bx]
Fkey_Ret:       push    cs
                pop     ds
                mov     bx,Keyboard
                mov     es,bx
                pop     es:k_Table
                pop     word ptr [SA_MesFlag]
                pop     [FkeysFlags]
                pop     word ptr [ScreenIOparams.CursorColor]
                pop     word ptr [ScreenIOparams.CursorLen]
                pop     word ptr [ScreenIOparams.CursorFlag]
                pop     [ActiveFlags]
                pop     es ds bp di si dx cx bx ax
                ret
Fkey            endp


Fkey_F1:        mov     ax,CONio
                mov     es,ax
                assume  es:CONio
                xor     es:DKO_OldBuffFlag,1
                cmp     es:DKO_OldBuffFlag,0
                jnz     Fkey_F1_Ret
                call    ClearBuffer
Fkey_F1_Ret:    ret
                assume  es:Keyboard

Fkey_F2:        call    Prepare4DOS
                mov     dx,offset Filespec
                xor     cx,cx
                mov     ax,3C01h
                int     21h
                jc      Fkey_F2errorNC
                mov     bx,ax
                mov     dx,offset RecognizeBytes
                mov     cx,5
                mov     ah,40h
                int     21h
                jc      Fkey_F2error
                cmp     ax,cx
                jne     Fkey_F2error
                mov     dx,offset SR_KbdParam
                mov     cx,1
                mov     ah,40h
                int     21h
                jc      Fkey_F2error
                mov     cx,CONio
                mov     ds,cx
                mov     dx,offset CONio:DKO_OldBuffFlag
                mov     cx,1
                mov     ah,40h
                int     21h
                jc      Fkey_F2error
                mov     cx,Keyboard
                mov     ds,cx
                mov     dx,offset Keyboard:a_NormalTable
                mov     cx,6 * 54h
                mov     ah,40h
                int     21h
                jc      Fkey_F2error
                cmp     ax,cx
                jne     Fkey_F2error
                mov     ah,3Eh
                int     21h
                mov     cs:GetKeyParams.RK_ErrPtr,offset SMS_Saved
Fkey_F2ret:     call    SOD4eraperP
                ret
Fkey_F2error:   mov     ah,3Eh
                int     21h
Fkey_F2errorNC: mov     cs:GetKeyParams.RK_ErrPtr,offset SMS_ErrorSave
                jmp     Fkey_F2ret


RecognizeBytes  db      0,0FFh,55h,0AAh,0
RecognizeBuffer db      5 dup (0)
Fkey_F3:        call    Prepare4DOS
                mov     dx,offset Filespec
                mov     ax,3D00h
                int     21h
                jc      Fkey_F3errorNC
                mov     bx,ax
                mov     dx,offset RecognizeBuffer
                mov     cx,5
                mov     ah,3Fh
                int     21h
                jc      Fkey_F3error
                cmp     ax,cx
                jne     Fkey_F3error
                push    cs
                pop     es
                mov     si,offset RecognizeBytes
                mov     di,offset RecognizeBuffer
                cld
        rep     cmpsb
                jne     Fkey_F3errorT
                mov     dx,offset SR_KbdParam
                mov     cx,1
                mov     ah,3Fh
                int     21h
                jc      Fkey_F3error
                mov     cx,CONio
                mov     ds,cx
                mov     dx,offset CONio:DKO_OldBuffFlag
                mov     cx,1
                mov     ah,3Fh
                int     21h
                jc      Fkey_F3error
                mov     cx,Keyboard
                mov     ds,cx
                mov     dx,offset Keyboard:a_NormalTable
                mov     cx,6 * 54h
                mov     ah,3Fh
                int     21h
                jc      Fkey_F3error
                cmp     ax,cx
                jne     Fkey_F3error
                mov     ah,3Eh
                int     21h
                call    UpdateKeyboard
                mov     cs:GetKeyParams.RK_ErrPtr,offset SMS_Restored
Fkey_F3ret:     call    SOD4eraperP
                ret
Fkey_F3error:   mov     ah,3Eh
                int     21h
Fkey_F3errorNC: mov     cs:GetKeyParams.RK_ErrPtr,offset SMS_ErrorLoad
                jmp     Fkey_F3ret
Fkey_F3errorT:  mov     ah,3Eh
                int     21h
                mov     cs:GetKeyParams.RK_ErrPtr,offset SMS_Type
                jmp     Fkey_F3ret

Fkey_F4:        call    GoAppleII
                ret

FkeyF5_Keys     db      7,8,5,6,18h,0Ch
FkeyF5_Procs    dw      FkeyF5_Up,FkeyF5_Down,FkeyF5_Left,FkeyF5_Right,FkeyF5_Enter,FkeyF5_Esc
Fkey_F5:        mov     ActiveFlags,1
FkeyF5Loop:     call    ReadKey
                mov     di,offset FkeyF5_Keys
                mov     cx,offset FkeyF5_Procs- offset FkeyF5_Keys
                call    CalcCommand
                jc      FkeyF5Loop
                shl     di,1
                mov     al,SR_KbdParam
                mov     ah,al
                call    FkeyF5_Procs[di]
                mov     SR_KbdParam,al
		call    UpdateKeyboard
                jnc     FkeyF5Loop
                ret

FkeyF5_Up:      and     ah,01100000b
                add     ah,00100000b
                and     ah,01100000b
                and     al,10011111b
                or      al,ah
                clc
                ret

FkeyF5_Down:    and     ah,01100000b
                sub     ah,00100000b
                and     ah,01100000b
                and     al,10011111b
                or      al,ah
                clc
                ret

FkeyF5_Left:    inc     ah
                and     ah,00011111b
                and     al,11100000b
                or      al,ah
                mov     di,offset SR_speeds_v
                mov     cx,10
		xchg    al,ah
                call    CalcCommand
		xchg    al,ah
                jc      FkeyF5_Left
                ret

FkeyF5_Right:   dec     ah
                and     ah,00011111b
                and     al,11100000b
                or      al,ah
                mov     di,offset SR_speeds_v
                mov     cx,10
		xchg    al,ah
                call    CalcCommand
		xchg    al,ah
                jc      FkeyF5_Right
                ret

FkeyF5_Enter:
FkeyF5_Esc:     stc
                ret


UpdateKeyboard  proc    far
                pushf
                push    ax
                mov     al,0ADh                 ; Disable Keyboard
                call    K_SendCommand
                jc      UK_Exit
                mov     al,0F3h
                call    K_SendData
                mov     al,cs:SR_KbdParam
                call    K_SendData
UK_Exit:        mov     al,0AEh                 ; Enable Keyboard
                out     64h,al
                pop     ax
		popf
                ret
UpdateKeyboard  endp


KBD_EXT         db      '.KBD',0
Fkey_F6:        mov     ActiveFlags,0000000000000100b
                mov     FkeysFlags,0000001000b
                mov     GetLineParams.GL_Buffer,offset Filespec
                mov     GetLineParams.GL_Pos,0
                mov     GetLineParams.GL_BegPrint,0
                mov     GetLineParams.GL_MaxLength,99
                mov     GetLineParams.GL_MaxPrint,27
                xor     bx,bx
Seek0_Loop:     cmp     FileSpec[bx],0
                jz      Seek0_Done
                inc     bl
                jmp     Seek0_Loop
Seek0_Done:     mov     GetLineParams.GL_Length,bl
                gotoxy  5,51
                GetLineService _GETLINE
                push    si di
                mov     si,offset KBD_EXT
                mov     di,offset Filespec
                call    AddExt
                pop     di si
                gotoxy  2,0
                mov     GetLineParams.GL_CX,cx
                ret

Fkey_F7:
Fkey_F8:
Fkey_F9:
Fkey_F0:        ret




; *******************************************************************
; **                                                               **
; **                                                               **
; **                        S H O W    A L L                       **
; **                                                               **
; **                                                               **
; *******************************************************************

ActiveFlags     dw      0
ShowAll         proc    far
                cli
                push    ax ds bp
                push    word ptr [ScreenIOparams.CursorColor]
                push    word ptr [ScreenIOparams.CursorLen]
                push    word ptr [ScreenIOparams.CursorFlag]
                push    cs
                pop     ds
                mov     ax,Keyboard
                mov     es,ax
                mov     ScreenIOparams.CursorLen,10
                mov     ScreenIOparams.CursorColor,10h
                mov     ScreenIOparams.CursorFlag,1
                call    ShowRepeat
                call    ShowBuffer
                call    ShowFilespec
                call    ShowAssignment
                call    ShowASCII
                call    ShowFuncKeys
                ScreenIOservice _SHOWLINE
                call    ShowTitle
                call    ShowMessage
                pop     word ptr [ScreenIOparams.CursorFlag]
                pop     word ptr [ScreenIOparams.CursorLen]
                pop     word ptr [ScreenIOparams.CursorColor]
                pop     bp ds ax
                sti
                ret
ShowAll         endp


; -- Draw box --------------------------
; Entry:
;  AH  = Active Flag Bit
;  CX  = HTAB & VTAB
;  BX  = Offset of the strings
;  DL  = Hi-light color
;  DH  = Number of lines - 1
; Destroy:
;  AX,BX,CX,DX
DB_CX           dw      ?
DrawBox:        push    ax
                mov     ax,cx
                add     ax,80 * 2
                mov     cs:DB_CX,ax
                pop     ax
                test    ActiveFlags,ax
                mov     ah,7
                jz      DB_ok1
                mov     ah,dl
DB_ok1:         ScreenIOservice _STRINGPRINT
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


ST_StrX         db      '                              APPLER KEYBOARD SETUP                             ',0
ShowTitle:      push    ax bx cx
                gotoxy  1,0
                mov     ah,5Fh
                mov     bx,offset ST_StrX
                ScreenIOservice _STRINGPRINT
                gotoxy  2,0
                xor     ah,ah
                ScreenIOservice _STRINGPRINT
                pop     cx bx ax
                ret


SR_Str          db      'ÚRepeat SettingsÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                 ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
SR_str1   db      1,7,'Delay:',0
SR_str2   db      1,7,' ms  Speed: ',0
SR_str3   db      1,7,' ch/s',0
SR_delays       dw      d250,d500,d750,d1000
SR_speeds_v     db      0,1,2,4,8,0Ah,0Dh,10h,14h,1Fh
SR_speeds       dw      s300,s267,s240,s200,s150,s100,s092,s075,s050,s020
d250            db      1,0Bh,' 250',0
d500            db      1,0Bh,' 500',0
d750            db      1,0Bh,' 750',0
d1000           db      1,0Bh,'1000',0
s300            db      1,0Bh,'30.0',0
s267            db      1,0Bh,'26.7',0
s240            db      1,0Bh,'24.0',0
s200            db      1,0Bh,'20.0',0
s150            db      1,0Bh,'15.0',0
s100            db      1,0Bh,'10.0',0
s092            db      1,0Bh,' 9.2',0
s075            db      1,0Bh,' 7.5',0
s050            db      1,0Bh,' 5.0',0
s020            db      1,0Bh,' 2.0',0
SR_KbdParam     db      0
ShowRepeat:     push    ax bx cx dx di
                gotoxy  3,0
                mov     bx,offset SR_Str
                mov     dx,30Eh
                mov     ax,0000000000000001b
                call    DrawBox
                gotoxy  5,2
                mov     bx,offset SR_Str1
                ScreenIOservice _STRINGPRINT
                xor     bx,bx
                mov     bl,SR_KbdParam
                shr     bl,5
                shl     bx,1
                mov     bx,SR_delays[bx]
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SR_str2
                ScreenIOservice _STRINGPRINT
                xor     bx,bx
                mov     al,SR_KbdParam
                and     al,00011111b
                push    cx
                mov     di,offset SR_Speeds_v
                mov     cx,10
                call    CalcCommand
                pop     cx
                shl     di,1
                mov     bx,SR_speeds[di]
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SR_str3
                ScreenIOservice _STRINGPRINT
                pop     di dx cx bx ax
                ret


SB_Str          db      'ÚBufferÄÄÄÄ¿ ',0
                db      '³          ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÙ ',0
SB_Enabled      db      1,0Bh,'Enabled',0
SB_Disabled     db      1,0Bh,'Disabled',0
ShowBuffer:     push    ax bx cx dx es
                gotoxy  3,36
                mov     bx,offset SB_Str
                mov     dx,30Eh
                mov     ax,0000000000000010b
                call    DrawBox
                gotoxy  5,38
                mov     ax,CONio
                mov     es,ax
                assume  es:CONio
                test    es:DKO_OldBuffFlag,1
                mov     bx,offset SB_Disabled
                jz      SB_1
                mov     bx,offset SB_Enabled
SB_1:           ScreenIOservice _STRINGPRINT
                pop     es dx cx bx ax
                ret
                assume  es:Keyboard


SF_Str          db      'ÚFilenameÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                             ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
Filespec        db      'APPLER.KBD',100 dup (0)
ShowFilespec:   push    ax bx cx dx
                gotoxy  3,49
                mov     bx,offset SF_Str
                mov     dx,30Eh
                mov     ax,0000000000000100b
                call    DrawBox
                xor     dl,dl
                xchg    Filespec[27],dl
                mov     bx,offset Filespec
                gotoxy  5,51
                mov     ah,0Bh
                ScreenIOservice _STRINGPRINT
                xchg    Filespec[27],dl
                pop     dx cx bx ax
                ret


SA_Str          db      'ÚKeyboard AssignmentÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                                                              ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SA_Message      db      1,0Fh,'Press the key to be changed',0
SA_Keyboard     db      'ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿  ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿',0
                db      '³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³  ³  ³³  ³³  ³³  ³',0
                db      'ÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙ  ÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙ',0
                db      'ÚÄÄÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄÄÄ¿  ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿',0
                db      '³    ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³    ³  ³  ³³  ³³  ³³  ³',0
                db      'ÀÄÄÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀ¿   ³  ÀÄÄÙÀÄÄÙÀÄÄÙ³  ³',0
                db      'ÚÄÄÄÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿³   ³  ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿³  ³',0
                db      '³     ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³   ³  ³  ³³  ³³  ³³  ³',0
                db      'ÀÄÄÄÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÄÙ  ÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙ',0
                db      'ÚÄÄÄÄÄÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄÄÄÄÄÄÄÄ¿  ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿ÚÄÄ¿',0
                db      '³       ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³  ³³         ³  ³  ³³  ³³  ³³  ³',0
                db      'ÀÄÄÄÄÄÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÙÀÄÄÄÄÄÄÄÄÄÙ  ÀÄÄÙÀÄÄÙÀÄÄÙ³  ³',0
                db      'ÚÄÄÄÄ¿       ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿        ÚÄÄÄÄ¿  ÚÄÄÄÄÄÄ¿ÚÄÄ¿³  ³',0
                db      '³    ³       ³                               ³        ³    ³  ³      ³³  ³³  ³',0
                db      'ÀÄÄÄÄÙ       ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ        ÀÄÄÄÄÙ  ÀÄÄÄÄÄÄÙÀÄÄÙÀÄÄÙ',0
SA_SpcProcs     dw      SAS_Enter,SAS_Ctrl,SAS_Lshift,SAS_Div,SAS_Rshift,SAS_Caps,SAS_Num
SA_TblPtr       dw      ?
SA_Active       dw      0
SA_MesFlag      db      1
ShowAssignment: push    ax bx cx dx si di
                mov     bx,es:k_Shifts
                call    get_table_ofs
                mov     bx,es:k_AppleTable[bx]
                mov     SA_TblPtr,bx
                gotoxy  7,0
                mov     bx,offset SA_Str
                mov     dx,110Eh
                mov     ax,0000000000001000b
                call    DrawBox
                mov     bx,offset SA_Keyboard
                gotoxy  9,1
                mov     dx,15
                mov     ah,7
SA_Loop1:       ScreenIOservice _STRINGPRINT
                add     cx,2*2
                add     bx,79
                dec     dx
                jnz     SA_Loop1
                mov     bx,offset SA_Message
                gotoxy  8,51
                cmp     SA_MesFlag,0
                jz      SA_Dont1
                ScreenIOservice _STRINGPRINT
SA_Dont1:       mov     si,53h
SA_Loop2:       mov     al,SA_Y[si]
                or      al,al
                jz      SA_Next
                dec     al
                jz      SA_Special
                mov     ah,80 * 2
                mul     ah
                mov     cx,ax
                xor     ax,ax
                mov     al,SA_X[si]
                add     cx,ax
                add     cx,ax
SA_SpecialRet:  mov     bx,SA_TblPtr
                mov     bl,es:[bx][si]
                cmp     bl,85h
                ja      SA_Next
                xor     bh,bh
                add     cx,81*2
                cmp     bl,20h
                mov     ax,0B00h+' '
                jae     SA_NoCtrl
                mov     al,'^'
SA_NoCtrl:      ScreenIOservice _SYMBPRINT
                mov     al,SA_Table[bx]
                ScreenIOservice _SYMBPRINT
SA_Next:        dec     si
                jnz     SA_Loop2
                jmp     SA_Ret

SA_Special:     xor     bx,bx
                mov     bl,SA_X[si]
                shl     bx,1
                mov     ah,7
                call    SA_SpcProcs[bx]
                jmp     SA_SpecialRet

SA_Ret:         pop     di si dx cx bx ax
                ret

SAS_Enter:      mov     bx,SA_TblPtr
                mov     bl,es:[bx][si]
                xor     bh,bh
                gotoxy  21,76
                cmp     bl,20h
                mov     ax,0B00h+' '
                jae     SASE_NoCtrl
                mov     al,'^'
SASE_NoCtrl:    ScreenIOservice _SYMBPRINT
                mov     al,SA_Table[bx]
                ScreenIOservice _SYMBPRINT
                gotoxy  12,56
                ret

SAS_CtrlStr     db      'Ctrl',0
SAS_Ctrl:       gotoxy  22,2
                mov     bx,offset SAS_CtrlStr
                test    es:k_Shifts,1
                mov     ah,7
                jz      SAS_Ctrl1
                mov     ah,0Fh
SAS_Ctrl1:      ScreenIOservice _STRINGPRINT
                gotoxy  22,56
                ScreenIOservice _STRINGPRINT
                ret

SAS_ShiftStr    db      'Shift',0
SAS_Lshift:     gotoxy  19,3
                mov     bx,offset SAS_ShiftStr
                test    es:k_Shifts,M_LEFT_SHIFT or M_RIGHT_SHIFT
                mov     ah,7
                jz      SAS_LS1
                mov     ah,0Fh
SAS_LS1:        ScreenIOservice _STRINGPRINT
                ret

SAS_Rshift:     gotoxy  19,53
                mov     bx,offset SAS_ShiftStr
                test    es:k_Shifts,M_LEFT_SHIFT or M_RIGHT_SHIFT
                mov     ah,7
                jz      SAS_RS1
                mov     ah,0Fh
SAS_RS1:        ScreenIOservice _STRINGPRINT
                ret

SAS_CapsStr     db      'Caps',0
SAS_Caps:       gotoxy  16,2
                mov     bx,offset SAS_CapsStr
                test    es:k_Shifts,M_CAPS_LOCK
                mov     ah,7
                jz      SAS_Caps1
                mov     ah,0Fh
SAS_Caps1:      ScreenIOservice _STRINGPRINT
                ret

SAS_NumStr      db      'NL',0
SAS_Num:        gotoxy  10,64
                mov     bx,offset SAS_NumStr
                test    es:k_Shifts,M_NUM_LOCK
                mov     ah,7
                jz      SAS_Num1
                mov     ah,0Fh
SAS_Num1:       ScreenIOservice _STRINGPRINT
                ret

SAS_Div:        mov     bx,SA_TblPtr
                mov     bl,es:[bx][si]
                xor     bh,bh
                gotoxy  10,68
                cmp     bl,20h
                mov     ax,0B00h+' '
                jae     SASD_NoCtrl
                mov     al,'^'
SASD_NoCtrl:    ScreenIOservice _SYMBPRINT
                mov     al,SA_Table[bx]
                ScreenIOservice _SYMBPRINT
                gotoxy  18,46
                ret


;                        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
SA_X            db       0,01,05,09,13,17,21,25,29,33,37,41,45,49,57, 2 ; 00
                db      07,11,15,19,23,27,31,35,39,43,47,51, 0, 1,08,12 ; 10
                db      16,20,24,28,32,36,40,44,48,52, 2,53,10,14,18,22 ; 20
                db      26,30,34,38,42, 3, 4,71, 0,28, 5, 0, 0, 0, 0, 0 ; 30
                db       0, 0, 0, 0, 0, 6, 0,63,67,71,75,63,67,71,75,63 ; 40
                db      67,71,65,71                                     ; 50

;                        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
SA_Y            db       0,09,09,09,09,09,09,09,09,09,09,09,09,09,09,12 ; 00
                db      12,12,12,12,12,12,12,12,12,12,12,12, 1, 1,15,15 ; 10
                db      15,15,15,15,15,15,15,15,15,15, 1,09,18,18,18,18 ; 20
                db      18,18,18,18,18, 1, 1,09, 0,21, 1, 0, 0, 0, 0, 0 ; 30
                db       0, 0, 0, 0, 0, 1, 0,12,12,12,09,15,15,15,14,18 ; 40
                db      18,18,21,21                                     ; 50

;                        0123456789ABCDEF0123456789ABCDEF
SA_Table        db      '@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_' ; 00
                db      'ú!"#$%&''()*+,-./0123456789:;<=>?'; 20
                db      '@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_' ; 40
                db      '`abcdefghijklmnopqrstuvwxyz{|}~±' ; 60
                db      1,2,1Bh,1Ah,18h,19h                ; 80


ST_Str          db      'ÚÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³            ³            ³            ³            ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
ST_Str1         db      1,0Eh,'³',1,7,' ASCII Char ',1,0Eh,'³',1,7,' ASCII Char ',1,0Eh,'³',1,7,' ASCII Char ',1,0Eh,'³',1,7,' ASCII Char ',1,0Eh,'³',0
ST_Str2         db      1,0Eh,'³',1,7,' ÄÄÄÄÄ ÄÄÄÄ ',1,0Eh,'³',1,7,' ÄÄÄÄÄ ÄÄÄÄ ',1,0Eh,'³',1,7,' ÄÄÄÄÄ ÄÄÄÄ ',1,0Eh,'³',1,7,' ÄÄÄÄÄ ÄÄÄÄ ',1,0Eh,'³',0
ST_Mes0         db      1,2Fh,'                                                   ',0
ST_Mes1         db      1,2Fh,'Select new char to assign to <',0
ST_Mes2         db      1,2Fh,'>',0

ST_ShiftTable   dw      ST_None
                dw      ST_Ctrl
                dw      ST_Ctrl
                dw      ST_Caps
                dw      ST_CapsShift
                dw      ST_Shift
                dw      ST_Num
ST_None         db      0
ST_Ctrl         db      'Ctrl+',0
ST_Shift        db      'Shift+',0
ST_Caps         db      'Caps+',0
ST_CapsShift    db      'Caps+Shift+',0
ST_Num          db      'Num+',0

ShowASCII?      db      0
ST_Shifts       dw      0
ST_BegPrint     db      0
ST_Pos          db      0
ShowASCII:      push    ax bx cx dx si di
                cmp     ShowASCII?,0
                jnz     ST_Go
                jmp     ST_Ret1
ST_Go:          mov     FkeysFlags,0000001000b
                gotoxy  4,14
                mov     bx,offset ST_Str
                mov     dx,130Eh
                mov     ax,0000000000010000b
                call    DrawBox
                gotoxy  5,14
                mov     bx,offset ST_Str1
                ScreenIOservice _STRINGPRINT
                gotoxy  6,14
                mov     bx,offset ST_Str2
                ScreenIOservice _STRINGPRINT
                gotoxy  7,18
                mov     si,cx
                mov     di,cx
                xor     bx,bx
                mov     bl,ST_BegPrint
                mov     dl,4
ST_Loop0:       mov     dh,16
ST_Loop:        mov     al,bl
                cmp     al,85h
                ja      ST_Ret
                mov     ah,7
                ScreenIOservice _BYTEPRINT
                add     cx,6
                cmp     bl,20h
                mov     al,' '
                jae     ST_NoCtrl
                mov     al,'^'
ST_NoCtrl:      mov     ah,0Fh
                ScreenIOservice _SYMBPRINT
                mov     al,SA_Table[bx]
                ScreenIOservice _SYMBPRINT
                cmp     bl,ST_Pos
                je      ST_ShowCursor
ST_ShowCursorR: inc     bx
                add     si,80*2
                mov     cx,si
                dec     dh
                jnz     ST_Loop
                add     di,26
                mov     si,di
                mov     cx,di
                dec     dl
                jnz     ST_Loop0
ST_Ret:         gotoxy  23,15
                mov     bx,offset ST_Mes0
                ScreenIOservice _STRINGPRINT
                gotoxy  23,15
                mov     bx,offset ST_Mes1
                ScreenIOservice _STRINGPRINT
                mov     bx,ST_Shifts
                call    get_table_ofs
                mov     bx,ST_ShiftTable[bx]
                mov     ah,2Eh
                ScreenIOservice _STRINGPRINT
                mov     bx,SA_Active
                mov     al,ST_Table[bx]
                cmp     al,20h
                jbe     ST_Special
                ScreenIOservice _SYMBPRINT
ST_SpecRet:     mov     bx,offset ST_Mes2
                ScreenIOservice _STRINGPRINT
ST_Ret1:        pop     di si dx cx bx ax
                ret

ST_ShowCursor:  push    cx
                sub     cx,9*2
                ScreenIOservice _CALCXY
                mov     cs:ScreenIOparams.CursorColor,40h
                ScreenIOservice _SHOWCURSOR
                pop     cx
                jmp     ST_ShowCursorR

ST_Special:     xor     bx,bx
                mov     bl,al
                shl     bx,1
                mov     bx,ST_Specials[bx]
                ScreenIOservice _STRINGPRINT
                jmp     ST_SpecRet

ST_Specials     dw      STS_Esc,STS_BS,STS_Tab,STS_Enter,STS_Space,STS_Num
                dw      STS_Home,STS_Up,STS_PgUp,STS_Left,STS_Cntr,STS_Right
                dw      STS_End,STS_Down,STS_PgDn,STS_Ins,STS_Del
STS_Esc         db      'Esc',0
STS_BS          db      'BackSpace',0
STS_Tab         db      'Tab',0
STS_Enter       db      'Enter',0
STS_Space       db      'Space',0
STS_Num         db      'Num',0
STS_Home        db      'Home',0
STS_Up          db      'Up',0
STS_PgUp        db      'PgUp',0
STS_Left        db      'Left',0
STS_Cntr        db      'Center',0
STS_Right       db      'Right',0
STS_End         db      'End',0
STS_Down        db      'Down',0
STS_PgDn        db      'PgDn',0
STS_Ins         db      'Ins',0
STS_Del         db      'Del',0

ST_Table        db      0,0,'1234567890-=',1
                db      2,'QWERTYUIOP[]',3
                db      0,'ASDFGHJKL;''`'
                db      0,'\ZXCVBNM,./',0,'*'
                db      0,4,0,0,0,0,0,0,0,0,0,0,0
                db      5,0,6,7,8,'-',9,10,11,'+',12,13,14,15,16



SFK_Str         db      '1       2       3       4       5       '
                db      '6       7       8       9      10       ',0
FkeysFlags      dw      0000111111b
SFK_FkeysMain   dw      SFK_Buffer, SFK_Save,   SFK_Load,     SFK_Cont,    SFK_Repeat
                dw      SFK_Name  , SFK_None  , SFK_None  ,   SFK_None,    SFK_None
SFK_None        db      '      ',0
SFK_Cont        db      'Apple ',0
SFK_Load        db      'Load  ',0
SFK_Save        db      'Save  ',0
SFK_Repeat      db      'Repeat',0
SFK_Buffer      db      'Buffer',0
SFK_Assign      db      'Assign',0
SFK_Name        db      'Name  ',0

ShowFuncKeys:   push    ax bx cx dx si
                gotoxy  19h,0
                mov     bx,offset SFK_Str
                mov     ah,7
                ScreenIOservice _STRINGPRINT
                gotoxy  19h,1
                xor     si,si
                mov     dx,cs:FkeysFlags
SFK_Loop0:      shr     dx,1
                mov     ah,58h
                jnc     SFK_Next0
                mov     ah,5Fh
SFK_Next0:      mov     bx,cs:SFK_FkeysMain[si]
                ScreenIOservice _STRINGPRINT
                add     cx,4
                add     si,2
                cmp     si,20
                jb      SFK_Loop0
                pop     si dx cx bx ax
                ret



SMS_Restored    db      ' Keyboard setup successfully restored',0
SMS_Saved       db      '    Keyboard setup successfully saved',0
SMS_ErrorLoad   db      1,0Ch,'       Error restoring keyboard setup',0
SMS_ErrorSave   db      1,0Ch,'          Error saving keyboard setup',0
SMS_Type        db      1,0Ch,'This file isn''t a keyboard setup file',0
ShowMessage:    cmp     GetKeyParams.RK_ErrPtr,0
                jz      SMS_Ret
                push    ax bx cx dx
                mov     bx,GetKeyParams.RK_ErrPtr
                mov     ah,0Ah
                gotoxy  8,41
                ScreenIOservice _STRINGPRINT
                pop     dx cx bx ax
SMS_Ret:        ret




                assume  es:Emulate

Upcase:         cmp     al,'A'
                jb      UPCSret
                cmp     al,'Z'
                ja      UPCSret
                or      al,20h
UPCSret:        ret

CalcCommand:    push    ax bx cx es             ; Returns number of a command
                push    cs                      ; Input:
                pop     es                      ;   di -> offset Commands
                call    Upcase                  ;   al -> search command
                cld                             ;   cx -> commands count
                mov     bx,di
                repne   scasb                   ; Output:
                stc                             ;   di <- Number of the command
                jne     CC_end                  ;   cf <- 1 if not found
                sub     di,bx
                dec     di
                clc
CC_end:         pop     es cx bx ax
                ret



; -- Hook INT 24h ----------------------

OldFlags        dw      ?
OldFkeys        dw      ?
Prepare4DOS:    saveall
                xor     ax,ax
                xchg    ax,cs:ActiveFlags
                mov     cs:OldFlags,ax
                xor     ax,ax
                xchg    ax,cs:FkeysFlags
                mov     cs:OldFkeys,ax
                call    ShowAll
                ScreenIOservice _SHOWSCREEN
                call    far ptr SystemTINI
                restoreall
                ret



; -- Unhook INT 24h --------------------

SOD4eraperP:    saveall
                mov     ax,cs:OldFlags
                mov     cs:ActiveFlags,ax
                mov     ax,cs:OldFkeys
                mov     cs:FkeysFlags,ax
                mov     ax,Emulate
                mov     es,ax
                mov     byte ptr [C000],0
                call    far ptr SystemINIT
                restoreall
                ret


GetLineUser     proc    far
                ret
GetLineUser     endp


GoAppleII:      push    ax bx es
                call    ShowAll
                ScreenIOservice _SHOWSCREEN
		mov     ax,Emulate
                mov     es,ax
                mov     al,C050
                ScreenIOservice _SetScreen
                xor     bx,bx
                xchg    bx,ActiveFlags
                SwitchToProcess PID_EMULATOR
                mov     ActiveFlags,bx
                pop     es bx ax
                ret


KBDsetup        ends

		END

;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      DEBUG.ASM                       |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Appler Debugger                 |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC
                include FM.INC

G_COMMAND_ENTRY =       00h
G_NewA          =       01h
G_NewX          =       02h
G_NewY          =       03h
G_NewS          =       04h
G_NewP          =       05h
G_NewPC         =       06h
G_Registers     =       07h
G_MiniAsm       =       08h
G_EditB         =       09h
G_EditA         =       0Ah
G_Disasm        =       0Bh
G_DumpB         =       0Ch
G_DumpA         =       0Dh
G_Limits        =       0Eh
G_Find          =       0Fh
G_Copy          =       10h
G_Compare       =       11h
G_Breaks        =       12h
G_Go            =       13h
G_LoadLab       =       14h
G_SaveLab       =       15h
G_DefineLab     =       16h
G_LabList       =       17h
G_DelLab        =       18h
G_LabOnOff      =       19h
G_SwapOnOff     =       1Ah
G_Calculate     =       1Bh
G_ResetApple    =       1Ch
G_MoveHelp      =       1Dh
G_PrintDump     =       1Eh
G_PrintAssembler =      1Fh

Debug           segment public
                assume  DS:Apple,ES:Emulate,CS:Debug,SS:Data

GetLineBuf      db      100 dup (0)

GetLineParams   GL_ParamStruc  <GetLineBuf,0,0,0,0,0,0,2,4,0,?,?,0,1,1,GetLineUser,?,?,?,?>
ScreenIOParams  SIO_ParamStruc <1,Debug,0,0,offset Screen,seg Screen,1,0,1,1>
GetKeyParams    RK_ParamStruc  <1,GK_Fkey,1,Alt_Key,0,T_WaitKey,ShowAll,offset FirstMsg>

DebugOutInit    proc    far
                cli
                push    ax ds es
                mov     ax,Apple
                mov     ds,ax
                mov     ax,Emulate
                mov     es,ax
                mov     al,ds:[0C000h]
                mov     es:[C000],al
                call    AppleKeysOn
                call    SetRegisters
                pop     es ds ax
                ret
DebugOutInit    endp


DebugInInit     proc    far
                cli
                push    ax cx ds es
                mov     ax,Apple
                mov     ds,ax
                mov     ax,Emulate
                mov     es,ax
                xor     al,al
                xchg    al,es:C000
                mov     ds:[0C000h],al
                call    GetRegisters
                assume  ds:CONio
                mov     ax,CONio
                mov     ds,ax
                mov     GL_ParamsOfs,  offset GetLineParams
                mov     GL_ParamsSeg,  seg    GetLineParams
                mov     SIO_ParamsOfs, offset ScreenIOParams
                mov     SIO_ParamsSeg, seg    ScreenIOParams
                mov     RK_ParamsOfs,  offset GetKeyParams
                mov     RK_ParamsSeg,  seg    GetKeyParams
                call    DebugKeysOn
                call    UnsetBreaks
                cmp     cs:ViewFlag,0
                jz      DII_Ret
                mov     ah,0Fh
                int     10h
                cmp     al,3
                jne     DII_Ret
                mov     al,C050
                ScreenIOservice _SetScreen
DII_Ret:        pop     es ds cx ax
                sti
                ret
DebugInInit     endp


                assume  DS:Apple,ES:Emulate,CS:Debug

GoWhere?        dw      G_COMMAND_ENTRY
ShowAll?        db      1
DebugMainRet:   call    DebugInit
BigLoop:        mov     ch,cs:GetLineParams.GL_BegPrint
                mov     cl,cs:GetLineParams.GL_Pos
                mov     di,cs:GoWhere?
                shl     di,1
                mov     cs:ShowAll?,1
                mov     cs:GoWhere?,G_COMMAND_ENTRY
                push    ds es
                call    cs:CmndAddress[di]
                pop     es ds
                cmp     cs:ShowAll?,0
                jz      BL_DontShowAll
                mov     cs:SM_Dec?,1
                call    ShowAll
                mov     cs:SM_Dec?,0
                mov     cs:GetLineParams.GL_Pos,cl
                mov     cs:GetLineParams.GL_BegPrint,ch
BL_DontShowAll: jmp     BigLoop

CommandEntry:   mov     cs:GetLineParams.GL_Color,0Bh
                mov     cs:GetLineParams.GL_Error,  offset UnknownCmd
                mov     cs:GetLineParams.GL_BegScan,offset MainCommands
                mov     cs:GetLineParams.GL_ENDScan,offset ENDScan1
                mov     cs:ActiveFlags,0000000000000001b
                mov     cs:ShowAllNumber,0
                mov     cs:GetLineParams.GL_GS_SpcFl,1
                cmp     cs:MinHelpPtr,8
                je      CE_01
                mov     ax,8
                mov     bx,42
                call    SH_Choose
CE_01:          gotoxy  17,1
                GetLineService _GETLINE
                jc      CE_Ret0
                GetLineService _GetCommand
                jc      CommandEntry
                inc     di
                mov     cs:GoWhere?,di
                mov     cs:ShowAll?,0
                jmp     CE_Ret
CE_Ret0:        GetLineService _GL_CLRBUFF
CE_Ret:         ret


CmndAddress     dw      CommandEntry
                dw      NewA, NewX, NewY, NewS, NewP, NewPC, Registers
                dw      MiniAsm, EditB, EditA, Disasm, DumpB, DumpA
                dw      Limits, Find, Copy, Compare, Breaks, Go
                dw      LoadLab, SaveLab
                dw      DefineLab, LabList, DelLab, LabOnOff, SwapOnOff
                dw      Calculate, ResetApple, MoveHelp
                dw      PrintDump,PrintAssembler,SoundOnOff
                dw      RecordStart,RecordStop,RecordPlay
                dw      LoadRec, SaveRec



; *******************************************************************
; **                                                               **
; **                                                               **
; **                       COMMANDS ROUTINES                       **
; **                                                               **
; **                                                               **
; *******************************************************************


; -- Registers change commands ---------

NewA:           mov     di,0
                jmp     RegModify
NewX:           mov     di,1
                jmp     RegModify
NewY:           mov     di,2
                jmp     RegModify
NewS:           mov     di,3
                jmp     RegModify
NewP:           mov     di,4
                jmp     RegModify
NewPC:          mov     di,5
                jmp     RegModify

REG_StoreCX     dw      0
REG_Current     dw      0
REG_CurrentSVD  dw      0
REG_CH          db      3
REG_Subrt       dw      REG_Flags, REG_A, REG_X, REG_Y, REG_P, REG_S, REG_PC

Registers:      mov     cs:ScreenIOparams.CursorColor,40h
                mov     cs:ShowAllNumber,4
                mov     ax,77
                mov     bx,77
                call    SH_Choose
                mov     ax,cs:REG_CurrentSVD
                mov     cs:REG_Current,ax
                mov     ch,cs:REG_CH
                mov     cs:ActiveFlags,0000000000000100b
REG_Loop:       mov     bx,cs:REG_Current
                shl     bx,1
                call    cs:REG_Subrt[bx]
                or      al,al
                jz      REG_Loop
                mov     cs:REG_CH,ch
                mov     ax,cs:REG_Current
                mov     cs:REG_CurrentSVD,ax
                GetLineService _GL_ClrBuff
                ret


REG_A:          lea     bx,cs:Regs.A
                clc
                jmp     RegsEdit

REG_X:          lea     bx,cs:Regs.X
                clc
                jmp     RegsEdit

REG_Y:          lea     bx,cs:Regs.Y
                clc
                jmp     RegsEdit

REG_P:          lea     bx,cs:Regs.P
                clc
                jmp     RegsEdit

REG_S:          lea     bx,cs:Regs.S
                clc
                jmp     RegsEdit

REG_PC:         lea     bx,cs:Regs.PC
                stc
                jmp     RegsEdit


RF_Commands     db      07h,08h,05h,06h,20h
                db      18h,0Ch
RF_ComSubrt     dw      REG_Up, REG_Down, RF_Left,RF_Right,RF_Flip
                dw      REG_Enter,REG_Esc
RF_CL           db      24h
RF_BL           db      10000000b
REG_Flags:      mov     cl,cs:RF_CL
                mov     bl,cs:RF_BL
                mov     cs:ScreenIOparams.CursorLen,1
RF_Loop0:       call    ReadKey
                push    cx
                mov     di,offset RF_Commands
                mov     cx,offset RF_ComSubrt - offset RF_Commands
                call    CalcCommand
                pop     cx
                jc      RF_Loop0
                shl     di,1
                call    word ptr cs:RF_ComSubrt[di]
                jnc     RF_Loop0
                mov     cs:RF_BL,bl
                mov     cs:RF_CL,cl
                ret

RF_Left:        rol     bl,1
                dec     cl
                cmp     cl,24h
                jae     RF_Lret
                mov     cl,2Bh
RF_Lret:        clc
                ret

RF_Right:       ror     bl,1
                inc     cl
                cmp     cl,2Bh
                jbe     RF_Rret
                mov     cl,24h
RF_Rret:        clc
                ret

RF_Flip:        xor     cs:Regs.P,bl
                ret



RE_Commands     db      '0123456789abcdef'
                db      07h,08h,18h,0Ch
RE_ComSubrt     dw      RE_Num,RE_Num,RE_Num,RE_Num,RE_Num,RE_Num,RE_Num,RE_Num
                dw      RE_Num,RE_Num,RE_Num,RE_Num,RE_Num,RE_Num,RE_Num,RE_Num
                dw      REG_Up, REG_Down,REG_Enter,REG_Esc
RE_FirstTime?   db      1
RegsEdit:       mov     cs:ScreenIOparams.CursorLen,4
                mov     dl,0
                jnc     RE_ok0
                inc     dl
                mov     cs:ScreenIOparams.CursorLen,6
RE_ok0:         mov     cl,39
RE_Loop0:       call    ReadKey
                push    cx
                mov     di,offset RE_Commands
                mov     cx,offset RE_ComSubrt - offset RE_Commands
                call    CalcCommand
                pop     cx
                jc      RE_Loop0
                shl     di,1
                call    word ptr cs:RE_ComSubrt[di]
                jnc     RE_Loop0
                ret

RE_Num:         shr     di,1
                mov     ax,di
                or      dl,dl
                jnz     RE_NumWord
                cmp     cs:RE_FirstTime?,0
                jz      RE_NumByte_1
                mov     byte ptr cs:[bx],0
RE_NumByte_1:   shl     byte ptr cs:[bx],4
                or      byte ptr cs:[bx],al
                jmp     RE_NumRet
RE_NumWord:     call    StopAnimate
                cmp     cs:RE_FirstTime?,0
                jz      RE_NumWord_1
                mov     word ptr cs:[bx],0
RE_NumWord_1:   shl     word ptr cs:[bx],4
                or      word ptr cs:[bx],ax
RE_NumRet:      clc
                mov     cs:RE_FirstTime?,0
                ret



REG_Up:         dec     cs:REG_Current
                jns     REG_UpRet
                mov     cs:REG_Current,6
REG_UpRet:      mov     ax,cs:REG_Current
                mov     ch,al
                add     ch,3
                xor     al,al
                stc
                mov     cs:RE_FirstTime?,1
                ret

REG_Enter:
REG_Down:       inc     cs:REG_Current
                cmp     cs:REG_Current,6
                jbe     REG_DownRet
                mov     cs:REG_Current,0
REG_DownRet:    mov     ax,cs:REG_Current
                mov     ch,al
                add     ch,3
                xor     al,al
                stc
                mov     cs:RE_FirstTime?,1
                ret

REG_Esc:        mov     cs:ScreenIOparams.CursorLen,1
                mov     al,0FFh
                stc
                mov     cs:RE_FirstTime?,1
                ret




R_StoreCX       dw      ?
RegModify:      GetLineService _GL_GetSymb
                or      al,al
                jz      R_Error4
                cmp     al,'='
                jne     R_Error3
                mov     cs:R_StoreCX,cx
                call    GetAddress
                cmp     di,5
                jne     R_2
                mov     cs:Regs.PC,ax
                GetLineService _GL_ClrBuff
                ret
R_2:            cmp     ah,0
                jnz     R_Error2
                mov     byte ptr cs:Regs.[di],al
                GetLineService _GL_ClrBuff
                ret
R_Error2:       mov     cs:GetKeyParams.RK_ErrPtr,offset IllegalNum
                mov     cx,cs:R_StoreCX
                inc     cl
                ret
R_Error4:       inc     cl
R_Error3:       mov     cs:GetKeyParams.RK_ErrPtr,offset EqualMess
                ret




; -- Assembler -------------------------

BuffDisasm:     test    cs:Mini_Flag,1
                jz      BD_ret
                push    cx si
                mov     cs:CalcFlag,0
                mov     si,cs:AssembAdr
                GetLineService _GL_ClrBuff
                mov     cs:ScreenIOparams.SP_BufFlag,1
                gotoxy  1Ah,2                   ; Unvisible
                call    OneInstr
                mov     cs:ScreenIOparams.SP_BufFlag,0
                mov     cs:GetLineParams.GL_Pos,0
                mov     cs:GetLineParams.GL_BegPrint,0
                pop     si cx
BD_ret:         ret

MA_StoreCX      dw      ?
MA_il           db      3 dup (?)
MA_ad           dw      3 dup (?)
MINI_Instr      dw      ?
Mini_Flag       db      0

MiniAsm:        GetLineService _GL_GetSymb
                dec     cl
                or      al,al
                jz      MINI111
                call    GetAddress
                mov     cs:AssembAdr,ax
MINI111:        mov     cs:GetLineParams.GL_MaxPrint,0Eh
                mov     cs:GetLineParams.GL_Color,1Bh
                mov     cs:GetLineParams.GL_Error,offset BadInstr
                mov     cs:GetLineParams.GL_BegScan,offset AsmInstr
                mov     cs:GetLineParams.GL_ENDScan,offset ENDScan2
                call    StopAnimate
                mov     cs:FkeysBuffer[1*size FkeyStruc].FkeyFlag,0
                call    ShowPrevIns
                mov     cs:ShowAllNumber,3
                mov     ax,52
                mov     bx,52
                call    SH_Choose
                mov     byte ptr cs:Mini_Flag,1
                mov     cs:ActiveFlags,0000000000000010b

MINI00:         call    BuffDisasm
MINI0001:       gotoxy  4,11h
                mov     cs:ScreenIOParams.CursorLen,1
                GetLineService _GetLine
                jnc     MINI0002
                jmp     MINIret
MINI0002:       GetLineService _GetCommand
                jc      MINI0001
                mov     cs:MINI_instr,di
                mov     si,cs:AssembAdr
                xor     di,di
MINI000:        mov     al,[si]
                xor     bx,bx
                mov     bl,al
                mov     al,cs:InstrLongTbl[bx]
                and     al,00000011b
                mov     cs:MA_il[di],al
                mov     bx,di
                shl     bx,1
                mov     cs:MA_ad[bx],si
                xor     bx,bx
                mov     bl,al
                add     si,bx
                inc     di
                cmp     di,3
                jb      MINI000

                call    MA_Assemble
                dec     cl
                mov     cs:GetLineParams.GL_Pos,cl
                mov     cs:GetLineParams.GL_BegPrint,ch
                jc      MINI0001

                xor     di,di
                xor     ax,ax
                sub     bx,cs:AssembAdr
MINI_loop0:     add     al,cs:MA_il[di]
                inc     di
                cmp     bl,al
                je      MINI_ok1
                ja      MINI_loop0
                xor     ah,ah
                mov     bh,ah
                sub     ax,bx
                shl     di,1
                mov     bx,cs:MA_ad[di]
                sub     bx,ax
MINI_loop1:     mov     byte ptr [bx],0EAh
                inc     bx
                dec     ax
                jnz     MINI_Loop1

MINI_ok1:       call    DOWN
                call    ShowProgram
                jmp     MINI00

MINIret:        call    InitGetLine
                mov     byte ptr cs:Mini_Flag,0
                mov     cs:FkeysBuffer[1*size FkeyStruc].FkeyFlag,1
                GetLineService _GL_ClrBuff
                ret

MA_Assemble:    mov     dh,byte ptr cs:MINI_Instr
                mov     dl,12
                mov     al,dh
                mul     dl
                mov     bx,ax
                xor     dl,dl
                mov     cl,cs:GetLineParams.GL_Pos
                mov     ch,cs:GetLineParams.GL_BegPrint
                mov     cs:MA_StoreCX,cx
                GetLineService _GL_GetSymb
                or      al,al
                jz      MA_OkAdrs
                cmp     al,'#'
                je      MA_Direct
                cmp     al,'('
                jne     MA_Error1
                jmp     MA_Indirect
MA_Error1:      dec     cl
                jmp     MA_Full

MA_OkAdrs:      mov     dl,cs:AsmTab1[bx]
                cmp     dl,0FFh
                je      MA_Error0
                mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                jmp     MA_ret

MA_Error0:      inc     cl
MA_Error:       mov     cs:GetKeyParams.RK_ErrPtr,offset BadInstr
                stc
                ret

MA_ret:         GetLineService _GL_ClrBuff
                clc
                ret

MA_Direct:      mov     dl,cs:AsmTab1[bx+1]
                cmp     dl,0FFh
                je      MA_Error0
                GetLineService _GL_GetSymb
                mov     cs:MA_StoreCX,cx
                dec     cl
                or      al,al
                jz      MA_DirectE
                mov     cs:MA_StoreCX,cx
                call    GetAddress
                cmp     ah,0
                jz      MA_ok1122
MA_DirectE:     mov     cx,cs:MA_StoreCX
                inc     cl
                jmp     MA_Error
MA_ok1122:      mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_Ret

MA_Full:        mov     cx,cs:MA_StoreCX
                GetLineService _GL_GetSymb
                or      al,al
                jz      MA_Error0
                dec     cl
                call    GetAddress
                dec     cl
                cmp     dh,35
                jb      MA_ESD1
                cmp     dh,44
                jnb     MA_ESD1
                jmp     MA_Branches
MA_ESD1:        push    ax
                GetLineService _GL_GetSymb
                cmp     al,','
                jne     MA_RealyFul
                GetLineService _GL_GetSymb
                or      al,20h
                cmp     al,'x'
                je      MA_FullX
                cmp     al,'y'
                pop     ax
                jne     MA_QWERTY
                jmp     MA_FullY
MA_QWERTY:      jmp     MA_Error

MA_RealyFul:    pop     ax
                cmp     ah,0
                jz      MA_TryZP
MA_NoZP:        mov     dl,cs:AsmTab1[bx+5]
                cmp     dl,0FFh
                jne     MA_FullOK1
                mov     cx,cs:MA_StoreCX
                jmp     MA_Error0
MA_FullOK1:     mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],ax
                inc     bx
                inc     bx
                jmp     MA_ret

MA_TryZP:       mov     dl,cs:AsmTab1[bx+2]
                cmp     dl,0FFh
                je      MA_NoZP
                mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_ret

MA_FullX:       pop     ax
                cmp     ah,0
                jz      MA_TryZP1
MA_NoZP1:       mov     dl,cs:AsmTab1[bx+6]
                cmp     dl,0FFh
                jne     MA_FullOK2
                mov     cx,cs:MA_StoreCX
                jmp     MA_Error0
MA_FullOK2:     mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],ax
                inc     bx
                inc     bx
                jmp     MA_ret

MA_TryZP1:      mov     dl,cs:AsmTab1[bx+3]
                cmp     dl,0FFh
                je      MA_NoZP1
                mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_ret

MA_FullY:       cmp     ah,0
                jz      MA_TryZP2
MA_NoZP2:       mov     dl,cs:AsmTab1[bx+7]
                cmp     dl,0FFh
                jne     MA_FullOK3
                mov     cx,cs:MA_StoreCX
                jmp     MA_Error0
MA_FullOK3:     mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],ax
                inc     bx
                inc     bx
                jmp     MA_ret

MA_TryZP2:      mov     dl,cs:AsmTab1[bx+4]
                cmp     dl,0FFh
                je      MA_NoZP2
                mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_ret


MA_Indirect:    mov     cs:MA_StoreCX,cx
                GetLineService _GL_GetSymb
                mov     cx,cs:MA_StoreCX
                or      al,al
                jnz     MA_IndOK33
                jmp     MA_Error
MA_IndOK33:     cmp     dh,44
                jne     MA_NoIndJmp
                jmp     MA_IndJMP
MA_NoIndJmp:    mov     cs:MA_StoreCX,cx
                call    GetAddress
                dec     cl
                push    ax
                GetLineService _GL_GetSymb
                or      al,al
                jnz     MA_IndOK2
                pop     ax
                jmp     MA_Error
MA_IndOK2:      cmp     al,')'
                je      MA_IndY
                cmp     al,','
                je      MA_IndX
                pop     ax
                mov     cx,cs:MA_StoreCX
                jmp     MA_Error

MA_IndY:        GetLineService _GL_GetSymb
                or      al,al
                jz      MA_65C02_ind
                cmp     al,','
                je      MA_IndY1
                pop     ax
                jmp     MA_Error
MA_IndY1:       GetLineService _GL_GetSymb
                or      al,20h
                cmp     al,'y'
                je      MA_IndY2
                pop     ax
                jmp     MA_Error
MA_IndY2:       pop     ax
                cmp     ah,0
                jz      MA_IndY21
MA_65C02_indER: mov     cx,cs:MA_StoreCX
                inc     cl
                jmp     MA_Error
MA_IndY21:      mov     dl,cs:AsmTab1[bx+9]
MA_65C02_indOK: cmp     dl,0FFh
                jne     MA_IndY3
                mov     cx,cs:MA_StoreCX
                jmp     MA_Error0
MA_IndY3:       mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_ret
MA_65C02_ind:   pop     ax
                cmp     ah,0
                jnz     MA_65C02_indER
                mov     dl,cs:AsmTab1[bx+10]
                jmp     MA_65C02_indOK


MA_IndX:        GetLineService _GL_GetSymb
                or      al,20h
                cmp     al,'x'
                je      MA_IndX2
                pop     ax
                jmp     MA_Error
MA_IndX2:       pop     ax
                cmp     ah,0
                jz      MA_IndX21
                mov     cx,cs:MA_StoreCX
                inc     cl
                jmp     MA_Error
MA_IndX21:      mov     dl,cs:AsmTab1[bx+8]
                cmp     dl,0FFh
                jne     MA_IndX3
                mov     cx,cs:MA_StoreCX
                jmp     MA_Error0
MA_IndX3:       mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_ret

MA_IndJMP:      call    GetAddress
                mov     bx,cs:AssembAdr
                mov     dl,6Ch
                push    ax
                dec     cl
                GetLineService _GL_GETSYMB
                cmp     al,')'
                jz      MA_IndJMP6C
                cmp     al,','
                jne     MA_IndJMP_ER
                GetLineService _GL_GETSYMB
                or      al,20h
                cmp     al,'x'
                jne     MA_IndJMP_ER
                mov     dl,7Ch
MA_IndJMP6C:    pop     ax
                mov     [bx],dl
                inc     bx
                mov     [bx],ax
                inc     bx
                inc     bx
                jmp     MA_ret
MA_IndJMP_ER:   dec     cl
MA_IndJMP_ER1:  pop     ax
                jmp     MA_Error0


MA_Branches:    push    bx
                mov     bx,cs:AssembAdr
                add     bx,2
                sub     ax,bx
                rcl     dh,1
                ror     dh,1
                adc     ah,0
                jnz     MA_err
                xor     dh,al
                shl     dh,1
                jnc     MA_noerr
MA_err:         pop     bx
                mov     cx,cs:MA_StoreCX
                inc     cl
                inc     cl
                jmp     MA_Error
MA_noerr:       pop     bx
                mov     dl,cs:AsmTab1[bx+5]
                mov     bx,cs:AssembAdr
                mov     [bx],dl
                inc     bx
                mov     [bx],al
                inc     bx
                jmp     MA_ret


BufferA         db      64 dup (?)
InitBufferA:    push    cx si di es
                mov     si,cs
                mov     es,si
                mov     si,SDA_Address
                mov     di,offset BufferA
                mov     cx,64
                cld
        rep     movsb
                pop     es di si cx
                ret


BufferB         db      64 dup (?)
InitBufferB:    push    cx si di es
                mov     si,cs
                mov     es,si
                mov     si,SDB_Address
                mov     di,offset BufferB
                mov     cx,64
                cld
        rep     movsb
                pop     es di si cx
                ret



; -- Memory Edit B ---------------------

MemoryEditStruc struc
EB_TextOrHex    db      ?
EB_TextCL2      db      ?
EB_TextCL1      db      ?
EB_TextCH       db      ?
EB_FirstFl      db      ?
EB_Address      dw      ?
EB_MinUp        db      ?
EB_MaxDown      db      ?
EB_MinLeft1     db      ?
EB_MinLeft2     db      ?
EB_MaxRight1    db      ?
EB_MaxRight2    db      ?
EB_Center       db      ?
EB_BytesInLine  dw      ?
EB_MemAdr       dw      ?
EB_InitBuffProc dw      ?
EB_TabFlag      db      ?
MemoryEditStruc ends

EB_Flag         db      0
EB_Params       MemoryEditStruc <0,8,61,20,0,0,20,23,8,61,54,77,29,16,offset SDB_Address,InitBufferB,1>
EditB:          mov     cs:EB_ParamsAddr, offset EB_Params
                mov     cs:ActiveFlags,0000000001000000b
                mov     cs:ShowAllNumber,2
                mov     ax,68
                mov     bx,68
                call    SH_Choose
                mov     cs:EB_Flag,1
                call    MemoryEditor
                mov     cs:EB_Flag,0
                ret




; -- Memory Edit A ---------------------

EA_Params       MemoryEditStruc <0,54,0,9,0,0,9,16,54,0,75,0FFh,0FFh,8,offset SDA_Address,InitBufferA,0>
EditA:          mov     cs:EB_ParamsAddr, offset EA_Params
                mov     cs:ActiveFlags,0000000000100000b
                mov     cs:ShowAllNumber,1
                mov     ax,61
                mov     bx,61
                call    SH_Choose
                mov     cs:EB_Flag,0
                call    MemoryEditor
                mov     cs:EB_Flag,1
                ret




; -- Disassembler ----------------------

Disasm:         call    GetAddress
                call    StopAnimate
                mov     cs:AssembAdr,ax
                call    ShowPrevIns
                GetLineService _GL_ClrBuff
                ret




; -- Dump B ----------------------------

DumpB:          call    GetAddress
                mov     cs:SDB_Address,ax
                call    InitBufferB
                mov     si,offset EB_Params
                call    EB_Init
                GetLineService _GL_ClrBuff
                ret




; -- Dump A ----------------------------

DumpA:          call    GetAddress
                mov     cs:SDA_Address,ax
                call    InitBufferA
                mov     si,offset EA_Params
                call    EB_Init
                GetLineService _GL_ClrBuff
                ret




; -- Limits ----------------------------

LeftLimit       dw      0                       ; '[' command
RightLimit      dw      0BFFFh

Limits:         GetLineService _GL_GetSymb
                or      al,al
                jnz     LI_ok1
                GetLineService _GL_ClrBuff
                mov     al,'['
                GetLineService _GL_Symbol
                mov     al,' '
                GetLineService _GL_Symbol
                mov     al,byte ptr cs:LeftLimit[1]
                GetLineService _GL_Byte
                mov     al,byte ptr cs:LeftLimit
                GetLineService _GL_Byte
                mov     al,','
                GetLineService _GL_Symbol
                mov     al,byte ptr cs:RightLimit[1]
                GetLineService _GL_Byte
                mov     al,byte ptr cs:RightLimit
                GetLineService _GL_Byte
                mov     al,']'
                GetLineService _GL_Symbol
                mov     cl,cs:GetLineParams.GL_Pos
                mov     ch,cs:GetLineParams.GL_BegPrint
                ret

LI_ok1:         cmp     al,']'
                je      LI_End
                cmp     al,','
                je      LI_Second
                dec     cl
                call    GetAddress
                mov     cs:LeftLimit,ax
LI_Second:      GetLineService _GL_GetSymb
                or      al,al
                jz      LI_End
                cmp     al,']'
                je      LI_End
                dec     cl
                call    GetAddress
                mov     cs:RightLimit,ax
LI_End:         mov     ax,cs:LeftLimit
                cmp     ax,cs:RightLimit
                ja      LI_NoOk
                GetLineService _GL_ClrBuff
                ret
LI_NoOk:        mov     cs:GetKeyParams.RK_ErrPtr,offset AdressError
                inc     cl
                ret




; -- Find ------------------------------

FindBuffer      db      256 dup (0)
F_LastAdr       dw      0
F_BufPtr        db      0
TextFlag        db      0
F_StoreCX       dw      0
F_StoreCX1      dw      0
F_StoreCX2      dw      0
F_or            db      0
F_si            dw      0

F_Err1:         mov     cs:GetKeyParams.RK_ErrPtr,offset NoStringMes
                inc     cl
                ret

F_Err2:         mov     cs:GetKeyParams.RK_ErrPtr,offset ByteExpMes
                mov     cx,cs:F_StoreCX2
                mov     cs:F_BufPtr,0
                inc     cl
                ret

Find:           mov     dl,cs:GetLineParams.GL_GS_SpcFl ; 'F' command
                GetLineService _GL_GetSymb
                cmp     cs:F_BufPtr,0
                jnz     F_FindNext
                or      al,al
                jz      F_Err1
F_FindNext:     or      al,al
                jnz     F_New
                mov     si,cs:F_LastAdr
                inc     si
                mov     cs:F_si,si
                jmp     F_Go_0
F_New:          dec     cl
                xor     ax,ax
                mov     cs:TextFlag,al
                mov     cs:F_BufPtr,al
                mov     cs:F_or,al
F_0:            GetLineService _GL_GetSymb
                or      al,al
                jnz     F_0000
                jmp     f_Go
F_0000:         cmp     al,27h                  ; '
                jne     F_str_0
                mov     byte ptr cs:F_or,0
                jmp     F_str
F_Str_0:        cmp     al,'"'
                jne     F_1
                mov     byte ptr cs:F_or,80h
F_str:          xor     byte ptr cs:TextFlag,0FFh
                mov     byte ptr cs:GetLineParams.GL_GS_SpcFl,0
                jnz     F_0
                mov     byte ptr cs:GetLineParams.GL_GS_SpcFl,1
                GetLineService _GL_GetSymb
                cmp     al,','
                je      F_0
                dec     cl
                jmp     F_0

F_1:            cmp     byte ptr cs:TextFlag,0
                jnz     F_1_1
                dec     cl
                mov     cs:F_StoreCX2,cx
                call    GetAddress
                or      ah,ah
                jz      F_1_1_1
                jmp     F_Err2
F_1_1:          or      al,cs:F_or
F_1_1_1:        xor     bx,bx
                mov     bl,cs:F_BufPtr
                mov     cs:FindBuffer[bx],al
                inc     byte ptr cs:F_BufPtr
                jmp     F_0

F_Go:           mov     si,cs:LeftLimit
                mov     cs:F_si,si
F_Go_0:         push    cs
                pop     es
                jmp     F_Go_000
F_Go_00:        inc     word ptr cs:F_si
                jz      F_NotFound
F_Go_000:       mov     si,cs:F_si
                cmp     si,cs:RightLimit
                ja      F_NotFound
                mov     di,offset FindBuffer
                xor     cx,cx
                mov     cl,cs:F_BufPtr
                rep     cmpsb
                jne     F_Go_00
                mov     si,cs:F_si
                mov     cs:SDB_Address,si
                call    InitBufferB
                mov     cs:F_LastAdr,si
                mov     si,offset EB_Params
                call    EB_Init
                mov     cs:GetLineParams.GL_GS_SpcFl,dl
                GetLineService _GL_ClrBuff
                jmp     F_ret
F_NotFound:     mov     cs:GetKeyParams.RK_ErrPtr,offset NotFound
                mov     cs:GetLineParams.GL_GS_SpcFl,dl
                mov     cl,cs:GetLineParams.GL_Pos
                mov     ch,cs:GetLineParams.GL_BegPrint
                inc     cl
F_ret:          ret




; -- Copy ------------------------------

Copy:           call    GetAddress
                push    ax
                GetLineService _GL_GetSymb
                or      al,al
                jnz     C_1
                pop     ax
                push    ax
                cmp     ax,cs:LeftLimit
                jb      C_Forward
                stc
                jmp     C_01
C_Forward:      clc
                jmp     C_01
C_1:            call    Upcase
                cmp     al,'f'
                clc
                je      C_01
                cmp     al,'b'
                jne     C_Error
                stc
C_01:           pop     ax
                push    es
                push    ds
                pop     es
                pushf
                mov     di,ax
                mov     si,cs:LeftLimit
                mov     cx,cs:RightLimit
                sub     cx,si
                inc     cx
                popf
                cld
                jnc     C_DoCopy
                mov     si,cs:RightLimit
                add     di,cx
                dec     di
                std
C_DoCopy:       rep     movsb
                pop     es
                cld
                GetLineService _GL_ClrBuff
                ret
C_Error:        pop     ax
                GetLineService _GL_Left
                mov     cs:GetKeyParams.RK_ErrPtr,offset BadParam
                ret




; -- Compare ---------------------------

Compare:        call    GetAddress
                push    es
                push    ds
                pop     es
                mov     di,ax
                mov     si,cs:LeftLimit
                mov     cx,cs:RightLimit
                sub     cx,si
                inc     cx
                cld
                repe    cmpsb
                pop     es
                pushf
                GetLineService _GL_ClrBuff
                inc     cl
                popf
                mov     cs:GetKeyParams.RK_ErrPtr,offset Identifical
                je      O_Ident
                mov     cs:GetKeyParams.RK_ErrPtr,offset NotIdent
                dec     di
                mov     cs:SDB_Address,di
                call    InitBufferB
                mov     si,offset EB_Params
                call    EB_Init
O_Ident:        ret




; -- Breaks ----------------------------

Breaks:         GetLineService _GL_GetSymb      ; 'B' command
                or      al,al
                jnz     B_ok1
B_Err:          inc     cl
B_Err1:         mov     cs:GetKeyParams.RK_ErrPtr,offset BreakNumMES
                ret
B_ok1:          dec     cl
                GetLineService _GL_GetSymb
                sub     al,'0'
                cmp     al,6
                ja      B_Err1
                cmp     al,1
                jb      B_Err1
                mov     bl,7
                mul     bl
                mov     bx,ax
                GetLineService _GL_GetSymb
                or      al,al
                jnz     B_ok2
                xor     cs:Breakpoints.[bx].BP_ActiveFlag,1
                GetLineService _GL_ClrBuff
                ret
B_ok2:          cmp     al,'='
                je      B_ok3
                mov     cs:GetKeyParams.RK_ErrPtr,offset EqualMess
                ret
B_ok3:          call    GetAddress
                mov     cs:Breakpoints[bx].BP_ActiveFlag,1
                mov     cs:Breakpoints[bx].BP_Address,ax
                GetLineService _GL_ClrBuff
                ret




; -- Go --------------------------------

Go:             mov     bx,cs:AssembAdr         ; 'G' command
                GetLineService _GL_GetSymb
                or      al,al
                jz      GO_1
                cmp     al,','
                je      Go_SecAdr
                dec     cl
                call    GetAddress
                mov     bx,ax
                dec     cl
                GetLineService _GL_GetSymb
                or      al,al
                jz      GO_1
                cmp     al,','
                jne     GO_1
Go_SecAdr:      mov     cs:Regs.PC,bx
                call    GetAddress
                mov     cs:Breakpoints.BP_ActiveFlag,1
                mov     cs:Breakpoints.BP_Address,ax
                call    GoAppleII
                mov     cs:Breakpoints.BP_ActiveFlag,0
                GetLineService _GL_ClrBuff
                ret
GO_1:           mov     cs:Regs.PC,bx
                mov     cs:Breakpoints.BP_ActiveFlag,0
                call    GoAppleII0
                GetLineService _GL_ClrBuff
                ret




; -- Load Labels -----------------------

LoadLab:        GetLineService _GL_GetSymb              ; 'LL' command
                dec     cl
                or      al,al
                jnz     LL_E0
                GetLineService _GL_ClrBuff
                mov     bx,offset Com_LLabels
                GetLineService _GL_String
                mov     al,' '
                GetLineService _GL_Symbol
                mov     bx,offset LAB_FileSpec
                GetLineService _GL_String
                GetLineService _GL_Home
                xor     ch,ch
                mov     cl,4
                mov     cs:GetKeyParams.RK_ErrPtr,offset LS_EnterMes1
                ret
LL_E0:          mov     byte ptr cs:LS_OpenFileF,3Dh
                mov     byte ptr cs:LS_RWfileF,3Fh
                mov     word ptr cs:LS_ErrPtr,offset LabErrMes_L
                mov     word ptr cs:LS_OkPtr,offset LabMes_L
                mov     word ptr cs:LS_FileSpec,offset LAB_FileSpec
                mov     word ptr cs:LS_Ext,offset LAB_Ext
                mov     word ptr cs:LS_Buffer,offset SymbMem
                mov     word ptr cs:LS_BufferLen,MaxSymbMem * 2 + 4
                jmp     File_LS




; -- Save Labels -----------------------

LAB_FileSpec    db      'UNTITLED.LAB', 67 dup (0)
LAB_Ext         db      '.LAB',0
SL_ErrFuck:     mov     cs:GetKeyParams.RK_ErrPtr,offset SymNoSymbErr
                GetLineService _GL_End
                mov     cl,cs:GetLineParams.GL_Pos
                mov     ch,cs:GetLineParams.GL_BegPrint
                inc     cl
                ret
SaveLab:        cmp     cs:SymbPtr,0            ; 'SL' command
                jz      SL_ErrFuck
                GetLineService _GL_GetSymb
                dec     cl
                or      al,al
                jnz     SL_E0
                GetLineService _GL_ClrBuff
                mov     bx,offset Com_SLabels
                GetLineService _GL_String
                mov     al,' '
                GetLineService _GL_Symbol
                mov     bx,offset LAB_FileSpec
                GetLineService _GL_String
                GetLineService _GL_Home
                xor     ch,ch
                mov     cl,4
                mov     cs:GetKeyParams.RK_ErrPtr,offset LS_EnterMes2
                ret
SL_E0:          mov     byte ptr cs:LS_OpenFileF,3Ch
                mov     byte ptr cs:LS_RWfileF,40h
                mov     word ptr cs:LS_ErrPtr,offset LabErrMes_S
                mov     word ptr cs:LS_OkPtr,offset LabMes_S
                mov     word ptr cs:LS_FileSpec,offset LAB_FileSpec
                mov     word ptr cs:LS_Ext,offset LAB_Ext
                mov     word ptr cs:LS_Buffer,offset SymbMem
                mov     word ptr cs:LS_BufferLen,MaxSymbMem * 2 + 4
                jmp     File_LS




; -- Define Label ----------------------

MaxSymbMem      =       1000h
MaxValCount     =       MaxSymbMem / 2

                even                            ; Don't touch!
SymbMem         db      MaxSymbMem dup (0)
SymbPtr         dw      0
SymbVal         dw      MaxValCount dup (0)
SymbValPtr      dw      0

DefineLab:      call    SymbGetVal
                jc      SD_NewSymb
                mov     bx,cs:SGV_adr
                mov     cx,cs:SGV_cx
                GetLineService _GL_GetSymb
                or      al,al
                jz      SD_EqMiss
                cmp     al,'='
                jne     SD_EqMiss1
                call    GetAddress
                mov     cs:SymbVal[bx],ax
                jmp     SD_ret
SD_NewSymb:     GetLineService _GL_GetSymb
                or      al,al
                jz      SD_SymMiss
                push    cx
                mov     di,offset Delimiters
                mov     cx,Delimiters_C
                call    CalcCommand
                pop     cx
                jnc     SD_SymMiss1
                dec     cl
                mov     bx,cs:SymbPtr
SD_Loop0:       GetLineService _GL_GetSymb
                cmp     al,'='
                je      SD_Cont1
                or      al,al
                jz      SD_EqMiss
                push    cx
                mov     di,offset Delimiters
                mov     cx,Delimiters_C
                call    CalcCommand
                pop     cx
                jnc     SD_EqMiss1
                mov     cs:SymbMem[bx],al
                inc     bx
                cmp     bx,MaxSymbMem
                jb      SD_Loop0
                mov     cs:GetKeyParams.RK_ErrPtr,offset SymNoMemErr
                ret
SD_EqMiss:      inc     cl
SD_EqMiss1:     mov     cs:GetKeyParams.RK_ErrPtr,offset EqualMess
                ret
SD_SymMiss:     inc     cl
SD_SymMiss1:    mov     cs:GetKeyParams.RK_ErrPtr,offset SymMissErr
                ret
SD_Cont1:       call    GetAddress
                mov     word ptr cs:SymbMem[bx],0
                inc     bx
                mov     cs:SymbPtr,bx
                mov     si,cs:SymbValPtr
                shl     si,1
                mov     cs:SymbVal[si],ax
                inc     word ptr cs:SymbValPtr
SD_ret:         mov     cs:GetKeyParams.RK_ErrPtr,0
                call    ShowPrevIns
                GetLineService _GL_ClrBuff
                ret




; -- Labels List -----------------------

LL_Commands     db      7,8,3,4,0Ch,18h
LL_Procs        dw      LL_Up,LL_Down,LL_PgUp,LL_PgDn,LL_Esc,LL_Enter
LabList:        cmp     cs:SymbPtr,0            ; 'list' command
                jnz     LL_NoError
                jmp     LL_Error1
LL_NoError:     mov     ax,85
                mov     bx,85
                call    SH_Choose
                mov     cs:SL_Flag,1
                mov     cs:ShowAllNumber,6
                mov     cs:ActiveFlags,0000000100000000b
                mov     cs:SL_Ptr,0
LL_Loop:        call    ReadKey
                mov     cx,offset LL_Procs- offset LL_Commands
                mov     di,offset LL_Commands
                call    CalcCommand
                jc      LL_Loop
                shl     di,1
                call    cs:LL_Procs[di]
                jnc     LL_Loop
LL_Ret:         mov     cs:SL_Flag,0
                GetLineService _GL_ClrBuff
                ret

LL_Up:          cmp     cs:SL_Ptr,0
                jz      LL_UpRet
                dec     cs:SL_Ptr
LL_UpRet:       clc
                ret

LL_Down:        mov     ax,cs:SL_Ptr
                add     ax,10
                cmp     ax,cs:SymbValPtr
                jae     LL_DownRet
                inc     cs:SL_Ptr
LL_DownRet:     clc
                ret

LL_PgUp:        mov     di,10
LL_PgUpLoop:    call    LL_Up
                dec     di
                jnz     LL_PgUpLoop
                clc
                ret

LL_PgDn:        mov     di,10
LL_PgDnLoop:    call    LL_Down
                dec     di
                jnz     LL_PgDnLoop
                clc
                ret

LL_Esc:
LL_Enter:       stc
                ret

LL_Error1:      mov     cs:GetKeyParams.RK_ErrPtr,offset SymNoSymbErr
                inc     cl
                ret



; -- Delete Label ----------------------

SD_Error1:      mov     cs:GetKeyParams.RK_ErrPtr,offset SymMissErr
SD_Error2:      inc     cl
                ret

DelLab:         GetLineService _GL_GetSymb
                or      al,al
                jz      SD_Error1
                cmp     al,'.'
                je      SDel_1
                dec     cl
SDel_1:         call    SymbGetVal
                jc      SD_Error2
                mov     si,offset SymbMem
                mov     di,si
                add     si,cs:SGV_nameEnd
                add     di,cs:SGV_nameBeg
                inc     si
                push    ds
                mov     ax,cs
                mov     ds,ax
                mov     es,ax
                mov     cx,cs:SymbPtr
                sub     cx,cs:SGV_nameEnd
                inc     cx
                cld
                rep     movsb
                mov     si,offset SymbVal
                add     si,cs:SGV_adr
                mov     di,si
                add     si,2
                mov     cx,cs:SymbValPtr
                shl     cx,1
                sub     cx,cs:SGV_adr
                dec     cx
                rep     movsb
                pop     ds
                dec     word ptr cs:SymbValPtr
                mov     cx,cs:SGV_nameEnd
                sub     cx,cs:SGV_nameBeg
                inc     cx
                sub     cs:SymbPtr,cx
                mov     bx,cs:SymbPtr
                mov     word ptr cs:SymbMem[bx],0
                call    ShowPrevIns
                GetLineService _GL_ClrBuff
SDel_ret:       ret




; -- Labels ON/OFF ---------------------

LabOnOff:       call    OnOff
                jc      LOO_ret
                mov     byte ptr cs:WordPrintFl,1
                jnz     LOO_ret0
                mov     byte ptr cs:WordPrintFl,0
LOO_ret0:       call    ShowPrevIns
                GetLineService _GL_ClrBuff
LOO_ret:        ret




; -- Swap ON/OFF -----------------------

SwapOnOff:      call    GetAddress
                mov     cs:SwapTime,ax
                GetLineService _GL_ClrBuff
                ret




; -- Evaluate expression ---------------

CalcCom         db      'h$d@b%'
CalcSub         dw      CalcHex,CalcHex,CalcHex,CalcDec,CalcDec,CalcBin,CalcBin
CalcNum         dw      ?

Calculate:      call    GetAddress
                mov     cs:CalcNum,ax
                GetLineService _GL_GetSymb
                or      al,al
                mov     di,0
                jz      CalcOk1
                push    cx
                mov     di,offset CalcCom
                mov     cx,offset CalcSub - offset CalcCom
                call    CalcCommand
                pop     cx
                jc      CalcError
                inc     di
                shl     di,1
CalcOk1:        mov     bx,cs:CalcNum
                GetLineService _GL_ClrBuff
                mov     al,' '
                GetLineService _GL_Symbol
                mov     GetLineParams.GL_InsFlag,1
                call    word ptr cs:CalcSub[di]
                xor     cx,cx
                cmp     cs:GetKeyParams.RK_ErrPtr,cx
                jz      CalcRet
                inc     cl
CalcRet:        ret
CalcError:      mov     cs:GetKeyParams.RK_ErrPtr,offset BadParam
                ret

CalcHex:        mov     al,bh
                GetLineService _GL_Byte
                mov     al,bl
                GetLineService _GL_Byte
                ret

CalcBin:        mov     al,'%'
                GetLineService _GL_Symbol
                mov     dx,1
                or      bx,bx
                clc
                jz      CalcB1
                mov     dx,10h
CalcB0:         dec     dx
                shl     bx,1
                jnc     CalcB0
                inc     dx
                jmp     CalcB1
CalcBinLoop:    shl     bx,1
CalcB1:         mov     al,'0'
                jnc     CalcB2
                mov     al,'1'
CalcB2:         GetLineService _GL_Symbol
                dec     dx
                jnz     CalcBinLoop
CalcB3:         ret

CalcDec:        mov     al,'@'
                GetLineService _GL_Symbol
                or      bx,bx
                jz      CalcD0000
CalcDdiv:       xor     dx,dx
CalcD0:         inc     dx
                sub     bx,10
                jnc     CalcD0
                add     bx,10
                dec     dx
                mov     ax,bx
                mov     bx,dx
                add     ax,'0'
                GetLineService _GL_Symbol
                GetLineService _GL_Left
                cmp     dx,0
                jnz     CalcDdiv
                ret
CalcD0000:      mov     al,'0'
                GetLineService _GL_Symbol
                ret




; -- Cold RESET Apple ][ ---------------

ResetApple:     call    ResetAppleII
                mov     ax,ds:[0FFFCh]
                mov     cs:Regs.PC,ax
                mov     cs:AssembAdr,ax
                call    StopAnimate
                call    ShowPrevIns
                xor     al,al
                mov     cs:Regs.A,al
                mov     cs:Regs.X,al
                mov     cs:Regs.Y,al
                mov     cs:Regs.S,al
                mov     cs:Regs.P,20h
                GetLineService _GL_ClrBuff
                ret




; -- Move Help Window ------------------

MH_Keys         db      7,8,5,6,1,2,3,4,19h,0Ch,18h
MH_Subrt        dw      MH_Up,MH_Down,MH_Left,MH_Right
                dw      MH_Home,MH_End,MH_PgUp,MH_PgDn,MH_Cntr
                dw      MH_Esc,MH_Enter
MH_CX           dw      ?
MH_OldSH_CX     dw      ?
MoveHelp:       test    cs:HelpFlag,1
                jnz     MH_ok
                jmp     MH_HelpClosed
MH_ok:          push    cs:ShowAllNumber
                mov     cs:ShowAllNumber,5
                mov     cs:MH_CX,cx
                mov     ax,cs:SH_CX
                mov     cs:MH_OldSH_CX,ax
                mov     dx,1
                xchg    cs:HelpPtr,dx
                call    SH_Calculate
                mov     cs:ActiveFlags,0000000010000000b
                xor     ax,ax
                mov     cs:FkeysBuffer[7*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[8*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[9*size FkeyStruc].FkeyFlag,al
                mov     cs:ScreenIOparams.CursorFlag,0
MH_Loop0:       mov     cx,cs:MH_CX
                call    ReadKey
                mov     di,offset MH_Keys
                mov     cx,offset MH_Subrt- offset MH_Keys
                call    CalcCommand
                jc      MH_Loop0
                shl     di,1
                call    cs:MH_Subrt[di]
                jnc     MH_Loop0
                mov     cs:HelpPtr,dx
                call    SH_Calculate
                mov     al,1
                mov     cs:FkeysBuffer[7*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[8*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[9*size FkeyStruc].FkeyFlag,al
                mov     cs:ScreenIOparams.CursorFlag,1
                pop     cs:ShowAllNumber
                GetLineService _GL_ClrBuff
MH_HelpClosed:  ret

MH_Up:          mov     cx,cs:SH_CX
                ScreenIOservice _CALCXY
                cmp     ch,1
                je      MH_UpRet
                sub     cs:SH_CX,80*2
MH_UpRet:       clc
                ret
MH_Down:        mov     cx,cs:SH_CX
                ScreenIOservice _CALCXY
                cmp     ch,12
                je      MH_DownRet
                add     cs:SH_CX,80*2
MH_DownRet:     clc
                ret
MH_Left:        mov     cx,cs:SH_CX
                ScreenIOservice _CALCXY
                cmp     cl,0
                je      MH_LeftRet
                sub     cs:SH_CX,2
MH_LeftRet:     clc
                ret
MH_Right:       mov     cx,cs:SH_CX
                ScreenIOservice _CALCXY
                cmp     cl,43
                je      MH_RightRet
                add     cs:SH_CX,2
MH_RightRet:    clc
                ret

MH_Home:        mov     cs:SH_CX,0
                clc
                ret
MH_End:         mov     cs:SH_CX,6E0h
                clc
                ret
MH_PgUp:        mov     cs:SH_CX,56h
                clc
                ret
MH_PgDn:        mov     cs:SH_CX,736h
                clc
                ret
MH_Cntr:        mov     cs:SH_CX,3EAh
                clc
                ret
MH_Esc:
;               mov     ax,cs:MH_OldSH_CX
;               mov     cs:SH_CX,ax
MH_Enter:       stc
                ret




; -- Print Memory Dump -----------------

PD_PrnFileSpec  db      'PRN',0
PD_FileSpec     db      79 dup (0)
PD_Title        db      '            Appler Debugger Print Out -- Apple ][ Memory Dump',0Dh,0Ah
                db      '--------------------------------------------------------------------------',0Dh,0Ah
PD_Line         db      80 dup (0)
PD_Handle       dw      ?
PD_ddl          db      ?
PD_Error_J:     jmp     PD_Error
PrintDump:      GetLineService _GL_GetSymb
                dec     cl
                mov     dx,offset PD_PrnFileSpec
                or      al,al
                jz      PD_1
                xor     bx,bx
PD_Loop0:       GetLineService _GL_GetSymb
                mov     cs:PD_FileSpec[bx],al
                inc     bx
                cmp     bx,79
                je      PD_LoopOK
                or      al,al
                jnz     PD_Loop0
PD_LoopOK:      mov     dx,offset PD_FileSpec
PD_1:           mov     GetKeyParams.RK_ErrPtr,offset PrintingMes
                call    Prepare4DOS
                push    ds
                push    cs
                pop     ds
                xor     cx,cx
                mov     ah,3Ch
                int     21h
                jc      PD_Error_J
                mov     cs:PD_Handle,ax
                mov     dx,offset PD_Title
                mov     cx,139
                mov     bx,ax
                mov     ah,40h
                int     21h
                jc      PD_Error_J
                pop     ds
                push    ds
                mov     bx,cs:LeftLimit
                mov     cx,cs:RightLimit
                sub     cx,bx
                inc     cx
                cld
                jmp     PD_NewLine1
PD_NewLine:     call    PD_PrintLine
                jc      PD_Error_J
PD_NewLine1:    call    PD_ClearLine
                xor     dl,dl
                mov     dh,58
                mov     al,bh
                call    PD_PrintByte
                mov     al,bl
                call    PD_PrintByte
                mov     al,':'
                call    PD_PrintSymbol
                mov     al,' '
                call    PD_PrintSymbol
                mov     cs:PD_ddl,8
                jmp     PD_NL
PD_PrintLoop:   mov     al,bl
                and     al,00001111b
                jz      PD_NewLine
PD_NL:          mov     al,ds:[bx]
                inc     bx
                call    PD_PrintByte
                xchg    dl,dh
                xor     ah,ah
                mov     di,ax
                shl     di,1
                mov     al,byte ptr ss:TextChars[di]
                cmp     al,0DBh
                jne     PD_2
                mov     al,20h
PD_2:           call    PD_PrintSymbol
                xchg    dl,dh
PD_Space:       mov     al,' '
                call    PD_PrintSymbol
                dec     cs:PD_ddl
                jz      PD_Space
                loop    PD_PrintLoop
                call    PD_PrintLine
                jc      PD_Error
                mov     bx,cs:PD_Handle
                mov     ah,3Eh
                int     21h
                jc      PD_Error
                mov     GetKeyParams.RK_ErrPtr,offset PrintOkMes
                GetLineService _GL_ClrBuff
                clc
PD_Ret:         pop     ds
                call    SOD4eraperP
                ret
PD_Error:       mov     GetKeyParams.RK_ErrPtr,offset PrintErrMes
                mov     ch,cs:GetLineParams.GL_BegPrint
                mov     cl,cs:GetLineParams.GL_Pos
                inc     cl
                stc
                jmp     PD_Ret




; -- Print Assembler -------------------

PA_Title        db      '    Appler Debugger Print Out',0Dh,0Ah
                db      '        65C02 Disassebler',0Dh,0Ah
                db      '---------------------------------',0Dh,0Ah
PA_Title1       db      0Dh,0Ah,'       Defined Labels List',0Dh,0Ah
                db      '---------------------------------',0Dh,0Ah
PA_Error_J:     jmp     PA_Error
PrintAssembler: GetLineService _GL_GetSymb
                dec     cl
                mov     dx,offset PD_PrnFileSpec
                or      al,al
                jz      PA_1
                xor     bx,bx
PA_Loop0:       GetLineService _GL_GetSymb
                mov     cs:PD_FileSpec[bx],al
                inc     bx
                cmp     bx,79
                je      PA_LoopOK
                or      al,al
                jnz     PA_Loop0
PA_LoopOK:      mov     dx,offset PD_FileSpec
PA_1:           mov     GetKeyParams.RK_ErrPtr,offset PrintingMes
                call    Prepare4DOS
                push    ds
                push    cs
                pop     ds
                xor     cx,cx
                mov     ah,3Ch
                int     21h
                jc      PA_Error_J
                mov     cs:PD_Handle,ax
                mov     dx,offset PA_Title
                mov     cx,93
                mov     bx,ax
                mov     ah,40h
                int     21h
                jc      PA_Error_J
                pop     ds
                push    ds
                mov     si,cs:LeftLimit
PA_Loop1:       call    PD_ClearLine
                gotoxy  1Ah,2                   ; Unvisible
                mov     dx,si
                call    OneInstr
                mov     cx,29
                call    PD_GetScreen
                call    PD_PrintLine
                jc      PA_Error_J
                cmp     dx,si
                ja      PA_Exit
                cmp     si,cs:RightLimit
                jbe     PA_Loop1
PA_Exit:        cmp     cs:SymbPtr,0
                jz      PA_NoLabs
                push    cs
                pop     ds
                mov     dx,offset PA_Title1
                mov     cx,65
                mov     bx,PD_Handle
                mov     ah,40h
                int     21h
                jc      PA_Error
                pop     ds
                push    ds
                xor     bx,bx
                mov     si,bx
                mov     dx,28
PA_ShowLabLoop: call    PD_ClearLine
                gotoxy  1Ah,2
                call    PrintSymbol
                gotoxy  1Ah,30
                mov     al,'='
                ScreenIOservice _SYMBPRINT
                mov     al,byte ptr cs:SymbVal[si+1]
                ScreenIOservice _BYTEPRINT
                mov     al,byte ptr cs:SymbVal[si]
                ScreenIOservice _BYTEPRINT
                mov     cx,33
                call    PD_GetScreen
                call    PD_PrintLine
                add     si,2
                inc     bx
                cmp     bx,cs:SymbValPtr
                jb      PA_ShowLabLoop
PA_NoLabs:      mov     bx,cs:PD_Handle
                mov     ah,3Eh
                int     21h
                jc      PA_Error
                mov     GetKeyParams.RK_ErrPtr,offset PrintAsmOkMes
                GetLineService _GL_ClrBuff
                clc
PA_Ret:         pop     ds
                call    SOD4eraperP
                ret
PA_Error:       mov     GetKeyParams.RK_ErrPtr,offset PrintAsmErrMes
                mov     ch,cs:GetLineParams.GL_BegPrint
                mov     cl,cs:GetLineParams.GL_Pos
                inc     cl
                stc
                jmp     PD_Ret



PD_GetScreen:   push    si ds es
                mov     ax,seg Screen
                mov     ds,ax
                mov     si,offset Screen + 25*80*2 + 4
                push    cs
                pop     es
                mov     di,offset PD_Line
                cld
PD_GS_MoveLoop: lodsw
                stosb
                loop    PD_GS_MoveLoop
                pop     es ds si
                ret



PD_ClearLine:   push    ax cx di es
                push    cs
                pop     es
                mov     di,offset PD_Line
                mov     al,' '
                mov     cx,80
                cld
        rep     stosb
                mov     cx,seg Screen
                mov     es,cx
                mov     di,offset Screen + 25*80*2
                mov     cx,70*2
        rep     stosb
                pop     es di cx ax
                ret

PL_cr           db      0Dh,0Ah
PD_PrintLine:   push    ax bx cx dx ds
                push    cs
                pop     ds
                mov     bx,offset PD_Line + 79
                mov     cx,80
PD_PL_Loop:     cmp     byte ptr cs:[bx],' '
                jne     PD_PL_Cont
                dec     bx
                dec     cx
                jnz     PD_PL_Loop
PD_PL_Cont:     mov     bx,cs:PD_Handle
                mov     dx,offset PD_Line
                mov     ah,40h
                int     21h
                jc      PD_PL_Err
                cmp     ax,cx
                jne     PD_PL_Err
                mov     dx,offset PL_cr
                mov     cx,2
                mov     ah,40h
                int     21h
                jc      PD_PL_Err
                cmp     ax,cx
                jne     PD_PL_Err
                clc
PD_PL_Ret:      pop     ds dx cx bx ax
                ret
PD_PL_Err:      stc
                jmp     PD_PL_Ret

PD_PrintByte:   push    ax bx dx
                xor     bx,bx
                mov     bl,dl
                mov     dx,ax
                shr     al,4
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                mov     cs:PD_Line[bx],al
                mov     al,dl
                and     al,00001111b
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                mov     cs:PD_Line+1[bx],al
                mov     dl,bl
                pop     dx bx ax
                add     dl,2
                ret

PD_PrintSymbol: push    bx
                xor     bx,bx
                mov     bl,dl
                mov     cs:PD_Line[bx],al
                inc     dl
                pop     bx
                ret




; -- Sound ON/OFF ----------------------

SoundOnOff:     call    OnOff
                jc      SOO_ret
                mov     ax,offset C030r
                mov     bx,offset C030w
                jnz     SOO_go
                mov     ax,offset C020r
                mov     bx,offset C020w
SOO_go:         push    es
                mov     cx,ss
                mov     es,cx
                mov     cx,16
                mov     di,offset C0xxRead + 2*30h
                cld
        rep     stosw
                mov     ax,bx
                mov     cx,16
                mov     di,offset C0xxWrite + 2*30h
        rep     stosw
                pop     es
                call    ShowPrevIns
                GetLineService _GL_ClrBuff
SOO_ret:        ret



RecordLen       equ     1000h
                db      0
RecordBuffer    dw      RecordLen dup (0)
REC_Realtime    db      0

; -- Start Recording -------------------

RecordStart:    GetLineService _GL_GetSymb
                call    Upcase
                or      al,al
                jz      RS_ok
                cmp     al,'f'
                je      RS_ok
                mov     cs:GetKeyParams.RK_ErrPtr,offset BadParam
                ret
RS_ok:          mov     cs:REC_Realtime,al
                push    es
                push    cs
                pop     es
                mov     di,offset RecordBuffer - 1
                mov     cx,RecordLen - 2
                call    StartRecord
                pop     es
                GetLineService _GL_ClrBuff
;                 call    GoAppleII0
                ret


; -- Stop Recording --------------------

RecordStop:     call    StopRecord
                mov     cs:GetKeyParams.RK_ErrPtr,offset RecPlayedMes
                or      cx,cx
                jz      RS_1
                cmp     cx,RecordLen - 2
                je      RS_1
                mov     cs:GetKeyParams.RK_ErrPtr,offset RecordedMes
RS_1:           cmp     cs:REC_Realtime,0
                jz      RS_xit
                push    es
                push    cs
                pop     es
                mov     di,offset RecordBuffer + 1
                mov     cx,RecordLen
                mov     al,1
                cld
RS_Loop:        stosb
                inc     di
                loop    RS_Loop
                pop     es
RS_xit:         GetLineService _GL_ClrBuff
                ret


; -- Play Recording --------------------

RecordPlay:     GetLineService _GL_GetSymb
                dec     cl
                or      al,al
                jz      RP_Play
                call    LoadRec
RP_Play:        push    ds
                push    cs
                pop     ds
                mov     si,offset RecordBuffer
                clc
                call    SimKbdRq
                pop     ds
                GetLineService _GL_ClrBuff
;                 call    GoAppleII0
                ret


; -- Load Record -----------------------

LoadRec:        GetLineService _GL_GetSymb              ; 'LR' command
                dec     cl
                or      al,al
                jnz     LR_E0
                GetLineService _GL_ClrBuff
                mov     bx,offset Com_LRecord
                GetLineService _GL_String
                mov     al,' '
                GetLineService _GL_Symbol
                mov     bx,offset REC_FileSpec
                GetLineService _GL_String
                GetLineService _GL_Home
                xor     ch,ch
                mov     cl,4
                mov     cs:GetKeyParams.RK_ErrPtr,offset LR_EnterMes1
                ret
LR_E0:          mov     byte ptr cs:LS_OpenFileF,3Dh
                mov     byte ptr cs:LS_RWfileF,3Fh
                mov     word ptr cs:LS_ErrPtr,offset RecErrMes_L
                mov     word ptr cs:LS_OkPtr,offset RecMes_L
                mov     word ptr cs:LS_FileSpec,offset REC_FileSpec
                mov     word ptr cs:LS_Ext,offset REC_Ext
                mov     word ptr cs:LS_Buffer,offset RecordBuffer
                mov     word ptr cs:LS_BufferLen,RecordLen * 2
                jmp     File_LS


; -- Save Record -----------------------

REC_FileSpec    db      'UNTITLED.REC', 67 dup (0)
REC_Ext         db      '.REC',0
SaveRec:        GetLineService _GL_GetSymb
                dec     cl
                or      al,al
                jnz     SR_E0
                GetLineService _GL_ClrBuff
                mov     bx,offset Com_SRecord
                GetLineService _GL_String
                mov     al,' '
                GetLineService _GL_Symbol
                mov     bx,offset REC_FileSpec
                GetLineService _GL_String
                GetLineService _GL_Home
                xor     ch,ch
                mov     cl,4
                mov     cs:GetKeyParams.RK_ErrPtr,offset SR_EnterMes2
                ret
SR_E0:          mov     byte ptr cs:LS_OpenFileF,3Ch
                mov     byte ptr cs:LS_RWfileF,40h
                mov     word ptr cs:LS_ErrPtr,offset RecErrMes_S
                mov     word ptr cs:LS_OkPtr,offset RecMes_S
                mov     word ptr cs:LS_FileSpec,offset REC_FileSpec
                mov     word ptr cs:LS_Ext,offset REC_Ext
                mov     word ptr cs:LS_Buffer,offset RecordBuffer
                mov     word ptr cs:LS_BufferLen,RecordLen * 2
                jmp     File_LS




; *******************************************************************
; **                                                               **
; **                                                               **
; **                     COMMANDS  SUBROUTINES                     **
; **                                                               **
; **                                                               **
; *******************************************************************


; -- Memory Editor ---------------------

EB_ParamsAddr   dw      ?
OldCurLen       db      ?
EB_Commands     db      07h,08h,05h,0Bh,06h,20h
                db      01h,02h,03h,04h,0Dh
                db      18h,0Ch
EB_ComSubrt     dw      EB_Up,EB_Down,EB_Left,EB_Left,EB_Right,EB_Space
                dw      EB_Home,EB_End,EB_PgUp,EB_PgDn,EB_Tab
                dw      EB_Enter,EB_Esc

EB_Init:        push    ax bx
                mov     al,cs:[si].EB_MinUp
                mov     cs:[si].EB_TextCH,al
                mov     al,cs:[si].EB_MinLeft1
                mov     cs:[si].EB_TextCL2,al
                mov     al,cs:[si].EB_MinLeft2
                mov     cs:[si].EB_TextCL1,al
                mov     bx,cs:[si].EB_MemAdr
                mov     ax,cs:[bx]
                mov     cs:[si].EB_Address,ax
                pop     bx ax
                ret

EB_Lcx:         mov     cl,cs:[si].EB_TextCL1
                mov     cs:ScreenIOparams.CursorLen,1
                cmp     cs:[si].EB_TextOrHex,0
                jnz     EB_Lcx1
                mov     cl,cs:[si].EB_TextCL2
                mov     cs:ScreenIOparams.CursorLen,4
EB_Lcx1:        mov     ch,cs:[si].EB_TextCH
                ret

MemoryEditor:   mov     si,cs:EB_ParamsAddr
                mov     al,cs:ScreenIOparams.CursorLen
                mov     cs:OldCurLen,al
                mov     cs:ScreenIOparams.CursorColor,40h
                mov     cs:[si].EB_FirstFl,1
                mov     bx,cs:[si].EB_MemAdr
                GetLineService _GL_GetSymb
                dec     cl
                or      al,al
                jz      EB_Loop0
                call    GetAddress
                mov     cs:[bx],ax
                call    EB_Init

EB_Loop0:       call    EB_Lcx
                mov     ah,0Bh
                call    ReadKey
                mov     di,offset EB_Commands
                mov     cx,offset EB_ComSubrt - offset EB_Commands
                call    CalcCommand
                jc      EB_CallDoIt
                shl     di,1
                call    cs:EB_ComSubrt[di]
                mov     cs:[si].EB_FirstFl,1
                jnc     EB_Loop0

EB_ret:         mov     al,cs:OldCurLen
                mov     cs:ScreenIOparams.CursorLen,al
                GetLineService _GL_ClrBuff
                ret

EB_CallDoIt:    call    EB_DoIt
                jmp     EB_Loop0

EB_DoIt:        push    ax bx di
                cmp     cs:[si].EB_TextOrHex,0
                jnz     EB_DoText
                or      al,20h
                cmp     al,'0'
                jb      EB_DoItRet2
                cmp     al,'9'
                jbe     E_Num
                cmp     al,'a'
                jb      EB_DoItRet2
                cmp     al,'f'
                ja      EB_DoItRet2
                sub     al,27h
E_Num:          sub     al,'0'
                mov     di,cs:[si].EB_Address
                mov     bh,[di]
                test    cs:[si].EB_FirstFl,1
                jz      EB_NotNew
                xor     bh,bh
EB_NotNew:      shl     bh,4
                or      bh,al
                mov     [di],bh
EB_DoItRet:     test    cs:[si].EB_FirstFL,1
                jnz     EB_DoItRet1
                call    EB_Right
EB_DoItRet1:    xor     cs:[si].EB_FirstFl,1
EB_DoItRet2:    pop     di bx ax
                ret

EB_DoText:      mov     di,cs:[si].EB_Address
                or      al,80h
                mov     [di],al
                call    EB_Right
                jmp     EB_DoItRet2


EB_Space:       cmp     cs:[si].EB_TextOrHex,0
                jz      EB_Right
                call    EB_DoIt
                clc
                ret

EB_Right:       push    ax bx cx
                mov     bx,cs:[si].EB_MemAdr
                mov     cl,cs:[si].EB_TextCL2
                mov     al,cs:[si].EB_TextCL1
                mov     ch,cs:[si].EB_TextCH
                cmp     cl,cs:[si].EB_Center
                jne     EB_R0
                inc     cl
                inc     al
EB_R0:          add     cl,3
                inc     al
                cmp     cl,cs:[si].EB_MaxRight1
                ja      EB_R1
                inc     cs:[si].EB_Address
                jmp     EB_R3
EB_R1:          mov     cl,cs:[si].EB_MinLeft1
                mov     al,cs:[si].EB_MinLeft2
                inc     ch
                cmp     ch,cs:[si].EB_MaxDown
                ja      EB_R2
                inc     cs:[si].EB_Address
                jmp     EB_R3
EB_R2:          push    ax
                mov     ax,cs:[bx]
                add     ax,cs:[si].EB_BytesInLine
                mov     cs:[bx],ax
                call    cs:[si].EB_InitBuffProc
                pop     ax
                inc     cs:[si].EB_Address
                mov     ch,cs:[si].EB_MaxDown
EB_R3:          mov     cs:[si].EB_TextCL2,cl
                mov     cs:[si].EB_TextCL1,al
                mov     cs:[si].EB_TextCH,ch
                pop     cx bx ax
                clc
                ret

EB_Left:        push    ax bx cx
                mov     bx,cs:[si].EB_MemAdr
                mov     cl,cs:[si].EB_TextCL2
                mov     al,cs:[si].EB_TextCL1
                mov     ch,cs:[si].EB_TextCH
                sub     cl,3
                dec     al
                mov     ah,cs:[si].EB_Center
                inc     ah
                cmp     cl,ah
                jne     EB_L0
                dec     cl
                dec     al
EB_L0:          cmp     cl,cs:[si].EB_MinLeft1
                jb      EB_L1
                dec     cs:[si].EB_Address
                jmp     EB_L3
EB_L1:          mov     cl,cs:[si].EB_MaxRight1
                mov     al,cs:[si].EB_MaxRight2
                dec     ch
                cmp     ch,cs:[si].EB_MinUp
                jb      EB_L2
                dec     cs:[si].EB_Address
                jmp     EB_L3
EB_L2:          push    ax
                mov     ax,cs:[bx]
                sub     ax,cs:[si].EB_BytesInLine
                mov     cs:[bx],ax
                call    cs:[si].EB_InitBuffProc
                pop     ax
                dec     cs:[si].EB_Address
                mov     ch,cs:[si].EB_MinUp
EB_L3:          mov     cs:[si].EB_TextCL2,cl
                mov     cs:[si].EB_TextCL1,al
                mov     cs:[si].EB_TextCH,ch
                pop     cx bx ax
                clc
                ret

EB_Up:          push    ax bx cx
                mov     bx,cs:[si].EB_MemAdr
                mov     ax,cs:[si].EB_BytesInLine
                call    EB_Lcx
                dec     ch
                cmp     ch,cs:[si].EB_MinUp
                jae     EB_U1
                mov     ch,cs:[si].EB_MinUp
                sub     cs:[bx],ax
                call    cs:[si].EB_InitBuffProc
EB_U1:          sub     cs:[si].EB_Address,ax
EB_U2:          mov     cs:[si].EB_TextCH,ch
                pop     cx bx ax
                clc
                ret

EB_Down:        push    ax bx cx
                mov     bx,cs:[si].EB_MemAdr
                mov     ax,cs:[si].EB_BytesInLine
                call    EB_Lcx
                inc     ch
                cmp     ch,cs:[si].EB_MaxDown
                jbe     EB_D1
                mov     ch,cs:[si].EB_MaxDown
                add     cs:[bx],ax
                call    cs:[si].EB_InitBuffProc
EB_D1:          add     cs:[si].EB_Address,ax
EB_D2:          mov     cs:[si].EB_TextCH,ch
                pop     cx bx ax
                clc
                ret

EB_Tab:         test    cs:[si].EB_TabFlag,1
                jz      EB_TabRet
                xor     cs:[si].EB_TextOrHex,0FFh
                mov     cs:[si].EB_FirstFl,1
EB_TabRet:      clc
                ret

EB_PgUp:        push    bx
                mov     bx,cs:[si].EB_MemAdr
                sub     cs:[si].EB_Address, 4 * 16
                sub     word ptr cs:[bx], 4 * 16
                call    cs:[si].EB_InitBuffProc
                clc
                pop     ax
                ret

EB_PgDn:        push    bx
                mov     bx,cs:[si].EB_MemAdr
                add     cs:[si].EB_Address, 4 * 16
                add     word ptr cs:[bx], 4 * 16
                call    cs:[si].EB_InitBuffProc
                clc
                pop     bx
                ret

EB_Home:        push    ax
                mov     al,cs:[si].EB_MinLeft1
EB_H0:          cmp     cs:[si].EB_TextCL2,al
                je      EB_H1
                call    EB_Left
                jmp     EB_H0
EB_H1:          mov     al,cs:[si].EB_MinUp
EB_H2:          cmp     cs:[si].EB_TextCH,al
                je      EB_H3
                call    EB_Up
                jmp     EB_H2
EB_H3:          pop     ax
                clc
                ret

EB_End:         push    ax
                mov     al,cs:[si].EB_MaxRight1
EB_E0:          cmp     cs:[si].EB_TextCL2,al
                je      EB_E1
                call    EB_Right
                jmp     EB_E0
EB_E1:          mov     al,cs:[si].EB_MaxDown
EB_E2:          cmp     cs:[si].EB_TextCH,al
                je      EB_E3
                call    EB_Down
                jmp     EB_E2
EB_E3:          pop     ax
                clc
                ret

EB_Esc:
EB_Enter:       stc
                ret




; -- Save/Load labels ------------------

LS_Ext          dw      ?
LS_FileSpec     dw      ?
LS_StoreCX      dw      ?
LS_OpenFileF    db      ?
LS_RWfileF      db      ?
LS_ErrPtr       dw      ?
LS_OkPtr        dw      ?
LS_Buffer       dw      ?
LS_BufferLen    dw      ?

File_LS:        call    Prepare4DOS
                push    cx ds
                mov     bx,cs:LS_FileSpec
                mov     dx,79
LAB_LS_0:       GetLineService _GL_GetSymb
                mov     byte ptr cs:[bx],al
                inc     bx
                dec     dx
                jz      LAB_LS_1
                or      al,al
                jnz     LAB_LS_0
LAB_LS_1:       push    ds
                push    cs
                pop     ds
                mov     si,cs:LS_Ext
                mov     di,cs:LS_FileSpec
                call    AddExt
                pop     ds
                mov     cs:LS_StoreCX,cx
                push    cs
                pop     ds
                mov     dx,cs:LS_FileSpec
                xor     cx,cx
                mov     ah,cs:LS_OpenFileF
                xor     al,al
                int     21h
                jc      LAB_LS_Err1
                mov     bx,ax
                mov     dx,cs:LS_Buffer
                mov     cx,cs:LS_BufferLen
                mov     ah,cs:LS_RWfileF
                int     21h
                jc      LAB_LS_Err
                cmp     ax,cx
                jne     LAB_LS_Err
                mov     ah,3Eh
                int     21h
                pop     ds cx
                mov     ax,cs:LS_OkPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                call    SOD4eraperP
                GetLineService _GL_ClrBuff
                clc
                ret
LAB_LS_Err:     mov     ah,3Eh
                int     21h
LAB_LS_Err1:    pop     ds cx
                mov     ax,cs:LS_ErrPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                mov     cx,cs:LS_StoreCX
                call    SOD4eraperP
                inc     cl
                stc
                ret




; -- Hook INT 24h ----------------------

Prepare4DOS:    saveall
                pushf
                mov     cs:FkeysMainFlag,0
                call    ShowAll
                ScreenIOservice _SHOWSCREEN
                call    far ptr SystemTINI
                popf
                restoreall
                ret



; -- Unhook INT 24h --------------------

SOD4eraperP:    saveall                         ; Unchain Critical Errors proc
                pushf
                mov     cs:FkeysMainFlag,1
                mov     ax,Emulate
                mov     es,ax
                mov     byte ptr [C000],0
                call    far ptr SystemINIT
                popf
                restoreall
                ret




; -- ON/OFF ----------------------------

OnOff:          push    ax
                GetLineService _GL_GetSymb
                call    Upcase
                cmp     al,'o'
                jne     OO_Error
                GetLineService _GL_GetSymb
                call    Upcase
                cmp     al,'n'
                je      OO_On
                cmp     al,'f'
                jne     OO_Error
                GetLineService _GL_GetSymb
                call    Upcase
                cmp     al,'f'
                je      OO_Off
OO_Error:       mov     cs:GetKeyParams.RK_ErrPtr,offset OnOffMes
                inc     cl
                stc
                jmp     OO_ret
OO_On:          mov     ax,1
                or      ax,ax
                clc
                jmp     OO_ret
OO_Off:         xor     ax,ax
                clc
OO_ret:         pop     ax
                ret




; *******************************************************************
; **                                                               **
; **                                                               **
; **                        S H O W    A L L                       **
; **                                                               **
; **                                                               **
; *******************************************************************

ShowAllNumber   dw      0
ShowAllProcs    dw      SA_Command,SA_EditA,SA_EditB,SA_Program,SA_Regs,SA_Help,SA_Labels
SA_Command      dw      ShowLabels,ShowProgram,ShowRegs,ShowStack,ShowBreaks,ShowDumpA
                dw      ShowDumpB,ShowFuncKeys,ShowCommand,ShowMessage
                dw      ShowLine,ShowHelp
SA_EditA        dw      ShowLabels,ShowCommand,ShowLine,ShowProgram,ShowMessage,ShowRegs
                dw      ShowStack,ShowBreaks,ShowDumpB,ShowHelp,ShowFuncKeys
                dw      ShowDumpA
SA_EditB        dw      ShowLabels,ShowCommand,ShowLine,ShowProgram,ShowMessage,ShowRegs
                dw      ShowStack,ShowBreaks,ShowDumpA,ShowHelp,ShowFuncKeys
                dw      ShowDumpB
SA_Program      dw      ShowLabels,ShowRegs,ShowStack,ShowBreaks,ShowDumpA,ShowDumpB
                dw      ShowCommand,ShowHelp,ShowFuncKeys
                dw      ShowProgram,ShowLine,ShowMessage
SA_Regs         dw      ShowLabels,ShowCommand,ShowLine,ShowProgram,ShowMessage
                dw      ShowStack,ShowBreaks,ShowDumpA,ShowDumpB,ShowHelp,ShowFuncKeys
                dw      ShowRegs
SA_Help         dw      ShowProgram,ShowRegs,ShowStack,ShowBreaks,ShowDumpA
                dw      ShowDumpB,ShowCommand,ShowMessage,ShowLine,ShowLabels
                dw      ShowHelp,ShowFuncKeys
SA_Labels       dw      ShowStack,ShowBreaks,ShowDumpA,ShowDumpB,ShowCommand,ShowProgram
                dw      ShowMessage,ShowLine,ShowRegs,ShowHelp,ShowFuncKeys
                dw      ShowLabels

ActiveFlags     dw      0
KbdShifts       dw      ?
ShowAll         proc    far
                push    bx dx es ds bp
                push    word ptr cs:ScreenIOparams.CursorColor
                push    word ptr cs:ScreenIOparams.CursorLen
                push    word ptr cs:ScreenIOparams.CursorFlag
                mov     bx,Keyboard
                mov     es,bx
                assume  es:Keyboard
                mov     bx,es:k_Shifts
                mov     cs:KbdShifts,bx
                mov     cs:ScreenIOparams.CursorFlag,1
                mov     bx,Emulate
                mov     es,bx
                mov     bx,Apple
                mov     ds,bx
                mov     dx,12
                mov     bx,cs:ShowAllNumber
                shl     bx,1
                mov     bx,cs:ShowAllProcs[bx]
SA_Loop:        call    cs:[bx]
                add     bx,2
                dec     dx
                jnz     SA_Loop
                pop     word ptr cs:ScreenIOparams.CursorFlag
                pop     word ptr cs:ScreenIOparams.CursorLen
                pop     word ptr cs:ScreenIOparams.CursorColor
                pop     bp ds es dx bx
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
DrawBox:        push    ax
                mov     ax,cx
                add     ax,80 * 2
                mov     cs:DB_CX,ax
                pop     ax
                test    cs:ActiveFlags,ax
                mov     ah,7
                jz      DB_ok1
                mov     ah,0Eh
DB_ok1:         ScreenIOservice _STRINGPRINT
                mov     bx,cs:ScreenIOparams.SP_bx
                dec     dh
                mov     al,dh
                mov     dx,cs:DB_CX
DB_Loop1:       mov     cx,dx
                add     dx,80 * 2
                ScreenIOservice _STRINGPRINT
                dec     al
                jnz     DB_Loop1
                mov     cx,dx
                mov     bx,cs:ScreenIOparams.SP_bx
                ScreenIOservice _STRINGPRINT
                ret



; --------------------------------------------------------------------------
; - SHOW  LINE

ShowLine:       ScreenIOservice _SHOWLINE
                ret

; --------------------------------------------------------------------------
; - SHOW MESSAGE

SM_Dec?         db      0
ShowMessage:    push    ax bx cx
                gotoxy  16,0
                mov     bx,offset SP_Str3
                test    cs:ActiveFlags,0000000000000010b
                mov     ah,0Eh
                jnz     SM_ok1
                mov     ah,7
SM_ok1:         ScreenIOservice _STRINGPRINT
                mov     bx,cs:GetKeyParams.RK_ErrPtr
                or      bx,bx
                jz      SM_Ret
                gotoxy  16,1
                mov     ah,0Ch
                ScreenIOservice _STRINGPRINT
                cmp     cs:SM_Dec?,0
                jz      SM_Ret
                pop     cx
                dec     cl
                push    cx
SM_Ret:         pop     cx bx ax
                ret

FirstMsg        db      1,0Ah,'Appler Debugger, v1.0',0
UnknownCmd      db      'Unknown command',0
IllegalNum      db      'Bad address or number',0
NotHexMes       db      'Hex digit expected',0
NotBinMes       db      'Bin digit expected',0
NotDecMes       db      'Dec digit expected',0
BigNumMes       db      'Address or number is too big',0
NumbMissMes     db      'Address or number expected',0
BadInstr        db      'Bad instruction',0
BadParam        db      'Bad or missing parameter',0
NoStringMes     db      'Search string expected',0
ByteExpMes      db      'Byte expected',0
NotFound        db      'String not found',0
NotIdent        db      'Different byte found',0
Identifical     db      1,0Ah,'Bytes are identical',0
AdressError     db      'End below begin',0
LS_EnterMes1    db      1,0Ah,'<Enter> to load labels',0
LabMes_L        db      1,0Ah,'Labels loaded',0
LabErrMes_L     db      'Error loading labels',0
LS_EnterMes2    db      1,0Ah,'<Enter> to save labels',0
LabMes_S        db      1,0Ah,'Labels saved',0
LabErrMes_S     db      'Error saving labels',0
EqualMess       db      '''='' expected',0
BreakNumMES     db      'Breakpoint number expected',0
SymMissErr      db      'Identifier expected',0
SymNoMemErr     db      'No memory to define this label',0
SymNotFndErr    db      'Label not defined',0
SymNoSymbErr    db      'No labels defined',0
OnOffMes        db      'ON or OFF expected',0
GA_PlusMes      db      1,7,'Carry',0
GA_MinusMes     db      1,7,'Borrow',0
GA_MulMes       db      1,7,'Overflow',0
ZeroDivMes      db      'Division by zero',0
GA_DivMes       db      1,0Ah,'Remainder='
GA_DivRest      db      '0000',1,7,' (truncated)',0
ExecutingMes    db      1,8Ah,'Executing',0
ToRTSmes        db      1,8Ah,'Executing to RTS...',0
InvalidOpcode   db      1,8Ch,'Unexpected Breakpoint',0
BreakpointMes   db      1,0Ch,'Breakpoint '
BreakpointNum   db      '? reached',0
PrintingMes     db      1,8Ah,'Printing',0
PrintOkMes      db      1,0Ah,'Memory Dump Printed OK',0
PrintErrMes     db      'Error printing Memory Dump',0
PrintAsmOkMes   db      1,0Ah,'Program Printed OK',0
PrintAsmErrMes  db      'Error printing Program',0
LR_EnterMes1    db      1,0Ah,'<Enter> to load macro',0
RecMes_L        db      1,0Ah,'Macro loaded',0
RecErrMes_L     db      'Error loading macro',0
SR_EnterMes2    db      1,0Ah,'<Enter> to save macro',0
RecMes_S        db      1,0Ah,'Macro saved',0
RecErrMes_S     db      'Error saving Macro',0
RecPlayedMes    db      1,0Ah,'Macro played',0
RecordedMes     db      1,0Ah,'Macro recorded',0

; --------------------------------------------------------------------------
; - SHOW COMMAND

ShowCommand:    push    ax cx
                gotoxy  17,0
                mov     ax,0700h+'>'
                ScreenIOservice _SYMBPRINT
SCM_Ret:        pop     cx ax
                ret

; --------------------------------------------------------------------------
; - SHOW PROGRAM

AssembAdr       dw      0                       ; This is the start address.
AssembAdr1      dw      0
ShowPrev?       db      0
PrevAdr         dw      ?
SP_Str          db      'ÚProgramÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                               ³',0
SP_Str3         db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SP_CursorXY     dw      401h
ShowProgram:    push    ax bx cx dx si es
                gotoxy  1,0
                mov     bx,offset SP_Str
                mov     dx,0F22h
                mov     ax,0000000000000010b
                call    DrawBox
                test    cs:ShowPrev?,1
                jz      SP_Dont
                gotoxy  3,2
                mov     si,cs:PrevAdr
                call    OneInstr
SP_Dont:        mov     si,cs:AssembAdr
                gotoxy  4,2
                mov     dx,12
                mov     cs:CalcFlag,1
AsmLoop0:       call    OneInstr
                mov     cs:CalcFlag,0
                add     cx,80 * 2
                dec     dx
                jnz     ASMLoop0
                mov     cs:AssembAdr1,si
                mov     cx,cs:SP_CursorXY
                mov     cs:ScreenIOparams.CursorColor,10h
                mov     cs:ScreenIOparams.CursorLen,31
                ScreenIOservice _SHOWCURSOR
                gotoxy  1,1
                mov     ax,0E00h+'P'
                cmp     cs:FkeysMainFlag,0
                jz      SP_Ret
                ScreenIOservice _SYMBPRINT
SP_Ret:         pop     es si dx cx bx ax
                ret
                assume  es:Emulate


; -- Scroll Program Window DOWN --------

UP:             push    cx ax bx si             ; Scrolls ASM window down.
                mov     si,cs:AssembAdr
                call    PrevInstAdr
                jnc     UP_0
                dec     si
UP_0:           mov     cs:AssembAdr,si
                call    PrevInstAdr
                jnc     UP_1
                dec     si
UP_1:           mov     cs:PrevAdr,si
                call    BuffDisasm
                clc
                mov     cs:ShowPrev?,1
                pop     si bx ax cx
                ret


; -- Scroll Program Window UP ----------

DOWN:           push    si ax cx
                mov     si,cs:AssembAdr
                mov     cs:ShowPrev?,1
                mov     cs:PrevAdr,si
                gotoxy  7,2
                call    OneInstr
                mov     cs:AssembAdr,si
                call    BuffDisasm
                pop     cx ax si
                ret


; -- Calc Previous Instruction Adr -----
; Entry:
;  SI  = Start_Address
; Exit:
;  SI  = Previous Instruction Address
;  CF  = 1 if can't or 0 otherwise

PIA_Counter     =       25
PIA_BegAdr      dw      ?
PIA_Adr         dw      ?
PrevInstAdr:    push    ax bx                   ; I: SI -> Address. O: SI <- PrevInstAdr
                mov     cs:PIA_BegAdr,si
                sub     si,PIA_Counter
PIA_Loop0:      mov     cs:PIA_adr,si
PIA_Loop1:      xor     bx,bx
                mov     bl,[si]
                mov     al,cs:InstrLongTbl[bx]
                test    al,00000100b
                jz      PIA_Valid
PIA_Next:       mov     si,cs:PIA_adr
                inc     si
                cmp     si,cs:PIA_BegAdr
                je      PIA_Cannot
                jmp     PIA_Loop0
PIA_Valid:      xor     ah,ah
                and     al,00000011b
                add     ax,si
                cmp     ax,cs:PIA_BegAdr
                ja      PIA_Next
                je      PIA_End
                mov     si,ax
                jmp     PIA_Loop1
PIA_End:        clc
PIA_End1:       pop     bx ax
                ret
PIA_Cannot:     stc
                jmp     PIA_End1


; -- Show Previous Instruction ---------

ShowPrevIns:    push    cx si
                mov     si,cs:AssembAdr
                call    PrevInstAdr
                jnc     SPI_ok
                dec     si
SPI_ok:         mov     cs:ShowPrev?,1
                mov     cs:PrevAdr,si
                pop     si cx
                ret


; -- Show One Instruction --------------
; Entry:
;  SI  = Start_Address
;  CH  = VTAB
; Exit:
;  SI  = Next Instruction Address

OI_ClrStr:      db      '                             ',0
CalcFlag        db      0
OI_StoreCX      dw      ?
OneInstr:       push    ax bx cx dx
                mov     cs:OI_StoreCX,cx
                mov     bx,offset OI_ClrStr
                ScreenIOservice _STRINGPRINT
                xor     ax,ax
                mov     bx,ax
                mov     al,[si]
                mov     bl,al
                add     bx,ax
                add     bx,ax
                mov     ah,0Bh
                mov     cx,cs:OI_StoreCX
                add     cx,0Fh * 2
                mov     al,cs:InstrTable[bx]
                ScreenIOservice _SYMBPRINT
                mov     al,cs:InstrTable[bx+1]
                ScreenIOservice _SYMBPRINT
                mov     al,cs:InstrTable[bx+2]
                ScreenIOservice _SYMBPRINT
                mov     al,' '
                ScreenIOservice _SYMBPRINT
                clc
                mov     ah,07h
                call    CheckBreak
                jc      OI_ok1
                mov     ah,0Ch
OI_ok1:         xor     dl,dl
                xchg    dl,cs:ScreenIOparams.SP_BufFlag
                mov     bx,si
                mov     al,7
                mov     cx,cs:OI_StoreCX
                call    WordPrintS
                mov     ax,0700h+':'
                ScreenIOservice _SYMBPRINT
                mov     cx,cs:OI_StoreCX
                add     cx,8 * 2
                mov     ah,3
                mov     al,[si]
                ScreenIOservice _BYTEPRINT
                xor     bx,bx
                mov     bl,[si]
                mov     ah,03h
                mov     bl,cs:ParamTable[bx]
                shl     bx,1
                mov     byte ptr cs:SC_ShowAdr?,1
                call    word ptr cs:AdrModes[bx]
                call    ShowCalc
                inc     si
OI_RET:         pop     dx cx bx ax
                ret

AdrModes        dw      NoOper,DirVal,ZP,ZPx,Full,FullX,FullY
                dw      BadX,BadY,ZPy,JMP1,JMP6C,NoOper,BEQ,Indirect,JMP7C


; -- Addressing Modes Procs ------------
; Entry:
;  SI  = Address of the first instruction byte
; Exit:
;  BX          = Address to show at the up-right
;  CF          = Show (0) or not (1) the contain of address in BX
;  SC_ShowAdr? = Show (1-default) or not (0) the address in BX
;  SI          = Address of the last instruction byte

NoOper:         stc
                ret

DirVal:         call    PDirVal
                inc     si
                stc
                ret

ZP:             call    PZPadr
                inc     si
                xor     bx,bx
                mov     bl,[si]
                clc
                mov     byte ptr cs:SC_ShowAdr?,0
                ret

ZPx:            call    PZPx
                inc     si
                xor     bx,bx
                mov     bl,[si]
                add     bl,cs:Regs.X
                clc
                ret

Full:           call    PWordAdr
                inc     si
                mov     bx,[si]
                inc     si
                clc
                mov     byte ptr cs:SC_ShowAdr?,0
                ret

FullX:          call    PFullX
                inc     si
                mov     bx,[si]
                inc     si
                xor     ax,ax
                mov     al,cs:Regs.X
                add     bx,ax
                clc
                ret

FullY:          call    PFullY
                inc     si
                mov     bx,[si]
                inc     si
                xor     ax,ax
                mov     al,cs:Regs.Y
                add     bx,ax
                clc
                ret

BadX:           call    PBadX
                inc     si
                mov     bl,[si]
                add     bl,cs:Regs.X
                xor     bh,bh
                mov     al,[bx]
                inc     bl
                mov     ah,[bx]
                mov     bx,ax
                clc
                ret

BadY:           call    PBadY
                inc     si
                xor     bx,bx
                mov     bl,[si]
                mov     al,[bx]
                inc     bl
                mov     ah,[bx]
                mov     bx,ax
                xor     ax,ax
                mov     al,cs:Regs.Y
                add     bx,ax
                clc
                ret

ZPy:            call    PZPy
                inc     si
                xor     bx,bx
                mov     bl,[si]
                add     bl,cs:Regs.Y
                clc
                ret

JMP1:           call    Pwordadr
                inc     si
                inc     si
                stc
                ret

JMP6C:          call    PJ6C
                inc     si
                mov     bx,[si]
                inc     si
                mov     al,[bx]
                inc     bl
                mov     ah,[bx]
                mov     bx,ax
                clc
                ret

BEQ:            call    PBranch
                inc     si
                stc
                ret

Indirect:       call    Pindirect
                inc     si
                mov     bl,[si]
                xor     bh,bh
                mov     al,[bx]
                inc     bl
                mov     ah,[bx]
                mov     bx,ax
                clc
                ret

JMP7C:          call    PJ7C
                inc     si
                mov     bl,cs:Regs.X
                xor     bh,bh
                add     bx,[si]
                mov     al,[bx]
                inc     bl
                mov     ah,[bx]
                mov     bx,ax
                inc     si
                clc
                ret

; -- Print Modes Procs -----------------
; Entry:
;  SI  = Address of the first instruction byte

PrintWORD:      mov     al,[si+1]
                ScreenIOservice _BYTEPRINT
                mov     al,[si+2]
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                mov     cs:ScreenIOparams.SP_BufFlag,dl
                add     cx,5 * 2
                ret

PrintBYTE:      mov     al,[si+1]
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                mov     cs:ScreenIOparams.SP_BufFlag,dl
                add     cx,7 * 2
                ret



PBadX:          call    PrintBYTE
                mov     al,'('
                ScreenIOservice _SYMBPRINT
                mov     al,5
                mov     bl,[si+1]
                call    BytePrintS
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'X'
                ScreenIOservice _SYMBPRINT
                mov     al,')'
                ScreenIOservice _SYMBPRINT
                ret

PBadY:          call    PrintBYTE
                mov     al,'('
                ScreenIOservice _SYMBPRINT
                mov     al,5
                mov     bl,[si+1]
                call    BytePrintS
                mov     al,')'
                ScreenIOservice _SYMBPRINT
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'Y'
                ScreenIOservice _SYMBPRINT
                ret

PZPadr:         call    PrintBYTE
                mov     al,9
                mov     bl,[si+1]
                jmp     BYTEPRINTS

PDirVal:        call    PrintBYTE
                mov     al,'#'
                ScreenIOservice _SYMBPRINT
                mov     al,[si+1]
                ScreenIOservice _BYTEPRINT
                ret

PZPx:           call    PrintBYTE
                mov     al,7
                mov     bl,[si+1]
                call    BytePrintS
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'X'
                ScreenIOservice _SYMBPRINT
                ret

PZPy:           call    PrintBYTE
                mov     al,7
                mov     bl,[si+1]
                call    BytePrintS
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'Y'
                ScreenIOservice _SYMBPRINT
                ret

PWordAdr:       call    PrintWORD
                mov     al,10
                mov     bx,[si+1]
                jmp     WordPrintS

PFullX:         call    PrintWORD
                mov     al,8
                mov     bx,[si+1]
                call    WordPrintS
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'X'
                ScreenIOservice _SYMBPRINT
                ret

PFullY:         call    PrintWORD
                mov     al,8
                mov     bx,[si+1]
                call    WordPrintS
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'Y'
                ScreenIOservice _SYMBPRINT
                ret

PJ6C:           call    PrintWORD
                mov     al,'('
                ScreenIOservice _SYMBPRINT
                mov     al,8
                mov     bx,[si+1]
                call    WordPrintS
                mov     al,')'
                ScreenIOservice _SYMBPRINT
                ret

PBranch:        call    PrintBYTE
                push    bx si
                mov     al,[si+1]
                cbw
                inc     si
                inc     si
                add     ax,si
                mov     bx,ax
                mov     ax,0B0Ah
                call    WordPrintS
                pop     si bx
                ret

Pindirect:      call    PrintBYTE
                mov     al,'('
                ScreenIOservice _SYMBPRINT
                mov     al,5
                mov     bl,[si+1]
                call    BytePrintS
                mov     al,')'
                ScreenIOservice _SYMBPRINT
                ret

PJ7C:           call    PrintWORD
                mov     al,'('
                ScreenIOservice _SYMBPRINT
                mov     al,8
                mov     bx,[si+1]
                call    WordPrintS
                mov     al,','
                ScreenIOservice _SYMBPRINT
                mov     al,'X'
                ScreenIOservice _SYMBPRINT
                mov     al,')'
                ScreenIOservice _SYMBPRINT
                ret


; -- Show address at up-rt corner ------
; Entry:
;  BX          = Address to show at the up-right
;  CF          = Show (0) or not (1) the contain of address in BX
;  SC_ShowAdr? = Show (1-default) or not (0) the address in BX

SC_Clear        db      1,7,'       ',0
SC_ShowAdr?     db      ?
SC_Length       db      ?
ShowCalc:       mov     cs:ScreenIOparams.SP_BufFlag,0
                push    ax cx dx bx
                gotoxy  2,18h
                mov     bx,offset SC_Clear
                jnc     SC_1
                cmp     byte ptr cs:CalcFlag,0
                jz      SC_ret
                ScreenIOservice _STRINGPRINT
                jmp     SC_ret
SC_1:           cmp     byte ptr cs:CalcFlag,0
                jz      SC_ret
                ScreenIOservice _STRINGPRINT
                pop     bx
                push    bx
                gotoxy  2,18h
                mov     ah,3
                cmp     byte ptr SC_ShowAdr?,0
                jz      SC_NoAdr
                mov     al,bh
                ScreenIOservice _BYTEPRINT
                mov     al,bl
                ScreenIOservice _BYTEPRINT
                mov     al,':'
                ScreenIOservice _SYMBPRINT
SC_NoAdr:       gotoxy  2,1Dh
                mov     al,[bx]
                ScreenIOservice _BYTEPRINT
SC_ret:         pop     bx dx cx ax
                ret

; --------------------------------------------------------------------------
; - SHOW  REGS

SR_Str          db      ' ÚRegistersÄ¿ ',0
                db      ' ³          ³ ',0
                db      ' ÀÄÄÄÄÄÄÄÄÄÄÙ ',0
SR_StrA         db      1,7,'A = ',0
SR_StrX         db      1,7,'X = ',0
SR_StrY         db      1,7,'Y = ',0
SR_StrP         db      1,7,'P = ',0
SR_StrS         db      1,7,'S = ',0
SR_StrPC        db      1,7,'PC= ',0
RegStruc        struc
A               db      ?
X               db      ?
Y               db      ?
S               db      ?
P               db      ?
PC              dw      ?
RegStruc        ends
Regs            RegStruc <0,0,0,0,0,0>
FlagSymbs       db      'NVúBDIZC'

ShowRegs:       push    ax bx cx dx
                gotoxy  1,21h
                mov     bx,offset SR_Str
                mov     dx,90Dh
                mov     ax,0000000000000100b
                call    DrawBox
                mov     ah,0Bh
                gotoxy  4,24h
                mov     bx,offset SR_StrA
                ScreenIOservice _STRINGPRINT
                mov     al,cs:Regs.A
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                gotoxy  5,24h
                mov     bx,offset SR_StrX
                ScreenIOservice _STRINGPRINT
                mov     al,cs:Regs.X
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                gotoxy  6,24h
                mov     bx,offset SR_StrY
                ScreenIOservice _STRINGPRINT
                mov     al,cs:Regs.Y
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                gotoxy  7,24h
                mov     bx,offset SR_StrP
                ScreenIOservice _STRINGPRINT
                mov     al,cs:Regs.P
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                gotoxy  8,24h
                mov     bx,offset SR_StrS
                ScreenIOservice _STRINGPRINT
                mov     al,cs:Regs.S
                ScreenIOservice _BYTEPRINT
                gotoxy  9,24h
                mov     bx,offset SR_StrPC
                ScreenIOservice _STRINGPRINT
                mov     al,byte ptr cs:Regs.PC[1]
                ScreenIOservice _BYTEPRINT
                mov     al,byte ptr cs:Regs.PC
                ScreenIOservice _BYTEPRINT
                mov     ah,0Bh
                mov     dl,cs:Regs.P
                xor     bx,bx
                gotoxy  3,24h
FlagsLoop0:     mov     ah,3
                shl     dl,1
                jnc     ClearFlag
                mov     ah,0Bh
ClearFlag:      mov     al,cs:FlagSymbs[bx]
                ScreenIOservice _SYMBPRINT
                inc     bx
                cmp     bx,8
                jb      FlagsLoop0
                gotoxy  1,23h
                mov     ax,0E00h+'R'
                cmp     cs:FkeysMainFlag,0
                jz      SR_Ret
                ScreenIOservice _SYMBPRINT
SR_Ret:         pop     dx cx bx ax
                ret

; --------------------------------------------------------------------------
; - SHOW STACK

SS_Str          db      ' ÚStackÄÄÄÄÄ¿ ',0
                db      ' ³          ³ ',0
                db      ' ÀÄÄÄÄÄÄÄÄÄÄÙ ',0
SS_1            db      '+1: ',0
SS_3            db      '+3: ',0
SS_5            db      '+5: ',0
SS_7            db      '+7: ',0
SS_StoreCX      dw      ?
ShowStack:      push    ax bx cx dx si
                gotoxy  0Bh,21h
                mov     bx,offset SS_Str
                mov     dx,60Dh
                mov     ax,0000000000001000b
                call    DrawBox
                mov     bx,101h
                add     bl,cs:Regs.S
                mov     si,offset SS_1
                gotoxy  0Dh,24h
                mov     cs:SS_StoreCX,cx
                mov     dx,4
SS_Loop1:       mov     ah,7
                xchg    bx,si
                ScreenIOservice _STRINGPRINT
                add     bx,5
                xchg    si,bx
                mov     ah,3
                inc     bl
                mov     al,ds:[bx]
                ScreenIOservice _BYTEPRINT
                dec     bl
                mov     al,ds:[bx]
                ScreenIOservice _BYTEPRINT
                add     bl,2
                add     cs:SS_StoreCX,80 * 2
                mov     cx,cs:SS_StoreCX
                dec     dx
                jnz     SS_Loop1
                pop     si dx cx bx ax
                ret

; --------------------------------------------------------------------------
; - SHOW  BREAKS

SB_Str          db      'ÚBreakpointsÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                               ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
Breakpoint      struc
BP_Address      dw      ?
BP_ByteStorage  db      ?
BP_ActiveFlag   db      ?
BP_FlashFlag    db      ?
BP_PrintXY      dw      ?
                ends

BreakPoints     Breakpoint <0,?,0,0,?>
                Breakpoint <0,?,0,0,2*80*2+49*2>
                Breakpoint <0,?,0,0,3*80*2+49*2>
                Breakpoint <0,?,0,0,4*80*2+49*2>
                Breakpoint <0,?,0,0,2*80*2+64*2>
                Breakpoint <0,?,0,0,3*80*2+64*2>
                Breakpoint <0,?,0,0,4*80*2+64*2>

ShowBreaks:     push    ax bx cx dx si
                gotoxy  1,2Fh
                mov     bx,offset SB_Str
                mov     dx,522h
                mov     ax,0000000000010000b
                call    DrawBox
                mov     si,7
                mov     dx,600h
SB_Loop:        mov     ah,7
                test    cs:Breakpoints[si].BP_ActiveFlag,1
                jz      SB_ok1
                mov     ah,0Ch
                test    cs:Breakpoints[si].BP_FlashFlag,1
                jz      SB_ok1
                mov     ah,8Ch
                mov     cs:Breakpoints[si].BP_FlashFlag,0
SB_ok1:         mov     cx,cs:Breakpoints[si].BP_PrintXY
                mov     al,'B'
                ScreenIOservice _SYMBPRINT
                mov     al,dl
                add     al,'0'+1
                ScreenIOservice _SYMBPRINT
                mov     ax,700h+':'
                ScreenIOservice _SYMBPRINT
                add     cx,2
                mov     bx,cs:Breakpoints[si].BP_Address
                mov     ax,30Ah
                call    WordPrintS
                inc     dl
                add     si,7
                dec     dh
                jnz     SB_Loop
                pop     si dx cx bx ax
                ret

; --------------------------------------------------------------------------
; - SHOW  DUMP A

SDA_Str         db      'ÚMemory Dump BÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                               ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SDA_NumStr      db      '0123456789ABCDEF'
SDA_Address     dw      0
SDA_StoreCX     dw      ?
ShowDumpA:      push    ax bx cx dx si
                gotoxy  7,2Fh
                mov     bx,offset SDA_Str
                mov     dx,0A22h
                mov     ax,0000000000100000b
                call    DrawBox
                mov     bx,cs:SDA_Address
                and     bx,000Fh
                gotoxy  8,38h
                mov     dl,8
                mov     ah,7
SDA_NumbLoop:   mov     al,cs:SDA_NumStr[bx]
                ScreenIOservice _SYMBPRINT
                inc     bx
                and     bx,0Fh
                add     cx,4
                dec     dl
                jnz     SDA_NumbLoop
                gotoxy  9,31h
                mov     SDA_StoreCX,cx
                mov     bx,cs:SDA_Address
                xor     si,si
                mov     dh,8
SDA_Loop0:      mov     ah,7
                mov     al,bh
                ScreenIOservice _BYTEPRINT
                mov     al,bl
                ScreenIOservice _BYTEPRINT
                mov     al,':'
                ScreenIOservice _SYMBPRINT
                mov     dl,8
SDA_Loop1:      add     cx,2
                mov     al,ds:[bx]
                cmp     al,cs:BufferA[si]
;               mov     cs:BufferA[si],al
                mov     ah,0Bh
                jne     SDA_NotSame
                mov     ah,3
SDA_NotSame:    ScreenIOservice _BYTEPRINT
                inc     bx
                inc     si
                dec     dl
                jnz     SDA_Loop1
                add     cs:SDA_StoreCX,80 * 2
                mov     cx,cs:SDA_StoreCX
                dec     dh
                jnz     SDA_Loop0
                cmp     cs:EB_Flag,0
                jz      SDA_Ret
                cmp     cs:FkeysMainFlag,0
                jz      SDA_Ret
                gotoxy  7,30h
                mov     ax,0E00h+'M'
                ScreenIOservice _SYMBPRINT
SDA_Ret:        pop     si dx cx bx ax
                ret

; --------------------------------------------------------------------------
; - SHOW  DUMP B

SDB_Str         db      'ÚMemory Dump AÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                                                              ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SDB_NumStr      db      '0123456789ABCDEF'
SDB_Address     dw      0
SDB_Count1      db      ?
SDB_1:          add     cx,2
                add     di,2
                jmp     SDB_1_ret
ShowDumpB:      push    ax bx cx dx si di
                gotoxy  12h,00h
                mov     bx,offset SDB_Str
                mov     dx,651h
                mov     ax,0000000001000000b
                call    DrawBox
                mov     bx,cs:SDB_Address
                and     bx,000Fh
                gotoxy  13h,3Dh
                mov     di,cx
                gotoxy  13h,0Ah
                mov     dx,10h
                mov     si,8
                mov     ah,7
SDB_NumbLoop:   mov     al,cs:SDB_NumStr[bx]
                ScreenIOservice _SYMBPRINT
                add     cx,4
                xchg    di,cx
                ScreenIOservice _SYMBPRINT
                xchg    di,cx
                dec     si
                jz      SDB_1
SDB_1_ret:      inc     bx
                and     bx,0Fh
                dec     dx
                jnz     SDB_NumbLoop
                gotoxy  14h,3Dh
                mov     dx,cx
                gotoxy  14h,2
                mov     si,cs:SDB_Address
                xor     di,di
                mov     cs:SDB_Count1,4
SDB_Loop0:      mov     ah,7
                mov     bx,si
                mov     al,bh
                ScreenIOservice _BYTEPRINT
                mov     al,bl
                ScreenIOservice _BYTEPRINT
                mov     al,':'
                ScreenIOservice _SYMBPRINT
                add     cx,4
                mov     bx,1008h
SDB_Loop1:      mov     al,ds:[si]
                cmp     al,cs:BufferB[di]
;               mov     cs:BufferB[di],al
                mov     ah,0Bh
                jne     SDB_NotSame
                mov     ah,3
SDB_NotSame:    ScreenIOservice _BYTEPRINT
                xchg    cx,dx
                xor     ah,ah
                xchg    di,ax
                shl     di,1
                mov     bp,ss:TextChars[di]
                xchg    di,ax
                mov     ax,bp
                ScreenIOservice _SYMBPRINT
                xchg    cx,dx
                add     cx,2
                dec     bl
                jz      SDB_2
SDB_2_ret:      inc     si
                inc     di
                dec     bh
                jnz     SDB_Loop1
                add     cx,24*2
                add     dx,63*2
                dec     cs:SDB_Count1
                jnz     SDB_Loop0
                cmp     cs:EB_Flag,0
                jnz     SDB_Ret
                cmp     cs:FkeysMainFlag,0
                jz      SDB_Ret
                gotoxy  12h,1
                mov     ax,0E00h+'M'
                ScreenIOservice _SYMBPRINT
SDB_Ret:        pop     di si dx cx bx ax
                ret
SDB_2:          add     cx,2
                add     dx,2
                jmp     SDB_2_ret

; --------------------------------------------------------------------------
; - SHOW FUNCTION KEYS

SFK_None        db      '      ',0
SFK_Cont        db      'Apple ',0
SFK_Animat      db      'Animat',0
SFK_Trace       db      'Trace ',0
SFK_Step        db      'Step  ',0
SFK_GoTo        db      'Run to',0
SFK_GoToRTS     db      'To RTS',0
SFK_View        db      'View  ',0
SFK_HelpON      db      'Help  ',0
SFK_HelpOFF     db      'CloseH',0
SFK_HelpUp      db      'Help ',0
SFK_HelpDown    db      'Help ',0
SFK_Stop        db      'Stop  ',0

SFK_Str         db      '1       2       3       4       5       '
                db      '6       7       8       9      10       ',0

FkeyStruc       struc
FkeyFlag        db      ?
FkeyLabel       dw      ?
FkeyProc        dw      ?
FkeyStruc       ends
FkeysMainFlag   db      1
FkeysBuffer     FkeyStruc <1, SFK_Cont,     GK_Cont    >
                FkeyStruc <1, SFK_Animat,   GK_Animat  >
                FkeyStruc <1, SFK_Step,     GK_Step    >
                FkeyStruc <1, SFK_Trace,    GK_Trace   >
                FkeyStruc <1, SFK_GoTo,     GK_GoTo    >
                FkeyStruc <1, SFK_GoToRTS,  GK_ToRTS   >
                FkeyStruc <1, SFK_View,     GK_View    >
                FkeyStruc <0, SFK_HelpUp,   GK_HelpUp  >
                FkeyStruc <0, SFK_HelpDown, GK_HelpDown>
                FkeyStruc <1, SFK_HelpOn,   GK_Help    >

ShowFuncKeys:   push    ax bx cx dx si di
                gotoxy  19h,0
                mov     bx,offset SFK_Str
                mov     ah,7
                ScreenIOservice _STRINGPRINT
                gotoxy  19h,1
                xor     si,si
                mov     di,10
                mov     dx,484Fh
                cmp     cs:FkeysMainFlag,0
                jnz     SFK_Loop
                mov     dx,4848h
SFK_Loop:       mov     bx,cs:FkeysBuffer[si].FkeyLabel
                mov     ah,dh
                cmp     cs:FkeysBuffer[si].FkeyFlag,0
                jz      SFK_ok1
                mov     ah,dl
SFK_ok1:        ScreenIOservice _STRINGPRINT
                add     cx,4
                add     si,size FkeyStruc
                dec     di
                jnz     SFK_Loop
                pop     di si dx cx bx ax
                ret

; --------------------------------------------------------------------------
; - SHOW HELP

SH_CX           dw      376h
HelpFlag        db      0
HelpAddr        dw      ?
HelpPtr         dw      ?
MinHelpPtr      dw      ?
MaxHelpPtr      dw      ?
SH_Str          db      'ÚHelpÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                   ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
Helps           label   byte
                db      ' ',0

SH_MoveHelp     db      ' ',0,' ',0,' ',0
                db      1,7,'   Use <',1,0Fh,'',1,7,'> keys to move Help',0
                db      ' ',0
                db      1,7,'     Press <',1,0Fh,'Enter',1,7,'> when done ',0,0

SH_ComHelp0     db      'Supported Commands List:',0
                db      ' ',0
                db      'REGS',1,7,' -edit registers',0
                db      '<reg> =<value>',1,7,' -change register',0
                db      ' ',0
                db      'D <addr>',1,7,' -disassemble',0
                db      'DA <addr>',1,7,' -dump A',0
                db      'DB <addr>',1,7,' -dump B',0
                db      'ASM [<addr>]',1,7,' -assembler mode',0
                db      'EA [<addr>]',1,7,' -edit dump A',0
                db      'EB [<addr>]',1,7,' -edit dump B',0
                db      ' ',0
                db      '[ <beg>,<end>]',1,7,' -set {margins}',0
                db      'FIND [<byte>,..][''st'',..]["st",..]',0
                db      1,7,'  -find string in {margins}',0
                db      'COPY <addr>',1,7,' -copy {margins}',0
                db      'COMP <addr>',1,7,' -compare {margins}',0
                db      'PDUMP [<FileName>]',0
                db      1,7,'  -Print Memory Dump',0
                db      'PASM [<FileName>]',0
                db      1,7,'  -Print Disassembled Dump',0
                db      ' ',0
                db      'BREAK<1..6>=<addr>',1,7,' -set breakpoint',0
                db      'GO [<start>][,<stop>]',1,7,' -execute',0
                db      ' ',0
                db      '. <Identifier>=<addr>',0
                db      1,7,'  -define label',0
                db      'LIST',1,7,' -defined labels list',0
                db      'DL <identifier>',1,7,' -delete label',0
                db      'LAB <ON>|<OFF>',1,7,' -labels activity',0
                db      'LL <FileName>',1,7,' -load labels',0
                db      'SL <FileName>',1,7,' -save labels',0
                db      ' ',0

                db      'RECORD [f]',1,7,' macro',0
                db      'STOP',1,7,' -stop recording',0
                db      'PLAY [<FileName>]',1,7,' -play macro',0
                db      'LM <FileName>',1,7,' -load macro',0
                db      'SM <FileName>',1,7,' -save macro',0
                db      ' ',0

                db      '? <expression>[,h][,d][,b]',0
                db      1,7,'  -evaluate expression',0
                db      'SWAP <TimerTicks>',1,7,' -scr swapping',0
                db      'SOUND <ON>|<OFF>',0
                db      'RESET',1,7,' -cold reset APPLE',0

                db      'Assembler Mode',0
                db      ' ',0
                db      1,7,'Enter 65C02 statements,<',1,0Fh,'Esc',1,7,'> Exit',0
                db      ' ',0
                db      'Examples:',0
                db      1,7,'  LDA (77),Y ',0
                db      1,7,'  BIT C000',0
                db      1,7,'  BPL 17FF',0,0

                db      'Memory Dump B Editor',0
                db      ' ',0
                db      1,7,'Enter hex numbers, <',1,0Fh,'Esc',1,7,'> Exit',0
                db      ' ',0
                db      1,7,'Use "',1,0Fh,'EB <addr>',1,7,'" command to change',0
                db      1,7,'dump address',0,0

                db      'Memory Dump A Editor',0
                db      ' ',0
                db      1,7,'Enter hex numbers or chars.',0
                db      1,7,'Press <',1,0Fh,'Tab',1,7,'> to swap entry area.',0
                db      1,7,'Use "',1,0Fh,'EA <addr>',1,7,'" command to change',0
                db      1,7,'dump address',0
                db      ' ',0
                db      1,7,'Press <',1,0Fh,'Esc',1,7,'> to Exit',0,0

                db      'Registers Editor',0
                db      ' ',0
                db      1,7,'Select register with <',1,0Fh,'',1,7,'>, then',0
                db      1,7,'enter hexadecimal value or press',0
                db      1,7,'<',1,0Fh,'Space',1,7,'> to flip a flag.',0
                db      ' ',0
                db      1,7,'Press <',1,0Fh,'Esc',1,7,'> to Exit.',0,0

                db      'View Labels',0
                db      ' ',0
                db      1,7,'Use <',1,0Fh,'',1,7,'>,<',1,0Fh,'PgUp',1,7,'>,<',1,0Fh,'PgDn',1,7,'> to move.',0
                db      ' ',0
                db      1,7,'Press <',1,0Fh,'Esc',1,7,'> to Exit.',0,0

ShowHelp:       test    cs:HelpFlag,1
                jz      SH_Ret
                push    ax bx cx dx
                mov     cx,cs:SH_CX
                mov     bx,offset SH_Str
                mov     dx,0C26h
                mov     ax,0000000010000000b
                call    DrawBox
SH_ok:          mov     bx,cs:HelpAddr
                mov     dx,cs:SH_CX
                add     dx,(80*2*2)+4
                mov     al,10
SH_Loop:        mov     cx,dx
                add     dx,80*2
                mov     ah,0Fh
                ScreenIOservice _STRINGPRINT
                mov     bx,cs:ScreenIOparams.SP_bx
                cmp     byte ptr cs:[bx],0
                jz      SH_Ret0
                dec     al
                jnz     SH_Loop
SH_Ret0:        mov     cx,cs:SH_CX
                add     cx,2
                mov     ax,0E00h+'H'
                cmp     cs:FkeysMainFlag,0
                jz      SH_Ret1
                ScreenIOservice _SYMBPRINT
SH_Ret1:        pop     dx cx bx ax
SH_Ret:         ret


SH_Calculate:   push    bx dx
                mov     bx,offset Helps
                mov     dx,cs:HelpPtr
SH_Loop0:       cmp     byte ptr cs:[bx],0
                jz      SH_EOL
                inc     bx
                jmp     SH_Loop0
SH_EOL:         inc     bx
                dec     dx
                jnz     SH_Loop0
                mov     cs:HelpAddr,bx
                pop     dx bx
                ret

SH_Choose:      mov     cs:HelpPtr,ax
                mov     cs:MinHelpPtr,ax
                mov     cs:MaxHelpPtr,bx
                call    SH_Calculate
                ret

; --------------------------------------------------------------------------
; - SHOW LABS

SL_Flag         db      0
SL_Ptr          dw      0
SL_CX           dw      ?
SL_Str          db      'ÚDefined Labels ListÄÄÄÄÄÄÄ¿',0
                db      '³                          ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
ShowLabels:     test    cs:SL_Flag,1
                jz      SL_Ret
                push    ax bx cx dx si di
                gotoxy  7,12
                mov     bx,offset SL_Str
                mov     dx,0C1Dh
                mov     ax,0000000100000000b
                call    DrawBox
                mov     di,10
                mov     bx,SL_Ptr
                mov     si,bx
                shl     si,1
                mov     dx,19
                gotoxy  9,14
                mov     cs:SL_CX,cx
SL_Loop:        mov     cx,cs:SL_CX
                call    PrintSymbol
                mov     cx,cs:SL_CX
                add     cs:SL_CX,80*2
                add     cx,20 * 2
                mov     ah,3
                mov     al,byte ptr cs:SymbVal[si+1]
                ScreenIOservice _BYTEPRINT
                mov     al,byte ptr cs:SymbVal[si]
                ScreenIOservice _BYTEPRINT
                add     si,2
                inc     bx
                cmp     bx,cs:SymbValPtr
                jae     SL_Ret1
                dec     di
                jnz     SL_Loop
SL_Ret1:        pop     di si dx cx bx ax
SL_Ret:         ret
; --------------------------------------------------------------------------



; *******************************************************************
; **                                                               **
; **                                                               **
; **                   P R I N T   S E R V I C E S                 **
; **                                                               **
; **                                                               **
; *******************************************************************

WordPrintS:     push    ax bx
                call    WordPrint
                jnc     WPS_ret
                mov     al,bh
                ScreenIOservice _BYTEPRINT
                mov     al,bl
                ScreenIOservice _BYTEPRINT
WPS_ret:        pop     bx ax
                ret



BYTEPRINTS:     push    ax bx
                xor     bh,bh
                call    WordPrint
                jnc     BPS_ret
                mov     al,bl
                ScreenIOservice _BYTEPRINT
BPS_ret:        pop     bx ax
                ret



WordPrintFl     db      1
WP_al           db      ?

WordPrint:      push    ax bx dx di es cx         ; Print a word
                push    cs
                pop     es                        ; Input:
                test    byte ptr cs:WordPrintFl,1 ;   BX-word to print
                jz      WP_1                      ;   AH-attr, CL-htab, CH-vtab
                mov     di,offset SymbVal         ;   AL-length
                cld
                mov     cx,cs:SymbValPtr
                cmp     cx,0
                jz      WP_1
                push    ax
                mov     ax,bx
                repne   scasw
                pop     ax
                jne     WP_1
                sub     di,offset SymbVal + 2
                mov     bx,di
                shr     bx,1
                pop     cx
                xor     dx,dx
                mov     dl,al
                mov     cs:WP_al,al
                call    PrintSymbol
                clc
                jmp     WP_ret

WP_1:           stc
                pop     cx
WP_ret:         pop     es di dx bx ax
                ret



; *******************************************************************
; **                                                               **
; **                                                               **
; **                      G E T   A D D R E S S                    **
; **                                                               **
; **                                                               **
; *******************************************************************

GAdd_Oper       db      '+-*/|^&<>'
GAdd_DoOper     dw      GA_Plus,GA_Minus,GA_Multiply,GA_Divide
                dw      GA_Or,GA_Xor,GA_And,GA_Shl,GA_Shr
GAdd_cx         dw      ?

GetAddress:     push    bx dx di
                call    GetAdr
                jc      GAdd_Error
GAdd_0:         mov     bx,ax
                GetLineService _GL_GetSymb
                push    cx
                mov     di,offset GAdd_Oper
                mov     cx,offset GAdd_DoOper - offset GAdd_Oper
                call    CalcCommand
                pop     cx
                jnc     GAdd_1
                mov     ax,bx
                pop     di dx bx
                ret

GAdd_Error:     pop     di dx bx ax
                ret

GAdd_1:         mov     cs:GAdd_cx,cx
                call    GetAdr
                jc      GAdd_Error
                shl     di,1
                xchg    ax,bx
                call    word ptr cs:GAdd_DoOper[di]
                jc      GAdd_0
                mov     cs:GetKeyParams.RK_ErrPtr,0
                jmp     GAdd_0

GA_Plus:        add     ax,bx
                mov     cs:GetKeyParams.RK_ErrPtr,offset GA_PlusMes
                ret

GA_Minus:       sub     ax,bx
                mov     cs:GetKeyParams.RK_ErrPtr,offset GA_MinusMes
                ret

GA_Multiply:    mul     bx
                mov     cs:GetKeyParams.RK_ErrPtr,offset GA_MulMes
                ret

GA_Divide:      push    dx
                xor     dx,dx
                cmp     bx,0
                jz      GA_ZeroDiv
                cmp     ax,bx
                jb      GA_DivRet
GA_DivLoop:     sub     ax,bx
                jc      GA_DivOk
                inc     dx
                jmp     GA_DivLoop
GA_DivOk:       add     ax,bx
                or      ax,ax
                clc
                jz      GA_DivRet

                push    dx
                mov     dx,ax
                mov     bx,3
GA_DivLoop00:   mov     al,dl
                shr     dx,4
                and     al,0Fh
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                mov     cs:GA_DivRest[bx],al
                dec     bx
                jns     GA_DivLoop00
                pop     dx
                stc
                mov     cs:GetKeyParams.RK_ErrPtr,offset GA_DivMes

GA_DivRet:      mov     ax,dx
                pop     dx
                ret

GA_ZeroDiv:     mov     cs:GetKeyParams.RK_ErrPtr,offset ZeroDivMes
                pop     dx di
                mov     cx,cs:GAdd_cx
                inc     cl
                jmp     GAdd_Error

GA_Or:          or      ax,bx
                clc
                ret

GA_Xor:         xor     ax,bx
                clc
                ret

GA_And:         and     ax,bx
                clc
                ret

GA_Shl:         push    cx
                mov     cl,bl
                shl     ax,cl
                pop     cx
                ret

GA_Shr:         push    cx
                mov     cl,bl
                shr     ax,cl
                pop     cx
                clc
                ret



Delimiters_C    =       19
Delimiters      db      '{[()]}/,=+-*/|^&<>',0
GAd_Sym         db      'rxysp.%@'
GAd_Sub         dw      GAd_A, GAd_X, GAd_Y, GAd_S, GAd_P
                dw      GAd_Label, GAd_Bin, GAd_Dec, GAd_Hex
GAd_Flag        db      ?

GetAdr:         push    bx di cx
                GetLineService _GL_GetSymb
                mov     di,offset GAd_Sym
                mov     cx,offset GAd_Sub - offset GAd_Sym
                call    CalcCommand
                pop     cx
                jnc     GAd_NotHex
                mov     di,8
GAd_NotHex:     shl     di,1
                call    word ptr cs:GAd_Sub[di]
                jc      GAd_Ret
                dec     cl
                mov     ax,bx
                mov     cs:GetKeyParams.RK_ErrPtr,0
                clc

GAd_Ret:        pop     di bx
                ret


GAd_A:          xor     bx,bx
                mov     bl,cs:Regs.A
                GetLineService _GL_GetSymb
                GetLineService _GL_GetSymb
                ret

GAd_X:          xor     bx,bx
                mov     bl,cs:Regs.X
                GetLineService _GL_GetSymb
                GetLineService _GL_GetSymb
                ret

GAd_Y:          xor     bx,bx
                mov     bl,cs:Regs.Y
                GetLineService _GL_GetSymb
                GetLineService _GL_GetSymb
                ret

GAd_S:          xor     bx,bx
                mov     bl,cs:Regs.S
                GetLineService _GL_GetSymb
                GetLineService _GL_GetSymb
                ret

GAd_P:          GetLineService _GL_GetSymb
                GetLineService _GL_GetSymb
                call    Upcase
                cmp     al,'c'
                je      Gad_PC
                xor     bx,bx
                mov     bl,cs:Regs.P
                ret

GAd_PC:         mov     bx,cs:Regs.PC
                GetLineService _GL_GetSymb
                ret


GAd_Label:      GetLineService _GL_GetSymb
                call    SymbGetVal
                jc      GAd_Lerror
                mov     cx,cs:SGV_cx
                mov     bx,ax
                inc     cl
                clc
                ret
GAd_Lerror:     inc     cl
                stc
                ret

GAd_Hex:        mov     byte ptr cs:GAd_Flag,0
                xor     bx,bx
GetLoop0:       GetLineService _GL_GetSymb
                push    cx
                mov     di,offset Delimiters
                mov     cx,Delimiters_C
                call    CalcCommand
                pop     cx
                jnc     GAd_Hret
                call    Upcase
                cmp     al,'0'
                jb      GAd_Herror
                cmp     al,'9'
                jbe     Anumb
                cmp     al,'a'
                jb      GAd_Herror
                cmp     al,'f'
                ja      GAd_Herror
                sub     al,27h
Anumb:          sub     al,'0'
OkNum:          shl     bx,1
                jc      GAd_Oj
                shl     bx,1
                jc      GAd_Oj
                shl     bx,1
                jc      GAd_Oj
                shl     bx,1
                jc      GAd_Oj
                or      bl,al
                mov     byte ptr cs:GAd_Flag,1
                jmp     GetLoop0

GAd_Hret:       test    byte ptr cs:GAd_Flag,1
                jz      GAd_Nj
                clc
                ret

GAd_Herror:     mov     cs:GetKeyParams.RK_ErrPtr,offset NotHexMes
                stc
                ret

GAd_Oj:         jmp     GAd_Overflow

GAd_Nj:         jmp     GAd_NumbMiss


GAd_Bin:        mov     byte ptr cs:GAd_Flag,0
                GetLineService _GL_GetSymb
                xor     bx,bx
GetLoop1:       GetLineService _GL_GetSymb
                push    cx
                mov     di,offset Delimiters
                mov     cx,Delimiters_C
                call    CalcCommand
                pop     cx
                jnc     GAd_Bret
                sub     al,'0'
                cmp     al,1
                ja      GAd_Berror
                shl     bx,1
                jc      GAd_Overflow
                or      bl,al
                mov     byte ptr cs:GAd_Flag,1
                jmp     GetLoop1

GAd_Bret:       test    byte ptr cs:GAd_Flag,1
                jz      GAd_NumbMiss
                clc
                ret

GAd_Berror:     mov     cs:GetKeyParams.RK_ErrPtr,offset NotBinMes
                stc
                ret



GAd_Dec:        mov     byte ptr cs:GAd_Flag,0
                GetLineService _GL_GetSymb
                xor     bx,bx
GetLoop2:       GetLineService _GL_GetSymb
                push    cx
                mov     di,offset Delimiters
                mov     cx,Delimiters_C
                call    CalcCommand
                pop     cx
                jnc     GAd_Dret
                sub     al,'0'
                cmp     al,9
                ja      GAd_Derror
                push    ax
                mov     ax,10
                mul     bx
                mov     bx,ax
                pop     ax
                jc      GAd_Overflow
                mov     ah,0
                add     bx,ax
                jc      GAd_Overflow
                mov     byte ptr cs:GAd_Flag,1
                jmp     GetLoop2

GAd_Dret:       test    byte ptr cs:GAd_Flag,1
                jz      GAd_NumbMiss
                clc
                ret

GAd_Derror:     mov     cs:GetKeyParams.RK_ErrPtr,offset NotDecMes
                stc
                ret


GAd_Overflow:   mov     cs:GetKeyParams.RK_ErrPtr,offset BigNumMes
                stc
                ret

GAd_NumbMiss:   mov     cs:GetKeyParams.RK_ErrPtr,offset NumbMissMes
                or      al,al
                jnz     Gad_NumbMiss1
                inc     cl
Gad_NumbMiss1:  stc
                ret



; *******************************************************************
; **                                                               **
; **                                                               **
; **             B R E A K P O I N T   S E R V I C E S             **
; **                                                               **
; **                                                               **
; *******************************************************************

SetBreaks       proc    far
                push    ax bx dx si ds
                mov     ax,Apple
                mov     ds,ax
                xor     bx,bx
                mov     dx,7
StB_Loop1:      test    cs:Breakpoints[bx].BP_ActiveFlag,1
                jz      StB_Next
                mov     si,cs:Breakpoints[bx].BP_Address
                mov     al,2
                xchg    al,[si]
                mov     cs:Breakpoints[bx].BP_ByteStorage,al
StB_Next:       add     bx,7
                dec     dx
                jnz     StB_Loop1
                pop     ds si dx bx ax
                ret
SetBreaks       endp


UnsetBreaks     proc    far
                push    ax bx dx si ds
                mov     ax,Apple
                mov     ds,ax
                mov     bx,6 * 7
                mov     dx,7
UsB_Loop1:      test    cs:Breakpoints[bx].BP_ActiveFlag,1
                jz      UsB_Next
                mov     si,cs:Breakpoints[bx].BP_Address
                mov     al,cs:Breakpoints[bx].BP_ByteStorage
                cmp     byte ptr [si],2
                jne     UsB_Next
                mov     [si],al
UsB_Next:       sub     bx,7
                dec     dx
                jnz     UsB_Loop1
                pop     ds si dx bx ax
                ret
UnsetBreaks     endp


CheckBreaks:    push    si
                mov     si,cs:Regs.PC
                stc
                call    CheckBreak
                pop     si
                ret


F1_or_Invalid?  db      ?

CheckBreak:     push    ax bx cx dx
                mov     al,1
                jc      CB_0
                xor     ax,ax
CB_0:           xor     bx,bx
                mov     cx,bx
                mov     dx,bx
CB_Loop1:       test    cs:Breakpoints[bx].BP_ActiveFlag,1
                jz      CB_1
                cmp     si,cs:Breakpoints[bx].BP_Address
                jne     CB_1
                mov     cl,1
                or      bx,bx
                jz      CB_1
                or      al,al
                jz      CB_1
                mov     cs:Breakpoints[bx].BP_FlashFlag,cl
                call    ShowPrevIns
                call    StopAnimate
                mov     cs:GetKeyParams.RK_ErrPtr,offset BreakpointMes
                mov     cs:BreakpointNum,dl
                add     cs:BreakpointNum,30h
CB_1:           add     bx,7
                inc     dx
                cmp     dx,7
                jne     CB_Loop1
                cmp     cl,1
                pop     dx cx bx ax
                ret



; *******************************************************************
; **                                                               **
; **                                                               **
; **                 L A B E L S   S E R V I C E S                 **
; **                                                               **
; **                                                               **
; *******************************************************************

SGV_dx          dw      ?
SGV_adr         dw      ?
SGV_nameBeg     dw      ?
SGV_nameEnd     dw      ?
SGV_cx          dw      ?

SymbGetVal:     push    bx dx si di cx          ; Returns value of a symbol
                xor     dx,dx
                mov     cs:SGV_NameBeg,dx       ; Input:
SGV_Loop0:      GetLineService _GL_GetSymb      ; CH -> vtab, CL -> htab
                inc     dx
                push    cx                      ; Output:
                mov     di,offset Delimiters    ;   AX -> value
                mov     cx,Delimiters_C         ;   cf -> set if not found
                call    CalcCommand
                pop     cx
                jc      SGV_Loop0
                dec     dx
                mov     cs:SGV_dx,dx

                xor     bx,bx
                xor     si,si
SGV_Loop1:      pop     cx
                push    cx
                mov     dx,cs:SGV_dx
SGV_Loop2:      GetLineService _GL_GetSymb
SGV_Loop3:      call    Upcase
                mov     ah,al
                mov     al,cs:SymbMem[bx]
                call    Upcase
                xchg    al,ah
                cmp     al,ah
                jne     SGV_NoOk0
                dec     dx
                jnz     SGV_NoOk1
                inc     bx
                cmp     byte ptr cs:SymbMem[bx],0
                jnz     SGV_NoOk0
                shl     si,1
                mov     ax,cs:SymbVal[si]
                mov     cs:GetKeyParams.RK_ErrPtr,0
                mov     cs:SGV_cx,cx
                mov     cs:SGV_adr,si
                mov     cs:SGV_nameEnd,bx
                clc
                jmp     SGV_ret

SGV_NoOk0:      cmp     byte ptr cs:SymbMem[bx],0
                jz      SGV_Cont1
                inc     bx
                jmp     SGV_NoOk0
SGV_Cont1:      inc     bx
                cmp     bx,cs:SymbPtr
                ja      SGV_NotFnd
                mov     cs:SGV_NameBeg,bx
                inc     si
                jmp     SGV_Loop1

SGV_NoOk1:      inc     bx
                cmp     bx,cs:SymbPtr
                jbe     SGV_Loop2
SGV_NotFnd:     mov     cs:GetKeyParams.RK_ErrPtr,offset SymNotFndErr
                stc

SGV_ret:        pop     cx di si dx bx
                ret



PrintSymbol:    push    ax bx dx di                     ; Print a symbol
                and     ah,11110000b
                or      ah,0Fh                          ; Input:
                xor     di,di                           ;   CH-vtab, CL-htab, *AH-attr
                test    cs:ScreenIOparams.SP_BufFlag,1  ;   BX-Symbol number
                jz      PS_Ok001                        ;   DX-Max Length
                mov     dx,0FFFFh
                mov     al,'.'
                ScreenIOservice _SYMBPRINT
PS_Ok001:       cmp     bx,0
                jz      PS_Go
                dec     di
PS_Loop1:       inc     di
                cmp     byte ptr cs:SymbMem[di],0
                jne     PS_Loop1
                dec     bx
                jnz     PS_Loop1
PS_Loop2:       inc     di
PS_Go:          mov     al,cs:SymbMem[di]
                or      al,al
                jz      PS_ret
                ScreenIOservice _SYMBPRINT
                dec     dx
                jnz     PS_Loop2
PS_ret:         pop     di dx bx ax
                ret



; *******************************************************************
; **                                                               **
; **                                                               **
; **               K E Y B O A R D   S E R V I C E S               **
; **                                                               **
; **                                                               **
; *******************************************************************

Alt_Keys        db      'prcmlh'
Alt_Procs       dw      Alt_Program,Alt_Regs,Alt_Command,Alt_Memory,Alt_Labels
                dw      Alt_Help
Alt_Key         proc    far
                push    cx si di ds
                mov     di,offset Alt_Keys
                mov     cx,offset Alt_Procs- offset Alt_Keys
                call    CalcCommand
                jc      Alt_Ret
                shl     di,1
                call    cs:Alt_Procs[di]
                jc      Alt_Ret
                mov     al,0Ch
Alt_Ret:        pop     ds di si cx
                ret

Alt_Program     proc    near
                mov     cs:GoWhere?,G_MiniAsm
                clc
                ret
Alt_Program     endp

Alt_Regs        proc    near
                mov     cs:GoWhere?,G_Registers
                clc
                ret
Alt_Regs        endp

Alt_Command     proc    near
                mov     cs:GoWhere?,G_COMMAND_ENTRY
                clc
                ret
Alt_Command     endp

Alt_Memory      proc    near
                mov     cs:GoWhere?,G_EditB
                mov     al,cs:EB_Flag
                xor     al,1
                jnz     Alt_Mret
                mov     cs:GoWhere?,G_EditA
Alt_Mret:       clc
                ret
Alt_Memory      endp

Alt_Labels      proc    near
                mov     cs:GoWhere?,G_LabList
                clc
                ret
Alt_Labels      endp

Alt_Help        proc    near
                mov     cs:GoWhere?,G_MoveHelp
                clc
                ret
Alt_Help        endp

Alt_Key         endp


GK_Fkey         proc    far
                push    ax bx cx dx si di bp ds es
                push    cs:ShowAllNumber
                push    cs:ActiveFlags
                mov     cs:ActiveFlags,0
                mov     cs:ShowAllNumber,5
                mov     bx,Emulate
                mov     es,bx
                mov     bx,Apple
                mov     ds,bx
                xor     bx,bx
                mov     bl,size FkeyStruc
                mul     bl
                mov     bx,ax
                cmp     cs:FkeysBuffer[bx].FkeyFlag,0
                jz      GK_NotActive
                mov     dx,cs:AssembAdr
                call    cs:FkeysBuffer[bx].FkeyProc
GK_NotActive:   pop     cs:ActiveFlags
                pop     cs:ShowAllNumber
                mov     cs:GetKeyParams.RK_FkeyFlag,1
                mov     word ptr cs:GetKeyParams.RK_FkeyProc,offset GK_Fkey
                mov     word ptr cs:GetKeyParams.RK_FkeyProc[2],seg GK_Fkey
                pop     es ds bp di si dx cx bx ax
                ret
GK_Fkey         endp



GK_Cont:        mov     cs:Breakpoints.BP_ActiveFlag,0
                call    GoAppleII0
                ret


OldC050         db      ?
GK_Animat:      xor     cs:GetKeyParams.RK_WaitKeyFlag,1
                mov     ax,100h
                cmp     cs:GetKeyParams.RK_WaitKeyFlag,al
                mov     bx,offset StopAnimate
                jz      T_DoIt
                mov     bx,offset StartAnimate
T_DoIt:         call    bx
                ret

StartAnimate:   push    ax
                xor     al,al
                mov     cs:FkeysBuffer[1*size FkeyStruc].FkeyLabel,offset SFK_Stop
                mov     cs:FkeysBuffer[2*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[3*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[4*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[5*size FkeyStruc].FkeyFlag,al
                mov     al,C050
                mov     cs:OldC050,al
                mov     cs:GetKeyParams.RK_WaitKeyFlag,1
                pop     ax
                ret

StopAnimate:    push    ax
                mov     ah,1
                mov     cs:FkeysBuffer[1*size FkeyStruc].FkeyLabel,offset SFK_Animat
                mov     cs:FkeysBuffer[2*size FkeyStruc].FkeyFlag,ah
                mov     cs:FkeysBuffer[3*size FkeyStruc].FkeyFlag,ah
                mov     cs:FkeysBuffer[4*size FkeyStruc].FkeyFlag,ah
                mov     cs:FkeysBuffer[5*size FkeyStruc].FkeyFlag,ah
                mov     al,cs:OldC050
                mov     es:C050,al
                mov     cs:GetKeyParams.RK_WaitKeyFlag,0
                pop     ax
                ret

T_WaitKey       proc    far
                push    bp ds es ax
                mov     ax,Apple
                mov     ds,ax
                mov     ax,Emulate
                mov     es,ax
                mov     al,es:C050
                call    StepAppleII
                call    CheckBreaks
                jc      T_ok01
                cmp     cs:ViewFlag,0
                jz      t_ok01
                inc     cs:ViewFlag
                mov     es:C000,94h             ; Press F7 to end view mode
T_ok01:         cmp     al,es:C050
                je      T_ok00
                mov     al,es:C050
                mov     cs:OldC050,al
                ScreenIOservice _SETTEXTMODE
T_ok00:         test    cs:ScreenIOparams.SS_ScreenFlag,1
                jz      T_ok10
                cmp     cs:GetKeyParams.RK_WaitKeyFlag,0
                jz      T_ok10
                call    ShowAll
                ScreenIOservice _SHOWCURSOR
T_ok10:         pop     ax es ds bp
                ret
T_WaitKey       endp


GK_Step:        mov     cs:Regs.PC,dx
                mov     bx,dx
                mov     al,[bx]
                xor     bx,bx
                mov     bl,al
                xor     ax,ax
                mov     al,cs:InstrLongTbl[bx]
                test    al,10000000b
                jz      GK_Trace
                and     al,00000011b
                add     ax,cs:Regs.PC
                mov     cs:Breakpoints.BP_ActiveFlag,1
                mov     cs:Breakpoints.BP_Address,ax
                mov     si,cs:Regs.PC
                call    GoAppleII
                mov     cs:Breakpoints.BP_ActiveFlag,0
                mov     cs:ShowPrev?,1
                mov     cs:PrevAdr,si
                ret


GK_Trace:       mov     cs:Regs.PC,dx
                call    StepAppleII
                call    CheckBreaks
                ScreenIOservice _SETTEXTMODE
                ret


GK_GoTo:        mov     cs:Breakpoints.BP_ActiveFlag,1
                mov     cs:Breakpoints.BP_Address,dx
                mov     si,cs:Regs.PC
                call    GoAppleII
                mov     cs:Breakpoints.BP_ActiveFlag,0
                call    ShowPrevIns
                ret

GK_ToRTS:       mov     ax,Emulate
                mov     es,ax
                xor     ax,ax
                mov     cs:FkeysMainFlag,al
                xchg    cs:ActiveFlags,ax
                mov     cs:GetKeyParams.RK_ErrPtr, offset ToRTSmes
                call    ShowAll
                ScreenIOService _SHOWSCREEN
                mov     cs:ActiveFlags,ax
                call    InitBufferA
                call    InitBufferB
                mov     al,cs:Regs.S
GK_ToRTS_loop:  call    StepAppleII_
                ScreenIOservice _SETTEXTMODE
                cmp     C000,0
                jnz     GK_ToRTS_ret
                mov     bx,cs:Regs.PC
                cmp     byte ptr ds:[bx],60h
                jne     GK_ToRTS_loop
                cmp     cs:Regs.S,al
                jne     GK_ToRTS_loop
GK_ToRTS_ret:   xor     ax,ax
                mov     C000,al
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                inc     al
                mov     cs:FkeysMainFlag,al
                call    ShowPrevIns
                ret


ViewFlag        db      0
GK_View:        mov     cs:ViewFlag,1
                mov     al,C050
                mov     cs:OldC050,al
                ScreenIOservice _SetScreen
                mov     cs:GetKeyParams.RK_FkeyFlag,0
                mov     cs:ScreenIOparams.SS_ScreenFlag,0
US_Loop1:       call    ReadKey
                cmp     cs:ViewFlag,2
                jne     US_NotBreak
                mov     cs:GetKeyParams.RK_ErrPtr,offset BreakpointMes
US_NotBreak:    cmp     cs:ViewFlag,0
                jz      US_Ret
                cmp     al,14h
                je      US_Ret
                cmp     al,0Ch
                je      US_Ret
                cmp     al,18h
                je      US_Quit
                cmp     al,0Fh
                je      US_Stop
                call    MySetScreen
                jmp     US_Loop1
US_Ret:         mov     al,cs:OldC050
                mov     C050,al
US_Quit:        mov     cs:ScreenIOparams.SS_ScreenFlag,1
                mov     cs:ViewFlag,0
                ret
US_Stop:        call    StopAnimate
                jmp     US_Ret



GK_Help:        mov     ax,100h
                xor     cs:HelpFlag,ah
                jnz     GK_HelpOn
                mov     cs:FkeysBuffer[9*size FkeyStruc].FkeyLabel,offset SFK_HelpOn
                mov     cs:FkeysBuffer[7*size FkeyStruc].FkeyFlag,al
                mov     cs:FkeysBuffer[8*size FkeyStruc].FkeyFlag,al
                jmp     GK_HelpRet
GK_HelpOn:      mov     cs:FkeysBuffer[9*size FkeyStruc].FkeyLabel,offset SFK_HelpOff
                mov     cs:FkeysBuffer[7*size FkeyStruc].FkeyFlag,ah
                mov     cs:FkeysBuffer[8*size FkeyStruc].FkeyFlag,ah
GK_HelpRet:     ret


GK_HelpUp:      push    ax
                mov     ax,cs:MinHelpPtr
                cmp     ax,cs:HelpPtr
                je      GK_HelpUpRet
                dec     cs:HelpPtr
                call    SH_Calculate
GK_HelpUpRet:   pop     ax
                ret

GK_HelpDown:    push    ax
                mov     ax,cs:MaxHelpPtr
                cmp     ax,cs:HelpPtr
                je      GK_HelpDownRet
                inc     cs:HelpPtr
                call    SH_Calculate
GK_HelpDownRet: pop     ax
                ret


GK_None:        ret



; *******************************************************************
; **                                                               **
; **                                                               **
; **               C O M M A N D S   S E R V I C E S               **
; **                                                               **
; **                                                               **
; *******************************************************************

Upcase:         cmp     al,'A'
                jb      UPCSret
                cmp     al,'Z'
                ja      UPCSret
                or      al,20h
UPCSret:        ret



CalcCommand:    push    ax bx cx es             ; Returns number of a command             .
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



MainCommands    db      '***',0
                db      'a',0
                db      'x',0
                db      'y',0
                db      's',0
                db      'p',0
                db      'pc',0
                db      'regs',0
                db      'asm',0
                db      'ea',0
                db      'eb',0
                db      'd',0
                db      'da',0
                db      'db',0
                db      '[',0
                db      'find',0
                db      'copy',0
                db      'compare',0
                db      'break',0
                db      'go',0
Com_LLabels     db      'll',0
Com_SLabels     db      'sl',0
                db      '.',0
                db      'list',0
                db      'dl',0
                db      'labels',0              ; ON / OFF
                db      'swap',0                ; ON / OFF
                db      '?',0
                db      'reset',0
                db      'movhlp',0
                db      'pdump',0
                db      'pasm',0
                db      'sound',0
                db      'record',0
                db      'stop',0
                db      'play',0
Com_LRecord     db      'lm',0
Com_SRecord     db      'sm'
ENDScan1        db      0

AsmInstr        db      '***',0
                db      'lda',0
                db      'ldx',0
                db      'ldy',0
                db      'sta',0
                db      'stx',0
                db      'sty',0
                db      'tax',0
                db      'tay',0
                db      'tsx',0
                db      'txa',0
                db      'txs',0
                db      'tya',0
                db      'pha',0
                db      'php',0
                db      'pla',0
                db      'plp',0
                db      'adc',0
                db      'sbc',0
                db      'inc',0
                db      'inx',0
                db      'iny',0
                db      'dec',0
                db      'dex',0
                db      'dey',0
                db      'and',0
                db      'ora',0
                db      'eor',0
                db      'asl',0
                db      'lsr',0
                db      'rol',0
                db      'ror',0
                db      'cmp',0
                db      'cpx',0
                db      'cpy',0
                db      'bit',0
                db      'bcc',0
                db      'bcs',0
                db      'beq',0
                db      'bmi',0
                db      'bne',0
                db      'bpl',0
                db      'bvc',0
                db      'bvs',0
                db      'bra',0
                db      'jmp',0
                db      'jsr',0
                db      'rts',0
                db      'rti',0
                db      'brk',0
                db      'nop',0
                db      'clc',0
                db      'cld',0
                db      'cli',0
                db      'clv',0
                db      'sec',0
                db      'sed',0
                db      'sei',0
                db      'tsb',0
                db      'trb',0
                db      'phy',0
                db      'phx',0
                db      'ply',0
                db      'plx',0
                db      'stz'
ENDScan2        db      0

; *******************************************************************
; **                                                               **
; **                                                               **
; **                 A P P L E R   I N T E R F A C E               **
; **                                                               **
; **                                                               **
; *******************************************************************

MSS_keys        db      'gth12fm '
MSS_subrt       dw      MSS_Graph, MSS_Text, MSS_HiGr, MSS_p1, MSS_p2
                dw      MSS_NoMix, MSS_Mix, MSS_Default

MySetScreen:    push    ax cx di es
                mov     di,offset MSS_keys
                mov     cx,offset MSS_subrt - offset MSS_keys
                call    CalcCommand
                jc      MSS_ret
                mov     ax,seg C050
                mov     es,ax
                shl     di,1
                mov     al,C050
                mov     ah,al
                call    cs:MSS_Subrt[di]
                cmp     al,ah
                je      MSS_ret
                ScreenIOservice _SetScreen
                mov     C050,al
MSS_ret:        pop     es di cx ax
                ret
MSS_Graph:      and     al,11110110b
                ret
MSS_Text:       or      al,00000001b
                ret
MSS_HiGr:       or      al,00001000b
                and     al,11111110b
                ret
MSS_p1:         and     al,11111011b
                ret
MSS_p2:         or      al,00000100b
                ret
MSS_NoMix:      and     al,11111101b
                ret
MSS_Mix:        or      al,00000010b
                ret
MSS_Default:    mov     al,cs:OldC050
                ret



DebugInit:      mov     ax,Apple
                mov     ds,ax
                call    InitGetLine
                cmp     byte ptr cs:F1_or_Invalid?,0
                jz      DI_NoInvalid
                mov     cs:GetKeyParams.RK_ErrPtr, offset InvalidOpcode
DI_NoInvalid:   mov     ax,cs:Regs.PC
                mov     cs:AssembAdr,ax
                call    ShowPrevIns
                call    InitBufferA
                call    InitBufferB
                ret

InitGetLine:    push    cx
                mov     cs:GetLineParams.GL_Color,       0Bh
                mov     cs:GetLineParams.GL_OverCurColor,40h
                mov     cs:GetLineParams.GL_InsCurColor, 20h
                mov     cs:GetLineParams.GL_MaxPrint,    32
                mov     cs:GetLineParams.GL_MaxLength,   99
                gotoxy  17,2
                mov     cs:GetLineParams.GL_CX,cx
                pop     cx
                ret



                assume  ds:Apple,es:TaskControl
GetRegisters    proc    near
                push    ax es
                mov     ax,TaskControl
                mov     es,ax
                mov     al,es:r_A
                mov     cs:Regs.A,al
                mov     al,es:r_X
                mov     cs:Regs.X,al
                mov     al,es:r_Y
                mov     cs:Regs.Y,al
                mov     al,es:r_S
                mov     cs:Regs.S,al
                mov     al,es:r_P
                mov     cs:Regs.P,al
                mov     ax,es:r_PC
                mov     cs:Regs.PC,ax
                pop     es ax
                ret
GetRegisters    endp

SetRegisters    proc    near
                push    ax es
                mov     ax,TaskControl
                mov     es,ax
                mov     al,cs:Regs.A
                mov     es:r_A,al
                mov     al,cs:Regs.X
                mov     es:r_X,al
                mov     al,cs:Regs.Y
                mov     es:r_Y,al
                mov     al,cs:Regs.S
                mov     es:r_S,al
                mov     al,cs:Regs.P
                mov     es:r_P,al
                mov     ax,cs:Regs.PC
                mov     es:r_PC,ax
                pop     es ax
                ret
SetRegisters    endp


SwapTime        dw      9
                assume  es:Emulate

GoAppleII0:     push    ax
                xor     ax,ax
                xchg    ax,cs:SwapTime
                call    GoAppleII
                mov     cs:SwapTime,ax
                pop     ax
                ret

GoAppleII:      push    ax bx cx dx es
                call    InitBufferA
                call    InitBufferB
                mov     cx,seg C050
                mov     es,cx
                xor     ax,ax
                xchg    cs:ActiveFlags,ax
                mov     cs:GetKeyParams.RK_ErrPtr, offset ExecutingMes
                call    ShowAll
                ScreenIOService _SHOWSCREEN
                mov     cs:ActiveFlags,ax
                mov     al,0C3h
                xchg    al,es:synchro_push_ax
                mov     cs:old_synchro,al
                push    es
                mov     ax,TaskControl
                mov     es,ax
                assume  es:TaskControl
                mov     es:T_Iflags,00000001b
                SwitchToProcess PID_EMULATOR
                mov     es:T_Iflags,00000010b
                pop     es
                assume  es:Emulate
                mov     al,cs:old_synchro
                mov     es:synchro_push_ax,al
                mov     ax,cs:SwapTime
                call    ScreenSwapReq
                call    SetBreaks
                cli
                SwitchToProcess PID_EMULATOR
                mov     cs:GetKeyParams.RK_ErrPtr,0
                call    CheckBreaks
                jnc     GAII_NoInvalid
                cmp     cs:F1_or_Invalid?,0
                jz      GAII_NoInvalid
                mov     cs:GetKeyParams.RK_ErrPtr, offset InvalidOpcode
GAII_NoInvalid: mov     ax,cs:Regs.PC
                mov     cs:AssembAdr,ax
                call    BuffDisasm
                call    ShowPrevIns
                mov     al,1
                mov     cs:RE_FirstTime?,al
                mov     cs:EA_Params.EB_FirstFl,al
                mov     cs:EB_Params.EB_FirstFl,al
                pop     es dx cx bx ax
                sti
                ret



old_synchro     db      ?
StepAppleII:    call    InitBufferA
                call    InitBufferB
StepAppleII_:   push    ax
                mov     al,0C3h
                xchg    al,es:synchro_push_ax
                mov     cs:old_synchro,al
                push    bx es
                mov     ax,TaskControl
                mov     es,ax
                assume  es:TaskControl
                mov     es:T_Iflags,00000001b
                mov     bx,cs:Regs.PC
                SwitchToProcess PID_EMULATOR
                mov     cs:ShowPrev?,1
                mov     cs:PrevAdr,bx
                mov     ax,cs:Regs.PC
                mov     cs:AssembAdr,ax
                call    BuffDisasm
                pop     es bx
                assume  es:Emulate
                mov     al,cs:old_synchro
                mov     es:synchro_push_ax,al
                pop     ax
                ret



GL_UserCommands db      7,8,3,4
GL_UserSubrt    dw      UP,DOWN,GL_PgUp,GL_PgDn
GetLineUser     proc    far
                push    bx cx di bp ds
                mov     di,Apple
                mov     ds,di
                mov     di,offset GL_UserCommands
                mov     cx,offset GL_UserSubrt- offset GL_UserCommands
                call    CalcCommand
                jc      GLU_Ret
                shl     di,1
                call    GL_UserSubrt[di]
GLU_Ret:        pop     ds bp di cx bx
                ret
GetLineUser     endp

GL_PgUp:        push    bx
                mov     bx,09h
GL_PU_loop:     call    UP
                dec     bx
                jnz     GL_PU_loop
                pop     bx
                clc
                ret

GL_PgDn:        push    bx
                mov     bx,09h
GL_PD_loop:     call    DOWN
                dec     bx
                jnz     GL_PD_loop
                pop     bx
                clc
                ret



; *******************************************************************
; **                                                               **
; **                                                               **
; **                          T A B L E S                          **
; **                                                               **
; **                                                               **
; *******************************************************************

;                          0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
InstrTable      db      'BRKORA??????TSBORAASL???PHPORAASL???TSBORAASL???' ;00
                db      'BPLORAORA???TRBORAASL???CLCORAINC???TRBORAASL???' ;10
                db      'JSRAND??????BITANDROL???PLPANDROL???BITANDROL???' ;20
                db      'BMIANDAND???BITANDROL???SECANDDEC???BITANDROL???' ;30
                db      'RTIEOR?????????EORLSR???PHAEORLSR???JMPEORLSR???' ;40
                db      'BVCEOREOR??????EORLSR???CLIEORPHY??????EORLSR???' ;50
                db      'RTSADC??????STZADCROR???PLAADCROR???JMPADCROR???' ;60
                db      'BVSADCADC???STZADCROR???SEIADCPLY???JMPADCROR???' ;70
                db      'BRASTA??????STYSTASTX???DEYBITTXA???STYSTASTX???' ;80
                db      'BCCSTASTA???STYSTASTX???TYASTATXS???STZSTASTZ???' ;90
                db      'LDYLDALDX???LDYLDALDX???TAYLDATAX???LDYLDALDX???' ;A0
                db      'BCSLDALDA???LDYLDALDX???CLVLDATSX???LDYLDALDX???' ;B0
                db      'CPYCMP??????CPYCMPDEC???INYCMPDEX???CPYCMPDEC???' ;C0
                db      'BNECMPCMP??????CMPDEC???CLDCMPPHX??????CMPDEC???' ;D0
                db      'CPXSBC??????CPXSBCINC???INXSBCNOP???CPXSBCINC???' ;E0
                db      'BEQSBCSBC??????SBCINC???SEDSBCPLX??????SBCINC???' ;F0



;                         0 1 2 3 4 5 6 7 8 9 A B  C  D E F
InstrLongTbl    db      82h,2,5,5,2,2,2,5,1,2,1,5, 3 ,3,3,5 ;00
                db      82h,2,2,5,2,2,2,5,1,3,1,5, 3 ,3,3,5 ;10
                db      83h,2,5,5,2,2,2,5,1,2,1,5, 3 ,3,3,5 ;20
                db      82h,2,2,5,2,2,2,5,1,3,1,5, 3 ,3,3,5 ;30
                db        1,2,5,5,5,2,2,5,1,2,1,5,83h,3,3,5 ;40
                db      82h,2,2,5,5,2,2,5,1,3,1,5, 5 ,3,3,5 ;50
                db        1,2,5,5,2,2,2,5,1,2,1,5,83h,3,3,5 ;60
                db      82h,2,2,5,2,2,2,5,1,3,1,5,83h,3,3,5 ;70
                db      82h,2,5,5,2,2,2,5,1,2,1,5, 3 ,3,3,5 ;80
                db      82h,2,2,5,2,2,2,5,1,3,1,5, 3 ,3,3,5 ;90
                db        2,2,2,5,2,2,2,5,1,2,1,5, 3 ,3,3,5 ;A0
                db      82h,2,2,5,2,2,2,5,1,3,1,5, 3 ,3,3,5 ;B0
                db        2,2,5,5,2,2,2,5,1,2,1,5, 3 ,3,3,5 ;C0
                db      82h,2,2,5,5,2,2,5,1,3,1,5, 5 ,3,3,5 ;D0
                db        2,2,5,5,2,2,2,5,1,2,1,5, 3 ,3,3,5 ;E0
                db      82h,2,2,5,5,2,2,5,1,3,1,5, 5 ,3,3,5 ;F0



;            ???      0
;            #        1
;            ZP       2
;            ZP,X     3
;            Full     4
;            Full,X   5
;            Full,Y   6
;            (ZP,X)   7
;            (ZP),Y   8
;            ZP,Y     9
;            JMP      A
;            JMP ()   B
;            NoOper   C
;            BEQ      D
;            (ZP)     E
;            (....,X) F


;                        0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
ParamTable      db       1, 7, 0, 0, 2, 2, 2, 0,12, 1,12, 0, 4, 4, 4, 0 ; 00
                db      13, 8,14, 0, 2, 3, 3, 0,12, 6,12, 0, 4, 5, 5, 0 ; 10
                db      10, 7, 0, 0, 2, 2, 2, 0,12, 1,12, 0, 4, 4, 4, 0 ; 20
                db      13, 8,14, 0, 3, 3, 3, 0,12, 6,12, 0, 5, 5, 5, 0 ; 30
                db      12, 7, 0, 0, 0, 2, 2, 0,12, 1,12, 0,10, 4, 4, 0 ; 40
                db      13, 8,14, 0, 0, 3, 3, 0,12, 6,12, 0, 0, 5, 5, 0 ; 50
                db      12, 7, 0, 0, 2, 2, 2, 0,12, 1,12, 0,11, 4, 4, 0 ; 60
                db      13, 8,14, 0, 3, 3, 3, 0,12, 6,12, 0,15, 5, 5, 0 ; 70
                db      13, 7, 0, 0, 2, 2, 2, 0,12, 1,12, 0, 4, 4, 4, 0 ; 80
                db      13, 8,14, 0, 3, 3, 9, 0,12, 6,12, 0, 4, 5, 5, 0 ; 90
                db       1, 7, 1, 0, 2, 2, 2, 0,12, 1,12, 0, 4, 4, 4, 0 ; A0
                db      13, 8,14, 0, 3, 3, 9, 0,12, 6,12, 0, 5, 5, 6, 0 ; B0
                db       1, 7, 0, 0, 2, 2, 2, 0,12, 1,12, 0, 4, 4, 4, 0 ; C0
                db      13, 8,14, 0, 0, 3, 3, 0,12, 6,12, 0, 0, 5, 5, 0 ; D0
                db       1, 7, 0, 0, 2, 2, 2, 0,12, 1,12, 0, 4, 4, 4, 0 ; E0
                db      13, 8,14, 0, 0, 3, 3, 0,12, 6,12, 0, 0, 5, 5, 0 ; F0



;                       NoOp #$   $.   $.X  $.Y  $..  $..X $..Y (X)  ()Y  ()   (....,X)
AsmTab1         db      0FFh,0A9h,0A5h,0B5h,0FFh,0ADh,0BDh,0B9h,0A1h,0B1h,0B2h,0FFh ;LDA
                db      0FFh,0A2h,0A6h,0FFh,0B6h,0AEh,0FFh,0BEh,0FFh,0FFh,0FFh,0FFh ;LDX
                db      0FFh,0A0h,0A4h,0B4h,0FFh,0ACh,0BCh,0FFh,0FFh,0FFh,0FFh,0FFh ;LDY
                db      0FFh,0FFh,085h,095h,0FFh,08Dh,09Dh,099h,081h,091h,092h,0FFh ;STA
                db      0FFh,0FFh,086h,0FFh,096h,08Eh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;STX
                db      0FFh,0FFh,084h,094h,0FFh,08Ch,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;STY
                db      0AAh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TAX
                db      0A8h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TAY
                db      0BAh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TSX
                db      08Ah,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TXA
                db      09Ah,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TXS
                db      098h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TYA
                db      048h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PHA
                db      008h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PHP
                db      068h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PLA
                db      028h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PLP
                db      0FFh,069h,065h,075h,0FFh,06Dh,07Dh,079h,061h,071h,072h,0FFh ;ADC
                db      0FFh,0E9h,0E5h,0F5h,0FFh,0EDh,0FDh,0F9h,0E1h,0F1h,0F2h,0FFh ;SBC
                db      01Ah,0FFh,0E6h,0F6h,0FFh,0EEh,0FEh,0FFh,0FFh,0FFh,0FFh,0FFh ;INC
                db      0E8h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;INX
                db      0C8h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;INY
                db      03Ah,0FFh,0C6h,0D6h,0FFh,0CEh,0DEh,0FFh,0FFh,0FFh,0FFh,0FFh ;DEC
                db      0CAh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;DEX
                db      088h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;DEY
                db      0FFh,029h,025h,035h,0FFh,02Dh,03Dh,039h,021h,031h,032h,0FFh ;AND
                db      0FFh,009h,005h,015h,0FFh,00Dh,01Dh,019h,001h,011h,012h,0FFh ;ORA
                db      0FFh,049h,045h,055h,0FFh,04Dh,05Dh,059h,041h,051h,052h,0FFh ;EOR
                db      00Ah,0FFh,006h,016h,0FFh,00Eh,01Eh,0FFh,0FFh,0FFh,0FFh,0FFh ;ASL
                db      04Ah,0FFh,046h,056h,0FFh,04Eh,05Eh,0FFh,0FFh,0FFh,0FFh,0FFh ;LSR
                db      02Ah,0FFh,026h,036h,0FFh,02Eh,03Eh,0FFh,0FFh,0FFh,0FFh,0FFh ;ROL
                db      06Ah,0FFh,066h,076h,0FFh,06Eh,07Eh,0FFh,0FFh,0FFh,0FFh,0FFh ;ROR
                db      0FFh,0C9h,0C5h,0D5h,0FFh,0CDh,0DDh,0D9h,0C1h,0D1h,0D2h,0FFh ;CMP
                db      0FFh,0E0h,0E4h,0FFh,0FFh,0ECh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;CPX
                db      0FFh,0C0h,0C4h,0FFh,0FFh,0CCh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;CPY
                db      0FFh,089h,024h,034h,0FFh,02Ch,03Ch,0FFh,0FFh,0FFh,0FFh,0FFh ;BIT
                db      0FFh,0FFh,0FFh,0FFh,0FFh,090h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BCC
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0B0h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BCS
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0F0h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BEQ
                db      0FFh,0FFh,0FFh,0FFh,0FFh,030h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BMI
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0D0h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BNE
                db      0FFh,0FFh,0FFh,0FFh,0FFh,010h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BPL
                db      0FFh,0FFh,0FFh,0FFh,0FFh,050h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BVC
                db      0FFh,0FFh,0FFh,0FFh,0FFh,070h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BVS
                db      0FFh,0FFh,0FFh,0FFh,0FFh,080h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BRA
                db      0FFh,0FFh,0FFh,0FFh,0FFh,04Ch,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;JMP
                db      0FFh,0FFh,0FFh,0FFh,0FFh,020h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;JSR
                db      060h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;RTS
                db      040h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;RTI
                db      0FFh,000h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;BRK
                db      0EAh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;NOP
                db      018h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;CLC
                db      0D8h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;CLD
                db      058h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;CLI
                db      0B8h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;CLV
                db      038h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;SEC
                db      0F8h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;SED
                db      078h,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;SEI
                db      0FFh,0FFh,004h,0FFh,0FFh,00Ch,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TSB
                db      0FFh,0FFh,014h,0FFh,0FFh,01Ch,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;TRB
                db      05Ah,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PHY
                db      0DAh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PHX
                db      07Ah,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PLY
                db      0FAh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ;PLX
                db      0FFh,0FFh,064h,074h,0FFh,09Ch,09Eh,0FFh,0FFh,0FFh,0FFh,0FFh ;STZ

Debug           ends

                END

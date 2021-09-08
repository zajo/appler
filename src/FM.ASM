;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      FM.ASM                          |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   File Manager                    |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC
                include FM.INC

G_DIRECTORY     =       0
G_MEMORY        =       1
G_PATH_FILTER   =       2

FM              segment public
                assume  cs:FM,ds:FM,es:Emulate

GetLineBuf      db      80h dup (0)

GetLineParams   GL_ParamStruc  <?,0,1,1,5,0,0,20h,40h,0,?,?,0Bh,1,0,GetLineUser,?,?,?,?>
ScreenIOParams  SIO_ParamStruc <1,FM,0,0,offset Screen,seg Screen,1,0,1,1>
GetKeyParams    RK_ParamStruc  <1,Fkey,1,Alt_Key,0,?,ShowAll,0>

FMInInit        proc    far
                cli
                push    ax ds es
                mov     ax,Emulate
                mov     es,ax
                mov     al,es:[C000]
                mov     cs:KeyPressed,al
                mov     es:C000,0
                call    DebugKeysOn
                assume  ds:CONio
                mov     ax,CONio
                mov     ds,ax
                mov     GL_ParamsOfs,  offset GetLineParams
                mov     GL_ParamsSeg,  seg    GetLineParams
                mov     SIO_ParamsOfs, offset ScreenIOParams
                mov     SIO_ParamsSeg, seg    ScreenIOParams
                mov     RK_ParamsOfs,  offset GetKeyParams
                mov     RK_ParamsSeg,  seg    GetKeyParams
                assume  ds:FM
                mov     cs:GetKeyParams.RK_ErrPtr,0
                pop     es ds ax
                call    UnsetBreaks
                sti
                ret
FMInInit        endp

KeyPressed      db      0
FMOutInit       proc    far
                cli
                push    ax es
                mov     ax,Emulate
                mov     es,ax
                mov     al,cs:KeyPressed
                mov     es:C000,al
                mov     ax,seg T_Iflags
                mov     es,ax
		assume  es:seg T_Iflags
                mov     byte ptr es:T_Iflags,00000010b
                assume  es:Emulate
                pop     es ax
                call    SetBreaks
		call    AppleKeysOn
                ret
FMOutInit       endp



; Entry:
;   DS --> segment
;   SI --> ^ext to add  (ASCIIZ)
;   DI --> ^filespec    (ASCIIZ)
; Exit:
;   CF --> 1 ext is not as expected, 0 - otherwise

AE_Ext          db      3 dup (?)
AE_Start        dw      ?
AddExt          proc    far
                push    ax cx si di es
                push    si
                mov     cs:AE_Start,di
                push    ds
                pop     es
                cld
                mov     cx,0FFh
                xor     al,al
        repne   scasb
                dec     di
                mov     cx,di
AE_Loop:        dec     di
                cmp     di,cs:AE_Start
                je      AE_DoAddExt
                mov     al,ds:[di]
                cmp     al,'.'
                je      AE_ret
                cmp     al,'\'
                jne     AE_Loop
AE_DoAddExt:    mov     di,cx
                push    di
                mov     cx,5
        rep     movsb
                pop     di
AE_ret:         pop     si
AE_WhatExtLoop: lodsb
                or      al,al
                clc
                jz      AE_Quit
                scasb
                je      AE_WhatExtLoop
                call    Upcase
                cmp     al,ds:[di-1]
                je      AE_WhatExtLoop
                stc
AE_Quit:        pop     es di si cx ax
                ret
AddExt          endp


; Entry:
;   DS --> segment
;   SI --> ^ext to add  (ASCIIZ)
;   DI --> ^filespec    (ASCIIZ)
; Exit:
;   ZF --> 1 ext is as expected, 0 - otherwise

CE_Ext          db      3 dup (?)
CE_Start        dw      ?
CmpExt          proc    far
                push    ax cx si di es
                mov     cs:CE_Start,di
                push    ds
                pop     es
                cld
                mov     cx,0FFh
                xor     al,al
        repne   scasb
CE_Loop:        dec     di
                cmp     di,cs:CE_Start
                je      CE_Quit
                mov     al,ds:[di]
                cmp     al,'\'
                je      CE_Quit
                cmp     al,'.'
                jne     CE_Loop
CE_CmpLoop:     lodsb
                or      al,al
                je      CE_Quit
                scasb
                je      CE_CmpLoop
                call    Upcase
                cmp     al,es:[di-1]
                je      CE_CmpLoop
CE_Quit:        or      al,al
                pop     es di si cx ax
                ret
CmpExt          endp


GoWhere?        dw      G_DIRECTORY
FM_MainRet:     push    cs
                pop     ds
                mov     F_MaxLength,0
                call    ReadDir
BigLoop:        mov     ch,GetLineParams.GL_BegPrint
                mov     cl,GetLineParams.GL_Pos
                mov     di,GoWhere?
                shl     di,1
                mov     GoWhere?,G_DIRECTORY
                call    CmndAddress[di]
                mov     GetLineParams.GL_Pos,cl
                mov     GetLineParams.GL_BegPrint,ch
                jmp     BigLoop

CmndAddress     dw      Directory,Memory,S_PathFilter



Directory:      mov     F_or_M,0
                jmp     Select

Memory:         mov     F_or_M,1
                jmp     Select


S_CommandsNum   =       8
S_ParamsStruc   struc
S_MaxLength     db      ?
S_BegPrint      db      ?
S_Pos           db      ?
S_CX            dw      ?
S_LinesNum      db      ?
S_Buffer        db      ?
S_ParamsStruc   ends

F_or_M          db      0
                db      ?
S_ActiveFlags   dw      0000000000000100b,0000000000001000b
S_Parameters    dw      DirectoryParams,MemoryParams

DirectoryParams label   byte
F_MaxLength     db      0
F_BegPrint      db      0
F_Pos           db      0
F_CX            dw      72Ah
F_LinesNum      db      17
FileBuffer      db      MAX_DIRECTORY_ENTRIES * size FileDescription dup (0)
FileTmpBuffer   db      size FileDescription dup (0)

MemoryParams    label   byte
M_MaxLength     db      1
M_BegPrint      db      0
M_Pos           db      0
M_CX            dw      0B02h
M_LinesNum      db      12
MemoryBuffer    db      1,0Fh,'<New File>',0
                db      FD_STATUS
                dw      0,0FFFFh,0
                db      0
                dw      0,0
                db      MAX_MEMORY_ENTRIES * size FileDescription dup (0)

S_Commands      db      'tben',18h
                db      7,8,3,4,1,2,0Dh,0Ch
S_Subrt         dw      S_Type,S_BegAdr,S_EndAdr,S_Name,S_Enter
                dw      S_Up,S_Down,S_PgUp,S_PgDn,S_Home,S_End,S_Tab,GoAppleII
S_CallIfZero?   db      0,0,0,0,0,0,0,0,0,0,0,0,1

Select:         xor     bx,bx
                mov     SHL_Flag,1
                mov     GetLineParams.GL_AllowSpc,0
                gotoxy  2,0
                mov     cs:GetLineParams.GL_CX,cx
                mov     bl,F_or_M
                shl     bx,1
                mov     bp,S_Parameters[bx]
                mov     ax,S_ActiveFlags[bx]
                mov     ActiveFlags,ax
                mov     FkeysFlags,1111111111b
                mov     ScreenIOparams.CursorFlag,0
                mov     GetLineParams.GL_Color,0Bh
                mov     cx,ds:[bp].S_CX
                call    ReadKey
                cmp     al,7Fh
                je      SelectRet
                mov     di,offset S_Commands
                mov     cx,offset S_Subrt- offset S_Commands
                call    CalcCommand
                jc      Select
                cmp     ds:[bp].S_MaxLength,0
                jnz     S_ok1
                test    S_CallIfZero?[di],1
                jz      Select
S_ok1:          shl     di,1
                call    S_Subrt[di]
                jnc     Select
                call    GoAppleII
                jmp     Select
SelectRet:      GetLineService _GL_CLRBUFF
                mov     F_or_M,0
                ret


S_Tab:          xor     F_or_M,1
                clc
                ret


NameEntering    db      0
S_NameFlags     db      0,1,1,1
S_Name:         call    EnterFilename
                clc
                ret
EnterFilename:  push    ax bx cx dx di bp
                mov     NameEntering,1
                push    word ptr [GetKeyParams.RK_AltFlag]
                mov     bl,0Bh
                mov     GetLineParams.GL_Color,bl
                mov     GetKeyParams.RK_AltFlag,0
                mov     SHL_Flag,0
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                test    ds:[bp].S_Buffer[di].FileFlags,FF_DAMAGED?
                jnz     S_NameRet
                test    ds:[bp].S_Buffer[di].FileFlags,FF_MODIFYNAME?
                jz      S_NameRet
                mov     cs:GetKeyParams.RK_ErrPtr,offset SMS_EnterFilename
                mov     FkeysFlags,0000000010b
                mov     ScreenIOparams.CursorFlag,1
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                lea     bx,ds:[bp].S_Buffer[di].FileName
                mov     GetLineParams.GL_Buffer,bx
                mov     GetLineParams.GL_Pos,0
                mov     GetLineParams.GL_BegPrint,0
                mov     GetLineParams.GL_MaxLength,0Ch
                mov     GetLineParams.GL_MaxPrint,0Dh
                call    Seek0
                mov     GetLineParams.GL_Length,bl
                mov     ScreenIOparams.CursorLen,1
                mov     cx,ds:[bp].S_CX
                dec     ch
                inc     cl
                mov     al,80 * 2
                mul     ch
                xor     bx,bx
                mov     bl,cl
                shl     bx,1
                add     ax,bx
                mov     cx,ax
                GetLineService _GETLINE
S_NameRet:      pop     word ptr [GetKeyParams.RK_AltFlag]
                mov     NameEntering,0
                pop     bp di dx cx bx ax
                ret

S_PathFilter:   push    word ptr ds:[ScreenIOparams.CursorFlag]
                push    word ptr ds:[GetKeyParams.RK_AltFlag]
                mov     SHL_Flag,0
                mov     GetKeyParams.RK_AltFlag,0
                mov     GetLineParams.GL_AllowSpc,0
                mov     ActiveFlags,0000000000000001b
                mov     FkeysFlags,0000000010b
                mov     ScreenIOparams.CursorFlag,1
                mov     GetLineParams.GL_Buffer,offset PathFilter
                mov     GetLineParams.GL_Pos,0
                mov     GetLineParams.GL_BegPrint,0
                mov     GetLineParams.GL_MaxLength,67+20h
                mov     GetLineParams.GL_MaxPrint,35
                mov     ScreenIOparams.CursorLen,1
                call    LinkPathFilter
                mov     GetLineParams.GL_Length,bl
                gotoxy  5,2
                GetLineService _GETLINE
                jc      S_Path1
                mov     GoWhere?,G_DIRECTORY
S_Path1:        call    GetPathFilter
                call    ReadDir
                pop     word ptr ds:[GetKeyParams.RK_AltFlag]
                pop     word ptr ds:[ScreenIOparams.CursorFlag]
                mov     SHL_Flag,1
                GetLineService _GL_CLRBUFF
                clc
                ret

S_Up:           push    ax
                mov     al,ds:[bp].S_Pos
                or      al,al
                jz      S_UpRet
                dec     al
                mov     ah,al
                sub     ah,ds:[bp].S_BegPrint
                cmp     ah,2
                jae     S_UpOk1
                cmp     ds:[bp].S_BegPrint,0
                jz      S_UpOk1
                dec     ds:[bp].S_BegPrint
                inc     byte ptr ds:[bp].S_CX[1]
S_UpOk1:        dec     byte ptr ds:[bp].S_CX[1]
S_UpRet:        mov     ds:[bp].S_Pos,al
                pop     ax
                clc
                ret

S_Down:         push    ax
                mov     al,ds:[bp].S_Pos
                mov     ah,ds:[bp].S_MaxLength
                dec     ah
                cmp     al,ah
                je      S_DownRet
                inc     al
                mov     ah,al
                sub     ah,ds:[bp].S_BegPrint
                add     ah,2
                cmp     ah,ds:[bp].S_LinesNum
                jb      S_DownOk1
                mov     ah,ds:[bp].S_BegPrint
                add     ah,ds:[bp].S_LinesNum
                jc      S_DownOk1
                cmp     ah,ds:[bp].S_MaxLength
                jae     S_DownOk1
                inc     ds:[bp].S_BegPrint
                dec     byte ptr ds:[bp].S_CX[1]
S_DownOk1:      inc     byte ptr ds:[bp].S_CX[1]
S_DownRet:      mov     ds:[bp].S_Pos,al
                pop     ax
                clc
                ret

S_PgUp:         push    cx
                xor     ch,ch
                mov     cl,ds:[bp].S_LinesNum
                dec     cx
S_PgUpLoop:     call    S_Up
                loop    S_PgUpLoop
                pop     cx
                clc
                ret

S_PgDn:         push    cx
                xor     ch,ch
                mov     cl,ds:[bp].S_LinesNum
                dec     cx
S_PgDnLoop:     call    S_Down
                loop    S_PgDnLoop
                pop     cx
                clc
                ret

S_Home:         push    cx
                mov     cx,MAX_DIRECTORY_ENTRIES
                dec     cx
S_HomeLoop:     call    S_Up
                loop    S_HomeLoop
                pop     cx
                clc
                ret

S_End:          push    cx
                mov     cx,MAX_DIRECTORY_ENTRIES
                dec     cx
S_EndLoop:      call    S_Down
                loop    S_EndLoop
                pop     cx
                clc
                ret

S_TypeNewVal    db      FD_Directory,FD_MSdos,FD_Code,FD_Status
S_TypeProcs     dw      STP_Directory,STP_Code,STP_Status,STP_MSdos
S_Type:         push    ax bx di
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                test    ds:[bp].S_Buffer[di].FileFlags,FF_DAMAGED?
                jnz     S_TypeRet
                test    ds:[bp].S_Buffer[di].FileFlags,FF_MODIFYTYPE?
                jz      S_TypeRet
                xor     bx,bx
                mov     bl,ds:[bp].S_Buffer[di].FileType
                mov     bl,S_TypeNewVal[bx]
                mov     ds:[bp].S_Buffer[di].FileType,bl
                shl     bx,1
                cmp     F_or_M,0
                mov     al,FF_MODIFYNAME?
                jnz     S_TypeCallProc
                call    FU_Procs[bx]
                mov     al,0
S_TypeCallProc: call    S_TypeProcs[bx]
S_TypeRet:      pop     di bx ax
                ret

STP_Directory:  ret

STP_Code:       or      al,FF_SHOWADDR? or FF_MODIFYADDR? or FF_MODIFYTYPE?
                mov     ds:[bp].S_Buffer[di].FileFlags,al
                ret

STP_Status:     or      al,FF_MODIFYTYPE?
                mov     ds:[bp].S_Buffer[di].FileFlags,al
                ret

STP_MSdos:      or      al,FF_SHOWADDR? or FF_MODIFYADDR? or FF_MODIFYTYPE?
                mov     ds:[bp].S_Buffer[di].FileFlags,al
                ret




S_BegAdrX       db      65,25
S_BegAdr:       push    ax bx cx dx di
                mov     SHL_Flag,0
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                test    ds:[bp].S_Buffer[di].FileFlags,FF_MODIFYADDR?
                jz      S_BegAdrRet
                test    ds:[bp].S_Buffer[di].FileFlags,FF_DAMAGED?
                jnz     S_BegAdrRet
                mov     cx,ds:[bp].S_CX
                xor     bx,bx
                mov     bl,F_or_M
                mov     cl,S_BegAdrX[bx]
                mov     dx,ds:[bp].S_Buffer[di].FileEndAdr
                sub     dx,ds:[bp].S_Buffer[di].FileBegAdr
                mov     bx,0FFFFh
                sub     bx,dx
                call    GetAddress
                jc      S_BegAdrRet
                cmp     ax,bx
                jna     S_BegAdrOK
                mov     dx,0FFFFh
                sub     dx,ax
S_BegAdrOK:     mov     ds:[bp].S_Buffer[di].FileBegAdr,ax
                add     ax,dx
                mov     ds:[bp].S_Buffer[di].FileEndAdr,ax
S_BegAdrRet:    pop     di dx cx bx ax
                clc
                ret

S_EndAdrX       db      72,32
S_EndAdr:       push    ax bx cx di
                mov     SHL_Flag,0
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                test    ds:[bp].S_Buffer[di].FileFlags,FF_DAMAGED?
                jnz     S_EndAdrRet
                test    ds:[bp].S_Buffer[di].FileFlags,FF_MODIFYADDR?
                jz      S_EndAdrRet
                mov     cx,ds:[bp].S_CX
                xor     bx,bx
                mov     bl,F_or_M
                mov     cl,S_EndAdrX[bx]
                call    GetAddress
                jc      S_EndAdrRet
                cmp     ax,ds:[bp].S_Buffer[di].FileBegAdr
                jb      S_EndAdrRet
                cmp     ds:[bp].S_Buffer[di].FileBegAdr,0
                jnz     S_EndAdrOk
S_EndAdrOk:     mov     ds:[bp].S_Buffer[di].FileEndAdr,ax
S_EndAdrRet:    pop     di cx bx ax
                clc
                ret

S_EnterErrorFL  db      0
S_EnterProcs    dw      S_EnterF,S_EnterM
S_Enter:        push    ax bx cx dx si di ds es
                cmp     ds:[bp].S_MaxLength,0
                jz      S_EnterRet
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,F_or_M
                shl     bx,1
                call    S_EnterProcs[bx]
S_EnterRet:     pop     es ds di si dx cx bx ax
                clc
                ret

SEF_Procs       dw      SEF_Directory,SEF_Code,SEF_Status,SEF_Fragment
S_EnterF:       mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,FileBuffer[di].FileType
                mov     si,bx
                mov     bx,di
                call    LinkName
                shl     si,1
                mov     dx,offset Path
                call    SEF_Procs[si]
                call    UnLinkName
                ret

SEF_Directory:  mov     bx,LN_BX
                mov     byte ptr Path[bx],'\'
                mov     byte ptr Path[bx+1],0
                call    ReadDir
                ret

SEF_Code:       mov     RF_ErrPtr,offset SMS_ErrFileLoad
                mov     RF_MesPtr,offset SMS_FileLoaded
                call    OpenReadFile
                jc      SEF_CodeRet
                mov     cx,4
                call    ReadFile
SEF_CodeRet:    ret

SEF_Status:     push    es
                call    OpenReadFile
                jc      SEF_StatusRet
                call    FloppyLoad
                call    DRAMLoad
                mov     RF_ErrPtr,offset SMS_ErrStatLoad
                mov     RF_MesPtr,offset SMS_StatLoaded
                mov     cx,size RW_Header
                call    ReadFile
                mov     si,offset RW_Header
                cld
                assume  es:TaskControl
                mov     ax,TaskControl
                mov     es,ax
                lodsb
                mov     es:r_A,al
                lodsb
                mov     es:r_X,al
                lodsb
                mov     es:r_Y,al
                lodsb
                mov     es:r_S,al
                lodsb
                mov     es:r_P,al
                lodsw
                mov     es:r_PC,ax

                mov     ax,Peripher
                mov     es,ax
                assume  es:Peripher
                lodsb
                mov     es:FLAGS,al
                lodsw
                mov     es:BufferPTR,ax
                lodsw
                mov     es:WriteCNT,ax
                lodsb
                mov     es:WriteREG,al
                mov     di,offset CurrentDrive
                mov     cx,5                    ; non-dos fields size
        rep     movsb
                mov     di,offset OtherDrive
                mov     cx,5                    ; non-dos fields size
        rep     movsb

                mov     ax,Emulate
                mov     es,ax
                assume  es:Emulate
                lodsb
                mov     es:C050,al
                lodsb
                mov     es:C080,al

SEF_StatusRet:  pop     es
                ret
                assume  es:Emulate

SEF_Fragment:   mov     RF_ErrPtr,offset SMS_ErrFileLoad
                mov     RF_MesPtr,offset SMS_FileLoaded
                xor     cx,cx
                call    OpenReadFile
                jc      SEF_FrgRet
                call    ReadFile
SEF_FrgRet:     ret


SEM_SVD         db      '.SVD',0
SEM_APL         db      '.APL',0
SEM_Procs       dw      SEM_Directory,SEM_Code,SEM_Status,SEM_Fragment
SEM_NewFile     db      ?
S_EnterM:       mov     bl,MemoryParams.S_Pos
                call    CalcBuffer
                cmp     MemoryBuffer[di].FileName[0],1
                mov     SEM_NewFile,0
                jne     SEM_NotNewFile
                mov     SEM_NewFile,1
                dec     MemoryBuffer[di].FileName[0]
                mov     MemoryBuffer[di].FileFlags,FF_MODIFYNAME?
                call    EnterFilename
                push    di
                lea     di,MemoryBuffer[di].FileName
                jnc     SEM_ok1
                push    es
                mov     si,offset FL_NewFile
                push    ds
                pop     es
                mov     cx,13
        rep     movsb
                pop     es di
                ret
SEM_ok1:        mov     si,offset SEM_SVD
                call    AddExt
                mov     cl,FD_STATUS
                mov     ch,FF_MODIFYNAME? or FF_MODIFYTYPE?
                jnc     SEM_ok2
                or      ch,FF_MODIFYADDR? or FF_SHOWADDR?
                mov     si,offset SEM_APL
                call    CmpExt
                mov     cl,FD_CODE
                je      SEM_ok2
                mov     cl,FD_MSDOS
SEM_ok2:        pop     di
                mov     MemoryBuffer[di].FileFlags,ch
                mov     MemoryBuffer[di].FileType,cl
                cmp     cl,FD_STATUS
                je      SEM_NotNewFile
                call    S_BegAdr
                call    S_EndAdr
SEM_NotNewFile: xor     bx,bx
                mov     bl,MemoryBuffer[di].FileType
                mov     si,bx
                mov     bx,di
                call    LinkName
                shl     si,1
                mov     dx,offset Path
                call    SEM_Procs[si]
                call    UnlinkName
                cmp     SEM_NewFile,0
                jz      SEM_Ret
                lea     si,MemoryBuffer[di].FileName
                mov     cl,MemoryBuffer[di].FileType
                mov     ch,MemoryBuffer[di].FileFlags
                mov     ax,MemoryBuffer[di].FileBegAdr
                mov     bx,MemoryBuffer[di].FileEndAdr
                sub     bx,ax
                inc     bx
                call    FileIsLoaded
SEM_Ret:        ret

SEM_Directory:  clc
                ret

SEM_Code:       mov     WF_ErrPtr,offset SMS_ErrFileSave
                mov     WF_MesPtr,offset SMS_FileSaved
                mov     ax,MemoryBuffer[di].FileBegAdr
                mov     word ptr RW_Header[0],ax
                mov     ax,MemoryBuffer[di].FileEndAdr
                sub     ax,word ptr RW_Header[0]
                inc     ax
                mov     word ptr RW_Header[2],ax
                call    OpenFileWrite
                jc      SEM_CodeRet
                mov     cx,4
                call    WriteFile
SEM_CodeRet:    ret

SEM_Status:     mov     WF_ErrPtr,offset SMS_ErrStatSave
                mov     WF_MesPtr,offset SMS_StatSaved
                call    OpenFileWrite
                jc      SEM_StatusRet
                call    FloppySave
                call    DRAMSave
                push    si di ds es
                mov     di,offset RW_Header
                cld
                push    cs
                pop     es
                assume  ds:TaskControl
                mov     ax,TaskControl
                mov     ds,ax
                mov     al,ds:r_A
                stosb
                mov     al,ds:r_X
                stosb
                mov     al,ds:r_Y
                stosb
                mov     al,ds:r_S
                stosb
                mov     al,ds:r_P
                stosb
                mov     ax,ds:r_PC
                stosw

                mov     ax,Peripher
                mov     ds,ax
                assume  ds:Peripher
                mov     al,FLAGS
                stosb
                mov     ax,BufferPTR
                stosw
                mov     ax,WriteCNT
                stosw
                mov     al,WriteREG
                stosb
                mov     si,offset CurrentDrive
                mov     cx,5                    ; non-dos fields size
        rep     movsb
                mov     si,offset OtherDrive
                mov     cx,5                    ; non-dos fields size
        rep     movsb

                mov     ax,Emulate
                mov     ds,ax
                assume  ds:Emulate
                mov     al,ds:C050
                stosb
                mov     al,C080
                stosb

                pop     es ds di si
                assume  ds:FM
                mov     cx,size RW_Header
                call    WriteFile
SEM_StatusRet:  ret
                assume  ds:FM

SEM_Fragment:   mov     WF_ErrPtr,offset SMS_ErrFileSave
                mov     WF_MesPtr,offset SMS_FileSaved
                call    OpenFileWrite
                jc      SEM_FragmentRet
                xor     cx,cx
                call    WriteFile
SEM_FragmentRet: ret



LinkPathFilter: push    ax si di es
                xor     bx,bx
                push    cs
                pop     es
                mov     si,offset Path
                mov     di,offset PathFilter
                cld
LPF_Loop1:      lodsb
                or      al,al
                jz      LPF_Filter
                stosb
                inc     bx
                jmp     LPF_Loop1
LPF_Filter:     mov     si,offset Filter
LPF_Loop2:      lodsb
                stosb
                inc     bx
                or      al,al
                jnz     LPF_Loop2
                dec     bx
                pop     es di si ax
                ret



GetPathFilter:  push    ax cx dx si di es
                push    cs
                pop     es
                xor     al,al
                mov     di,offset PathFilter
                cld
                mov     cx,20h+67
        repne   scasb
                dec     di
                mov     si,di
                std
GPF_Loop1:      cmp     si,offset PathFilter
                jna     GPF_NoPath
                lodsb
                cmp     al,'\'
                jne     GPF_Loop1
                add     si,2
                mov     dx,si
                mov     si,offset PathFilter
                mov     di,offset Path
                cld
GPF_Loop2:      lodsb
                stosb
                cmp     si,dx
                jna     GPF_Loop2
                dec     si
                dec     di
                xor     al,al
                stosb
                mov     Path[67],0
GPF_NoPath:     cld
                mov     di,offset Filter
                xor     cx,cx
GPF_Loop3:      lodsb
                stosb
                cmp     cx,20h
                je      GPF_LongFilt
                inc     cx
                or      al,al
                jnz     GPF_Loop3
                cmp     cx,1
                je      GPF_NoFilter
GPF_Ret:        pop     es di si dx cx ax
                ret

GPF_LongFilt:   dec     di
                xor     ax,ax
                stosb
                jmp     GPF_Ret

GPF_DefaultFilt db      '*.APL,*.ROM,*.SVD',0
GPF_NoFilter:   mov     si,offset PathFilter
                mov     di,offset Path
                cld
GPF_Loop4:      lodsb
                stosb
                or      al,al
                jnz     GPF_Loop4
                mov     si,offset GPF_DefaultFilt
                mov     di,offset Filter
                mov     cx,offset GPF_NoFilter - offset GPF_DefaultFilt
        rep     movsb
                jmp     GPF_Ret



Seek0:          push    si
                xor     si,si
Seek0_Loop:     cmp     byte ptr ds:[bx][si],0
                jz      Seek0_Done
                inc     si
                jmp     Seek0_Loop
Seek0_Done:     mov     bx,si
                pop     si
                ret


; Entry:
;  DS:SI -> Name,0
;  AX    -  Begin Address
;  BX    -  Length
;  CL    -  Type
;  CH    -  Flags
FIL_Buffer      db      80 dup (0)
FileIsLoaded    proc    far
                push    ax bx cx dx si di bp ds es
                push    ax
                mov     di,offset FIL_Buffer
                push    cs
                pop     es
                mov     ah,60h
                int     21h
                mov     si,di
                push    cs
                pop     ds
                lea     di,FileTmpBuffer.FileName
                mov     dx,di
FIL_Loop:       lodsb
                cmp     al,':'
                je      FIL_Hop1
                cmp     al,'\'
                jne     FIL_ok1
FIL_Hop1:       mov     di,dx
                jmp     FIL_Loop
FIL_ok1:        stosb
                or      al,al
                jnz     FIL_Loop
                pop     ax
                mov     FileTmpBuffer.FileBegAdr,ax
                mov     word ptr FileTmpBuffer.File1st4bytes[0],ax
                mov     dx,bx
                or      bx,bx
                jnz     FIL_ok2
                dec     dx
FIL_ok2:        mov     word ptr FileTmpBuffer.File1st4bytes[2],dx
                add     bx,ax
                dec     bx
                mov     FileTmpBuffer.FileEndAdr,bx
                mov     FileTmpBuffer.FileType,cl
                mov     FileTmpBuffer.FileFlags,ch
                mov     bx,MAX_DIRECTORY_ENTRIES
                mov     ax,size FileDescription
                mul     bx
                mov     di,ax
                call    FileLoaded
                pop     es ds bp di si dx cx bx ax
                ret
FileIsLoaded    endp



FL_NewFile      db      1,0Fh,'<New File>',0
                db      FD_STATUS
                dw      0,0FFFFh,0
                db      0
                dw      0,0
FileLoaded:     push    ax bx dx si di bp
                mov     bp,offset MemoryParams
                mov     si,di
                mov     bl,M_MaxLength
                dec     bl
                cmp     M_MaxLength,MAX_MEMORY_ENTRIES
                jae     FL_NoInc
                inc     M_MaxLength
FL_NoInc:       call    CalcBuffer
                mov     bx,size FileDescription
                dec     bx
FL_Loop0:       mov     al,FileBuffer[si][bx]
                mov     MemoryBuffer[di][bx],al
                mov     al,FL_NewFile[bx]
                mov     MemoryBuffer[size FileDescription+di][bx],al
                dec     bx
                jns     FL_Loop0
                or      MemoryBuffer[di].FileFlags,FF_MODIFYNAME?
                xor     si,si
                mov     bx,1
FL_Loop1:       cmp     si,di
                je      FL_Next1
                mov     ax,MemoryBuffer[di].FileBegAdr
                cmp     ax,MemoryBuffer[si].FileEndAdr
                ja      FL_Next1
                mov     ax,MemoryBuffer[di].FileEndAdr
                cmp     ax,MemoryBuffer[si].FileBegAdr
                jb      FL_Next1
                cmp     ax,MemoryBuffer[si].FileEndAdr
                jb      FL_Damaged
                mov     ax,MemoryBuffer[di].FileBegAdr
                cmp     ax,MemoryBuffer[si].FileBegAdr
                ja      FL_Damaged
                dec     bx
                call    Delete
                inc     bx
                sub     di,size FileDescription
                jmp     FL_Next2
FL_Damaged:     or      MemoryBuffer[si].FileFlags,FF_DAMAGED?
FL_Next1:       add     si,size FileDescription
                inc     bl
FL_Next2:       cmp     bl,M_MaxLength
                jb      FL_Loop1
                mov     bp,offset MemoryParams
                call    S_End
                call    S_Up
                pop     bp di si dx bx ax
                ret


Delete:         push    ax cx si di es
                mov     cl,ds:[bp].S_MaxLength
                cmp     cl,1
                jz      DelRet
                sub     cl,bl
                dec     ds:[bp].S_MaxLength
                cmp     cl,1
                je      DelRet
                mov     al,Size FileDescription
                mul     cl
                mov     cx,ax
                call    CalcBuffer
                lea     si,ds:[bp].S_Buffer
                add     di,si
                mov     si,di
                add     si,size FileDescription
                push    cs
                pop     es
                cld
        rep     movsb
DelRet:         mov     al,ds:[bp].S_Pos
                cmp     al,ds:[bp].S_MaxLength
                jb      DelRetOk
                call    S_Up
DelRetOk:       pop     es di si cx ax
                ret


GA_Buffer       db      5 dup (?)
GetAddress:     push    word ptr [GetKeyParams.RK_AltFlag]
                mov     GetKeyParams.RK_AltFlag,0
                push    bx bp cx
                xor     bx,bx
                mov     bl,F_or_M
                mov     bl,0Bh
                mov     GetLineParams.GL_Color,bl
                mov     FkeysFlags,0000000010b
                mov     ScreenIOparams.CursorFlag,1
                mov     GetLineParams.GL_Buffer,offset GA_Buffer
                mov     GetLineParams.GL_MaxLength,4
                mov     GetLineParams.GL_MaxPrint,4
                mov     ScreenIOparams.CursorLen,1
                GetLineService _GL_ClrBuff
                pop     cx
                push    cx
                dec     ch
                mov     al,80 * 2
                mul     ch
                xor     bx,bx
                mov     bl,cl
                shl     bx,1
                add     ax,bx
                mov     cx,ax
                GetLineService _GETLINE
                jc      GetAddressRet
                xor     cx,cx
                call    GetAddr
GetAddressRet:  pop     cx bp bx
                pop     word ptr [GetKeyParams.RK_AltFlag]
                ret


GA_Delimiters   db      ',/',0
GA_DelimitersC  =       3
GetAddr:        push    bx bp
                xor     bx,bx
                GetLineService _GL_GetSymb
                or      al,al
                jz      GA_error
                dec     cl
GA_Loop:        GetLineService _GL_GetSymb
                push    cx di
                mov     di,offset GA_Delimiters
                mov     cx,GA_DelimitersC
                call    CalcCommand
                pop     di cx
                jnc     GA_Exit
                call    Upcase
                cmp     al,'0'
                jb      GA_error
                cmp     al,'9'
                jbe     GA_Anumb
                cmp     al,'a'
                jb      GA_error
                cmp     al,'f'
                ja      GA_error
                sub     al,27h
GA_Anumb:       sub     al,'0'
                shl     bx,4
                or      bl,al
                jmp     GA_Loop
GA_error:       stc
                jmp     GA_Ret
GA_Exit:        mov     ax,bx
                clc
GA_Ret:         pop     bp bx
                ret


RF_ErrPtr       dw      ?
RF_MesPtr       dw      ?
RW_Header       db      100h dup (?)

OpenReadFile:   push    ax
                call    Prepare4DOS
                mov     ax,3D00h
                int     21h
                mov     bx,ax
                call    SOD4eraperP
                pop     ax
                ret

ReadFile:       push    ax bx cx dx ds
                call    Prepare4DOS
                mov     ah,3Fh
                mov     dx,offset RW_Header
                or      cx,cx
                jz      RF_NoHeader
                int     21h
                cmp     ax,cx
                jne     RF_Error
                jc      RF_Error
RF_NoHeader:    mov     cx,FileBuffer[di].FileEndAdr
                mov     dx,FileBuffer[di].FileBegAdr
                sub     cx,dx
                mov     ax,Apple
                mov     ds,ax
                mov     ah,3Fh
                inc     cx
                jnz     RF_NoLong
                inc     cl
                mov     ah,3Fh
                int     21h
                jc      RF_Error
                mov     cx,0FFFFh
                inc     dx
RF_NoLong:      mov     ah,3Fh
                int     21h
                jc      RF_Error
                cmp     cx,ax
                jz      RF_NoErr1
                add     dx,ax
                dec     dx
                mov     cs:FileBuffer[di].FileEndAdr,dx
                jmp     RF_Error
RF_NoErr1:      mov     ax,cs:RF_MesPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                mov     cs:S_EnterErrorFL,0
                and     cs:FileBuffer[di].FileFlags,not FF_DAMAGED?
RF_ErrorRet:    mov     ah,3Eh
                int     21h
                pop     ds
                call    SOD4eraperP
                call    FileLoaded
                pop     dx cx bx ax
                ret
RF_Error:       mov     ax,cs:RF_ErrPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                mov     cs:S_EnterErrorFL,1
                or      cs:FileBuffer[di].FileFlags,FF_DAMAGED?
                jmp     RF_ErrorRet


WF_ErrPtr       dw      ?
WF_MesPtr       dw      ?

; Create (rewrite) a file. Set CF if an error occured. Exit: BX -- file handle

OpenFileWrite:  push    ax cx dx ds
                test    MemoryBuffer[di].FileFlags,FF_DAMAGED?
                jz      OFW_1
OFW_GetKeyLoop1: mov    SC1_Flag,1
                mov     SHL_Flag,0
                mov     ActiveFlags,0000000000010000b
                call    ReadKey
                mov     SC1_Flag,0
                mov     SHL_Flag,1
                cmp     al,0Ch
                stc
                je      OFW_Ret
                or      al,20h
                cmp     al,'n'
                stc
                je      OFW_Ret
                cmp     al,'y'
                jne     OFW_GetKeyLoop1
                and     MemoryBuffer[di].FileFlags,not FF_DAMAGED?
OFW_1:          call    Prepare4DOS
                xor     cx,cx
                mov     ah,5Bh
                int     21h
                jnc     OFW_NoError
                cmp     ax,50h
                jne     OFW_Error
                call    SOD4eraperP
OFW_GetKeyLoop: mov     SC_Flag,1
                mov     SHL_Flag,0
                mov     ActiveFlags,0000000000010000b
                call    ReadKey
                mov     SC_Flag,0
                mov     SHL_Flag,1
                cmp     al,0Ch
                stc
                je      OFW_Ret
                or      al,20h
                cmp     al,'n'
                stc
                je      OFW_Ret
                cmp     al,'y'
                jne     OFW_GetKeyLoop
                call    Prepare4DOS
                xor     cx,cx
                mov     ax,3C01h
                int     21h
                jc      OFW_Error
OFW_NoError:    mov     bx,ax
                call    SOD4eraperP
OFW_Ret:        pop     ds dx cx ax
                ret
OFW_Error:      mov     ax,cs:WF_ErrPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                mov     cs:S_EnterErrorFL,1
                jmp     OFW_NoError


; Entry: BX -- file handle ...

WriteFile:      push    ax bx cx dx ds
                call    Prepare4DOS
                mov     ah,40h
                mov     dx,offset RW_Header
                or      cx,cx
                jz      WF_NoHeader
                int     21h
                jc      WF_Error
                cmp     ax,cx
                jne     WF_Error
WF_NoHeader:    mov     cx,MemoryBuffer[di].FileEndAdr
                mov     dx,MemoryBuffer[di].FileBegAdr
                sub     cx,dx
                mov     ax,Apple
                mov     ds,ax
                mov     ah,40h
                inc     cx
                jnz     WF_NoLong
                inc     cl
                mov     ah,40h
                int     21h
                jc      WF_Error
                mov     cx,0FFFFh
                inc     dx
WF_NoLong:      mov     ah,40h
                int     21h
                jc      WF_Error
                cmp     ax,cx
                jne     WF_Error
                mov     ax,cs:WF_MesPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                mov     cs:S_EnterErrorFL,0
WF_Ret:         mov     ah,3Eh
                int     21h
                call    SOD4eraperP
                call    UnLinkName
                pop     ds dx cx bx ax
                ret
WF_Error:       mov     ax,cs:WF_ErrPtr
                mov     cs:GetKeyParams.RK_ErrPtr,ax
                mov     cs:S_EnterErrorFL,1
                jmp     WF_Ret



; -- Read Directory ------------------

RD_GetDirs?     db      1
Path            db      '.\',66 dup (0)                  ; Current Path
Filter          db      '*.APL,*.ROM,*.SVD',020h dup (0) ; Scan Filter
PathFilter      db      68+20h dup (0)                   ; Path&Filter
WildCard        db      0Dh dup (0)                      ; Temp
WC_AnyFile      db      '*.*',0                          ; For SubDirs scanning

BufPtr          dw      0
RD_0OfsSvd      dw      0
DTA             DTA_S   <0,0,0,0,0,0>

ReadDirectory   proc    near
                push    ax bx cx dx si di es
                call    Prepare4DOS
                mov     si,offset Path
                mov     di,si
                push    ds
                pop     es
                mov     ah,60h
                int     21h
                mov     dx,offset DTA
                mov     ah,1Ah
                int     21h

                xor     bx,bx
RD_SearchFor0:  cmp     Path[bx],0
                jz      RD_0Found
                inc     bx
                jmp     RD_SearchFor0
RD_0Found:      or      bx,bx
                jz      RD_PathOK
                cmp     Path[bx-1],'\'
                je      RD_PathOK
                mov     Path[bx],'\'
                inc     bx
                mov     Path[bx],0
RD_PathOK:      xor     si,si
                mov     RD_0OfsSvd,bx

                cmp     RD_GetDirs?,0
                jz      RD_GetFiles

RD_CopyWC1:     mov     al,WC_AnyFile[si]
                mov     Path[bx],al
                inc     si
                inc     bx
                cmp     al,0
                jnz     RD_CopyWC1
                mov     bx,BufPtr
                mov     dx,offset Path
                mov     cx,FA_DIRECTORY
                FindFirst
                jc      RD_GetFiles
RD_GetDirLoop:  test    DTA.Attributes,FA_DIRECTORY
		jz      RD_GD_Next
                cmp     F_MaxLength,0FFh
                je      RD_NoMoreFiles
                call    RD_PutFile
                inc     F_MaxLength
                add     bx,size FileDescription
RD_GD_Next:     FindNext
                jnc     RD_GetDirLoop
                mov     BufPtr,bx

RD_GetFiles:    mov     bx,RD_0OfsSvd
		xor     si,si
RD_CopyWC2:     mov     al,WildCard[si]
                mov     Path[bx],al
                inc     si
                inc     bx
                cmp     al,0
                jnz     RD_CopyWC2
                mov     bx,BufPtr
                mov     dx,offset Path
                mov     cx,FA_ARCHIVE
                FindFirst
                jc      RD_NoMoreFiles
RD_GetFilesLoop: cmp    F_MaxLength,0FFh
                je      RD_NoMoreFiles
                call    RD_PutFile
                inc     F_MaxLength
                add     bx,size FileDescription
                FindNext
		jnc     RD_GetFilesLoop

RD_NoMoreFiles: mov     si,RD_0OfsSvd
                mov     byte ptr Path[si],0
                mov     BufPtr,bx
                call    SOD4eraperP
                pop     es di si dx cx bx ax
                ret
ReadDirectory   endp



PF_FileExts     db      'FRGAPLROMSVD'
PF_FileTypes    db      FD_MSdos,FD_Code,FD_Code,FD_Status
PF_Addr         dw      PF_Directory,PF_Code,PF_Status,PF_MSdos
PF_NameLength   dw      ?
RD_PutFile      proc    near
                push    ax cx dx si di bp es
                xor     si,si
PF_GetNameLoop: mov     al,DTA.FileSpec[si]
                mov     FileBuffer[bx].FileName[si],al
                inc     si
                or      al,al
                jnz     PF_GetNameLoop
                mov     PF_NameLength,si

                or      bx,bx
		jz      PF_Cont1
                xor     bp,bp
PF_Cmp0:        xor     di,di
PF_Cmp1:        mov     al,ds:FileBuffer[bp].FileName[di]
                cmp     al,FileBuffer[bx].FileName[di]
                jne     PF_NotMatch
                inc     di
                or      al,al
                jnz     PF_Cmp1
PF_Error:       sub     bx,size FileDescription
                dec     F_MaxLength
		jmp     PF_Ret
PF_NotMatch:    add     bp,size FileDescription
                cmp     bp,bx
		jne     PF_Cmp0

PF_Cont1:       mov     FileBuffer[bx].FileFlags,0
                test    DTA.Attributes,FA_DIRECTORY
                jz      PF_NotDir
                mov     FileBuffer[bx].FileType,FD_DIRECTORY
                jmp     PF_Ret

PF_NotDir:      mov     ax,word ptr DTA.FileSize
                cmp     word ptr DTA.FileSize[2],0
                jz      PF_NotBig
                mov     ax,0FFFFh
PF_NotBig:      mov     FileBuffer[bx].FileLength,ax
                push    cs
                pop     es
                cld
                lea     di,FileBuffer[bx].FileName
                inc     di
                mov     al,'.'
                mov     cx,PF_NameLength
        repne   scasb
                xor     dl,dl
                jcxz    PF_PokeType
                mov     bp,di
                mov     si,offset PF_FileExts
                mov     dh,4
PF_CmpExtLoop:  mov     di,bp
                mov     cx,3
        repe    cmpsb
                je      PF_PokeType
PF_3:           inc     si
		loop    PF_3
                inc     dl
                dec     dh
                jnz     PF_CmpExtLoop
                xor     dl,dl
PF_PokeType:    xor     dh,dh
                mov     di,dx
                xor     ax,ax
                mov     al,PF_FileTypes[di]
                mov     FileBuffer[bx].FileType,al
                mov     di,ax
                mov     si,bx
                mov     bp,offset DirectoryParams
                call    LinkName
                mov     dx,offset Path
                mov     ax,3D00h
                int     21h
                call    UnLinkName
                jc      PF_Ret1
                lea     dx,FileBuffer[si].File1st4bytes
                mov     cx,4
                mov     bx,ax
                mov     ah,3Fh
                int     21h
                mov     ah,3Eh
                int     21h
                shl     di,1
                call    PF_Addr[di]
PF_Ret1:        mov     bx,si
PF_Ret:         pop     es bp di si dx cx ax
                ret
RD_PutFile      endp

PF_Directory:   mov     FileBuffer[si].FileFlags,0
                ret

PF_Code:        mov     FileBuffer[si].FileFlags,FF_SHOWADDR? or FF_MODIFYADDR? or FF_MODIFYTYPE?
                mov     ax,word ptr FileBuffer[si].File1st4bytes
                mov     FileBuffer[si].FileBegAdr,ax
                mov     ax,word ptr FileBuffer[si].File1st4bytes[2]
                add     ax,FileBuffer[si].FileBegAdr
                jnc     PF_Code_ok
                xor     ax,ax
PF_Code_ok:     dec     ax
                mov     FileBuffer[si].FileEndAdr,ax
                ret

PF_Status:      mov     FileBuffer[si].FileFlags,FF_MODIFYTYPE?
                xor     ax,ax
                mov     FileBuffer[si].FileBegAdr,ax
                dec     ax
                mov     FileBuffer[si].FileEndAdr,ax
                ret

PF_MSdos:       mov     FileBuffer[si].FileFlags,FF_SHOWADDR? or FF_MODIFYADDR? or FF_MODIFYTYPE?
                mov     FileBuffer[si].FileBegAdr,800h
                mov     ax,FileBuffer[si].FileLength
                add     ax,800h
                jnc     PF_MSdos_ok
                xor     ax,ax
PF_MSdos_ok:    dec     ax
                mov     FileBuffer[si].FileEndAdr,ax
                ret



ReadDir         proc    near
                push    ax si di
                mov     GetKeyParams.RK_ErrPtr,offset SMS_ReadDir
		xor     ax,ax
                mov     F_MaxLength,al
                mov     BufPtr,ax
                mov     F_BegPrint,al
                mov     F_Pos,al
                mov     F_CX,72Ah
                mov     RD_GetDirs?,1
                xor     si,si
RD1_Loop0:      xor     di,di
RD1_Cloop:      mov     al,Filter[si]
                or      al,al
                jz      RD1_CallRead
                cmp     al,','
                je      RD1_CallRead
                mov     WildCard[di],al
                inc     si
                inc     di
                cmp     di,0Ch
                jb      RD1_Cloop
RD1_CallRead:   mov     byte ptr WildCard[di],0
                call    ReadDirectory
                mov     RD_GetDirs?,0
                cmp     byte ptr Filter[si],0
                jz      RD1_Done
RD1_Ignore:     inc     si
                cmp     byte ptr Filter[si],','
		je      RD1_Ignore
                jmp     RD1_Loop0
RD1_Done:       mov     GetKeyParams.RK_ErrPtr,0
                pop     di si ax
                call    LinkPathFilter
                ret
ReadDir         endp


LN_BX           dw      ?
LinkName:       pushf
                push    ax bx si di
                mov     si,bx
                lea     si,ds:[bp].S_Buffer[si]
                mov     di,cs:RD_0OfsSvd
                xor     bx,bx
LN_Loop:        mov     al,cs:[si].FileName[bx]
                mov     cs:Path[di][bx],al
                inc     bx
                or      al,al
                jnz     LN_Loop
                dec     bx
                add     bx,di
                mov     cs:LN_BX,bx
                pop     di si bx ax
                popf
                ret



UnLinkName:     pushf
                push    bx
                mov     bx,cs:RD_0OfsSvd
                mov     cs:Path[bx],0
                pop     bx
                popf
                ret



Upcase:         cmp     al,'A'
                jb      UPCSret
                cmp     al,'Z'
                ja      UPCSret
                or      al,20h
UPCSret:        ret



CalcBuffer:     push    ax
                mov     al,size FileDescription
                mul     bl
                mov     di,ax
                pop     ax
                ret


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

DOSflag         db      0
OldFlags        dw      0
Prepare4DOS:    saveall
                pushf
                xor     ax,ax
                mov     cs:SHL_Flag,al
                xchg    ax,cs:ActiveFlags
                mov     cs:OldFlags,ax
                mov     cs:DOSflag,1
                call    ShowAll
                ScreenIOservice _SHOWSCREEN
                call    far ptr SystemTINI
                popf
                restoreall
                ret



; -- Unhook INT 24h --------------------

SOD4eraperP:    saveall
                pushf
                mov     ax,cs:OldFlags
                mov     cs:ActiveFlags,ax
                mov     cs:SHL_Flag,1
                mov     ax,Emulate
                mov     es,ax
                mov     byte ptr [C000],0
                call    far ptr SystemINIT
                mov     cs:DOSflag,0
                popf
                restoreall
                ret


; *******************************************************************
; **                                                               **
; **                                                               **
; **                        S H O W    A L L                       **
; **                                                               **
; **                                                               **
; *******************************************************************

ActiveFlags     dw      0
ShowAll         proc    far
                push    ds bp
                push    word ptr [ScreenIOparams.CursorColor]
                push    word ptr [ScreenIOparams.CursorLen]
                push    word ptr [ScreenIOparams.CursorFlag]
                push    cs
                pop     ds
                mov     ScreenIOparams.CursorLen,14 ;35
                mov     ScreenIOparams.CursorColor,10h
                mov     ScreenIOparams.CursorFlag,1
                call    InitFlags
                call    ShowPathFilter
                call    ShowDirectory
                call    ShowMemory
                call    ShowFuncKeys
                ScreenIOservice _SHOWLINE
                call    ShowTitle
                call    ShowMessage
                call    ShowHilights
                call    ShowConfirm
                call    ShowConfirm1
                pop     word ptr [ScreenIOparams.CursorFlag]
                pop     word ptr [ScreenIOparams.CursorLen]
                pop     word ptr [ScreenIOparams.CursorColor]
                pop     bp ds
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
                test    ActiveFlags,ax
                mov     ah,7
                jz      DB_ok1
                mov     ah,0Eh
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



IF_Procs        dw      IFP_F1,IFP_F2,IFP_F3,IFP_F4,IFP_F5
                dw      IFP_F6,IFP_F7,IFP_F8,IFP_F9,IFP_F0
InitFlags:      push    ax bx si di bp
                xor     bx,bx
                mov     bl,F_or_M
                shl     bx,1
                mov     bp,S_Parameters[bx]
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                xor     si,si
                cmp     DOSflag,0
                mov     FkeysFlags,0000000000b
                jnz     IF_Ret
                cmp     SHL_Flag,0
                mov     FkeysFlags,0000000010b
                jz      IF_Ret
IF_Loop:        call    IF_Procs[si]
                add     si,2
                cmp     si,20
                jb      IF_Loop
                cmp     ActiveFlags,0
                jnz     IF_Ret
                mov     FkeysFlags,0
IF_Ret:         pop     bp di si bx ax
                ret

IFP1_fl         dw      0000000000b,0000000001b,0000000001b,0000000001b
IFP_F1:         cmp     ds:[bp].S_MaxLength,0
                jz      IFP1_Ret
                xor     bx,bx
                mov     bl,ds:[bp].S_Buffer[di].FileType
                shl     bx,1
                mov     ax,IFP1_fl[bx]
                or      FkeysFlags,ax
IFP1_Ret:

IFP_F2:         or      FkeysFlags,0000000010b
                ret

IFP3_fl         dw      0000000000b,0000000100b,0000000100b,0000000100b
IFP_F3:         push    di
                cmp     F_MaxLength,0
                jz      IFP3_Ret
                mov     bl,F_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,FileBuffer[di].FileType
                shl     bx,1
                mov     ax,IFP3_fl[bx]
                or      FkeysFlags,ax
IFP3_Ret:       pop     di
                ret

IFP4_fl         dw      0000000000b,0000001000b,0000001000b,0000001000b
IFP_F4:         push    di
                mov     bl,M_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,MemoryBuffer[di].FileType
                shl     bx,1
                mov     ax,IFP4_fl[bx]
                or      FkeysFlags,ax
                pop     di
                ret

IFP_F5:         push    di
                cmp     F_or_M,0
                jz      IFP5_Ret
                cmp     ds:[bp].S_MaxLength,1
                jbe     IFP5_Ret
                mov     bl,M_Pos
                call    CalcBuffer
                cmp     MemoryBuffer[di].FileName[0],1
                je      IFP5_Ret
                or      FkeysFlags,0000010000b
IFP5_Ret:       pop     di
                ret

IFP_F6:
IFP_F7:
IFP_F8:
IFP_F9:         ret

IFP_F0:         or      FkeysFlags,1100000000b
                test    ActiveFlags,1
                jz      IFP0_Ret
                mov     FkeysFlags,0000000010b
IFP0_Ret:       ret


ST_Str          db      '                              APPLER FILE MANAGER                              ',1,7,' ',0
ShowTitle:      push    ax bx cx
                gotoxy  1,0
                mov     ah,2Fh
                mov     bx,offset ST_Str
                ScreenIOservice _STRINGPRINT
                gotoxy  2,0
                xor     ah,ah
                ScreenIOservice _STRINGPRINT
                pop     cx bx ax
                ret


comment         %
                push    ax dx ds
                mov     ax,2a1h
                mov     ds,ax
                mov     dx,24h
                mov     ax,2509h
                int     21h
                pop     ds dx ax
                int     3
                %

SP_Str          db      'ÚPath&FilterÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
ShowPathFilter: push    ax bx cx dx
                gotoxy  3,0
                mov     bx,offset SP_Str
                mov     dh,3
                mov     ax,0000000000000001b
                call    DrawBox
                mov     bx,35
                xor     al,al
                xchg    PathFilter[bx],al
                mov     bx,offset PathFilter
                mov     ah,0Bh
                gotoxy  5,2
                ScreenIOservice _StringPrint
                mov     bx,35
                xchg    PathFilter[bx],al
                pop     dx cx bx ax
                ret


SD_Str          db      'ÚDirectoryÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0

SD_AntetAddr    dw      SD_Antet1,SD_Antet1,SD_Antet1,SD_Antet1
                dw      SD_Antet3,SD_Antet1,SD_Antet4,SD_Antet1
                dw      SD_Antet2,SD_Antet1,SD_Antet2,SD_Antet1
                dw      SD_Antet3,SD_Antet1,SD_Antet3,SD_Antet1
                dw      SD_Antet5,SD_Antet1,SD_Antet5,SD_Antet1
                dw      SD_Antet7,SD_Antet1,SD_Antet8,SD_Antet1
                dw      SD_Antet6,SD_Antet1,SD_Antet6,SD_Antet1
                dw      SD_Antet7,SD_Antet1,SD_Antet7,SD_Antet1

SD_Antet1       db      1,07h,'N',    'ame          ',      'T',    'ype    ',      'B',    'egin  ',      'E',    'nd',0
SD_Antet2       db      1,07h,'N',    'ame          ',1,0Fh,'T',1,7,'ype    ',      'B',    'egin  ',      'E',    'nd',0
SD_Antet3       db      1,07h,'N',    'ame          ',1,0Fh,'T',1,7,'ype    ',1,0Fh,'B',1,7,'egin  ',1,0Fh,'E',1,7,'nd',0
SD_Antet4       db      1,07h,'N',    'ame          ',      'T',    'ype    ',1,0Fh,'B',1,7,'egin  ',1,0Fh,'E',1,7,'nd',0
SD_Antet5       db      1,0Fh,'N',1,7,'ame          ',      'T',    'ype    ',      'B',    'egin  ',      'E',    'nd',0
SD_Antet6       db      1,0Fh,'N',1,7,'ame          ',1,0Fh,'T',1,7,'ype    ',      'B',    'egin  ',      'E',    'nd',0
SD_Antet7       db      1,0Fh,'N',1,7,'ame          ',1,0Fh,'T',1,7,'ype    ',1,0Fh,'B',1,7,'egin  ',1,0Fh,'E',1,7,'nd',0
SD_Antet8       db      1,0Fh,'N',1,7,'ame          ',      'T',    'ype    ',1,0Fh,'B',1,7,'egin  ',1,0Fh,'E',1,7,'nd',0

SD_Antet0       db      1,7,'ÄÄÄÄÄÄÄÄÄÄÄÄ  ÄÄÄÄÄÄ  ÄÄÄÄÄ  ÄÄÄÄ',0

SD_NotFndMsg    db      1,7,'No Matching Files in Directory',0

ShowDirectory:  push    ax bx cx dx di
                gotoxy  3,40
                mov     bx,offset SD_Str
                mov     dh,21
                mov     ax,0000000000000100b
                call    DrawBox
                cmp     F_MaxLength,0
                jnz     SD_ok2
                gotoxy  5,2Bh
                mov     bx,offset SD_NotFndMsg
                ScreenIOservice _STRINGPRINT
                jmp     SD_Ret
SD_ok2:         mov     bl,F_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,FileBuffer[di].FileFlags
                shl     bx,1
                mov     bx,SD_AntetAddr[bx]
                cmp     SHL_Flag,0
                jz      SD_ok25
                test    ActiveFlags,0000000000000100b
                jnz     SD_ok3
SD_ok25:        mov     bx,offset SD_Antet1
SD_ok3:         gotoxy  5,2Bh
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SD_Antet0
                gotoxy  6,2Bh
                ScreenIOservice _STRINGPRINT
                mov     bl,F_BegPrint
                mov     dx,17
                mov     di,offset FileBuffer
                gotoxy  7,43
                mov     ah,7
SD_Loop0:       call    OneFile
                add     cx,80 * 2
                inc     bl
                cmp     bl,F_MaxLength
                je      SD_Ret0
                dec     dx
                jnz     SD_Loop0
SD_Ret0:        mov     cx,F_CX
                ScreenIOservice _SHOWCURSOR
SD_Ret:         pop     di dx cx bx ax
                ret

SM_Str          db      'ÚMemoryÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
ShowMemory:     push    ax bx cx dx di
                gotoxy  7,0
                mov     bx,offset SM_Str
                mov     dh,16
                mov     ax,0000000000001000b
                call    DrawBox
                mov     bl,M_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,MemoryBuffer[di].FileFlags
                shl     bx,1
                mov     bx,SD_AntetAddr[bx]
                cmp     SHL_Flag,0
                jz      SM_ok25
                test    ActiveFlags,0000000000001000b
                jnz     SM_ok3
SM_ok25:        mov     bx,offset SD_Antet1
SM_ok3:         gotoxy  9,3
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SD_Antet0
                gotoxy  10,3
                ScreenIOservice _STRINGPRINT
                mov     bl,M_BegPrint
                mov     dx,12
                mov     di,offset MemoryBuffer
                gotoxy  11,3
                mov     ah,0Bh
SM_Loop0:       call    OneFile
                add     cx,80 * 2
                inc     bl
                cmp     bl,M_MaxLength
                jae     SM_Ret0
                dec     dx
                jnz     SM_Loop0
SM_Ret0:        cmp     NameEntering,0
                jnz     SM_Ret
                mov     cx,M_CX
                mov     ScreenIOparams.CursorColor,40h
                ScreenIOservice _SHOWCURSOR
SM_Ret:         pop     di dx cx bx ax
                ret


SMS_Clear       db      '                                        ',0
SMS_ReadDir     db      'Accessing Disk Directory...',0
SMS_FileLoaded  db      'File loaded',0
SMS_FileSaved   db      'File saved',0
SMS_StatLoaded  db      'Status restored',0
SMS_StatSaved   db      'Status saved',0
SMS_ErrFileLoad db      1,0Ch,'Error loading file',0
SMS_ErrFileSave db      1,0Ch,'Error saving file',0
SMS_ErrStatLoad db      1,0Ch,'Error restoring status',0
SMS_ErrStatSave db      1,0Ch,'Error saving status',0
SMS_EnterFilename db    'Enter Filename (<Esc> cancel)',0
ShowMessage:    push    ax bx cx
                gotoxy  18h,0
                mov     bx,offset SMS_Clear
                mov     ah,0Ah
                ScreenIOservice _STRINGPRINT
                cmp     GetKeyParams.RK_ErrPtr,0
                jz      SMS_Ret
                gotoxy  18h,1
                mov     bx,GetKeyParams.RK_ErrPtr
                ScreenIOservice _STRINGPRINT
SMS_Ret:        pop     cx bx ax
                ret



SFK_Str         db      '1       2       3       4       5       '
                db      '6       7       8       9      10       ',0
FkeysFlags      dw      1111111111b
SFK_FkeysMain   dw      SFK_Run,SFK_Cont,SFK_Load,SFK_Save,SFK_Delete
                dw      SFK_None,SFK_None,SFK_None,SFK_PathFilter,SFK_Rescan
SFK_Run         db      1,2Fh,'Run   ',0
SFK_Cont        db      1,2Fh,'Apple ',0
SFK_Load        db      1,1Fh,'Load  ',0
SFK_Save        db      1,4Fh,'Save  ',0
SFK_Delete      db      1,2Fh,'Delete',0
SFK_PathFilter  db      1,2Fh,'Path&F',0
SFK_Rescan      db      1,2Fh,'Rescan',0
SFK_None        db      1,2Fh,'      ',0

ShowFuncKeys:   push    ax bx cx dx si
                gotoxy  19h,0
                mov     bx,offset SFK_Str
                mov     ah,7
                ScreenIOservice _STRINGPRINT
                gotoxy  19h,1
                xor     si,si
                mov     dx,FkeysFlags
SFK_Loop0:      shr     dx,1
                mov     ah,8
                jnc     SFK_Next0
                mov     ah,0Fh
SFK_Next0:      mov     bx,SFK_FkeysMain[si]
                and     byte ptr [bx+1],0F0h
                or      byte ptr [bx+1],ah
                ScreenIOservice _STRINGPRINT
                add     cx,4
                add     si,2
                cmp     si,20
                jb      SFK_Loop0
                pop     si dx cx bx ax
                ret

SHL_Flag        db      1
ShowHilights:   cmp     SHL_Flag,0
                jz      SHL_Ret
                push    ax cx
                gotoxy  3,1
                mov     ax,0E00h+'P'
                ScreenIOservice _SYMBPRINT
                gotoxy  3,41
                mov     al,'D'
                ScreenIOservice _SYMBPRINT
                gotoxy  7,1
                mov     al,'M'
                ScreenIOservice _SYMBPRINT
                pop     cx ax
SHL_Ret:        ret


SC_Str          db      'ÚConfirmÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                               ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SC_FileMes      db      1,7,'File ',1,0Fh,0
SC_AlreadyMes   db      1,7,' already exists.',0
SC_SureMes      db      1,7,'Are you sure you want to overwrite this file?',0
SC_Flag         db      0
ShowConfirm:    cmp     SC_Flag,0
                jz      SC1_Ret
                push    ax bx cx dx di
                gotoxy  9,7
                mov     bx,offset SC_Str
                mov     dh,6
                mov     ax,0000000000010000b
                call    DrawBox
                gotoxy  11,9
                mov     bx,offset SC_FileMes
                ScreenIOservice _STRINGPRINT
                mov     bl,M_Pos
                call    CalcBuffer
                lea     bx,MemoryBuffer[di].FileName
                mov     ah,0Fh
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SC_AlreadyMes
                ScreenIOservice _STRINGPRINT
                gotoxy  13,9
                mov     bx,offset SC_SureMes
                ScreenIOservice _STRINGPRINT
                pop     di dx cx bx ax
SC1_Ret:        ret



SC1_Str         db      'ÚConfirmÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                                   ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
SC1_FileMes     db      1,7,'File ',1,0Fh,0
SC1_OverWritten db      1,7,' is overwritten by another file.',0
SC1_SureMes     db      1,7,'Are you sure you want to save this file?',0
SC1_Flag        db      0
ShowConfirm1:   cmp     SC1_Flag,0
                jz      SC_Ret
                push    ax bx cx dx di
                gotoxy  16,20
                mov     bx,offset SC1_Str
                mov     dh,6
                mov     ax,0000000000010000b
                call    DrawBox
                gotoxy  18,22
                mov     bx,offset SC1_FileMes
                ScreenIOservice _STRINGPRINT
                mov     bl,M_Pos
                call    CalcBuffer
                lea     bx,MemoryBuffer[di].FileName
                mov     ah,0Fh
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SC1_OverWritten
                ScreenIOservice _STRINGPRINT
                gotoxy  20,22
                mov     bx,offset SC1_SureMes
                ScreenIOservice _STRINGPRINT
                pop     di dx cx bx ax
SC_Ret:         ret



OF_CX           dw      ?
OF_Types        dw      OF_Directory,OF_Code,OF_Status,OF_MSdos
OF_Directory    db      1,7,'<DIR>',0
OF_Code         db      'DOS3.3',0
OF_Status       db      'Status',0
OF_MSdos        db      'MS-DOS',0
OF_NoAddr       db      1,7,' --     -- ',0
OF_Base         dw      ?
OF_Color        db      ?
OneFile:        push    ax bx cx dx di
                mov     OF_Base,di
                mov     OF_CX,cx
                call    CalcBuffer
                mov     bp,OF_Base
                lea     bx,ds:[bp][di].FileName
                test    ds:[bp][di].FileFlags,FF_DAMAGED?
                mov     OF_Color,0Bh
                jz      OF_hop1
                mov     ah,0Ch
                mov     OF_Color,ah
OF_hop1:        ScreenIOservice _STRINGPRINT
                cmp     byte ptr ds:[bx],1
                je      OF_Ret
                mov     cx,OF_CX
                add     cx,2*14
                xor     bx,bx
                mov     bp,OF_Base
                mov     bl,ds:[bp][di].FileType
                shl     bx,1
                mov     bx,OF_Types[bx]
                mov     ah,OF_Color
                ScreenIOservice _STRINGPRINT
                mov     cx,OF_CX
                add     cx,2*22
                mov     bx,offset OF_NoAddr
                ScreenIOservice _STRINGPRINT
                mov     bp,OF_Base
                test    ds:[bp][di].FileFlags,FF_SHOWADDR?
                jz      OF_Ret
                mov     cx,OF_CX
                add     cx,2*22
                mov     ah,OF_Color
                mov     bp,OF_Base
                mov     al,byte ptr ds:[bp][di].FileBegAdr[1]
                ScreenIOservice _BYTEPRINT
                mov     bp,OF_Base
                mov     al,byte ptr ds:[bp][di].FileBegAdr[0]
                ScreenIOservice _BYTEPRINT
                mov     bp,OF_Base
                mov     cx,OF_CX
                add     cx,2*29
                mov     ah,OF_Color
                mov     bp,OF_Base
                mov     al,byte ptr ds:[bp][di].FileEndAdr[1]
                ScreenIOservice _BYTEPRINT
                mov     bp,OF_Base
                mov     al,byte ptr ds:[bp][di].FileEndAdr[0]
                ScreenIOservice _BYTEPRINT
OF_Ret:         pop     di dx cx bx ax
                ret




; *******************************************************************
; **                                                               **
; **                                                               **
; **               K E Y B O A R D   S E R V I C E S               **
; **                                                               **
; **                                                               **
; *******************************************************************

GetLineUser     proc    far
                ret
GetLineUser     endp

Alt_Keys        db      'pdm'
Alt_Procs       dw      Alt_PathFilter,Alt_Directory,Alt_Memory
Alt_Key         proc    far
                push    cx si di ds
                mov     di,offset Alt_Keys
                mov     cx,offset Alt_Procs- offset Alt_Keys
                call    CalcCommand
                jc      Alt_Ret
                shl     di,1
                call    cs:Alt_Procs[di]
                mov     al,7Fh
Alt_Ret:        pop     ds di si cx
                ret

Alt_PathFilter  proc    near
                mov     cs:GoWhere?,G_PATH_FILTER
                ret
Alt_PathFilter  endp

Alt_Directory   proc    near
                mov     cs:GoWhere?,G_DIRECTORY
                ret
Alt_Directory   endp

Alt_Memory      proc    near
                mov     cs:GoWhere?,G_MEMORY
                ret
Alt_Memory      endp

Alt_Key         endp



FkeysMasks      dw      1b,10b,100b,1000b,10000b,100000b,1000000b,10000000b,100000000b,1000000000b
Fkeys_Main      dw      Fkey_Run,Fkey_Cont,Fkey_Load,Fkey_Save,Fkey_Delete
                dw      ?,?,?,Fkey_PathFilter,Fkey_Rescan
Fkey            proc    far
                push    ax bx cx dx si di bp ds es
                push    cs
                pop     ds
                push    word ptr ds:[ScreenIOparams.CursorLen]
                push    word ptr ds:[ScreenIOparams.CursorFlag]
                push    ds:[GetLineParams.GL_Buffer]
                push    ds:[GetLineParams.GL_CX]
                push    [ActiveFlags]
                push    [FkeysFlags]
                xor     bx,bx
                mov     bl,al
                shl     bx,1
                mov     si,bx
                mov     ax,FkeysMasks[si]
                test    FkeysFlags,ax
                jz      Fkey_Ret
                xor     bx,bx
                mov     bl,F_or_M
                shl     bx,1
                mov     bp,S_Parameters[bx]
                call    Fkeys_Main[si]
                xor     bx,bx
                mov     bl,F_or_M
                shl     bx,1
                mov     bp,S_Parameters[bx]
                mov     cx,ds:[bp].S_CX
Fkey_Ret:       pop     [FkeysFlags]
                pop     [ActiveFlags]
                pop     ds:[GetLineParams.GL_CX]
                pop     ds:[GetLineParams.GL_Buffer]
                pop     word ptr ds:[ScreenIOparams.CursorFlag]
                pop     word ptr ds:[ScreenIOparams.CursorLen]
                pop     es ds bp di si dx cx bx ax
                ret
Fkey            endp

FU_Procs        dw      FU_Dir,FU_Code,FU_Status,FU_MSDos
Fkey_Update:    push    ax bx di
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                test    ds:[bp].S_Buffer[di].FileFlags,FF_DAMAGED?
                jnz     FU_Ret
                test    ds:[bp].S_Buffer[di].FileFlags,FF_MODIFYADDR?
                jz      FU_Ret
                xor     bx,bx
                mov     bl,ds:[bp].S_Buffer[di].FileType
                shl     bx,1
                call    FU_Procs[bx]
FU_Ret:         pop     di bx ax
                ret

FU_Dir:         ret

FU_Code:        mov     ax,word ptr ds:[bp].S_Buffer[di].File1st4bytes
                mov     ds:[bp].S_Buffer[di].FileBegAdr,ax
                mov     ax,word ptr ds:[bp].S_Buffer[di].File1st4bytes[2]
                add     ax,ds:[bp].S_Buffer[di].FileBegAdr
                jnc     FU_Code_ok
                xor     ax,ax
FU_Code_ok:     dec     ax
                mov     ds:[bp].S_Buffer[di].FileEndAdr,ax
                ret

FU_Status:      xor     ax,ax
                mov     ds:[bp].S_Buffer[di].FileBegAdr,ax
                dec     ax
                mov     ds:[bp].S_Buffer[di].FileEndAdr,ax
                ret

FU_MSdos:       mov     ds:[bp].S_Buffer[di].FileBegAdr,800h
                mov     ax,ds:[bp].S_Buffer[di].FileLength
                add     ax,800h
                jnc     FU_MSdos_ok
                xor     ax,ax
FU_MSdos_ok:    dec     ax
                mov     ds:[bp].S_Buffer[di].FileEndAdr,ax
                ret

Fkey_RunProcs   dw      FRP_Run,FRP_Go
Fkey_Run:       mov     si,bx
                mov     bl,ds:[bp].S_Pos
                call    CalcBuffer
                cmp     ds:[bp].S_Buffer[di].FileType,FD_Code
                jb      Fkey_RunRet
                mov     bx,ds:[bp].S_Buffer[di].FileBegAdr
                call    Fkey_RunProcs[si]
Fkey_RunRet:    ret

FRP_RunProgram  db      0A9h,20h,0A9h,0,0A9h,3,0A9h,3Ch,4Ch
FRP_RunAddress  dw      ?
FRP_Procs       dw      FRPP_Directory,FRPP_Code,FRPP_Status,FRPP_MSdos
FRP_Run:        call    ResetAppleII
                mov     bp,offset DirectoryParams
                call    S_Enter
                cmp     S_EnterErrorFL,0
                jnz     FRP_RunRet
                push    bx
                mov     bl,M_MaxLength
                sub     bl,2
                call    CalcBuffer
                pop     bx
                xor     ax,ax
                mov     al,MemoryBuffer[di].FileType
                mov     di,ax
                shl     di,1
                call    FRP_Procs[di]
                call    GoAppleII
FRP_RunRet:     ret

FRPP_MSdos:
FRPP_Code:      push    es
                mov     ax,Apple
                mov     es,ax
                assume  es:Apple
                mov     GetKeyParams.RK_ErrPtr,0
                mov     FRP_RunAddress,bx
                mov     di,0C700h
                mov     si,offset FRP_RunProgram
                mov     cx,11
                cld
                rep     movsb
                pop     es
                ret
                assume  es:Emulate

FRPP_Damaged:
FRPP_Directory:
FRPP_Status:    ret


FRP_Go:         push    ds
                cmp     ds:[bp].S_Buffer[di].FileType,FD_Status
                je      FRPG_NoBegAdr
                mov     ax,TaskControl
                mov     ds,ax
                assume  ds:TaskControl
                mov     ds:r_PC,bx
FRPG_NoBegAdr:  pop     ds
                assume  ds:FM
                call    GoAppleII
                ret



Fkey_Cont:      call    GoAppleII
                ret

Fkey_Load:      mov     bp,offset DirectoryParams
                call    S_EnterF
                ret

Fkey_Save:      push    word ptr F_or_M
                mov     F_or_M,1
                mov     bp,offset MemoryParams
                call    S_EnterM
                pop     word ptr F_or_M
                ret

Fkey_Delete:    mov     bl,ds:[bp].S_Pos
                call    Delete
                ret

Fkey_PathFilter: call   S_PathFilter
                ret

Fkey_Rescan:    call    ReadDir
                ret


RA_FictiveName  db      'ESD$$$$$.$$$',0
ResetAppleII    proc    far
                push    ax bx cx dx si di bp ds es
                pushf
                cli
                call    SystemRESET
                popf
                push    cs
                pop     ds
                mov     ax,Apple
                mov     es,ax
                assume  es:Apple
                xor     di,di
                mov     cx,0C000h
                xor     al,al
                cld
        rep     stosb
                xor     ax,ax
                mov     bx,0C000h
                mov     si,offset RA_FictiveName
                mov     cx,102h
                call    FileIsLoaded            ; Reset done!
                mov     bp,offset MemoryParams
                mov     bl,M_Pos
                call    Delete
                call    S_Up
                mov     bx,es:[0FFFCh]
                mov     ax,TaskControl
                mov     es,ax
                assume  es:TaskControl
                mov     es:r_PC,bx
                pop     es ds bp di si dx cx bx ax
                ret
ResetAppleII    endp
                assume  es:Emulate


GoAppleII:      push    ax bx es
                xor     bx,bx
                xchg    bx,ActiveFlags
                call    ShowAll
                ScreenIOservice _SHOWSCREEN
		mov     ax,Emulate
                mov     es,ax
                mov     al,C050
                ScreenIOservice _SetScreen
                SwitchToProcess PID_EMULATOR
                mov     ActiveFlags,bx
                pop     es bx ax
                ret

FM              ends

		END

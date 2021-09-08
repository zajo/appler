;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      DM.ASM                          |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Disk Manager                    |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC
                include DM.INC

G_DIRECTORY     =       0
G_PATH_FILTER   =       1
G_IMAGE         =       2
G_D1            =       3
G_D2            =       4

DM              segment public
                assume  cs:DM,ds:DM,es:Emulate

ManagerState    db      MS_NORMAL
GetLineBuf      db      80h dup (0)

GetLineParams   GL_ParamStruc <?,0,1,1,5,0,0,20h,40h,0,?,?,0Bh,1,0,GetLineUser,?,?,?,?>
ScreenIOParams  SIO_ParamStruc <1,DM,0,0,offset Screen,seg Screen,1,0,1,1>
GetKeyParams    RK_ParamStruc <1,Fkey,1,Alt_Key,0,?,ShowAll,0 >

disk1_ptr       dd      CurrentDrive
disk2_ptr       dd      OtherDrive
set_ptrs:       push    ax bx ds
                pushf
                mov     ds,word ptr cs:disk1_ptr[2]
                assume  ds:seg CurrentDrive
                cmp     ds:CurrentDrive.ID,0
                mov     ax,offset CurrentDrive
                mov     bx,offset OtherDrive
                jz      set_ptrs_1
                xchg    ax,bx
set_ptrs_1:     mov     word ptr cs:disk1_ptr[0],ax
                mov     word ptr cs:disk2_ptr[0],bx
                popf
                pop     ds bx ax
                ret

                assume  es:seg CurrentDrive
present1:       push    bp es
                les     bp,disk1_ptr
                cmp     es:[bp].FileHandle,0FFFFh
                pop     es bp
                ret

present2:       push    bp es
                les     bp,disk2_ptr
                cmp     es:[bp].FileHandle,0FFFFh
                pop     es bp
                ret
                assume  es:Emulate

DMInInit        proc    far
                call    DM_InInitP
                call    UnSetBreaks
                ret
DMInInit        endp

DMOutInit       proc    far
                push    ax es
                call    DM_OutInitP
                mov     ax,seg T_Iflags
                mov     es,ax
                assume  es:seg T_Iflags
                mov     byte ptr es:T_Iflags,00000010b
                assume  es:Emulate,ds:DM
                call    AppleKeysOn
                call    SetBreaks
                pop     es ax
                ret
DMOutInit       endp

DM_InInitP      proc    near
                cli
                push    ax bx ds es
                mov     ax,Emulate
                mov     es,ax
                mov     al,es:[C000]
                mov     cs:KeyPressed,al
                mov     es:[C000],0
                call    DebugKeysOn
                call    set_ptrs
                mov     ax,CONio
                mov     ds,ax
                assume  ds:CONio
                mov     GL_ParamsOfs,  offset GetLineParams
                mov     GL_ParamsSeg,  seg    GetLineParams
                mov     SIO_ParamsOfs, offset ScreenIOParams
                mov     SIO_ParamsSeg, seg    ScreenIOParams
                mov     RK_ParamsOfs,  offset GetKeyParams
                mov     RK_ParamsSeg,  seg    GetKeyParams
                assume  ds:DM
                pop     es ds bx ax
                sti
                ret
DM_InInitP      endp

KeyPressed      db      0
DM_OutInitP     proc    near
                cli
                push    ax es
                mov     ax,Emulate
                mov     es,ax
                mov     al,cs:KeyPressed
                mov     es:[C000],al
                assume  es:Emulate
                pop     es ax
                ret
DM_OutInitP     endp



GoWhere?        dw      G_D1
DM_FirstFlag    db      1
DM_MainRet:     push    cs
                pop     ds
                cmp     DM_FirstFlag,0
                jz      BigLoop
                mov     DM_FirstFlag,0
                call    ShowAll
                mov     DirectoryParams.S_MaxLength,0
                call    ReadDir
BigLoop:        mov     GetLineParams.GL_Color,0Bh
                mov     GetLineParams.GL_CX,80*2
                mov     di,GoWhere?
                shl     di,1
                mov     GoWhere?,G_D1
                call    CmndAddress[di]
                call    ShowAll
                jmp     BigLoop

CmndAddress     dw      Directory,S_PathFilter,Image,D1,D2

I_Current       db      0
I_CurrentSVD    db      0
I_FirstTime?    db      1
I_CH            db      15,15,15,16,17,17,17,19,19,19,20,21,21,21,22
I_CL            db      29,32,35,29,29,32,35,29,32,35,29,29,32,35,29
I_Keys          db      '0123456789abcdef'
                db      5,6,7,8,1,2,20h
                db      0Ch,18h,7Fh
I_Procs         dw      I_Num,I_Num,I_Num,I_Num,I_Num,I_Num,I_Num,I_Num
                dw      I_Num,I_Num,I_Num,I_Num,I_Num,I_Num,I_Num,I_Num
                dw      I_Left,I_Right,I_Up,I_Down,I_Home,I_End,I_Space
                dw      I_Esc,I_Enter,I_7Fh
Image:          push    es
                mov     ScreenIOparams.CursorColor,40h
                mov     ScreenIOparams.CursorFlag,1
                mov     ScreenIOparams.CursorLen,4
                mov     cs:ActiveFlags,0000000000010000b
                mov     I_FirstTime?,1
                mov     bx,seg SectorImage
                mov     es,bx
                assume  es:seg SectorImage
                xor     bx,bx
                mov     bl,I_CurrentSVD
                mov     I_Current,bl
I_Loop:         xor     bx,bx
                mov     bl,I_Current
                mov     ch,I_CH[bx]
                mov     cl,I_CL[bx]
                dec     cl
                call    ReadKey
                mov     di,offset I_Keys
                mov     cx,offset I_Procs - offset I_Keys
                call    CalcCommand
                jc      I_Loop
                shl     di,1
                xor     bx,bx
                mov     bl,I_Current
                call    I_Procs[di]
                jnc     I_Loop
                pop     es
                mov     bl,I_Current
                mov     I_CurrentSvd,bl
                ret

I_OffsetAddr    db      AddressProlog,AddressProlog+1,AddressProlog+2
                db      AddressCheckSum
                db      AddressEpilog,AddressEpilog+1,AddressEpilog+2
                db      DataProlog, DataProlog+1, DataProlog+2
                db      DataCheckSum
                db      DataEpilog, DataEpilog+1, DataEpilog+2
                db      EndByte
I_Num:          mov     bl,I_OffsetAddr[bx]
                xor     bh,bh
                shr     di,1
                mov     ax,di
                cmp     cs:I_FirstTime?,0
                jz      I_NumByte_1
                mov     byte ptr es:SectorImage[bx],0
I_NumByte_1:    shl     byte ptr es:SectorImage[bx],4
                or      byte ptr es:SectorImage[bx],al
                clc
                mov     I_FirstTime?,0
                ret

I_Left:         dec     I_Current
                jns     I_LeftOk
                mov     I_Current,size SectorImage_S - 1
I_LeftOk:       clc
                mov     I_FirstTime?,1
                ret

I_SpaceFlags    db      0,1,1,1,1,1,1,0,1,1,1,1,1,1,1
I_Space:        cmp     I_SpaceFlags[bx],0
                jz      I_SpcRet
                mov     bl,I_OffsetAddr[bx]
                xor     bh,bh
                xor     byte ptr es:SectorImageF[bx],0FFh
                cmp     cs:I_FirstTime?,1
I_SpcRet:       clc
                ret

I_Enter:
I_Right:        inc     I_Current
                cmp     I_Current,size SectorImage_S
                jb      I_RightOk
                mov     I_Current,0
I_RightOk:      clc
                mov     I_FirstTime?,1
                ret

I_Ups           db      14,12,13,0,3,1,2,4,5,6,7,10,8,9,11
I_Up:           mov     al,I_Ups[bx]
                mov     I_Current,al
                clc
                mov     I_FirstTime?,1
                ret

I_Downs         db      3,5,6,4,7,8,9,10,12,13,11,14,1,2,0
I_Down:         mov     al,I_Downs[bx]
                mov     I_Current,al
                clc
                mov     I_FirstTime?,1
                ret

I_Home:         mov     I_Current,0
                clc
                mov     I_FirstTime?,1
                ret

I_End:          mov     I_Current,size SectorImage_S - 1
                clc
                mov     I_FirstTime?,1
                ret

I_Esc:          call    GoAppleII
                clc
                ret

I_7Fh:          stc
                ret


                assume  es:Emulate
S_ParamsStruc   struc
S_MaxLength     db      0
S_BegPrint      db      ?
S_Pos           db      ?
S_CX            dw      ?
S_LinesNum      db      ?
S_Buffer        db      ?
S_ParamsStruc   ends
DirectoryParams S_ParamsStruc <0,0,0,0B2Ah,13>
                db      100h * size DiskDescription dup (0)

S_Commands      db      'ta',18h
                db      7,8,3,4,1,2,0Ch
S_Subrt         dw      S_Type,S_Access,S_Enter
                dw      S_Up,S_Down,S_PgUp,S_PgDn,S_Home,S_End,GoAppleII
S_CallIfZero?   db      0,0,0,0,0,0,0,0,0
Directory:      xor     bx,bx
                mov     SHL_Flag,1
                mov     GetLineParams.GL_AllowSpc,0
                gotoxy  2,0
                mov     GetLineParams.GL_CX,cx
                mov     ActiveFlags,0000000000000010b
                mov     FkeysFlags,1111111111b
                mov     ScreenIOparams.CursorFlag,0
                mov     cx,DirectoryParams.S_CX
                call    ReadKey
                cmp     al,7Fh
                je      SelectRet
                mov     di,offset S_Commands
                mov     cx,offset S_Subrt- offset S_Commands
                call    CalcCommand
                jc      Directory
                cmp     DirectoryParams.S_MaxLength,0
                jnz     S_ok1
                test    S_CallIfZero?[di],1
                jz      Directory
S_ok1:          shl     di,1
                call    S_Subrt[di]
                jmp     Directory
SelectRet:      GetLineService _GL_CLRBUFF
                ret

S_Up:           push    ax
                mov     al,DirectoryParams.S_Pos
                or      al,al
                jz      S_UpRet
                dec     al
                mov     ah,al
                sub     ah,DirectoryParams.S_BegPrint
                cmp     ah,2
                jae     S_UpOk1
                cmp     DirectoryParams.S_BegPrint,0
                jz      S_UpOk1
                dec     DirectoryParams.S_BegPrint
                inc     byte ptr DirectoryParams.S_CX[1]
S_UpOk1:        dec     byte ptr DirectoryParams.S_CX[1]
S_UpRet:        mov     DirectoryParams.S_Pos,al
                pop     ax
                ret

S_Down:         push    ax
                mov     al,DirectoryParams.S_Pos
                mov     ah,DirectoryParams.S_MaxLength
                dec     ah
                cmp     al,ah
                je      S_DownRet
                inc     al
                mov     ah,al
                sub     ah,DirectoryParams.S_BegPrint
                add     ah,2
                cmp     ah,DirectoryParams.S_LinesNum
                jb      S_DownOk1
                mov     ah,DirectoryParams.S_BegPrint
                add     ah,DirectoryParams.S_LinesNum
                jc      S_DownOk1
                cmp     ah,DirectoryParams.S_MaxLength
                jae     S_DownOk1
                inc     DirectoryParams.S_BegPrint
                dec     byte ptr DirectoryParams.S_CX[1]
S_DownOk1:      inc     byte ptr DirectoryParams.S_CX[1]
S_DownRet:      mov     DirectoryParams.S_Pos,al
                pop     ax
                ret

S_PgUp:         push    cx
                xor     ch,ch
                mov     cl,DirectoryParams.S_LinesNum
                dec     cx
S_PgUpLoop:     call    S_Up
                loop    S_PgUpLoop
                pop     cx
                ret

S_PgDn:         push    cx
                xor     ch,ch
                mov     cl,DirectoryParams.S_LinesNum
                dec     cx
S_PgDnLoop:     call    S_Down
                loop    S_PgDnLoop
                pop     cx
                ret

S_Home:         push    cx
                mov     cx,100h
                dec     cx
S_HomeLoop:     call    S_Up
                loop    S_HomeLoop
                pop     cx
                ret

S_End:          push    cx
                mov     cx,100h
                dec     cx
S_EndLoop:      call    S_Down
                loop    S_EndLoop
                pop     cx
                ret

S_Access:       push    bx di
                mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                test    DirectoryParams.S_Buffer[di].FileFlag,FF_DAMAGED?
                jnz     S_AccessRet
                xor     DirectoryParams.S_Buffer[di].FileFlag,FF_READ_ONLY?
S_AccessRet:    pop     di bx
                ret

S_TypeNewVal    db      FD_Directory,FD_DOS33,FD_Nibble
S_Type:         push    ax bx di
                mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                mov     al,DirectoryParams.S_Buffer[di].FileFlag
                test    al ,FF_DAMAGED?
                jnz     S_TypeRet
                test    al,FF_MODIFYTYPE?
                jz      S_TypeRet
                xor     bx,bx
                mov     bl,DirectoryParams.S_Buffer[di].FileType
                mov     bl,S_TypeNewVal[bx]
                mov     DirectoryParams.S_Buffer[di].FileType,bl
S_TypeRet:      pop     di bx ax
                ret

S_EnterProcs    dw      SE_Directory,SE_Nibble,SE_DOS33
S_Enter:        push    ax bx cx dx si di ds es
                cmp     ManagerState,MS_NORMAL
                jne     S_EnterRet
                cmp     DirectoryParams.S_MaxLength,0
                jz      S_EnterRet
                mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                test    DirectoryParams.S_Buffer[di].FileFlag,FF_DAMAGED?
                jnz     S_EnterRet
                xor     bx,bx
                mov     bl,DirectoryParams.S_Buffer[di].FileType
                mov     si,bx
                mov     bx,di
                call    LinkName
                shl     si,1
                mov     dx,offset Path
                call    S_EnterProcs[si]
                call    UnLinkName
S_EnterRet:     pop     es ds di si dx cx bx ax
                ret

SE_Directory:   mov     bx,LN_BX
                mov     byte ptr Path[bx],'\'
                mov     byte ptr Path[bx+1],0
                call    ReadDir
                ret

SE_DOS33:
SE_Nibble:      test    ActiveFlags,0000000000001000b
                mov     ax,offset Fkey_InsertB
                jnz     SE_1
                mov     ax,offset Fkey_InsertA
SE_1:           call    ax
                ret



D1:             mov     DN,0
                mov     ActiveFlags,0000000000000100b
                jmp     Drive

D2:             mov     DN,1
                mov     ActiveFlags,0000000000001000b
                jmp     Drive

D_Chars         db      'av'
                db      7,8,3,4,1,2,18h,0Ch
D_Procs         dw      D_Access,D_Volume
                dw      S_Up,S_Down,S_PgUp,S_PgDn,S_Home,S_End,S_Enter,GoAppleII
D_CallIfZero?   db      0,0,1,1,1,1,1,1,1,1
DN              db      ?
Drive:          push    es
D_Loop:         call    ReadKey
                cmp     al,7Fh
                je      D_Ret
                cmp     DN,0
                mov     dx,offset SDA_Filename
                mov     bx,offset present1
                les     bp,disk1_ptr
                jz      D_ok1
                mov     dx,offset SDA_Filename
                mov     bx,offset present2
                les     bp,disk2_ptr
                assume  es:seg CurrentDrive
D_ok1:          mov     di,offset D_Chars
                mov     cx,offset D_Procs - offset D_Chars
                call    CalcCommand
                jc      D_Loop
                call    bx
                jnz     D_ok2
                cmp     D_CallIfZero?[di],0
                jz      D_Loop
D_ok2:          shl     di,1
                call    D_Procs[di]
                jmp     D_Loop
D_Ret:          pop     es
                ret

D_Access:       push    ax cx
                call    Prepare4DOS
                mov     ax,4300h
                int     21h
                jc      D_AccessError
                mov     ax,4301h
                xor     cx,1
                int     21h
                jc      D_AccessError
                xor     es:[bp].WriteProtect,0FFh
D_AccessExit:   call    SOD4eraperP
                pop     cx ax
                ret

D_RemoveDisk    dw      Fkey_RemoveA,Fkey_RemoveB
D_AccessError:  xor     bh,bh
                mov     bl,DN
                shl     bx,1
                call    D_RemoveDisk[bx]
                jmp     D_AccessExit


D_VolCXs        dw      622h,0B22h
D_Vol_First?    db      ?
D_VolNums       db      '0123456789abcdef'
D_Volume:       push    word ptr [GetKeyParams.RK_AltFlag]
                cmp     es:[bp].DiskType,0
                jz      D_VolRet
                mov     ScreenIOparams.CursorColor,40h
                mov     ScreenIOparams.CursorFlag,1
                mov     ScreenIOparams.CursorLen,4
                mov     SHL_Flag,0
                mov     GetKeyParams.RK_AltFlag,0
                mov     D_Vol_First?,1
D_VolLoop:      xor     bh,bh
                mov     bl,DN
                shl     bx,1
                mov     cx,D_VolCXs[bx]
                call    ReadKey
                cmp     al,0Ch
                je      D_VolRet
                cmp     al,18h
                je      D_VolRet
                mov     di,offset D_VolNums
                mov     cx,16
                call    CalcCommand
                jc      D_VolLoop
                mov     bl,es:[bp].Volume
                cmp     D_Vol_First?,0
                jz      D_VolNotFirst
                xor     bl,bl
                mov     D_Vol_First?,bl
D_VolNotFirst:  shl     bl,4
                or      bx,di
                mov     es:[bp].Volume,bl
                jmp     D_VolLoop
D_VolRet:       mov     ScreenIOparams.CursorFlag,0
                mov     SHL_Flag,1
                pop     word ptr [GetKeyParams.RK_AltFlag]
                ret
                assume  es:Emulate


S_PathFilter:   push    word ptr cs:[ScreenIOparams.CursorFlag]
                push    word ptr cs:[GetKeyParams.RK_AltFlag]
                mov     SHL_Flag,0
                mov     GetKeyParams.RK_AltFlag,0
                mov     GetLineParams.GL_AllowSpc,0
                mov     ActiveFlags,0000000000000001b
                mov     FkeysFlags,0000000101b
                mov     ScreenIOparams.CursorFlag,1
                mov     GetLineParams.GL_Buffer,offset PathFilter
                mov     GetLineParams.GL_Pos,0
                mov     GetLineParams.GL_BegPrint,0
                mov     GetLineParams.GL_MaxLength,67+20h
                mov     GetLineParams.GL_MaxPrint,35
                mov     ScreenIOparams.CursorLen,1
                call    LinkPathFilter
                mov     GetLineParams.GL_Length,bl
                gotoxy  5,42
                GetLineService _GETLINE
                call    GetPathFilter
                call    ReadDir
                pop     word ptr cs:[GetKeyParams.RK_AltFlag]
                pop     word ptr cs:[ScreenIOparams.CursorFlag]
                mov     SHL_Flag,1
                GetLineService _GL_CLRBUFF
                clc
                ret

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

GPF_DefaultFilt db      '*.DSK,*.NBL',0
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



; -- Read Directory ------------------

RD_GetDirs?     db      1
Path            db      '.\',66 dup (0)         ; Current Path
Filter          db      '*.DSK,*.NBL',020h dup (0) ; Scan Filter
PathFilter      db      67+20h dup (0)          ; Path&Filter
WildCard        db      0Dh dup (0)             ; Temp
WC_AnyFile      db      '*.*',0                 ; For SubDirs scanning

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
                cmp     DirectoryParams.S_MaxLength,0FEh
                je      RD_NoMoreFiles
                call    RD_PutFile
                inc     DirectoryParams.S_MaxLength
                add     bx,size DiskDescription
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
                mov     cx,FA_ARCHIVE or FA_READ_ONLY
                FindFirst
                jc      RD_NoMoreFiles
RD_GetFilesLoop: cmp    DirectoryParams.S_MaxLength,0FEh
                je      RD_NoMoreFiles
                call    RD_PutFile
                inc     DirectoryParams.S_MaxLength
                add     bx,size DiskDescription
                FindNext
                jnc     RD_GetFilesLoop

RD_NoMoreFiles: mov     si,RD_0OfsSvd
                mov     byte ptr Path[si],0
                mov     BufPtr,bx
                call    SOD4eraperP
                pop     es di si dx cx bx ax
                ret
ReadDirectory   endp



PF_FileExts     db      'NBLDSK'
PF_FileTypes    db      FD_Nibble,FD_DOS33
PF_Addr         dw      PF_Directory,PF_Nibble,PF_DOS33
PF_NameLength   dw      ?
RD_PutFile      proc    near
                push    ax cx dx si di bp es
                xor     si,si
PF_GetNameLoop: mov     al,DTA.FileSpec[si]
                mov     DirectoryParams.S_Buffer[bx].FileName[si],al
                inc     si
                or      al,al
                jnz     PF_GetNameLoop
                mov     PF_NameLength,si

                or      bx,bx
                jz      PF_Cont1
                xor     bp,bp
PF_Cmp0:        xor     di,di
PF_Cmp1:        mov     al,DirectoryParams.S_Buffer[bp].FileName[di]
                cmp     al,DirectoryParams.S_Buffer[bx].FileName[di]
                jne     PF_NotMatch
                inc     di
                or      al,al
                jnz     PF_Cmp1
PF_Error:       sub     bx,size DiskDescription
                dec     DirectoryParams.S_MaxLength
                jmp     PF_Ret
PF_NotMatch:    add     bp,size DiskDescription
                cmp     bp,bx
                jne     PF_Cmp0

PF_Cont1:       mov     DirectoryParams.S_Buffer[bx].FileFlag,0
                test    DTA.Attributes,FA_DIRECTORY
                jz      PF_NotDir
                mov     DirectoryParams.S_Buffer[bx].FileType,FD_DIRECTORY
                jmp     PF_Ret

PF_NotDir:      push    cs
                pop     es
                cld
                lea     di,DirectoryParams.S_Buffer[bx].FileName
                inc     di
                mov     al,'.'
                mov     cx,PF_NameLength
        repne   scasb
                xor     dl,dl
                jcxz    PF_PokeType
                mov     bp,di
                mov     si,offset PF_FileExts
                mov     dh,2
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
                mov     DirectoryParams.S_Buffer[bx].FileType,al
                mov     di,ax
                shl     di,1
                call    PF_Addr[di]
                and     DirectoryParams.S_Buffer[bx].FileFlag,not FF_READ_ONLY?
                test    DTA.Attributes,FA_READ_ONLY
                jz      PF_Ret
                or      DirectoryParams.S_Buffer[bx].FileFlag,FF_READ_ONLY?
PF_Ret:         pop     es bp di si dx cx ax
                ret
RD_PutFile      endp

PF_Directory:   mov     DirectoryParams.S_Buffer[bx].FileFlag,0
                ret

PF_DOS33:       mov     DirectoryParams.S_Buffer[bx].FileFlag,FF_MODIFYTYPE?
                ret

PF_Nibble:      mov     DirectoryParams.S_Buffer[bx].FileFlag,FF_MODIFYTYPE?
                ret


RD_NewDisk      db      1,0Fh,'<New Disk>',0
ReadDir         proc    near
                push    ax bx si di
                mov     GetKeyParams.RK_ErrPtr,offset SMS_ReadDir
                xor     ax,ax
                mov     DirectoryParams.S_MaxLength,al
                mov     BufPtr,ax
                mov     DirectoryParams.S_BegPrint,al
                mov     DirectoryParams.S_Pos,al
                mov     DirectoryParams.S_CX,0B2Ah
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
RD1_CallRead:   mov     WildCard[di],0
                call    ReadDirectory
                mov     RD_GetDirs?,0
                cmp     Filter[si],0
                jz      RD1_Done
RD1_Ignore:     inc     si
                cmp     Filter[si],','
                je      RD1_Ignore
                jmp     RD1_Loop0
RD1_Done:       mov     GetKeyParams.RK_ErrPtr,0
                mov     bl,DirectoryParams.S_MaxLength
                inc     DirectoryParams.S_MaxLength
                call    CalcBuffer
                xor     bx,bx
RD_CopyNewName: mov     al,RD_NewDisk[bx]
                mov     DirectoryParams.S_Buffer[di].FileName[bx],al
                inc     bx
                or      al,al
                jnz     RD_CopyNewName
                mov     DirectoryParams.S_Buffer[di].FileFlag,FF_MODIFYTYPE?
                mov     DirectoryParams.S_Buffer[di].FileType,FD_DOS33
                call    LinkPathFilter
                call    CheckInsertion
                pop     di si bx ax
                ret
ReadDir         endp


CheckInsertion: push    ax bx cx di bp ds es
                pushf
                push    cs
                pop     ds
                cmp     DirectoryParams.S_MaxLength,0
                jz      CI_Quit
                call    set_ptrs
                xor     cx,cx
                mov     bl,cl
                call    CalcBuffer
CI_Loop:        mov     bx,di
                call    LinkName
                xor     bx,bx
                call    present1
                jz      CI_NodiskA
CI_Loop1:       mov     al,SDA_Filename[bx]
                or      al,al
                jz      CI_L1exit
                inc     bx
                cmp     al,Path-1[bx]
                je      CI_Loop1
CI_L1exit:      mov     al,FF_INSERTED1?
                je      CI_ok1
CI_NodiskA:     xor     al,al
CI_ok1:         and     DirectoryParams.S_Buffer[di].FileFlag,not(FF_INSERTED1? or FF_INSERTED2?)
                or      DirectoryParams.S_Buffer[di].FileFlag,al
                xor     bx,bx
                call    present2
                jz      CI_NodiskB
CI_Loop2:       mov     al,SDB_Filename[bx]
                or      al,al
                jz      CI_L2exit
                inc     bx
                cmp     al,Path-1[bx]
                je      CI_Loop2
CI_L2exit:      mov     al,FF_INSERTED2?
                je      CI_ok2
CI_NodiskB:     xor     al,al
CI_ok2:         or      DirectoryParams.S_Buffer[di].FileFlag,al
                mov     bl,cl
                inc     cl
                add     di,size DiskDescription
                cmp     bl,DirectoryParams.S_MaxLength
                jb      CI_Loop
                call    UnLinkName
CI_Quit:        popf
                pop     es ds bp di cx bx ax
                ret
                assume  es:Emulate


LN_BX           dw      ?
LinkName:       pushf
                push    ax bx si di
                mov     si,bx
                lea     si,DirectoryParams.S_Buffer[si]
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
                mov     al,size DiskDescription
                mul     bl
                mov     di,ax
                pop     ax
                ret


CalcCommand:    push    ax bx cx es             ; Returns number of a command
                push    cs                      ; Input:
                pop     es                      ; di -> offset Commands
                call    Upcase                  ; al -> search command
                cld                             ; cx -> commands count
                mov     bx,di
                repne   scasb                   ; Output:
                stc                             ; di <- Number of the command
                jne     CC_end                  ; cf <- 1 if not found
                sub     di,bx
                dec     di
                clc
CC_end:         pop     es cx bx ax
ccc             label   byte
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
                mov     ScreenIOparams.CursorLen,14 ;36
                mov     ScreenIOparams.CursorColor,10h
                mov     ScreenIOparams.CursorFlag,1
                call    InitFlags
                ScreenIOservice _CLEARSCREEN
                call    ShowPathFilter
                call    ShowDirectory
                call    ShowDiskA
                call    ShowDiskB
                call    ShowImage
                call    ShowFuncKeys
                call    ShowError
                call    ShowMessage
                ScreenIOservice _SHOWLINE
                call    ShowHilights
                call    ShowTitle
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
                mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                xor     si,si
                cmp     SHL_Flag,0
                mov     FkeysFlags,0000000100b
                jz      IF_0
IF_Loop:        call    IF_Procs[si]
                add     si,2
                cmp     si,20
                jb      IF_Loop
IF_0:           cmp     DOSflag,0
                jnz     IF_1
                cmp     ActiveFlags,0
                jnz     IF_Ret
IF_1:           mov     FkeysFlags,0
IF_Ret:         pop     bp di si bx ax
                ret

IFP_F1:         cmp     ManagerState,MS_NORMAL
                jne     IFP_F1ret
                or      FkeysFlags,0000000001b
                mov     SFK_Reboot[1],06Fh
                cmp     DirectoryParams.S_Buffer[di].FileType,FD_DIRECTORY
                je      IFP_F1ret
                test    DirectoryParams.S_Buffer[di].FileFlag,FF_INSERTED1? or FF_INSERTED2? or FF_DAMAGED?
                jnz     IFP_F1ret
                mov     SFK_Reboot[1],01Fh
IFP_F1ret:      ret

IFP_F2_D1       dw      Fkey_InsertA,Fkey_RemoveA
IFP_F2_D2       dw      Fkey_InsertB,Fkey_RemoveB
IFP_F2:         or      FkeysFlags,00000010b
                test    ActiveFlags,0000000000001000b
                mov     bx,offset IFP_F2_D1
                mov     ax,offset present1
                jz      IFP_F2_1
                mov     bx,offset IFP_F2_D2
                mov     ax,offset present2
IFP_F2_1:       call    ax
                mov     ax,[bx][2]
                mov     SFK_FkeysMain[2],offset SFK_Remove
                jnz     IFP_F2_2
                mov     ax,[bx][0]
                mov     SFK_FkeysMain[2],offset SFK_Insert
                cmp     DirectoryParams.S_Buffer[di].FileType,FD_DIRECTORY
                je      IFP_F2_12
                test    DirectoryParams.S_Buffer[di].FileFlag,FF_INSERTED1? or FF_INSERTED2? or FF_DAMAGED?
                jz      IFP_F2_2
IFP_F2_12:      and     FkeysFlags,11111101b
IFP_F2_2:       mov     Fkeys_Main[2],ax
                ret

IFP_F3:         or      FkeysFlags,0000000100b
                cmp     ManagerState,MS_NORMAL
                mov     SFK_FkeysMain[2*2],offset SFK_Apple
                mov     Fkeys_Main[2*2],offset Fkey_Apple
                je      IFP_F3_1
                mov     SFK_FkeysMain[2*2],offset SFK_Resume
                mov     Fkeys_Main[2*2],offset Fkey_Resume
IFP_F3_1:       ret

IFP_F4:         cmp     ManagerState,MS_NORMAL
                mov     SFK_FkeysMain[3*2],offset SFK_None
                mov     Fkeys_Main[3*2],offset Fkey_None
                je      IFP_F4_1
                or      FkeysFlags,0000001000b
                mov     SFK_FkeysMain[3*2],offset SFK_Abort
                mov     Fkeys_Main[3*2],offset Fkey_Abort
IFP_F4_1:       ret

IFP_F5:
IFP_F6:
IFP_F7:
IFP_F8:
IFP_F9:         ret

IFP_F0:         or      FkeysFlags,1100000000b
                test    ActiveFlags,1
                jz      IFP0_Ret
                mov     FkeysFlags,0000000101b
IFP0_Ret:       ret


ST_Str          db      '                               APPLER DISK MANAGER                              ',0
ShowTitle:      push    ax bx cx
                gotoxy  1,0
                mov     ah,6Fh
                mov     bx,offset ST_Str
                ScreenIOservice _STRINGPRINT
                gotoxy  2,0
                xor     ah,ah
                ScreenIOservice _STRINGPRINT
                pop     cx bx ax
                ret


SP_Str          db      'ÚPath&FilterÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                      ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0
ShowPathFilter: push    ax bx cx dx
                gotoxy  3,40
                mov     bx,offset SP_Str
                mov     dh,3
                mov     ax,0000000000000001b
                call    DrawBox
                mov     bx,35
                xor     al,al
                xchg    PathFilter[bx],al
                mov     bx,offset PathFilter
                mov     ah,0Bh
                gotoxy  5,42
                ScreenIOservice _StringPrint
                mov     bx,35
                xchg    PathFilter[bx],al
SPF_Ret:        pop     dx cx bx ax
                ret


SD_Str          db      'ÚDirectoryÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿',0
                db      '³                                      ³',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ',0

SD_Antet0       db      1,07h,'ÄÄÄÄÄÄÄÄÄÄÄÄ   ÄÄÄÄÄÄ   ÄÄÄÄÄÄÄÄÄÄ',0
SD_Antet1       db      1,07h,'Filename       Type     Access',0
SD_Antet2       db      1,07h,'Filename       ',1,0Fh,'T',1,07h,'ype     ',1,0Fh,'A',1,07h,'ccess',0
SD_NotFndMsg    db      1,7,'No Matching Files in Directory',0
SD_AntetAddr    dw      SD_Antet1,SD_Antet1,SD_Antet2,SD_Antet1
                dw      SD_Antet1,SD_Antet1,SD_Antet2,SD_Antet1

ShowDirectory:  push    ax bx cx dx di
                gotoxy  7,40
                mov     bx,offset SD_Str
                mov     dh,17
                mov     ax,0000000000000010b
                call    DrawBox
                cmp     DirectoryParams.S_MaxLength,0
                jnz     SD_ok2
                gotoxy  9,2Bh
                mov     bx,offset SD_NotFndMsg
                ScreenIOservice _STRINGPRINT
                jmp     SD_Ret
SD_ok2:         mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                xor     bx,bx
                mov     bl,DirectoryParams.S_Buffer[di].FileFlag
                test    bl,11111000b
                jnz     SD_ok25
                and     bl,00000111b
                shl     bx,1
                mov     bx,SD_AntetAddr[bx]
                cmp     SHL_Flag,0
                jz      SD_ok25
                test    ActiveFlags,0000000000000010b
                jnz     SD_ok3
SD_ok25:        mov     bx,offset SD_Antet1
SD_ok3:         gotoxy  9,43
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SD_Antet0
                gotoxy  10,43
                ScreenIOservice _STRINGPRINT
                mov     bl,DirectoryParams.S_BegPrint
                mov     dx,13
                mov     di,offset DirectoryParams.S_Buffer
                gotoxy  11,43
                mov     ah,7
SD_Loop0:       call    OneFile
                add     cx,80 * 2
                inc     bl
                cmp     bl,DirectoryParams.S_MaxLength
                je      SD_Ret0
                dec     dx
                jnz     SD_Loop0
SD_Ret0:        cmp     NameEntering,0
                jnz     SD_Ret
                mov     cx,DirectoryParams.S_CX
                ScreenIOservice _SHOWCURSOR
SD_Ret:         pop     di dx cx bx ax
                ret


SDA_Str         db      'ÚDrive 1ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
SDA_NoDisk      db      1,0Fh,'NO DISK IN DRIVE',0
SDA_File        db      1,7,'Name: ',0
SDA_Type        db      1,7,'Type: ',0
SDA_Access      db      'A',1,7,'ccess: ',0
SDA_Volume      db      'V',1,7,'olume:  ',0
SDA_Track       db      1,7,'Track:',1,0Fh,0
SDA_DOS33       db      1,0Bh,'DOS 3.3',0
SDA_Nibble      db      1,0Bh,'Nibblized',0
SDA_ReadOnly    db      1,0Bh,'R',0
SDA_RW          db      1,0Bh,'R/W',0
SDA_Color       db      ?
SDA_Filename    db      80h dup (0)
ShowDiskA:      push    ax bx cx dx si es
                gotoxy  3,0
                mov     bx,offset SDA_Str
                mov     dh,4
                mov     ax,0000000000000100b
                call    DrawBox
                les     si,disk1_ptr
                assume  es:seg CurrentDrive
                cmp     es:[si].FileHandle,0FFFFh
                jne     SDA_Show
                mov     bx,offset SDA_NoDisk
                gotoxy  5,11
                ScreenIOservice _STRINGPRINT
                jmp     SDA_Ret
SDA_Show:       mov     SDA_Color,7
                cmp     SHL_Flag,0
                jz      SDA_LoLight
                test    ActiveFlags,0000000000000100b
                jz      SDA_LoLight
                mov     SDA_Color,0Fh
SDA_LoLight:    gotoxy  5,2
                mov     bx,offset SDA_File
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SDA_Filename
                call    ShowFilename
                gotoxy  6,2
                mov     bx,offset SDA_Type
                mov     ah,SDA_Color
                ScreenIOservice _STRINGPRINT
                cmp     es:[si].DiskType,0
                mov     bx,offset SDA_Nibble
                jz      SDA_Print
                mov     bx,offset SDA_DOS33
SDA_Print:      ScreenIOservice _STRINGPRINT
                gotoxy  5,26
                mov     bx,offset SDA_Access
                mov     ah,SDA_Color
                ScreenIOservice _STRINGPRINT
                cmp     es:[si].WriteProtect,0
                mov     bx,offset SDA_RW
                jz      SDA_ok1
                mov     bx,offset SDA_ReadOnly
SDA_ok1:        ScreenIOservice _STRINGPRINT
                cmp     es:[si].DiskType,0
                jz      SDA_Ret
                gotoxy  6,26
                mov     bx,offset SDA_Volume
                mov     ah,SDA_Color
                ScreenIOservice _STRINGPRINT
                mov     ah,0Bh
                mov     al,es:[si].Volume
                ScreenIOservice _BYTEPRINT
SDA_Ret:        gotoxy  3,30
                mov     bx,offset SDA_Track
                ScreenIOservice _STRINGPRINT
                mov     al,es:[si].Track
                mov     ah,0Fh
                ScreenIOservice _BYTEPRINT
                pop     es si dx cx bx ax
                ret
                assume  es:Emulate


SDB_Str         db      'ÚDrive 2ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
SDB_Type        db      0
SDB_Filename    db      80h dup (0)
ShowDiskB:      push    ax bx cx dx si es
                gotoxy  8,0
                mov     bx,offset SDB_Str
                mov     dh,4
                mov     ax,0000000000001000b
                call    DrawBox
                les     si,disk2_ptr
                assume  es:seg CurrentDrive
                cmp     es:[si].FileHandle,0FFFFh
                jne     SDB_Show
                mov     bx,offset SDA_NoDisk
                gotoxy  10,11
                ScreenIOservice _STRINGPRINT
                jmp     SDB_Ret
SDB_Show:       mov     SDA_Color,7
                cmp     SHL_Flag,0
                jz      SDB_LoLight
                test    ActiveFlags,0000000000001000b
                jz      SDB_LoLight
                mov     SDA_Color,0Fh
SDB_LoLight:    gotoxy  10,2
                mov     bx,offset SDA_File
                ScreenIOservice _STRINGPRINT
                mov     bx,offset SDB_Filename
                call    ShowFilename
                gotoxy  11,2
                mov     bx,offset SDA_Type
                mov     ah,SDA_Color
                ScreenIOservice _STRINGPRINT
                cmp     es:[si].DiskType,0
                mov     bx,offset SDA_Nibble
                jz      SDB_Print
                mov     bx,offset SDA_DOS33
SDB_Print:      ScreenIOservice _STRINGPRINT
                gotoxy  10,26
                mov     bx,offset SDA_Access
                mov     ah,SDA_Color
                ScreenIOservice _STRINGPRINT
                cmp     es:[si].WriteProtect,0
                mov     bx,offset SDA_RW
                jz      SDB_ok1
                mov     bx,offset SDA_ReadOnly
SDB_ok1:        ScreenIOservice _STRINGPRINT
                cmp     es:[si].DiskType,0
                jz      SDB_Ret
                gotoxy  11,26
                mov     bx,offset SDA_Volume
                mov     ah,SDA_Color
                ScreenIOservice _STRINGPRINT
                mov     ah,0Bh
                mov     al,es:[si].Volume
                ScreenIOservice _BYTEPRINT
SDB_Ret:        gotoxy  8,30
                mov     bx,offset SDA_Track
                ScreenIOservice _STRINGPRINT
                mov     al,es:[si].Track
                mov     ah,0Fh
                ScreenIOservice _BYTEPRINT
                pop     es si dx cx bx ax
                ret
                assume  es:Emulate


ShowFilename:   push    ax si di es
                push    cx
                cmp     byte ptr ds:[bx],0
                stc
                jz      SF_Ret
                mov     di,bx
                mov     ax,ds
                mov     es,ax
                mov     cx,0FFh
                xor     al,al
                cld
                repne   scasb
                std
                mov     si,di
                dec     si
SF_Loop1:       lodsb
                cmp     al,'\'
                je      SF_ok
                cmp     si,bx
                jae     SF_Loop1
                dec     si
SF_ok:          mov     bx,si
                add     bx,2
                mov     ah,3
                clc
                pop     cx
                pushf
                ScreenIOservice _STRINGPRINT
                popf
SF_Ret:         pop     es di si ax
                ret


SI_Str          db      'ÚDOS 3.3 Sector ImageÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿ ',0
                db      '³                                     ³ ',0
                db      'ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ ',0
SI_AdrP         db      1,7,'Address Field Prolog:      ',0
SI_AdrChecksum  db      1,7,'Address Field Checksum:    ',0
SI_AdrE         db      1,7,'Address Field Epilog:      ',0
SI_DataP        db      1,7,'Data Field Prolog:         ',0
SI_DataChecksum db      1,7,'Data Field Checksum:       ',0
SI_DataE        db      1,7,'Data Field Epilog:         ',0
SI_EOS          db      1,7,'End-Of-Sector Byte:        ',0
SI_Texts        dw      SI_AdrP,?,?
                dw      SI_AdrChecksum
                dw      SI_AdrE,?,?
                dw      SI_DataP,?,?
                dw      SI_DataChecksum
                dw      SI_DataE,?,?
                dw      SI_EOS,?
SI_TextFlags    db      1,0,0,1,1,0,0,1,0,0,1,1,0,0,1
ShowImage:      push    ax bx cx dx si di ds
                gotoxy  13,0
                mov     bx,offset SI_Str
                mov     dh,10
                mov     ax,0000000000010000b
                call    DrawBox
                mov     ax,seg SectorImage
                mov     ds,ax
                mov     si,offset SectorImage
                mov     dx,offset SectorImageF
                cld
                xor     di,di
SI_Loop:        cmp     cs:SI_TextFlags[di],0
                jz      SI_Dont
                mov     ch,cs:I_CH[di]
                dec     ch
                mov     al,ch
                mov     ah,80 * 2
                mul     ah
                add     ax,2*2
                mov     cx,ax
                shl     di,1
                mov     bx,cs:SI_Texts[di]
                shr     di,1
                ScreenIOservice _STRINGPRINT
SI_Dont:        xchg    dx,si
                lodsb
                xchg    dx,si
                or      al,al
                mov     ah,3
                jz      SI_ok1
                mov     ah,0Bh
SI_ok1:         lodsb
                ScreenIOservice _BYTEPRINT
                add     cx,2
                inc     di
                cmp     di,size SectorImage_S
                jb      SI_Loop
                pop     ds di si dx cx bx ax
                ret


SMS_ReadDir       db    'Accessing Disk Directory...',0
SMS_DecodeErr     db    1,8Ch,'Drive ',3
                  dw    DM_DriveNum
                  db    ': Error Decoding Track Data',0
SMS_EnterFilename db    'Enter Filename (<Esc> cancel)',0
ShowMessage:    push    ax bx cx
                cmp     GetKeyParams.RK_ErrPtr,0
                jz      SMS_Ret
                gotoxy  18h,1
                mov     bx,GetKeyParams.RK_ErrPtr
                mov     ah,0Ah
                ScreenIOservice _STRINGPRINT
SMS_Ret:        pop     cx bx ax
                ret



SFK_Str         db      '1       2       3       4       5       '
                db      '6       7       8       9      10       ',0
FkeysFlags      dw      1010000111b
SFK_FkeysMain   dw      SFK_Reboot,SFK_Insert,SFK_Apple,SFK_None,SFK_None
                dw      SFK_None,SFK_None,SFK_None,SFK_PathFilter,SFK_Rescan
SFK_Reboot      db      1,6Fh,'Reboot',0
SFK_Apple       db      1,6Fh,'Apple ',0
SFK_Resume      db      1,6Fh,'Resume',0
SFK_Abort       db      1,6Fh,'Abort ',0
SFK_Insert      db      1,6Fh,'Insert',0
SFK_Remove      db      1,6Fh,'Remove',0
SFK_PathFilter  db      1,6Fh,'Path&F',0
SFK_Rescan      db      1,6Fh,'Rescan',0
SFK_None        db      1,6Fh,'      ',0

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


SE_BadAdrChk    db      'Bad address checksum: ',3
                dw      DM_BadData,0
SE_BadAdrEpi    db      'Bad address epilog, S:',3
                dw      DM_Sector,0
SE_BadTrack     db      'Wrong track number: ',3
                dw      DM_BadData
                db      ', S:',3
                dw      DM_Sector,0
SE_BadSector    db      'Sector number not allowed: ',3
                dw      DM_BadData,0
SE_MisingData   db      'Data field not found, S:',3
                dw      DM_Sector,0
SE_DuplicateSec db      'Sector found twice: ',3
                dw      DM_BadData
                db      ', S:',3
                dw      DM_Sector,0
SE_BadDataChk   db      'Bad data checksum: ',3
                dw      DM_BadData
                db      ', S:',3
                dw      DM_Sector,0
SE_BadDataImg   db      'Bad nibble byte, S:',3
                dw      DM_Sector,0
SE_BadDataEpi   db      1,8Ch,'Bad data epilog, S:',3
                dw      DM_Sector,0
SE_BadEnd       db      'Bad end-of-sector byte, S:',3
                dw      DM_Sector,0
SE_MissingSec   db      'Can''t find sector: ',3
                dw      DM_BadData,0
SE_WriteAttempt db      'Write protected',0
SE_ErrorAddress dw      SE_BadAdrChk
                dw      SE_BadAdrEpi
                dw      SE_BadTrack
                dw      SE_BadSector
                dw      SE_MisingData
                dw      SE_DuplicateSec
                dw      SE_BadDataChk
                dw      SE_BadDataImg
                dw      SE_BadDataEpi
                dw      SE_BadEnd
                dw      SE_MissingSec
                dw      SE_WriteAttempt
ShowError:      push    ax bx cx
                cmp     ManagerState,MS_NORMAL
                je      SE_Ret
                cmp     DM_DriveNum,1
                gotoxy  4,2
                je      SE_ok1
                gotoxy  9,2
SE_ok1:         xor     bx,bx
                mov     bl,DM_ErrorCode
                shl     bx,1
                mov     bx,SE_ErrorAddress[bx]
                mov     ah,0Ch
                ScreenIOservice _STRINGPRINT
SE_Ret:         pop     cx bx ax
                ret

SHL_Flag        db      1
ShowHilights:   cmp     SHL_Flag,0
                jz      SHL_Ret
                push    ax cx
                gotoxy  13,16
                mov     ax,0E00h+'I'
                ScreenIOservice _SYMBPRINT
                gotoxy  3,7
                mov     al,'1'
                ScreenIOservice _SYMBPRINT
                gotoxy  8,7
                mov     al,'2'
                ScreenIOservice _SYMBPRINT
                gotoxy  3,41
                mov     al,'P'
                ScreenIOservice _SYMBPRINT
                gotoxy  7,41
                mov     al,'D'
                ScreenIOservice _SYMBPRINT
SHL_Exit:       pop     cx ax
SHL_Ret:        ret


OF_CX           dw      ?
OF_Types        dw      OF_Directory,OF_Nibble,OF_DOS33
OF_Directory    db      1,7,'<DIR>',0
OF_DOS33        db      'DOS3.3',0
OF_Nibble       db      'Nibble',0
OF_RO           db      'Read Only ',0
OF_RW           db      'Read/Write',0
OF_DirAccess    db      1,7,'   ----   ',0
OF_Inserted1    db      1,0Fh,'Inserted in Drive 1',0
OF_Inserted2    db      1,0Fh,'Inserted in Drive 2',0
OF_Base         dw      ?
OF_Color        db      ?
comment         %
                push    ax dx ds
                mov     ax,4d9h
                mov     ds,ax
                mov     dx,103h
                mov     ax,2509h
                int     21h
                pop     ds dx ax
                int     3
                %
OneFile:        push    ax bx cx dx di
                mov     OF_Base,di
                mov     OF_CX,cx
                call    CalcBuffer
                mov     bp,OF_Base
                lea     bx,ds:[bp][di].FileName
                test    ds:[bp][di].FileFlag,FF_DAMAGED?
                mov     OF_Color,0Bh
                jz      OF_hop1
                mov     ah,0Ch
                mov     OF_Color,ah
OF_hop1:        ScreenIOservice _STRINGPRINT
                mov     cx,OF_CX
                add     cx,2*15
                mov     bp,OF_Base
                test    ds:[bp][di].FileFlag,FF_INSERTED1? or FF_INSERTED2?
                jz      OF_NotInserted
                test    ds:[bp][di].FileFlag,FF_INSERTED1?
                mov     bx,offset OF_Inserted1
                jnz     OF_id1
                mov     bx,offset OF_Inserted2
OF_id1:         ScreenIOservice _STRINGPRINT
                jmp     OF_Ret
OF_NotInserted: xor     bx,bx
                push    bp
                mov     al,ds:[bp][di].FileType
                mov     bl,al
                shl     bx,1
                mov     bx,OF_Types[bx]
                mov     ah,OF_Color
                ScreenIOservice _STRINGPRINT
                cmp     al,FD_DIRECTORY
                mov     bx,offset OF_DirAccess
                pop     bp
                je      OF_hop2
                test    ds:[bp][di].FileFlag,FF_READ_ONLY?
                mov     bx,offset OF_RO
                jnz     OF_hop2
                mov     bx,offset OF_RW
OF_hop2:        mov     cx,OF_CX
                add     cx,2*24
                ScreenIOservice _STRINGPRINT
OF_Ret:         pop     di dx cx bx ax
                ret




; *******************************************************************
; **                                                               **
; **                                                               **
; **               K E Y B O A R D   S E R V I C E S               **
; **                                                               **
; **                                                               **
; *******************************************************************

Alt_Keys        db      'ipd12'
Alt_Procs       dw      Alt_Image,Alt_PathFilter,Alt_Directory,Alt_D1,Alt_D2
Alt_Key         proc    far
                push    cx si di ds
                mov     di,offset Alt_Keys
                mov     cx,offset Alt_Procs- offset Alt_Keys
                call    CalcCommand
                jc      Alt_Ret
Alt_ok:         shl     di,1
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

Alt_Image       proc    near
                mov     cs:GoWhere?,G_IMAGE
                ret
Alt_Image       endp

Alt_D1          proc    near
                mov     cs:GoWhere?,G_D1
                ret
Alt_D1          endp

Alt_D2          proc    near
                mov     cs:GoWhere?,G_D2
                ret
Alt_D2          endp

Alt_Key         endp



FkeysMasks      dw      1b,10b,100b,1000b,10000b,100000b,1000000b,10000000b,100000000b,1000000000b
Fkeys_Main      dw      Fkey_Reboot,Fkey_None,Fkey_Apple,Fkey_InsertA,Fkey_InsertB
                dw      Fkey_None,Fkey_None,Fkey_None,Fkey_PathFilter,Fkey_Rescan
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
                mov     bx,Emulate
                mov     es,bx
                xor     bx,bx
                mov     bl,al
                shl     bx,1
                mov     si,bx
                mov     ax,FkeysMasks[si]
                test    FkeysFlags,ax
                jz      Fkey_Ret
                xor     bx,bx
                call    Fkeys_Main[si]
                mov     cx,DirectoryParams.S_CX
Fkey_Ret:       pop     [FkeysFlags]
                pop     [ActiveFlags]
                pop     ds:[GetLineParams.GL_CX]
                pop     ds:[GetLineParams.GL_Buffer]
                pop     word ptr ds:[ScreenIOparams.CursorFlag]
                pop     word ptr ds:[ScreenIOparams.CursorLen]
                pop     es ds bp di si dx cx bx ax
                ret
Fkey            endp

Fkey_InsertA:   clc
                call    InsertDisk
                ret

Fkey_InsertB:   stc
                call    InsertDisk
                ret

; Entry:
;   CF -- 0 - Disk1, 1 - Disk2
ID_Flags        db      ?
ID_Rescan?      db      ?
ID_Ext          db      '.DSK',0
InsertDisk:     mov     ID_Rescan?,0
                mov     si,offset SDA_Filename
                jnc     ID_Disk1
                mov     si,offset SDB_Filename
ID_Disk1:       lahf
                mov     ID_Flags,ah
                cmp     DirectoryParams.S_MaxLength,0
                jz      ID_Ret
                mov     bl,DirectoryParams.S_Pos
                call    CalcBuffer
                test    DirectoryParams.S_Buffer[di].FileFlag,FF_INSERTED1? or FF_INSERTED2?
                jnz     ID_Ret
                cmp     DirectoryParams.S_Buffer[di].FileType,FD_DIRECTORY
                je      ID_Ret
                cmp     DirectoryParams.S_Buffer[di].FileName[0],1
                jne     ID_NotNew
                mov     ID_Rescan?,1
                add     di,size DiskDescription
                call    EnterFilename
                jc      ID_Quit
                push    si di
                lea     di,DirectoryParams.S_Buffer[di].FileName
                mov     si,offset ID_Ext
                call    AddExt
                pop     di si
                mov     DirectoryParams.S_Buffer[di].FileType,FD_NIBBLE
                jc      ID_NotDOS33
                mov     DirectoryParams.S_Buffer[di].FileType,FD_DOS33
ID_NotDOS33:    mov     bx,di
                call    CreateDisk
                jc      ID_Err
ID_NotNew:      mov     bx,di
                call    LinkName
                xor     bx,bx
ID_Loop:        mov     al,Path[bx]
                mov     [si][bx],al
                inc     bx
                or      al,al
                jnz     ID_Loop
                call    UnlinkName
                mov     dx,si
                mov     bl,DirectoryParams.S_Buffer[di].FileType
                dec     bl
                mov     bh,0FEh
                test    DirectoryParams.S_Buffer[di].FileFlag,FF_READ_ONLY?
                mov     al,1
                jnz     ID_1
                xor     al,al
ID_1:           mov     ah,ID_Flags
                sahf
                call    OpenDiskFile
                jc      ID_Err
                and     DirectoryParams.S_Buffer[di].FileFlag,not FF_DAMAGED?
                clc
                jmp     ID_Ret
ID_Err:         or      DirectoryParams.S_Buffer[di].FileFlag,FF_DAMAGED?
                mov     ah,ID_Flags
                sahf
                call    CloseDiskFile
                stc
ID_Ret:         cmp     ID_Rescan?,0
                jz      ID_Quit
                call    ReadDir
ID_Quit:        ret

CreateDisk:     push    ax bx dx cx
                call    LinkName
                mov     dx,offset Path
                mov     ah,3Ch
                xor     cx,cx
                int     21h
                jc      CD_Err
                mov     bx,ax
                mov     ah,3Eh
                int     21h
CD_Err:         call    UnlinkName
                pop     cx dx bx ax
                ret


Fkey_RemoveA:   call    CloseDiskFile1
                mov     cs:SDA_Filename[0],0
                ret

Fkey_RemoveB:   call    CloseDiskFile2
                mov     cs:SDB_Filename[0],0
                ret

Fkey_Reboot:    call    Fkey_InsertA
                jc      FR_Ret
                call    ResetAppleII
                call    GoAppleII
FR_Ret:         ret

Fkey_PathFilter: call   S_PathFilter
                ret

Fkey_Rescan:    call    ReadDir
                ret

Fkey_Apple:     call    GoAppleII
                ret

Fkey_Resume:    clc
                jmp     DMentry_Exit
Fkey_Abort:     stc
                jmp     DMentry_Exit

Fkey_None:
                ret


NameEntering    db      0
EnterFilename:  push    ax bx cx dx di
                mov     NameEntering,1
                push    word ptr [GetKeyParams.RK_AltFlag]
                push    word ptr [FkeysFlags]
                push    word ptr [SHL_Flag]
                mov     GetLineParams.GL_Color,0Bh
                mov     GetKeyParams.RK_AltFlag,0
                mov     SHL_Flag,0
                mov     FkeysFlags,0000000100b
                mov     ScreenIOparams.CursorFlag,1
                lea     bx,DirectoryParams.S_Buffer[di].FileName
                mov     GetLineParams.GL_Buffer,bx
                mov     GetLineParams.GL_Pos,0
                mov     GetLineParams.GL_BegPrint,0
                mov     GetLineParams.GL_MaxLength,0Ch
                mov     GetLineParams.GL_MaxPrint,0Dh
                mov     GetLineParams.GL_Length,0
                mov     ScreenIOparams.CursorLen,1
                mov     cx,DirectoryParams.S_CX
                dec     ch
                inc     cl
                mov     al,80 * 2
                mul     ch
                xor     bx,bx
                mov     bl,cl
                shl     bx,1
                add     ax,bx
                mov     cx,ax
                mov     GetKeyParams.RK_ErrPtr,offset SMS_EnterFilename
                GetLineService _GETLINE
                pop     word ptr [SHL_Flag]
                pop     word ptr [FkeysFlags]
                pop     word ptr [GetKeyParams.RK_AltFlag]
                gotoxy  2,0
                mov     GetLineParams.GL_CX,cx
                mov     NameEntering,0
                pop     di dx cx bx ax
                ret




GetLineUser     proc    far
                ret
GetLineUser     endp


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


; Entry:
;   DS:DX^  -- Filename
;   AL      -- Access Mode: 0 - Don't Change, else Read Only
;   BL      -- Type: 0 - Nibble, 1 - DOS 3.3
;   BH      -- Volume (for DOS 3.3 type only)
;   CF      -- 0 - Disk1, 1 - Disk2
; Exit:
;   CF      -- Cleared if successfull
                assume  es:seg CurrentDrive
OpenDiskFile    proc    far
                push    ax bx cx dx si di bp ds es
                call    set_ptrs
                mov     cl,al
                les     bp,cs:disk1_ptr
                mov     di,offset SDA_Filename
                jnc     ODF_Continue
                les     bp,cs:disk2_ptr
                mov     di,offset SDB_Filename
ODF_Continue:   call    CloseDiskFIle
                mov     ax,3D02h
                int     21h
                jnc     ODF_1
                mov     ax,3D00h
                int     21h
                jc      ODF_Quit
                stc
ODF_1:          mov     es:[bp].FileHandle,ax
                mov     es:[bp].DiskType,bl
                mov     es:[bp].Volume,bh
                mov     bl,0FFh
                jc      ODF_2
                xor     bl,bl
ODF_2:          or      cl,cl
                jz      ODF_3
                mov     bl,0FFh
ODF_3:          mov     es:[bp].WriteProtect,bl
                mov     si,dx
                mov     bx,es:[bp].FileHandle
                mov     cx,1
                mov     dx,1000h
                mov     ax,4200h
                int     21h
                jc      ODF_Ret
                push    ds
                push    cs
                pop     ds
                mov     cx,40h
                mov     dx,offset ODF_TempBuffer
                mov     ah,3Fh
                int     21h
                jc      ODF_Ret
                cmp     ax,cx
                jne     ODF_Ret
                cmp     ODF_TempBuffer[3],3
                jne     ODF_Ret
                cmp     ODF_TempBuffer[35h],10h
                jne     ODF_Ret
                cmp     word ptr ODF_TempBuffer[36h],100h
                jne     ODF_Ret
                mov     al,ODF_TempBuffer[6]
                mov     es:[bp].Volume,al
ODF_Ret:        pop     ds
                push    cs
                pop     es
                mov     ah,60h
                int     21h
                clc
                call    CheckInsertion
ODF_Quit:       pop     es ds bp di si dx cx bx ax
                ret
ODF_TempBuffer  db      40h dup (?)
OpenDiskFile    endp

; Entry:
;   CF      -- 0 - Disk1, 1 - Disk2
CloseDiskFile   proc    near
                push    ax bx bp es
                call    set_ptrs
                les     bp,cs:disk1_ptr
                jnc     CDF_Disk1
                les     bp,cs:disk2_ptr
                assume  es:seg CurrentDrive
CDF_Disk1:      mov     bx,es:[bp].FileHandle
                inc     bx
                jz      CDF_NoDisk
                dec     bx
                cmp     cs:ManagerState,MS_NORMAL
                jne     CDF_FlushOK             ; Don't flush while in error
                cmp     bp,offset CurrentDrive
                jne     CDF_FlushOK             ; Flush only if close current
                call    FlushBuffer
CDF_FlushOK:    mov     ah,3Eh
                int     21h
                jc      CDF_Ret
                mov     es:[bp].FileHandle,0FFFFh
                call    CheckInsertion
CDF_Ret:        clc
CDF_Quit:       pop     es bp bx ax
                ret
CDF_NoDisk:     stc
                jmp     CDF_Quit
CloseDiskFile   endp

OpenDiskFile1   proc    far
                push    ax bx dx bp ds es
                call    set_ptrs
                push    cs
                pop     ds
                les     bp,disk1_ptr
                mov     dx,offset SDA_Filename
                cmp     SDA_Filename[0],0
                jz      ODF1_NoFile
                mov     bl,es:[bp].DiskType
                mov     bh,es:[bp].Volume
                mov     al,es:[bp].WriteProtect
                clc
                call    OpenDiskFile
                jnc     ODF1_Ret
ODF1_NoFile:    mov     es:[bp].FileHandle,0FFFFh
                call    CheckInsertion
ODF1_Ret:       pop     es ds bp dx bx ax
                ret
OpenDiskFile1   endp

OpenDiskFile2   proc    far
                push    ax bx dx bp ds es
                call    set_ptrs
                push    cs
                pop     ds
                les     bp,disk2_ptr
                mov     dx,offset SDB_Filename
                cmp     SDB_Filename[0],0
                jz      ODF2_NoFile
                mov     bl,es:[bp].DiskType
                mov     bh,es:[bp].Volume
                mov     al,es:[bp].WriteProtect
                stc
                call    OpenDiskFile
                jnc     ODF2_Ret
ODF2_NoFile:    mov     es:[bp].FileHandle,0FFFFh
                call    CheckInsertion
ODF2_Ret:       pop     es ds bp dx bx ax
                ret
OpenDiskFile2   endp

CloseDiskFile1  proc    far
                clc
                call    CloseDiskFile
                jnc     CDF1_Ret
                mov     cs:SDA_Filename[0],0
CDF1_Ret:       ret
CloseDiskFile1  endp

CloseDiskFile2  proc    far
                stc
                call    CloseDiskFile
                jnc     CDF2_Ret
                mov     cs:SDB_Filename[0],0
CDF2_Ret:       ret
CloseDiskFile2  endp
                assume  es:Emulate

; Entry:
;   DL     <-- Sector (0FFh if an invalid sector number)
;   AH     <-- Error Code
;   AL     <-- Bad Data
; Exit:
;   CF     --> 0 - Retry, 1 - Abort
OldEnableTask   db      ?
DM_ScreenMode   db      ?
DMentry_SP      dw      ?
DM_ErrorCode    db      ?
DM_BadData      db      ?
DM_DriveNum     db      ?
DM_Sector       db      ?
DM_OldKeyTable  dw      ?
DM_old_gl       dd      ?
DM_old_sio      dd      ?
DM_old_rk       dd      ?
DM_SwapFlag     db      ?
DMentry         proc    far
                SaveAll
                push    word ptr cs:[GetKeyParams.RK_AltFlag]

                mov     bx,seg k_Table          ; Save Current Key Table
                mov     ds,bx
                assume  ds:seg k_Table
                mov     bx,ds:k_Table
                mov     cs:DM_OldKeyTable,bx

                mov     bx,CONio                ; Save Current CONIO Params
                mov     ds,bx
                assume  ds:CONio
                mov     bx,ds:GL_ParamsOfs
                mov     word ptr cs:DM_old_gl[0],bx
                mov     bx,ds:GL_ParamsSeg
                mov     word ptr cs:DM_old_gl[2],bx
                mov     bx,ds:SIO_ParamsOfs
                mov     word ptr cs:DM_old_sio[0],bx
                mov     bx,ds:SIO_ParamsSeg
                mov     word ptr cs:DM_old_sio[2],bx
                mov     bx,ds:RK_ParamsOfs
                mov     word ptr cs:DM_old_rk[0],bx
                mov     bx,ds:RK_ParamsSeg
                mov     word ptr cs:DM_old_rk[2],bx

                call    DM_InInitP
                mov     bx,seg SwapFlag
                mov     ds,bx
                assume  ds:seg SwapFlag
                mov     al,1
                xchg    al,ds:SwapFlag
                mov     cs:DM_SwapFlag,al
                mov     bx,seg EnableTaskSwitch
                mov     ds,bx
                assume  ds:seg EnableTaskSwitch
                xor     bl,bl
                xchg    ds:EnableTaskSwitch,bl
                mov     cs:OldEnableTask,bl
                mov     bx,seg CurrentDrive
                mov     ds,bx
                assume  ds:seg CurrentDrive
                mov     cl,ds:CurrentDrive.ID
                push    cs
                pop     ds
                assume  DS:DM
                mov     ScreenIOparams.CursorFlag,0
                mov     DM_ErrorCode,ah
                mov     DM_Sector,dl
                mov     DM_BadData,al
                inc     cl
                mov     DM_DriveNum,cl
                dec     cl
                mov     ActiveFlags,0000000000000100b
                mov     GoWhere?,G_D1
                jz      DMentry_1
                mov     ActiveFlags,0000000000001000b
                mov     GoWhere?,G_D2
DMentry_1:      mov     ah,0Fh
                int     10h
                mov     DM_ScreenMode,al
                mov     I_CurrentSVD,0
                mov     ManagerState,MS_ERROR
                mov     DMentry_SP,sp
                mov     GetKeyParams.RK_ErrPtr,offset SMS_DecodeErr
                jmp     DM_MainRet
;               ---------------------
DMentry_Exit:   mov     sp,DMentry_SP
                pushf
                mov     ManagerState,MS_NORMAL
                mov     ax,seg EnableTaskSwitch
                mov     ds,ax
                assume  ds:seg EnableTaskSwitch
                mov     al,cs:OldEnableTask
                mov     ds:EnableTaskSwitch,al
                call    DM_OutInitP

                mov     ax,seg k_Table          ; Restore Entry Key Table
                mov     ds,ax
                assume  ds:seg k_Table
                mov     ax,cs:DM_OldKeyTable
                mov     ds:k_Table,ax

                mov     ax,CONio                ; Restore Entry CONIO Params
                mov     ds,ax
                assume  ds:CONio
                mov     ax,word ptr cs:DM_old_gl[0]
                mov     ds:GL_ParamsOfs,ax
                mov     ax,word ptr cs:DM_old_gl[2]
                mov     ds:GL_ParamsSeg,ax
                mov     ax,word ptr cs:DM_old_sio[0]
                mov     ds:SIO_ParamsOfs,ax
                mov     ax,word ptr cs:DM_old_sio[2]
                mov     ds:SIO_ParamsSeg,ax
                mov     ax,word ptr cs:DM_old_rk[0]
                mov     ds:RK_ParamsOfs,ax
                mov     ax,word ptr cs:DM_old_rk[2]
                mov     ds:RK_ParamsSeg,ax

                cmp     cs:DM_ScreenMode,3
                jne     DM_Entry_2
                cmp     cs:DM_SwapFlag,0
                jz      DM_Entry_2
                ScreenIOservice _SHOWSCREEN
                jmp     DM_Entry_3
DM_Entry_2:     mov     ax,seg C050
                mov     es,ax
                assume  es:seg C050
                mov     al,es:C050
                ScreenIOservice _SetScreen
DM_Entry_3:     popf
                pop     word ptr cs:[GetKeyParams.RK_AltFlag]
                RestoreAll
                ret
DMentry         endp
                assume  es:Emulate

DM              ends
                END

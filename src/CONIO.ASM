;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      CONIO.ASM                       |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Keyboard input / screen output  |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|


                include GLOBALS.INC
                include INTERFAC.INC
                include CONIO.INC

CONio           segment public
                assume  ds:CONio,cs:CONio,es:ApplerVideo


; --- Get Line Services Proc ---

GL_ServSubrt    dw      GetLine
                dw      GL_Symbol,GL_String,GL_Byte,GL_GetSymb,GL_Left,GL_Right
                dw      GL_Ins,GL_Del,GL_BackSpc,GL_Home,GL_End,GL_ClrBuff,GetCommand
GL_Services     proc    far
                push    bp ds
                shl     bp,1
                call    cs:GL_ServSubrt[bp]
                pop     ds bp
                ret
GL_Services     endp


; --- Screen Services Proc ---

SIO_ServSubrt   dw      ClearScreen,ShowScreen
                dw      SymbPrint,SymbPrintXY,BytePrint,StringPrint,GetSymb,ShowLine,CalcXY
                dw      ShowCursor,HideCursor,SetTextMode,SetScreen
SIO_Services    proc    far
                push    bp ds
                shl     bp,1
                call    cs:SIO_ServSubrt[bp]
                pop     ds bp
                ret
SIO_Services    endp


; --- Pointers Storage ---

GL_ParamsAdr    label   dword
GL_ParamsOfs    dw      ?
GL_ParamsSeg    dw      ?

SIO_ParamsAdr   label   dword
SIO_ParamsOfs   dw      ?
SIO_ParamsSeg   dw      ?

RK_ParamsAdr    label   dword
RK_ParamsOfs    dw      ?
RK_ParamsSeg    dw      ?

GL_SetRegs      macro
                lds     bp,cs:GL_ParamsAdr
                endm

SIO_SetRegs     macro
                lds     bp,cs:SIO_ParamsAdr
                endm

RK_SetRegs      macro
                lds     bp,cs:RK_ParamsAdr
                endm


; --- GET LINE proc ---

GL_Commands     db      05h,06h,09h,0Ah,0Bh
                db      01h,02h
                db      18h,0Ch
GL_ComSubrt     dw      GL_Left,GL_Right,GL_Ins,GL_Del,GL_BackSpc
                dw      GL_Home,GL_End
                dw      GL_Enter,GL_Esc
GL_FirstFlag    db      ?

GetLine:        push    ax bx cx dx di bp ds
                GL_SetRegs
                mov     cs:GL_FirstFlag,1
                mov     word ptr ds:[bp].GL_CX,cx
                call    CalcXY
                mov     ds:[bp].GL_X,cl
                mov     ds:[bp].GL_Y,ch
                mov     al,ds:[bp].GL_Length
                cmp     al,ds:[bp].GL_Pos
                jae     GL_Loop0
                mov     ds:[bp].GL_Pos,al
GL_Loop0:       test    ds:[bp].GL_InsFlag,1
                mov     al,ds:[bp].GL_OverCurColor
                jz      GL_Cursor
                mov     al,ds:[bp].GL_Length
                cmp     al,ds:[bp].GL_MaxLength
                mov     al,ds:[bp].GL_InsCurColor
                jb      GL_Cursor
                mov     al,ds:[bp].GL_OverCurColor
GL_Cursor:      SIO_SetRegs
                mov     ds:[bp].CursorColor,al
                GL_SetRegs
                xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                mov     ch,ds:[bp].GL_Y
                mov     cl,bl
                sub     cl,ds:[bp].GL_BegPrint
                add     cl,ds:[bp].GL_X
                call    ReadKey
                mov     di,offset GL_Commands
                mov     cx,offset GL_ComSubrt - offset GL_Commands
                call    CalcCommand
                jc      GL_NotCmnd
                shl     di,1
                call    word ptr cs:GL_ComSubrt[di]
                mov     cs:GL_FirstFlag,0
                jnc     GL_Loop0
                cmp     ax,0
                clc
                jz      GL_MainRet
                stc
GL_MainRet:     pop     ds bp di dx cx bx ax
                ret

GL_NotCmnd:     cmp     al,20h
                jb      GL_CallUser
                cmp     cs:GL_FirstFlag,0
                jz      GL_CallSymbol
                cmp     ds:[bp].GL_Pos,0
                ja      GL_CallSymbol
                call    GL_ClrBuff
GL_CallSymbol:  call    GL_Symbol
                jmp     GL_Loop0
GL_CallUser:    call    ds:[bp].[GL_User]
                mov     cs:GL_FirstFlag,1
                jmp     GL_Loop0


GL_Symbol:      push    bx cx dx si di ds es
                GL_SetRegs
                test    ds:[bp].GL_AllowSpc,1
                jnz     GL_S_do1
                cmp     al,20h
                je      GL_Sret
GL_S_do1:       xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                test    ds:[bp].GL_InsFlag,1
                jz      GL_S_Over
                xor     cx,cx
                mov     cl,ds:[bp].GL_Length
                cmp     cl,ds:[bp].GL_MaxLength
                jnb     GL_S_Over

                push    ds
                pop     es
                sub     cl,bl
                inc     cx
                xor     dx,dx
                mov     dl,ds:[bp].GL_Length
                mov     si,ds:[bp].GL_Buffer
                add     si,dx
                mov     di,si
                inc     di
                std
                rep     movsb
                inc     ds:[bp].GL_Length
                jmp     GL_S_1

GL_S_Over:      mov     cl,ds:[bp].GL_Length
                cmp     bl,cl
                jb      GL_S_1
                cmp     cl,ds:[bp].GL_MaxLength
                jnb     GL_Sret
                inc     ds:[bp].GL_Length
GL_S_1:         xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                add     bx,ds:[bp].GL_Buffer
                mov     [bx],al
                call    GL_Right

GL_Sret:        pop     es ds di si dx cx bx
                ret


GL_String:      push    ax bx bp ds              ; Puts a string in the buffer
                GL_SetRegs
GL_Str0:        mov     al,[bx]
                cmp     al,0
                je      GL_Str1
                call    GL_Symbol
                inc     bx
                jmp     GL_Str0
GL_Str1:        pop     ds bp bx ax
                ret


GL_Byte:        push    ax                      ; Overwrite / Insert a byte
                shr     al,4
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                call    GL_Symbol
                pop     ax
                push    ax
                and     al,00001111b
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                call    GL_Symbol
                pop     ax
                ret


GL_Left:        push    bx cx bp ds             ; Moves cursor left
                GL_SetRegs
                xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                cmp     bl,0
                jna     GL_Lret
                dec     bx
                mov     cx,bx
                sub     cl,ds:[bp].GL_BegPrint
                cmp     cl,2
                jae     GL_Lret
                cmp     ds:[bp].GL_BegPrint,0
                jna     GL_Lret
                dec     ds:[bp].GL_BegPrint
GL_Lret:        mov     ds:[bp].GL_Pos,bl
                pop     ds bp cx bx
                clc
                ret


GL_Right:       push    bx cx bp ds             ; Moves cursor right
                GL_SetRegs
                xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                cmp     bl,ds:[bp].GL_Length
                jnb     GL_Rret
                inc     bx
                mov     cx,bx
                mov     ch,ds:[bp].GL_MaxPrint
                sub     ch,2
                sub     cl,ds:[bp].GL_BegPrint
                cmp     cl,ch
                jb      GL_Rret
                mov     cl,ds:[bp].GL_Length
                sub     cl,ds:[bp].GL_BegPrint
                cmp     cl,ds:[bp].GL_MaxPrint
                jna     GL_Rret
                inc     ds:[bp].GL_BegPrint
GL_Rret:        mov     ds:[bp].GL_Pos,bl
                pop     ds bp cx bx
                clc
                ret


GL_Ins:         push    bp ds
                GL_SetRegs
                xor     ds:[bp].GL_InsFlag,1       ; Toggles INS mode
                pop     ds bp
                clc
                ret

GL_Del:         push    bx cx si di ds es       ; Delete char at cursor
                GL_SetRegs
                cmp     ds:[bp].GL_Length,0
                jz      GL_Dret
                xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                cmp     bl,ds:[bp].GL_Length
                jae     GL_Dret
                push    ds
                pop     es
                mov     si,ds:[bp].GL_Buffer
                add     si,bx
                mov     di,si
                inc     si
                xor     cx,cx
                mov     cl,ds:[bp].GL_Length
                sub     cl,bl
                cld
                rep     movsb
                dec     ds:[bp].GL_Length
                mov     bl,ds:[bp].GL_Length
                sub     bl,ds:[bp].GL_BegPrint
                cmp     bl,ds:[bp].GL_MaxPrint
                jae     GL_Dret
                cmp     ds:[bp].GL_BegPrint,0
                jz      GL_Dret
                dec     ds:[bp].GL_BegPrint
GL_Dret:        pop     es ds di si cx bx
                clc
                ret


GL_BackSpc:     push    bp ds
                GL_SetRegs
                cmp     ds:[bp].GL_Pos,0
                jna     GL_BS_ret
                call    GL_Left
                call    GL_Del
GL_BS_ret:      pop     ds bp
                clc
                ret


GL_Home:        push    bx
                mov     bx,0FFh
GL_Hloop:       call    GL_Left
                dec     bx
                jnz     GL_Hloop
                pop     bx
                clc
                ret


GL_End:         push    bx
                mov     bx,0FFh
GL_Eloop:       call    GL_Right
                dec     bx
                jnz     GL_Eloop
                pop     bx
                clc
                ret


GL_Esc:         call    GL_SetZero
                mov     ax,1
                stc
                ret


GL_Enter:       call    GL_SetZero
                mov     ax,0
                stc
                ret


GL_SetZero:     push    bx
                xor     bx,bx
                mov     bl,ds:[bp].GL_Length
                add     bx,ds:[bp].GL_Buffer
                mov     byte ptr [bx],0
                pop     bx
                ret


GL_ClrBuff:     push    ax bp ds
                GL_SetRegs
                xor     ax,ax
                mov     ds:[bp].GL_Pos,al
                mov     ds:[bp].GL_Length,al
                mov     ds:[bp].GL_BegPrint,al
                xor     cx,cx
                pop     ds bp ax
                ret


GL_GetSymb:     push    bx bp ds
                GL_SetRegs
                mov     ds:[bp].GL_Pos,cl
                mov     ds:[bp].GL_BegPrint,ch
GL_GS_Loop0:    xor     bx,bx
                mov     bl,ds:[bp].GL_Pos
                cmp     bl,ds:[bp].GL_Length
                mov     al,0
                jae     GL_GS_ret
                pushf
                add     bx,ds:[bp].GL_Buffer
                mov     al,ds:[bx]
                call    GL_Right
                popf
                jb      GL_GS_0
                inc     ds:[bp].GL_Pos
GL_GS_0:        test    ds:[bp].GL_GS_SpcFl,1
                jz      GL_GS_ret
                cmp     al,' '
                je      GL_GS_Loop0
GL_GS_ret:      mov     cl,ds:[bp].GL_Pos
                mov     ch,ds:[bp].GL_BegPrint
                pop     ds bp bx
                ret


GL_Ecx          dw      ?
GL_Ecx1         dw      ?
GL_ComSymb      db      'abcdefghijklmnopqrstuvwxyz?[.'
GL_ComSymbC     =       29
GetCommand:     push    si cx dx bp ds          ; Scan for commands
                GL_SetRegs
                mov     dl,ds:[bp].GL_GS_SpcFl
                mov     ds:[bp].GL_GS_SpcFl,0
                xor     di,di
                mov     si,ds:[bp].GL_BegScan
                mov     ds:[bp].GL_Eparam,1
                xor     cx,cx
GL_Eloop00:     call    GL_GetSymb
                cmp     al,' '
                je      GL_Eloop00
                dec     cl
                or      al,al
                jz      GL_Eerror1
                mov     cs:GL_Ecx1,cx
GL_Eloop0:      dec     si
                mov     cx,cs:GL_Ecx1
GL_Eloop1:      inc     si
                mov     cs:GL_Ecx,cx
                call    GL_GetSymb
                call    Upcase
                push    cx di
                mov     di,offset GL_ComSymb
                mov     cx,GL_ComSymbC
                call    CalcCommand
                pop     di cx
                jc      GL_Eok
                or      al,al
                jz      GL_Eok0
                cmp     al,ds:[si]
                je      GL_Eloop1
GL_Eloop2:      cmp     byte ptr ds:[si],0
                jz      GL_E0
                inc     si
                jmp     GL_Eloop2
GL_E0:          inc     si
                cmp     si,ds:[bp].GL_ENDScan
                ja      GL_Eerror
                inc     di
                jmp     GL_Eloop0
GL_Eerror:      mov     ds:[bp].GL_Pos,0
                mov     ds:[bp].GL_BegPrint,0
                mov     si,ds:[bp].GL_Error
                RK_SetRegs
                mov     ds:[bp].RK_ErrPtr,si
                GL_SetRegs
GL_Eerror1:     stc
                jmp     GL_Eret
GL_Eok0:        mov     ds:[bp].GL_Eparam,0
                jmp     GL_Eok1
GL_Eok:         mov     cx,cs:GL_Ecx
GL_Eok1:        mov     ds:[bp].GL_Pos,cl
                mov     ds:[bp].GL_BegPrint,ch
                xor     ax,ax
                cmp     di,0
                jz      GL_Eerror
                dec     di
                clc
GL_Eret:        mov     ds:[bp].GL_GS_SpcFl,dl
                pop     ds bp dx cx si
                ret


; --- SCREEN I/O procs ---

ClearScreen:    push    ax cx di es
                SIO_SetRegs
                les     di,dword ptr ds:[bp].SS_SourceOfs
                mov     ax,720h
                mov     cx,80*25
                cld
        rep     stosw
                pop     es di cx ax
                ret


ShowLine:       push    ax cx dx si di bp ds es
                SIO_SetRegs
                les     di,dword ptr ds:[bp].SS_SourceOfs
                GL_SetRegs
                add     di,ds:[bp].GL_CX
                xor     ax,ax
                mov     al,ds:[bp].GL_BegPrint
                mov     dh,al
                add     ax,ds:[bp].GL_Buffer
                mov     si,ax
                mov     ah,ds:[bp].GL_Color
                cld
                xor     cx,cx
                mov     cl,ds:[bp].GL_MaxPrint
GL_SL_Loop0:    lodsb
                cmp     dh,ds:[bp].GL_Length
                jb      GL_SL_1
                mov     al,' '
GL_SL_1:        stosw
                inc     dh
                loop    GL_SL_Loop0
                pop     es ds bp di si dx cx ax
                ret


; CalcXY--Translate page offset to X & Y coordinates
; Entry:
;   CX -- Page offset
; Exit:
;   CX -- Coordinates

CalcXY:         push    ax bx
                xor     ax,ax
                mov     bx,80 * 2
CXY_CalcLoop:   sub     cx,bx
                inc     ax
                jnc     CXY_CalcLoop
                add     cx,bx
                shr     cx,1
                mov     ch,al
                pop     bx ax
                ret


ShowScreen:     push    ds es di si cx bp       ; Moves the screen in the text page.
                SIO_SetRegs
                cmp     ds:[bp].SS_ScreenFLag,0
                jz      SSret
                call    SetTextMode
                lds     si,dword ptr ds:[bp].SS_SourceOfs
                mov     di,ApplerVideo
                mov     es,di
                xor     di,di
                mov     cx,80*25
                cld
        rep     movsw
SSret:          pop     bp cx si di es ds
                ret


; Shows a byte on the screen.
; Input:
;   AL -> byte to print, AH -> attributes
;   CX -> Page offset

; Output:
;   CX <- CX + 2

BytePrint:      push    ax bx
                mov     bx,ax
                shr     al,4
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                call    SymbPrint
                mov     al,bl
                and     al,00001111b
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                call    SymbPrint
                pop     bx ax
                ret
comment         %
BytePrint:      push    ax bx di es
                SIO_SetRegs
                les     di,dword ptr ds:[bp].SS_SourceOfs
                add     di,cx
                cld
                mov     bx,ax
                shr     al,4
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                stosw
                mov     al,bl
                and     al,00001111b
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                stosw
                add     cx,2*2
                pop     es di bx ax
                ret
                %


; Shows a symbol on the screen.
; Input:
;   AL -> symb, AH -> attributes
;   CX -> Page offset

; Output:
;   CX <- CX + 2

SymbPrint:      push    ds bp bx
                SIO_SetRegs
                cmp     ds:[bp].SP_BufFlag,0
                jnz     SP_Buffer
                lds     bx, dword ptr ds:[bp].SS_SourceOfs
                add     bx,cx
                mov     ds:[bx],ax
SP_Ret:         add     cx,2
                pop     bx bp ds
                ret
SP_Buffer:      call    GL_Symbol
                jmp     SP_Ret


; Shows a symbol on the screen.
; Input:
;   AL -> symb, AH -> attributes
;   CH -> vtab, CL -> htab

; Output:
;   CL <- CL + 1

SymbPrintXY:    push    ds bp bx cx ax
                SIO_SetRegs
                lds     bx, dword ptr ds:[bp].SS_SourceOfs
                dec     ch
                mov     al,ch
                mov     ah,80 * 2
                mul     ah
                add     bx,ax
                xor     ch,ch
                shl     cx,1
                add     bx,cx
                pop     ax
                mov     ds:[bx],ax
                pop     cx bx bp ds
                inc     cl
                ret


; Shows a string on the screen.
; Input:
; BX -> offset string
;   AH -> attributes
;   CX -> Page offset

; Output:
;   CX <- CX + String Length * 2

StringPrint:    push    ax bx dx si di bp ds es
                SIO_SetRegs
                mov     ds,ds:[bp].SP_SourceSeg
                les     di, dword ptr ds:[bp].SS_SourceOfs
                add     di,cx
                mov     si,bx
                cld

SP_Loop1:       lodsb
                mov     dl,al
                or      dl,dl
                jz      SP_0
                dec     dl
                jz      SP_1
                dec     dl
                jz      SP_2
                dec     dl
                jz      SP_3
                stosw
                jmp     SP_Loop1

SP_3:           lodsb
                mov     bl,al
                lodsb
                mov     bh,al
                mov     al,ds:[bx]
                jmp     SP_3_Entry

SP_2:           lodsb
SP_3_Entry:     mov     dl,al
                shr     al,4
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                stosw
                mov     al,dl
                and     al,00001111b
                cmp     al,0Ah
                cmc
                adc     al,30h
                daa
                stosw
                jmp     SP_Loop1

SP_1:           lodsb
                mov     ah,al
                add     bx,2
                jmp     SP_Loop1

SP_0:           mov     ds:[bp].SP_bx,si
                dec     si
                sub     si,bx
                shl     si,1
                add     cx,si
                pop     es ds bp di si dx bx ax
                ret


; Read a symbol from the screen.
; Input:
;   CH -> vtab, CL -> htab

; Output:
;   AH <- Attr, AL <- ASCII code
;   CX <- CX + 1

GetSymb:        push    ds bp si bx cx
                SIO_SetRegs
GetSymb1:       lds     si,dword ptr ds:[bp].SS_SourceOfs
                dec     ch
                mov     al,ch
                mov     ah,80 * 2
                mul     ah
                mov     bx,ax
                xor     ch,ch
                shl     cx,1
                add     bx,cx
                add     bx,si
                mov     ax,ds:[bx]
                pop     cx
                inc     cl
                push    cx
                SIO_SetRegs
                test    ds:[bp].SpacesFlag,1
                jz      GS_ret
                cmp     al,20h
                je      GetSymb1
GS_ret:         pop     cx bx si bp ds
                ret




OldCursor       db      80 dup (?)
ShowCursor:     push    ax bx cx dx bp ds
                SIO_SetRegs
                mov     dl,ds:[bp].SpacesFlag
                mov     dh,ds:[bp].CursorLen
                mov     ds:[bp].SpacesFlag,0
                xor     bx,bx
SC_Loop1:       call    GetSymb
                mov     cs:OldCursor[bx],ah
                cmp     ds:[bp].CursorFlag,0
                jz      SC_NoCursor
                and     ah,00001111b
                or      ah,ds:[bp].CursorColor
                dec     cl
                call    SymbPrintXY
SC_NoCursor:    inc     bx
                dec     dh
                jnz     SC_Loop1
                mov     ds:[bp].SpacesFlag,dl
                pop     ds bp dx cx bx ax
                ret


HideCursor:     push    ax bx cx dx bp ds
                SIO_SetRegs
                mov     dl,ds:[bp].SpacesFlag
                mov     dh,ds:[bp].CursorLen
                mov     ds:[bp].SpacesFlag,0
                xor     bx,bx
HC_Loop1:       call    GetSymb
                mov     ah,cs:OldCursor[bx]
                dec     cl
                call    SymbPrintXY
                inc     bx
                dec     dh
                jnz     HC_Loop1
                mov     ds:[bp].SpacesFlag,dl
                pop     ds bp dx cx bx ax
                ret



SetTextMode:    push    ax bx cx bp ds
                SIO_SetRegs
                test    ds:[bp].SS_ScreenFlag,1
                jz      STM_DontSet
                mov     ah,0Fh
                int     10h
                cmp     al,3
                je      STM_SetCursor
                mov     ax,3
                int     10h
                mov     cx,2021h
                mov     ah,1
                int     10h
                mov     ax,0500h
                int     10h

                mov     cs:STM_WaitFlag,0
                mov     ax,4
                mov     cx,seg STM_Wait
                mov     dx,offset STM_Wait
                call    TimerReq
STM_WaitLoop:   cmp     cs:STM_WaitFlag,0
                jz      STM_WaitLoop

STM_DontSet:    pop     ds bp cx bx ax
                ret
STM_SetCursor:  mov     cx,2021h
                mov     ah,1
                int     10h
                mov     ax,0500h
                int     10h
                jmp     STM_DontSet

STM_WaitFlag    db      ?
STM_Wait:       mov     cs:STM_WaitFlag,1
                retf


SetScreen:      SaveAll
                mov     bx,Apple
                mov     cx,Video
                mov     ds,bx
                mov     es,cx
                call    SetScrEntry
                RestoreAll
                ret


; --- Wait Key proc ---

                assume  es:Emulate

RK_ProcessIDs   db      PID_DEBUGGER
                db      PID_FILE_MANAGER
                db      PID_FLOPPY_DISK_MANAGER
                db      PID_KEYBOARD_SETUP
                db      PID_DONT_SWITCH
                db      PID_DONT_SWITCH
                db      PID_DONT_SWITCH
                db      PID_DONT_SWITCH
                db      PID_ABOUT_SCREEN
                db      PID_HELP_SCREEN
                db      PID_DOS_SHELL
                db      PID_QUIT_APPLER

                assume  es:Keyboard
ReadKey         proc    far
                push    bx dx bp ds es
GK_0:           mov     bx,Keyboard
                mov     es,bx
                RK_SetRegs
                call    WaitKey
                cmp     al,0Eh
                jb      GK_ret
                cmp     al,17h
                ja      GK_NoFkey
                test    es:k_Shifts,M_ALT
                jz      GK_NoAltF
                sub     al,0Eh
                xor     bx,bx
                mov     bl,al
                mov     al,cs:RK_ProcessIDs[bx]
                call    TaskSwitch
                jmp     GK_0
GK_NoALtF:      cmp     ds:[bp].RK_FkeyFlag,0
                jz      GK_NoFkey
                sub     al,0Eh
                call    ds:[bp].[RK_FkeyProc]
                jmp     GK_0
GK_NoFkey:      test    es:k_Shifts,M_ALT
                jz      GK_Ret
                cmp     ds:[bp].RK_AltFlag,0
                jz      GK_Ret
                call    ds:[bp].[RK_AltProc]
                jc      GK_0
GK_ret:         pop     es ds bp dx bx
                ret
ReadKey         endp
                assume  es:Emulate

WK_FkeysStr     db      '1D',4Fh,'e',4Fh,'b',4Fh,'u',4Fh,'g',4Fh,' ',4Fh,' '
                db      '2F',2Fh,'i',2Fh,'l',2Fh,'e',2Fh,'I',2Fh,'O',2Fh,' '
                db      '3D',6Fh,'i',6Fh,'s',6Fh,'k',6Fh,'I',6Fh,'O',6Fh,' '
                db      '4K',5Fh,'b',5Fh,'d',5Fh,'S',5Fh,'t',5Fh,'p',5Fh,' '
                db      '5 ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' '
                db      '6 ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' '
                db      '7 ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' '
                db      '8 ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' ',07h,' '
                db      '9A',1Fh,'b',1Fh,'o',1Fh,'u',1Fh,'t',1Fh,' ',1Fh,'1'
                db      '0H',3Fh,'e',3Fh,'l',3Fh,'p',3Fh,' ',3Fh,' ',3Fh,' '

WaitKey         proc    far
                push    bx si di bp ds es
WK_Loop0:       mov     bx,Keyboard
                mov     es,bx
                assume  es:Keyboard
                mov     es:k_KeyPressed,1
WK_Loop:        mov     bx,Keyboard
                mov     es,bx
                RK_SetRegs
                assume  ds:CONio
                cmp     ds:[bp].RK_WaitKeyFlag,0
                jz      WK_05
                call    ds:[bp].[RK_WaitKeyProc]
                jmp     WK_06
WK_05:          xor     al,al
                xchg    al,es:k_KeyPressed
                or      al,al
                jz      WK_07
                call    ds:[bp].[RK_ShowAll]
                call    ShowCursor
WK_06:          test    es:k_Shifts,M_ALT
                jz      WK_AltNoPress
                push    cx ds
                mov     cx,seg EnableTaskSwitch
                mov     ds,cx
                assume  ds:seg EnableTaskSwitch
                cmp     ds:EnableTaskSwitch,0
                jz      WK_AltNoPress1
                SIO_SetRegs
                assume  ds:CONio
                push    es
                les     di, dword ptr ds:[bp].SS_SourceOfs
                add     di,24*80*2
                push    cs
                pop     ds
                mov     si,offset WK_FkeysStr
                mov     cx,80
                cld
                rep     movsw
                pop     es
                RK_SetRegs
WK_AltNoPress1: pop     ds cx
WK_AltNoPress:  call    ShowScreen
WK_07:          mov     ax,Emulate
                mov     es,ax
                assume  es:Emulate
                mov     al,es:C000
                or      al,al
                jnz     WaitKey2
                jmp     WK_Loop

WaitKey2:       mov     bx,Keyboard
                mov     ds,bx
                assume  ds:Keyboard
                mov     ah,ds:k_ScanCode
                mov     C000,0
                call    key_taken
                call    HideCursor
                cmp     al,80h+1Ah
                je      WK_DosShell
                cmp     al,80h+1Bh
                je      WK_QuitAppler
                xor     al,10000000b
                RK_SetRegs
                assume  ds:CONio
                mov     ds:[bp].RK_ErrPtr,0
                pop     es ds bp di si bx
                ret

WK_DosShell:    call    DosShell
                jmp     WK_Loop0

WK_QuitAppler:  jmp     QuitAppler
WaitKey         endp



                assume  ds:seg k_Table
DKO_OldBuffFlag db      0
DebugKeysOn     proc    far
                push    ax ds
                mov     ax,seg k_Table
                mov     ds,ax
                mov     ds:k_Table,offset k_DebugTable
                xor     ax,ax
                xchg    ds:k_BufferFlag,al
                mov     cs:DKO_OldBuffFlag,al
                pop     ds ax
                ret
DebugKeysOn     endp

AppleKeysOn     proc    far
                push    ax ds
                mov     ax,seg k_Table
                mov     ds,ax
                mov     ds:k_Table,offset k_AppleTable
                mov     al,cs:DKO_OldBuffFlag
                mov     ds:k_BufferFlag,al
                pop     ds ax
                ret
AppleKeysOn     endp
                assume  ds:CONio



SwapFlag        db      1
ScreenSwapReq   proc    far
                push    ax cx dx
                mov     cs:SwapFlag,0
                mov     cx,seg ScreenSwap
                mov     dx,offset ScreenSwap
                or      ax,ax
                jnz     SSR_SetTimer
                call    ScreenSwap
                jmp     SSR_NoTimer
SSR_SetTimer:   call    TimerReq
SSR_NoTimer:    pop     dx cx ax
                ret
ScreenSwapReq   endp

ScreenSwap      proc    far
                cmp     cs:SwapFlag,0
                mov     cs:SwapFlag,1
                jnz     SS_Ret
                push    ax bx bp es
                mov     ah,0Fh
                int     10h
                cmp     al,3
                jne     SS_NoSwap
                mov     ax,seg C050
                mov     es,ax
                mov     al,C050
                ScreenIOservice _SetScreen
SS_NoSwap:      pop     es bp bx ax
SS_Ret:         ret
ScreenSwap      endp

; --- Internal procs ---

Upcase:         cmp     al,'A'
                jb      UPCSret
                cmp     al,'Z'
                ja      UPCSret
                or      al,20h
UPCSret:        ret

CalcCommand:    push    ax bx cx es             ; Returns number of a command             .
                push    cs                      ; Input:
                pop     es                      ;   di -> offset Commands
                cld                             ;   al -> search command
                mov     bx,di                   ;   cx -> commands count
                repne   scasb
                stc                             ; Output:
                jne     CC_end                  ;   di <- Number of the command
                sub     di,bx                   ;   cf <- 1 if not found
                dec     di
                clc
CC_end:         pop     es cx bx ax
                ret

CONio           ends
                end

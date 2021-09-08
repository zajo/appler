;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      STARTUP.ASM                     |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Program Startup                 |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

Startup         segment public
Startup         ends

                include GLOBALS.INC
                include INTERFAC.INC
                include FM.INC

Apple           segment public
                db      0FFFFh dup (0)
                org     0
                db      8Dh,51h,0C0h            ; 0000- STA C051
                db      8Dh,54h,0C0h            ; 0003- STA C054
                db      0A9h,0A0h               ; 0006- LDA #A0 <ÄÄÄÄÄ¿
                db      0A2h,0                  ; 0008- LDX #00       ³
                db      9Dh,0,4                 ; 000A- STA 400,x <Ä¿ ³
                db      0E8h                    ; 000D- INX         ³ ³
                db      0D0h,0FAh               ; 000E- BNE 000A ÄÄÄÙ ³
                db      0A5h,0Ch                ; 0010- LDA 0C        ³
                db      0C9h,7                  ; 0012- CMP #07       ³
                db      0B0h,5                  ; 0014- BCS 001B ÄÄÄ¿ ³
                db      0E6h,0Ch                ; 0016- INC 0C      ³ ³
                db      04Ch,6,0                ; 0018- JMP 0006 ÄÄÄÅÄÙ
                db      0B5h,28h                ; 001B- LDA 28,x <ÄÄÁÄ¿
                db      0F0h,0FEh               ; 001D- BEQ 001D      ³
                db      9,80h                   ; 001F- ORA #80       ³
                db      9Dh,0D0h,7              ; 0021- STA 07D0,x    ³
                db      0E8h                    ; 0024- INX           ³
                db      04Ch,1Bh,0              ; 0025- JMP 001B ÄÄÄÄÄÙ
                db      'ROM is missing, Apple halted. Press <F1>',0
Apple           ends



Startup         segment public
                assume  CS:Startup

StartHere:      xor     al,al
                out     21h,al
                mov     bx,sp
                shr     bx,4
                mov     ax,ss
                mov     cx,ds
                sub     ax,cx
                add     bx,ax
                inc     bx
                mov     ah,4Ah
                int     21h
                call    CheckVideoType          ; Check for video type
                call    CommandLine             ; Read ROM & Command Line Files
                call    SaveDosScr              ; Save DOS screen
                call    Advertisement           ; Show advertisement
                call    HookVectors             ; Hook 01 & 09 interrupts
                call    InitKeyboard            ; Turn keyboard lights off
                call    InitData                ; Build data tables
                call    SystemINIT
                call    InsertDisks             ; Insert Default Disk Files
                jmp     CALLpowerON             ; GO!


StartupON       proc    far
                call    HookVectors             ; Hook 01 & 09 interrupts
                call    InitKeyboard            ; Turn keyboard lights off
                call    SaveDosScr              ; Save DOS screen
                ret
StartupON       endp

StartupOFF      proc    far
                call    RestoreDosScr
                call    UnInitKeyboard
                call    UnHookVectors
                ret
StartupOFF      endp


CheckVideoType  Proc    near
                push    ds
                mov     ah,12h
                mov     bl,10h
                int     10h
                and     bl,not 10h              ; =0 if CGA or 64k EGA
                jz      ChkVideoType20
                cmp     bh,1
                jne     ChkVideoType10
                mov     ax,seg Port3?4h
                mov     ds,ax
                mov     DS:Port3?4h,3B4h
ChkVideoType10:
                pop     ds
                ret

ChkVideoType20: push    cs
                pop     ds
                mov     dx,offset NoEGAmessage
                mov     ah,9
                int     21h
                mov     ax,4C02h
                int     21h
;               exit    2

NoEGAmessage    db      0Dh,0Ah,'  This program requires 128k EGA or more.'
                db      0Dh,0Ah,'$'
CheckVideoType  Endp


RunFile?        db      0
StoredDS        dw      ?
DTA             db      80h dup (0)
Path            db      160 dup (0)

CommandLine     proc    near
                push    ds es
                mov     cs:StoredDS,ds
                mov     ah,62h
                int     21h
                mov     es,bx
                mov     es,es:[2Ch]
                xor     di,di
                mov     cx,0FFFFh
                cld
RF_SeekPath:    xor     al,al
        repne   scasb
                cmp     byte ptr es:[di],0
                jnz     RF_SeekPath
                mov     si,di
                add     si,3
                mov     ax,es
                mov     ds,ax
                push    cs
                pop     es
                mov     di,offset Path
                xor     bx,bx
RF_GetPath:     lodsb
                stosb
                cmp     al,'\'
                jne     RF_GP_1
                mov     bx,di
                jmp     RF_GetPath
RF_GP_1:        or      al,al
                jnz     RF_GetPath
                mov     cs:RF_FileSpecOfs,bx

                mov     es,cs:StoredDS
                push    cs
                pop     ds
                mov     dx,offset DTA
                mov     ah,1Ah
                int     21h
                mov     si,offset SysFileSpec
                call    CopyFileSpec
                mov     dx,offset Path
                mov     cx,0000000000100011b
                FindFirst
                jc      Init20
Init10:         push    cs
                pop     ds
                mov     si,offset DTA+1Eh
                call    CopyFileSpec
                mov     dx,offset Path
                call    ReadFile
                push    cs
                pop     ds
                mov     dx,offset DTA
                FindNext
                jnc     Init10
Init20:         cmp     byte ptr es:[80h],0
                jz      Init25
                mov     byte ptr cs:SkipTitle?,1
Init25:         mov     di,81h
InitCycle:      xor     cx,cx
                mov     cl,ES:[80h]
                or      cx,cx
                je      InitCycle2
                cld
                mov     al,' '
        repe    scasb
InitCycle2:     je      InitCont_J
                cmp     byte ptr es:[di-1],'/'
                jne     i_not_option
                mov     ax,word ptr es:[di]
                cmp     ah,' '
                je      i_opt_ok
                cmp     ah,0Dh
                jne     i_unknown
i_opt_ok:       cmp     al,'?'
                jne     i_not_help
                push    cs
                pop     ds
                mov     dx,offset i_help_mes
                mov     ah,9
                int     21h
                jmp     i_halt
i_not_help:     or      al,20h
                cmp     al,'k'
                jne     i_unknown
                push    ds
                mov     ax,Keyboard
                mov     ds,ax
                assume  ds:Keyboard
                mov     K_KeyboardRet1,0CBh
                mov     K_KeyboardRet2,0CBh
                mov     K_KeyboardRet3,0CBh
                mov     K_KeyboardRet4,0CBh
                pop     ds
                assume  ds:nothing
                inc     di
                dec     cx
                or      cx,cx
                jz      InitCont_J
                mov     es:[80h],cl
                jmp     InitCycle
i_unknown:      mov     dx,offset UnknownMes
                push    cs
                pop     ds
                push    ax
                mov     ah,9
                int     21h
                mov     ah,2
                pop     dx
                cmp     dl,2Dh
                je      i_blank_prm
                int     21h
i_blank_prm:    mov     dl,0Ah
                int     21h
i_halt:         mov     ax,4C02h
                int     21h
;               exit    2
i_not_option:   cmp     byte ptr es:[di-1],'-'
                mov     cs:RunFile?,1
ESD_0:          jne     ESD_1
                mov     cs:RunFile?,0
        repe    scasb
                je      InitCont_J
ESD_1:          lea     si,[di-1]
        repne   scasb
                jne     InitCycle3
                dec     di
InitCycle3:     xor     al,al
                stosb
                mov     ES:[80h],cl

                push    di ds es
                mov     di,offset Path
                push    es
                pop     ds
                push    cs
                pop     es
                xor     dl,dl
AddExtLoop:     lodsb
                stosb
                cmp     al,'.'
                jne     AE_1
                mov     dl,1
AE_1:           cmp     al,'\'
                jne     AE_2
                xor     dl,dl
AE_2:           or      al,al
                jnz     AddExtLoop
                dec     di
                mov     cx,5
                mov     si,offset DefaultExt
                push    cs
                pop     ds
                or      dl,dl
                jnz     DontAddExt
        rep     movsb
DontAddExt:     mov     dx,offset Path
                call    ReadFile
                pop     es ds di

                jmp     InitCycle
InitCont_J:     jmp     InitCont

DefaultExt      db      '.APL',0



RF_DS_SI        label   dword
RF_SI           dw      ?
RF_DS           dw      ?
ReadFile:       mov     cs:[InitErrBuf],dx      ; DS:DX - read file name
                mov     cs:[InitErrBuf][2],ds
                mov     cs:RF_SI,dx
                mov     cs:RF_DS,ds
                mov     ax,3D00h
                int     21h
                jc      InitErrNC
                xchg    ax,bx
                push    cs
                pop     ds
                mov     dx,offset InitFileAdr
                mov     cx,4
                mov     ah,3Fh
                int     21h
                jc      InitErrC
                mov     ax,Apple
                mov     ds,ax
                mov     dx,CS:InitFileAdr
                mov     cx,CS:InitFileLen
                mov     ax,dx
                add     ax,cx
                jnc     RF_NotBig
                sub     cx,ax     ;Decrease file length to fit in Apple segment
RF_NotBig:      cmp     cs:RunFile?,0
                jz      ESD_2
                push    cx si di ds es
                push    ds
                pop     es
                push    cs
                pop     ds
                mov     si,offset SlotPrg
                mov     di,0C700h
                mov     cx,SlotLen
        rep     movsb
                mov     di,0C700h
                mov     ds:SlotLen[di],dx
                pop     es ds di si cx
ESD_2:          mov     ah,3Fh
                int     21h
                jc      InitErrC
                mov     cs:InitFileLen,ax
                mov     ah,3Eh
                int     21h
                jc      InitErrNC
                lds     si,cs:RF_DS_SI
                mov     ax,cs:InitFileAdr
                mov     bx,cs:InitFileLen
                mov     ch,FF_SHOWADDR? or FF_MODIFYADDR? or FF_MODIFYTYPE?
                mov     cl,FD_CODE
                call    FileIsLoaded
                ret

InitErrC:       mov     ah,3Eh
                int     21h
InitErrNC:      push    cs
                pop     ds
                mov     dx,offset InitErrMes1
                mov     ah,9
                int     21h
                les     di,dword ptr CS:[InitErrBuf]
                xor     ax,ax
                mov     cx,ax
                dec     cx
                cld
        repne   scasb
                dec     di
                mov     al,'$'
                stosb
                lds     dx,dword ptr CS:[InitErrBuf]
                mov     ah,9
                int     21h
                push    cs
                pop     ds
                mov     dx,offset InitErrMes2
                mov     ah,9
                int     21h
                mov     ax,4C01h
                int     21h
;               exit    1
InitCont:       pop     es ds
                ret

RF_FileSpecOfs  dw      ?
CopyFileSpec:   push    ax si di ds es
                mov     ax,Startup
                mov     ds,ax
                mov     es,ax
                mov     di,cs:RF_FileSpecOfs
                cld
CopyFileSpecLp: lodsb
                stosb
                or      al,al
                jnz     CopyFileSpecLp
                pop     es ds di si ax
                ret

SysFileSpec     db      '*.ROM',0

InitFileAdr     dw      0
InitFileLen     dw      0

InitErrBuf      dw      2 dup (0)

UnknownMes      db      0Dh,0Ah,'  Bad command line parameter: /$'
InitErrMes1     db      0Dh,0Ah,'  APPLER: Can''t read file $'
InitErrMes2     db      0Dh,0Ah,'$'
i_help_mes      db      0Dh,0Ah
                db      '  Appler - an Apple ][ emulator by Emil Dotchevski & Alexander Patalenski',0Dh,0Ah,0Dh,0Ah
                db      '  Command line syntax: appler [[-]<filename[.APL]>] ... [/k] [/?]',0Dh,0Ah
                db      '    <filename> - ''.APL'' file to load (use ''-'' to disable file execution)',0Dh,0Ah
                db      '    /k         - don''t set keyboard params',0Dh,0Ah
                db      '    /?         - this message',0Dh,0Ah
                db      '$'

SlotPrg         db      0A9h,20h,0A9h,0,0A9h,3,0A9h,3Ch,4Ch
SlotEnd         label   byte
SlotLen         =       offset SlotEnd - offset SlotPrg
CommandLine     endp



; OpenDiskFile Entry Params:
;   DS:DX^  -- Filename
;   AL      -- Access Mode: 0 - Don't Change, else Read Only
;   BL      -- Type: 0 - Nibble, 1 - DOS 3.3
;   BH      -- Volume (for DOS 3.3 type only)
;   CF      -- 0 - Disk1, 1 - Disk2
InsertDisks     proc    near
                push    ds
                push    cs
                pop     ds
                mov     dx,offset ID_nameDSK
                mov     bl,1
                mov     bh,0FEh
                mov     al,0
                clc
                call    OpenDiskFile
                jnc     ID_Ret
                mov     dx,offset ID_nameNBL
                mov     bl,0
                mov     al,0
                clc
                call    OpenDiskFile
ID_Ret:         pop     ds
                ret
ID_nameNBL      db      'APPLER.NBL',0
ID_nameDSK      db      'APPLER.DSK',0
InsertDisks     endp



Advertisement   proc    near
                push    ds es
                push    cs
                pop     ds
                cmp     SkipTitle?,0
                jnz     a_SkipTitle
                mov     ax,0B800h
                mov     es,ax
                mov     di,80*24*2
                mov     cx,80
                xor     ax,ax
                cld
        rep     stosw
                mov     si,offset a_picture
                push    es
                push    cs
                pop     es
                mov     ax,1201h
                mov     bl,30h
                int     10h
                mov     ax,83h
                int     10h
                mov     ax,1110h
                mov     cx,76
                mov     bx,0E00h
                mov     dx,0B0h
                mov     bp,offset a_GraphSet
                int     10h
                mov     ah,01h
                mov     cx,2000h
                int     10h
                mov     ax,1202h
                mov     bl,30h
                int     10h
                mov     ax,1000h
                mov     bx,2A0Ah
                int     10h
                mov     bx,260Eh
                int     10h
                mov     bx,2406h
                int     10h
                mov     bx,1C03h
                int     10h
                mov     ax,1003h
                mov     bl,0
                int     10h
                cld
                pop     es
                xor     di,di
                mov     ah,7
                mov     cx,80*24
a_loop:         lodsb
                or      al,al
                jnz     a_not_attr
                lodsb
                mov     ah,al
                jmp     a_loop
a_not_attr:     stosw
                loop    a_loop
                xor     ax,ax
                int     16h
a_SkipTitle:    pop     es ds
                ret

SkipTitle?      db      0
Buffer1000h     label   byte
a_picture       db      0,03h,'ÐÜññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññññÝÑ'
                db      0,03h,'ð ',0,00Ah,'Ð',0,0AFh,'                                                                          ',0,00Ah,'Ñ',0,03,' ð'
                db      0,03h,'ð ',0,0A0h,'  ÐððððððððððÑ                             ÙððÑ                             ',0,03,' ð'
                db      0,03h,'ð ',0,0E0h,'  ðððÜññññÝððð                              ððð                          ôõ ',0,03,' ð'
                db      0,03h,'ð ',0,0E0h,'  ððð      ððð ÙðððððððððððÑ ÙðððððððððððÑ  ððð  ÐððððððððððÑ ÙððÑÐððððððÑ  ',0,03,' ð'
                db      0,03h,'ð ',0,060h,'  ðððÚ    Ûððð  ðððÜññññÝððð  ðððÜññññÝððð  ððð  ðððÜññññÝððð  ðððÜñññÝððð  ',0,03,' ð'
                db      0,03h,'ð ',0,060h,'  ðððððððððððð  ððð      ððð  ððð      ððð  ððð  ðððÞòòòòßððð  ððð     Öñ×  ',0,03,' ð'
                db      0,03h,'ð ',0,040h,'  ðððÜññññÝððð  ððð      ððð  ððð      ððð  ððð  ðððððððððððÓ  ððð          ',0,03,' ð'
                db      0,03h,'ð ',0,040h,'  ððð      ððð  ðððÞòòòòßððð  ðððÞòòòòßððð  ððð  ðððä       Û  ððð          ',0,03,' ð'
                db      0,03h,'ð ',0,050h,' ÛðððÚ    ÛðððÚ ðððððððððððÓ  ðððððððððððÓ ÛðððÚ ÒððððððððððÓ ÛðððÚ         ',0,03,' ð'
                db      0,03h,'ð ',0,050h,'                ðððØ          ðððØ                                          ',0,03,' ð'
                db      0,03h,'ð ',0,010h,'               ÛðððÚ         ÛðððÚ                                          ',0,03,' ð'
                db      0,03h,'ð ',0,001h,'Ò',0,01Fh,'                                                                          ',0,001h,'Ó',0,03,' ð'
                db      0,03h,'ð                                                                              ð'
                db      0,03h,'ð ',0,00Fh,' ÐÜñÝÑ ',0,008h,'The Best!',0,00Fh,'  ÙÑ        ÝÑ ÐÜ     ÐÜññù           ÙÑ     ÛÑÚ            ',0,03,' ð'
                db      0,03h,'ð ',0,00Fh,' ðÚ Ûð ÐÜñÝÑ ÐÜñÝÑ ð ÐèñéÑ   ð ð      ðÞòò ÙêíðíÑ ð  ð ð ÐÜÝêÙðØ  ÐÜÝÑÙêÜÝÑ ',0,03,' ð'
                db      0,03h,'ð ',0,00Fh,' ðÜñÝð ðÚ Ûð ðÚ Ûð ð ðèññ×  Ûð ðÚ     ðä    ð ð ð ðÚÛð ð ðÚÛð ðÚ ÛðÚÛð ð    ',0,03,' ð'
                db      0,03h,'ð ',0,00Fh,' ñ   ñ ðÜññ× ðÜññ× ñ Öñññ×  ñ× Öñ     Öññññ ñ ñ ñ Öñ×Öâñ Öñ×ÖâÖññ×Öññ× ñ    ',0,03,' ð'
                db      0,03h,'ð ',0,00Fh,'       ñ     ñ                                    ',0,008h,'°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈ ',0,03,' ð'
                db      0,03h,'ð                                                                              ð'
                db      0,03h,'ð ',0,00Bh,'                  by Alexander Patalenski & Emil Dotchevski                 ',0,03,' ð'
                db      0,03h,'ð ',0,00Fh,'                 óóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóóó                ',0,03,' ð'
                db      0,03h,'ð ',0,00Bh,'                        https://github.com/zajo/appler                      ',0,03,' ð'
                db      0,03h,'ÒÞòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòòßÓ'
end_ega_picture label   byte
                db      1000h - (offset end_ega_picture - offset a_picture) dup (0)
Advertisement   endp


HookVectors     proc    near
                push    ds es
                mov     ax,3509h
                int     21h
                mov     word ptr CS:[OldKbd],bx
                mov     word ptr CS:[OldKbd][2],es
                mov     al,1
                int     21h
                mov     word ptr CS:[OldDebug],bx
                mov     word ptr CS:[OldDebug][2],es
                mov     al,24h
                int     21h
                mov     word ptr CS:[OldCriticalErr],bx
                mov     word ptr CS:[OldCriticalErr][2],es
                mov     ax,seg k_int09
                mov     ds,ax
                mov     dx,offset k_int09
                mov     ax,2509h
                int     21h
                mov     bx,seg WaitInstrEnd
                mov     ds,bx
                mov     dx,offset WaitInstrEnd
                mov     al,1
                int     21h
                mov     bx,seg CriticalErrProc
                mov     ds,bx
                mov     dx,offset CriticalErrProc
                mov     al,24h
                int     21h
                pop     es ds
                ret

OldKbd          dd      0
OldDebug        dd      0
OldCriticalErr  dd      0
HookVectors     endp



UnHookVectors   proc    near
                push    ds
                lds     dx,cs:OldDebug
                mov     ax,2501h
                int     21h
                lds     dx,cs:OldKbd
                mov     al,9
                int     21h
                lds     dx,cs:OldCriticalErr
                mov     al,24h
                int     21h
                pop     ds
                ret
UnHookVectors   endp


CriticalErrProc proc    far
                mov     al,3
                iret
CriticalErrProc endp



InitKeyboard    proc    near
                push    ds
                xor     ax,ax
                mov     ds,ax
                mov     ds:[417h],ax
                call    UpdateKeyboard
                mov     ax,Keyboard
                mov     ds,ax
                assume  ds:Keyboard
                xor     ax,ax
                mov     ds:k_Shifts,ax
                call    SetLEDs
                assume  ds:nothing
                pop     ds
                ret
InitKeyboard    endp



UnInitKeyboard  proc    near
                push    ax si ds
                xor     ax,ax
                call    SetLEDs
                mov     ds,ax
                mov     ds:[417h],ax
UIK_Loop1:      mov     ah,1
                int     16h
                jz      UIK_ok
                xor     ax,ax
                int     16h
                jmp     UIK_Loop1
UIK_ok:         pop     ds si ax
                ret
UnInitKeyboard  endp



SaveDosScr:     push    ds es
                mov     ah,0Fh
                int     10h
                mov     cs:ModeSvd,al
                mov     cs:PageSvd,bh
                mov     ah,3
                int     10h
                mov     cs:CursorSvd,dx
                mov     cs:CursorShapeSVD,cx
                mov     cx,80 * 25
                mov     si,0B800h
                mov     ds,si
                push    cs
                pop     es
                xor     si,si
                mov     di,offset DosScrSvd
                cld
                rep     movsw
                mov     cx,2021h
                mov     ah,1
                int     10h
                pop     es ds
                ret

RestoreDosScr:  push    ds es
                mov     ah,0Fh
                int     10h
                xor     ah,ah
                cmp     al,2
                jb      RDS_Set
                cmp     al,cs:ModeSvd
                je      RDS_DontSet
RDS_Set:        mov     al,cs:ModeSvd
                int     10h
RDS_DontSet:    mov     al,cs:PageSvd
                mov     al,0
                mov     ah,5
                int     10h
                mov     bh,cs:PageSvd
                mov     ah,2
                mov     dx,cs:CursorSvd
                int     10h
                mov     ah,1
                mov     cx,cs:CursorShapeSVD
                int     10h
                mov     cx,80 * 25
                mov     si,0B800h
                mov     es,si
                push    cs
                pop     ds
                xor     di,di
                mov     si,offset DosScrSvd
                cld
        rep     movsw
                pop     es ds
                ret

DosScrSvd       dw      80 * 25 dup (0)
ModeSvd         db      0
PageSvd         db      0
CursorSvd       dw      0
CursorShapeSVD  dw      0


DS_CurrentVM    db      ?
DosShell        proc    far
                push    ax bx cx dx si di bp ds es
                mov     ah,0Fh
                int     10h
                mov     cs:DS_CurrentVM,al
                mov     ah,62h
                int     21h
                mov     es,bx
                mov     ds,es:[2Ch]
                mov     es,es:[2Ch]
                xor     di,di
                mov     si,di
                mov     bx,di
                cld
DS_FindEnd:     lodsb
                inc     bx
                or      al,al
                jnz     DS_FindEnd
                lodsb
                inc     bx
                or      al,al
                jnz     DS_FindEnd
                xor     ax,ax
                push    cs
                pop     ds
DS_ScanLoop:    mov     si,offset DS_ComSpecStr
                mov     di,ax
                mov     cx,8
        rep     cmpsb
                je      DS_Found
                inc     ax
                dec     bx
                jnz     DS_ScanLoop
                jmp     DS_Ret
DS_Found:       push    di es
                call    SystemTINI
                call    StartupOFF
                pop     es di
                push    cs
                pop     ds
                mov     dx,offset DS_Message
                mov     ah,9
                int     21h
                push    es
                pop     ds
                push    cs
                pop     es
                mov     dx,di
                mov     bx,offset DS_EPB
                mov     cs:DS_save_ss,ss
                mov     cs:DS_save_sp,sp
                mov     ax,4B00h
                int     21h
                mov     ss,cs:DS_save_ss
                mov     sp,cs:DS_save_sp
                jnc     DS_ok
                push    cs
                pop     ds
                mov     dx,offset DS_NoMemMes
                mov     ah,9
                int     21h
DS_WaitEsc:     xor     ax,ax
                int     16h
                cmp     al,27
                jne     DS_WaitEsc
DS_ok:          call    StartupON
                call    SystemINIT
DS_Ret:         mov     ah,0Fh
                int     10h
                cmp     al,cs:DS_CurrentVM
                je      DS_DontSet
                xor     ax,ax
                mov     al,cs:DS_CurrentVM
                int     10h
DS_DontSet:     cmp     al,3
                je      RS_Exit
                mov     ax,seg C050
                mov     es,ax
                assume  es:seg C050
                mov     al,es:C050
                mov     bp,12                   ; Set Screen
                call    SIO_Services
                assume  es:nothing
RS_Exit:        pop     es ds bp di si dx cx bx ax
                ret

DS_ComSpecStr   db      'COMSPEC='
DS_EPB          dw      0
                dw      offset DS_CMDline, seg DS_CMDline
                dd      2 dup (0)
DS_CMDline      db      0,0Dh
DS_save_ss      dw      ?
DS_save_sp      dw      ?
DS_Message      db      0Dh,0Ah,'Enter ''EXIT'' to return to APPLER...$'
DS_NoMemMes     db      0Dh,'Can''t run command interpreter (not enough memory?)'
                db      0Dh,0Ah,0Ah,'         Press <Esc> to return to APPLER',0Dh,0Ah,'$'
DosShell        endp



                assume  DS:nothing
QuitAppler      proc    far
                call    SystemTINI
                call    StartupOFF
                push    cs
                pop     ds
                mov     dx,offset ExitMes
                mov     ah,9
                int     21h
                mov     ax,4C00h
                int     21h
;               exit    0                     ; Normal Program EXIT
QuitAppler      endp

ExitMes         db      0Ah,0Dh,'  Back to reality (of sorts)...',0Ah,0Dh,'$'


Screen          label   word
a_BegSet        label   byte
a_GraphSet      db      000h,000h,000h,000h,08Ah,08Bh,0AAh
                db      0AAh,0AAh,052h,000h,000h,000h,000h
                db      000h,000h,014h,007h,094h,054h,014h
                db      014h,014h,013h,000h,000h,000h,000h
                db      000h,000h,020h,038h,020h,021h,021h
                db      021h,0A5h,018h,000h,000h,000h,000h
                db      000h,000h,000h,000h,0CEh,029h,029h
                db      0C9h,009h,0E9h,000h,000h,000h,000h
                db      000h,000h,008h,008h,00Eh,009h,009h
                db      009h,009h,00Eh,000h,000h,000h,000h
                db      000h,000h,000h,000h,048h,048h,048h
                db      048h,038h,008h,008h,070h,000h,000h
                db      000h,000h,040h,070h,042h,042h,042h
                db      042h,04Ah,031h,000h,000h,000h,000h
                db      000h,000h,000h,000h,026h,029h,0A9h
                db      0A9h,0A9h,046h,000h,000h,000h,000h
                db      000h,000h,000h,000h,00Eh,009h,009h
                db      009h,009h,00Eh,008h,008h,000h,000h
                db      000h,000h,000h,000h,031h,04Ah,04Ah
                db      04Ah,04Ah,031h,000h,000h,000h,000h
                db      000h,000h,000h,000h,094h,05Ah,050h
                db      050h,050h,090h,000h,000h,000h,000h
                db      000h,000h,010h,010h,01Ch,012h,012h
                db      012h,012h,01Ch,000h,000h,000h,000h
                db      000h,000h,006h,002h,092h,092h,092h
                db      092h,092h,06Ah,000h,000h,000h,000h
                db      000h,000h,000h,000h,069h,092h,092h
                db      092h,092h,071h,010h,010h,0E0h,000h
                db      000h,000h,000h,000h,0CAh,04Dh,048h
                db      048h,048h,0A8h,000h,000h,000h,000h
                db      000h,000h,040h,000h,04Eh,052h,052h
                db      052h,052h,04Dh,000h,000h,000h,000h
                db      000h,000h,000h,000h,070h,048h,048h
                db      048h,048h,048h,000h,000h,000h,000h
                db      000h,000h,000h,000h,072h,04Bh,04Ah
                db      04Ah,04Ah,072h,040h,040h,000h,000h
                db      000h,000h,000h,000h,08Ch,052h,012h
                db      012h,012h,00Ch,000h,000h,000h,000h
                db      000h,000h,000h,000h,06Ah,093h,092h
                db      092h,092h,072h,010h,0E0h,000h,000h
                db      000h,000h,000h,000h,08Eh,052h,012h
                db      012h,012h,00Dh,000h,000h,000h,000h
                db      000h,000h,000h,000h,079h,055h,055h
                db      055h,055h,055h,000h,000h,000h,000h
                db      000h,000h,000h,000h,0E3h,054h,054h
                db      057h,054h,053h,000h,000h,000h,000h
                db      000h,000h,000h,000h,028h,0B5h,0A0h
                db      0A0h,020h,0A1h,000h,000h,000h,000h
                db      000h,000h,000h,000h,0C0h,000h,0C0h
                db      020h,020h,0C0h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,007h,01Fh,03Fh,07Fh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      000h,0E0h,0F8h,0FCh,0FEh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,07Fh,03Fh,01Fh,007h,000h
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FEh,0FCh,0F8h,0E0h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,007h,01Fh,03Fh,07Fh,0FFh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,0E0h,0F8h,0FCh,0FEh,0FFh,0FFh
                db      0FFh,0FFh,07Fh,03Fh,01Fh,007h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0FFh,0FEh,0FCh,0F8h,0E0h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0F8h,0E0h,0C0h,080h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,01Fh,007h,003h,001h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,080h,0C0h,0E0h,0F8h,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,001h,003h,007h,01Fh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0F8h,0E0h,0C0h,080h,000h,000h
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,01Fh,007h,003h,001h,000h,000h
                db      000h,000h,080h,0C0h,0E0h,0F8h,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      000h,000h,001h,003h,007h,01Fh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0F8h,0E0h,0C0h,080h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,01Fh,007h,003h,001h,000h,000h
                db      000h,000h,080h,0C0h,0E0h,0F8h,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,001h,003h,007h,01Fh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0F8h,0E0h,0C0h,080h,000h,000h
                db      000h,000h,080h,0C0h,0E0h,0F8h,0FFh
                db      0FFh,01Fh,007h,003h,001h,000h,000h
                db      000h,000h,001h,003h,007h,01Fh,0FFh
                db      0FFh,0F8h,0E0h,0C0h,0E0h,0F8h,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,01Fh,007h,003h,007h,01Fh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0F8h,0E0h,0C0h,0E0h,0F8h,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,01Fh,007h,003h,007h,01Fh,0FFh
                db      000h,0C3h,0E7h,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0E7h,0C3h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0C3h,0E7h,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0E7h,0C3h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,0C3h,0E7h,0FFh,0FFh,0FFh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0FFh,0FFh,0FFh,0E7h,0C3h,000h
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,0FFh
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh
                db      0FFh,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,07Eh,07Eh,018h
                db      018h,018h,018h,018h,018h,000h,000h
                db      000h,000h,000h,000h,0C6h,0EEh,0FEh
                db      0D6h,0C6h,0C6h,0C6h,0C6h,000h,000h
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ; not used
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ; not used
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ; not used
                db      0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ; not used
                db      007h,01Fh,03Fh,07Fh,0FFh,0FFh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      0E0h,0F8h,0FCh,0FEh,0FFh,0FFh,0FFh
                db      000h,000h,000h,000h,000h,000h,000h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0FFh,0FFh,07Fh,03Fh,01Fh,007h
                db      000h,000h,000h,000h,000h,000h,000h
                db      0FFh,0FFh,0FFh,0FEh,0FCh,0F8h,0E0h
a_EndSet        label   byte
                dw      (80*26) - ((offset a_EndSet - offset a_BegSet) / 2) dup (0)

Startup         ends

                END     StartHere

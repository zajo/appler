;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      EMULATE.ASM                     |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   I/O Switches Emulation          |
; |                                             |
; |  Authors:   Alexander & Emil                |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC

                ReadAllFreeSpace

Emulate         segment common
                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

                UseNextFreeSpace
AppleFlags      db      00110000b
                even
AppleSP         dw      StackPage*100h + 0FFh

SaveStack       dw      0
ResetFlag       db      0

C000            db      0
C050            db      0000b
C080            db      1000b

HGRcolor        db      07h
		even
Port3?4h        dw      3D4h
                CheckAddress

                UseNextFreeSpace
SetScrEntry     Proc    far                     ; Set Screen mode.
                mov     si,ax                   ; AL - mode.
                xor     al,1b
                mov     ah,C050
                ror     ax,1
                rol     ah,1
                mov     C050,ah
                mov     dx,50h
SetScrEntry10:  shr     si,1
                mov     bx,dx
                adc     bl,0
                shl     bx,1
                mov     di,offset SetScrEntry20
                jmp     SS:C0XXRead[bx]
SetScrEntry20:  add     dl,2
                cmp     dl,58h
                jb      SetScrEntry10
                ret
SetScrEntry     Endp
                CheckAddress

                UseNextFreeSpace
PowerON         Proc    far                     ; Initial Test entry point
                mov     ax,Apple
                mov     bx,Video
                mov     ds,ax
                mov     es,bx
                mov     al,0
                call    SetScrEntry
                jmp     RESET
PowerON         Endp
                CheckAddress

                UseNextFreeSpace
RESET           Proc    far                     ; Reset Pressed entry point
                xor     eax,eax
                push    ax
                popf
                mov     ax,Data
                mov     ss,ax
                mov     sp,CS:[SaveStack]
                call    SystemRESET
RESET_Wait:     sti
                test    CS:[ResetFlag],00000001b
                jnz     RESET_Wait

                mov     ax,Apple
                mov     bx,Video
                mov     ds,ax
                mov     es,bx
                xor     ax,ax
                mov     bx,ax
                mov     cx,ax
                mov     dx,ax
                mov     di,ax
                mov     bp,ax
                sahf
                mov     si,DS:[RESETvector]
                DoNext
RESET           Endp
                CheckAddress

                UseNextFreeSpace
ChangeTEXTcolor Proc    far
                Save    ax cx di es
                mov     di,ss
		mov     es,di
                mov     di,offset TEXTchars + 1
                mov     cx,40h
                mov     ah,al
                shl     al,4
		cld
TC_Loop1:       stosb
                inc     di
                loop    TC_Loop1
                or      al,10000000b
                mov     cx,40h
TC_Loop2:       stosb
                inc     di
                loop    TC_Loop2
                mov     cx,80h
		mov     al,ah
TC_Loop3:       stosb
                inc     di
                loop    TC_Loop3
                Restore ax cx di es
                ret
ChangeTEXTcolor Endp
                CheckAddress


;-------------- Keyboard emulation entries & subroutines -----------------------

                UseNextFreeSpace
C000r:          call    key_taken
                call    synchronize
                mov     al,C000
                mov     bl,ch
                jmp     di
C000w:          call    synchronize
                sahf
                DoNext
C010r:          call    synchronize
                and     byte ptr C000,01111111b
                call    GetBuffer
                mov     bl,ch
                jmp     di
C010w:          call    synchronize
                and     byte ptr C000,01111111b
                call    GetBuffer
		sahf
                DoNext

ResetKeyboard   Proc    far
                mov     C000,0
                call    ClearBuffer
                ret
ResetKeyboard   Endp
                CheckAddress

;-------------- Speaker emulation entries & subroutines ------------------------

                UseNextFreeSpace
C030r:          call    synchronize
                in      al,61h
                xor     al,00000010b
                out     61h,al
                mov     bl,ch
                jmp     di
C030w:          call    synchronize
                in      al,61h
                xor     al,00000010b
                out     61h,al
                sahf
                DoNext

C020r:          call    synchronize
                mov     al,cs:C020bit
                xor     al,80h
                mov     cs:C020bit,al
                push    dx
                mov     dx,378h
                out     dx,al
                pop     dx
                mov     bl,ch
                jmp     di
C020w:          call    synchronize
                mov     al,cs:C020bit
                xor     al,80h
                mov     cs:C020bit,al
                push    dx
                mov     dx,378h
                out     dx,al
                pop     dx
                sahf
                DoNext
C020bit         db      0

ResetSpeaker    Proc    far
                in      al,61h
                and     al,11111100b
                out     61h,al
                mov     cs:C020bit,0
                ret
ResetSpeaker    Endp
                CheckAddress

;-------------- Digital Outputs emulation entries & subroutines ----------------

                UseNextFreeSpace
C05Or:          call    synchronize
                mov     bl,al
                and     bx,111b
                mov     al,PPortBuffer
                and     al,DOmasks[bx]
                or      al,DOvalues[bx]
                mov     PPortBuffer,al
                mov     bx,dx
                mov     dx,PPortBase
                out     dx,al
                mov     dx,bx
                mov     bl,ch
                jmp     di
C05Ow:          call    synchronize
                mov     bl,al
                and     bx,111b
                mov     al,PPortBuffer
                and     al,DOmasks[bx]
                or      al,DOvalues[bx]
                mov     PPortBuffer,al
                mov     bx,dx
                mov     dx,PPortBase
                out     dx,al
                mov     dx,bx
                mov     bl,ch
                sahf
                DoNext

DOmasks         db      11111110b,11111110b,11111101b,11111101b
                db      11111011b,11111011b,11110111b,11110111b
DOvalues        db      0000b,0001b,0000b,0010b,0000b,0100b,0000b,1000b

ResetDigOutputs Proc    far
                mov     al,PPortBuffer
                and     al,11110000b
                mov     PPortBuffer,al
                mov     dx,PPortBase
                out     dx,al
                ret
ResetDigOutputs Endp

                even
PPortBase       dw      3BCh
PPortBuffer     db      00001111b               ; 0 - Inputs, 1 - Outputs
                CheckAddress

;-------------- Joystick emulation entries & subroutines -----------------------

                UseNextFreeSpace

C061r:          mov     al,cs:JoyButton1
                mov     bl,ch
                jmp     di

C062r:          mov     al,cs:JoyButton2
                mov     bl,ch
                jmp     di

JoyButton1      db      7Fh
JoyButton2      db      7Fh
joy_pos1        dw      0
joy_pos2        dw      0
JoyStick        db      0
JoyEnd          label   word
JoyEx           db      0
JoyEy           db      0
Joy_Table       dw      1400,0,2800,1400

C064r:          mov     ebx,eax
                sub     ebx,cs:C07X_eax
                shr     ebx,16
                cmp     bx,cs:joy_pos1
                mov     al,0FEh
                rcr     al,1
                xchg    al,cs:JoyEx
                or      al,cs:JoyEx
                mov     bl,ch
                jmp     di

C065r:          mov     ebx,eax
                sub     ebx,cs:C07X_eax
                shr     ebx,16
                cmp     bx,cs:joy_pos2
                mov     al,0FEh
                rcr     al,1
                xchg    al,cs:JoyEy
                or      al,cs:JoyEy
                mov     bl,ch
                jmp     di

                CheckAddress
                UseNextFreeSpace

C07Xr:          mov     cs:C07X_eax,eax
                xor     bx,bx
                mov     cs:JoyEnd,bx
                mov     bl,cs:JoyStick
                shl     bl,1
                and     bl,6
                mov     ax,cs:Joy_Table[bx]
                mov     cs:joy_pos1,ax
                mov     bl,cs:JoyStick
                shr     bl,1
                and     bl,6
                mov     ax,cs:Joy_Table[bx]
                mov     cs:joy_pos2,ax
                mov     al,0FFh
                mov     bl,ch
                jmp     di

C0612r:         mov     al,7Fh
                mov     bl,ch
                jmp     di

C0645r:         mov     al,0FFh
                mov     bl,ch
                jmp     di

C07X_eax        dd      0

C061w:
C062w:
C07Xw:          sahf
                DoNext

                CheckAddress

;-------------- N/A entries & subroutines --------------------------------------

                UseNextFreeSpace
C0NAr:          mov     bl,ch
                jmp     di
C0NAw:          sahf
                DoNext
                CheckAddress

;-------------- Synchronization Subroutines ------------- MacroSoft & IvoSoft---

                UseNextFreeSpace
; Entry:
;   EAH - 65C02 clocks sinse last call to synchronize
synchronize     proc    near
synchro_push_ax label   byte
                cli
                push    ax bx cx dx
                lahf
                push    ax
                mov     ebx,eax
                sub     eax,cs:old_eax
                mov     al,00000100b            ; 00000110b
                out     43h,al
                jmp     $+2
                shr     eax,16                  ; 10
                mul     cs:O75
                shr     eax,6                   ; 12
                mov     bx,ax                   ; 65C02 clocks in timer ticks
                in      al,40h
                jmp     $+2
                jmp     $+2
                jmp     $+2
                mov     ah,al
                in      al,40h
                jmp     $+2
                jmp     $+2
                jmp     $+2
                xchg    al,ah
                mov     cx,cs:old_timer
                sub     cx,ax                   ; cx-time passed since last call
                sub     bx,cx                   ; bx-time to wait
                jbe     synch_xit               ; don't wait
                sub     cx,bx
synch_loop:
                mov     cx,ax
                mov     al,00000100b
                cli
                out     43h,al
                jmp     $+2
                jmp     $+2
                jmp     $+2
                in      al,40h
                jmp     $+2
                jmp     $+2
                jmp     $+2
                mov     ah,al
                in      al,40h
                sti
                xchg    al,ah
                sub     cx,ax
                sub     bx,cx
                jnb     synch_loop
                cli
synch_xit:
                mov     cs:old_timer,ax
                mov     cs:old_eax,ebx
                mov     eax,ebx
                pop     ax
                sahf
                pop     dx cx bx ax
                sti
                ret
old_timer       dw      0
O75             dd      75
old_eax         dd      0
synchronize     endp
                CheckAddress

;-------------- Include peripheral devices emulation files ---------------------

                include Video.ASM
                include DRAM.INC
                include Floppy.INC
                include PhisFlop.INC

Emulate         ends

;-------------------------------------------------------------------------------

Peripher        segment public
                assume  CS:Peripher,DS:Nothing,ES:Nothing

OldTimer        dd      0

TimerINIT       Proc    near
                mov     ax,3508h
                int     21h
                mov     word ptr OldTimer,bx
                mov     word ptr OldTimer+2,es
                push    cs
                pop     ds
                mov     dx,offset TimerCntr
                mov     ax,2508h
                int     21h
                ret
TimerINIT       Endp

TimerTINI       Proc    near
                lds     dx,OldTimer
                mov     ax,2508h
                int     21h
                ret
TimerTINI       Endp

		even
Tcounters       dw      Tlen dup (0)
Tadrs           dd      Tlen dup (0)

TimerReq        Proc    far                     ; CX:DX-Proc address, AX-Count
                Save    bx
                pushf
                cli
                xor     bx,bx
TimerReq10:     cmp     word ptr Tadrs[BX],dx
                jne     TimerReq20
                cmp     word ptr Tadrs[BX]+2,cx
                je      TimerReq50
TimerReq20:     add     bx,4
                cmp     bx,Tlen*4
                jb      TimerReq10
                xor     bx,bx
TimerReq30:     cmp     Tcounters[BX],0
                je      TimerReq40
                add     bx,2
                cmp     bx,Tlen*2
                jb      TimerReq30
                jmp     TimerReqExit            ; ERROR: Tlen must be increased
TimerReq40:     shl     bx,1
                mov     word ptr Tadrs[BX],dx
                mov     word ptr Tadrs[BX]+2,cx
TimerReq50:     shr     bx,1
                mov     Tcounters[BX],ax
TimerReqExit:   popf
                Restore bx
                ret
TimerReq        Endp

TimerCntr       Proc    far
                Save    ax bx
                cli
                xor     ax,ax
                mov     bx,ax
TimerCntr10:    cmp     Tcounters[bx],0
                je      TimerCntr20
                inc     ax
                dec     Tcounters[bx]
                jnz     TimerCntr20
                SaveAll
                shl     bx,1
                call    Tadrs[bx]
                RestoreAll
TimerCntr20:    add     bx,2
                cmp     bx,Tlen*2
                jb      TimerCntr10
                or      ax,ax
comment         %
                mov     al,20h
                out     20h,al
                %
                jnz     TimerCntr30
comment         %
                in      al,21h
                or      al,00000001b
                out     21h,al
                %
TimerCntr30:    xchg    bp,sp
                xor     ax,ax
                xchg    ax,cs:TimerFlags
                or      [bp+8],ax
                xchg    sp,bp
                Restore ax bx
                jmp     cs:[OldTimer]
;               iret
TimerFlags      dw      0
TimerCntr       Endp



SystemINIT      Proc    far
                mov     al,00001100b
                mov     dx,3F2h
                out     dx,al
                mov     al,IRQmasks
                out     21h,al
                call    TimerINIT
                call    FloppyINIT
                call    PhisFloppyINIT
                ret
SystemINIT      Endp


SystemTINI      Proc    far
                call    PhisFloppyTINI
                call    FloppyTINI
                call    TimerTINI
                mov     al,0
                out     21h,al
                ret
SystemTINI      Endp


SystemRESET     Proc    far                     ; Registers state:
                call    ResetDRAM               ; SS -> Data
                call    ResetKeyboard           ; IF = 0
                call    ResetSpeaker            ; All others are unknown
                call    ResetDigOutputs         ; and may be modified.
                call    ResetVideo
                call    ResetFloppy
                call    ResetPhisFloppy
                ret
SystemRESET     Endp

Peripher        ends

;===============================================================================

Data            segment stack 'stack'
		even
C0xxRead        dw      10h dup ( C000r )
                dw      10h dup ( C010r )
                dw      10h dup ( C020r )               ; C020
                dw      10h dup ( C030r )
                dw      10h dup ( C0NAr )               ; C040
                dw      C050r, C051r
                dw      C052r, C053r
                dw      C054r, C055r
                dw      C056r, C057r
                dw      8 dup ( C05Or )
                dw      C0NAr,C0612r,C0612r,C0NAr       ; C060
                dw      C0645r,C0645r
                dw      2 dup ( C0NAr )
                dw      4 dup ( C0NAr )
                dw      4 dup ( C0NAr )
                dw      10h dup ( C07Xr )               ; C070
                dw      10h dup ( C08Xr )
                dw      10h dup ( C0NAr )               ; C090
                dw      10h dup ( C0NAr )               ; C0A0
                dw      10h dup ( C0NAr )               ; C0B0
                dw      10h dup ( C0NAr )               ; C0C0
                dw      10h dup ( C0NAr )               ; C0D0
                dw      C0E0r,C0E1r,C0E2r,C0E3r,C0E4r,C0E5r,C0E6r,C0E7r
                dw      C0E8r,C0E9r,C0EAr,C0EBr,C0ECr,C0EDr,C0EEr,C0EFr
                dw      10h dup ( C0NAr )               ; C0F0

C0xxWrite       dw      10h dup ( C000w )
                dw      10h dup ( C010w )
                dw      10h dup ( C020w )               ; C020
                dw      10h dup ( C030w )
                dw      10h dup ( C0NAw )               ; C040
                dw      C050w, C051w                    ; C050
                dw      C052w, C053w
                dw      C054w, C055w
                dw      C056w, C057w
                dw      8 dup ( C05Ow )
                dw      C0NAw,C061w,C062w,C0NAw         ; C060
                dw      4 dup ( C0NAw )
                dw      4 dup ( C0NAw )
                dw      4 dup ( C0NAw )
                dw      10h dup ( C07Xw )               ; C070
                dw      10h dup ( C08Xw )               ; C080
                dw      10h dup ( C0NAw )               ; C090
                dw      10h dup ( C0NAw )               ; C0A0
                dw      10h dup ( C0NAw )               ; C0B0
                dw      10h dup ( C0NAw )               ; C0C0
                dw      10h dup ( C0NAw )               ; C0D0
                dw      C0E0w,C0E1w,C0E2w,C0E3w,C0E4w,C0E5w,C0E6w,C0E7w
                dw      C0E8w,C0E9w,C0EAw,C0EBw,C0ECw,C0EDw,C0EEw,C0EFw
                dw      10h dup ( C0NAw )               ; C0F0

Data            ends

                End

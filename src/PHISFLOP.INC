;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      PHISFLOP.ASM                    |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Phisical Floppy Emulation       |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

;       This file is included in EMULATE.ASM

;-------------- Phisical Floppy emulation entries ------------------------------

                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

                UseNextFreeSpace
C0D0r:
C0D1r:
C0D2r:
C0D3r:
C0D4r:
C0D5r:
C0D6r:
C0D7r:          push    cs
                push    di
                jmp     ChangePhase
C0D0w:
C0D1w:
C0D2w:
C0D3w:
C0D4w:
C0D5w:
C0D6w:
C0D7w:          Save    ax
                call    ChangePhase
                Restore ax
                sahf
                DoNext

C0D8r:          push    cs
                push    di
                jmp     MotorOFF
C0D8w:          Save    ax
                call    MotorOFF
                Restore ax
                sahf
                DoNext

C0D9r:          push    cs
                push    di
                jmp     MotorON
C0D9w:          Save    ax
                call    MotorON
                Restore ax
                sahf
                DoNext

C0DAr:
C0DBr:          push    cs
                push    di
                jmp     ChangeDrive
C0DAw:
C0DBw:          Save    ax
                call    ChangeDrive
                Restore ax
                sahf
                DoNext
                CheckAddress

                UseNextFreeSpace
C0DCr:          push    cs
                push    di
                jmp     StrobeData
C0DCw:          Save    ax
                call    StrobeData
                Restore ax
                sahf
                DoNext

C0DDr:          mov     al,0FFh
                mov     bl,ch
                jmp     di
C0DDw:          Save    ax
                mov     al,bh
                call    LatchData
                Restore ax
                sahf
                DoNext

C0DEr:          push    cs
                push    di
                call    PF_ReadMode
                jmp     ReadWProtSwitch
C0DEw:          Save    ax
                call    PF_ReadMode
                Restore ax
                sahf
                DoNext

C0DFr:          push    di
                call    PF_WriteMode
                mov     al,0FFh
                ret
C0DFw:          Save    ax
                call    PF_WriteMode
                Restore ax
                sahf
                DoNext
                CheckAddress

;-------------- Phisical Floppy emulation subroutines --------------------------

Peripher        segment public
                assume  CS:Peripher,DS:Nothing,ES:Nothing

PF_Flags        db      00000000b
                even
PF_BufferPtr    dw      0                       ; Byte pointer in the R/W buffer
WriteLatch      db      0                       ; Write Latch register
                even
PPort??8        dw      378h
PPort??A        dw      37Ah


PhisFloppyINIT  Proc    near
                mov     dx,PPort??8
                mov     al,01100000b
                out     dx,al
                ret
PhisFloppyINIT  Endp

PhisFloppyTINI  Proc    near
                mov     dx,PPort??8
                mov     al,01100000b
                out     dx,al
                ret
PhisFloppyTINI  Endp

ResetPhisFloppy Proc    near
                call    PF_ReadMode
                mov     al,0
                call    ChangeDrive
                call    MotorOFF
                ret
ResetPhisFloppy Endp

                even
MotorON         Proc    far
                Save    cx,dx
                mov     cx,seg MotorOFF_C
                mov     dx,offset MotorOFF_C
                xor     ax,ax
                call    TimerReq
                or      PF_Flags,00000011b
                test    PF_Flags,10000000b
                jnz     MotorON10
                mov     dx,PPort??8
                in      al,dx
                and     al,10111111b
                out     dx,al
MotorON10:      Restore cx,dx
                mov     bl,ch
                ret
MotorON         Endp

                even
MotorOFF        Proc    far
                test    PF_Flags,00000010b
                jz      MotorOFF10
                and     PF_Flags,11111101b
                Save    cx,dx
                mov     cx,seg MotorOFF_C
                mov     dx,offset MotorOFF_C
                mov     ax,MotorOffDelay
                call    TimerReq
                Restore cx,dx
MotorOFF10:     mov     bl,ch
                ret
MotorOFF_C:     call    PF_FlushBuffer
                and     PF_Flags,11111100b
                mov     bx,dx
                mov     dx,PPort??8
                in      al,dx
                or      al,01000000b
                out     dx,al
                mov     dx,bx
                mov     bl,ch
                ret
MotorOFF        Endp

                even
ChangeDrive     Proc    far
                ror     al,1
                xor     al,PF_Flags
                jns     ChangeDrive10
                xor     PF_Flags,10000000b
                test    PF_Flags,00000001b
                jz      ChangeDrive10
                mov     bx,dx
                mov     dx,PPort??8
                in      al,dx
                xor     al,01000000b
                out     dx,al
                mov     dx,bx
ChangeDrive10:  mov     bl,ch
                ret
ChangeDrive     Endp

                even
ChangePhase     Proc    far
                call    PF_FlushBuffer
                and     ax,111b
                mov     bx,ax
                Save    dx
                mov     dx,PPort??8
                in      al,dx
                and     al,ChangePhase_and[BX]
                or      al,ChangePhase_or [BX]
                out     dx,al
                Restore dx
                mov     bl,ch
                ret
ChangePhase_and db      11111101b,11111111b,11111011b,11111111b,11110111b,11111111b,11101111b,11111111b
ChangePhase_or  db      00000000b,00000010b,00000000b,00000100b,00000000b,00001000b,00000000b,00010000b
ChangePhase     Endp

                even
PF_ReadMode     Proc    far
                and     PF_Flags,10111111b
                mov     bx,PF_BufferPtr
                add     bx,ReadAdd
                cmp     bx,TrackBufferLen
                jb      PF_ReadMode10
                sub     bx,TrackBufferLen
PF_ReadMode10:  mov     PF_BufferPtr,bx
                mov     WriteCNT,0
                mov     bl,ch
                ret
PF_ReadMode     Endp

                even
PF_WriteMode    Proc    far
                or      PF_Flags,01000000b
                mov     bx,PF_BufferPtr
                add     bx,WriteAdd
                cmp     bx,TrackBufferLen
                jb      PF_WriteMode10
                sub     bx,TrackBufferLen
PF_WriteMode10: mov     PF_BufferPtr,bx
                test    PF_Flags,00000100b
                jnz     PF_WriteMode20
                mov     PF_BufferPtr,0
                or      PF_Flags,00010100b
PF_WriteMode20: or      PF_Flags,00001000b
                mov     bl,ch
                ret
PF_WriteMode    Endp

                even
StrobeData      Proc    far
                mov     ah,PF_Flags
                test    ah,01000000b
                jnz     StrobeData40
                test    ah,00000100b
                jnz     StrobeData10
                call    PF_LoadBuffer
                mov     PF_BufferPtr,0
                mov     ah,PF_Flags
StrobeData10:   mov     bx,PF_BufferPtr
                mov     al,PF_TrackBuffer[bx]
                test    ah,00000001b
                jz      StrobeData30
                inc     bx
                cmp     bx,TrackBufferLen
                jb      StrobeData20
                xor     bx,bx
                and     PF_Flags,11111011b
StrobeData20:   mov     PF_BufferPtr,bx
StrobeData30:   mov     bl,ch
                ret
StrobeData40:   test    ah,00000001b
                jz      StrobeData60
                mov     bx,PF_BufferPtr
                mov     al,WriteLatch
                mov     PF_TrackBuffer[bx],al
                inc     bx
                cmp     bx,TrackBufferLen
                jb      StrobeData50
                xor     bx,bx
StrobeData50:   mov     PF_BufferPtr,bx
                mov     bx,WriteCNT
                inc     bx
                mov     WriteCNT,bx
                cmp     bx,FormatLimit
                jb      StrobeData60
                or      PF_Flags,00010000b
StrobeData60:   mov     bl,ch
                ret
StrobeData      Endp

                even
LatchData       Proc    far
                mov     WriteLatch,al
                mov     bl,ch
                ret
LatchData       Endp

                even
ReadWProtSwitch Proc    far
                mov     bx,dx
                mov     dx,PPort??A
                in      al,dx
                mov     dx,bx
                shr     al,1
                sbb     al,al
                mov     bl,ch
                ret
ReadWProtSwitch Endp


TimerPort       =       40h
TimerStep       =       3818                    ; round((4*8*1.19318)*100h)
MaxWaitCount    =       100
TimerCounter    dw      0
WaitCount       dw      23

PF_LoadBuffer   Proc    near                    ; Saves all registers
                SaveAll
                pushf
                cli
                cld
                mov     ax,Apple
                mov     ds,ax
                xor     ax,ax
                mov     al,DS:[0C0DDh]
                mov     WaitCount,ax
                mov     ax,cs
                mov     ds,ax
                mov     es,ax
                mov     di,offset PF_TrackBuffer
                mov     dx,PPort??8
                mov     al,14h
                out     43h,al
                xor     ax,ax
                out     TimerPort,al
                mov     TimerCounter,ax
@@05:           Save    di
                mov     bx,7
@@10:           in      al,dx
                or      al,al
                jns     @@10
                jmp     @@15
@@15:           mov     di,offset StosBuffer
                mov     cx,WaitCount
        rep     stosb
@@20:           in      al,dx
                shl     ax,1
                dec     bx
                jnz     @@15
                Restore di
                mov     al,ah
                or      al,80h
                stosb
                cmp     di,offset PF_TrackBuffer+TrackBufferLen
                jb      @@05
                popf
                RestoreAll
                or      PF_Flags,00000100b
                and     PF_Flags,11100111b
                ret
PF_LoadBuffer   Endp

PF_FlushBuffer  Proc    near                    ; Saves all registers
                test    PF_Flags,00011000b
                jz      PF_FBExit

;               Write   Track

PF_FBExit:      and     PF_Flags,11111011b
                ret
PF_FlushBuffer  Endp


PF_TrackBuffer  db      TrackBufferLen dup(0)
StosBuffer      db      MaxWaitCount dup(0)

Peripher        Ends

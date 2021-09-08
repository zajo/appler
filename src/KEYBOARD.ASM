;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      KEYBOARD.ASM                    |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Keyboard Manager                |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC

Keyboards       group   Keyboard,SimKbd
Keyboard        segment public
                assume  cs:Keyboard, ds:Keyboard, es:Emulate, ss:Data


DATA_PORT       =       60h
COMMAND_PORT    =       64h
OUTPUT_FULL     =       01h             ; Output buffer full flag bit
INPUT_EMPTY     =       02h             ; Input buffer empty flag bit
DISABLE_KEYBOARD=       0ADh            ; Disable keyboard command code
ENABLE_KEYBOARD =       0AEh            ; Enable keyboard command code
LED_SET         =       0EDh            ; Set keyboard LEDs command code
ACKNOWLEDGE     =       0FAh            ; Keyboard ACK
TIME_OUT        =       0FFFFh          ; 8042 time out counter value

K_KeyboardRet1  label   byte
SetLEDs         proc    far                     ; AL - LED data
                push    ax
                mov     al,DISABLE_KEYBOARD
                call    K_SendCommand
                jc      SetLEDs_Exit
                mov     al,LED_SET
                call    K_SendData
                jc      SetLEDs_Exit
                pop     ax
                push    ax
                call    K_SendData
SetLEDs_Exit:   mov     al,ENABLE_KEYBOARD
                out     COMMAND_PORT,al
                pop     ax
                ret
SetLEDs         endp
LightsData      db      0

K_KeyboardRet2  label   byte
K_SendCommand   proc    far
                push    ax
                call    WaitInputEmpty
                jc      K_SC_Ret
                out     COMMAND_PORT,al
                call    WaitOutputFull
                jc      K_SC_Ret
                in      al,DATA_PORT
                call    WaitInputEmpty
K_SC_Ret:       pop     ax
                ret
K_SendCommand   endp

K_KeyboardRet3  label   byte
K_SendData      proc    far
                push    ax
                call    WaitInputEmpty
                jc      K_SD_Ret
                out     DATA_PORT,al
                call    WaitOutputFull
                jc      K_SD_Ret
                in      al,DATA_PORT
                call    WaitInputEmpty
K_SD_Ret:       pop     ax
                ret
K_SendData      endp

K_KeyboardRet4  label   byte
K_GetData       proc    far
                in      al,DATA_PORT
                call    WaitInputEmpty
                ret
K_GetData       endp

WaitInputEmpty  proc    near
                push    ax cx
                mov     cx,TIME_OUT
WIE_Loop:       in      al,COMMAND_PORT
                test    al,INPUT_EMPTY
                jz      WIE_Exit
                loop    WIE_Loop
                stc
WIE_Exit:       pop     cx ax
                ret
WaitInputEmpty  endp

WaitOutputFull  proc    near
                push    ax cx
                mov     cx,TIME_OUT
WOF_Loop:       in      al,COMMAND_PORT
                test    al,OUTPUT_FULL
                jz      WOF_Exit
                loop    WOF_Loop
                stc
WOF_Exit:       pop     cx ax
                ret
WaitOutputFull  endp


k_BufferFlag    db      0
k_BuffPtr1      db      0
k_BuffPtr2      db      0
k_Buffer        db      64 dup (?)

ClearBuffer     proc    far
                mov     cs:k_BuffPtr1,0
                mov     cs:k_BuffPtr2,0
                ret
ClearBuffer     endp

PutBuffer       proc    near
                test    C000,10000000b
                jz      k_NoBuff
                test    k_BufferFlag,1
                jz      k_NoBuff
                xor     bx,bx
                mov     bl,k_BuffPtr2
                mov     k_Buffer[bx],al
                inc     bl
                cmp     bl,size k_Buffer
                jb      PB_1
                xor     bx,bx
PB_1:           cmp     bl,k_BuffPtr1
                je      PB_Ret
                mov     k_BuffPtr2,bl
                jmp     PB_Ret
k_NoBuff:       mov     C000,al
PB_Ret:         ret
PutBuffer       endp

GetBuffer       proc    far
                pushf
                push    ax bx ds es
                push    cs
                pop     ds
                cmp     k_BufferFlag,0
                jz      GB_Ret
                mov     ax,Emulate
                mov     es,ax
                xor     bx,bx
                mov     bl,k_BuffPtr1
                mov     al,k_Buffer[bx]
                cmp     bl,k_BuffPtr2
                je      GB_Ret
                inc     bl
                cmp     bl,size k_Buffer
                jb      GB_1
                xor     bx,bx
GB_1:           mov     k_BuffPtr1,bl
                mov     [C000],al
GB_Ret:         pop     es ds bx ax
                popf
                ret
GetBuffer       endp

get_table_ofs   proc    far
                push    ax
                mov     al,bl
                xor     bx,bx
                test    al,M_ALT
                mov     bl,2 shl 1
                jnz     gto_ModeOK
                test    al,M_CTRL
                mov     bl,1 shl 1
                jnz     gto_ModeOK
                test    al,M_CAPS_LOCK
                jz      gto_not_caps
                test    al,M_LEFT_SHIFT or M_RIGHT_SHIFT
                mov     bl,4 shl 1
                jnz     gto_ModeOK
                mov     bl,3 shl 1
                jmp     gto_ModeOK
gto_not_caps:   test    al,M_LEFT_SHIFT or M_RIGHT_SHIFT
                mov     bl,5 shl 1
                jnz     gto_ModeOK
                test    al,M_NUM_LOCK
                mov     bl,6 shl 1
                jnz     gto_ModeOK
                xor     bx,bx
gto_ModeOK:     pop     ax
                ret
get_table_ofs   endp

k_Fire1         =       80h
k_Fire2         =       81h
k_LeftArrow     =       82h
k_RightArrow    =       83h
k_UpArrow       =       84h
k_DownArrow     =       85h
None            =       86h
Ctrl            =       87h
Lshift          =       88h
Rshift          =       89h
Caps            =       8Ah
ALT             =       8Bh
k_Reset         =       8Ch
k_Pause         =       8Dh
k_F1            =       8Eh
k_F2            =       8Fh
k_F3            =       90h
k_F4            =       91h
k_F5            =       92h
k_F6            =       93h
k_F7            =       94h
k_F8            =       95h
k_F9            =       96h
k_F10           =       97h
k_DosShell      =       98h
k_QuitAppler    =       99h
k_F11           =       9Ah
k_F12           =       9Bh
k_NumLock       =       9Ch

k_KeyPressed    db      1
k_Flags         dw      0
k_KeyCode       db      0
k_ScanCode      db      0
k_Shifts        dw      0
k_Table         dw      k_AppleTable
k_AppleTable    dw      a_NormalTable           ; Normal table
                dw      a_CtrlTable             ; Ctrl pressed
                dw      a_AltTable              ; Ctrl and Alt pressed
                dw      a_CapsTable             ; Caps Lock mode
                dw      a_CpsShfTable           ; Shift in Caps Lock mode
                dw      a_ShiftTable            ; Shift mode
                dw      a_NumTable              ; Num Lock mode
k_DebugTable    dw      d_NormalTable
                dw      d_NormalTable
                dw      d_AltTable
                dw      d_CapsTable
                dw      d_CpsShfTable
                dw      d_ShiftTable
                dw      d_NormalTable
k_KbdSetupTable dw      k_NormalTable
                dw      k_NormalTable
                dw      k_AltTable
                dw      k_NormalTable
                dw      k_NormalTable
                dw      k_NormalTable
                dw      k_NormalTable


k_int09:        push    ax
                in      al,DATA_PORT
                push    ax
                in      al,61h
                or      al,11000000b
                jmp     $+2
                out     61h,al
                and     al,01111111b
                jmp     $+2
                out     61h,al
                mov     al,20h
                out     20h,al
                pop     ax
                call    far ptr KeyStopPlay
                xchg    sp,bp
                or      [bp+6],ax
                xchg    sp,bp
k_int09_iret:   pop     ax
                iret

KeyStopPlay:    or      al,al
                js      Key
                call    SimKbdClr
Key:            push    bx si ds es
                push    cs
                pop     ds
                mov     k_Flags,0
                test    k_PauseFlag,1
                jnz     k_KeyPause
                mov     bx,Emulate
                mov     es,bx
                mov     ah,al
                xor     bx,bx
                mov     bl,ah
                and     bl,01111111b
                cmp     bl,58h
                ja      k_ret
                mov     al,bl
                mov     bx,k_Shifts
                call    get_table_ofs
                mov     si,k_Table
                mov     bx,[si][bx]
                xlat
                mov     k_KeyCode,al
                or      al,al
                js      k_SpecialKey
                or      ah,ah
                js      k_ret
                or      al,10000000b
                call    PutBuffer
k_record_ret:   mov     al,ah
                call    RecordKey
k_ret:          and     ah,01111111b
                mov     k_ScanCode,ah
                mov     ax,k_Flags
                pop     es ds si bx
                retf

k_KeyPause:     or      al,al
                js      k_ret
                mov     k_PauseFlag,0
                jmp     k_ret

k_SpecialKey:   cmp     ah,k_OldSpcKey
                je      k_ret
                push    ax
                and     al,01111111b
                or      ah,ah
                mov     si,offset k_KeyOnSub
                jns     k_SK_on
                mov     si,offset k_KeyOffSub
                xor     ah,ah
k_SK_on:        mov     k_OldSpcKey,ah
                xor     bh,bh
                mov     bl,al
                shl     bx,1
                mov     ax,k_Shifts
                call    [si][bx]
                mov     k_Shifts,ax
                mov     k_KeyPressed,1
                pop     ax
                jmp     k_record_ret
k_OldSpcKey     db      0
k_KeyOnSub      dw      k_Fire1_ON,k_Fire2_ON,k_LA_ON,k_RA_ON,k_UA_ON,k_DA_ON
                dw      k_None
                dw      k_Ctrl_ON,k_Lshift_ON,k_Rshift_ON,k_Caps_ON,k_ALT_ON
                dw      k_Reset_ON,k_Pause_ON
                dw      k_F_ON,k_F_ON,k_F_ON,k_F_ON,k_F_ON,k_F_ON,k_F_ON,k_F_ON,k_F_ON,k_F_ON
                dw      k_F_ON,k_F_ON
                dw      k_None,k_F12_ON,k_Num_ON
k_KeyOffSub     dw      k_Fire1_OFF,k_Fire2_OFF,k_LA_OFF,k_RA_OFF,k_UA_OFF,k_DA_OFF
                dw      k_None
                dw      k_Ctrl_OFF,k_Lshift_OFF,k_Rshift_OFF,k_Caps_OFF,k_ALT_OFF
                dw      k_Reset_OFF,k_None
                dw      k_None,k_None,k_None,k_None,k_None,k_None,k_None,k_None,k_None,k_None
                dw      k_None,k_None
                dw      k_None,k_None,k_Num_OFF

k_Ctrl_OFF:     and     al,not M_CTRL
k_None:         ret
k_Lshift_OFF:   and     al,not M_LEFT_SHIFT
                ret
k_Rshift_OFF:   and     al,not M_RIGHT_SHIFT
k_Caps_OFF:     ret
k_ALT_OFF:      and     al,not M_ALT
                ret
k_Reset_OFF:    and     ResetFlag,11111110b
                mov     C000,0
                ret
k_Fire1_OFF:    mov     es:JoyButton1,7Fh
                ret
k_Fire2_OFF:    mov     es:JoyButton2,7Fh
                ret
k_LA_OFF:       and     es:JoyStick,not 00000001b
                ret
k_RA_OFF:       and     es:JoyStick,not 00000010b
                ret
k_UA_OFF:       and     es:JoyStick,not 00000100b
                ret
k_DA_OFF:       and     es:JoyStick,not 00001000b
                ret

k_Ctrl_ON:      or      al,M_CTRL
                ret
k_Lshift_ON:    cmp     k_ScanCode,060h
                je      k_Lshift_ON_ret
                or      al,M_LEFT_SHIFT
k_Lshift_ON_ret:ret
k_Rshift_ON:    cmp     k_ScanCode,060h
                je      k_Rshift_ON_ret
                or      al,M_RIGHT_SHIFT
k_Rshift_ON_ret:ret
k_Caps_ON:      xor     al,M_CAPS_LOCK
                push    ax
                xor     LightsData,00000100b
                mov     al,LightsData
                call    SetLEDs
                pop     ax
                ret
k_ALT_ON:       or      al,M_ALT
                ret
k_Num_ON:       xor     al,M_NUM_LOCK
                push    ax
                xor     LightsData,00000010b
                mov     al,LightsData
                call    SetLEDs
                test    al,00000010b
                mov     ss:C0xxRead[2*61h], offset C0612r
                mov     ss:C0xxRead[2*62h], offset C0612r
                mov     ss:C0xxRead[2*64h], offset C0645r
                mov     ss:C0xxRead[2*65h], offset C0645r
                jz      k_Num_ON1
                mov     ss:C0xxRead[2*61h], offset C061r
                mov     ss:C0xxRead[2*62h], offset C062r
                mov     ss:C0xxRead[2*64h], offset C064r
                mov     ss:C0xxRead[2*65h], offset C065r
                mov     es:JoyStick,0
k_Num_ON1:      pop     ax
k_Num_OFF:      ret
k_Fire1_ON:     mov     es:JoyButton1,0FFh
                ret
k_Fire2_ON:     mov     es:JoyButton2,0FFh
                ret
k_LA_ON:        or      es:JoyStick,00000001b
                ret
k_RA_ON:        or      es:JoyStick,00000010b
                ret
k_UA_ON:        or      es:JoyStick,00000100b
                ret
k_DA_ON:        or      es:JoyStick,00001000b
                ret
k_Reset_ON:     test    al,M_CTRL
                jz      k_Reset_ON_J
                test    ResetFlag,00000001b
                jnz     k_Reset_ON_J
                or      ResetFlag,00000001b
                jmp     RESET
k_Reset_ON_J:   ret

k_PauseFlag     db      0
k_OldIRQ        db      ?
k_Pause_ON:     push    ax
                in      al,21h
                mov     k_OldIRQ,al
                mov     al,11111101b
                out     21h,al
                mov     k_PauseFlag,1
                mov     al,00000111b
                call    SetLEDs
                sti
k_PauseLoop:    test    k_PauseFlag,1
                jnz     k_PauseLoop
                cli
                mov     al,k_OldIRQ
                out     21h,al
                mov     al,LightsData
                call    SetLEDs
                pop     ax
                and     al,not M_CTRL
                ret

k_ProcessIDs    db      PID_DEBUGGER
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

k_F_ON:         push    es
                mov     ax,seg RetWhere?
                mov     es,ax
                assume  es:seg RetWhere?
                shr     bx,1
                sub     bl,k_F1 and 01111111b
                mov     al,k_ProcessIDs[bx]
                mov     k_OldSpcKey,0
                mov     es:RetWhere?,al
                or      word ptr k_Flags,0000000100000000b
                pop     es
                mov     ax,k_Shifts
                and     al,not(M_CTRL or M_LEFT_SHIFT or M_RIGHT_SHIFT or M_ALT)
                ret
                assume  es:Emulate

k_F12_ON:       xor     es:synchro_push_ax,0FAh xor 0C3h
                ret


a_NormalTable   db      None,1Bh,'1234567890-=',8                 ; Normal Table
                db      9,'QWERTYUIOP[]',0Dh
                db      Ctrl,'ASDFGHJKL;',27h,'`'
                db      LShift,'\ZXCVBNM,./',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_NumLock,k_Reset,None,0Bh,None,'-'
                db      8,None,15h,'+',None,0Ah,None,9,4
                db      None,None,None,None,k_F12

a_CtrlTable     db      None,1Bh,'1234567890-=',8                 ; CtrlTable
                db      9,11h,17h,5,12h,14h,19h,15h,9,0Fh,10h,1Bh,1Dh,0Dh
                db      Ctrl,1,13h,4,6,7,8,0Ah,0Bh,0Ch,';',27h,1Eh
                db      LShift,0,1Ah,18h,3,16h,2,0Eh,0Dh,',./',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_Pause,k_Reset,None,0Bh,None,'-'
                db      8,None,15h,'+',None,0Ah,None,9,4
                db      None,None,None,None,k_F12

a_ShiftTable    db      None,1Bh,'!@#$%^&*()_+',15h               ; ShiftTable
                db      9,'qwertyuiop{}',0Dh
                db      Ctrl,'asdfghjkl:"~'
                db      LShift,'|zxcvbnm<>?',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_NumLock,k_Reset,'789-456+1230.'
                db      None,None,None,None,k_F12

a_CapsTable     db      None,1Bh,'1234567890-=',8                 ; CapsTable
                db      9,'qwertyuiop[]',0Dh
                db      Ctrl,'asdfghjkl;',27h,'`'
                db      LShift,'\zxcvbnm,./',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_NumLock,k_Reset,None,0Bh,None,'-'
                db      8,None,15h,'+',None,0Ah,None,9,4
                db      None,None,None,None,k_F12

a_CpsShfTable   db      None,1Bh,'!@#$%^&*()_+',15h               ; CpsShfTable
                db      9,'QWERTYUIOP[]',0Dh
                db      Ctrl,'ASDFGHJKL:"~'
                db      LShift,'|ZXCVBNM,./',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_NumLock,k_Reset,'789-456+1230.'
                db      None,None,None,None,k_F12

a_AltTable      db      None,1Bh,'1234567890-=',8 ; AltTable
                db      9,11h,17h,5,12h,14h,19h,15h,9,0Fh,10h,1Bh,1Dh,0Dh
                db      Ctrl,1,13h,k_DosShell,6,7,8,0Ah,0Bh,0Ch,';',27h,1Eh
                db      LShift,0,1Ah,k_QuitAppler,3,16h,2,0Eh,0Dh,',./',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_NumLock,k_Reset,None,0Bh,None,'-'
                db      8,None,15h,'+',None,0Ah,None,9,None
                db      None,None,None,None,k_F12

a_NumTable      db      None,1Bh,'1234567890-=',8          ; Num Table
                db      9,'QWERTYUIOP[]',0Dh
                db      Ctrl,'ASDFGHJKL;',27h,'`'
                db      LShift,'\ZXCVBNM,./',RShift,'*'
                db      ALT,' ',Caps
                db      k_F1,k_F2,k_F3,k_F4,k_F5,k_F6,k_F7,k_F8,k_F9,k_F10
                db      k_NumLock,k_Reset,None,k_UpArrow,None,'-'
                db      k_LeftArrow,None,k_RightArrow,'+',None,k_DownArrow,None,k_Fire1,k_Fire2
                db      None,None,None,None,k_F12



;  1 Home
;  2 End
;  3 PgUp
;  4 PgDn
;  5 Left
;  6 Right
;  7 Up
;  8 Down
;  9 Ins
;  A Del
;  B BS
;  C Esc
;  D Tab
;  E F1
;  F F2
; 10 F3
; 11 F4
; 12 F5
; 13 F6
; 14 F7
; 15 F8
; 16 F9
; 17 F10
; 18 Enter
; 19 Cntr
; 1A Dos Shell
; 1B Quit

d_NormalTable   db      None,0Ch,'1234567890-=',0Bh
                db      0Dh,'qwertyuiop[]',18h
                db      Ctrl,'asdfghjkl;',27h,'`'
                db      LShift,'\zxcvbnm,./',RShift,'*'
                db      ALT,' ',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,1,7,3,'-'
                db      5,19h,6,'+',2,8,4,9,0Ah
                db      None,None,None,None,None

d_ShiftTable    db      None,0Ch,'!@#$%^&*()_+',0Bh
                db      0Dh,'QWERTYUIOP{}',18h
                db      Ctrl,'ASDFGHJKL:"~'
                db      LShift,'|ZXCVBNM<>?',RShift,'*'
                db      ALT,' ',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,1,7,3,'-'
                db      5,19h,6,'+',2,8,4,9,0Ah
                db      None,None,None,None,None

d_CapsTable     db      None,0Ch,'1234567890-=',0Bh
                db      0Dh,'QWERTYUIOP[]',18h
                db      Ctrl,'ASDFGHJKL;',27h,'`'
                db      LShift,'\ZXCVBNM,./',RShift,'*'
                db      ALT,' ',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,1,7,3,'-'
                db      5,19h,6,'+',2,8,4,9,0Ah
                db      None,None,None,None,None

d_CpsShfTable   db      None,0Ch,'!@#$%^&*()_+',0Bh
                db      0Dh,'qwertyuiop{}',18h
                db      Ctrl,'asdfghjkl:"~'
                db      LShift,'|zxcvbnm<>?',RShift,'*'
                db      ALT,' ',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,1,7,3,'-'
                db      5,19h,6,'+',2,8,4,9,0Ah
                db      None,None,None,None,None

d_AltTable      db      None,0Ch,'1234567890-=',0Bh
                db      0Dh,'qwertyuiop[]',18h
                db      Ctrl,'as',1Ah,'fghjkl;',27h,'`'
                db      LShift,'\z',1Bh,'cvbnm,./',RShift,'*'
                db      ALT,' ',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,1,7,3,'-'
                db      5,19h,6,'+',2,8,4,9,0Ah
                db      None,None,None,None,None

k_NormalTable   db      None,'..............'
                db      '..............'
                db      Ctrl,'............'
                db      LShift,'...........',RShift,'.'
                db      ALT,'.',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,'....'
                db      '.........'
                db      None,None,None,None,None

k_AltTable      db      None,1Ah,'.............'
                db      '..............'
                db      Ctrl,'............'
                db      LShift,'...........',RShift,'.'
                db      ALT,'.',Caps
                db      0Eh,0Fh,10h,11h,12h,13h,14h,15h,16h,17h
                db      k_NumLock,None,'....'
                db      '........',1Bh
                db      None,None,None,None,None
Keyboard        ends



SimKbd          segment public
                assume  cs:SimKbd,ds:SimKbd,es:Emulate

; Entry:
;   DS:SI -> keys
;   CF    -- keys format type: 1 - single, 0 - double
SimKbdRq        proc    far
                push    ax cx dx
                mov     al,0
                jnc     SKR_1
                inc     al
SKR_1:          mov     cs:SK_SpeedType,al
                mov     word ptr cs:SK_Address,si
                mov     word ptr cs:SK_Address[2],ds
                xor     ax,ax
                mov     al,cs:SK_Speed
                mov     cx,cs
                mov     dx,offset SimKbdTimer
                call    TimerReq
                pop     dx cx ax
                ret
SimKbdRq        endp

SimKbdClrKeys   db      0
SimKbdClr       proc    far
                push    si ds
                push    cs
                pop     ds
                mov     si,offset SimKbdClrKeys
                stc
                call    SimKbdRq
                pop     ds si
                ret
SimKbdClr       endp

key_taken       proc    far
                mov     cs:SK_WaitFlag,0
                ret
key_taken       endp

SK_SpeedType    db      1
SK_Address      dd      ?
SK_Speed        db      1
SK_WaitFlag     db      0
SimKbdTimer     proc    far
                mov     ax,seg C000
                mov     es,ax
                lds     si,cs:SK_Address
                cmp     cs:SK_WaitFlag,0
                jz      SK_ok
                mov     ax,1
                mov     cx,cs
                mov     dx,offset SimKbdTimer
                call    TimerReq
                ret
SK_ok:          cld
                lodsb
                or      al,al
                jz      SK_Ret
                cmp     al,0FFh
                jne     SK_DoIt
                lodsb
                mov     cs:SK_Speed,al
                jmp     SK_CallRq
SK_DoIt:        mov     es:C000,0
                call    far ptr Key
                mov     bl,es:C000
                mov     cs:SK_WaitFlag,bl
                mov     bx,seg TimerFlags
                mov     es,bx
                assume  es:seg TimerFlags
                or      es:TimerFlags,ax
                cmp     cs:SK_SpeedType,1
                je      SK_CallRq
                lodsb
                mov     cs:SK_Speed,al
SK_CallRq:      cmc
                call    SimKbdRq
SK_Ret:         ret
SimKbdTimer     endp

;------------------------------------------------------ Recording & Playback ---

; Entry:
;   ES:DI -> buffer
;   CX    -- buffer length
StartRecord     proc    far
                push    ax ds
                push    cs
                pop     ds
                mov     RK_RecordAddrLo,di
                mov     RK_RecordAddrHi,es
                mov     RK_MaxRecord,cx
                mov     RK_InitialCount,cx
                mov     ax,40h
                mov     ds,ax
                mov     ax,word ptr ds:[6Ch]
                mov     cs:RK_RecordTime,ax
                pop     ds ax
                ret
StartRecord     endp


RK_InitialCount dw      0

; Exit:
;   CX -- recorded keys count
StopRecord      proc    far
                push    ax di es
                mov     cx,cs:RK_InitialCount
                sub     cx,cs:RK_MaxRecord
                xor     ax,ax
                mov     cs:RK_MaxRecord,ax
                les     di,cs:RK_RecordAddr
                inc     ax
                stosw
                pop     es di ax
                ret
StopRecord      endp


RK_RecordAddr   label   dword
RK_RecordAddrLo dw      0
RK_RecordAddrHi dw      0
RK_RecordTime   dw      0
RK_MaxRecord    dw      0
RK_GoToDebug    db      0FFh,1,38h,3Bh,0B8h
                db      1Fh,14h,18h,19h,2Ah,02h,0AAh,39h,30h,16h,21h
                DB      21h,12h,13h,39h,21h,16h,26h,26h,2Ah,02h,0AAh
                db      0

; Entry:
;   AL -- key to be recorded
RecordKey       proc    far
                push    ax bx di ds es
                push    cs
                pop     ds
                cmp     RK_MaxRecord,0
                jz      RK_ret
                mov     bx,40h
                mov     es,bx
                mov     bx,word ptr es:[6Ch]
                xchg    bx,RK_RecordTime
                sub     bx,RK_RecordTime
                neg     bx
                or      bx,bx
                jnz     RK_1
                inc     bx
RK_1:           or      bh,bh
                jz      RK_2
                mov     bl,0FFh
RK_2:           les     di,RK_RecordAddr
                cld
                mov     ah,al
                mov     al,bl
                stosw
                mov     RK_RecordAddrLo,di
                dec     RK_MaxRecord
                jnz     RK_Ret
                call    StopRecord
                mov     si,offset RK_GoToDebug
                stc
                call    SimKbdRq
RK_ret:         pop     es ds di bx ax
                ret
RecordKey       endp

SimKbd          ends

                end

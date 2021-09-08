;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      TASKCTRL.ASM                    |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Task Manager                    |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC

TaskControl     segment public
                assume  CS:TaskControl,DS:TaskControl,ES:Emulate,SS:Data

PROCESSES_NUM   =       9

CurrentProcessID db     PID_EMULATOR
Stacks          dw      SP_Emulator
                dw      SP_Debugger
                dw      SP_FileManager
                dw      SP_FloppyDiskManager
                dw      SP_KeyboardSetup
                dw      SP_AboutScreen
                dw      SP_HelpScreen
                dw      SP_DosShell
                dw      SP_QuitAppler
PackedSPs       dw      PROCESSES_NUM dup (0)
StackPointers   dw      PROCESSES_NUM dup (0)

INinits         dd      EmulatorInInit,DebugInInit,FMInInit,DMInInit
                dd      KBDsetupInInit,AboutInInit,HelpInInit,NoInit,NoInit
OUTinits        dd      EmulatorOutInit,DebugOutInit,FMOutInit,DMOutInit
                dd      KBDsetupOutInit,AboutOutInit,HelpOutInit,NoInit,NoInit

EnableTaskSwitch  db    1
PreviousProcessID db    PID_DONT_SWITCH
TaskSwitch      proc    far                     ; Proces ID in AL
                pushf
                SaveAll
                cmp     cs:EnableTaskSwitch,0
                jz      TS_DontSwitch
                cmp     al,PID_DONT_SWITCH
                je      TS_DontSwitch
                cmp     al,PID_PREVIOUS_PROCESS
                jne     TS_NotPrevious
                mov     al,cs:PreviousProcessID
TS_NotPrevious: cli
                mov     bx,ss
                mov     ds,bx
                mov     es,bx
                xor     bh,bh
                mov     bl,cs:CurrentProcessID
                mov     cs:PreviousProcessID,bl
                mov     cs:CurrentProcessID,al
                shl     bx,1
                mov     cs:StackPointers[bx],sp
                shl     bx,1
                call    cs:OUTinits[bx]
                shr     bx,1
                mov     si,sp
                mov     cx,offset SP_MainStack
                sub     cx,sp
                mov     di,cs:Stacks[bx]
                sub     di,cx
                mov     cs:PackedSPs[bx],di
                shr     cx,1
                cld
        rep     movsw
                xor     bh,bh
                mov     bl,cs:CurrentProcessID
                shl     bx,1
                mov     si,cs:PackedSPs[bx]
                mov     di,cs:StackPointers[bx]
                mov     sp,di
                mov     cx,offset SP_MainStack
                sub     cx,di
                shr     cx,1
        rep     movsw
                shl     bx,1
                call    cs:INinits[bx]
TS_DontSwitch:  RestoreAll
                popf
                ret
TaskSwitch      endp

S_Address       struc
RetSegment      dw      ?
RetOffset       dw      ?
S_Address       ends
StartupAdr      macro   Adr
                S_Address <seg Adr, offset Adr>
                endm
RetAddresses    label   S_Address
                StartupAdr ?
                StartupAdr DebugMainRet
                StartupAdr FM_MainRet
                StartupAdr DM_MainRet
                StartupAdr KBDsetupRET
                StartupAdr AboutMainRet
                StartupAdr HelpMainRet
                StartupAdr CtrlAltEsc
                StartupAdr CtrlAltDel

CALLpowerON     proc    far
                cli
                mov     ax,18*4
                mov     cx,seg HelpMessage
                mov     dx,offset HelpMessage
                call    TimerReq
                push    cs
                pop     ds
                mov     cx,PROCESSES_NUM
		xor     bx,bx
                mov     si,bx
                mov     ax,7200h                ; Valid flags
InitStacksLoop: mov     sp,Stacks[si]
                push    RetAddresses[bx].RetSegment
                push    RetAddresses[bx].RetOffset
                push    ax                      ; Valid flags
                sub     sp,9*2
                mov     PackedSPs[si],sp
                mov     StackPointers[si],offset SP_MainStack - (1+1+1+9)*2
		add     bx,4
		add     si,2
                loop    InitStacksLoop
		mov     ax,Emulate
		mov     es,ax
                mov     CurrentProcessID,PID_EMULATOR
                mov     sp,offset SP_MainStack
                mov     SaveStack,sp
		jmp     far ptr PowerON
CALLpowerON     endp



HelpMsg         db      ' Press <F10> for Help '
HelpMessage     proc    far
                push    ax cx si di ds es
                mov     ah,0Fh
                int     10h
                cmp     al,1
                jne     HM_Ret
                push    cs
                pop     ds
                mov     ax,Video
                mov     es,ax
                mov     si,offset HelpMsg
                mov     di,40*24*2+9*2
                mov     cx,offset HelpMessage - offset HelpMsg
                mov     ah,2Fh
HM_Loop:        lodsb
                stosw
                loop    HM_Loop
                mov     ax,18*7
                mov     cx,seg HideHelpMessage
                mov     dx,offset HideHelpMessage
                call    TimerReq
HM_Ret:         pop     es ds di si cx ax
                ret
HelpMessage     endp

HideHelpMessage proc    far
                push    ax cx di es
                mov     ah,0Fh
                int     10h
                cmp     al,1
                jne     HHM_Ret
                mov     ax,Video
                mov     es,ax
                mov     di,40*24*2+9*2
                mov     cx,offset HelpMessage- offset HelpMsg
                mov     ax,0
        rep     stosw
HHM_Ret:        pop     es di cx ax
                ret
HideHelpMessage endp


                assume  CS:TaskControl,DS:nothing,ES:nothing,SS:Data
WIE_HELP        dw      0
WIE_Counter     dw      1
WaitInstrEnd    proc    far
		xchg    bp,sp
		cmp     byte ptr [bp],0
		je      WaitInstrEnd1
		xchg    sp,bp
		iret
WaitInstrEnd1:  cmp     word ptr [bp+2],Emulate
		je      WaitInstrEnd2
		xchg    sp,bp
		iret
WaitInstrEnd2:  mov     [WIE_HELP],ax
                mov     ax,[bp]
		cmp     ah,DS:[si-1]
		mov     ax,[WIE_HELP]
		xchg    sp,bp
		je      WaitInstrEnd3
		iret
WaitInstrEnd3:  dec     [WIE_Counter]
		jz      WaitInstrEnd4
		iret
WaitInstrEnd4:  mov     ax,seg F1_or_Invalid?
                mov     es,ax
                assume  es:seg F1_or_Invalid?
                mov     byte ptr es:F1_or_Invalid?,0
                pop     ax
                pop     es
                pop     ax
		jmp     DO_RETapple
WaitInstrEnd    endp

                assume  DS:TaskControl, ES:Emulate

r_A             db      0
r_X             db      0
r_Y             db      0
r_S             db      0
r_P             db      0
r_PC            dw      0
T_Iflags        db      00000010b
RetWhere?       db      0
Emulator        proc    far
RETapple:       pushf                      ; Invalid Opcode Entry Point
                xor     ax,ax
		push    ax
		popf
                mov     ax,Debug
		mov     es,ax
                assume  es:Debug
                mov     es:F1_or_Invalid?,1
                mov     cs:RetWhere?,PID_DEBUGGER
                pop     ax
DO_RETapple:    push    cs                 ; WaitInstrEnd Entry Point
                pop     ds
                mov     bx,Emulate
                mov     es,bx
                assume  es:Emulate
		and     al,11000000b
		shl     ax,1
                rol     al,3
		shr     ax,1
		or      al,dh
                or      al,AppleFlags
                mov     r_P,al
                mov     r_A,dl
                mov     r_X,cl
		mov     ax,bp
                mov     r_Y,al
                mov     ax,AppleSP
                mov     r_S,al
		dec     si
                mov     r_PC,si

                mov     sp,offset SP_MainStack
                mov     al,RetWhere?
                call    TaskSwitch

                cli
                push    cs
                pop     ds
		mov     ax,Emulate
                mov     es,ax
                mov     SaveStack,sp
                mov     dl,r_A
		xor     ax,ax
                mov     al,r_X
                mov     cx,ax
                mov     al,r_Y
		mov     bp,ax
                mov     al,r_S
                mov     byte ptr AppleSP,al
                mov     si,r_PC
                mov     al,r_P
		mov     ah,al
		mov     bh,al
		mov     dh,al
                and     ah,00111100b
		and     bh,00001000b
		and     dh,01000001b
                mov     AppleFlags,ah
		cbw
		shr     al,1
		ror     al,1
		shr     ax,1
		xor     ah,ah
		mov     bl,ah
                or      ah,T_Iflags
                shl     bh,2
		or      bh,0D8h
		push    ax
		push    es
		push    bx
		mov     ax,Apple
		mov     bx,Video
		mov     ds,ax
                mov     es,bx
                xor     bl,bl
                mov     cs:WIE_Counter,2
                iret
Emulator        endp

EmulatorInInit  proc    far
                mov     cs:RetWhere?,PID_DEBUGGER
                ret
EmulatorInInit  endp

EmulatorOutInit proc    far
                push    ax cx di es
                mov     ax,seg SwapFlag
		mov     es,ax
                assume  es:seg SwapFlag
                mov     es:SwapFlag,1
                assume  es:Emulate
                mov     ax,Apple
                mov     es,ax
                mov     di,0C700h
                mov     cx,11
                xor     al,al
        rep     stosb
                pop     es di cx ax
                ret
EmulatorOutInit endp

CtrlAltEsc:     call    DosShell
                SwitchToProcess PID_EMULATOR
                jmp     CtrlAltEsc

CtrlAltDel:     call    QuitAppler
                jmp     CtrlAltDel

NoInit          proc    far
                ret
NoInit          endp

TaskControl     ends


DATA            segment stack 'stack'

                        dw      24+000h dup (0)
SP_Emulator             label   word
                        dw      24+080h dup (0)
SP_Debugger             label   word
                        dw      24+060h dup (0)
SP_FileManager          label   word
                        dw      24+060h dup (0)
SP_FloppyDiskManager    label   word
                        dw      24+060h dup (0)
SP_KeyboardSetup        label   word
                        dw      24+030h dup (0)
SP_AboutScreen          label   word
                        dw      24+030h dup (0)
SP_HelpScreen           label   word
                        dw      24+020h dup (0)
SP_DosShell             label   word
                        dw      24+000h dup (0)
SP_QuitAppler           label   word
                        dw      0C0h dup (0)
SP_MainStack            label   word

DATA            ends

		END

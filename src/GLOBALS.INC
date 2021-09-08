;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      GLOBALS.ASM                     |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Common Definitions & Macros     |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

                .386

;============== Constants ======================================================

WriteOFS        =       99h ;98h                ; Write Memory offset
StackPage       =       1                       ; Apple Stack page number
GRchar          =       'ß'                     ; Character used in GR Mode
LNdelimiter     =       'ú'                     ; License Name Delimiter (#250)
Tlen            =       16                      ; Max counters number
IRQmasks        =       10011100b               ; IRQ Interrupts activity (1-disabled)
MotorOffDelay   =       2 * 18                  ; Floppy Drive stop delay

RESETvector     =       0FFFCh                  ; 65C02
ABORTvector     =       0FFF8h                  ;      exception
NMIvector       =       0FFFAh                  ;              interrupt
IRQvector       =       0FFFEh                  ;                     vectors
BRKvector       =       0FFFEh                  ;

ReadAdd         =       0
WriteAdd        =       0
DataSearchLen   =       22                      ; Max distance b/address&data fields
TrackBufferLen  =       186Ah                   ; Number of Bytes on disk
TrackBuffer2Len =       DataSearchLen+31+156h   ; Max Sector length
FormatLimit     =       156h+20
;       .DSK type only:
Gap1            =       07FFFh                  ; From begining to first sector
Gap2            =       0FFFFh                  ; B/ address and data fields
Gap3            =       07FFFh                  ; B/ two sectors
Gap1Len         =       0Bh
Gap2Len         =       04h
Gap3Len         =       0Bh

;-------------- Process IDs ----------------------------------------------------
PID_EMULATOR            = 000h
PID_DEBUGGER            = 001h
PID_FILE_MANAGER        = 002h
PID_FLOPPY_DISK_MANAGER = 003h
PID_KEYBOARD_SETUP      = 004h
PID_ABOUT_SCREEN        = 005h
PID_HELP_SCREEN         = 006h
PID_DOS_SHELL           = 007h
PID_QUIT_APPLER         = 008h
PID_PREVIOUS_PROCESS    = 0FEh
PID_DONT_SWITCH         = 0FFh

;-------------- Keyboard Status Bits -------------------------------------------
M_CTRL          =       00000001b
M_LEFT_SHIFT    =       00000010b
M_RIGHT_SHIFT   =       00000100b
M_ALT           =       00001000b
M_NUM_LOCK      =       00100000b
M_CAPS_LOCK     =       01000000b

;============== Macroses =======================================================

Save            MACRO   a,b,c,d,e,f,g,h,i,j,k
                IRP     r,<a,b,c,d,e,f,g,h,i,j,k>
        IFNB    <r>
                push    r
        ENDIF
                ENDM
                ENDM

Restore         MACRO   a,b,c,d,e,f,g,h,i,j,k
                IRP     r,<k,j,i,h,g,f,e,d,c,b,a>
        IFNB    <r>
                pop     r
        ENDIF
                ENDM
                ENDM

SaveAll         MACRO
                push    ax bx cx dx si di bp ds es
                ENDM

RestoreAll      MACRO
                pop     es ds bp di si dx cx bx ax
                ENDM

FastStos        MACRO   Count                   ; AL - byte to stos
                Local   L1                      ; CX|Count - count in bytes
                mov     ah,al
        IFNB    <Count>
                mov     cx,(Count)/2
        rep     stosw
        IF      (Count) mod 2
                stosb
        ENDIF
        ELSE
                shr     cx,1
        rep     stosw
                jnc     L1
                stosb
L1:
        ENDIF
                ENDM

FastMovs        MACRO   Count                   ; CX|Count - count in bytes
                Local   L1
        IFNB    <Count>
                mov     cx,(Count)/2
        rep     movsw
        IF      (Count) mod 2
                movsb
        ENDIF
        ELSE
                shr     cx,1
        rep     movsw
                jnc     L1
                movsb
L1:
        ENDIF
                ENDM

SmartStos       MACRO   Dest,Count              ; AL - byte to stos
                Local   L1,L2                   ; DI|Dest - destination address
                mov     ah,al                   ; CX|Count - count in bytes
        IFNB    <Dest>
                mov     di,offset Dest
        IFNB    <Count>
Temp            =       Count
        IF      (offset Dest) mod 2
                stosb
Temp            =       Temp-1
        ENDIF
                mov     cx,Temp/2
        rep     stosw
        IF      Temp mod 2
                stosb
        ENDIF
        ELSE
        IF      (offset Dest) mod 2
                stosb
                dec     cx
        ENDIF
                shr     cx,1
        rep     stosw
                jnc     L2
                stosb
L2:
        ENDIF
        ELSE
        IFNB    <Count>
                mov     cx,Count
        ENDIF
                test    di,1b
                jz      L1
                stosb
                dec     cx
L1:             shr     cx,1
        rep     stosw
                jnc     L2
                stosb
L2:
        ENDIF
                ENDM

Print           MACRO   a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q
                %OUT    a&b&c&d&e&f&g&h&i&j&k&l&m&n&o&p&q
                ENDM

;-------------- Specific use definitions ---------------------------------------

If_this_is_file MACRO   FileName
                IRP     ThisFile,%@FileName
                IFIDNI  <ThisFile>,<FileName>
                ENDM
                ENDM

db_LICENSE_NAME MACRO
        IFDEF   LICENSE_NAME
                IRP     s,%LICENSE_NAME
                IRPC    c,<s>
                IF      "&c" NE LNdelimiter
                db      "&c"
                ELSE
                db      " "
                ENDIF
                ENDM
                ENDM
        ELSE
                db      'SHAREWARE'
        ENDIF
                ENDM


Opcode          MACRO   Code
                org     Code*100h
EndAddress      =       $+WriteOFS-1
                IRP     n,<% Code>
ValidOpcode&&n  equ     1
                ENDM
                ENDM

WriteAllFreeSpace MACRO
        IFDEF   Update
        IF1
Temp            =       0
FreeSpacePtr    =       0
                REPT    100h
                IRP     n,<%Temp>
        IFNDEF  ValidOpcode&&&n
                ENDM
                Print   <FreeSpace>,%FreeSpacePtr,< = >,%Temp
FreeSpacePtr    =       FreeSpacePtr+1
        ENDIF
Temp            =       Temp+1
                ENDM
                Print   <FreeSpaceCount>,< = >,%FreeSpacePtr
                Print   < IF 0 >
        ENDIF
        ENDIF
                ENDM

ReadAllFreeSpace MACRO
                include 65C02.INC
                ENDIF
                ENDM

FreeSpacePtr    =       0

UseNextFreeSpace MACRO
        IF      FreeSpacePtr LT FreeSpaceCount
                IRP     n,<%FreeSpacePtr>
                org     FreeSpace&&n*100h + 3
EndAddress      =       $-3+WriteOFS-1
                ENDM
FreeSpacePtr    =       FreeSpacePtr + 1
        ELSE
                ERR
                Print   <  Not enough free space!!>
        ENDIF
                ENDM

WriteMem        MACRO   Page
                org     Page*100h+WriteOFS
EndAddress      =       $-WriteOFS+0FFh
                ENDM

CheckAddress    MACRO   Lab
Len             =       EndAddress-($-1)
        IF      Len LT 0
                ERR
        ENDIF
        IFNB <Lab>
        IF      Len LT 0
                Print   <  >,<Lab>,<: >,<Fragment is >,%0-Len,< bytes bigger.>
        ELSE
                Print   <  >,<Lab>,<: >,%Len,< bytes left.>
        ENDIF
        ENDIF
                ENDM

AddTiming       MACRO   ms
                lea     eax,[eax+10000h*ms]
                ENDM

DoNext          MACRO
                lodsb
                mov     bh,al
                jmp     bx
                ENDM

GoWrite         MACRO
                mov     al,WriteOFS
                jmp     ax
                ENDM

SwitchToProcess macro   ProcessID
                mov     al,ProcessID
                call    TaskSwitch
                endm

;-------------- Floppy emulation interface -------------------------------------

Drive_S         Struc
ID              db      ?                       ; 0 or 1
Phase           db      00000000b               ; 0D0C0B0A - Phase A..D
PhasePTR        db      0                       ; ex. ^----- Half-step phase ptr
StepCounter     db      0                       ; Half-step counter
Track           db      0                       ; Double-step Track Number
;       Disk attributes:
FileHandle      dw      0FFFFh                  ; 0FFFFh if no disk in the drive
WriteProtect    db      0                       ; 0FFh-protected, 0-not
DiskType        db      0                       ; 0 - .NBL, 1 - .DSK
Volume          db      0FEh                    ; .DSK: Disk Volume
Drive_S         Ends

SectorImage_S   Struc
AddressProlog   db      0D5h,0AAh,096h          ; Address Field Prolog
AddressCheckSum db      000h                    ; Address Field CheckSum
AddressEpilog   db      0DEh,0AAh,0EBh          ; Address Field Epilog
DataProlog      db      0D5h,0AAh,0ADh          ; Data Field Prolog
DataCheckSum    db      000h                    ; Data Field CheckSum
DataEpilog      db      0DEh,0AAh,0EBh          ; Data Field Epilog
EndByte         db      0FFh                    ; End Of Sector byte
SectorImage_S   Ends

SectorImageF_S  Struc
AddressProlog   db      0FFh,0FFh,0FFh          ; Sector Image compare flags
AddressCheckSum db      0FFh                    ;
AddressEpilog   db      0FFh,0FFh,000h          ; 0 - ignore, 0FFh - compare
DataProlog      db      0FFh,0FFh,0FFh          ;
DataCheckSum    db      0FFh                    ;
DataEpilog      db      0FFh,0FFh,000h          ;
EndByte         db      000h                    ;
SectorImageF_S  Ends

;------ Error Codes:
;                               ; AL:   DL:
e_BadAdrCheckSum   =    0       ; Yes   No      ; Bad Address Field Checksum
e_BadAdrEpilog     =    1       ; No    Yes     ; Bad Address Field Epilog
e_BadTrackNumber   =    2       ; Yes   Yes     ; Track Number mismatch
e_BadSectorNumber  =    3       ; Yes   No      ; Not [0..F] Sector Number
e_MissingDataField =    4       ; No    Yes     ; Data Field not found
e_DuplicateSector  =    5       ; Yes   Yes     ; Sector found again
e_BadDataCheckSum  =    6       ; Yes   Yes     ; Bad Data Field Checksum
e_BadDataImage     =    7       ; No    Yes     ; Not 6&2 coded byte found
e_BadDataEpilog    =    8       ; No    Yes     ; Bad Data Field Epilog
e_BadEndByte       =    9       ; Yes   Yes     ; Bad End Byte
e_MissingSector    =    10      ; Yes   No      ; Sector not found

e_WriteAttempt     =    11                      ; Write attempt on protected disk


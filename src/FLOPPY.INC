;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      FLOPPY.INC                      |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Floppy Disk Emulation           |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

;       This file is included in EMULATE.ASM

;-------------- Floppy emulation entries ---------------------------------------

                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

                UseNextFreeSpace
C0E0r:
C0E1r:
C0E2r:
C0E3r:
C0E4r:
C0E5r:
C0E6r:
C0E7r:          push    cs
                push    di
                jmp     StepMotor
C0E0w:
C0E1w:
C0E2w:
C0E3w:
C0E4w:
C0E5w:
C0E6w:
C0E7w:          Save    ax
                call    StepMotor
                Restore ax
                sahf
                DoNext

C0E8r:          push    cs
                push    di
                jmp     StopMotors
C0E8w:          Save    ax
                call    StopMotors
                Restore ax
                sahf
                DoNext

C0E9r:          push    cs
                push    di
                jmp     StartMotors
C0E9w:          Save    ax
                call    StartMotors
                Restore ax
                sahf
                DoNext

C0EAr:
C0EBr:          push    cs
                push    di
                jmp     DeviceSelect
C0EAw:
C0EBw:          Save    ax
                call    DeviceSelect
                Restore ax
                sahf
                DoNext
                CheckAddress

                UseNextFreeSpace
C0ECr:          push    cs
                push    di
                jmp     ReadWriteBuf
C0ECw:          Save    ax
                call    ReadWriteBuf
                Restore ax
                sahf
                DoNext

C0EDr:          mov     al,0FFh
                mov     bl,ch
                jmp     di
C0EDw:          Save    ax
                mov     al,bh
                call    WriteDataReg
                Restore ax
                sahf
                DoNext

C0EEr:          push    cs
                push    di
                call    ReadMode
                jmp     WriteProtection
C0EEw:          Save    ax
                call    ReadMode
                Restore ax
                sahf
                DoNext

C0EFr:          push    di
                call    WriteMode
                mov     al,0FFh
                ret
C0EFw:          Save    ax
                call    WriteMode
                Restore ax
                sahf
                DoNext
                CheckAddress

;-------------- Floppy emulation subroutines -----------------------------------

Peripher        segment public
                assume  CS:Peripher,DS:Nothing,ES:Nothing

FLAGS           db      00000010b
                even
BufferPTR       dw      0                       ; Byte pointer in the R/W buffer
WriteCNT        dw      0                       ; Written bytes between two reads
WriteREG        db      0                       ; Temporal write register
                even
CurrentDrive    Drive_S <0>                     ; Active Drive Attributes
OtherDrive      Drive_S <1>

; Entry:
;   bx    - file handle
;   ds:si - header ptr
; Action:
;   load track buffer
; Exit:
;   CF: 0-ok, 1-error (don't close file)
FloppyLoad      proc    far
                push    ax cx dx ds
                mov     ax,seg Buffer1000h
                mov     ds,ax
                mov     dx,offset Buffer1000h
                mov     cx,1000h
                mov     ah,3Fh
                int     21h
                cmp     ax,cx
                pop     ds dx cx ax
                ret
FloppyLoad      endp

; Entry:
;   bx    - file handle
;   es:di - header ptr
; Action:
;   save track buffer
; Exit:
;   CF: 0-ok, 1-error (don't close file)
FloppySave      proc    far
                push    ax cx dx ds
                mov     ax,seg Buffer1000h
                mov     ds,ax
                mov     dx,offset Buffer1000h
                mov     cx,1000h
                mov     ah,40h
                int     21h
                cmp     ax,cx
                pop     ds dx cx ax
                ret
FloppySave      endp
                assume  ds:Nothing

FloppyINIT      Proc    near
                call    OpenDiskFile1
                call    OpenDiskFile2
                ret
FloppyINIT      Endp

FloppyTINI      Proc    near
                call    CloseDiskFile1
                call    CloseDiskFile2
                ret
FloppyTINI      Endp

ResetFloppy     Proc    near
                call    ReadMode
                mov     al,0
                call    DeviceSelect
                call    StopMotors
                ret
ResetFloppy     Endp

                even
StartMotors     Proc    far
                or      FLAGS,00000011b
                mov     bl,ch
                ret
StartMotors     Endp

                even
StopMotors      Proc    far
                test    FLAGS,00000010b
                jz      StopMotors5
                and     FLAGS,11111101b
                mov     bl,ch
                ret
StopMotorsC:    test    FLAGS,00000010b
                jnz     StopMotors5
                call    WriteTrack
                and     FLAGS,11111100b
StopMotors5:    mov     bl,ch
                ret
StopMotors      Endp

                even
DeviceSelect    Proc    far
                and     al,1b
                xor     al,CurrentDrive.ID
                jz      DeviceSelect20
                call    WriteTrack
                Save    si cx
                mov     si,offset CurrentDrive
                mov     cx,size Drive_S
DeviceSelect10: lods    byte ptr CS:[SI]
                xchg    CS:OtherDrive.ID[SI-1]-CurrentDrive.ID,al
                mov     CS:[SI-1],al
                loop    DeviceSelect10
                Restore si cx
DeviceSelect20: mov     bl,ch
                ret
DeviceSelect    Endp

                even
StepMotor       Proc    far
                test    FLAGS,00000001b
                jz      StepMotor8
                Save    cx
                mov     cl,al
                and     cl,00000110b
                mov     ah,CurrentDrive.Phase
                ror     ah,cl
                ror     ax,1
                xor     cl,00000111b
                ror     ah,cl
                mov     CurrentDrive.Phase,ah
                mov     cl,CurrentDrive.PhasePTR
                ror     ah,cl
                mov     ch,ah
                mov     bl,CurrentDrive.StepCounter
                mov     bh,bl
StepMotor5:     mov     ah,ch
                xor     al,al
                shr     ah,1
                shr     ah,1
                rcl     al,1
                shr     ah,1
                rcl     al,1
                shr     ah,1
                rcl     al,1
                shr     ah,1
                cmp     ah,al
                je      StepMotor20
                ja      StepMotor10
                inc     cl
                ror     ch,1
                inc     bl
                jmp     StepMotor5
StepMotor8:     mov     bl,ch
                ret
StepMotor10:    dec     cl
                rol     ch,1
                dec     bl
                jmp     StepMotor5
StepMotor20:    and     cl,00000111b
                mov     CurrentDrive.PhasePTR,cl
                xor     bh,bl
                and     bh,11111100b
                jz      StepMotor25
                call    WriteTrack
StepMotor25:    cmp     bl,0F8h
                jb      StepMotor27
                and     bl,111b
StepMotor27:    mov     CurrentDrive.StepCounter,bl
                shr     bl,1
                shr     bl,1
                mov     CurrentDrive.Track,bl
StepMotor30:    Restore cx
                mov     bl,ch
                ret
StepMotor       Endp

                even
ReadMode        Proc    far
                and     FLAGS,10111111b
                mov     bx,BufferPTR
                add     bx,ReadAdd
                cmp     bx,TrackBufferLen
                jb      ReadMode10
                sub     bx,TrackBufferLen
ReadMode10:     mov     BufferPTR,bx
                mov     WriteCNT,0
                mov     bl,ch
                ret
ReadMode        Endp

                even
WriteMode       Proc    far
                or      FLAGS,01000000b
                mov     bx,BufferPTR
                add     bx,WriteAdd
                cmp     bx,TrackBufferLen
                jb      WriteMode10
                sub     bx,TrackBufferLen
WriteMode10:    mov     BufferPTR,bx
                test    FLAGS,00000100b
                jnz     WriteMode20
                mov     BufferPTR,0
                or      FLAGS,00010100b
WriteMode20:    or      FLAGS,00001000b
                mov     bl,ch
                ret
WriteMode       Endp

                even
ReadWriteBuf    Proc    far
                mov     ah,FLAGS
                test    ah,01000000b
                jnz     WriteBuff10
                test    ah,00000100b
                jnz     ReadBuff10
                call    ReadTrack
                mov     BufferPTR,0
                or      FLAGS,00000100b
                and     FLAGS,11100111b
                mov     ah,FLAGS
ReadBuff10:     mov     bx,BufferPTR
                mov     al,TrackBuffer[bx]
                test    ah,00000001b
                jz      ReadBuff30
                inc     bx
                cmp     bx,TrackBufferLen
                jb      ReadBuff20
                xor     bx,bx
ReadBuff20:     mov     BufferPTR,bx
ReadBuff30:     mov     bl,ch
                ret
WriteBuff10:    test    ah,00000001b
                jz      Writebuff30
                mov     bx,BufferPTR
                mov     al,WriteREG
                mov     TrackBuffer[bx],al
                inc     bx
                cmp     bx,TrackBufferLen
                jb      WriteBuff20
                xor     bx,bx
WriteBuff20:    mov     BufferPTR,bx
                mov     bx,WriteCNT
                inc     bx
                mov     WriteCNT,bx
                cmp     bx,FormatLimit
                jb      WriteBuff30
                or      FLAGS,00010000b
Writebuff30:    mov     bl,ch
                ret
ReadWriteBuf    Endp

                even
WriteDataReg    Proc    far
                mov     WriteREG,al
                mov     bl,ch
                ret
WriteDataReg    Endp

                even
WriteProtection Proc    far
                mov     al,CurrentDrive.WriteProtect
                mov     bl,ch
                ret
WriteProtection Endp

;-------------------------------------------------------------------------------

ReadTrack       Proc    far                     ; Saves all registers
                SaveAll
                cmp     CurrentDrive.DiskType,0
                mov     ax,cs
                mov     ds,ax
                mov     si,offset TrackBuffer
                mov     di,TrackBufferLen
                je      ReadTrack10
                mov     ax,seg Buffer1000h
                mov     ds,ax
                mov     si,offset Buffer1000h
                mov     di,1000h
ReadTrack10:    mov     al,CurrentDrive.Track
                cbw
                mul     di
                mov     cx,dx
                mov     dx,ax
                mov     bx,CurrentDrive.FileHandle
                mov     ax,4200h
                int     21h
                jc      ReadTrack20
                mov     dx,si
                mov     cx,di
                mov     ah,3Fh
                int     21h
                jnc     ReadTrack30
                cmp     ax,cx
                je      ReadTrack30
ReadTrack20:    mov     ax,cs
                mov     es,ax
                mov     di,offset TrackBuffer
                mov     cx,TrackBufferLen/2
                mov     ax,Gap1
        rep     stosw
                jmp     ReadTrack40
ReadTrack30:    cmp     CurrentDrive.DiskType,0
                je      ReadTrack40
                call    EncodeTrack
ReadTrack40:    RestoreAll
                ret
ReadTrack       Endp

EncodeTrack     Proc    near                    ; Destroys all registers
                cld
                mov     ax,cs
                mov     ds,ax
                mov     es,ax
                assume  ds:Peripher,es:Peripher
                mov     di,offset TrackBuffer
                mov     dl,0
                mov     ax,Gap1
                mov     cx,Gap1Len/2
Encode10: rep   stosw
                mov     si,offset SectorImage.AddressProlog
                movsb
                movsw
                lodsb
                mov     dh,al
                mov     al,CurrentDrive.Volume
                xor     dh,al
                mov     ah,al
                shr     al,1
                or      ax,0AAAAh
                stosw
                mov     al,CurrentDrive.Track
                xor     dh,al
                mov     ah,al
                shr     al,1
                or      ax,0AAAAh
                stosw
                xor     bx,bx
                mov     bl,dl
                mov     bl,PosToLogNumber[BX]
                mov     al,LogToPhisNumber[BX]
                xor     dh,al
                mov     ah,al
                shr     al,1
                or      ax,0AAAAh
                stosw
                mov     al,dh
                mov     ah,al
                shr     al,1
                or      ax,0AAAAh
                stosw
                movsw
                movsb
                mov     ax,Gap2
                mov     cx,Gap2Len/2
        rep     stosw
                movsw
                movsb
                lodsb
                mov     dh,al
                xchg    bh,bl
                add     bx,offset Buffer1000h
                mov     si,bx
                mov     ax,seg Buffer1000h
                mov     ds,ax
                assume  ds:seg Buffer1000h
                mov     bx,offset EncodeTable
                mov     cx,56h
Encode15:       xor     ah,ah
                mov     al,DS:[SI+2*56h]
                shr     al,1
                rcl     ah,1
                shr     al,1
                rcl     ah,1
                mov     ES:[DI+3*56h],al
                mov     al,DS:[SI+56h]
                shr     al,1
                rcl     ah,1
                shr     al,1
                rcl     ah,1
                mov     ES:[DI+2*56h],al
                lodsb
                shr     al,1
                rcl     ah,1
                shr     al,1
                rcl     ah,1
                mov     ES:[DI+56h],al
                mov     al,ah
                xor     al,dh
                xor     dh,al
                xlat    CS:[BX]
                stosb
                loop    Encode15
                mov     si,di
                mov     ax,cs
                mov     ds,ax
                assume  ds:Peripher
                mov     cx,100h
Encode20:       lodsb
                xor     al,dh
                xor     dh,al
                xlat
                stosb
                loop    Encode20
                mov     al,dh
                xlat
                stosb
                mov     si,offset SectorImage.DataEpilog
                movsw
                movsw
                mov     ax,Gap3
                mov     cx,Gap3Len/2
                inc     dl
                cmp     dl,10h
                jnb     Encode30
                jmp     Encode10
Encode30:       mov     ax,Gap1
                mov     cx,offset TrackBuffer2
                sub     cx,di
                shr     cx,1
        rep     stosw
                adc     cx,0
        rep     stosb
                ret
                assume  ds:Nothing,es:Nothing
EncodeTrack     Endp

FlushBuffer     Proc    far                     ; External entry
                call    WriteTrack              ; (from Disk Manager)
                ret
FlushBuffer     Endp

WriteTrack      Proc    near                    ; Saves all registers
                test    FLAGS,00011000b
                jz      WriteTrack30
                cmp     CurrentDrive.WriteProtect,0
                jne     WriteTrack30
                SaveAll
                cmp     CurrentDrive.DiskType,0
                mov     ax,cs
                mov     ds,ax
                mov     si,offset TrackBuffer
                mov     di,TrackBufferLen
                je      WriteTrack10
                call    DecodeTrackM
                mov     ax,seg Buffer1000h
                mov     ds,ax
                mov     si,offset Buffer1000h
                mov     di,1000h
WriteTrack10:
                and     FLAGS,11100111b
                mov     al,CurrentDrive.Track
                cbw
                mul     di
                mov     cx,dx
                mov     dx,ax
                mov     bx,CurrentDrive.FileHandle
                mov     ax,4200h
                int     21h
                jc      WriteTrack20
                mov     dx,si
                mov     cx,di
                mov     ah,40h
                int     21h
WriteTrack20:   RestoreAll
WriteTrack30:   and     FLAGS,11111011b
                ret
WriteTrack      Endp

DecodeTrackM    Proc    near
DecodeTrackM10: call    DecodeTrack
                jnc     DecodeTrackM20
                Save    ax bx cx dx
                mov     bl,DecodedSector
                and     bx,0Fh
                mov     dl,PhisToLogNumber[BX]
                pushf
                pushf
                pop     cx
                and     cx,not(11b shl 8)
                push    cx
                popf
                call    DMentry
                lahf
                popf
                sahf
                Restore ax bx cx dx
                jnc     DecodeTrackM10
DecodeTrackM20: ret
DecodeTrackM    Endp

DecodeTrack     Proc    near                    ; Destroys all registers
                assume  ds:Peripher,es:Peripher
                cld
                mov     ax,cs
                mov     ds,ax
                mov     es,ax
                mov     si,offset TrackBuffer
                mov     di,offset TrackBuffer2
                FastMovs TrackBuffer2Len
                mov     di,offset SectorFlags
                mov     al,1
                FastStos 10h
                mov     di,offset TrackBuffer
                jmp     Decode10
DecodeTrkErr_J: jmp     DecodeTrackErr
DecodeTrkEnd_J: jmp     DecodeTrackEnd
Decode10:       mov     cx,offset TrackBuffer2
                sub     cx,di
                jbe     DecodeTrkEnd_J
                mov     al,SectorImage.AddressProlog
        repne   scasb
                jne     DecodeTrkEnd_J
                mov     ax,ES:[DI]
                xor     ax,word ptr SectorImage .AddressProlog+1
                and     ax,word ptr SectorImageF.AddressProlog+1
                jnz     Decode10
                lea     si,[di+2]
                mov     dh,SectorImage .AddressCheckSum
                call    DecodeAdrField
                and     al,SectorImageF.AddressCheckSum
                mov     ah,e_BadAdrCheckSum
                jnz     DecodeTrkErr_J          ; Bad Address CheckSum
                lodsw
                xor     ax,word ptr SectorImage .AddressEpilog
                and     ax,word ptr SectorImageF.AddressEpilog
                jnz     Decode15
                lodsb
                xor     al,SectorImage .AddressEpilog+2
                and     al,SectorImageF.AddressEpilog+2
Decode15:       mov     ah,e_BadAdrEpilog
                jnz     DecodeTrkErr_J          ; Bad Address Epilog
                mov     al,DecodedTrack
                cmp     al,CurrentDrive.Track
                mov     ah,e_BadTrackNumber
                jne     DecodeTrkErr_J          ; Bad Track Number
                mov     al,DecodedSector
                cmp     al,0Fh
                mov     ah,e_BadSectorNumber
                ja      DecodeTrkErr_J          ; Bad Sector Number
                mov     di,si
                mov     cx,DataSearchLen
Decode20:       mov     al,SectorImage.DataProlog
        repne   scasb
                mov     ah,e_MissingDataField
                jne     DecodeTrkErr_J          ; Data Field is Missing
                mov     ax,ES:[DI]
                xor     ax,word ptr SectorImage .DataProlog+1
                and     ax,word ptr SectorImageF.DataProlog+1
                jnz     Decode20
                lea     si,[di+2]
                mov     bl,DecodedSector
                and     bx,0Fh
                mov     bl,PhisToLogNumber[BX]
                dec     SectorFlags[BX]
                mov     al,bl
                mov     ah,e_DuplicateSector
                jnz     DecodeTrackErr          ; Duplicate Sector
                xchg    bh,bl
                add     bx,offset Buffer1000h
                mov     di,bx
                mov     dh,SectorImage .DataCheckSum
                call    DecodeDataField
                and     al,SectorImageF.DataCheckSum
                and     al,3Fh
                mov     ah,e_BadDataCheckSum
                jnz     DecodeTrackErr          ; Bad Data CheckSum
                or      bp,bp
                mov     ah,e_BadDataImage
                jnz     DecodeTrackErr          ; Bad Data Image
                lodsw
                xor     ax,word ptr SectorImage .DataEpilog
                and     ax,word ptr SectorImageF.DataEpilog
                jnz     Decode70
                lodsb
                xor     al,SectorImage .DataEpilog+2
                and     al,SectorImageF.DataEpilog+2
Decode70:       mov     ah,e_BadDataEpilog
                jnz     DecodeTrackErr          ; Bad Data Epilog
                lodsb
                mov     ah,al
                xor     ah,SectorImage .EndByte
                and     ah,SectorImageF.EndByte
                mov     ah,e_BadEndByte
                jnz     DecodeTrackErr          ; Bad End Byte
                mov     di,si
                jmp     Decode10
DecodeTrackErr: stc
                jmp     DecodeTrackExt
DecodeTrackEnd: mov     bx,0Fh
                mov     ah,e_MissingSector
Decode80:       mov     al,bl
                cmp     SectorFlags[BX],0
                jne     DecodeTrackErr          ; Sector is Missing
                dec     bx
                jns     Decode80
                mov     al,DecodedVolume
                mov     CurrentDrive.Volume,al
                clc
DecodeTrackExt: ret

DecodeAdrField  Proc    near                    ; DS:SI - Source
                lodsw                           ; DH - CheckSum Seed
                rol     al,1
                and     al,ah
                mov     DecodedVolume,al
                xor     dh,al
                lodsw
                rol     al,1
                and     al,ah
                mov     DecodedTrack,al
                xor     dh,al
                lodsw
                rol     al,1
                and     al,ah
                mov     DecodedSector,al
                xor     dh,al
                lodsw
                rol     al,1
                and     al,ah
                xor     al,dh
                ret
DecodeAdrField  Endp                            ; AL - CheckSum Result

DecodeDataField Proc    near                    ; SI,DI - Source,Destination
                Save    es                      ; DH - CheckSum Seed
                mov     ax,seg Buffer1000h
                mov     es,ax
                assume  es:seg Buffer1000h
                Save    di
                mov     bx,offset DecodeTable - 80h
                shl     dh,1
                shl     dh,1
                xor     bp,bp
                mov     cx,56h-2
DDF10:          lodsb
                xlat
                shl     al,1
                adc     bp,0
                xor     dh,al
                mov     al,dh
                xor     ah,ah
                shl     al,1
                rcr     ah,1
                shl     ax,1
                rcl     ah,1
                mov     ES:[DI+2*56h],ah
                xor     ah,ah
                shl     al,1
                rcr     ah,1
                shl     ax,1
                rcl     ah,1
                mov     ES:[DI+1*56h],ah
                shl     al,1
                rcr     ah,1
                rol     al,1
                rol     ax,1
                stosb
                loop    DDF10
                mov     cx,2
DDF20:          lodsb
                xlat
                shl     al,1
                adc     bp,0
                xor     dh,al
                mov     al,dh
                xor     ah,ah
                shl     al,1
                shl     al,1
                shl     al,1
                rcr     ah,1
                shl     ax,1
                rcl     ah,1
                mov     ES:[DI+1*56h],ah
                shl     al,1
                rcr     ah,1
                rol     al,1
                rol     ax,1
                stosb
                loop    DDF20
                Restore di
                mov     cx,100h
DDF30:          lodsb
                xlat
                shl     al,1
                adc     bp,0
                xor     dh,al
                or      ES:[DI],dh
                inc     di
                loop    DDF30
                lodsb
                xlat
                shl     al,1
                adc     bp,0
                xor     al,dh
                shr     al,1
                shr     al,1
                Restore es
                assume  es:Peripher
                ret                             ; AL - CheckSum Result
DecodeDataField Endp                            ; BP - Bad Data Image flag
                assume  ds:Nothing,es:Nothing
DecodeTrack     Endp                            ; Error: CF=1, AH-Code, AL-Data

;-------------------------------------------------------------------------------
                even
SectorImage     SectorImage_S  <>
SectorImageF    SectorImageF_S <>

DecodedVolume   db      0
DecodedTrack    db      0
DecodedSector   db      0

SectorFlags     db      10h dup(0)

PosToLogNumber  db      0Fh,0Eh,0Dh,0Ch,0Bh,0Ah,09h,08h ; Position-to-Logical
                db      07h,06h,05h,04h,03h,02h,01h,00h ; number convert table
LogToPhisNumber db      00h,0Dh,0Bh,09h,07h,05h,03h,01h ; Logical-to-Phisical
                db      0Eh,0Ch,0Ah,08h,06h,04h,02h,0Fh ; number convert table
PhisToLogNumber db      00h,07h,0Eh,06h,0Dh,05h,0Ch,04h ; Phisical-to-Logical
                db      0Bh,03h,0Ah,02h,09h,01h,08h,0Fh ; number convert table

EncodeTable     label   byte                    ; 6&2 Encode Table
T1              =       80h
                REPT    80h
T3              =       (T1 and (T1 shl 1)) and 01111110b
T4              =       not(T1 or (T1 shl 1)) and 01111110b
T4              =       T4 and (T4 - 1)
        IF (T3 GT 0) and (T4 EQ 0)
                db      T1
        ENDIF
T1              =       T1 + 1
                ENDM

DecodeTable     label   byte                    ; 6&2 Decode Table
T1              =       80h
T2              =       0
                REPT    80h
T3              =       (T1 and (T1 shl 1)) and 01111110b
T4              =       not(T1 or (T1 shl 1)) and 01111110b
T4              =       T4 and (T4 - 1)
        IF (T3 GT 0) and (T4 EQ 0)
                db      T2 shl 1
T2              =       T2 + 1
        ELSE
                db      80h
        ENDIF
T1              =       T1 + 1
                ENDM

TrackBuffer     db      TrackBufferLen  dup(0)
TrackBuffer2    db      TrackBuffer2Len dup(0)

Peripher        ends

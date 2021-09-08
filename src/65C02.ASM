;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      65C02.ASM                       |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   65C02 CPU Emulator              |
; |                                             |
; |  Author:    Alexander Patalenski            |
; |_____________________________________________|

                include GLOBALS.INC
                include INTERFAC.INC

UserMask        =       0FC02h

Emulate         segment common
                assume  CS:Emulate,DS:Apple,ES:Video,SS:Data

Immediate       MACRO                           ; #$..
                lodsb
                ENDM

Page0           MACRO                           ; $..
                lodsb
                mov     bh,bl
                xlat
                ENDM

Page0X          MACRO                           ; $..,X
                lodsb
                add     al,cl
                mov     bh,bl
                xlat
                ENDM

Page0Y          MACRO                           ; $..,Y
                lodsb
                add     ax,bp
                mov     bh,bl
                xlat
                ENDM

Direct          MACRO                           ; $....
                lodsw
                mov     bh,ah
                ENDM

DirectX         MACRO                           ; $....,X
                lodsw
                add     ax,cx
                mov     bh,ah
                ENDM

DirectY         MACRO                           ; $....,Y
                lodsw
                add     ax,bp
                mov     bh,ah
                ENDM

IndirectPage0   MACRO                           ; ($..)
                lodsb
                mov     ah,bl
                xchg    bx,ax
                xlat
                inc     bl
                mov     bh,[bx]
                mov     bl,ch
                ENDM

IndirectPage0X  MACRO                           ; ($..,X)
                lodsb
                mov     bx,cx
                add     bl,al
                mov     al,[bx]
                inc     bl
                mov     bh,[bx]
                mov     bl,ch
                ENDM

IndirectPage0Y  MACRO                           ; ($..),Y
                lodsb
                mov     ah,bl
                xchg    bx,ax
                xlat
                inc     bl
                mov     ah,[bx]
                add     ax,bp
                mov     bh,ah
                mov     bl,ch
                ENDM

;-------------------------------------------------------------------------------

_LDA_           MACRO
                mov     dl,al
                or      dl,dl
                ENDM

_LDX_           MACRO
                mov     cl,al
                or      cl,cl
                ENDM

_LDY_           MACRO
                mov     ah,bl
                mov     bp,ax
                or      al,al
                ENDM

_AND_           MACRO
                and     dl,al
                ENDM

_ORA_           MACRO
                or      dl,al
                ENDM

_EOR_           MACRO
                xor     dl,al
                ENDM

ADCcounter      =       0
_ADC_           MACRO
                Local   _ADC_10
ADCcounter      =       ADCcounter+1
                rcr     dh,1
                adc     al,dl
                IRP     n,<%ADCcounter>
ADC&&n          Label   byte
                ENDM
                cld                             ;; or <daa>
                mov     dl,al
                mov     dh,bl                   ;; 0
                jno     _ADC_10
                mov     dh,00100000b
_ADC_10:        rcl     dh,1
                ENDM

SBCcounter      =       0
_SBC_           MACRO
                Local   _SBC_10
SBCcounter      =       SBCcounter+1
                rcr     dh,1
                cmc
                sbb     dl,al
                mov     al,dl
                IRP     n,<%SBCcounter>
SBC&&n          Label   byte
                ENDM
                cld                             ;; or <das>
                cmc
                mov     dl,al
                mov     dh,bl                   ;; 0
                jno     _SBC_10
                mov     dh,00100000b
_SBC_10:        rcl     dh,1
                ENDM

_CMP_           MACRO
                rcr     dh,1
                cmp     dl,al
                cmc
                rcl     dh,1
                ENDM

_CPX_           MACRO
                rcr     dh,1
                cmp     cl,al
                cmc
                rcl     dh,1
                ENDM

_CPY_           MACRO
                mov     bx,bp
                rcr     dh,1
                cmp     bl,al
                cmc
                rcl     dh,1
                mov     bl,bh
                ENDM

_BIT_           MACRO
                test    dl,al
                lahf
                shl     ax,1
                ror     ah,1
                shl     dh,2
                shl     al,1
                rcr     dh,1
                shr     dh,1
                sahf
                ENDM


DoInstr0        MACRO   Inst,Adr
                Adr
              _&Inst&_
                DoNext
                ENDM

DoInstr         MACRO   Inst,Adr
                Local   Inst_cont,Inst_C0XX
                Adr
                cmp     bh,0C0h
                je      Inst_C0XX
                xlat
Inst_cont:    _&Inst&_
                DoNext
Inst_C0XX:      mov     bh,bl
                mov     bl,al
                shl     bx,1
                mov     di,offset Inst_cont
                jmp     SS:C0XXRead[bx]         ; AL - Address
                ENDM



MemPage         =       0
                REPT    100h
                org     MemPage*100h
                jmp     BadOpcode
MemPage         =       MemPage+1
		ENDM


                Opcode  0A9h                    ; LDA #$..
                AddTiming 2
                DoInstr0 LDA,Immediate
                CheckAddress

                Opcode  0A5h                    ; LDA $..
                AddTiming 3
                DoInstr0 LDA,Page0
                CheckAddress

                Opcode  0B5h                    ; LDA $..,X
                AddTiming 4
                DoInstr0 LDA,Page0X
                CheckAddress

                Opcode  0ADh                    ; LDA $....
                AddTiming 4
                DoInstr LDA,Direct
                CheckAddress

                Opcode  0BDh                    ; LDA $....,X
                AddTiming 4
                DoInstr LDA,DirectX
                CheckAddress

                Opcode  0B9h                    ; LDA $....,Y
                AddTiming 4
                DoInstr LDA,DirectY
                CheckAddress

                Opcode  0B2h                    ; LDA ($..)     **65C02**
                AddTiming 5
                DoInstr LDA,IndirectPage0
                CheckAddress

                Opcode  0A1h                    ; LDA ($..,X)
                AddTiming 6
                DoInstr LDA,IndirectPage0X
                CheckAddress

                Opcode  0B1h                    ; LDA ($..),Y
                AddTiming 5
                DoInstr LDA,IndirectPage0Y
                CheckAddress

                Opcode  0A2h                    ; LDX #$..
                AddTiming 2
                DoInstr0 LDX,Immediate
                CheckAddress

                Opcode  0A6h                    ; LDX $..
                AddTiming 3
                DoInstr0 LDX,Page0
                CheckAddress

                Opcode  0B6h                    ; LDX $..,Y
                AddTiming 4
                DoInstr0 LDX,Page0Y
                CheckAddress

                Opcode  0AEh                    ; LDX $....
                AddTiming 4
                DoInstr LDX,Direct
                CheckAddress

                Opcode  0BEh                    ; LDX $....,Y
                AddTiming 4
                DoInstr LDX,DirectY
                CheckAddress

                Opcode  0A0h                    ; LDY #$..
                AddTiming 2
                DoInstr0 LDY,Immediate
                CheckAddress

                Opcode  0A4h                    ; LDY $..
                AddTiming 3
                DoInstr0 LDY,Page0
                CheckAddress

                Opcode  0B4h                    ; LDY $..,X
                AddTiming 4
                DoInstr0 LDY,Page0X
                CheckAddress

                Opcode  0ACh                    ; LDY $....
                AddTiming 4
                DoInstr LDY,Direct
                CheckAddress

                Opcode  0BCh                    ; LDY $....,X
                AddTiming 4
                DoInstr LDY,DirectX
                CheckAddress

                Opcode  69h                     ; ADC #$..
                AddTiming 2
                DoInstr0 ADC,Immediate
                CheckAddress

                Opcode  65h                     ; ADC $..
                AddTiming 3
                DoInstr0 ADC,Page0
                CheckAddress

                Opcode  75h                     ; ADC $..,X
                AddTiming 4
                DoInstr0 ADC,Page0X
                CheckAddress

                Opcode  6Dh                     ; ADC $....
                AddTiming 4
                DoInstr ADC,Direct
                CheckAddress

                Opcode  7Dh                     ; ADC $....,X
                AddTiming 4
                DoInstr ADC,DirectX
                CheckAddress

                Opcode  79h                     ; ADC $....,Y
                AddTiming 4
                DoInstr ADC,DirectY
                CheckAddress

                Opcode  72h                     ; ADC ($..)     **65C02**
                AddTiming 5
                DoInstr ADC,IndirectPage0
                CheckAddress

                Opcode  61h                     ; ADC ($..,X)
                AddTiming 6
                DoInstr ADC,IndirectPage0X
                CheckAddress

                Opcode  71h                     ; ADC ($..),Y
                AddTiming 5
                DoInstr ADC,IndirectPage0Y
                CheckAddress

                Opcode  0E9h                    ; SBC #$..
                AddTiming 2
                DoInstr0 SBC,Immediate
                CheckAddress

                Opcode  0E5h                    ; SBC $..
                AddTiming 3
                DoInstr0 SBC,Page0
                CheckAddress

                Opcode  0F5h                    ; SBC $..,X
                AddTiming 4
                DoInstr0 SBC,Page0X
                CheckAddress

                Opcode  0EDh                    ; SBC $....
                AddTiming 4
                DoInstr SBC,Direct
                CheckAddress

                Opcode  0FDh                    ; SBC $....,X
                AddTiming 4
                DoInstr SBC,DirectX
                CheckAddress

                Opcode  0F9h                    ; SBC $....,Y
                AddTiming 4
                DoInstr SBC,DirectY
                CheckAddress

                Opcode  0F2h                    ; SBC ($..)     **65C02**
                AddTiming 5
                DoInstr SBC,IndirectPage0
                CheckAddress

                Opcode  0E1h                    ; SBC ($..,X)
                AddTiming 6
                DoInstr SBC,IndirectPage0X
                CheckAddress

                Opcode  0F1h                    ; SBC ($..),Y
                AddTiming 5
                DoInstr SBC,IndirectPage0Y
                CheckAddress

                Opcode  29h                     ; AND #$..
                AddTiming 2
                DoInstr0 AND,Immediate
                CheckAddress

                Opcode  25h                     ; AND $..
                AddTiming 3
                DoInstr0 AND,Page0
                CheckAddress

                Opcode  35h                     ; AND $..,X
                AddTiming 4
                DoInstr0 AND,Page0X
                CheckAddress

                Opcode  2Dh                     ; AND $....
                AddTiming 4
                DoInstr AND,Direct
                CheckAddress

                Opcode  3Dh                     ; AND $....,X
                AddTiming 4
                DoInstr AND,DirectX
                CheckAddress

                Opcode  39h                     ; AND $....,Y
                AddTiming 4
                DoInstr AND,DirectY
                CheckAddress

                Opcode  32h                     ; AND ($..)     **65C02**
                AddTiming 5
                DoInstr AND,IndirectPage0
                CheckAddress

                Opcode  21h                     ; AND ($..,X)
                AddTiming 6
                DoInstr AND,IndirectPage0X
                CheckAddress

                Opcode  31h                     ; AND ($..),Y
                AddTiming 5
                DoInstr AND,IndirectPage0Y
                CheckAddress

                Opcode  09h                     ; ORA #$..
                AddTiming 2
                DoInstr0 ORA,Immediate
                CheckAddress

                Opcode  05h                     ; ORA $..
                AddTiming 3
                DoInstr0 ORA,Page0
                CheckAddress

                Opcode  15h                     ; ORA $..,X
                AddTiming 4
                DoInstr0 ORA,Page0X
                CheckAddress

                Opcode  0Dh                     ; ORA $....
                AddTiming 4
                DoInstr ORA,Direct
                CheckAddress

                Opcode  1Dh                     ; ORA $....,X
                AddTiming 4
                DoInstr ORA,DirectX
                CheckAddress

                Opcode  19h                     ; ORA $....,Y
                AddTiming 4
                DoInstr ORA,DirectY
                CheckAddress

                Opcode  12h                     ; ORA ($..)     **65C02**
                AddTiming 5
                DoInstr ORA,IndirectPage0
                CheckAddress

                Opcode  01h                     ; ORA ($..,X)
                AddTiming 6
                DoInstr ORA,IndirectPage0X
                CheckAddress

                Opcode  11h                     ; ORA ($..),Y
                AddTiming 5
                DoInstr ORA,IndirectPage0Y
                CheckAddress

                Opcode  49h                     ; EOR #$..
                AddTiming 2
                DoInstr0 EOR,Immediate
                CheckAddress

                Opcode  45h                     ; EOR $..
                AddTiming 3
                DoInstr0 EOR,Page0
                CheckAddress

                Opcode  55h                     ; EOR $..,X
                AddTiming 4
                DoInstr0 EOR,Page0X
                CheckAddress

                Opcode  4Dh                     ; EOR $....
                AddTiming 4
                DoInstr EOR,Direct
                CheckAddress

                Opcode  5Dh                     ; EOR $....,X
                AddTiming 4
                DoInstr EOR,DirectX
                CheckAddress

                Opcode  59h                     ; EOR $....,Y
                AddTiming 4
                DoInstr EOR,DirectY
                CheckAddress

                Opcode  52h                     ; EOR ($..)     **65C02**
                AddTiming 5
                DoInstr EOR,IndirectPage0
                CheckAddress

                Opcode  41h                     ; EOR ($..,X)
                AddTiming 6
                DoInstr EOR,IndirectPage0X
                CheckAddress

                Opcode  51h                     ; EOR ($..),Y
                AddTiming 5
                DoInstr EOR,IndirectPage0Y
                CheckAddress

                Opcode  0C9h                    ; CMP #$..
                AddTiming 2
                DoInstr0 CMP,Immediate
                CheckAddress

                Opcode  0C5h                    ; CMP $..
                AddTiming 3
                DoInstr0 CMP,Page0
                CheckAddress

                Opcode  0D5h                    ; CMP $..,X
                AddTiming 4
                DoInstr0 CMP,Page0X
                CheckAddress

                Opcode  0CDh                    ; CMP $....
                AddTiming 4
                DoInstr CMP,Direct
                CheckAddress

                Opcode  0DDh                    ; CMP $....,X
                AddTiming 4
                DoInstr CMP,DirectX
                CheckAddress

                Opcode  0D9h                    ; CMP $....,Y
                AddTiming 4
                DoInstr CMP,DirectY
                CheckAddress

                Opcode  0D2h                    ; CMP ($..)     **65C02**
                AddTiming 5
                DoInstr CMP,IndirectPage0
                CheckAddress

                Opcode  0C1h                    ; CMP ($..,X)
                AddTiming 6
                DoInstr CMP,IndirectPage0X
                CheckAddress

                Opcode  0D1h                    ; CMP ($..),Y
                AddTiming 5
                DoInstr CMP,IndirectPage0Y
                CheckAddress

                Opcode  0E0h                    ; CPX #$..
                AddTiming 2
                DoInstr0 CPX,Immediate
                CheckAddress

                Opcode  0E4h                    ; CPX $..
                AddTiming 3
                DoInstr0 CPX,Page0
                CheckAddress

                Opcode  0ECh                    ; CPX $....
                AddTiming 4
                DoInstr CPX,Direct
                CheckAddress

                Opcode  0C0h                    ; CPY #$..
                AddTiming 2
                DoInstr0 CPY,Immediate
                CheckAddress

                Opcode  0C4h                    ; CPY $..
                AddTiming 3
                DoInstr0 CPY,Page0
                CheckAddress

                Opcode  0CCh                    ; CPY $....
                AddTiming 4
                DoInstr CPY,Direct
                CheckAddress

                Opcode  89h                     ; BIT #$..      **65C02**
                AddTiming 2
                DoInstr0 BIT,Immediate
                CheckAddress

                Opcode  24h                     ; BIT $..
                AddTiming 3
                DoInstr0 BIT,Page0
                CheckAddress

                Opcode  34h                     ; BIT $..,X     **65C02**
                AddTiming 4
                DoInstr0 BIT,Page0X
                CheckAddress

                Opcode  2Ch                     ; BIT $....
                AddTiming 4
                DoInstr BIT,Direct
                CheckAddress

                Opcode  3Ch                     ; BIT $....,X   **65C02**
                AddTiming 4
                DoInstr BIT,DirectX
                CheckAddress

                Opcode  85h                     ; STA $..
                AddTiming 3
                lodsb
                mov     ah,bl
                mov     di,ax
                mov     [di],dl
                DoNext
                CheckAddress

                Opcode  95h                     ; STA $..,X
                AddTiming 4
                lodsb
                lahf
                add     al,cl
                sahf
                mov     ah,bl
                mov     di,ax
                mov     [di],dl
                DoNext
                CheckAddress

                Opcode  8Dh                     ; STA $....
                AddTiming 4
                lodsw
                mov     di,ax
                mov     bh,dl
                GoWrite
                CheckAddress

                Opcode  9Dh                     ; STA $....,X
                AddTiming 5
                lodsw
                mov     di,ax
                lahf
                add     di,cx
                sahf
                mov     ax,di
                mov     bh,dl
                GoWrite
                CheckAddress

                Opcode  99h                     ; STA $....,Y
                AddTiming 5
                lodsw
                mov     di,ax
                lea     ax,[di+bp]
                mov     di,ax
                mov     bh,dl
                GoWrite
                CheckAddress

                Opcode  92h                     ; STA ($..)     **65C02**
                AddTiming 6
                lodsb
                mov     ah,bl
                mov     di,ax
                lahf
                inc     al
                jz      STA_10
                sahf
                mov     di,[di]
                mov     ax,di
                mov     bh,dl
                GoWrite
STA_10:         sahf
                mov     al,[di]
                mov     ah,DS:[0]
                mov     di,ax
                mov     bh,dl
                GoWrite
                CheckAddress

                Opcode  81h                     ; STA ($..,X)
                AddTiming 6
                lodsb
                lahf
                add     al,cl
                mov     di,ax
                inc     al
                jz      STA_20
                and     di,0FFh
                sahf
                mov     di,[di]
                mov     ax,di
                mov     bh,dl
                GoWrite
STA_20:         sahf
                mov     al,DS:[0FFh]
                mov     ah,DS:[000h]
                mov     di,ax
                mov     bh,dl
                GoWrite
                CheckAddress

                Opcode  91h                     ; STA ($..),Y
                AddTiming 6
                lodsb
                mov     ah,bl
                mov     di,ax
                lahf
                inc     al
                jz      STA_30
                mov     di,[di]
                add     di,bp
                sahf
                mov     ax,di
                mov     bh,dl
                GoWrite
STA_30:         mov     bl,[di]
                mov     bh,DS:[0]
                add     bx,bp
                sahf
                mov     ax,bx
                mov     di,bx
                mov     bl,ch
                mov     bh,dl
                GoWrite
                CheckAddress

                Opcode  86h                     ; STX $..
                AddTiming 3
                lodsb
                mov     ah,bl
                mov     di,ax
                mov     [di],cl
                DoNext
                CheckAddress

                Opcode  96h                     ; STX $..,Y
                AddTiming 4
                lodsb
                mov     bx,bp
                lahf
                add     bl,al
                sahf
                mov     [bx],cl
                mov     bl,bh
                DoNext
                CheckAddress

                Opcode  8Eh                     ; STX $....
                AddTiming 4
                lodsw
                mov     di,ax
                mov     bh,cl
                GoWrite
                CheckAddress

                Opcode  84h                     ; STY $..
                AddTiming 3
                lodsb
                mov     ah,bl
                mov     di,ax
                mov     ax,bp
                mov     [di],al
                DoNext
                CheckAddress

                Opcode  94h                     ; STY $..,X
                AddTiming 4
                lodsb
                lahf
                add     al,cl
                sahf
                mov     ah,bl
                mov     di,ax
                mov     ax,bp
                mov     [di],al
                DoNext
                CheckAddress

                Opcode  8Ch                     ; STY $....
                AddTiming 4
                mov     ax,bp
                mov     bh,al
                lodsw
                mov     di,ax
                GoWrite
                CheckAddress

                Opcode  64h                     ; STZ $..       **65C02**
                AddTiming 3
                lodsb
                mov     ah,bl
                mov     di,ax
                mov     [di],bl
                DoNext
                CheckAddress

                Opcode  74h                     ; STZ $..,X     **65C02**
                AddTiming 4
                lodsb
                lahf
                add     al,cl
                sahf
                mov     ah,bl
                mov     di,ax
                mov     [di],bl
                DoNext
                CheckAddress

                Opcode  9Ch                     ; STZ $....     **65C02**
                AddTiming 4
                lodsw
                mov     di,ax
                mov     bh,bl
                GoWrite
                CheckAddress

                Opcode  9Eh                     ; STZ $....,X   **65C02**
                AddTiming 5
                lodsw
                mov     di,ax
                lahf
                add     di,cx
                sahf
                mov     ax,di
                mov     bh,bl
                GoWrite
                CheckAddress

                Opcode  0Ah                     ; ASL
                AddTiming 2
                rcr     dh,1
                shl     dl,1
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  06h                     ; ASL $..
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                rcr     dh,1
                shl     byte ptr [di],1
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  16h                     ; ASL $..,X
                AddTiming 6
                lodsb
                add     al,cl
                mov     ah,bl
                mov     di,ax
                rcr     dh,1
                shl     byte ptr [di],1
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  0Eh                     ; ASL $....
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                shl     bh,1
                rcl     dh,1
                GoWrite
                CheckAddress

                Opcode  1Eh                     ; ASL $....,X
                AddTiming 7
                lodsw
                add     ax,cx
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                shl     bh,1
                rcl     dh,1
                GoWrite
                CheckAddress

                Opcode  4Ah                     ; LSR
                AddTiming 2
                rcr     dh,1
                shr     dl,1
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  46h                     ; LSR $..
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                rcr     dh,1
                shr     byte ptr [di],1
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  56h                     ; LSR $..,X
                AddTiming 6
                lodsb
                add     al,cl
                mov     ah,bl
                mov     di,ax
                rcr     dh,1
                shr     byte ptr [di],1
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  4Eh                     ; LSR $....
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                shr     bh,1
                rcl     dh,1
                GoWrite
                CheckAddress

                Opcode  5Eh                     ; LSR $....,X
                AddTiming 7
                lodsw
                add     ax,cx
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                shr     bh,1
                rcl     dh,1
                GoWrite
                CheckAddress

                Opcode  2Ah                     ; ROL
                AddTiming 2
                rcr     dh,1
                rcl     dx,1
                or      dl,dl
                DoNext
                CheckAddress

                Opcode  26h                     ; ROL $..
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                mov     al,[di]
                rcr     dh,1
                rcl     al,1
                rcl     dh,1
                or      al,al
                mov     [di],al
                DoNext
                CheckAddress

                Opcode  36h                     ; ROL $..,X
                AddTiming 6
                lodsb
                add     al,cl
                mov     ah,bl
                mov     di,ax
                mov     al,[di]
                rcr     dh,1
                rcl     al,1
                rcl     dh,1
                or      al,al
                mov     [di],al
                DoNext
                CheckAddress

                Opcode  2Eh                     ; ROL $....
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                rcl     bh,1
                rcl     dh,1
                or      bh,bh
                GoWrite
                CheckAddress

                Opcode  3Eh                     ; ROL $....,X
                AddTiming 7
                lodsw
                add     ax,cx
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                rcl     bh,1
                rcl     dh,1
                or      bh,bh
                GoWrite
                CheckAddress

                Opcode  6Ah                     ; ROR
                AddTiming 2
                rcr     dx,1
                rcl     dh,1
                or      dl,dl
                DoNext
                CheckAddress

                Opcode  66h                     ; ROR $..
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                mov     al,[di]
                rcr     dh,1
                rcr     al,1
                rcl     dh,1
                or      al,al
                mov     [di],al
                DoNext
                CheckAddress

                Opcode  76h                     ; ROR $..,X
                AddTiming 6
                lodsb
                add     al,cl
                mov     ah,bl
                mov     di,ax
                mov     al,[di]
                rcr     dh,1
                rcr     al,1
                rcl     dh,1
                or      al,al
                mov     [di],al
                DoNext
                CheckAddress

                Opcode  6Eh                     ; ROR $....
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                rcr     bh,1
                rcl     dh,1
                or      bh,bh
                GoWrite
                CheckAddress

                Opcode  7Eh                     ; ROR $....,X
                AddTiming 7
                lodsw
                add     ax,cx
                mov     di,ax
                mov     bh,[di]
                rcr     dh,1
                rcr     bh,1
                rcl     dh,1
                or      bh,bh
                GoWrite
                CheckAddress

                Opcode  1Ah                     ; INC           **65C02**
                AddTiming 2
                inc     dl
                DoNext
                CheckAddress

                Opcode  0E6h                    ; INC $..
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                inc     byte ptr [di]
                DoNext
                CheckAddress

                Opcode  0F6h                    ; INC $..,X
                AddTiming 6
                lodsb
                add     al,cl
                mov     ah,bl
                mov     di,ax
                inc     byte ptr [di]
                DoNext
                CheckAddress

                Opcode  0EEh                    ; INC $....
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,[di]
                inc     bh
                GoWrite
                CheckAddress

                Opcode  0FEh                    ; INC $....,X
                AddTiming 7
                lodsw
                add     ax,cx
                mov     di,ax
                mov     bh,[di]
                inc     bh
                GoWrite
                CheckAddress

                Opcode  3Ah                     ; DEC           **65C02**
                AddTiming 2
                dec     dl
                DoNext
                CheckAddress

                Opcode  0C6h                    ; DEC $..
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                dec     byte ptr [di]
                DoNext
                CheckAddress

                Opcode  0D6h                    ; DEC $..,X
                AddTiming 6
                lodsb
                add     al,cl
                mov     ah,bl
                mov     di,ax
                dec     byte ptr [di]
                DoNext
                CheckAddress

                Opcode  0CEh                    ; DEC $....
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,[di]
                dec     bh
                GoWrite
                CheckAddress

                Opcode  0DEh                    ; DEC $....,X
                AddTiming 7
                lodsw
                add     ax,cx
                mov     di,ax
                mov     bh,[di]
                dec     bh
                GoWrite
                CheckAddress

                Opcode  14h                     ; TRB $..       **65C02**
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                lahf
                mov     al,[di]
                mov     bh,al
                and     bh,dl
                rcl     ah,1
                lahf
                rcl     ah,1
                ror     ah,1
                xor     al,bh
                mov     [di],al
                sahf
                DoNext
                CheckAddress

                Opcode  1Ch                     ; TRB $....     **65C02**
                AddTiming 6
                lodsw
                mov     di,ax
                lahf
                mov     al,[di]
                mov     bh,al
                and     bh,dl
                rcl     ah,1
                lahf
                rcl     ah,1
                ror     ah,1
                xor     bh,al
                sahf
                mov     ax,di
                GoWrite
                CheckAddress

                Opcode  04h                     ; TSB $..       **65C02**
                AddTiming 5
                lodsb
                mov     ah,bl
                mov     di,ax
                lahf
                or      [di],dl
                or      dl,dl
                mov     al,ah
                lahf
                shl     ax,1
                ror     ah,1
                sahf
                DoNext
                CheckAddress

                Opcode  0Ch                     ; TSB $....     **65C02**
                AddTiming 6
                lodsw
                mov     di,ax
                mov     bh,dl
                lahf
                or      bh,[di]
                or      dl,dl
                mov     al,ah
                lahf
                shl     ax,1
                ror     ah,1
                sahf
                mov     ax,di
                GoWrite
                CheckAddress

                Opcode  80h                     ; BRA $..       **65C02**
                AddTiming 3
                lodsb
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  0D0h                    ; BNE $..
                AddTiming 2
                lodsb
                je      BNE_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BNE_10:         DoNext
                CheckAddress

                Opcode  0F0h                    ; BEQ $..
                AddTiming 2
                lodsb
                jne     BEQ_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BEQ_10:         DoNext
                CheckAddress

                Opcode  10h                     ; BPL $..
                AddTiming 2
                lodsb
                js      BPL_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BPL_10:         DoNext
                CheckAddress

                Opcode  30h                     ; BMI $..
                AddTiming 2
                lodsb
                jns     BMI_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BMI_10:         DoNext
                CheckAddress

                Opcode  90h                     ; BCC $..
                AddTiming 2
                lodsb
                ror     dh,1
                jc      BCC_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BCC_10:         rol     dh,1
                DoNext
                CheckAddress

                Opcode  0B0h                    ; BCS $..
                AddTiming 2
                lodsb
                ror     dh,1
                jnc     BCS_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BCS_10:         rol     dh,1
                DoNext
                CheckAddress

                Opcode  50h                     ; BVC $..
                AddTiming 2
                lodsb
                rol     dh,1
                jo      BVC_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BVC_10:         ror     dh,1
                DoNext
                CheckAddress

                Opcode  70h                     ; BVS $..
                AddTiming 2
                lodsb
                rol     dh,1
                jno     BVS_10
                cbw
                mov     bx,ax
                lea     si,[si+bx]
                mov     bl,ch
                AddTiming 1
BVS_10:         ror     dh,1
                DoNext
                CheckAddress

                Opcode  4Ch                     ; JMP $....
                AddTiming 3
                mov     si,[si]
                DoNext
                CheckAddress

                Opcode  6Ch                     ; JMP ($....)
                AddTiming 5
                mov     bx,[si]
                mov     si,[bx]
                lahf
                inc     bl
                jz      JMP_10
                sahf
                mov     bl,ch
                DoNext
JMP_10:         sahf
                mov     ax,si
                mov     ah,[bx]
                mov     si,ax
                DoNext
                CheckAddress

                Opcode  7Ch                     ; JMP ($....,X) **65C02**
                AddTiming 6
                mov     bx,[si]
                lahf
                add     bx,cx
                mov     si,[bx]
                inc     bl
                jz      JMP_20
                sahf
                mov     bl,ch
                DoNext
JMP_20:         sahf
                mov     ax,si
                mov     ah,[bx]
                mov     si,ax
                DoNext
                CheckAddress

                Opcode  20h                     ; JSR $....
                AddTiming 6
                mov     di,si
                mov     si,[si]
                mov     bx,AppleSP
                lahf
                inc     di
                or      bl,bl
                jz      JSR_10
                dec     bx
                mov     [bx],di
                dec     bl
                sahf
                mov     AppleSP,bx
                mov     bl,ch
                DoNext
JSR_10:         sahf
                mov     ax,di
                mov     DS:[StackPage*100h],ah
                mov     DS:[StackPage*100h+0FFh],al
                mov     byte ptr AppleSP,0FEh
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  60h                     ; RTS
                AddTiming 6
                call    synchronize
                mov     bx,AppleSP
                lahf
                inc     bl
                mov     si,[bx]
                inc     bl
                mov     AppleSP,bx
                jz      RTS_10
                inc     si
                sahf
                mov     bl,ch
                DoNext
RTS_10:         mov     bx,si
                mov     bh,DS:[StackPage*100h]
                mov     si,bx
                inc     si
                sahf
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  00h                     ; BRK
                AddTiming 6
                lahf
                mov     al,AppleFlags
                mov     bl,al
                or      al,00000100b
                mov     AppleFlags,al
                mov     al,ah
                and     al,11000000b
                shl     ax,1
                rol     al,3
                ror     ah,1
                rcr     al,1
                or      al,dh
                or      al,bl
                mov     bx,AppleSP
                inc     si
                or      bl,bl
                jz      BRK_10
                dec     bx
                mov     [bx],si
                dec     bl
                mov     [bx],al
                dec     bl
                sahf
                mov     AppleSP,bx
                mov     si,DS:[BRKvector]
                mov     bl,ch
                DoNext
BRK_10:         sahf
                mov     bx,si
                mov     DS:[StackPage*100h],bh
                mov     ah,bl
                mov     DS:[StackPage*100h+0FEh],ax
                mov     byte ptr AppleSP,0FDh
                mov     si,DS:[BRKvector]
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  40h                     ; RTI
                AddTiming 6
                mov     bx,AppleSP
                inc     bl
                mov     al,[bx]
                inc     bl
                mov     si,[bx]
                inc     bl
                mov     AppleSP,bx
                jz      RTI_30
RTI_05:         mov     dh,al
                and     dh,01000001b
                mov     bh,al
                cbw
                shr     al,1
                ror     ax,1
                ror     ah,1
                mov     al,AppleFlags
                mov     bl,al
                and     bx,0000110000110000b
                or      bl,bh
                mov     AppleFlags,bl
                xor     al,bl
                test    al,00001000b
                jnz     RTI_10
                sahf
                mov     bl,ch
                DoNext
RTI_10:         test    bl,00001000b
                mov     bl,ch
                jnz     RTI_20
                jmp     CLD_10
RTI_20:         jmp     SED_10
RTI_30:         mov     bx,si
                mov     bh,DS:[StackPage*100h]
                mov     si,bx
                jmp     RTI_05
                CheckAddress

                Opcode  48h                     ; PHA
                AddTiming 3
                mov     bx,AppleSP
                mov     [bx],dl
                lahf
                dec     bl
                sahf
                mov     AppleSP,bx
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  68h                     ; PLA
                AddTiming 6
                mov     bx,AppleSP
                inc     bl
                mov     dl,[bx]
                mov     AppleSP,bx
                or      dl,dl
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  0DAh                    ; PHX           **65C02**
                AddTiming 3
                mov     bx,AppleSP
                mov     [bx],cl
                lahf
                dec     bl
                sahf
                mov     AppleSP,bx
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  0FAh                    ; PLX           **65C02**
                AddTiming 4
                mov     bx,AppleSP
                inc     bl
                mov     cl,[bx]
                mov     AppleSP,bx
                or      cl,cl
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  5Ah                     ; PHY           **65C02**
                AddTiming 3
                mov     ax,bp
                mov     bx,AppleSP
                mov     [bx],al
                lahf
                dec     bl
                sahf
                mov     AppleSP,bx
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  7Ah                     ; PLY           **65C02**
                AddTiming 4
                mov     bx,AppleSP
                inc     bl
                mov     al,[bx]
                mov     AppleSP,bx
                mov     ah,ch
                mov     bp,ax
                or      al,al
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  08h                     ; PHP
                AddTiming 3
                lahf
                mov     al,ah
                and     al,11000000b
                shl     ax,1
                rol     al,3
                ror     ah,1
                rcr     al,1
                or      al,dh
                or      al,AppleFlags
                mov     bx,AppleSP
                mov     [bx],al
                dec     bl
                sahf
                mov     AppleSP,bx
                mov     bl,ch
                DoNext
                CheckAddress

                Opcode  28h                     ; PLP
                AddTiming 4
                mov     bx,AppleSP
                inc     bl
                mov     al,[bx]
                mov     AppleSP,bx
                mov     dh,al
                and     dh,01000001b
                mov     bh,al
                cbw
                shr     al,1
                ror     ax,1
                ror     ah,1
                mov     al,AppleFlags
                mov     bl,al
                and     bx,0000110000110000b
                or      bl,bh
                mov     AppleFlags,bl
                xor     al,bl
                test    al,00001000b
                jnz     PLP_10
                sahf
                mov     bl,ch
                DoNext
PLP_10:         test    bl,00001000b
                mov     bl,ch
                jnz     PLP_20
                jmp     CLD_10
PLP_20:         jmp     SED_10
                CheckAddress

                Opcode  0E8h                    ; INX
                AddTiming 2
                inc     cl
                DoNext
                CheckAddress

                Opcode  0CAh                    ; DEX
                AddTiming 2
                dec     cl
                DoNext
                CheckAddress

                Opcode  0C8h                    ; INY
                AddTiming 2
                mov     ax,bp
                inc     al
                mov     bp,ax
                DoNext
                CheckAddress

                Opcode  88h                     ; DEY
                AddTiming 2
                mov     ax,bp
                dec     al
                mov     bp,ax
                DoNext
                CheckAddress

                Opcode  0AAh                    ; TAX
                AddTiming 2
                mov     cl,dl
                or      cl,cl
                DoNext
                CheckAddress

                Opcode  0A8h                    ; TAY
                AddTiming 2
                mov     ah,bl
                mov     al,dl
                mov     bp,ax
                or      al,al
                DoNext
                CheckAddress

                Opcode  8Ah                     ; TXA
                AddTiming 2
                mov     dl,cl
                or      dl,dl
                DoNext
                CheckAddress

                Opcode  98h                     ; TYA
                AddTiming 2
                mov     ax,bp
                mov     dl,al
                or      dl,dl
                DoNext
                CheckAddress

                Opcode  0BAh                    ; TSX
                AddTiming 2
                mov     cl,byte ptr AppleSP
                or      cl,cl
                DoNext
                CheckAddress

                Opcode  9Ah                     ; TXS
                AddTiming 2
                mov     byte ptr AppleSP,cl
                DoNext
                CheckAddress

                Opcode  18h                     ; CLC
                AddTiming 2
                rcr     dh,1
                clc
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  38h                     ; SEC
                AddTiming 2
                rcr     dh,1
                stc
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  0B8h                    ; CLV
                AddTiming 2
                rcr     dh,1
                mov     dh,bl
                rcl     dh,1
                DoNext
                CheckAddress

                Opcode  58h                     ; CLI
                AddTiming 2
                lahf
                and     AppleFlags,11111011b
                sahf
                DoNext
                CheckAddress

                Opcode  78h                     ; SEI
                AddTiming 2
                lahf
                or      AppleFlags,00000100b
                sahf
                DoNext
                CheckAddress

                Opcode  0D8h                    ; CLD
                AddTiming 2
                lahf
                and     AppleFlags,11110111b
CLD_10:         sahf
                mov     di,ds
                mov     ax,cs
                mov     ds,ax
                assume  DS:Emulate
                mov     al,0FCh                 ; <cld>
Temp            =       0
                REPT    ADCcounter
Temp            =       Temp+1
                IRP     n,<%Temp>
                mov     ADC&&n,al
                ENDM
                ENDM
Temp            =       0
                REPT    SBCcounter
Temp            =       Temp+1
                IRP     n,<%Temp>
                mov     SBC&&n,al
                ENDM
                ENDM
                mov     ds,di
                assume  DS:Apple
                DoNext
                CheckAddress

                Opcode  0F8h                    ; SED
                AddTiming 2
                lahf
                or      AppleFlags,00001000b
SED_10:         sahf
                mov     di,ds
                mov     ax,cs
                mov     ds,ax
                assume  DS:Emulate
                mov     al,27h                  ; <daa>
Temp            =       0
                REPT    ADCcounter
Temp            =       Temp+1
                IRP     n,<%Temp>
                mov     ADC&&n,al
                ENDM
                ENDM
                mov     al,2Fh                  ; <das>
Temp            =       0
                REPT    SBCcounter
Temp            =       Temp+1
                IRP     n,<%Temp>
                mov     SBC&&n,al
                ENDM
                ENDM
                mov     ds,di
                assume  DS:Apple
                DoNext
                CheckAddress

                Opcode  0EAh                    ; NOP
                AddTiming 2
                DoNext
                CheckAddress

;-------------------------------------------------------------------------------

                Opcode  02h                     ; ???
                jmp     RETapple
BadOpcode:      xchg    bh,bl
                mov     bl,SS:NotInstr[bx]
                lahf
                or      bl,bl
                jns     InvalidInst
                cmp     word ptr [si],UserMask
                je      JumpToUser
                and     bl,7Fh
InvalidInst:    dec     si
                add     si,bx
                sahf
                mov     bl,bh
                DoNext
JumpToUser:     add     si,2
                lodsb
                mov     bl,al
                shl     bx,2
                sahf
                Save    ds es
                pushf
                call    SS:UserAdrs[bx]
                Restore ds es
                mov     bl,0
                DoNext
                CheckAddress

Emulate         ends

User            segment public
                assume  cs:User

BlankU:         iret

DebugU:         jmp     far ptr RETapple

User            ends

Data            segment stack 'stack'

;                       0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F
NotInstr        db      0,0,2,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 00 00 - Debugger
                db      0,0,0,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 10 8x - User
                db      0,0,4,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 20
                db      0,0,0,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 30
                db      0,0,2,2,2,0,0,2,0,0,0,1,0,0,0,4 ; 40
                db      0,0,0,2,3,0,0,2,0,0,0,1,4,0,0,4 ; 50
                db      0,0,3,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 60
                db      0,0,0,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 70
                db      0,0,3,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 80
                db      0,0,0,2,0,0,0,2,0,0,0,1,0,0,0,4 ; 90
                db      0,0,0,2,0,0,0,2,0,0,0,1,0,0,0,4 ; A0
                db      0,0,0,2,0,0,0,2,0,0,0,1,0,0,0,4 ; B0
                db      0,0,2,2,0,0,0,2,0,0,0,1,0,0,0,4 ; C0
                db      0,0,0,2,2,0,0,2,0,0,0,1,3,0,0,4 ; D0
                db      0,0,2,2,0,0,0,2,0,0,0,1,0,0,0,4 ; E0
                db      0,0,0,2,3,0,0,2,0,0,0,1,3,0,0,84 ; F0

		even
UserAdrs        dd      DebugU,BlankU,BlankU,BlankU,BlankU,BlankU,BlankU,BlankU
                dd      BlankU,BlankU,BlankU,BlankU,BlankU,BlankU,BlankU,BlankU
                dd      0F0h dup (BlankU)

Data            ends

;-------------------------------------------------------------------------------

                WriteAllFreeSpace

                End

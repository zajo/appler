;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      CONIO.INC                       |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Keyboard input / screen output  |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|


_GETLINE        =       0
_GL_SYMBOL      =       1
_GL_STRING      =       2
_GL_BYTE        =       3
_GL_GETSYMB     =       4
_GL_LEFT        =       5
_GL_RIGHT       =       6
_GL_INS         =       7
_GL_DEL         =       8
_GL_BACKSPC     =       9
_GL_HOME        =       10
_GL_END         =       11
_GL_CLRBUFF     =       12
_GETCOMMAND     =       13

_CLEARSCREEN    =       0
_SHOWSCREEN     =       1
_SYMBPRINT      =       2
_SYMBPRINTXY    =       3
_BYTEPRINT      =       4
_STRINGPRINT    =       5
_GETSYMB        =       6
_SHOWLINE       =       7
_CALCXY         =       8
_SHOWCURSOR     =       9
_HIDECURSOR     =       10
_SETTEXTMODE    =       11
_SETSCREEN      =       12

GL_ParamStruc   struc
GL_Buffer       dw      ?                       ; Line buffer address
GL_Pos          db      ?                       ; Current cursor position
GL_Length       db      ?                       ; Current line length
GL_MaxLength    db      ?                       ; Max line length
GL_MaxPrint     db      ?                       ; Max number of characters to print
GL_BegPrint     db      ?                       ; Begin print location
GL_InsFlag      db      ?                       ; 0 or 1
GL_InsCurColor  db      ?                       ; Insert cursor color
GL_OverCurColor db      ?                       ; Overwrite cursor color
GL_CX           dw      ?
GL_X            db      ?
GL_Y            db      ?
GL_Color        db      ?                       ; Text color
GL_GS_SpcFl     db      ?
GL_AllowSpc     db      ?                       ; Allow or not the spaces
GL_User         dd      ?                       ; Non-standart functions proc
GL_BegScan      dw      ?                       ; Begin address of the commands
GL_ENDScan      dw      ?                       ; End address of the commands
GL_Error        dw      ?
GL_Eparam       db      ?
GL_ParamStruc   ends

SIO_ParamStruc  struc
SpacesFlag      db      ?                       ; Get symb spaces flag
SP_SourceSeg    dw      ?                       ; String print source seg
SP_bx           dw      ?                       ; String print end bx value
SP_BufFlag      db      ?                       ; String print bufflag
SS_SourceOfs    dw      ?
SS_SourceSeg    dw      ?
CursorLen       db      ?
CursorColor     db      ?
CursorFlag      db      ?
SS_ScreenFlag   db      ?
SIO_ParamStruc  ends

RK_ParamStruc   struc
RK_FkeyFlag     db      ?                       ; Fkeys support flag
RK_FkeyProc     dd      ?                       ; Fkeys support proc
RK_AltFlag      db      ?
RK_AltProc      dd      ?
RK_WaitKeyFlag  db      ?
RK_WaitKeyProc  dd      ?                       ; Call while waiting for a key
RK_ShowAll      dd      ?                       ; ShowAll proc
RK_ErrPtr       dw      ?
RK_ParamStruc   ends

GetLineService  macro   Service
                mov     bp,Service
                call    GL_Services
                endm

ScreenIOservice macro   Service
                mov     bp,Service
                call    SIO_Services
                endm

GotoXY          macro   vtab,htab
                mov     cx,((vtab-1) * 80 * 2) + (htab * 2)
                endm

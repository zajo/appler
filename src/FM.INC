;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      FM.INC                          |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   File Maneger Macros & Stuff     |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

MAX_DIRECTORY_ENTRIES = 100h
MAX_MEMORY_ENTRIES    =  20h

DTA_S           struc
Reserved        db      15h dup (0)
Attributes      db      0
Time            dw      0
Date            dw      0
FileSize        dd      0
FileSpec        db      0Dh dup (0)
                ends

; File Attributes Bitmaps:
FA_READ_ONLY    =       00000001b
FA_HIDDEN       =       00000010b
FA_SYSTEM       =       00000100b
FA_VOLUME_LABEL =       00001000b
FA_DIRECTORY    =       00010000b
FA_ARCHIVE      =       00100000b

FileDescription struc
FileName        db      0Dh dup (0)
FileType        db      0
FileBegAdr      dw      0
FileEndAdr      dw      0
FileLength      dw      0
FileFlags       db      0
File1st4bytes   db      4 dup (0)
                ends

; File Flags Bitmaps:
FF_DAMAGED?     =       00000001b
FF_SHOWADDR?    =       00000010b
FF_MODIFYADDR?  =       00000100b
FF_MODIFYTYPE?  =       00001000b
FF_MODIFYNAME?  =       00010000b

; File Type Codes:
FD_DIRECTORY    =       0
FD_CODE         =       1
FD_STATUS       =       2
FD_MSDOS        =       3

FindFirst       macro
                mov     ah,4Eh
                int     21h
                endm

FindNext        macro
                mov     ah,4Fh
                int     21h
                endm

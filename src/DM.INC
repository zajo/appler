;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      DM.INC                          |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Disk Manager                    |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

DTA_S           struc
Reserved        db      15h dup (0)
Attributes      db      0
Time            dw      0
Date            dw      0
FileSize        dd      0
FileSpec        db      0Dh dup (0)
                ends

DiskDescription struc
FileName        db      0Dh dup (0)
FileType        db      0
FileFlag        db      0
DiskDescription ends

; File Attributes Bitmaps:
FA_READ_ONLY    =       00000001b
FA_HIDDEN       =       00000010b
FA_SYSTEM       =       00000100b
FA_VOLUME_LABEL =       00001000b
FA_DIRECTORY    =       00010000b
FA_ARCHIVE      =       00100000b

; File Flags Bitmaps:
FF_DAMAGED?     =       00000001b
FF_MODIFYTYPE?  =       00000010b
FF_READ_ONLY?   =       00000100b
FF_INSERTED1?   =       00001000b
FF_INSERTED2?   =       00010000b

; File Type Codes:
FD_DIRECTORY    =       0
FD_NIBBLE       =       1
FD_DOS33        =       2

FindFirst       macro
                mov     ah,4Eh
                int     21h
                endm

FindNext        macro
                mov     ah,4Fh
                int     21h
                endm

MS_NORMAL        =      0
MS_ERROR         =      1

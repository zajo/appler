;  _____________________________________________
; |                                             |
; |  Project:   APPLER                          |
; |  File:      INTERFAC.INC                    |
; |  Compiler:  16-bit TASM (2.5)               |
; |                                             |
; |  Subject:   Global Data Definitions         |
; |                                             |
; |  Author:    Emil Dotchevski                 |
; |_____________________________________________|

;---- APPLER SEGMENTS DEFINITIONS ----------------------------------------------

Startup         segment public use16
                ends
Emulate         segment common use16
                ends
Peripher        segment public use16
                ends
Keyboard        segment public use16
                ends
SimKbd          segment public use16
                ends
TaskControl     segment public use16
                ends
CONio           segment public use16
                ends
Debug           segment public use16
                ends
FM              segment public use16
                ends
DM              segment public use16
                ends
KBDsetup        segment public use16
                ends
About           segment public use16
                ends
Help            segment public use16
                ends
User            segment public use16
                ends
Apple           segment public use16
                ends
Data            segment stack 'stack' use16
                ends

;---- GLOBAL SYMBOLS -----------------------------------------------------------

Startup         segment public
                Global  OldDebug                :dword
                Global  OldKbd                  :dword
                Global  DosShell                :far
                Global  QuitAppler              :far
                Global  Buffer1000h             :byte
                Global  Screen                  :word
                Global  StartupON               :far
                Global  StartupOFF              :far
                Global  InitData                :near
Startup         ends

Emulate         segment common
                Global  DRAM_ModefyAdr          :word
                Global  DRAM_ReadWrite          :abs
                Global  DRAM_WriteOnly          :abs
                Global  DRAM_DoNotWrite         :abs
                Global  TEXT_ModefyAdr          :word
                Global  TEXT_TextMode           :abs
                Global  TEXT_GrMode             :abs
                Global  TEXT_MixedGrMode        :abs
                Global  TEXT_MixedHgrMode       :abs
                Global  TEXT_NA                 :abs
                Global  HGR_ModefyAdr           :word
                Global  HGR_HgrMode             :abs
                Global  HGR_MixedMode           :abs
                Global  HGR_NA                  :abs
                Global  PowerON                 :far
                Global  RESET                   :far
                Global  SetScrEntry             :far
                Global  ChangeTEXTcolor         :far
                Global  C000                    :byte
                Global  C050                    :byte
                Global  C080                    :byte
                Global  SaveStack               :word
                Global  ResetFlag               :byte
                Global  AppleSP                 :word
                Global  AppleFlags              :byte
                Global  HGRcolor                :byte
                Global  Port3?4h                :word
                Global  MixedHgrMode1           :near
                Global  MixedHgrMode2           :near
                Global  Synchronize             :near
                Global  C0612r                  :near
                Global  C0645r                  :near
                Global  C061r                   :near
                Global  C062r                   :near
                Global  C064r                   :near
                Global  C065r                   :near
                Global  C030r                   :near
                Global  C020r                   :near
                Global  C030w                   :near
                Global  C020w                   :near
                Global  JoyButton1              :byte
                Global  JoyButton2              :byte
                Global  JoyStick                :byte
                Global  synchro_push_ax         :byte
                Global  DRAMSave                :far
                Global  DRAMLoad                :far
Emulate         ends

Peripher        segment public
                Global  SystemINIT              :far
                Global  SystemTINI              :far
                Global  SystemRESET             :far
                Global  TimerINIT               :far
                Global  TimerTINI               :far
                Global  TimerReq                :far
                Global  FlushBuffer             :far
                Global  ReadTrack               :far
                Global  FloppySave              :far
                Global  FloppyLoad              :far
                Global  TimerFlags              :word
                Global  SectorImage             :byte
                Global  SectorImageF            :byte
                Global  CurrentDrive            :byte
                Global  OtherDrive              :byte
                Global  FLAGS                   :byte
                Global  BufferPTR               :word
                Global  WriteCNT                :word
                Global  WriteREG                :byte
Peripher        ends

Data            segment stack 'stack'
                Global  C0XXRead                :word
                Global  C0XXWrite               :word
                Global  DRAM                    :byte
                Global  HGRadr                  :word
                Global  TEXTadr                 :word
                Global  TEXTchars               :word
                Global  GRcolors                :byte
                Global  HGRcolors               :word
                Global  HGRmasks                :word
                Global  HGRchars                :word
                Global  HgrTextAdr              :word
                Global  DACtable                :byte
                Global  Bank1                   :byte
                Global  Bank2                   :byte
Data            ends

Keyboard        segment public
                Global  k_Table                 :word
                Global  k_Shifts                :word
                Global  k_ScanCode              :byte
                Global  k_AppleTable            :word
                Global  k_DebugTable            :word
                Global  k_KbdSetupTable         :word
                Global  k_BufferFlag            :byte
                Global  k_KeyPressed            :byte
                Global  a_NormalTable           :byte
                Global  a_CtrlTable             :byte
                Global  a_ShiftTable            :byte
                Global  a_CapsTable             :byte
                Global  a_CpsShfTable           :byte
                Global  a_AltTable              :byte
                Global  K_KeyboardRet1          :byte
                Global  K_KeyboardRet2          :byte
                Global  K_KeyboardRet3          :byte
                Global  K_KeyboardRet4          :byte
                Global  K_SendCommand           :far
                Global  K_SendData              :far
                Global  K_GetData               :far
                Global  SetLEDs                 :far
                Global  ClearBuffer             :far
                Global  GetBuffer               :far
                Global  k_int09                 :far
                Global  get_table_ofs           :far
Keyboard        ends

SimKbd          segment public
                Global  SimKbdRq                :far
                Global  SimKbdClr               :far
                Global  StartRecord             :far
                Global  StopRecord              :far
                Global  key_taken               :far
SimKbd          ends

TaskControl     segment public
                Global  RETapple                :far
                Global  TaskSwitch              :far
                Global  CALLPowerOn             :far
                Global  WaitInstrEnd            :far
                Global  EnableTaskSwitch        :byte
                Global  RetWhere?               :byte
                Global  T_Iflags                :byte
                Global  r_A                     :byte
                Global  r_X                     :byte
                Global  r_Y                     :byte
                Global  r_S                     :byte
                Global  r_P                     :byte
                Global  r_PC                    :word
TaskControl     ends

CONio           segment public
                Global  GL_Services             :far
                Global  SIO_Services            :far
                Global  ReadKey                 :far
                Global  AppleKeysOn             :far
                Global  DebugKeysOn             :far
                Global  ScreenSwapReq           :far
                Global  GL_ParamsAdr            :dword
                Global  GL_ParamsOfs            :word
                Global  GL_ParamsSeg            :word
                Global  SIO_ParamsAdr           :dword
                Global  SIO_ParamsOfs           :word
                Global  SIO_ParamsSeg           :word
                Global  RK_ParamsAdr            :dword
                Global  RK_ParamsOfs            :word
                Global  RK_ParamsSeg            :word
                Global  DKO_OldBuffFlag         :byte
                Global  SwapFlag                :byte
CONio           ends

Debug           segment public
                Global  DebugMainRet            :far
                Global  DebugInInit             :far
                Global  DebugOutInit            :far
                Global  SetBreaks               :far
                Global  UnsetBreaks             :far
                Global  F1_or_Invalid?          :byte
Debug           ends

FM              segment public
                Global  FM_MainRet              :far
                Global  FMInInit                :far
                Global  FMOutInit               :far
                Global  FileIsLoaded            :far
                Global  AddExt                  :far
                Global  ResetAppleII            :far
FM              ends

DM              segment public
                Global  DM_MainRet              :far
                Global  DMInInit                :far
                Global  DMOutInit               :far
                Global  OpenDiskFile            :far
                Global  OpenDiskFile1           :far
                Global  OpenDiskFile2           :far
                Global  CloseDiskFile1          :far
                Global  CloseDiskFile2          :far
                Global  DMentry                 :far
DM              ends

KBDsetup        segment public
                Global  KBDsetupRET             :far
                Global  KBDSetupInInit          :far
                Global  KBDSetupOutInit         :far
                Global  UpdateKeyboard          :far
KBDsetup        ends

About           segment public
                Global  AboutMainRet            :far
                Global  AboutInInit             :far
                Global  AboutOutInit            :far
About           ends

Help            segment public
                Global  HelpMainRet             :far
                Global  HelpInInit              :far
                Global  HelpOutInit             :far
Help            ends

Video           segment at 0A000h use16
Video           ends

ApplerVideo     segment at 0B800h use16
ApplerVideo     ends

User            segment public
User            ends

Apple           segment public
Apple           ends

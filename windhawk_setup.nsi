; ==============================================================================
; Windhawk Installer Script (NSIS 3.x)
; Customized with Zero-UAC Administrator Command Prompt Feature
; ==============================================================================

Unicode True
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

; ------------------------------------------------------------------------------
; General Definitions
; ------------------------------------------------------------------------------
!define PRODUCT_NAME "Windhawk"
!define PRODUCT_VERSION "1.5.0"
!define PRODUCT_PUBLISHER "Ramen Software"
!define PRODUCT_WEB_SITE "https://windhawk.net"
!define PRODUCT_DIR_REGKEY "Software\Windhawk"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"

Name "${PRODUCT_NAME}"
OutFile "windhawk_setup.exe"
InstallDir "$PROGRAMFILES64\Windhawk"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir"
RequestExecutionLevel admin

; ------------------------------------------------------------------------------
; UI / Icons
; ------------------------------------------------------------------------------
!define MUI_ICON "src\windhawk\app\rsrc\app.ico"
!define MUI_UNICON "src\windhawk\app\rsrc\app.ico"
!define MUI_ABORTWARNING

; ------------------------------------------------------------------------------
; Variables
; ------------------------------------------------------------------------------
Var InstallMode ; 0 = Standard (Service), 1 = Portable
Var IsUpdate    ; 0 = Fresh Install, 1 = Update
Var DetectedDir

; ------------------------------------------------------------------------------
; Installer Pages
; ------------------------------------------------------------------------------
!insertmacro MUI_PAGE_WELCOME

; Custom installation options page
Page custom InstallationTypePage InstallationTypePageLeave

!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

; Finish Page
!define MUI_FINISHPAGE_RUN "$INSTDIR\windhawk.exe"
!define MUI_FINISHPAGE_RUN_PARAMETERS "-tray-only"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Windhawk Tray Icon"
!insertmacro MUI_PAGE_FINISH

; ------------------------------------------------------------------------------
; Uninstaller Pages
; ------------------------------------------------------------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; ------------------------------------------------------------------------------
; Languages
; ------------------------------------------------------------------------------
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

; ------------------------------------------------------------------------------
; Custom Installation Type Page (Standard vs Portable)
; ------------------------------------------------------------------------------
Var Dialog
Var RadioStandard
Var RadioPortable

Function InstallationTypePage
    ${If} $IsUpdate == 1
        !insertmacro MUI_HEADER_TEXT "检测到已安装程序 (Update / Upgrade)" "已自动检测到现有的 Windhawk 安装路径，将保留配置并进行更新。"
    ${Else}
        !insertmacro MUI_HEADER_TEXT "选择安装类型 (Choose Installation Type)" "选择您希望如何安装 ${PRODUCT_NAME}。"
    ${EndIf}

    nsDialogs::Create 1018
    Pop $Dialog
    ${If} $Dialog == error
        Abort
    ${EndIf}

    ${If} $IsUpdate == 1
        ${NSD_CreateLabel} 20u 5u 260u 16u "检测到现有安装目录：$\r$\n$INSTDIR"
        Pop $0
        ${NSD_CreateRadioButton} 20u 26u 260u 12u "标准安装/服务更新 (Standard - 推荐，含系统服务与免UAC提权)"
        Pop $RadioStandard
        ${NSD_CreateRadioButton} 20u 46u 260u 12u "便携模式安装 (Portable - 无服务，数据保存在程序目录)"
        Pop $RadioPortable
    ${Else}
        ${NSD_CreateRadioButton} 20u 20u 260u 12u "标准安装 (Standard - 推荐，包含系统服务与免UAC提权)"
        Pop $RadioStandard
        ${NSD_CreateRadioButton} 20u 50u 260u 12u "便携模式 (Portable - 无服务，数据保存在程序目录)"
        Pop $RadioPortable
    ${EndIf}

    ${If} $InstallMode == 1
        ${NSD_Check} $RadioPortable
    ${Else}
        ${NSD_Check} $RadioStandard
    ${EndIf}

    nsDialogs::Show
FunctionEnd

Function InstallationTypePageLeave
    ${NSD_GetState} $RadioPortable $0
    ${If} $0 == ${BST_CHECKED}
        StrCpy $InstallMode 1
        ${If} $IsUpdate == 0
        ${AndIf} $INSTDIR == "$PROGRAMFILES64\Windhawk"
            StrCpy $INSTDIR "$DESKTOP\Windhawk"
        ${EndIf}
    ${Else}
        StrCpy $InstallMode 0
        ${If} $IsUpdate == 0
        ${AndIf} $INSTDIR == "$DESKTOP\Windhawk"
            StrCpy $INSTDIR "$PROGRAMFILES64\Windhawk"
        ${EndIf}
    ${EndIf}
FunctionEnd

; ------------------------------------------------------------------------------
; Initialization & Command Line Parsing
; ------------------------------------------------------------------------------
Function .onInit
    ; Default values
    StrCpy $InstallMode 0
    StrCpy $IsUpdate 0
    StrCpy $DetectedDir ""

    ; 1. Check registry (64-bit view then 32-bit view) to detect existing installation
    SetRegView 64
    ReadRegStr $0 HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir"
    ${If} $0 == ""
        ReadRegStr $0 HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation"
    ${EndIf}

    SetRegView 32
    ${If} $0 == ""
        ReadRegStr $0 HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir"
    ${EndIf}
    ${If} $0 == ""
        ReadRegStr $0 HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation"
    ${EndIf}

    ; If an existing installation directory is found and contains windhawk files
    ${If} $0 != ""
    ${AndIf} ${FileExists} "$0\windhawk.exe"
        StrCpy $DetectedDir $0
        StrCpy $INSTDIR $0
        StrCpy $IsUpdate 1

        ; Detect whether existing installation was portable or standard
        ${If} ${FileExists} "$0\windhawk.ini"
            ReadINIStr $1 "$0\windhawk.ini" "Storage" "Portable"
            ${If} $1 == "1"
                StrCpy $InstallMode 1
            ${Else}
                StrCpy $InstallMode 0
            ${EndIf}
        ${EndIf}
    ${Else}
        StrCpy $INSTDIR "$PROGRAMFILES64\Windhawk"
    ${EndIf}

    ; Parse command line flags
    ${GetParameters} $R0
    ${GetOptions} $R0 "/PORTABLE" $R1
    ${IfNot} ${Errors}
        StrCpy $InstallMode 1
        ${If} $IsUpdate == 0
            StrCpy $INSTDIR "$DESKTOP\Windhawk"
        ${EndIf}
    ${EndIf}

    ${GetOptions} $R0 "/STANDARD" $R1
    ${IfNot} ${Errors}
        StrCpy $InstallMode 0
        ${If} $IsUpdate == 0
            StrCpy $INSTDIR "$PROGRAMFILES64\Windhawk"
        ${EndIf}
    ${EndIf}
FunctionEnd

; ------------------------------------------------------------------------------
; Main Installation Section
; ------------------------------------------------------------------------------
Section "MainSection" SEC01
    SetOutPath "$INSTDIR"
    ; Stop existing instances if running
    DetailPrint "Stopping existing Windhawk processes and service..."
    ${If} ${FileExists} "$INSTDIR\windhawk.exe"
        nsExec::Exec '"$INSTDIR\windhawk.exe" -exit -wait -timeout 3000'
    ${EndIf}
    nsExec::Exec 'net stop Windhawk'
    nsExec::Exec 'sc stop Windhawk'
    nsExec::Exec 'taskkill /F /IM windhawk.exe'
    nsExec::Exec 'taskkill /F /IM windhawk-ui.exe'
    Sleep 1000

    ; Robust in-use file replacement: rename locked DLLs/EXEs to .old before overwriting
    Delete "$INSTDIR\32\windhawk.dll.old"
    Rename "$INSTDIR\32\windhawk.dll" "$INSTDIR\32\windhawk.dll.old"
    Delete "$INSTDIR\64\windhawk.dll.old"
    Rename "$INSTDIR\64\windhawk.dll" "$INSTDIR\64\windhawk.dll.old"
    Delete "$INSTDIR\arm64\windhawk.dll.old"
    Rename "$INSTDIR\arm64\windhawk.dll" "$INSTDIR\arm64\windhawk.dll.old"
    Delete "$INSTDIR\windhawk.dll.old"
    Rename "$INSTDIR\windhawk.dll" "$INSTDIR\windhawk.dll.old"
    Delete "$INSTDIR\windhawk.exe.old"
    Rename "$INSTDIR\windhawk.exe" "$INSTDIR\windhawk.exe.old"

    Delete /REBOOTOK "$INSTDIR\32\windhawk.dll.old"
    Delete /REBOOTOK "$INSTDIR\64\windhawk.dll.old"
    Delete /REBOOTOK "$INSTDIR\arm64\windhawk.dll.old"
    Delete /REBOOTOK "$INSTDIR\windhawk.dll.old"
    Delete /REBOOTOK "$INSTDIR\windhawk.exe.old"

    ; Create subdirectories
    CreateDirectory "$INSTDIR\32"
    CreateDirectory "$INSTDIR\64"
    CreateDirectory "$INSTDIR\arm64"

    ; Copy binaries
    File "Windhawk_AdminCmd_Release\windhawk.exe"
    File "Windhawk_AdminCmd_Release\windhawk.dll"

    SetOutPath "$INSTDIR\32"
    File "Windhawk_AdminCmd_Release\32\windhawk.dll"

    SetOutPath "$INSTDIR\64"
    File "Windhawk_AdminCmd_Release\64\windhawk.dll"

    SetOutPath "$INSTDIR\arm64"
    File "Windhawk_AdminCmd_Release\arm64\windhawk.dll"

    SetOutPath "$INSTDIR"

    ; Handle Configs based on InstallMode
    ${If} $InstallMode == 0
        SetShellVarContext all

        ; Standard Mode configuration
        FileOpen $0 "$INSTDIR\windhawk.ini" w
        FileWrite $0 "[Storage]$\r$\n"
        FileWrite $0 "EnginePath=.$\r$\n"
        FileWrite $0 "AppDataPath=%ProgramData%\Windhawk$\r$\n"
        FileWrite $0 "RegistryKey=HKLM\Software\Windhawk$\r$\n"
        FileWrite $0 "Portable=0$\r$\n"
        FileClose $0

        FileOpen $0 "$INSTDIR\engine.ini" w
        FileWrite $0 "[Storage]$\r$\n"
        FileWrite $0 "AppDataPath=%ProgramData%\Windhawk\Engine$\r$\n"
        FileWrite $0 "RegistryKey=HKLM\Software\Windhawk\Engine$\r$\n"
        FileWrite $0 "Portable=0$\r$\n"
        FileClose $0

        ; Create AppData/Engine directories in ProgramData ($APPDATA with SetShellVarContext all is C:\ProgramData)
        CreateDirectory "$APPDATA\Windhawk"
        CreateDirectory "$APPDATA\Windhawk\Engine"

        ; Register & Start Windows Service
        DetailPrint "Registering Windhawk SYSTEM Service..."
        nsExec::Exec 'sc stop Windhawk'
        nsExec::Exec 'sc delete Windhawk'
        nsExec::Exec 'sc create Windhawk binPath= "\"$INSTDIR\windhawk.exe\" -service" start= auto DisplayName= "Windhawk"'
        nsExec::Exec 'sc description Windhawk "Windhawk customization service and zero-UAC elevation provider"'
        DetailPrint "Starting Windhawk Service..."
        nsExec::Exec 'sc start Windhawk'

        ; Create Shortcuts
        CreateDirectory "$SMPROGRAMS\${PRODUCT_NAME}"
        CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk" "$INSTDIR\windhawk.exe" "-tray-only" "$INSTDIR\windhawk.exe" 0
        CreateShortcut "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall ${PRODUCT_NAME}.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
        CreateShortcut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\windhawk.exe" "-tray-only" "$INSTDIR\windhawk.exe" 0

        ; Create Uninstaller
        WriteUninstaller "$INSTDIR\uninstall.exe"

        ; Write Registry entries for Add/Remove Programs (both 64-bit and 32-bit views)
        SetRegView 64
        WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir" "$INSTDIR"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME} (Zero-UAC Admin CMD)"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayIcon" '"$INSTDIR\windhawk.exe",0'
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1

        SetRegView 32
        WriteRegStr HKLM "${PRODUCT_DIR_REGKEY}" "InstallDir" "$INSTDIR"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME} (Zero-UAC Admin CMD)"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayIcon" '"$INSTDIR\windhawk.exe",0'
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
        WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoModify" 1
        WriteRegDWORD HKLM "${PRODUCT_UNINST_KEY}" "NoRepair" 1

    ${Else}
        SetShellVarContext current

        ; Portable Mode configuration
        CreateDirectory "$INSTDIR\Data"
        CreateDirectory "$INSTDIR\Data\Engine"

        FileOpen $0 "$INSTDIR\windhawk.ini" w
        FileWrite $0 "[Storage]$\r$\n"
        FileWrite $0 "EnginePath=.$\r$\n"
        FileWrite $0 "AppDataPath=Data$\r$\n"
        FileWrite $0 "Portable=1$\r$\n"
        FileClose $0

        FileOpen $0 "$INSTDIR\engine.ini" w
        FileWrite $0 "[Storage]$\r$\n"
        FileWrite $0 "AppDataPath=Data\Engine$\r$\n"
        FileWrite $0 "Portable=1$\r$\n"
        FileClose $0
    ${EndIf}
SectionEnd

; ------------------------------------------------------------------------------
; Uninstaller Section
; ------------------------------------------------------------------------------
Section "Uninstall"
    SetShellVarContext all

    ; Terminate tray/app
    nsExec::Exec 'taskkill /F /IM windhawk.exe'
    Sleep 1000

    ; Stop and delete service
    nsExec::Exec 'sc stop Windhawk'
    nsExec::Exec 'sc delete Windhawk'

    ; Delete shortcuts
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\${PRODUCT_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRODUCT_NAME}\Uninstall ${PRODUCT_NAME}.lnk"
    RMDir "$SMPROGRAMS\${PRODUCT_NAME}"
    Delete "$DESKTOP\${PRODUCT_NAME}.lnk"

    ; Delete files
    Delete "$INSTDIR\32\windhawk.dll"
    Delete "$INSTDIR\64\windhawk.dll"
    Delete "$INSTDIR\arm64\windhawk.dll"
    Delete "$INSTDIR\windhawk.dll"
    Delete "$INSTDIR\windhawk.exe"
    Delete "$INSTDIR\windhawk.ini"
    Delete "$INSTDIR\engine.ini"
    Delete "$INSTDIR\uninstall.exe"

    RMDir "$INSTDIR\32"
    RMDir "$INSTDIR\64"
    RMDir "$INSTDIR\arm64"
    RMDir "$INSTDIR"

    ; Delete Registry entries
    SetRegView 64
    DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
    DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"
    SetRegView 32
    DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
    DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"

    SetAutoClose true
SectionEnd

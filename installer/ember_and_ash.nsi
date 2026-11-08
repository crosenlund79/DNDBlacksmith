; Ember & Ash — Windows installer (NSIS). Built by .github/workflows/windows-installer.yml:
;   makensis -DVERSION=<version> installer/ember_and_ash.nsi
; Expects the exported game in build/windows/ (EmberAndAsh.exe with the embedded .pck).
Unicode true
!include "MUI2.nsh"

!define APPNAME "Ember & Ash"
!define APPKEY "EmberAndAsh"
!ifndef VERSION
  !define VERSION "0.10"
!endif

Name "${APPNAME}"
OutFile "../build/EmberAndAsh-Setup.exe"
InstallDir "$PROGRAMFILES64\Ember and Ash"
InstallDirRegKey HKLM "Software\${APPKEY}" "InstallDir"
RequestExecutionLevel admin
BrandingText "${APPNAME} ${VERSION}"
VIProductVersion "0.12.0.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "FileDescription" "${APPNAME} installer"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\EmberAndAsh.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Light the forge (start ${APPNAME})"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Ember & Ash" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "../build/windows/EmberAndAsh.exe"
  File /nonfatal "../build/windows/EmberAndAsh.console.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\EmberAndAsh.exe"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk" "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\EmberAndAsh.exe"
  WriteRegStr HKLM "Software\${APPKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}" "Publisher" "Ember & Ash"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}" "DisplayIcon" "$INSTDIR\EmberAndAsh.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\EmberAndAsh.exe"
  Delete "$INSTDIR\EmberAndAsh.console.exe"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  Delete "$SMPROGRAMS\${APPNAME}\Uninstall ${APPNAME}.lnk"
  RMDir "$SMPROGRAMS\${APPNAME}"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}"
  DeleteRegKey HKLM "Software\${APPKEY}"
SectionEnd

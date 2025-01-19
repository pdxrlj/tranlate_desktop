#define MyAppName "Translate Desktop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "智能翻译助手"
#define MyAppExeName "translate_desktop.exe"

[Setup]
; 必需的设置
AppId={{com.yourcompany.translatedesktop}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=installer
OutputBaseFilename=translate_desktop
Compression=lzma
SolidCompression=yes
; 允许用户选择安装目录
DisableDirPage=no
AllowNoIcons=yes
; 允许用户选择开始菜单目录
DisableProgramGroupPage=no
; 要求管理员权限
PrivilegesRequired=admin
; 添加卸载信息
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
; 添加安装程序图标和标题
SetupIconFile="C:\Users\ruanyu\Code\flutter_demo\tranlate_desktop\build\windows\x64\runner\Release\data\flutter_assets\assets\app_icon.ico"
WizardStyle=modern
WizardSizePercent=120
; 添加完整卸载
Uninstallable=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 注意: 不要在 SourceDir 中使用 "Flags: ignoreversion" 于 DLL, OCX 等系统文件
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Registry]
; 删除应用程序设置
Root: HKCU; Subkey: "Software\{#MyAppPublisher}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run\{#MyAppName}"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"; ValueType: string; ValueName: "{app}\{#MyAppExeName}"; Flags: uninsdeletevalue

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"
Type: files; Name: "{userappdata}\Microsoft\Windows\Start Menu\Programs\{#MyAppName}\*"
Type: dirifempty; Name: "{userappdata}\Microsoft\Windows\Start Menu\Programs\{#MyAppName}"
Type: files; Name: "{commonappdata}\Microsoft\Windows\Start Menu\Programs\{#MyAppName}\*"
Type: dirifempty; Name: "{commonappdata}\Microsoft\Windows\Start Menu\Programs\{#MyAppName}"
Type: dirifempty; Name: "{app}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; 在卸载前关闭应用程序
Filename: "taskkill.exe"; Parameters: "/F /IM ""{#MyAppExeName}"""; Flags: runhidden
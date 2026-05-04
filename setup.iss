; ── WeNote 安装脚本 ────────────────────────────────────────
; 使用 Inno Setup 6 编译

#define MyAppName "WeNote"
#define MyAppNameCN "微记"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "baituo"
#define MyAppURL "https://github.com/baituoo/WeNote"
#define MyAppExeName "WeNote.exe"

[Setup]
; 基本信息
AppId={{B8F4A3D2-7E5C-4A1B-9F6D-3C8E2A5B1D7F}
AppName={#MyAppName}
AppVerName={#MyAppNameCN} {#MyAppVersion}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; 安装路径
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppNameCN}
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog

; 输出文件
OutputDir=.
OutputBaseFilename=WeNote_Setup_v{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

; 语言
[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式"

[Files]
; 主程序和所有依赖文件
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs
; 开源协议
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; 开始菜单
Name: "{autoprograms}\{#MyAppNameCN}"; Filename: "{app}\{#MyAppExeName}"
; 桌面快捷方式（可选）
Name: "{autodesktop}\{#MyAppNameCN}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; 安装完成后运行程序
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppNameCN}"; Flags: nowait postinstall skipifsilent

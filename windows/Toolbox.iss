#define MyAppName "Docker Toolbox"
#define MyAppPublisher "Docker"
#define MyAppURL "https://docker.com"
#define MyAppContact "https://docker.com"

#define b2dIsoPath "..\bundle\boot2docker.iso"
#define dockerCli "..\bundle\docker.exe"
#define dockerMachineCli "..\bundle\docker-machine.exe"
#define dockerComposeCli "..\bundle\docker-compose.exe"
#define kitematic "..\bundle\kitematic"
#define virtualBoxCommon "..\bundle\common.cab"
#define virtualBoxMsi "..\bundle\VirtualBox_amd64.msi"

[Setup]
AppCopyright={#MyAppPublisher}
AppId={{FC4417F0-D7F3-48DB-BCE1-F5ED5BAFFD91}
AppContact={#MyAppContact}
AppComments={#MyAppURL}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName=Docker
DisableProgramGroupPage=yes
OutputBaseFilename=DockerToolbox
Compression=lzma
SolidCompression=yes
WizardImageFile=windows-installer-side.bmp
WizardSmallImageFile=windows-installer-logo.bmp
WizardImageStretch=yes
UninstallDisplayIcon={app}\unins000.exe
SetupIconFile=toolbox.ico
ChangesEnvironment=true

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Run]
Filename: "{win}\explorer.exe"; Parameters: "{userprograms}\Docker\"; Flags: postinstall skipifsilent; Description: "View Shortcuts in File Explorer"

[Tasks]
Name: desktopicon; Description: "{cm:CreateDesktopIcon}"
Name: modifypath; Description: "Add docker binaries to &PATH"
Name: upgradevm; Description: "Upgrade Boot2Docker VM"

[Components]
Name: "Docker"; Description: "Docker Client for Windows" ; Types: full custom; Flags: fixed
Name: "DockerMachine"; Description: "Docker Machine for Windows" ; Types: full custom; Flags: fixed
Name: "DockerCompose"; Description: "Docker Compose for Windows" ; Types: full custom
Name: "VirtualBox"; Description: "VirtualBox"; Types: full custom; Flags: disablenouninstallwarning
Name: "Kitematic"; Description: "Kitematic for Windows (Alpha)" ; Types: full custom

[Files]
Source: "{#dockerCli}"; DestDir: "{app}"; Flags: ignoreversion; Components: "Docker"
Source: ".\Start-DockerMachine.ps1"; DestDir: "{app}"; Flags: ignoreversion; Components: "Docker"
Source: "{#dockerMachineCli}"; DestDir: "{app}"; Flags: ignoreversion; Components: "DockerMachine"
Source: "{#dockerComposeCli}"; DestDir: "{app}"; Flags: ignoreversion; Components: "DockerCompose"
Source: "{#kitematic}\*"; DestDir: "{app}\kitematic"; Flags: ignoreversion recursesubdirs; Components: "Kitematic"
Source: "{#b2dIsoPath}"; DestDir: "{app}"; Flags: ignoreversion; Components: "DockerMachine"; AfterInstall: CopyBoot2DockerISO()
Source: "{#virtualBoxCommon}"; DestDir: "{app}\installers\virtualbox"; Components: "VirtualBox"
Source: "{#virtualBoxMsi}"; DestDir: "{app}\installers\virtualbox"; DestName: "virtualbox.msi"; AfterInstall: RunInstallVirtualBox(); Components: "VirtualBox"

[Icons]
Name: "{userprograms}\Docker\Kitematic (Alpha)"; WorkingDir: "{app}"; Filename: "{app}\kitematic\Kitematic.exe"; Components: "Kitematic"
Name: "{commondesktop}\Kitematic (Alpha)"; WorkingDir: "{app}"; Filename: "{app}\kitematic\Kitematic.exe"; Tasks: desktopicon; Components: "Kitematic"

[UninstallRun]
Filename: "{app}\docker-machine.exe"; Parameters: "rm -f default"

[UninstallDelete]
Type: filesandordirs; Name: "{localappdata}\..\Roaming\Kitematic"

[Registry]
Root: HKCU; Subkey: "Environment"; ValueType:string; ValueName:"DOCKER_TOOLBOX_INSTALL_PATH"; ValueData:"{app}" ; Flags: preservestringtype ;

[Code]
#include "base64.iss"
#include "guid.iss"

var
  TrackingDisabled: Boolean;
//  TrackingCheckBox: TNewCheckBox;

function uuid(): String;
var
  dirpath: String;
  filepath: String;
  ansiresult: AnsiString;
begin
  dirpath := ExpandConstant('{userappdata}\DockerToolbox');
  filepath := dirpath + '\id.txt';
  ForceDirectories(dirpath);

  Result := '';
  if FileExists(filepath) then
    LoadStringFromFile(filepath, ansiresult);
    Result := String(ansiresult)

  if Length(Result) = 0 then
    Result := GetGuid('');
    StringChangeEx(Result, '{', '', True);
    StringChangeEx(Result, '}', '', True);
    SaveStringToFile(filepath, AnsiString(Result), False);
end;

function WindowsVersionString(): String;
var
  ResultCode: Integer;
  lines : TArrayOfString;
begin
  if not Exec(ExpandConstant('{cmd}'), ExpandConstant('/c wmic os get caption | more +1 > C:\windows-version.txt'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
    Result := 'N/A';
    exit;
  end;

  if LoadStringsFromFile(ExpandConstant('C:\windows-version.txt'), lines) then begin
    Result := lines[0];
  end else begin
    Result := 'N/A'
  end;
end;

procedure TrackEventWithProperties(name: String; properties: String);
var
  payload: String;
  WinHttpReq: Variant;
begin
  if TrackingDisabled or WizardSilent() then
    exit;

  if Length(properties) > 0 then
    properties := ', ' + properties;

  try
//    payload := Encode64(Format(ExpandConstant('{{"event": "%s", "properties": {{"token": "{#MixpanelToken}", "distinct_id": "%s", "os": "win32", "os version": "%s", "version": "{#MyAppVersion}" %s}}'), [name, uuid(), WindowsVersionString(), properties]));
    payload := '';
    WinHttpReq := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    WinHttpReq.Open('POST', 'https://api.mixpanel.com/track/?data=' + payload, false);
    WinHttpReq.SetRequestHeader('Content-Type', 'application/json');
    WinHttpReq.Send('');
  except
  end;
end;

procedure TrackEvent(name: String);
begin
  TrackEventWithProperties(name, '');
end;

function NeedToInstallVirtualBox(): Boolean;
begin
  // TODO: Also compare versions
  Result := (
    (GetEnv('VBOX_INSTALL_PATH') = '')
    and
    (GetEnv('VBOX_MSI_INSTALL_PATH') = '')
  );
end;

function VBoxPath(): String;
begin
  if GetEnv('VBOX_INSTALL_PATH') <> '' then
    Result := GetEnv('VBOX_INSTALL_PATH')
  else
    Result := GetEnv('VBOX_MSI_INSTALL_PATH')
end;

procedure InitializeWizard;
var
  WelcomePage: TWizardPage;
//  TrackingLabel: TLabel;
begin
  TrackingDisabled := True;  // Remove this if we re-enable tracking
  WelcomePage := PageFromID(wpWelcome)

  WizardForm.WelcomeLabel2.AutoSize := True;

//  TrackingCheckBox := TNewCheckBox.Create(WizardForm);
//  TrackingCheckBox.Top := WizardForm.WelcomeLabel2.Top + WizardForm.WelcomeLabel2.Height + 10;
//  TrackingCheckBox.Left := WizardForm.WelcomeLabel2.Left;
//  TrackingCheckBox.Width := WizardForm.WelcomeLabel2.Width;
//  TrackingCheckBox.Height := 28;
//  TrackingCheckBox.Caption := 'Help Docker improve Toolbox.';
//  TrackingCheckBox.Checked := True;
//  TrackingCheckBox.Parent := WelcomePage.Surface;

//  TrackingLabel := TLabel.Create(WizardForm);
//  TrackingLabel.Parent := WelcomePage.Surface;
//  TrackingLabel.Font := WizardForm.WelcomeLabel2.Font;
//  TrackingLabel.Font.Color := clGray;
//  TrackingLabel.Caption := 'This collects anonymous data to help us detect installation problems and improve the overall experience. We only use it to aggregate statistics and will never share it with third parties.';
//  TrackingLabel.WordWrap := True;
//  TrackingLabel.Visible := True;
//  TrackingLabel.Left := WizardForm.WelcomeLabel2.Left;
//  TrackingLabel.Width := WizardForm.WelcomeLabel2.Width;
//  TrackingLabel.Top := TrackingCheckBox.Top + TrackingCheckBox.Height + 5;
//  TrackingLabel.Height := 100;

    // Don't do this until we can compare versions
    // Wizardform.ComponentsList.Checked[3] := NeedToInstallVirtualBox();
    Wizardform.ComponentsList.ItemEnabled[3] := not NeedToInstallVirtualBox();
end;

function InitializeSetup(): boolean;
begin
  TrackEvent('Installer Started');
  Result := True;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  if CurPageID = wpWelcome then begin
      //if TrackingCheckBox.Checked then begin
      if False then begin
        TrackEventWithProperties('Continued from Overview', '"Tracking Enabled": "Yes"');
        TrackingDisabled := False;
        DeleteFile(ExpandConstant('{userdocs}\..\.docker\machine\no-error-report'));
      end else begin
        TrackEventWithProperties('Continued from Overview', '"Tracking Enabled": "No"');
        TrackingDisabled := True;
        CreateDir(ExpandConstant('{userdocs}\..\.docker\machine'));
        SaveStringToFile(ExpandConstant('{userdocs}\..\.docker\machine\no-error-report'), '', False);
      end;
  end;
  Result := True
end;

procedure RunInstallVirtualBox();
var
  ResultCode: Integer;
begin
  WizardForm.FilenameLabel.Caption := 'installing VirtualBox'
  if not Exec(ExpandConstant('msiexec'), ExpandConstant('/qn /i "{app}\installers\virtualbox\virtualbox.msi" /norestart'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    MsgBox('virtualbox install failure', mbInformation, MB_OK);
end;

procedure CopyBoot2DockerISO();
begin
  WizardForm.FilenameLabel.Caption := 'copying boot2docker iso'
  if not ForceDirectories(ExpandConstant('{userdocs}\..\.docker\machine\cache')) then
      MsgBox('Failed to create docker machine cache dir', mbError, MB_OK);
  if not FileCopy(ExpandConstant('{app}\boot2docker.iso'), ExpandConstant('{userdocs}\..\.docker\machine\cache\boot2docker.iso'), false) then
      MsgBox('File moving failed!', mbError, MB_OK);
end;

function CanUpgradeVM(): Boolean;
var
  ResultCode: Integer;
begin
  if NeedToInstallVirtualBox() or not FileExists(ExpandConstant('{app}\docker-machine.exe')) then begin
    Result := false
    exit
  end;

  ExecAsOriginalUser(VBoxPath() + 'VBoxManage.exe', 'showvminfo default', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
  if ResultCode <> 0 then begin
    Result := false
    exit
  end;

  if not DirExists(ExpandConstant('{userdocs}\..\.docker\machine\machines\default')) then begin
    Result := false
    exit
  end;

  Result := true
end;

function UpgradeVM() : Boolean;
var
  ResultCode: Integer;
begin
  TrackEvent('VM Upgrade Started');
  WizardForm.StatusLabel.Caption := 'Upgrading Docker Toolbox VM...'
  ExecAsOriginalUser(ExpandConstant('{app}\docker-machine.exe'), 'stop default', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
  if (ResultCode = 0) or (ResultCode = 1) then
  begin
    FileCopy(ExpandConstant('{userdocs}\..\.docker\machine\cache\boot2docker.iso'), ExpandConstant('{userdocs}\..\.docker\machine\machines\default\boot2docker.iso'), false)
    TrackEvent('VM Upgrade Succeeded');
  end
  else begin
    TrackEvent('VM Upgrade Failed');
    MsgBox('VM Upgrade Failed because the VirtualBox VM could not be stopped.', mbCriticalError, MB_OK);
    Result := false
    WizardForm.Close;
    exit;
  end;
  Result := true
end;

const
  ModPathName = 'modifypath';
  ModPathType = 'user';

function ModPathDir(): TArrayOfString;
begin
  setArrayLength(Result, 1);
  Result[0] := ExpandConstant('{app}');
end;
#include "modpath.iss"

procedure CurStepChanged(CurStep: TSetupStep);
var
  Success: Boolean;
begin
  Success := True;
  if CurStep = ssPostInstall then
  begin
    trackEvent('Installing Files Succeeded');
    if IsTaskSelected(ModPathName) then
      ModPath();
    if not WizardSilent() then
    begin
      if IsTaskSelected('upgradevm') then
      begin
        if CanUpgradeVM() then begin
          Success := UpgradeVM();
        end;
      end;
    end;

    if Success then
      trackEvent('Installer Finished');
  end;
end;

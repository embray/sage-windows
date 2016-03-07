#define MyAppName "SageMath Windows"
#define MyAppPublisher "SageMath"
#define MyAppURL "http://www.sagemath.org/"
#define MyAppContact "http://www.sagemath.org/"

#define SageGroupName "SageMath"
#define sageMathImage "..\bundle\sagemath.tar"
#define dockerToolbox "..\bundle\DockerToolbox.exe"
#define dockerVMName "default"

#ifndef SageImageRepo
  #define SageImageRepo "sagemath/sagemath-jupyter"
#endif

#ifndef SageImageTag
  #define SageImageTag "latest"
#endif

// Really we need to know this in order to install the image
// properly; we may be able to pass this in some other nicer way
// but simply requiring it to be defined is fine for now.
#ifndef SageImageDigest
  #error The SHA1 digest for the sagemath Docker image to install must be passed to innosetup via /DSageImageDigest
#endif

#ifndef Compression
  #define Compression "lzma"
#endif

// NOTE: Enable DiskSpanning if the bundled Docker image is so large that
// the install file becomes >2GB compressed.
#ifndef DiskSpanning
  #if Compression == "none"
    #define DiskSpanning="yes"
  #else
    #define DiskSpanning="no"
  #endif
#endif

[Setup]
AppCopyright={#MyAppPublisher}
AppId={{723D6855-C02C-42AE-92E7-8DFEDA411195}
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
DefaultDirName={pf}\{#SageGroupName}
DefaultGroupName={#SageGroupName}
DisableProgramGroupPage=yes
DisableWelcomePage=no
DiskSpanning={#DiskSpanning}
OutputBaseFilename={#SageGroupName}
Compression={#Compression}
SolidCompression=yes
WizardImageFile=windows-installer-side.bmp
WizardSmallImageFile=windows-installer-logo.bmp
WizardImageStretch=yes
UninstallDisplayIcon={app}\unins000.exe
SetupIconFile=toolbox.ico
ChangesEnvironment=true
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Run]
Filename: "{win}\explorer.exe"; Parameters: "{userprograms}\{#SageGroupName}\"; Flags: postinstall skipifsilent; Description: "View Shortcuts in File Explorer"

[Tasks]
//Name: desktopicon; Description: "{cm:CreateDesktopIcon}"
//Name: modifypath; Description: "Add docker binaries to &PATH"
//Name: upgradevm; Description: "Upgrade Boot2Docker VM"

[Components]
Name: "Docker"; Description: "Docker for Windows" ; Types: full custom; Flags: fixed
Name: "SageMath"; Description: "SageMath image for Docker"; Types: full custom; Flags: fixed

[Files]
Source: "{#dockerToolbox}"; DestDir: "{tmp}"; Flags: ignoreversion deleteafterinstall; Components: "Docker"; AfterInstall: RunInstallDocker
Source: "{#sageMathImage}"; Components: "SageMath"; Flags: dontcopy
// NOTE: This file has more to do with Docker than sage itself.  It's the
// equivalent to start.sh which comes with Docker Toolbox, but written
// for MS powershell, so that we don't strictly need to install Git
// Eventually we could avoid shipping this if Docker Toolbox starts
// including it; see https://github.com/docker/toolbox/pull/321 
Source: ".\Start-DockerMachine.ps1"; DestDir: "{app}"; Flags: ignoreversion; Components: "SageMath"

[Code]
#include "base64.iss"
#include "guid.iss"

const
  // TODO: Maybe InnoSetup has a nicer way to do this built-in
  DockerComponent = 0;
  SageMathComponent = 1;

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
  if Length(properties) > 0 then
    Log(Format('%s:%s%s', [name, #13#10, properties]))
  else
    Log(name);

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


function NeedToInstallVBox(): Boolean;
begin
  Result := VBoxPath() = ''
end;


function DockerPath(): String;
var
  Path: String;
begin
  Result := ''
  if RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'DOCKER_TOOLBOX_INSTALL_PATH', Path) then
  begin
    // Just checking that this value exists is not enough, since Docker
    // does not remove it when it is uninstalled; see
    // https://github.com/docker/toolbox/pull/443
    Path := RemoveBackslash(Path);
    if FileExists(Path + '\docker.exe') and FileExists(Path + '\docker-machine.exe') then
      Result := Path;
  end;
end;


function NeedToInstallDocker(): Boolean;
begin
  // TODO: Should also attempt to run the docker CLI and check the
  // client and server versions (if the CLI even runs successfully)
  Result := DockerPath() = ''
end;


procedure InitializeWizard;
var
  WelcomePage: TWizardPage;
  InstallDockerCaption: String;
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

// TODO: It seems to me the following two optional component install
// routines could be made into a general procedure

  InstallDockerCaption := Wizardform.ComponentsList.ItemCaption[DockerComponent];

  if NeedToInstallDocker() then
  begin
    Wizardform.ComponentsList.Checked[DockerComponent] := True;
  end else begin
    InstallDockerCaption := InstallDockerCaption + ' (already installed)';
    Wizardform.ComponentsList.Checked[DockerComponent] := False;
  end;

  Wizardform.ComponentsList.ItemCaption[DockerComponent] := InstallDockerCaption;
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


// This is used to modify the users PATH environment vvariable to include
// the app's install path.  May still be useful if, for example, we want
// too add a 'sage' command-line executable (in this case probably just a
// batch script or something)
const
  ModPathName = 'modifypath';
  ModPathType = 'user';

function ModPathDir(): TArrayOfString;
begin
  setArrayLength(Result, 1);
  Result[0] := ExpandConstant('{app}');
end;
#include "modpath.iss"


// Run a shell command, capturing and returning stdout
// Takes the same arguments as Exec but also returns
// stdout as a string passed by reference as the last argument
function ExecCaptureStdout(Cmd: String; CmdArgs: String; WorkingDir: String; const ShowCmd: Integer; const Wait: TExecWait; var ResultCode: Integer; var Stdout: String): Boolean;
var
  StdoutFile: String;
  StdoutText: AnsiString;
begin
  StdoutFile := GenerateUniqueName(ExpandConstant('{tmp}'), '.txt');
  CmdArgs := Format('/S /C ""%s" %s > "%s""', [Cmd, CmdArgs, StdoutFile]);
  Log(Format(ExpandConstant('Running "%s" %s'), [Cmd, CmdArgs]));
  Result := ExecAsOriginalUser(ExpandConstant('{cmd}'), CmdArgs, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  LoadStringFromFile(StdoutFile, StdoutText);
  Stdout := String(StdoutText);
end;


// This procedure runs the 'docker' client command with the given
// arguments.  Returns the return code of the command.
// TODO: Maybe also return stdout/err
function RunDocker(Args: String): Integer;
var
  ResultCode: Integer;
begin
  // The following mess is how we can run the docker.exe command while
  // setting the appropriate environment variables given by
  // 'docker-machine env' for the Docker client to connect to the correct
  // host.
  Args := Format('/S /C "(FOR /f "tokens=*" %%i IN (''"%s\docker-machine.exe" env %s'') DO %%i) && "%s\docker.exe" %s"', [DockerPath(), ExpandConstant('{#dockerVMName}'), DockerPath(), Args]);
  ExecAsOriginalUser(ExpandConstant('{cmd}'), Args, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := ResultCode;
end;


function RunDockerMachine(Args: String; var ResultCode: Integer; var Stdout: String): Boolean;
begin
  Result := ExecCaptureStdout(Format('%s\docker-machine.exe', [DockerPath()]),
                              Args, '', SW_HIDE, ewWaitUntilTerminated,
			      ResultCode, Stdout);
end;


// Used to run the DockerToolbox installer; determines the appropriate tasks
// and components to enable in the installer (currently Git will be installed
// even though we don't need it--see https://github.com/docker/toolbox/pull/418
procedure RunInstallDocker();
var
  DockerComponents: String;
  ResultCode: Integer;
  InstallArgs: String;
begin
  WizardForm.StatusLabel.Caption := 'Installing Docker...';
  // Must install Docker and DockerMachine at a minimum, no compose,
  // kitematic, etc.
  DockerComponents := 'Docker,DockerMachine'

  if NeedToInstallVBox() then
  begin
    DockerComponents := DockerComponents + ',VirtualBox'
  end;

  InstallArgs := Format('/SILENT /NOCANCEL /NOICONS /COMPONENTS="%s" /TASKS=""', [DockerComponents]);

  // Run Docker installer in quiet mode (will show a progress bar but not
  // ask for any user input); select only required components and disable
  // all tasks and icons
  Exec(ExpandConstant('{tmp}\DockerToolbox.exe'), InstallArgs, '',
                      SW_SHOW, ewWaitUntilTerminated, ResultCode);
end;



// Returns true if the Docker VM is up and running
function IsDockerMachineRunning(): Boolean;
var
  ResultCode: Integer;
  MachineStatus: String;
begin
  WizardForm.StatusLabel.Caption := 'Checking Docker VM status...';
  RunDockerMachine(ExpandConstant('status {#dockerVMName}'), ResultCode, MachineStatus);
  WizardForm.StatusLabel.Caption := 'Checking Docker VM status... [OK]';
  if (ResultCode = 0) then
  begin
    Result := 0 = CompareText('running', TrimRight(MachineStatus));
  end else begin
    Result := False
  end;
end;


// This step starts the boot2docker VM with docker-machine
// so that we can then issue commands to the docker-engine through
// the docker client (namely load the sagemath image, which we then delete
// from the installation)
procedure RunInstallSageImage();
var
  ResultCode: Integer;
  Stdout: String;
begin
  TrackEvent('Installing the Sage image');
  // TODO Maybe worth specifying a constant for this
  WizardForm.StatusLabel.Caption := 'Extracting Sage image archive...';
  ExtractTemporaryFile('sagemath.tar');

  if not IsDockerMachineRunning() then
  begin
    // TODO This could take a few minutes and appear to hang.  Figure out some way
    // to update a progress bar, or at least display a spinner?
    WizardForm.StatusLabel.Caption := 'Starting Docker VM...'
    RunDockerMachine(ExpandConstant('start {#dockerVMName}'), ResultCode, Stdout);
    if (ResultCode = 0) then
    begin
      WizardForm.StatusLabel.Caption := 'Starting Docker VM... [OK]';
    end else begin
      TrackEvent('VM start Failed');
      MsgBox('The Docker VM could not be started', mbCriticalError, MB_OK);
      WizardForm.Close;
      exit;
    end;
  end;

  // TODO: This is also quite time consuming--try to provide a
  // progress bar if possible...?
  WizardForm.StatusLabel.Caption := 'Loading SageMath image into Docker...';

  ResultCode := RunDocker(Format('load -i "%s"', [ExpandConstant('{tmp}\sagemath.tar')]));

  if (ResultCode = 0) then
  begin
    WizardForm.StatusLabel.Caption := 'Loading SageMath image into Docker... [OK]';
    RunDocker(Format('tag %s %s:%s', [ExpandConstant('{#SageImageDigest}'), ExpandConstant('{#SageImageRepo}'),
                                      ExpandConstant('{#SageImageTag}')]));
  end else begin
    TrackEvent('Image load Failed');
    MsgBox(ExpandConstant('The {#SageGroupName} Docker image could not be loaded'), mbCriticalError, MB_OK);
    WizardForm.Close;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Success: Boolean;
begin
  Success := True;
  if CurStep = ssPostInstall then
  begin
    TrackEvent('Installing Files Succeeded');
    if IsTaskSelected(ModPathName) then
      ModPath();

    RunInstallSageImage();

    if Success then
      TrackEvent('Installer Finished');
  end;
end;

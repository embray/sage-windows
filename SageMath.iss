#define MyAppName "SageMath"
#define MyAppVersion "7.4"
#define MyAppPublisher "SageMath"
#define MyAppURL "http://www.sagemath.org/"
#define MyAppContact "http://www.sagemath.org/"

#define SageGroupName "SageMath"

#ifndef Compression
  #define Compression "lzma"
#endif

#ifndef AppBuildDir
  #define AppBuildDir "build"
#endif

#ifndef DiskSpanning
  #if Compression == "none"
    #define DiskSpanning="yes"
  #else
    #define DiskSpanning="no"
  #endif
#endif

#define Bin         "{app}\app\bin"
#define OptSageMath "{app}\app\opt\sagemath-" + MyAppVersion
#define OptSageMathPosix "/opt/sagemath-" + MyAppVersion

[Setup]
AppCopyright={#MyAppPublisher}
AppId={#MyAppName}
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
OutputDir=dist
OutputBaseFilename={#MyAppName}-{#MyAppVersion}
Compression={#Compression}
SolidCompression=yes
WizardImageFile=resources\sage-banner.bmp
WizardSmallImageFile=resources\sage-sticker.bmp
WizardImageStretch=yes
UninstallDisplayIcon={app}\unins000.exe
SetupIconFile=resources\sage-floppy-disk.ico
ChangesEnvironment=true
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: startmenu; Description: "Create &start menu icons"; GroupDescription: "Additional icons"
Name: desktop; Description: "Create &desktop icons"; GroupDescription: "Additional icons"

[Files]
Source: "dot_sage\*"; DestDir: "{#OptSageMath}\dot_sage"; Flags: recursesubdirs ignoreversion
Source: "{#AppBuildDir}\app\*"; DestDir: "{app}\app"; Flags: recursesubdirs ignoreversion
Source: "resources\sagemath.ico"; DestDir: "{app}"; Flags: ignoreversion; AfterInstall: FixupSymlinks

; InnoSetup will not create empty directories found when including files
; recursively in the [Files] section, so any directories that must exist
; (but start out empty) in the cygwin distribution must be created
;
; /etc/fstab.d is where user-specific mount tables go--this is used in
; sage for windows by /etc/sagerc to set up the /dot_sage mount point for
; each user's DOT_SAGE directory, since the actual path name might contain
; spaces and other special characters not handled well by some software that
; uses DOT_SAGE
;
; /dev/shm and /dev/mqueue are used by the system for POSIX semaphores, shared
; memory, and message queues and must be created world-writeable
[Dirs]
Name: "{app}\app\etc\fstab.d"; Permissions: users-modify
Name: "{app}\app\dev\shm"; Permissions: users-modify
Name: "{app}\app\dev\mqueue"; Permissions: users-modify

[UninstallDelete]
Type: filesandordirs; Name: "{app}\app\etc\fstab.d"
Type: filesandordirs; Name: "{app}\app\dev\shm"
Type: filesandordirs; Name: "{app}\app\dev\mqueue"

#define RunSage "/bin/bash --login -c '" + OptSageMathPosix + "/sage'"
#define RunSageDoc "The SageMath console interface"
#define RunSageSh "/bin/bash --login -c '" + OptSageMathPosix + "/sage -sh'"
#define RunSageShDoc "Command prompt in the SageMath shell environment"
#define RunSageNotebook "/bin/bash --login -c '" + OptSageMathPosix + "/sage --notebook jupyter'"
#define RunSageNotebookDoc "Start SageMath notebook server"

[Icons]
Name: "{app}\SageMath"; Filename: "{#bin}\mintty.exe"; Parameters: "-t SageMath -i sagemath.ico {#RunSage}"; WorkingDir: "{app}"; Comment: "{#RunSageDoc}"; IconFilename: "{app}\sagemath.ico"
Name: "{group}\SageMath"; Filename: "{#bin}\mintty.exe"; Parameters: "-t SageMath -i sagemath.ico {#RunSage}"; WorkingDir: "{app}"; Comment: "{#RunSageDoc}"; IconFilename: "{app}\sagemath.ico"; Tasks: startmenu
Name: "{commondesktop}\SageMath"; Filename: "{#bin}\mintty.exe"; Parameters: "-t SageMath -i sagemath.ico {#RunSage}"; WorkingDir: "{app}"; Comment: "{#RunSageDoc}"; IconFilename: "{app}\sagemath.ico"; Tasks: desktop

Name: "{app}\SageMath Shell"; Filename: "{#bin}\mintty.exe"; Parameters: "-t 'SageMath Shell' -i sagemath.ico {#RunSageSh}"; WorkingDir: "{app}"; Comment: "{#RunSageShDoc}"; IconFilename: "{app}\sagemath.ico"
Name: "{group}\SageMath Shell"; Filename: "{#bin}\mintty.exe"; Parameters: "-t 'SageMath Shell' -i sagemath.ico {#RunSageSh}"; WorkingDir: "{app}"; Comment: "{#RunSageShDoc}"; IconFilename: "{app}\sagemath.ico"; Tasks: startmenu
Name: "{commondesktop}\SageMath Shell"; Filename: "{#bin}\mintty.exe"; Parameters: "-t SageMath -i sagemath.ico {#RunSageSh}"; WorkingDir: "{app}"; Comment: "{#RunSageShDoc}"; IconFilename: "{app}\sagemath.ico"; Tasks: desktop

Name: "{app}\SageMath Notebook"; Filename: "{#bin}\mintty.exe"; Parameters: "-t 'SageMath Shell' -i sagemath.ico {#RunSageNotebook}"; WorkingDir: "{app}"; Comment: "{#RunSageNotebookDoc}"; IconFilename: "{app}\sagemath.ico"
Name: "{group}\SageMath Notebook"; Filename: "{#bin}\mintty.exe"; Parameters: "-t 'SageMath Shell' -i sagemath.ico {#RunSageNotebook}"; WorkingDir: "{app}"; Comment: "{#RunSageNotebookDoc}"; IconFilename: "{app}\sagemath.ico"; Tasks: startmenu
Name: "{commondesktop}\SageMath Notebook"; Filename: "{#bin}\mintty.exe"; Parameters: "-t SageMath -i sagemath.ico {#RunSageNotebook}"; WorkingDir: "{app}"; Comment: "{#RunSageNotebookDoc}"; IconFilename: "{app}\sagemath.ico"; Tasks: desktop

[Code]
procedure FixupSymlinks();
var
    n: Integer;
    i: Integer;
    resultCode: Integer;
    filenames: TArrayOfString;
    filenam: String;
begin
    LoadStringsFromFile(ExpandConstant('{app}\app\etc\symlinks.lst'), filenames);
    n := GetArrayLength(filenames);
    WizardForm.ProgressGauge.Min := 0;
    WizardForm.ProgressGauge.Max := n - 1;
    WizardForm.ProgressGauge.Position := 0;
    WizardForm.StatusLabel.Caption := 'Fixing up symlinks...';
    for i := 0 to n - 1 do
    begin
        filenam := filenames[i];
        WizardForm.FilenameLabel.Caption := Copy(filenam, 2, Length(filenam));
        WizardForm.ProgressGauge.Position := i;
        Exec(ExpandConstant('{sys}\attrib.exe'), '+S ' + filenam,
                            ExpandConstant('{app}\app'), SW_HIDE,
                            ewNoWait, resultCode);
    end;
end;

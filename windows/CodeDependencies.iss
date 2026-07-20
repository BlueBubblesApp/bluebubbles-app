[Code]
// https://github.com/DomGries/InnoDependencyInstaller

// types and variables
type
  TDependency_Entry = record
    Filename: String;
    Parameters: String;
    Title: String;
    URL: String;
    Checksum: String;
    ForceSuccess: Boolean;
    RestartAfter: Boolean;
    Components: String;
  end;

var
  Dependency_List: array of TDependency_Entry;
  Dependency_NeedToRestart, Dependency_ForceX86, Dependency_ForceX64: Boolean;
  Dependency_Components: String;
  Dependency_DownloadPage: TDownloadWizardPage;

function Dependency_IsEntryActive(const Entry: TDependency_Entry): Boolean;
begin
  Result := (Entry.Components = '') or WizardIsComponentSelected(Entry.Components);
end;

procedure Dependency_Add(const Filename, Parameters, Title, URL, Checksum: String; const ForceSuccess, RestartAfter: Boolean);
var
  Dependency: TDependency_Entry;
  DependencyCount: Integer;
begin
  Dependency.Filename := Filename;
  Dependency.Parameters := Parameters;
  Dependency.Title := Title;

  if FileExists(ExpandConstant('{tmp}{\}') + Filename) then begin
    Dependency.URL := '';
    Log('Dependency queued (already in tmp): ' + Title);
  end else begin
    Dependency.URL := URL;
    Log('Dependency queued for download: ' + Title);
  end;

  Dependency.Checksum := Checksum;
  Dependency.ForceSuccess := ForceSuccess;
  Dependency.RestartAfter := RestartAfter;
  Dependency.Components := Dependency_Components;

  DependencyCount := GetArrayLength(Dependency_List);
  SetArrayLength(Dependency_List, DependencyCount + 1);
  Dependency_List[DependencyCount] := Dependency;
end;

<event('InitializeWizard')>
procedure Dependency_InitializeWizard;
begin
  Dependency_DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), nil);
end;

<event('PrepareToInstall')>
function Dependency_PrepareToInstall(var NeedsRestart: Boolean): String;
var
  DependencyCount, DependencyIndex, ActiveCount, ActiveIndex, ResultCode: Integer;
  Retry: Boolean;
  TempValue: String;
begin
  DependencyCount := GetArrayLength(Dependency_List);

  if DependencyCount > 0 then begin
    Dependency_DownloadPage.Show;

    for DependencyIndex := 0 to DependencyCount - 1 do begin
      if not Dependency_IsEntryActive(Dependency_List[DependencyIndex]) then begin
        continue;
      end;
      if Dependency_List[DependencyIndex].URL <> '' then begin
        Dependency_DownloadPage.Clear;
        Dependency_DownloadPage.Add(Dependency_List[DependencyIndex].URL, Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Checksum);

        Retry := True;
        while Retry do begin
          Retry := False;

          try
            Dependency_DownloadPage.Download;
          except
            if Dependency_DownloadPage.AbortedByUser then begin
              Log('Download aborted by user: ' + Dependency_List[DependencyIndex].Title);
              Result := Dependency_List[DependencyIndex].Title;
              DependencyIndex := DependencyCount;
            end else begin
              case SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbError, MB_ABORTRETRYIGNORE, IDIGNORE) of
                IDABORT: begin
                  Result := Dependency_List[DependencyIndex].Title;
                  DependencyIndex := DependencyCount;
                end;
                IDRETRY: begin
                  Retry := True;
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    if Result = '' then begin
      ActiveCount := 0;
      for DependencyIndex := 0 to DependencyCount - 1 do begin
        if Dependency_IsEntryActive(Dependency_List[DependencyIndex]) then begin
          ActiveCount := ActiveCount + 1;
        end;
      end;

      ActiveIndex := 0;
      for DependencyIndex := 0 to DependencyCount - 1 do begin
        if not Dependency_IsEntryActive(Dependency_List[DependencyIndex]) then begin
          Log('Dependency skipped (component not selected): ' + Dependency_List[DependencyIndex].Title);
          continue;
        end;
        ActiveIndex := ActiveIndex + 1;
        Dependency_DownloadPage.SetText(Dependency_List[DependencyIndex].Title, '');
        Dependency_DownloadPage.SetProgress(ActiveIndex, ActiveCount + 1);

        while True do begin
          ResultCode := 0;
#ifdef Dependency_CustomExecute
          if {#Dependency_CustomExecute}(ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, ResultCode) then begin
#else
          if ShellExec('', ExpandConstant('{tmp}{\}') + Dependency_List[DependencyIndex].Filename, Dependency_List[DependencyIndex].Parameters, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then begin
#endif
            Log('Dependency exit code ' + IntToStr(ResultCode) + ': ' + Dependency_List[DependencyIndex].Title);
            if Dependency_List[DependencyIndex].RestartAfter then begin
              if DependencyIndex = DependencyCount - 1 then begin
                Dependency_NeedToRestart := True;
              end else begin
                NeedsRestart := True;
                Result := Dependency_List[DependencyIndex].Title;
              end;
              break;
            end else if (ResultCode = 0) or Dependency_List[DependencyIndex].ForceSuccess then begin // ERROR_SUCCESS (0)
              break;
            end else if ResultCode = 1641 then begin // ERROR_SUCCESS_REBOOT_INITIATED (1641)
              NeedsRestart := True;
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end else if ResultCode = 3010 then begin // ERROR_SUCCESS_REBOOT_REQUIRED (3010)
              Dependency_NeedToRestart := True;
              break;
            end else if ResultCode = 1638 then begin // ERROR_PRODUCT_VERSION (1638)
              break;
            end;
          end;

          case SuppressibleMsgBox(FmtMessage(SetupMessage(msgErrorFunctionFailed), [Dependency_List[DependencyIndex].Title, IntToStr(ResultCode)]), mbError, MB_ABORTRETRYIGNORE, IDIGNORE) of
            IDABORT: begin
              Result := Dependency_List[DependencyIndex].Title;
              break;
            end;
            IDIGNORE: begin
              break;
            end;
          end;
        end;

        if Result <> '' then begin
          break;
        end;
      end;

      if NeedsRestart then begin
        Log('Dependency requires restart: registering RunOnce to resume setup');
        TempValue := '"' + ExpandConstant('{srcexe}') + '" /restart=1 /LANG="' + ExpandConstant('{language}') + '" /DIR="' + WizardDirValue + '" /GROUP="' + WizardGroupValue + '" /TYPE="' + WizardSetupType(False) + '" /COMPONENTS="' + WizardSelectedComponents(False) + '" /TASKS="' + WizardSelectedTasks(False) + '"';
        if WizardNoIcons then begin
          TempValue := TempValue + ' /NOICONS';
        end;
        RegWriteStringValue(HKA, 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', '{#SetupSetting("AppName")}', TempValue);
      end;
    end;

    Dependency_DownloadPage.Hide;
  end;
end;

#ifndef Dependency_NoUpdateReadyMemo
<event('UpdateReadyMemo')>
#endif
function Dependency_UpdateReadyMemo(const Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  DependencyIndex: Integer;
  DependencyMemo: String;
begin
  Result := '';
  if MemoUserInfoInfo <> '' then begin
    Result := Result + MemoUserInfoInfo + Newline + NewLine;
  end;
  if MemoDirInfo <> '' then begin
    Result := Result + MemoDirInfo + Newline + NewLine;
  end;
  if MemoTypeInfo <> '' then begin
    Result := Result + MemoTypeInfo + Newline + NewLine;
  end;
  if MemoComponentsInfo <> '' then begin
    Result := Result + MemoComponentsInfo + Newline + NewLine;
  end;
  if MemoGroupInfo <> '' then begin
    Result := Result + MemoGroupInfo + Newline + NewLine;
  end;
  if MemoTasksInfo <> '' then begin
    Result := Result + MemoTasksInfo;
  end;

  DependencyMemo := '';
  for DependencyIndex := 0 to GetArrayLength(Dependency_List) - 1 do begin
    if Dependency_IsEntryActive(Dependency_List[DependencyIndex]) then begin
      DependencyMemo := DependencyMemo + #13#10 + '%1' + Dependency_List[DependencyIndex].Title;
    end;
  end;

  if DependencyMemo <> '' then begin
    if MemoTasksInfo = '' then begin
      Result := Result + SetupMessage(msgReadyMemoTasks);
    end;
    Result := Result + FmtMessage(DependencyMemo, [Space]);
  end;
end;

<event('NeedRestart')>
function Dependency_NeedRestart: Boolean;
begin
  Result := Dependency_NeedToRestart;
end;

function Dependency_IsArm64: Boolean;
begin
  Result := not Dependency_ForceX86 and not Dependency_ForceX64 and IsArm64;
end;

function Dependency_IsX64: Boolean;
begin
  Result := not Dependency_ForceX86 and (Is64BitInstallMode or (Dependency_ForceX64 and IsX64Compatible));
end;

function Dependency_String(const x86, x64, arm64: String): String;
begin
  if Dependency_IsArm64 then begin
    Result := arm64;
  end else if Dependency_IsX64 then begin
    Result := x64;
  end else begin
    Result := x86;
  end;
end;

function Dependency_ArchSuffix: String;
begin
  Result := Dependency_String('', '_x64', '_arm64');
end;

function Dependency_ArchTitle: String;
begin
  Result := Dependency_String(' (x86)', ' (x64)', ' (arm64)');
end;

function Dependency_PassiveOrQuiet(const Passive, Quiet: String): String;
begin
  if WizardSilent then begin
    Result := Quiet;
  end else begin
    Result := Passive;
  end;
end;

var
  Dependency_NetCoreRuntimesArch: String;
  Dependency_NetCoreRuntimes: TArrayOfString;

procedure Dependency_ListNetCoreRuntimes;
var
  Arch, Path: String;
  ResultCode: Integer;
  Output: TExecOutput;
begin
  Arch := Dependency_String('x86', 'x64', 'arm64');
  if Dependency_NetCoreRuntimesArch = Arch then begin
    exit;
  end;
  Dependency_NetCoreRuntimesArch := Arch;
  SetArrayLength(Dependency_NetCoreRuntimes, 0);

  if not RegQueryStringValue(HKLM32, 'SOFTWARE\dotnet\Setup\InstalledVersions\' + Arch, 'InstallLocation', Path) or not FileExists(Path + 'dotnet.exe') then begin
    Path := ExpandConstant(Dependency_String('{commonpf32}', '{commonpf64}', '{commonpf64}')) + '\dotnet\';
  end;
  if ExecAndCaptureOutput(Path + 'dotnet.exe', '--list-runtimes', '', SW_HIDE, ewWaitUntilTerminated, ResultCode, Output) and (ResultCode = 0) then begin
    Dependency_NetCoreRuntimes := Output.StdOut;
  end;
end;

function Dependency_IsNetCoreInstalled(Runtime: String; Major, Minor, Revision: Word): Boolean;
var
  LineIndex: Integer;
  LineParts: TArrayOfString;
  PackedVersion: Int64;
  LineMajor, LineMinor, LineRevision, LineBuild: Word;
begin
  Dependency_ListNetCoreRuntimes;

  for LineIndex := 0 to Length(Dependency_NetCoreRuntimes) - 1 do begin
    LineParts := StringSplit(Trim(Dependency_NetCoreRuntimes[LineIndex]), [' '], stExcludeEmpty);

    if (Length(LineParts) > 1) and (Lowercase(LineParts[0]) = Lowercase(Runtime)) and StrToVersion(LineParts[1], PackedVersion) then begin
      UnpackVersionComponents(PackedVersion, LineMajor, LineMinor, LineRevision, LineBuild);

      if (LineMajor = Major) and (LineMinor = Minor) and (LineRevision >= Revision) then begin
        Result := True;
        exit;
      end;
    end;
  end;
  Result := False;
end;

procedure Dependency_AddDotNet35;
begin
  // https://dotnet.microsoft.com/download/dotnet-framework/net35-sp1
  if not IsDotNetInstalled(net35, 1) then begin
    Dependency_Add('dotnetfx35.exe',
      '/lang:enu ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      '.NET Framework 3.5 Service Pack 1',
      'https://download.microsoft.com/download/2/0/E/20E90413-712F-438C-988E-FDAA79A8AC3D/dotnetfx35.exe',
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet40;
begin
  // https://dotnet.microsoft.com/download/dotnet-framework/net40
  if not IsDotNetInstalled(net4full, 0) then begin
    Dependency_Add('dotNetFx40_Full_setup.exe',
      '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      '.NET Framework 4.0',
      'https://download.microsoft.com/download/1/B/E/1BE39E79-7E39-46A3-96FF-047F95396215/dotNetFx40_Full_setup.exe',
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet45;
begin
  // https://dotnet.microsoft.com/download/dotnet-framework/net452
  if not IsDotNetInstalled(net452, 0) then begin
    Dependency_Add('dotnetfx45.exe',
      '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      '.NET Framework 4.5.2',
      'https://go.microsoft.com/fwlink/?LinkId=397707',
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet46;
begin
  // https://dotnet.microsoft.com/download/dotnet-framework/net462
  if not IsDotNetInstalled(net462, 0) then begin
    Dependency_Add('dotnetfx46.exe',
      '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      '.NET Framework 4.6.2',
      'https://go.microsoft.com/fwlink/?linkid=780596',
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet47;
begin
  // https://dotnet.microsoft.com/download/dotnet-framework/net472
  if not IsDotNetInstalled(net472, 0) then begin
    Dependency_Add('dotnetfx47.exe',
      '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      '.NET Framework 4.7.2',
      'https://go.microsoft.com/fwlink/?LinkId=863262',
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet48;
begin
    // https://dotnet.microsoft.com/download/dotnet-framework/net48
    if not IsDotNetInstalled(net48, 0) then begin
      Dependency_Add('dotnetfx48.exe',
        '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
        '.NET Framework 4.8',
        'https://go.microsoft.com/fwlink/?LinkId=2085155',
        '', False, False);
    end;
end;

procedure Dependency_AddDotNet481;
begin
  // https://dotnet.microsoft.com/download/dotnet-framework/net481
  if not IsDotNetInstalled(net481, 0) then begin
    Dependency_Add('dotnetfx481.exe',
      '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      '.NET Framework 4.8.1',
      'https://go.microsoft.com/fwlink/?LinkId=2203304',
      '', False, False);
  end;
end;

procedure Dependency_AddNetCore(const Prefix, Title, URL: String);
begin
  Dependency_Add(Prefix + Dependency_ArchSuffix + '.exe',
    '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
    Title + Dependency_ArchTitle,
    URL,
    '', False, False);
end;

procedure Dependency_AddNetCore31;
begin
  // https://dotnet.microsoft.com/download/dotnet-core/3.1
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 3, 1, 32) then begin
    Dependency_AddNetCore('netcore31', '.NET Core Runtime 3.1.32', Dependency_String('https://download.visualstudio.microsoft.com/download/pr/de4b3438-24a2-4d1d-a845-97355cf97b71/515abb880478b49f7c1bced8fbf07b16/dotnet-runtime-3.1.32-win-x86.exe', 'https://download.visualstudio.microsoft.com/download/pr/476eba79-f17f-49c8-a213-0f24a22cd026/37c02de81ff5b76ac57a5427462395f1/dotnet-runtime-3.1.32-win-x64.exe', 'https://download.visualstudio.microsoft.com/download/pr/476eba79-f17f-49c8-a213-0f24a22cd026/37c02de81ff5b76ac57a5427462395f1/dotnet-runtime-3.1.32-win-x64.exe'));
  end;
end;

procedure Dependency_AddNetCore31Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 3, 1, 32) then begin
    Dependency_AddNetCore('netcore31asp', 'ASP.NET Core Runtime 3.1.32', Dependency_String('https://download.visualstudio.microsoft.com/download/pr/63b482d2-04b2-4dd4-baaf-d1e78de80738/40321091c872f4e77337b68fc61a5a07/aspnetcore-runtime-3.1.32-win-x86.exe', 'https://download.visualstudio.microsoft.com/download/pr/98910750-2644-472c-ab2b-17f315ccb953/c2a4c223ee11e2eec7d13744e7a45547/aspnetcore-runtime-3.1.32-win-x64.exe', 'https://download.visualstudio.microsoft.com/download/pr/98910750-2644-472c-ab2b-17f315ccb953/c2a4c223ee11e2eec7d13744e7a45547/aspnetcore-runtime-3.1.32-win-x64.exe'));
  end;
end;

procedure Dependency_AddNetCore31Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 3, 1, 32) then begin
    Dependency_AddNetCore('netcore31desktop', '.NET Desktop Runtime 3.1.32', Dependency_String('https://download.visualstudio.microsoft.com/download/pr/3f353d2c-0431-48c5-bdf6-fbbe8f901bb5/542a4af07c1df5136a98a1c2df6f3d62/windowsdesktop-runtime-3.1.32-win-x86.exe', 'https://download.visualstudio.microsoft.com/download/pr/b92958c6-ae36-4efa-aafe-569fced953a5/1654639ef3b20eb576174c1cc200f33a/windowsdesktop-runtime-3.1.32-win-x64.exe', 'https://download.visualstudio.microsoft.com/download/pr/b92958c6-ae36-4efa-aafe-569fced953a5/1654639ef3b20eb576174c1cc200f33a/windowsdesktop-runtime-3.1.32-win-x64.exe'));
  end;
end;

procedure Dependency_AddDotNet50;
begin
  // https://dotnet.microsoft.com/download/dotnet/5.0
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 5, 0, 17) then begin
    Dependency_AddNetCore('dotnet50', '.NET Runtime 5.0.17', Dependency_String('https://aka.ms/dotnet/5.0/dotnet-runtime-win-x86.exe', 'https://aka.ms/dotnet/5.0/dotnet-runtime-win-x64.exe', 'https://aka.ms/dotnet/5.0/dotnet-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet50Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 5, 0, 17) then begin
    Dependency_AddNetCore('dotnet50asp', 'ASP.NET Core Runtime 5.0.17', Dependency_String('https://aka.ms/dotnet/5.0/aspnetcore-runtime-win-x86.exe', 'https://aka.ms/dotnet/5.0/aspnetcore-runtime-win-x64.exe', 'https://aka.ms/dotnet/5.0/aspnetcore-runtime-win-x64.exe'));
  end;
end;

procedure Dependency_AddDotNet50Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 5, 0, 17) then begin
    Dependency_AddNetCore('dotnet50desktop', '.NET Desktop Runtime 5.0.17', Dependency_String('https://aka.ms/dotnet/5.0/windowsdesktop-runtime-win-x86.exe', 'https://aka.ms/dotnet/5.0/windowsdesktop-runtime-win-x64.exe', 'https://aka.ms/dotnet/5.0/windowsdesktop-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet60;
begin
  // https://dotnet.microsoft.com/download/dotnet/6.0
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 6, 0, 36) then begin
    Dependency_AddNetCore('dotnet60', '.NET Runtime 6.0.36', Dependency_String('https://aka.ms/dotnet/6.0/dotnet-runtime-win-x86.exe', 'https://aka.ms/dotnet/6.0/dotnet-runtime-win-x64.exe', 'https://aka.ms/dotnet/6.0/dotnet-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet60Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 6, 0, 36) then begin
    Dependency_AddNetCore('dotnet60asp', 'ASP.NET Core Runtime 6.0.36', Dependency_String('https://aka.ms/dotnet/6.0/aspnetcore-runtime-win-x86.exe', 'https://aka.ms/dotnet/6.0/aspnetcore-runtime-win-x64.exe', 'https://aka.ms/dotnet/6.0/aspnetcore-runtime-win-x64.exe'));
  end;
end;

procedure Dependency_AddDotNet60Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 6, 0, 36) then begin
    Dependency_AddNetCore('dotnet60desktop', '.NET Desktop Runtime 6.0.36', Dependency_String('https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x86.exe', 'https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x64.exe', 'https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet70;
begin
  // https://dotnet.microsoft.com/download/dotnet/7.0
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 7, 0, 20) then begin
    Dependency_AddNetCore('dotnet70', '.NET Runtime 7.0.20', Dependency_String('https://aka.ms/dotnet/7.0/dotnet-runtime-win-x86.exe', 'https://aka.ms/dotnet/7.0/dotnet-runtime-win-x64.exe', 'https://aka.ms/dotnet/7.0/dotnet-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet70Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 7, 0, 20) then begin
    Dependency_AddNetCore('dotnet70asp', 'ASP.NET Core Runtime 7.0.20', Dependency_String('https://aka.ms/dotnet/7.0/aspnetcore-runtime-win-x86.exe', 'https://aka.ms/dotnet/7.0/aspnetcore-runtime-win-x64.exe', 'https://aka.ms/dotnet/7.0/aspnetcore-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet70Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 7, 0, 20) then begin
    Dependency_AddNetCore('dotnet70desktop', '.NET Desktop Runtime 7.0.20', Dependency_String('https://aka.ms/dotnet/7.0/windowsdesktop-runtime-win-x86.exe', 'https://aka.ms/dotnet/7.0/windowsdesktop-runtime-win-x64.exe', 'https://aka.ms/dotnet/7.0/windowsdesktop-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet80;
begin
  // https://dotnet.microsoft.com/download/dotnet/8.0
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 8, 0, 28) then begin
    Dependency_AddNetCore('dotnet80', '.NET Runtime 8.0.28', Dependency_String('https://aka.ms/dotnet/8.0/dotnet-runtime-win-x86.exe', 'https://aka.ms/dotnet/8.0/dotnet-runtime-win-x64.exe', 'https://aka.ms/dotnet/8.0/dotnet-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet80Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 8, 0, 28) then begin
    Dependency_AddNetCore('dotnet80asp', 'ASP.NET Core Runtime 8.0.28', Dependency_String('https://aka.ms/dotnet/8.0/aspnetcore-runtime-win-x86.exe', 'https://aka.ms/dotnet/8.0/aspnetcore-runtime-win-x64.exe', 'https://aka.ms/dotnet/8.0/aspnetcore-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet80Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 8, 0, 28) then begin
    Dependency_AddNetCore('dotnet80desktop', '.NET Desktop Runtime 8.0.28', Dependency_String('https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x86.exe', 'https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe', 'https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet90;
begin
  // https://dotnet.microsoft.com/download/dotnet/9.0
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 9, 0, 17) then begin
    Dependency_AddNetCore('dotnet90', '.NET Runtime 9.0.17', Dependency_String('https://aka.ms/dotnet/9.0/dotnet-runtime-win-x86.exe', 'https://aka.ms/dotnet/9.0/dotnet-runtime-win-x64.exe', 'https://aka.ms/dotnet/9.0/dotnet-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet90Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 9, 0, 17) then begin
    Dependency_AddNetCore('dotnet90asp', 'ASP.NET Core Runtime 9.0.17', Dependency_String('https://aka.ms/dotnet/9.0/aspnetcore-runtime-win-x86.exe', 'https://aka.ms/dotnet/9.0/aspnetcore-runtime-win-x64.exe', 'https://aka.ms/dotnet/9.0/aspnetcore-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet90Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 9, 0, 17) then begin
    Dependency_AddNetCore('dotnet90desktop', '.NET Desktop Runtime 9.0.17', Dependency_String('https://aka.ms/dotnet/9.0/windowsdesktop-runtime-win-x86.exe', 'https://aka.ms/dotnet/9.0/windowsdesktop-runtime-win-x64.exe', 'https://aka.ms/dotnet/9.0/windowsdesktop-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet100;
begin
  // https://dotnet.microsoft.com/download/dotnet/10.0
  if not Dependency_IsNetCoreInstalled('Microsoft.NETCore.App', 10, 0, 9) then begin
    Dependency_AddNetCore('dotnet100', '.NET Runtime 10.0.9', Dependency_String('https://aka.ms/dotnet/10.0/dotnet-runtime-win-x86.exe', 'https://aka.ms/dotnet/10.0/dotnet-runtime-win-x64.exe', 'https://aka.ms/dotnet/10.0/dotnet-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet100Asp;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', 10, 0, 9) then begin
    Dependency_AddNetCore('dotnet100asp', 'ASP.NET Core Runtime 10.0.9', Dependency_String('https://aka.ms/dotnet/10.0/aspnetcore-runtime-win-x86.exe', 'https://aka.ms/dotnet/10.0/aspnetcore-runtime-win-x64.exe', 'https://aka.ms/dotnet/10.0/aspnetcore-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNet100Desktop;
begin
  if not Dependency_IsNetCoreInstalled('Microsoft.WindowsDesktop.App', 10, 0, 9) then begin
    Dependency_AddNetCore('dotnet100desktop', '.NET Desktop Runtime 10.0.9', Dependency_String('https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x86.exe', 'https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x64.exe', 'https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-arm64.exe'));
  end;
end;

procedure Dependency_AddDotNetHosting(const Major, Patch: Integer; const URL: String);
begin
  // https://dotnet.microsoft.com/download/dotnet
  if not Dependency_IsNetCoreInstalled('Microsoft.AspNetCore.App', Major, 0, Patch) then begin
    Dependency_Add('dotnet' + IntToStr(Major) + '0hosting.exe',
      '/lcid ' + IntToStr(GetUILanguage) + ' ' + Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
      'ASP.NET Core ' + IntToStr(Major) + '.0 Hosting Bundle',
      URL,
      '', False, False);
  end;
end;

procedure Dependency_AddDotNet80Hosting; begin Dependency_AddDotNetHosting(8, 28, 'https://aka.ms/dotnet/8.0/dotnet-hosting-win.exe'); end;
procedure Dependency_AddDotNet90Hosting; begin Dependency_AddDotNetHosting(9, 17, 'https://aka.ms/dotnet/9.0/dotnet-hosting-win.exe'); end;
procedure Dependency_AddDotNet100Hosting; begin Dependency_AddDotNetHosting(10, 9, 'https://aka.ms/dotnet/10.0/dotnet-hosting-win.exe'); end;

procedure Dependency_AddVC2005;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=26347
  if not IsMsiProductInstalled(Dependency_String('{86C9D5AA-F00C-4921-B3F2-C60AF92E2844}', '{A8D19029-8E5C-4E22-8011-48070F9E796E}', '{A8D19029-8E5C-4E22-8011-48070F9E796E}'), PackVersionComponents(8, 0, 61000, 0)) then begin
    Dependency_Add('vcredist2005' + Dependency_ArchSuffix + '.exe',
      '/q',
      'Visual C++ 2005 Service Pack 1 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE', 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE', 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC2008;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=26368
  if not IsMsiProductInstalled(Dependency_String('{DE2C306F-A067-38EF-B86C-03DE4B0312F9}', '{FDA45DDF-8E17-336F-A3ED-356B7B7C688A}', '{FDA45DDF-8E17-336F-A3ED-356B7B7C688A}'), PackVersionComponents(9, 0, 30729, 6161)) then begin
    Dependency_Add('vcredist2008' + Dependency_ArchSuffix + '.exe',
      '/q',
      'Visual C++ 2008 Service Pack 1 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe', 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe', 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC2010;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=26999
  if not IsMsiProductInstalled(Dependency_String('{1F4F1D2A-D9DA-32CF-9909-48485DA06DD5}', '{5B75F761-BAC8-33BC-A381-464DDDD813A3}', '{5B75F761-BAC8-33BC-A381-464DDDD813A3}'), PackVersionComponents(10, 0, 40219, 0)) then begin
    Dependency_Add('vcredist2010' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/passive', '/q') + ' /norestart',
      'Visual C++ 2010 Service Pack 1 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe', 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe', 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC2012;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=30679
  if not IsMsiProductInstalled(Dependency_String('{4121ED58-4BD9-3E7B-A8B5-9F8BAAE045B7}', '{EFA6AFA1-738E-3E00-8101-FD03B86B29D1}', '{EFA6AFA1-738E-3E00-8101-FD03B86B29D1}'), PackVersionComponents(11, 0, 61030, 0)) then begin
    Dependency_Add('vcredist2012' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
      'Visual C++ 2012 Update 4 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe', 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe', 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC2013;
begin
  // https://support.microsoft.com/en-us/help/4032938
  if not IsMsiProductInstalled(Dependency_String('{B59F5BF1-67C8-3802-8E59-2CE551A39FC5}', '{20400CF0-DE7C-327E-9AE4-F0F38D9085F8}', '{20400CF0-DE7C-327E-9AE4-F0F38D9085F8}'), PackVersionComponents(12, 0, 40664, 0)) then begin
    Dependency_Add('vcredist2013' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
      'Visual C++ 2013 Update 5 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://download.visualstudio.microsoft.com/download/pr/10912113/5da66ddebb0ad32ebd4b922fd82e8e25/vcredist_x86.exe', 'https://download.visualstudio.microsoft.com/download/pr/10912041/cee5d6bca2ddbcd039da727bf4acb48a/vcredist_x64.exe', 'https://download.visualstudio.microsoft.com/download/pr/10912041/cee5d6bca2ddbcd039da727bf4acb48a/vcredist_x64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC14;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' + Dependency_String('x86', 'x64', 'arm64'), 'Version', Version) and (Copy(Version, 1, 1) = 'v') then begin
    Delete(Version, 1, 1);
  end;
  if not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(14, 51, 36247, 0)) < 0) then begin
    Dependency_Add('vcredist14' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
      'Visual C++ v14 Redistributable' + Dependency_ArchTitle,
      Dependency_String('https://aka.ms/vc14/vc_redist.x86.exe', 'https://aka.ms/vc14/vc_redist.x64.exe', 'https://aka.ms/vc14/vc_redist.arm64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVC2015To2019; begin Dependency_AddVC14; end;
procedure Dependency_AddVC2015To2022; begin Dependency_AddVC14; end;

procedure Dependency_AddDirectX;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=35
  Dependency_Add('dxwebsetup.exe',
    '/q',
    'DirectX Runtime',
    'https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe',
    '', True, False);
end;

procedure Dependency_AddSql2008Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=30438
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(10, 50, 4000, 0)) < 0) then begin
    Dependency_Add('sql2008express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2008 R2 Service Pack 2 Express',
      Dependency_String('https://download.microsoft.com/download/0/4/B/04BE03CD-EAF3-4797-9D8D-2E08E316C998/SQLEXPR32_x86_ENU.exe', 'https://download.microsoft.com/download/0/4/B/04BE03CD-EAF3-4797-9D8D-2E08E316C998/SQLEXPR_x64_ENU.exe', 'https://download.microsoft.com/download/0/4/B/04BE03CD-EAF3-4797-9D8D-2E08E316C998/SQLEXPR_x64_ENU.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddSql2012Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=56042
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(11, 0, 7001, 0)) < 0) then begin
    Dependency_Add('sql2012express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2012 Service Pack 4 Express',
      Dependency_String('https://download.microsoft.com/download/B/D/E/BDE8FAD6-33E5-44F6-B714-348F73E602B6/SQLEXPR32_x86_ENU.exe', 'https://download.microsoft.com/download/B/D/E/BDE8FAD6-33E5-44F6-B714-348F73E602B6/SQLEXPR_x64_ENU.exe', 'https://download.microsoft.com/download/B/D/E/BDE8FAD6-33E5-44F6-B714-348F73E602B6/SQLEXPR_x64_ENU.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddSql2014Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=57473
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(12, 0, 6024, 0)) < 0) then begin
    Dependency_Add('sql2014express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2014 Service Pack 3 Express',
      Dependency_String('https://download.microsoft.com/download/3/9/F/39F968FA-DEBB-4960-8F9E-0E7BB3035959/SQLEXPR32_x86_ENU.exe', 'https://download.microsoft.com/download/3/9/F/39F968FA-DEBB-4960-8F9E-0E7BB3035959/SQLEXPR_x64_ENU.exe', 'https://download.microsoft.com/download/3/9/F/39F968FA-DEBB-4960-8F9E-0E7BB3035959/SQLEXPR_x64_ENU.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddSql2016Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=103447
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(13, 0, 6404, 1)) < 0) then begin
    Dependency_Add('sql2016express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2016 Service Pack 3 Express',
      'https://download.microsoft.com/download/f/a/8/fa83d147-63d1-449c-b22d-5fef9bd5bb46/SQLServer2016-SSEI-Expr.exe',
      '', False, False);
  end;
end;

procedure Dependency_AddSql2017Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=55994
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(14, 0, 0, 0)) < 0) then begin
    Dependency_Add('sql2017express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2017 Express',
      'https://download.microsoft.com/download/5/E/9/5E9B18CC-8FD5-467E-B5BF-BADE39C51F73/SQLServer2017-SSEI-Expr.exe',
      '', False, False);
  end;
end;

procedure Dependency_AddSql2019Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=101064
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(15, 0, 0, 0)) < 0) then begin
    Dependency_Add('sql2019express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2019 Express',
      'https://download.microsoft.com/download/7/f/8/7f8a9c43-8c8a-4f7c-9f92-83c18d96b681/SQL2019-SSEI-Expr.exe',
      '', False, False);
  end;
end;

procedure Dependency_AddSql2022Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=104781
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(16, 0, 1000, 6)) < 0) then begin
    Dependency_Add('sql2022express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2022 Express',
      'https://go.microsoft.com/fwlink/p/?linkid=2216019',
      '', False, False);
  end;
end;

procedure Dependency_AddSql2025Express;
var
  Version: String;
  PackedVersion: Int64;
begin
  // https://www.microsoft.com/en-us/sql-server/sql-server-downloads
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQLServer\CurrentVersion', 'CurrentVersion', Version) or not StrToVersion(Version, PackedVersion) or (ComparePackedVersion(PackedVersion, PackVersionComponents(17, 0, 1000, 7)) < 0) then begin
    Dependency_Add('sql2025express' + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/QS', '/Q') + ' /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQL /INSTANCENAME=MSSQLSERVER',
      'SQL Server 2025 Express',
      'https://download.microsoft.com/download/7ab8f535-7eb8-4b16-82eb-eca0fa2d38f3/SQL2025-SSEI-Expr.exe',
      '', False, False);
  end;
end;

procedure Dependency_AddSqlOleDb19;
begin
  // https://learn.microsoft.com/en-us/sql/connect/oledb/download-oledb-driver-for-sql-server
  if not RegValueExists(HKLM, 'SOFTWARE\Microsoft\MSOLEDBSQL19', 'InstalledVersion') then begin
    Dependency_Add('msoledbsql' + Dependency_ArchSuffix + '.msi',
      '/qn /norestart IACCEPTMSOLEDBSQLLICENSETERMS=YES',
      'Microsoft OLE DB Driver 19 for SQL Server' + Dependency_ArchTitle,
      Dependency_String('https://go.microsoft.com/fwlink/?linkid=2364026', 'https://go.microsoft.com/fwlink/?linkid=2364027', 'https://go.microsoft.com/fwlink/?linkid=2364027'),
      '', False, False);
  end;
end;

procedure Dependency_AddSqlOdbc18;
begin
  // https://learn.microsoft.com/en-us/sql/connect/odbc/download-odbc-driver-for-sql-server
  if not RegKeyExists(HKLM, 'SOFTWARE\ODBC\ODBCINST.INI\ODBC Driver 18 for SQL Server') then begin
    Dependency_Add('msodbcsql' + Dependency_ArchSuffix + '.msi',
      '/qn /norestart IACCEPTMSODBCSQLLICENSETERMS=YES',
      'Microsoft ODBC Driver 18 for SQL Server' + Dependency_ArchTitle,
      Dependency_String('https://go.microsoft.com/fwlink/?linkid=2358335', 'https://go.microsoft.com/fwlink/?linkid=2358430', 'https://go.microsoft.com/fwlink/?linkid=2358431'),
      '', False, False);
  end;
end;

procedure Dependency_AddWebView2;
begin
  // https://developer.microsoft.com/en-us/microsoft-edge/webview2
  if not (RegValueExists(HKLM, Dependency_String('SOFTWARE', 'SOFTWARE\WOW6432Node', 'SOFTWARE\WOW6432Node') + '\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv')
    or RegValueExists(HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv')) then begin
    Dependency_Add('MicrosoftEdgeWebview2Setup.exe',
      '/silent /install',
      'WebView2 Runtime',
      'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
      '', False, False);
  end;
end;

procedure Dependency_AddAccessDatabaseEngine2016;
begin
  // https://www.microsoft.com/en-us/download/details.aspx?id=54920
  if not RegKeyExists(HKLM, 'SOFTWARE\Microsoft\Office\16.0\Access Connectivity Engine\Engines\ACE') then begin
    Dependency_Add('AccessDatabaseEngine2016' + Dependency_ArchSuffix + '.exe',
      '/quiet',
      'Microsoft Access Database Engine 2016' + Dependency_ArchTitle,
      Dependency_String('https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/accessdatabaseengine.exe', 'https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/accessdatabaseengine_X64.exe', 'https://download.microsoft.com/download/3/5/C/35C84C36-661A-44E6-9324-8786B8DBE231/accessdatabaseengine_X64.exe'),
      '', False, False);
  end;
end;

procedure Dependency_AddVSTORuntime;
begin
  // https://learn.microsoft.com/en-us/visualstudio/vsto/how-to-install-the-visual-studio-tools-for-office-runtime-redistributable
  if not RegKeyExists(HKLM, Dependency_String('SOFTWARE', 'SOFTWARE\WOW6432Node', 'SOFTWARE\WOW6432Node') + '\Microsoft\VSTO Runtime Setup\v4R') then begin
    Dependency_Add('vstor_redist.exe',
      '/q /norestart',
      'Visual Studio 2010 Tools for Office Runtime',
      'https://download.microsoft.com/download/5/d/2/5d24f8f8-efbb-4b63-aa33-3785e3104713/vstor_redist.exe',
      '', False, False);
  end;
end;

var
  Dependency_WinAppRuntimePackages: TArrayOfString;
  Dependency_WinAppRuntimePackagesListed: Boolean;

// the Windows App Runtime ships per channel side-by-side; apps need the channel they were built against
function Dependency_IsWinAppRuntimeInstalled(const Channel: String): Boolean;
var
  ResultCode, LineIndex: Integer;
  Output: TExecOutput;
begin
  if not Dependency_WinAppRuntimePackagesListed then begin
    Dependency_WinAppRuntimePackagesListed := True;
    if ExecAndCaptureOutput('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "(Get-AppxPackage -AllUsers Microsoft.WindowsAppRuntime.*).Name"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode, Output) and (ResultCode = 0) then begin
      Dependency_WinAppRuntimePackages := Output.StdOut;
    end;
  end;

  for LineIndex := 0 to Length(Dependency_WinAppRuntimePackages) - 1 do begin
    if Trim(Dependency_WinAppRuntimePackages[LineIndex]) = 'Microsoft.WindowsAppRuntime.' + Channel then begin
      Result := True;
      exit;
    end;
  end;
  Result := False;
end;

procedure Dependency_AddWinAppRuntime(const Channel, URL: String);
begin
  // https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/downloads
  if not Dependency_IsWinAppRuntimeInstalled(Channel) then begin
    Dependency_Add('windowsappruntime' + Channel + Dependency_ArchSuffix + '.exe',
      '--quiet',
      'Windows App Runtime ' + Channel + Dependency_ArchTitle,
      URL,
      '', False, False);
  end;
end;

procedure Dependency_AddWinAppRuntime20; begin Dependency_AddWinAppRuntime('2.0', Dependency_String('https://aka.ms/windowsappsdk/2.0/2.0.1/windowsappruntimeinstall-x86.exe', 'https://aka.ms/windowsappsdk/2.0/2.0.1/windowsappruntimeinstall-x64.exe', 'https://aka.ms/windowsappsdk/2.0/2.0.1/windowsappruntimeinstall-arm64.exe')); end;
procedure Dependency_AddWinAppRuntime21; begin Dependency_AddWinAppRuntime('2.1', Dependency_String('https://aka.ms/windowsappsdk/2.1/2.1.3/windowsappruntimeinstall-x86.exe', 'https://aka.ms/windowsappsdk/2.1/2.1.3/windowsappruntimeinstall-x64.exe', 'https://aka.ms/windowsappsdk/2.1/2.1.3/windowsappruntimeinstall-arm64.exe')); end;

var
  Dependency_JavaMajor: Integer;
  Dependency_JavaMajorDetected: Boolean;

function Dependency_GetJavaMajor: Integer;
var
  JavaExe, Line: String;
  ResultCode, LineIndex, QuotePos: Integer;
  Output: TExecOutput;
  Parts: TArrayOfString;
begin
  if not Dependency_JavaMajorDetected then begin
    Dependency_JavaMajorDetected := True;
    Dependency_JavaMajor := 0;

    // detect whichever java.exe an app would actually use: JAVA_HOME, else PATH
    JavaExe := GetEnv('JAVA_HOME');
    if (JavaExe <> '') and FileExists(JavaExe + '\bin\java.exe') then begin
      JavaExe := JavaExe + '\bin\java.exe';
    end else begin
      JavaExe := 'java.exe';
    end;

    // `java -version` prints to stderr
    if ExecAndCaptureOutput(JavaExe, '-version', '', SW_HIDE, ewWaitUntilTerminated, ResultCode, Output) and (ResultCode = 0) then begin
      for LineIndex := 0 to Length(Output.StdErr) - 1 do begin
        Line := Output.StdErr[LineIndex];
        QuotePos := Pos('version "', Line);
        if QuotePos > 0 then begin
          Parts := StringSplit(Copy(Line, QuotePos + 9, Length(Line)), ['.'], stExcludeEmpty);
          if Length(Parts) > 0 then begin
            Dependency_JavaMajor := StrToIntDef(Parts[0], 0);
            if (Dependency_JavaMajor = 1) and (Length(Parts) > 1) then begin
              Dependency_JavaMajor := StrToIntDef(Parts[1], 0); // legacy "1.8.0_x" -> 8
            end;
          end;
          break;
        end;
      end;
    end;
  end;

  Result := Dependency_JavaMajor;
end;

procedure Dependency_AddJava(const Major: Integer; const URL: String);
begin
  // https://learn.microsoft.com/en-us/java/openjdk/download
  if (URL <> '') and (Dependency_GetJavaMajor < Major) then begin
    Dependency_Add('openjdk-' + IntToStr(Major) + Dependency_ArchSuffix + '.msi',
      '/quiet /norestart ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJavaHome',
      'OpenJDK ' + IntToStr(Major) + Dependency_ArchTitle,
      URL,
      '', False, False);
  end;
end;

// Java 8 has no Microsoft build (and is still shipped 32-bit), so it comes from Eclipse Temurin
procedure Dependency_AddJava8; begin Dependency_AddJava(8, Dependency_String('https://api.adoptium.net/v3/installer/latest/8/ga/windows/x86/jdk/hotspot/normal/eclipse', 'https://api.adoptium.net/v3/installer/latest/8/ga/windows/x64/jdk/hotspot/normal/eclipse', 'https://api.adoptium.net/v3/installer/latest/8/ga/windows/x64/jdk/hotspot/normal/eclipse')); end;
procedure Dependency_AddJava11; begin Dependency_AddJava(11, Dependency_String('', 'https://aka.ms/download-jdk/microsoft-jdk-11-windows-x64.msi', 'https://aka.ms/download-jdk/microsoft-jdk-11-windows-aarch64.msi')); end;
procedure Dependency_AddJava17; begin Dependency_AddJava(17, Dependency_String('', 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.msi', 'https://aka.ms/download-jdk/microsoft-jdk-17-windows-aarch64.msi')); end;
procedure Dependency_AddJava21; begin Dependency_AddJava(21, Dependency_String('', 'https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.msi', 'https://aka.ms/download-jdk/microsoft-jdk-21-windows-aarch64.msi')); end;
procedure Dependency_AddJava25; begin Dependency_AddJava(25, Dependency_String('', 'https://aka.ms/download-jdk/microsoft-jdk-25-windows-x64.msi', 'https://aka.ms/download-jdk/microsoft-jdk-25-windows-aarch64.msi')); end;

function Dependency_IsPythonInstalled(const Tag: String): Boolean;
begin
  Result := RegKeyExists(HKLM, 'Software\Python\PythonCore\' + Tag + '\InstallPath')
    or RegKeyExists(HKLM, 'Software\Wow6432Node\Python\PythonCore\' + Tag + '\InstallPath')
    or RegKeyExists(HKCU, 'Software\Python\PythonCore\' + Tag + '\InstallPath');
end;

procedure Dependency_AddPython(const Minor, URL: String);
begin
  // https://www.python.org/downloads/windows/
  if not Dependency_IsPythonInstalled(Minor + Dependency_String('-32', '', '-arm64')) then begin
    Dependency_Add('python' + Minor + Dependency_ArchSuffix + '.exe',
      Dependency_PassiveOrQuiet('/passive', '/quiet') + ' InstallAllUsers=1 PrependPath=1',
      'Python ' + Minor + Dependency_ArchTitle,
      URL,
      '', False, False);
  end;
end;

procedure Dependency_AddPython313; begin Dependency_AddPython('3.13', Dependency_String('https://www.python.org/ftp/python/3.13.13/python-3.13.13.exe', 'https://www.python.org/ftp/python/3.13.13/python-3.13.13-amd64.exe', 'https://www.python.org/ftp/python/3.13.13/python-3.13.13-arm64.exe')); end;

procedure Dependency_AddPowerShell7;
begin
  // https://github.com/PowerShell/PowerShell/releases
  if not FileExists(ExpandConstant(Dependency_String('{commonpf32}', '{commonpf64}', '{commonpf64}')) + '\PowerShell\7\pwsh.exe') then begin
    Dependency_Add('powershell7' + Dependency_ArchSuffix + '.msi',
      Dependency_PassiveOrQuiet('/passive', '/quiet') + ' /norestart',
      'PowerShell 7.6.2' + Dependency_ArchTitle,
      Dependency_String('https://github.com/PowerShell/PowerShell/releases/download/v7.6.2/PowerShell-7.6.2-win-x86.msi', 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.2/PowerShell-7.6.2-win-x64.msi', 'https://github.com/PowerShell/PowerShell/releases/download/v7.6.2/PowerShell-7.6.2-win-arm64.msi'),
      '', False, False);
  end;
end;
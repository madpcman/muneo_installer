; MuneoInstaller.iss
; ------------------------------------
; Inno Setup 설치 스크립트 (CLAIX + 장치 타입 + VC++ 재배포 포함)
; ------------------------------------

#ifndef Brand
  #define Brand "claix"
;  #define Brand "ai_mclassing"
#endif

#ifndef AppVersion
  #define AppVersion "0.8.68"
#endif

#if Brand == "claix"
  #define AppId "{{C9E9B24F-4B44-4E65-9F66-90ABCDEF0001}"
  #define AppName "Claix"
  #define AppPublisher "Grib"
  #define AppExeName "claix.exe"
  #define AppDataFolderName "Claix"
  #define InstallDirName "CLAIX"
  #define OutputBaseName "claix_class_setup"
#elif Brand == "ai_mclassing"
  #define AppId "{{D8F3451B-18A0-4D0E-A151-6E0B6BBD0F4A}"
  #define AppName "AI Mclassing"
  #define AppPublisher "Makers"
  #define AppExeName "ai_mclassing.exe"
  #define AppDataFolderName "AI Mclassing"
  #define InstallDirName "AI_Mclassing"
  #define OutputBaseName "ai_mclassing_setup"
#else
  #error Unsupported Brand define. Use /DBrand=claix or /DBrand=ai_mclassing
#endif

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}

; 기본 설치 폴더: C:\Grib\CLAIX
DefaultDirName={sd}\{#AppPublisher}\{#InstallDirName}
DisableDirPage=yes
DefaultGroupName={#AppPublisher}
DisableProgramGroupPage=yes

OutputDir=.
OutputBaseFilename={#OutputBaseName}_{#SetupSetting("AppVersion")}
SetupIconFile=..\assets\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}

PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
Compression=lzma
SolidCompression=yes
UsePreviousAppDir=no


[Languages]
; ✅ 한글 UI (Inno Setup 설치 폴더의 Languages\Korean.isl 사용)
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"

; ✅ (선택) 영어도 같이 제공하려면 주석 해제
; Name: "english"; MessagesFile: "compiler:Default.isl"


[Files]
; Flutter Windows 빌드 결과 전체 복사
; NSIS의 File /r "..\build\windows\x64\runner\Release\*.*" 와 동일한 역할
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

; VC++ 재배포 패키지 인스톨러 포함
; (경로에 맞게 VC_redist.x64.exe 를 옮겨 두고 사용)
Source: "VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[InstallDelete]
Type: files; Name: "{commondesktop}\{#AppName}.lnk"
Type: files; Name: "{autodesktop}\{#AppName}.lnk"

[Icons]
; 바탕화면 바로가기
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"

; 시작 메뉴 폴더 및 바로가기
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"

[Run]
; VC++ 재배포 패키지 설치 (없을 때만 실행)
Filename: "{tmp}\VC_redist.x64.exe"; \
  Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Microsoft Visual C++ 2015-2022 x64 Redistributable 설치 중..."; \
  Flags: waituntilterminated; \
  Check: NeedsVCRedistInstall
Filename: "{cmd}"; \
  Parameters: "/C netsh advfirewall firewall delete rule name=""{#AppName}"" program=""{app}\{#AppExeName}"" >nul 2>&1 & netsh advfirewall firewall delete rule name=""{#AppName} Outbound"" program=""{app}\{#AppExeName}"" >nul 2>&1 & netsh advfirewall firewall add rule name=""{#AppName}"" dir=in action=allow program=""{app}\{#AppExeName}"" enable=yes profile=any & netsh advfirewall firewall add rule name=""{#AppName} Outbound"" dir=out action=allow program=""{app}\{#AppExeName}"" enable=yes profile=any"; \
  StatusMsg: "{#AppName} 방화벽 예외를 등록하는 중..."; \
  Flags: runhidden waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "{#AppName} 실행하기"; Flags: nowait postinstall skipifsilent unchecked

[UninstallRun]
Filename: "{cmd}"; \
  Parameters: "/C netsh advfirewall firewall delete rule name=""{#AppName}"" program=""{app}\{#AppExeName}"" >nul 2>&1 & netsh advfirewall firewall delete rule name=""{#AppName} Outbound"" program=""{app}\{#AppExeName}"" >nul 2>&1"; \
  Flags: runhidden waituntilterminated

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\com.grib\{#AppDataFolderName}"
Type: dirifempty; Name: "{userappdata}\com.grib"
Type: filesandordirs; Name: "{app}"

[Code]

var
  DevicePage: TWizardPage;
  rbUser, rbOpsBoard, rbOneQuick: TRadioButton;
  DeviceType: string;
  PreservedLicenseVerified: string;
  PreservedLicenseKey: string;

const
  RequiredVCRedistMajor = 14;
  RequiredVCRedistMinor = 50;
  RequiredVCRedistBuild = 35719;

function IsVCRedistInstalled: Boolean;
var
  Val: Cardinal;
begin
  { 64비트 레지스트리에서 VC++ 2015-2022 x64 런타임 설치 여부 확인 }
  Result :=
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
      'Installed',
      Val
    ) and (Val = 1);
end;

function IsVCRedist2015To2022Installed: Boolean;
var
  Installed: Cardinal;
  Major: Cardinal;
  Minor: Cardinal;
  Bld: Cardinal;
begin
  Result :=
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
      'Installed',
      Installed
    ) and
    (Installed = 1) and
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
      'Major',
      Major
    ) and
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
      'Minor',
      Minor
    ) and
    RegQueryDWordValue(
      HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64',
      'Bld',
      Bld
    ) and
    (
      (Major > RequiredVCRedistMajor) or
      (
        (Major = RequiredVCRedistMajor) and
        (
          (Minor > RequiredVCRedistMinor) or
          (
            (Minor = RequiredVCRedistMinor) and
            (Bld >= RequiredVCRedistBuild)
          )
        )
      )
    ) and
    FileExists(ExpandConstant('{sys}\VCRUNTIME140_1.dll'));
end;

function NeedsVCRedistInstall: Boolean;
begin
  Result := not IsVCRedist2015To2022Installed;
end;

function ReadExistingDeviceType(const FileName: string): string;
var
  S : AnsiString;
  FirstLine: string;
  LFPos: Integer;
begin
  Result := '';

  if not FileExists(FileName) then Exit;

  if not LoadStringFromFile(FileName, S) then Exit;

  { 줄 끝 CRLF 포함된 전체 내용에서 첫 줄만 뽑아냄 }
  LFPos := Pos(#10, S);   // \n 찾기
  if LFPos > 0 then
    FirstLine := Copy(S, 1, LFPos - 1)
  else
    FirstLine := Trim(S);

  FirstLine := Trim(FirstLine);

  { "deviceType=" prefix 제거 }
  if Pos('deviceType=', FirstLine) = 1 then
    Result := Trim(Copy(FirstLine, 12, MaxInt));
end;


function ReadExistingConfigValue(const FileName, KeyName: string): string;
var
  S: AnsiString;
  KeyPrefix, Line: string;
  StartPos, EndPos, I, SLen: Integer;
begin
  Result := '';
  if not FileExists(FileName) then Exit;
  if not LoadStringFromFile(FileName, S) then Exit;

  KeyPrefix := LowerCase(KeyName) + '=';
  StartPos := 1;
  SLen := Length(S);

  while StartPos <= SLen do
  begin
    EndPos := StartPos;
    while (EndPos <= SLen) and (S[EndPos] <> #10) do
      EndPos := EndPos + 1;

    Line := Trim(Copy(S, StartPos, EndPos - StartPos));
    I := Length(Line);
    while (I > 0) and (Line[I] = #13) do
    begin
      Delete(Line, I, 1);
      I := I - 1;
    end;

    if Pos(KeyPrefix, LowerCase(Line)) = 1 then
    begin
      Result := Trim(Copy(Line, Length(KeyName) + 2, MaxInt));
      Exit;
    end;

    StartPos := EndPos + 1;
  end;
end;


procedure InitializeWizard;
var
  RadioMinHeight, RadioGap: Integer;
begin
  { 기본값: teacher }
  DeviceType := 'user';
  PreservedLicenseVerified := '';
  PreservedLicenseKey := '';
  RadioMinHeight := ScaleY(24);
  RadioGap := ScaleY(12);

  { SelectDir 뒤에 커스텀 페이지 추가 }
  DevicePage :=
    CreateCustomPage(
      wpSelectDir,
      '장치 타입 선택',
      '설치할 장치 타입을 선택하세요.'
    );

  rbUser := TNewRadioButton.Create(DevicePage);
  rbUser.Parent := DevicePage.Surface;
  rbUser.Caption := '사용자';
  rbUser.Left := ScaleX(8);
  rbUser.Top := ScaleY(16);
  rbUser.Width := ScaleX(200);
  if rbUser.Height < RadioMinHeight then
    rbUser.Height := RadioMinHeight;

  rbOpsBoard := TNewRadioButton.Create(DevicePage);
  rbOpsBoard.Parent := DevicePage.Surface;
  rbOpsBoard.Caption := '전자칠판';
  rbOpsBoard.Left := rbUser.Left;
  rbOpsBoard.Top := rbUser.Top + rbUser.Height + RadioGap;
  rbOpsBoard.Width := ScaleX(200);
  if rbOpsBoard.Height < RadioMinHeight then
    rbOpsBoard.Height := RadioMinHeight;

  rbOneQuick := TNewRadioButton.Create(DevicePage);
  rbOneQuick.Parent := DevicePage.Surface;
  rbOneQuick.Caption := '모둠칠판';
  rbOneQuick.Left := rbUser.Left;
  rbOneQuick.Top := rbOpsBoard.Top + rbOpsBoard.Height + RadioGap;
  rbOneQuick.Width := ScaleX(200);
  if rbOneQuick.Height < RadioMinHeight then
    rbOneQuick.Height := RadioMinHeight;

  { 기본 라디오는 교사용 }
  rbUser.Checked := True;
end;

procedure CurPageChanged(CurPageID: Integer);
var
  CfgPath, T: string;
begin
  { 커스텀 장치 타입 페이지가 보여질 때, 기존 설정 파일을 읽어서 미리 선택 }
  if CurPageID = DevicePage.ID then
  begin
    { 사용자가 선택한 설치 경로 기준으로 config 파일 경로 계산 }
    CfgPath := ExpandConstant('{app}\config\device_config.ini');

    if FileExists(CfgPath) then
    begin
      T := ReadExistingDeviceType(CfgPath);
      if T <> '' then
      begin
        DeviceType := T;
        { 기존 deviceType 값에 따라 라디오 버튼 선택 }
        if SameText(DeviceType, 'user') then
          rbUser.Checked := True
        else if SameText(DeviceType, 'opsboard') then
          rbOpsBoard.Checked := True
        else if SameText(DeviceType, 'onequick') then
          rbOneQuick.Checked := True
        else
        begin
          { 인식 안 되면 기본값 }
          DeviceType := 'user';
          rbUser.Checked := True;
        end;
      end;
    end;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;

  { 장치 타입 페이지에서 Next 클릭 시 값 검증 }
  if CurPageID = DevicePage.ID then
  begin
    if rbUser.Checked then
      DeviceType := 'user'
    else if rbOpsBoard.Checked then
      DeviceType := 'opsboard'
    else if rbOneQuick.Checked then
      DeviceType := 'onequick'
    else
    begin
      MsgBox('장치 타입을 하나 선택해야 합니다.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  CfgDir, CfgFile: string;
  ResultCode: Integer;
begin
  { 설치 완료 후 config\device_config.ini 기록 }
  if CurStep = ssInstall then
  begin
    Exec(
      ExpandConstant('{cmd}'),
      '/C taskkill /F /T /IM {#AppExeName} >nul 2>&1',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ResultCode
    );

    CfgFile := ExpandConstant('{app}\config\device_config.ini');
    PreservedLicenseVerified := ReadExistingConfigValue(CfgFile, 'licenseVerified');
    PreservedLicenseKey := ReadExistingConfigValue(CfgFile, 'licenseKey');
  end;

  if CurStep = ssPostInstall then
  begin
    CfgDir := ExpandConstant('{app}\config');
    CfgFile := CfgDir + '\device_config.ini';

    if not DirExists(CfgDir) then
      ForceDirectories(CfgDir);

    SaveStringToFile(
      CfgFile,
      'deviceType=' + DeviceType + #13#10,
      False  { append = False → 항상 새로 작성 }
    );

    if PreservedLicenseVerified <> '' then
    begin
      SaveStringToFile(
        CfgFile,
        'licenseVerified=' + PreservedLicenseVerified + #13#10,
        True
      );
    end;

    if PreservedLicenseKey <> '' then
    begin
      SaveStringToFile(
        CfgFile,
        'licenseKey=' + PreservedLicenseKey + #13#10,
        True
      );
    end;
  end;
end;

{ Bounded waits for security tools. Also included by the process-runner smoke test. }
type
  TSecurityShellExecuteInfo = record
    cbSize, fMask: Cardinal;
    Wnd: HWND;
    Verb, FileName, Parameters, Directory: string;
    Show: Integer;
    InstApp: THandle;
    IDList: LongWord;
    ClassName: string;
    ClassKey: THandle;
    HotKey: Cardinal;
    Monitor, Process: THandle;
  end;
  TSecurityMessage = record
    Wnd: HWND;
    Message, WParam: LongWord;
    LParam: Longint;
    Time: LongWord;
    X, Y: Longint;
    PrivateData: LongWord;
  end;

function SecurityShellExecuteEx(var Info: TSecurityShellExecuteInfo): Boolean;
  external 'ShellExecuteExW@shell32.dll stdcall';
function SecurityWait(Handle: THandle; Milliseconds: Cardinal): Cardinal;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function SecurityExitCode(Handle: THandle; var Code: Cardinal): Boolean;
  external 'GetExitCodeProcess@kernel32.dll stdcall';
function SecurityTerminate(Handle: THandle; Code: Cardinal): Boolean;
  external 'TerminateProcess@kernel32.dll stdcall';
function SecurityCloseHandle(Handle: THandle): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';
function SecurityTickCount: Cardinal;
  external 'GetTickCount@kernel32.dll stdcall';
function SecurityPeekMessage(var Msg: TSecurityMessage; Wnd: HWND;
  MinMessage, MaxMessage, Remove: Cardinal): Boolean;
  external 'PeekMessageW@user32.dll stdcall';
function SecurityTranslateMessage(var Msg: TSecurityMessage): Boolean;
  external 'TranslateMessage@user32.dll stdcall';
function SecurityDispatchMessage(var Msg: TSecurityMessage): Longint;
  external 'DispatchMessageW@user32.dll stdcall';

procedure PumpSecurityMessages;
var
  Msg: TSecurityMessage;
  Count: Integer;
begin
  { Keep painting and input responsive; bound the work even under message traffic.
    Leave WM_QUIT in the queue for the installer's outer message loop. }
  for Count := 1 to 32 do
  begin
    if not SecurityPeekMessage(Msg, 0, 0, 0, 0) then Exit;
    if Msg.Message = $0012 then Exit;
    if SecurityPeekMessage(Msg, 0, 0, 0, 1) then
    begin
      SecurityTranslateMessage(Msg);
      SecurityDispatchMessage(Msg);
    end;
  end;
end;

function SecuritySystemDir: string;
begin
  { ShellExecuteEx does not apply Inno Setup's filesystem redirection rules. }
  if IsWin64 then Result := ExpandConstant('{sysnative}')
  else Result := ExpandConstant('{sys}');
end;

function RunSecurityProcess(const Operation, FileName, Parameters: string;
  TimeoutSeconds: Integer): Integer;
var
  Info: TSecurityShellExecuteInfo;
  Started, Elapsed, WaitResult, ExitCode: Cardinal;
begin
  Result := -1;
  Info.cbSize := SizeOf(Info);
  Info.fMask := $00000040 or $00000400; { process handle; no shell error dialogs }
  Info.Verb := 'open';
  Info.FileName := FileName;
  Info.Parameters := Parameters;
  Info.Directory := ExpandConstant('{tmp}');
  Info.Show := SW_HIDE;
  Log(Format('Security: starting %s (timeout %d seconds)', [Operation, TimeoutSeconds]));
  if not SecurityShellExecuteEx(Info) then
  begin
    Log('Security: launch failed: ' + SysErrorMessage(DLLGetLastError));
    Exit;
  end;
  if Info.Process = 0 then
  begin
    Log('Security: no process handle returned.');
    Exit;
  end;
  try
    Started := SecurityTickCount;
    repeat
      WaitResult := SecurityWait(Info.Process, 100);
      if WaitResult = 0 then
      begin
        if SecurityExitCode(Info.Process, ExitCode) then Result := ExitCode;
        Exit;
      end;
      if WaitResult <> $00000102 then
      begin
        Log('Security: process wait failed: ' + SysErrorMessage(DLLGetLastError));
        SecurityTerminate(Info.Process, 1);
        Exit;
      end;
      Elapsed := SecurityTickCount - Started;
      if not IsUninstaller then
      begin
        WizardForm.StatusLabel.Caption :=
          Format('%s (%d/%d초)', [Operation, Elapsed div 1000, TimeoutSeconds]);
        WizardForm.Refresh;
      end;
      PumpSecurityMessages;
    until Elapsed >= Cardinal(TimeoutSeconds * 1000);
    Result := -2;
    Log('Security: TIMEOUT: ' + Operation + '; stopping this helper and continuing.');
    { Only terminate the exact process we launched, never other PowerShell sessions. }
    if not SecurityTerminate(Info.Process, 1460) then
      Log('Security: helper termination failed: ' + SysErrorMessage(DLLGetLastError))
    else
      SecurityWait(Info.Process, 1000);
  finally
    if SecurityWait(Info.Process, 0) = $00000102 then
      SecurityTerminate(Info.Process, 1460);
    SecurityCloseHandle(Info.Process);
    Log(Format('Security: %s returned %d', [Operation, Result]));
  end;
end;

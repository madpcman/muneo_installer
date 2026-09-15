; Compile with ISCC and run /VERYSILENT /SP- /LOG="path".
; Exercises the production runner without changing Windows security settings.
[Setup]
AppName=Security process runner test
AppVersion=1.0
DefaultDirName={tmp}\SecurityProcessTest
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
OutputBaseFilename=test_security_process
SetupLogging=yes

[Code]
#include "..\installer\SecurityProcess.iss"

var
  InputHandled: Boolean;

procedure TestButtonClick(Sender: TObject);
begin
  InputHandled := True;
end;

procedure Require(Condition: Boolean; const Message: string);
begin
  if not Condition then RaiseException(Message);
  Log('PASS: ' + Message);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  Started, Elapsed: Cardinal;
  PowerShell, Marker, Params: string;
  Info: TSecurityShellExecuteInfo;
  TestButton: TNewButton;
begin
  if CurStep <> ssInstall then Exit;
  Require(SizeOf(Info) = 60, 'ShellExecuteEx structure size');
  PowerShell := SecuritySystemDir + '\WindowsPowerShell\v1.0\powershell.exe';
  TestButton := TNewButton.Create(WizardForm);
  TestButton.Parent := WizardForm;
  TestButton.OnClick := @TestButtonClick;
  PostMessage(TestButton.Handle, $00F5, 0, 0); { BM_CLICK }
  Code := RunSecurityProcess('Successful command', PowerShell,
    '-NoProfile -NonInteractive -Command "exit 0"', 10);
  Require(Code = 0, 'Success exit code');
  Require(InputHandled, 'Window messages are handled while waiting');
  TestButton.Free;
  Code := RunSecurityProcess('Failed command', PowerShell,
    '-NoProfile -NonInteractive -Command "exit 7"', 10);
  Require(Code = 7, 'Nonzero exit code');
  Code := RunSecurityProcess('Missing executable', ExpandConstant('{tmp}\missing-security-test.exe'), '', 1);
  Require(Code = -1, 'Launch failure');
  Marker := ExpandConstant('{tmp}\security-timeout-marker.txt');
  DeleteFile(Marker);
  StringChangeEx(Marker, '''', '''''', True);
  Params := '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 5; ' +
    'Set-Content -LiteralPath ''' + Marker + ''' -Value late"';
  Started := SecurityTickCount;
  Code := RunSecurityProcess('Unresponsive command', PowerShell, Params, 1);
  Elapsed := SecurityTickCount - Started;
  Require(Code = -2, 'Timeout exit code');
  Require(Elapsed < 4000, 'Timeout returns within bounded time');
  Code := RunSecurityProcess('Continue after timeout', PowerShell,
    '-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 6; exit 0"', 10);
  Require(Code = 0, 'Subsequent operations continue');
  Require(not FileExists(ExpandConstant('{tmp}\security-timeout-marker.txt')),
    'Timed out helper was terminated before its delayed write');
end;

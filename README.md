# muneo_installer

## 설치 시 Windows 보안 설정

- 파일 복사 전에 실제 설치 폴더를 Microsoft Defender 바이러스 검사 제외 경로로 추가합니다. 기존 제외 목록은 유지합니다.
- 설치 프로그램이 새로 추가한 제외 경로는 HKLM에 기록하고, 앱 제거 시 해당 경로만 삭제합니다. 재설치해도 소유 기록을 유지합니다. 제거 실패 시 기록을 남깁니다.
- 스마트 앱 컨트롤 설정이 있는 PC에서는 `VerifiedAndReputablePolicyState=0` 설정 후 `CiTool.exe -r`로 정책을 갱신하고, `Get-MpComputerStatus`로 Off 상태를 확인합니다. 스마트 앱 컨트롤은 PC 전체 설정이므로 앱 제거 시 다시 켜지 않습니다.
- 기존 앱 실행 파일의 방화벽 인바운드·아웃바운드 허용 규칙도 유지합니다.
- 설정 실패 시 설치는 계속되며 `Security:` 접두사로 결과와 오류를 설치 로그에 기록합니다. 설치 로그는 기본적으로 임시 폴더에 생성되며 `/LOG="경로"`로 지정할 수 있습니다. 제거 로그가 필요하면 제거 프로그램에도 `/LOG="경로"`를 지정합니다.
- 기관의 중앙 정책·변조 방지 설정에 따라 제외 등록이 차단되거나 실제 검사에 반영되지 않을 수 있습니다. 로그의 제외 등록 확인은 목록 재조회 기준입니다. 스마트 앱 컨트롤이 설치 프로그램 자체를 차단하면 설치 전에 코드 서명 또는 관리 설정으로 해결해야 합니다.
- 설치 도중 취소·실패한 경우 이미 적용된 보안 설정은 자동 복원되지 않습니다. 제외 경로 소유 기록은 재설치 후 제거 시 정리에 사용됩니다.

Muneo Windows 앱과 Inno Setup 설치파일을 브랜드별로 빌드하는 프로젝트입니다.

## 지원 브랜드

- `claix`
- `ai_mclassing`

브랜드 설정은 `branding/brands.json`에서 관리합니다.

## 사전 준비

Windows 환경에서 아래 도구가 필요합니다.

- Python
- Inno Setup 6
- 루트 경로의 `pubspec.yaml`

`ISCC.exe`는 PATH에 등록되어 있거나 기본 설치 경로인 `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`에 있어야 합니다.

## 전체 설치파일 빌드

PowerShell에서 프로젝트 루트로 이동한 뒤 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Brand claix
```

다른 브랜드를 빌드하려면 `-Brand` 값만 변경합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Brand ai_mclassing
```

기본 빌드 모드는 `release`입니다. 필요하면 `debug` 또는 `profile`을 지정할 수 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Brand claix -Mode profile
```

## 빌드 흐름

`scripts/build_installer.ps1`는 다음 순서로 처리합니다.

1. `scripts/apply_brand.ps1` 실행
2. 브랜드 설정에 맞춰 앱 이름, 패키지명, Windows 실행파일 메타데이터, Flutter/Android 리소스 갱신
3. `branding/<브랜드>/assets`를 프로젝트 `assets`로 복사
4. `assets`를 `build\windows\x64\runner\Release\data\flutter_assets\assets`로 덮어쓰기
5. `build\windows\x64\runner\branding\<브랜드>`의 실행파일과 `data\app.so`를 `build\windows\x64\runner\Release`로 복사
6. `Release` 폴더에서 다른 브랜드 실행파일 삭제
7. 실행파일의 파일 버전을 읽어 `installer\MuneoInstaller.iss`의 `#define AppVersion` 갱신
8. `installer\MuneoInstaller.iss`의 `#define Brand` 갱신
9. `flutter build windows` 실행
10. `pubspec.yaml`의 `version`을 읽어 Inno Setup에 전달
11. Inno Setup으로 설치파일 생성

## 브랜드 적용만 실행

Flutter 빌드나 설치파일 생성을 하지 않고 브랜드 리소스만 적용하려면 아래 명령을 사용합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply_brand.ps1 -Brand claix
```

## 선택 옵션

브랜드 적용을 건너뛰고 설치파일만 다시 만들려면 `-SkipApply`를 사용합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Brand claix -SkipApply
```

Flutter Windows 빌드를 건너뛰고 기존 빌드 결과로 설치파일만 만들려면 `-SkipWindowsBuild`를 사용합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Brand claix -SkipWindowsBuild
```

두 옵션을 함께 사용할 수도 있습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Brand claix -SkipApply -SkipWindowsBuild
```

## 산출물

Inno Setup 설치파일은 `installer` 폴더에 생성됩니다.

파일명은 브랜드와 버전에 따라 아래 형식입니다.

- `claix_class_setup_<버전>.exe`
- `ai_mclassing_setup_<버전>.exe`

## 주의사항

- `MuneoInstaller.iss`는 한글 주석과 문자열을 포함하므로 인코딩을 유지해야 합니다.
- `apply_brand.ps1`는 `MuneoInstaller.iss`를 수정할 때 기존 인코딩을 감지해 같은 인코딩으로 저장합니다.
- 브랜드별 Windows 실행파일은 `build\windows\x64\runner\branding\<브랜드>` 아래에 있어야 합니다.
- 실행파일명은 `branding/brands.json`의 `windows_binary_name` 값과 일치해야 합니다.

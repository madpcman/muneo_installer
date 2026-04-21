param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('claix', 'ai_mclassing')]
  [string]$Brand,

  [ValidateSet('debug', 'profile', 'release')]
  [string]$Mode = 'release',

  [switch]$SkipApply,
  [switch]$SkipWindowsBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot
$brandsConfig = Get-Content -Raw -Path (Join-Path $repoRoot 'branding\brands.json') | ConvertFrom-Json

if (-not $SkipApply) {
  & powershell -ExecutionPolicy Bypass -File .\scripts\apply_brand.ps1 -Brand $Brand
  if ($LASTEXITCODE -ne 0) {
    throw "apply_brand.ps1 failed with exit code $LASTEXITCODE"
  }
}

function Remove-StaleWindowsExecutables {
  param([string]$BuildMode)

  $runnerDir = Join-Path $repoRoot "build\windows\x64\runner\$([char]::ToUpperInvariant($BuildMode[0]))$($BuildMode.Substring(1))"
  if (-not (Test-Path $runnerDir)) {
    return
  }

  $binaryNames = @($brandsConfig.PSObject.Properties.Value.windows_binary_name) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique

  foreach ($binaryName in $binaryNames) {
    $exePath = Join-Path $runnerDir "$binaryName.exe"
    if (Test-Path $exePath) {
      Remove-Item -Path $exePath -Force
      Write-Host "[clean] Removed stale executable: $exePath"
    }
  }
}

if (-not $SkipWindowsBuild) {
  Remove-StaleWindowsExecutables -BuildMode $Mode
  if ($Mode -eq 'release') {
    flutter build windows
  } else {
    flutter build windows --$Mode
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Windows build failed with exit code $LASTEXITCODE"
  }
}

$pubspec = Get-Content -Raw -Path .\pubspec.yaml
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*([^\s\+]+)')
if (-not $versionMatch.Success) {
  throw 'Could not read version from pubspec.yaml'
}
$appVersion = $versionMatch.Groups[1].Value.Trim()

$isccCommand = Get-Command iscc -ErrorAction SilentlyContinue
if ($null -ne $isccCommand) {
  $isccPath = $isccCommand.Source
} else {
  $defaultIscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
  if (-not (Test-Path $defaultIscc)) {
    throw 'ISCC.exe not found. Add Inno Setup to PATH or install it in Program Files (x86)\Inno Setup 6.'
  }
  $isccPath = $defaultIscc
}

& $isccPath "/DBrand=$Brand" "/DAppVersion=$appVersion" .\installer\MuneoInstaller.iss
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup build failed with exit code $LASTEXITCODE"
}

Write-Host "[OK] Installer built. brand=$Brand mode=$Mode version=$appVersion"

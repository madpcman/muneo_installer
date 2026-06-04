param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('claix', 'ai_mclassing', 'iot_bridge')]
  [string]$Brand,

  [ValidateSet('debug', 'profile', 'release')]
  [string]$Mode = 'release',

  [ValidateSet('PROD', 'DEV')]
  [string]$ServiceType = 'PROD',

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

function Copy-WindowsReleaseBrandArtifacts {
  param([string]$BrandName)

  $brandConfig = $brandsConfig.PSObject.Properties[$BrandName].Value
  if ($null -eq $brandConfig) {
    throw "Brand '$BrandName' not found in branding/brands.json"
  }

  $binaryName = [string]$brandConfig.windows_binary_name
  if ([string]::IsNullOrWhiteSpace($binaryName)) {
    throw "Missing windows_binary_name for brand '$BrandName'"
  }

  $releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
  $sourceExe = Join-Path $releaseDir "$binaryName.exe"
  $sourceAppSo = Join-Path $releaseDir 'data\app.so'
  if (-not (Test-Path $sourceExe)) {
    throw "Windows release executable not found: $sourceExe"
  }
  if (-not (Test-Path $sourceAppSo)) {
    throw "Windows release app.so not found: $sourceAppSo"
  }

  $installerBrandDir = Join-Path 'D:\Projects\Grib\LocalLinkSchool\muneo_installer\build\windows\x64\runner\branding' $BrandName
  $installerBrandDataDir = Join-Path $installerBrandDir 'data'
  New-Item -ItemType Directory -Path $installerBrandDataDir -Force | Out-Null

  Copy-Item -LiteralPath $sourceExe -Destination (Join-Path $installerBrandDir "$binaryName.exe") -Force
  Copy-Item -LiteralPath $sourceAppSo -Destination (Join-Path $installerBrandDataDir 'app.so') -Force
  Write-Host "[copy] Windows release artifacts copied to installer branding: $installerBrandDir"
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
  if ($Mode -eq 'release') {
    Copy-WindowsReleaseBrandArtifacts -BrandName $Brand
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

& $isccPath "/DBrand=$Brand" "/DAppVersion=$appVersion" "/DServiceType=$ServiceType" .\installer\MuneoInstaller.iss
if ($LASTEXITCODE -ne 0) {
  throw "Inno Setup build failed with exit code $LASTEXITCODE"
}

Write-Host "[OK] Installer built. brand=$Brand mode=$Mode version=$appVersion serviceType=$ServiceType"

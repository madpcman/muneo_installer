param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('claix', 'ai_mclassing')]
  [string]$Brand
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Update-FileRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement
  )
  $raw = Get-Content -Raw -Path $Path
  $updated = [System.Text.RegularExpressions.Regex]::Replace($raw, $Pattern, $Replacement)
  if ($updated -ne $raw) {
    Write-Utf8NoBom -Path $Path -Content $updated
  }
}

function Get-ExistingTextEncoding {
  param([Parameter(Mandatory = $true)][string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    return (New-Object System.Text.UTF8Encoding -ArgumentList $true, $true)
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    return [System.Text.Encoding]::Unicode
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
    return [System.Text.Encoding]::BigEndianUnicode
  }

  $strictUtf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false, $true
  try {
    [void]$strictUtf8.GetString($bytes)
    return $strictUtf8
  } catch {
    return [System.Text.Encoding]::Default
  }
}

function Update-FileRegexPreserveEncoding {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement
  )
  $encoding = Get-ExistingTextEncoding -Path $Path
  $raw = [System.IO.File]::ReadAllText($Path, $encoding)
  $updated = [System.Text.RegularExpressions.Regex]::Replace($raw, $Pattern, $Replacement)
  if ($updated -ne $raw) {
    [System.IO.File]::WriteAllText($Path, $updated, $encoding)
  }
}

function Resolve-RepoPath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  return (Join-Path $repoRoot $RelativePath)
}

function Normalize-ArgbHex {
  param([Parameter(Mandatory = $true)][string]$Value)
  $s = $Value.Trim()
  if ($s.StartsWith('#')) {
    $hex = $s.Substring(1)
    if ($hex.Length -eq 6) { return "0xFF$($hex.ToUpper())" }
    if ($hex.Length -eq 8) { return "0x$($hex.ToUpper())" }
  }
  if ($s -match '^0x[0-9a-fA-F]{8}$') { return "0x$($s.Substring(2).ToUpper())" }
  if ($s -match '^[0-9a-fA-F]{6}$') { return "0xFF$($s.ToUpper())" }
  if ($s -match '^[0-9a-fA-F]{8}$') { return "0x$($s.ToUpper())" }
  throw "Invalid color hex value: $Value"
}

function Escape-DartString {
  param([Parameter(Mandatory = $true)][string]$Value)
  return $Value.Replace('\', '\\').Replace("'", "\'")
}

function Escape-XmlText {
  param([Parameter(Mandatory = $true)][string]$Value)
  return $Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

function Convert-FromCodePoints {
  param([Parameter(Mandatory = $true)][int[]]$CodePoints)
  $sb = New-Object System.Text.StringBuilder
  foreach ($codePoint in $CodePoints) {
    [void]$sb.Append([char]$codePoint)
  }
  return $sb.ToString()
}

function Normalize-Opacity {
  param([Parameter(Mandatory = $true)]$Value)
  $n = 0.0
  try {
    $n = [double]$Value
  } catch {
    throw "Invalid opacity value: $Value"
  }
  if ($n -lt 0.0 -or $n -gt 1.0) {
    throw "Opacity out of range (0..1): $Value"
  }
  return ('{0:0.###}' -f $n)
}

function Normalize-NonNegativeDouble {
  param([Parameter(Mandatory = $true)]$Value)
  $n = 0.0
  try {
    $n = [double]$Value
  } catch {
    throw "Invalid numeric value: $Value"
  }
  if ($n -lt 0.0) {
    throw "Numeric value must be >= 0: $Value"
  }
  return ('{0:0.###}' -f $n)
}

function Normalize-PositiveDouble {
  param([Parameter(Mandatory = $true)]$Value)
  $n = 0.0
  try {
    $n = [double]$Value
  } catch {
    throw "Invalid numeric value: $Value"
  }
  if ($n -le 0.0) {
    throw "Numeric value must be > 0: $Value"
  }
  return ('{0:0.###}' -f $n)
}

function Normalize-Bool {
  param([Parameter(Mandatory = $true)]$Value)
  try {
    return [System.Convert]::ToBoolean($Value).ToString().ToLowerInvariant()
  } catch {
    throw "Invalid boolean value: $Value"
  }
}

function Get-ThreePartFileVersion {
  param([Parameter(Mandatory = $true)][string]$Path)
  $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
  $versionText = [string]$versionInfo.FileVersion
  if ([string]::IsNullOrWhiteSpace($versionText)) {
    $versionText = [string]$versionInfo.ProductVersion
  }
  if ($versionText -match '(\d+)\.(\d+)\.(\d+)') {
    return "$($Matches[1]).$($Matches[2]).$($Matches[3])"
  }
  throw "Unable to read a three-part file version from: $Path"
}

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
  $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$repoRoot = [string](Resolve-Path (Join-Path $scriptRoot '..'))

$brandConfigPath = Resolve-RepoPath 'branding\brands.json'
$configRoot = Get-Content -Raw -Path $brandConfigPath | ConvertFrom-Json
$config = $configRoot.$Brand
if ($null -eq $config) {
  throw "Brand '$Brand' not found in branding/brands.json"
}

$displayName = [string]$config.display_name
$packageName = [string]$config.package_name
$updateRequestPackageName = if ($null -ne $config.update_request_package_name -and -not [string]::IsNullOrWhiteSpace([string]$config.update_request_package_name)) {
  [string]$config.update_request_package_name
} else {
  $packageName
}
$windowsBinaryName = [string]$config.windows_binary_name
$windowsFileDescription = [string]$config.windows_file_description
$windowsProductName = [string]$config.windows_product_name
$windowsLegalCopyright = [string]$config.windows_legal_copyright
$brandAssetsDir = Join-Path $repoRoot ([string]$config.assets_dir)
$logoIconSvg = Join-Path $brandAssetsDir 'logo_icon.svg'
$brandAppIconIco = Join-Path $brandAssetsDir 'app_icon.ico'
$colors = $config.colors
$texts = $config.texts
$dimensions = $config.dimensions

if ([string]::IsNullOrWhiteSpace($windowsFileDescription)) {
  $windowsFileDescription = $windowsBinaryName
}
if ([string]::IsNullOrWhiteSpace($windowsProductName)) {
  $windowsProductName = $displayName
}
if ([string]::IsNullOrWhiteSpace($windowsLegalCopyright)) {
  $windowsLegalCopyright = "Copyright (C) 2025 com.grib. All rights reserved."
}
if ($null -eq $colors) {
  throw "Missing colors config in branding/brands.json for brand '$Brand'"
}
if ($null -eq $texts) {
  throw "Missing texts config in branding/brands.json for brand '$Brand'"
}
if ($null -eq $dimensions) {
  throw "Missing dimensions config in branding/brands.json for brand '$Brand'"
}

if (-not (Test-Path $brandAssetsDir)) { throw "Missing brand assets dir: $brandAssetsDir" }
if (-not (Test-Path $logoIconSvg)) { throw "Missing logo icon svg in brand assets: $logoIconSvg" }

# 1) Windows metadata / binary name / app window title.
Update-FileRegex -Path (Resolve-RepoPath 'windows/CMakeLists.txt') -Pattern 'set\(BINARY_NAME\s+"[^"]+"\)' -Replacement "set(BINARY_NAME `"$windowsBinaryName`")"
Update-FileRegex -Path (Resolve-RepoPath 'windows/runner/Runner.rc') -Pattern 'VALUE\s+"FileDescription",\s+"[^"]+"' -Replacement "VALUE `"FileDescription`", `"$windowsFileDescription`""
Update-FileRegex -Path (Resolve-RepoPath 'windows/runner/Runner.rc') -Pattern 'VALUE\s+"InternalName",\s+"[^"]+"' -Replacement "VALUE `"InternalName`", `"$windowsBinaryName`""
Update-FileRegex -Path (Resolve-RepoPath 'windows/runner/Runner.rc') -Pattern 'VALUE\s+"LegalCopyright",\s+"[^"]+"' -Replacement "VALUE `"LegalCopyright`", `"$windowsLegalCopyright`""
Update-FileRegex -Path (Resolve-RepoPath 'windows/runner/Runner.rc') -Pattern 'VALUE\s+"OriginalFilename",\s+"[^"]+\.exe"' -Replacement "VALUE `"OriginalFilename`", `"$windowsBinaryName.exe`""
Update-FileRegex -Path (Resolve-RepoPath 'windows/runner/Runner.rc') -Pattern 'VALUE\s+"ProductName",\s+"[^"]+"' -Replacement "VALUE `"ProductName`", `"$windowsProductName`""
Update-FileRegex -Path (Resolve-RepoPath 'windows/runner/main.cpp') -Pattern 'L"Local\\[^"]+_single_instance_guard"' -Replacement "L`"Local\\$windowsBinaryName`_single_instance_guard`""

# 2) Android package / app label. Keep component class names fixed to avoid
# source package rewrites on every brand switch.
Update-FileRegex -Path (Resolve-RepoPath 'android/app/build.gradle.kts') -Pattern 'namespace\s*=\s*"[^"]+"' -Replacement 'namespace = "kr.co.grib.claix"'
Update-FileRegex -Path (Resolve-RepoPath 'android/app/build.gradle.kts') -Pattern 'applicationId\s*=\s*"[^"]+"' -Replacement "applicationId = `"$packageName`""
Update-FileRegex -Path (Resolve-RepoPath 'android/app/src/main/AndroidManifest.xml') -Pattern 'android:label="[^"]+"' -Replacement "android:label=`"$displayName`""
Update-FileRegex -Path (Resolve-RepoPath 'android/app/src/main/AndroidManifest.xml') -Pattern 'android:name="\.ScreenCaptureService"' -Replacement 'android:name="kr.co.grib.claix.ScreenCaptureService"'
Update-FileRegex -Path (Resolve-RepoPath 'android/app/src/main/AndroidManifest.xml') -Pattern 'android:name="\.OverlayService"' -Replacement 'android:name="kr.co.grib.claix.OverlayService"'
Update-FileRegex -Path (Resolve-RepoPath 'android/app/src/main/AndroidManifest.xml') -Pattern 'android:name="\.MainActivity"' -Replacement 'android:name="kr.co.grib.claix.MainActivity"'
Update-FileRegex -Path (Resolve-RepoPath 'android/app/src/main/AndroidManifest.xml') -Pattern 'android:name="\.BoardPopupActivity"' -Replacement 'android:name="kr.co.grib.claix.BoardPopupActivity"'

# 3) Generate brand color constants for Flutter UI.
$brandColorsPath = Resolve-RepoPath 'lib/core/branding/brand_colors.dart'
$primaryGradientStart = Normalize-ArgbHex ([string]$colors.primary_gradient_start)
$primaryGradientEnd = Normalize-ArgbHex ([string]$colors.primary_gradient_end)
$primaryButtonText = Normalize-ArgbHex ([string]$colors.primary_button_text)
$cardShadow = Normalize-ArgbHex ([string]$colors.card_shadow)
$selectTileBorderSelected = Normalize-ArgbHex ([string]$colors.select_tile_border_selected)
$selectTileBorderDefault = Normalize-ArgbHex ([string]$colors.select_tile_border_default)
$selectTileShadow = Normalize-ArgbHex ([string]$colors.select_tile_shadow)
$selectPromptBg = Normalize-ArgbHex ([string]$colors.select_prompt_bg)
$selectPromptText = Normalize-ArgbHex ([string]$colors.select_prompt_text)
$inputFillBg = Normalize-ArgbHex ([string]$colors.input_fill_bg)
$loginInputFocusedBorder = Normalize-ArgbHex ([string]$colors.login_input_focused_border)
$labelText = Normalize-ArgbHex ([string]$colors.label_text)
$bottomBarActive = Normalize-ArgbHex ([string]$colors.bottombar_active)
$bottomBarInactive = Normalize-ArgbHex ([string]$colors.bottombar_inactive)
$bottomBarDanger = Normalize-ArgbHex ([string]$colors.bottombar_danger)
$bottomBarGroupEnabledBg = Normalize-ArgbHex ([string]$colors.bottombar_group_enabled_bg)
$bottomBarFuncGradientStart = Normalize-ArgbHex ([string]$colors.bottombar_func_gradient_start)
$bottomBarFuncGradientEnd = Normalize-ArgbHex ([string]$colors.bottombar_func_gradient_end)
$loginBgOpacity = Normalize-Opacity $colors.login_bg_opacity
$groupLessonTopButtonPrimary = Normalize-ArgbHex ([string]$colors.group_lesson_top_button_primary)
$groupLessonTopButtonDanger = Normalize-ArgbHex ([string]$colors.group_lesson_top_button_danger)
$groupLessonTopButtonOutlineBg = Normalize-ArgbHex ([string]$colors.group_lesson_top_button_outline_bg)
$groupLessonTopButtonOutlineBorder = Normalize-ArgbHex ([string]$colors.group_lesson_top_button_outline_border)
$groupLessonTopButtonOutlineText = Normalize-ArgbHex ([string]$colors.group_lesson_top_button_outline_text)
$groupLessonArrangeTitleText = Normalize-ArgbHex ([string]$colors.group_lesson_arrange_title_text)
$groupLessonArrangeTitleBackground = Normalize-ArgbHex ([string]$colors.group_lesson_arrange_title_background)
$groupLessonRenameButtonBg = Normalize-ArgbHex ([string]$colors.group_lesson_rename_button_bg)
$sidePanelTitleBackground = Normalize-ArgbHex ([string]$colors.side_panel_title_background)
$settingsButtonPrimary = Normalize-ArgbHex ([string]$colors.settings_button_primary)
$settingsButtonText = Normalize-ArgbHex ([string]$colors.settings_button_text)
$settingsButtonBackground = Normalize-ArgbHex ([string]$colors.settings_button_background)
$settingsNameOuterGradientStart = Normalize-ArgbHex ([string]$colors.settings_name_outer_gradient_start)
$settingsNameOuterGradientEnd = Normalize-ArgbHex ([string]$colors.settings_name_outer_gradient_end)
$settingsRoleImageHeight = Normalize-NonNegativeDouble $colors.settings_role_image_height
$settingsFileSelectButtonRadius = Normalize-NonNegativeDouble $colors.settings_file_select_button_radius
$chatFileSelectButtonRadius = Normalize-NonNegativeDouble $colors.chat_file_select_button_radius
$chatInputBorderRadius = Normalize-NonNegativeDouble $colors.chat_input_border_radius
$chatFileButtonBackground = Normalize-ArgbHex ([string]$colors.chat_file_button_background)
$chatFileButtonIcon = Normalize-ArgbHex ([string]$colors.chat_file_button_icon)
$chatSendButtonBackground = Normalize-ArgbHex ([string]$colors.chat_send_button_background)
$chatSendButtonIconEnabled = Normalize-ArgbHex ([string]$colors.chat_send_button_icon_enabled)
$chatSendButtonIconDisabled = Normalize-ArgbHex ([string]$colors.chat_send_button_icon_disabled)
$chatShowAvatar = Normalize-Bool $colors.chat_show_avatar
$chatBubbleSentBackground = Normalize-ArgbHex ([string]$colors.chat_bubble_sent_background)
$chatBubbleReceivedBackground = Normalize-ArgbHex ([string]$colors.chat_bubble_received_background)
$chatBubbleSentTimeText = Normalize-ArgbHex ([string]$colors.chat_bubble_sent_time_text)
$chatBubbleReceivedTimeText = Normalize-ArgbHex ([string]$colors.chat_bubble_received_time_text)
$chatComposerBottomGradient = Normalize-Bool $colors.chat_composer_bottom_gradient
$loginBgCharacterHeight = Normalize-NonNegativeDouble $colors.login_bg_character_height
$bottomBarShowLeftLogo = Normalize-Bool $colors.bottom_bar_show_left_logo
$quickCommandBarRadius = Normalize-NonNegativeDouble $colors.quick_command_bar_radius
$quickCommandBarButtonRadius = Normalize-NonNegativeDouble $colors.quick_command_bar_button_radius
$quickCommandBarButtonSelectedBackground = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_selected_background)
$quickCommandBarButtonSelectedText = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_selected_text)
$quickCommandBarButtonUnselectedText = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_unselected_text)
$quickCommandBarButtonIconSelected = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_icon_selected)
$quickCommandBarButtonIconUnselected = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_icon_unselected)
$quickCommandBarButtonSelectedInnerBackground = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_selected_inner_background)
$quickCommandBarButtonSelectedInnerShadow = Normalize-ArgbHex ([string]$colors.quick_command_bar_button_selected_inner_shadow)

$brandColorsDart = @"
import 'package:flutter/material.dart';

/// Auto-generated by scripts/apply_brand.ps1
/// Do not edit manually.
class BrandColors {
  static const Color primaryGradientStart = Color($primaryGradientStart);
  static const Color primaryGradientEnd = Color($primaryGradientEnd);
  static const Color primaryButtonText = Color($primaryButtonText);
  static const Color cardShadow = Color($cardShadow);

  static const Color selectTileBorderSelected = Color($selectTileBorderSelected);
  static const Color selectTileBorderDefault = Color($selectTileBorderDefault);
  static const Color selectTileShadow = Color($selectTileShadow);

  static const Color selectPromptBackground = Color($selectPromptBg);
  static const Color selectPromptText = Color($selectPromptText);

  static const Color inputFillBackground = Color($inputFillBg);
  static const Color loginInputFocusedBorder = Color($loginInputFocusedBorder);
  static const Color labelText = Color($labelText);

  static const Color bottomBarActive = Color($bottomBarActive);
  static const Color bottomBarInactive = Color($bottomBarInactive);
  static const Color bottomBarDanger = Color($bottomBarDanger);
  static const Color bottomBarGroupEnabledBackground = Color($bottomBarGroupEnabledBg);
  static const Color bottomBarFuncGradientStart = Color($bottomBarFuncGradientStart);
  static const Color bottomBarFuncGradientEnd = Color($bottomBarFuncGradientEnd);

  static const double loginBgOpacity = $loginBgOpacity;

  static const Color groupLessonTopButtonPrimary = Color($groupLessonTopButtonPrimary);
  static const Color groupLessonTopButtonDanger = Color($groupLessonTopButtonDanger);
  static const Color groupLessonTopButtonOutlineBackground = Color($groupLessonTopButtonOutlineBg);
  static const Color groupLessonTopButtonOutlineBorder = Color($groupLessonTopButtonOutlineBorder);
  static const Color groupLessonTopButtonOutlineText = Color($groupLessonTopButtonOutlineText);
  static const Color groupLessonArrangeTitleText = Color($groupLessonArrangeTitleText);
  static const Color groupLessonArrangeTitleBackground = Color($groupLessonArrangeTitleBackground);
  static const Color groupLessonRenameButtonBackground = Color($groupLessonRenameButtonBg);

  static const Color sidePanelTitleBackground = Color($sidePanelTitleBackground);

  static const Color settingsButtonPrimary = Color($settingsButtonPrimary);
  static const Color settingsButtonText = Color($settingsButtonText);
  static const Color settingsButtonBackground = Color($settingsButtonBackground);
  static const Color settingsNameOuterGradientStart = Color($settingsNameOuterGradientStart);
  static const Color settingsNameOuterGradientEnd = Color($settingsNameOuterGradientEnd);

  static const double settingsRoleImageHeight = $settingsRoleImageHeight;
  static const double settingsFileSelectButtonRadius = $settingsFileSelectButtonRadius;
  static const double chatFileSelectButtonRadius = $chatFileSelectButtonRadius;
  static const double chatInputBorderRadius = $chatInputBorderRadius;
  static const Color chatFileButtonBackground = Color($chatFileButtonBackground);
  static const Color chatFileButtonIcon = Color($chatFileButtonIcon);
  static const Color chatSendButtonBackground = Color($chatSendButtonBackground);
  static const Color chatSendButtonIconEnabled = Color($chatSendButtonIconEnabled);
  static const Color chatSendButtonIconDisabled = Color($chatSendButtonIconDisabled);
  static const bool chatShowAvatar = $chatShowAvatar;
  static const Color chatBubbleSentBackground = Color($chatBubbleSentBackground);
  static const Color chatBubbleReceivedBackground = Color($chatBubbleReceivedBackground);
  static const Color chatBubbleSentTimeText = Color($chatBubbleSentTimeText);
  static const Color chatBubbleReceivedTimeText = Color($chatBubbleReceivedTimeText);
  static const bool chatComposerBottomGradient = $chatComposerBottomGradient;
  static const double loginBgCharacterHeight = $loginBgCharacterHeight;
  static const bool bottomBarShowLeftLogo = $bottomBarShowLeftLogo;
  static const double quickCommandBarRadius = $quickCommandBarRadius;
  static const double quickCommandBarButtonRadius = $quickCommandBarButtonRadius;
  static const Color quickCommandBarButtonSelectedBackground = Color($quickCommandBarButtonSelectedBackground);
  static const Color quickCommandBarButtonSelectedText = Color($quickCommandBarButtonSelectedText);
  static const Color quickCommandBarButtonUnselectedText = Color($quickCommandBarButtonUnselectedText);
  static const Color quickCommandBarButtonIconSelected = Color($quickCommandBarButtonIconSelected);
  static const Color quickCommandBarButtonIconUnselected = Color($quickCommandBarButtonIconUnselected);
  static const Color quickCommandBarButtonSelectedInnerBackground = Color($quickCommandBarButtonSelectedInnerBackground);
  static const Color quickCommandBarButtonSelectedInnerShadow = Color($quickCommandBarButtonSelectedInnerShadow);
}
"@
Write-Utf8NoBom -Path $brandColorsPath -Content $brandColorsDart

# 3.5) Generate Android quickbar style resources from brand colors.
$androidQuickBgSelectedPath = Resolve-RepoPath 'android/app/src/main/res/drawable/bg_quick_button_selected.xml'
$androidOverlayPanelPath = Resolve-RepoPath 'android/app/src/main/res/drawable/bg_overlay_panel.xml'
$androidOverlayPanelStatePath = Resolve-RepoPath 'android/app/src/main/res/drawable/bg_overlay_panel_state.xml'
$androidQuickDecorClipRoundPath = Resolve-RepoPath 'android/app/src/main/res/drawable/quick_decor_clip_round.xml'
$androidQuickDecorClipLeftRoundPath = Resolve-RepoPath 'android/app/src/main/res/drawable/quick_decor_clip_left_round.xml'
$androidQuickTextPath = Resolve-RepoPath 'android/app/src/main/res/color/quick_button_text.xml'
$androidQuickIconTintPath = Resolve-RepoPath 'android/app/src/main/res/color/quick_button_icon_tint.xml'

$androidSelectedBgHex = '#{0}' -f $quickCommandBarButtonSelectedBackground.Substring(4)
$androidSelectedInnerBgHex = '#{0}' -f $quickCommandBarButtonSelectedInnerBackground.Substring(4)
$androidSelectedInnerShadowHex = '#{0}' -f $quickCommandBarButtonSelectedInnerShadow.Substring(4)
$androidSelectedTextHex = '#{0}' -f $quickCommandBarButtonSelectedText.Substring(4)
$androidUnselectedTextHex = '#{0}' -f $quickCommandBarButtonUnselectedText.Substring(4)
$androidIconSelectedHex = '#{0}' -f $quickCommandBarButtonIconSelected.Substring(4)
$androidIconUnselectedHex = '#{0}' -f $quickCommandBarButtonIconUnselected.Substring(4)

$buttonRadiusDpValue = [double]$quickCommandBarButtonRadius
$innerRadiusDpValue = $buttonRadiusDpValue - 1.0
if ($innerRadiusDpValue -lt 0.0) { $innerRadiusDpValue = 0.0 }
$panelRadiusDpValue = [double]$quickCommandBarRadius
$buttonRadiusDp = ('{0:0.###}' -f $buttonRadiusDpValue)
$innerRadiusDp = ('{0:0.###}' -f $innerRadiusDpValue)
$panelRadiusDp = ('{0:0.###}' -f $panelRadiusDpValue)

$androidQuickBgSelectedXml = @"
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="$androidSelectedBgHex" />
            <corners android:radius="${buttonRadiusDp}dp" />
        </shape>
    </item>
    <item
        android:left="1dp"
        android:top="1dp"
        android:right="1dp"
        android:bottom="1dp">
        <shape android:shape="rectangle">
            <solid android:color="$androidSelectedInnerBgHex" />
            <stroke
                android:width="1dp"
                android:color="$androidSelectedInnerShadowHex" />
            <corners android:radius="${innerRadiusDp}dp" />
        </shape>
    </item>
</layer-list>
"@
Write-Utf8NoBom -Path $androidQuickBgSelectedPath -Content $androidQuickBgSelectedXml

$androidOverlayPanelXml = @"
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">

    <item android:left="0dp" android:top="2dp" android:right="0dp" android:bottom="6dp">
        <shape android:shape="rectangle">
            <corners android:radius="${panelRadiusDp}dp"/>
            <solid android:color="#1A000000"/>
        </shape>
    </item>

    <item>
        <shape android:shape="rectangle">
            <corners android:radius="${panelRadiusDp}dp"/>
            <solid android:color="#FFFFFFFF"/>
        </shape>
    </item>

    <item>
        <shape android:shape="rectangle">
            <corners android:radius="${panelRadiusDp}dp"/>
            <stroke
                android:width="1dp"
                android:color="#1A000000"/>
        </shape>
    </item>

</layer-list>
"@
Write-Utf8NoBom -Path $androidOverlayPanelPath -Content $androidOverlayPanelXml

$androidOverlayPanelStateXml = @"
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">

    <item android:state_pressed="true">
        <layer-list>
            <item>
                <shape android:shape="rectangle">
                    <corners android:radius="${panelRadiusDp}dp"/>
                    <solid android:color="#EDEFF3"/>
                </shape>
            </item>
            <item>
                <shape android:shape="rectangle">
                    <corners android:radius="${panelRadiusDp}dp"/>
                    <stroke
                        android:width="1dp"
                        android:color="#22000000"/>
                </shape>
            </item>
        </layer-list>
    </item>

    <item android:drawable="@drawable/bg_overlay_panel"/>
</selector>
"@
Write-Utf8NoBom -Path $androidOverlayPanelStatePath -Content $androidOverlayPanelStateXml

$androidQuickDecorClipRoundXml = @"
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners android:radius="${panelRadiusDp}dp" />
    <solid android:color="@android:color/transparent" />
</shape>
"@
Write-Utf8NoBom -Path $androidQuickDecorClipRoundPath -Content $androidQuickDecorClipRoundXml

$androidQuickDecorClipLeftRoundXml = @"
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <corners
        android:topLeftRadius="${panelRadiusDp}dp"
        android:bottomLeftRadius="${panelRadiusDp}dp"
        android:topRightRadius="0dp"
        android:bottomRightRadius="0dp" />
    <solid android:color="@android:color/transparent" />
</shape>
"@
Write-Utf8NoBom -Path $androidQuickDecorClipLeftRoundPath -Content $androidQuickDecorClipLeftRoundXml

$androidQuickTextXml = @"
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:state_selected="true" android:color="$androidSelectedTextHex" />
    <item android:state_pressed="true" android:color="$androidSelectedTextHex" />
    <item android:color="$androidUnselectedTextHex" />
</selector>
"@
Write-Utf8NoBom -Path $androidQuickTextPath -Content $androidQuickTextXml

$androidQuickIconTintXml = @"
<?xml version="1.0" encoding="utf-8"?>
<selector xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:state_selected="true" android:color="$androidIconSelectedHex" />
    <item android:state_pressed="true" android:color="$androidIconSelectedHex" />
    <item android:color="$androidIconUnselectedHex" />
</selector>
"@
Write-Utf8NoBom -Path $androidQuickIconTintPath -Content $androidQuickIconTintXml

$brandTextsPath = Resolve-RepoPath 'lib/core/branding/brand_texts.dart'
$bottomBarMonitoring = Escape-DartString ([string]$texts.bottombar_monitoring)
$bottomBarGroupLesson = Escape-DartString ([string]$texts.bottombar_group_lesson)
$bottomBarScreenShare = Escape-DartString ([string]$texts.bottombar_screen_share)
$bottomBarFocusMode = Escape-DartString ([string]$texts.bottombar_focus_mode)
$bottomBarChat = Escape-DartString ([string]$texts.bottombar_chat)
$bottomBarSettings = Escape-DartString ([string]$texts.bottombar_settings)
$bottomBarEndClass = Escape-DartString ([string]$texts.bottombar_end_class)
$lessonNormal = Escape-DartString ([string]$texts.lesson_normal)
$lessonGroup = Escape-DartString ([string]$texts.lesson_group)
$lessonNormalProgress = Escape-DartString ([string]$texts.lesson_normal_progress)
$lessonGroupProgress = Escape-DartString ([string]$texts.lesson_group_progress)
$overlayBtnMain = Convert-FromCodePoints @(0xBA54, 0xC778)
$overlayBtnScreen = Convert-FromCodePoints @(0xD654, 0xBA74, 0xACF5, 0xC720)
$overlayBtnTranslate = 'AI' + (Convert-FromCodePoints @(0xBC88, 0xC5ED))
$overlayBtnSettings = Convert-FromCodePoints @(0xC124, 0xC815)
$overlayBtnMic = Convert-FromCodePoints @(0xB9C8, 0xC774, 0xD06C)
$overlayBtnClose = Convert-FromCodePoints @(0xB2EB, 0xAE30)
$displayNameXml = Escape-XmlText $displayName
$bottomBarChatXml = Escape-XmlText ([string]$texts.bottombar_chat)
$overlayBtnMainXml = Escape-XmlText $overlayBtnMain
$overlayBtnScreenXml = Escape-XmlText $overlayBtnScreen
$overlayBtnTranslateXml = Escape-XmlText $overlayBtnTranslate
$overlayBtnSettingsXml = Escape-XmlText $overlayBtnSettings
$overlayBtnMicXml = Escape-XmlText $overlayBtnMic
$overlayBtnCloseXml = Escape-XmlText $overlayBtnClose

$androidStringsPath = Resolve-RepoPath 'android/app/src/main/res/values/strings.xml'
$androidOverlayStringsXml = @"
<resources>
    <string name="app_name">$displayNameXml</string>
    <string name="overlay_btn_main">$overlayBtnMainXml</string>
    <string name="overlay_btn_screen">$overlayBtnScreenXml</string>
    <string name="overlay_btn_chat">$bottomBarChatXml</string>
    <string name="overlay_btn_translate">$overlayBtnTranslateXml</string>
    <string name="overlay_btn_settings">$overlayBtnSettingsXml</string>
    <string name="overlay_btn_mic">$overlayBtnMicXml</string>
    <string name="overlay_btn_close">$overlayBtnCloseXml</string>
</resources>
"@
Write-Utf8NoBom -Path $androidStringsPath -Content $androidOverlayStringsXml

$brandTextsDart = @"
/// Auto-generated by scripts/apply_brand.ps1
/// Do not edit manually.
class BrandTexts {
  static const String bottomBarMonitoring = '$bottomBarMonitoring';
  static const String bottomBarGroupLesson = '$bottomBarGroupLesson';
  static const String bottomBarScreenShare = '$bottomBarScreenShare';
  static const String bottomBarFocusMode = '$bottomBarFocusMode';
  static const String bottomBarChat = '$bottomBarChat';
  static const String bottomBarSettings = '$bottomBarSettings';
  static const String bottomBarEndClass = '$bottomBarEndClass';

  static const String lessonNormal = '$lessonNormal';
  static const String lessonGroup = '$lessonGroup';
  static const String lessonNormalProgress = '$lessonNormalProgress';
  static const String lessonGroupProgress = '$lessonGroupProgress';
}
"@
Write-Utf8NoBom -Path $brandTextsPath -Content $brandTextsDart

$brandLayoutPath = Resolve-RepoPath 'lib/core/branding/brand_layout.dart'
$commonPopupWidth = Normalize-PositiveDouble $dimensions.common_popup_width
$commonPopupHeight = Normalize-PositiveDouble $dimensions.common_popup_height

$brandLayoutDart = @"
/// Auto-generated by scripts/apply_brand.ps1
/// Do not edit manually.
class BrandLayout {
  static const double commonPopupWidth = $commonPopupWidth;
  static const double commonPopupHeight = $commonPopupHeight;
}
"@
Write-Utf8NoBom -Path $brandLayoutPath -Content $brandLayoutDart

$brandConfigPath = Resolve-RepoPath 'lib/core/branding/brand_config.dart'
$escapedUpdateRequestPackageName = Escape-DartString $updateRequestPackageName
$brandConfigDart = @"
/// Auto-generated by scripts/apply_brand.ps1
/// Do not edit manually.
class BrandConfig {
  static const String packageName = '$packageName';
  static const String updateRequestPackageName = '$escapedUpdateRequestPackageName';
}
"@
Write-Utf8NoBom -Path $brandConfigPath -Content $brandConfigDart

# 4) Replace the entire shared assets tree from brand assets.
$targetAssetsDir = Resolve-RepoPath 'assets'
if (Test-Path $targetAssetsDir) {
  Remove-Item -Path (Join-Path $targetAssetsDir '*') -Recurse -Force -ErrorAction SilentlyContinue
}
Copy-Item -Path (Join-Path $brandAssetsDir '*') -Destination $targetAssetsDir -Recurse -Force

# 4.5) Replace Android native lock overlay drawables used by view_screen_lock_overlay.xml.
$androidDrawableDir = Resolve-RepoPath 'android\app\src\main\res\drawable'
$brandLockBoard = Join-Path $brandAssetsDir 'character\lock_back_board.png'
$brandLockTeacher = Join-Path $brandAssetsDir 'character\lock_back_teacher.png'
if (Test-Path $androidDrawableDir) {
  if (Test-Path $brandLockBoard) {
    Copy-Item -Path $brandLockBoard -Destination (Join-Path $androidDrawableDir 'lock_back_board.png') -Force
  }
  if (Test-Path $brandLockTeacher) {
    Copy-Item -Path $brandLockTeacher -Destination (Join-Path $androidDrawableDir 'lock_back_teacher.png') -Force
  }
}

# 5) Generate app icons for Windows/Android/tray from brand icon svg or ico.
python (Resolve-RepoPath 'scripts/generate_brand_assets.py') "$logoIconSvg" "$repoRoot" "$brandAppIconIco"

# 6) Replace built Windows Flutter assets with the applied shared assets.
$builtFlutterAssetsDir = Resolve-RepoPath 'build\windows\x64\runner\Release\data\flutter_assets\assets'
$builtFlutterAssetsParentDir = Split-Path -Parent $builtFlutterAssetsDir
if (-not (Test-Path $builtFlutterAssetsParentDir)) {
  New-Item -ItemType Directory -Path $builtFlutterAssetsParentDir -Force | Out-Null
}
if (Test-Path $builtFlutterAssetsDir) {
  Remove-Item -Path (Join-Path $builtFlutterAssetsDir '*') -Recurse -Force -ErrorAction SilentlyContinue
} else {
  New-Item -ItemType Directory -Path $builtFlutterAssetsDir -Force | Out-Null
}
Copy-Item -Path (Join-Path $targetAssetsDir '*') -Destination $builtFlutterAssetsDir -Recurse -Force

# 7) Copy the selected brand executable and app.so into Release and update installer defines.
$releaseRunnerDir = Resolve-RepoPath 'build\windows\x64\runner\Release'
$brandRunnerDir = Resolve-RepoPath (Join-Path 'build\windows\x64\runner\branding' $Brand)
$brandExecutableName = "$windowsBinaryName.exe"
$sourceBrandExecutable = Join-Path $brandRunnerDir $brandExecutableName
$targetBrandExecutable = Join-Path $releaseRunnerDir $brandExecutableName
$sourceBrandAppSo = Join-Path $brandRunnerDir 'data\app.so'
$targetBrandAppSo = Join-Path $releaseRunnerDir 'data\app.so'
if (-not (Test-Path $sourceBrandExecutable)) {
  throw "Missing brand executable: $sourceBrandExecutable"
}
if (-not (Test-Path $sourceBrandAppSo)) {
  throw "Missing brand app.so: $sourceBrandAppSo"
}
if (-not (Test-Path $releaseRunnerDir)) {
  New-Item -ItemType Directory -Path $releaseRunnerDir -Force | Out-Null
}
if (-not (Test-Path (Split-Path -Parent $targetBrandAppSo))) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $targetBrandAppSo) -Force | Out-Null
}
foreach ($brandProperty in $configRoot.PSObject.Properties) {
  $otherWindowsBinaryName = [string]$brandProperty.Value.windows_binary_name
  if ([string]::IsNullOrWhiteSpace($otherWindowsBinaryName) -or $otherWindowsBinaryName -eq $windowsBinaryName) {
    continue
  }
  $otherBrandExecutable = Join-Path $releaseRunnerDir "$otherWindowsBinaryName.exe"
  if (Test-Path $otherBrandExecutable) {
    Remove-Item -Path $otherBrandExecutable -Force
  }
}
Copy-Item -Path $sourceBrandExecutable -Destination $targetBrandExecutable -Force
Copy-Item -Path $sourceBrandAppSo -Destination $targetBrandAppSo -Force

$installerScriptPath = Resolve-RepoPath 'installer\MuneoInstaller.iss'
$appVersion = Get-ThreePartFileVersion -Path $targetBrandExecutable
Update-FileRegexPreserveEncoding -Path $installerScriptPath -Pattern '(?m)^\s*#define\s+AppVersion\s+"[^"]+"' -Replacement "  #define AppVersion `"$appVersion`""
Update-FileRegexPreserveEncoding -Path $installerScriptPath -Pattern '(?m)^\s*#define\s+Brand\s+"[^"]+"' -Replacement "  #define Brand `"$Brand`""

Write-Host "[OK] Brand '$Brand' applied"
Write-Host "     display_name   : $displayName"
Write-Host "     package_name   : $packageName"
Write-Host "     windows_binary : $windowsBinaryName"
Write-Host "     app_version    : $appVersion"
Write-Host "     file_desc      : $windowsFileDescription"
Write-Host "     product_name   : $windowsProductName"
Write-Host "     copyright      : $windowsLegalCopyright"

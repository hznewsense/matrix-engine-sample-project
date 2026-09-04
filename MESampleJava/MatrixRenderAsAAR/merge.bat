@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Save script path before any shifts
for %%I in ("%~f0") do set "SCRIPT_FILE=%%~fI"
for %%I in ("%~f0") do set "SCRIPT_DIR=%%~dpI"

rem Usage:
rem   merge.bat [-o out.aar] [-m AndroidManifest.xml] [-abi arm64-v8a,armeabi-v7a] [-so <soDirOrSoFile>]... <in1.aar> <in2.aar> ...
rem
rem Auto mode:
rem - If no input AARs are given, will scan:
rem     .\merge\libs\**\*.aar
rem     .\merge\libs\**\*.jar  (copied into output AAR libs/)
rem - If no -so is given, will scan:
rem     .\merge\jniLibs\**\*.so

set "OUT_AAR="
set "MANIFEST="
set "ABI_FILTER="
set "SO_DIRS="
set "INPUT_AARS="

:parse
if "%~1"=="" goto :run

if /I "%~1"=="-o" (
  set "OUT_AAR=%~2"
  shift
  shift
  goto :parse
)
if /I "%~1"=="-m" (
  set "MANIFEST=%~2"
  shift
  shift
  goto :parse
)
if /I "%~1"=="-abi" (
  set "ABI_FILTER=%~2"
  shift
  shift
  goto :parse
)
if /I "%~1"=="-so" (
  if not "%~2"=="" (
    set "SO_DIRS=!SO_DIRS!;%~2"
  )
  shift
  shift
  goto :parse
)

rem positional: input aar
set "INPUT_AARS=!INPUT_AARS!;%~1"
shift
goto :parse

:run
if "%OUT_AAR%"=="" (
  set "OUT_AAR=merged.aar"
)

set "SCRIPT_DIR_NOSLASH=%SCRIPT_DIR%"
if "%SCRIPT_DIR_NOSLASH:~-1%"=="\" set "SCRIPT_DIR_NOSLASH=%SCRIPT_DIR_NOSLASH:~0,-1%"

set "TMP_PS1=%TEMP%\merge_aar_%RANDOM%_%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "& {param($sf,$tmp) $c = Get-Content -LiteralPath $sf -Raw; $m = '###PS_SCRIPT_START###'; $idx = $c.LastIndexOf($m); if ($idx -lt 0) { Write-Host 'ERROR: embedded ps script marker not found' -ForegroundColor Red; exit 1 }; $ps = $c.Substring($idx + $m.Length); $ps = $ps -replace '^[\r\n]+' , ''; Set-Content -LiteralPath $tmp -Value $ps -Encoding UTF8}" -sf "%SCRIPT_FILE%" -tmp "%TMP_PS1%"
if errorlevel 1 exit /b 1

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMP_PS1%" -BaseDir "%SCRIPT_DIR_NOSLASH%" -OutAar "%OUT_AAR%" -Manifest "%MANIFEST%" -AbiFilter "%ABI_FILTER%" -SoDirs "%SO_DIRS%" -InputAars "%INPUT_AARS%"
set "RC=%ERRORLEVEL%"

del /f /q "%TMP_PS1%" >nul 2>nul
exit /b %RC%

###PS_SCRIPT_START###
param(
  [Parameter(Mandatory=$true)][string]$BaseDir,
  [string]$OutAar = 'merged.aar',
  [string]$Manifest = '',
  [string]$AbiFilter = '',
  [string]$SoDirs = '',
  [string]$InputAars = ''
)

$BaseDir = ($BaseDir -replace '[\r\n]', '').Trim().Trim('"')
$BaseDir = [IO.Path]::GetFullPath($BaseDir)

function Fail([string]$msg) {
  Write-Host ('ERROR: ' + $msg) -ForegroundColor Red
  exit 1
}

function Resolve-Base([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return $p }
  if ([IO.Path]::IsPathRooted($p)) { return [IO.Path]::GetFullPath($p) }
  return [IO.Path]::GetFullPath((Join-Path $BaseDir $p))
}

function Get-KnownAbi([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $null }
  switch -Regex ($name) {
    '^arm64-v8a$' { return 'arm64-v8a' }
    '^armeabi-v7a$' { return 'armeabi-v7a' }
    '^x86_64$' { return 'x86_64' }
    '^x86$' { return 'x86' }
    default { return $null }
  }
}

$outFull = Resolve-Base $OutAar

$inputs = @()
$extraJars = @()
foreach ($p in ($InputAars -split ';' | Where-Object { $_ -and $_.Trim() })) {
  $pp = Resolve-Base $p
  if (-not (Test-Path -LiteralPath $pp)) { Fail ('input aar not found: ' + $pp) }
  $inputs += $pp
}

if ($inputs.Count -lt 1) {
  $autoMergeDir = Join-Path $BaseDir 'merge'
  $autoLibsDir = Join-Path $autoMergeDir 'libs'
  $autoJniDir = Join-Path $autoMergeDir 'jniLibs'

  if (Test-Path -LiteralPath $autoLibsDir -PathType Container) {
    $autoAars = Get-ChildItem -LiteralPath $autoLibsDir -Recurse -File -Filter '*.aar' -ErrorAction SilentlyContinue
    foreach ($a in $autoAars) { $inputs += $a.FullName }

    $autoJars = Get-ChildItem -LiteralPath $autoLibsDir -Recurse -File -Filter '*.jar' -ErrorAction SilentlyContinue
    foreach ($j in $autoJars) { $extraJars += $j.FullName }
  }

  if ([string]::IsNullOrWhiteSpace($SoDirs) -and (Test-Path -LiteralPath $autoJniDir -PathType Container)) {
    $SoDirs = $autoJniDir
  }
}

if ($inputs.Count -lt 1) { Fail 'no input aars specified (pass input .aar files, or put them under .\merge\libs next to this script)' }

$abiSet = $null
if ($AbiFilter -and $AbiFilter.Trim()) {
  $abiSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach ($a in ($AbiFilter -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) { [void]$abiSet.Add($a) }
}

$jar = (Get-Command jar.exe -ErrorAction SilentlyContinue)
if (-not $jar) {
  if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME 'bin\jar.exe'
    if (Test-Path -LiteralPath $candidate) { $jar = Get-Command $candidate }
  }
}
if (-not $jar) { Fail 'cannot find jar.exe (install JDK or add it to PATH / set JAVA_HOME)' }

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue | Out-Null

function Expand-ArchiveFile([string]$zipPath,[string]$destDir) {
  if (Test-Path -LiteralPath $destDir) {
    Remove-Item -LiteralPath $destDir -Recurse -Force
  }
  $null = New-Item -ItemType Directory -Path $destDir -Force
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destDir)
}

$workRoot = Join-Path $env:TEMP ('merge_aar_' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $workRoot -Force

$outDir = Join-Path $workRoot 'out'
$null = New-Item -ItemType Directory -Path $outDir -Force

$outRes = Join-Path $outDir 'res'
$outAssets = Join-Path $outDir 'assets'
$outJni = Join-Path $outDir 'jni'
$outLibs = Join-Path $outDir 'libs'
$null = New-Item -ItemType Directory -Path $outRes,$outAssets,$outJni,$outLibs -Force

foreach ($jarPath in $extraJars) {
  if (Test-Path -LiteralPath $jarPath) {
    Copy-Item -LiteralPath $jarPath -Destination (Join-Path $outLibs ([IO.Path]::GetFileName($jarPath))) -Force
  }
}

$classesExtract = Join-Path $workRoot 'classes_extract'
$null = New-Item -ItemType Directory -Path $classesExtract -Force

$manifestWritten = $false
$manifestSource = $null

if ($Manifest -and $Manifest.Trim()) {
  $mFull = Resolve-Base $Manifest
  if (-not (Test-Path -LiteralPath $mFull)) { Fail ('manifest not found: ' + $mFull) }
  Copy-Item -LiteralPath $mFull -Destination (Join-Path $outDir 'AndroidManifest.xml') -Force
  $manifestWritten = $true
  $manifestSource = $mFull
}

function CopyTree([string]$src,[string]$dst) {
  if (-not (Test-Path -LiteralPath $src)) { return }
  $items = Get-ChildItem -LiteralPath $src -Recurse -Force -File
  foreach ($it in $items) {
    $rel = $it.FullName.Substring($src.Length).TrimStart('\','/')
    $target = Join-Path $dst $rel
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    Copy-Item -LiteralPath $it.FullName -Destination $target -Force
  }
}

function CopyJniTree([string]$srcJni,[string]$dstJni,[System.Collections.Generic.HashSet[string]]$abiSet) {
  if (-not (Test-Path -LiteralPath $srcJni)) { return }

  $abiDirs = Get-ChildItem -LiteralPath $srcJni -Directory -ErrorAction SilentlyContinue
  foreach ($abi in $abiDirs) {
    if ($abiSet -and (-not $abiSet.Contains($abi.Name))) { continue }
    $dstAbi = Join-Path $dstJni $abi.Name
    if (-not (Test-Path -LiteralPath $dstAbi)) { $null = New-Item -ItemType Directory -Path $dstAbi -Force }
    CopyTree $abi.FullName $dstAbi
  }
}

$idx = 0
foreach ($aar in $inputs) {
  $idx++
  $unzip = Join-Path $workRoot ('in_' + $idx)
  Expand-ArchiveFile $aar $unzip

  if (-not $manifestWritten) {
    $m = Join-Path $unzip 'AndroidManifest.xml'
    if (Test-Path -LiteralPath $m) {
      Copy-Item -LiteralPath $m -Destination (Join-Path $outDir 'AndroidManifest.xml') -Force
      $manifestWritten = $true
      $manifestSource = $aar
    }
  }

  CopyTree (Join-Path $unzip 'res') $outRes
  CopyTree (Join-Path $unzip 'assets') $outAssets

  CopyJniTree (Join-Path $unzip 'jni') $outJni $abiSet

  $inLibs = Join-Path $unzip 'libs'
  if (Test-Path -LiteralPath $inLibs) {
    $jars = Get-ChildItem -LiteralPath $inLibs -Filter '*.jar' -File -ErrorAction SilentlyContinue
    foreach ($j in $jars) {
      Copy-Item -LiteralPath $j.FullName -Destination (Join-Path $outLibs $j.Name) -Force
    }
  }

  foreach ($name in @('R.txt','public.txt','proguard.txt','consumer-rules.pro')) {
    $p = Join-Path $unzip $name
    if (Test-Path -LiteralPath $p) {
      if (-not (Test-Path -LiteralPath (Join-Path $outDir $name))) {
        Copy-Item -LiteralPath $p -Destination (Join-Path $outDir $name) -Force
      }
    }
  }

  $classesJar = Join-Path $unzip 'classes.jar'
  if (Test-Path -LiteralPath $classesJar) {
    Push-Location $classesExtract
    & $jar.Path xf $classesJar | Out-Null
    Pop-Location
  }
}

if (-not $manifestWritten) {
  Fail 'no AndroidManifest.xml found (use -m to provide one, or ensure first input aar contains it)'
}

$soDirsList = @()
foreach ($d in ($SoDirs -split ';' | Where-Object { $_ -and $_.Trim() })) {
  $dd = Resolve-Base $d
  if (-not (Test-Path -LiteralPath $dd)) { Fail ('-so dir not found: ' + $dd) }
  $soDirsList += $dd
}

foreach ($sd in $soDirsList) {
  if (Test-Path -LiteralPath $sd -PathType Leaf) {
    if ([IO.Path]::GetExtension($sd) -ne '.so') { continue }
    $parentAbi = Get-KnownAbi ((Split-Path -Parent $sd) | Split-Path -Leaf)
    $abiName = $parentAbi
    if (-not $abiName) { $abiName = 'armeabi-v7a' }
    if ($abiSet -and (-not $abiSet.Contains($abiName))) { continue }
    $dstAbi = Join-Path $outJni $abiName
    if (-not (Test-Path -LiteralPath $dstAbi)) { $null = New-Item -ItemType Directory -Path $dstAbi -Force }
    Copy-Item -LiteralPath $sd -Destination (Join-Path $dstAbi ([IO.Path]::GetFileName($sd))) -Force
    continue
  }

  $abiDirs = Get-ChildItem -LiteralPath $sd -Directory -ErrorAction SilentlyContinue
  if ($abiDirs -and $abiDirs.Count -gt 0) {
    foreach ($abi in $abiDirs) {
      if ($abiSet -and (-not $abiSet.Contains($abi.Name))) { continue }
      $dstAbi = Join-Path $outJni $abi.Name
      if (-not (Test-Path -LiteralPath $dstAbi)) { $null = New-Item -ItemType Directory -Path $dstAbi -Force }
      CopyTree $abi.FullName $dstAbi
    }
  } else {
    $soFiles = Get-ChildItem -LiteralPath $sd -Filter '*.so' -File -Recurse -ErrorAction SilentlyContinue
    foreach ($so in $soFiles) {
      $abiName = $null
      $cur = $so.Directory
      while ($cur -and $cur.FullName -and ($cur.FullName.Length -ge $sd.Length)) {
        $maybe = Get-KnownAbi $cur.Name
        if ($maybe) { $abiName = $maybe; break }
        $cur = $cur.Parent
      }
      if (-not $abiName) { $abiName = 'armeabi-v7a' }
      if ($abiSet -and (-not $abiSet.Contains($abiName))) { continue }
      $dstAbi = Join-Path $outJni $abiName
      if (-not (Test-Path -LiteralPath $dstAbi)) { $null = New-Item -ItemType Directory -Path $dstAbi -Force }
      Copy-Item -LiteralPath $so.FullName -Destination (Join-Path $dstAbi $so.Name) -Force
    }
  }
}

$outClassesJar = Join-Path $outDir 'classes.jar'
Push-Location $classesExtract
& $jar.Path cf $outClassesJar . | Out-Null
Pop-Location

$outDirParent = Split-Path -Parent $outFull
if ($outDirParent -and (-not (Test-Path -LiteralPath $outDirParent))) { $null = New-Item -ItemType Directory -Path $outDirParent -Force }
if (Test-Path -LiteralPath $outFull) { Remove-Item -LiteralPath $outFull -Force }

Push-Location $outDir
& $jar.Path cf $outFull . | Out-Null
Pop-Location

Write-Host ('OK: ' + $outFull)
Write-Host ('Manifest: ' + $manifestSource)

Remove-Item -LiteralPath $workRoot -Recurse -Force

param([string]$GameDir, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
if (-not $GameDir) {
    $steamRoots = @(
        (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
        (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -ErrorAction SilentlyContinue).InstallPath
        (Join-Path ${env:ProgramFiles(x86)} 'Steam')
    ) | Where-Object { $_ } | Select-Object -Unique
    $libraries = @($steamRoots)
    foreach ($steamRoot in $steamRoots) {
        $libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraryFile) {
            $contents = Get-Content -LiteralPath $libraryFile -Raw
            foreach ($entry in [regex]::Matches($contents, '"path"\s+"([^"]+)"')) {
                $libraries += $entry.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    $candidates = @($libraries | Select-Object -Unique | ForEach-Object {
        $candidate = Join-Path $_ 'steamapps\common\Balatro'
        if (Test-Path -LiteralPath (Join-Path $candidate 'Balatro.exe')) {
            (Resolve-Path -LiteralPath $candidate).Path
        }
    } | Select-Object -Unique)
    if ($candidates.Count -eq 0) { throw 'Balatro was not found. Install it through Steam, or pass -GameDir "D:\SteamLibrary\steamapps\common\Balatro".' }
    if ($candidates.Count -gt 1) { throw ('Multiple installations found. Use -GameDir to select one: ' + ($candidates -join ', ')) }
    $GameDir = $candidates[0]
}
$game = (Resolve-Path -LiteralPath $GameDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $game 'Balatro.exe'))) { throw 'Balatro.exe was not found.' }
if ($CheckOnly) { Write-Output "Balatro: $game"; return }
if (Get-Process Balatro -ErrorAction SilentlyContinue) { throw 'Please close Balatro before installing.' }
$save = Join-Path $env:APPDATA 'Balatro'
$destination = Join-Path $save 'Mods\Yubalatro'
$dll = Join-Path $game 'version.dll'
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'installation.json')) { throw 'Already installed. Use uninstall.ps1 before reinstalling.' }
if (Test-Path -LiteralPath $destination) { throw 'An existing Yubalatro mod was found; installation stopped to preserve it.' }
if (Test-Path -LiteralPath $dll) { throw 'An existing Lovely loader was found; installation stopped to preserve it.' }
$archive = Join-Path $PSScriptRoot '.cache\lovely-v0.9.0.zip'
New-Item -ItemType Directory -Path (Split-Path $archive) -Force | Out-Null
if (-not (Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/ethangreen-dev/lovely-injector/releases/download/v0.9.0/lovely-x86_64-pc-windows-msvc.zip' -OutFile $archive
}
$expected = '40B994A055EE75E5F2ABA81E7AE06F2C17460E18CC346483089921899FADD1F7'
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) { throw 'Lovely archive hash mismatch.' }
$unpacked = Join-Path $PSScriptRoot '.cache\lovely-v0.9.0'
Expand-Archive -LiteralPath $archive -DestinationPath $unpacked -Force
$backup = Join-Path $PSScriptRoot ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $game -Destination (Join-Path $backup 'game') -Recurse
if (Test-Path -LiteralPath $save) { Copy-Item -LiteralPath $save -Destination (Join-Path $backup 'save') -Recurse }
New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'mod') -Destination $destination -Recurse
Copy-Item -LiteralPath (Join-Path $unpacked 'version.dll') -Destination $dll
$record = [ordered]@{
    game = $game; mod = $destination; backup = $backup
    loader_sha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    original_exe_sha256 = (Get-FileHash -LiteralPath (Join-Path $backup 'game\Balatro.exe') -Algorithm SHA256).Hash
    lovely_version = '0.9.0'
}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'installation.json') -Encoding UTF8
Write-Output "Installed: $destination"
Write-Output "Backup: $backup"

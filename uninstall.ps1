$ErrorActionPreference = 'Stop'
if (Get-Process Balatro -ErrorAction SilentlyContinue) { throw 'Please close Balatro before uninstalling.' }
$recordPath = Join-Path $PSScriptRoot 'installation.json'
$record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
$expectedMod = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Balatro\Mods\Yubalatro'))
$actualMod = [IO.Path]::GetFullPath($record.mod)
if ($actualMod -ne $expectedMod) { throw 'Unexpected mod path.' }
$workspace = (Resolve-Path -LiteralPath $PSScriptRoot).Path.TrimEnd('\') + '\'
$backup = [IO.Path]::GetFullPath($record.backup)
if (-not $backup.StartsWith($workspace, [StringComparison]::OrdinalIgnoreCase)) { throw 'Backup must be inside the workspace.' }
$disabled = Join-Path $backup ('disabled-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $disabled | Out-Null
if (Test-Path -LiteralPath $actualMod) { Move-Item -LiteralPath $actualMod -Destination (Join-Path $disabled 'Yubalatro') }
$dll = Join-Path ([IO.Path]::GetFullPath($record.game)) 'version.dll'
if ((Test-Path -LiteralPath $dll) -and ((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -eq $record.loader_sha256)) {
    $otherMods = @(Get-ChildItem -LiteralPath (Split-Path $actualMod) | Where-Object { $_.Name -ne 'lovely' -and ($_.PSIsContainer -or $_.Extension -eq '.zip') })
    if ($otherMods.Count -eq 0) { Move-Item -LiteralPath $dll -Destination (Join-Path $disabled 'version.dll') }
}
Move-Item -LiteralPath $recordPath -Destination (Join-Path $disabled 'installation.json')
Write-Output 'Yubalatro uninstalled. Current saves and progress were preserved.'

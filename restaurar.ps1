# Reconstruye lo que el repositorio guarda partido: la ISO, los .AFS (desde _partes\) y ps2EntryRunner.exe (Release).
# Uso tras clonar:  powershell -NoProfile -File restaurar.ps1
# Para el .exe hace falta GitHub CLI con sesion iniciada (gh auth login); el repositorio es privado.
$ErrorActionPreference = 'Stop'
$J = $PSScriptRoot
Set-Location $J
$env:PATH = "$J\..\herramientas\gh\bin;$env:PATH"
foreach ($dir in Get-ChildItem _partes -Directory -ErrorAction SilentlyContinue) {
    $rel = $dir.Name.Replace('__', '\')
    $man = Join-Path '_partes' "$($dir.Name).sha256"
    if ((Test-Path -LiteralPath $rel) -and (Test-Path $man) -and ((Get-FileHash -LiteralPath $rel -Algorithm SHA256).Hash -eq (Get-Content $man -Raw).Trim())) { Write-Host "  ya esta: $rel"; continue }
    Write-Host "  uniendo $rel"
    New-Item -ItemType Directory -Force (Split-Path -Parent (Join-Path $J $rel)) | Out-Null
    $out = [IO.File]::Create((Join-Path $J $rel))
    try { foreach ($p in Get-ChildItem $dir.FullName -Filter *.part | Sort-Object Name) { $b = [IO.File]::ReadAllBytes($p.FullName); $out.Write($b, 0, $b.Length) } } finally { $out.Dispose() }
    if ((Test-Path $man) -and ((Get-FileHash -LiteralPath $rel -Algorithm SHA256).Hash -ne (Get-Content $man -Raw).Trim())) { throw "Suma de comprobacion incorrecta: $rel" }
}
$exe = 'PS2Recomp\build_windows\ps2xRuntime\ps2EntryRunner.exe'
if (-not (Test-Path $exe) -or ((Get-FileHash $exe -Algorithm SHA256).Hash -ne (Get-Content ps2EntryRunner.sha256 -Raw).Trim())) {
    Write-Host '  descargando ps2EntryRunner.exe del Release'
    $tmp = Join-Path $env:TEMP 'pes_exe'
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    gh release download ejecutable -p ps2EntryRunner.zip -D $tmp
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo descargar el ejecutable (gh auth login?)' }
    New-Item -ItemType Directory -Force (Split-Path -Parent $exe) | Out-Null
    Expand-Archive (Join-Path $tmp 'ps2EntryRunner.zip') -DestinationPath (Split-Path -Parent $exe) -Force
}
New-Item -ItemType Directory -Force PES2014_PS2_extracted\mc0, PES2014_PS2_extracted\mc1, logs | Out-Null
Write-Host 'OK: listo para jugar con jugar.bat'

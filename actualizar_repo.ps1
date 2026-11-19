# Actualiza el repositorio privado de GitHub con el contenido de esta carpeta (PES2014_JUGAR).
# Uso:  powershell -NoProfile -File actualizar_repo.ps1 [-Mensaje "texto del commit"] [-SinPush]
# - Los archivos de mas de 95 MB (ISO, .AFS) no caben en GitHub: se parten en trozos de 90 MB dentro de _partes\
#   (solo si cambiaron; restaurar.ps1 los vuelve a juntar).
# - ps2EntryRunner.exe (231 MB) va comprimido como asset del Release "ejecutable" (solo si cambio).
# - Se excluyen partidas (mc0/mc1) y logs (ver .gitignore).
param([string]$Mensaje = '', [switch]$SinPush)
$ErrorActionPreference = 'Stop'
$J = $PSScriptRoot
Set-Location $J
$env:PATH = "$J\..\herramientas\mingit\cmd;$J\..\herramientas\gh\bin;$env:PATH"
$TROZO = 90MB
$EXE = 'PS2Recomp\build_windows\ps2xRuntime\ps2EntryRunner.exe'
$GRANDES = @('rea\PES 2014.iso', 'PES2014_PS2_extracted\0_SOUND.AFS', 'PES2014_PS2_extracted\0_TEXT.AFS',
             'PES2014_PS2_extracted\Q_SOUND.AFS', 'PES2014_PS2_extracted\S_SOUND.AFS')

function Sha($f) { (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash }

# 0) Aviso si aparece otro archivo grande no previsto (GitHub rechaza > 100 MB).
Get-ChildItem -Recurse -File -Force | Where-Object {
    $_.Length -gt 95MB -and $_.FullName -notlike "$J\.git\*" -and $_.FullName -notlike "$J\_partes\*" -and $_.FullName -notlike "$J\logs\*"
} | ForEach-Object {
    $rel = $_.FullName.Substring($J.Length + 1)
    if ($rel -ne $EXE -and $GRANDES -notcontains $rel) { throw "Archivo grande no previsto: $rel. Anadelo a `$GRANDES en actualizar_repo.ps1 y a .gitignore." }
}

# 1) Partir los archivos grandes (solo si cambiaron).
New-Item -ItemType Directory -Force _partes | Out-Null
foreach ($rel in $GRANDES) {
    if (-not (Test-Path -LiteralPath $rel)) { Write-Host "  (falta $rel, se omite)"; continue }
    $nombre = $rel.Replace('\', '__')
    $dir = Join-Path '_partes' $nombre
    $man = Join-Path '_partes' "$nombre.sha256"
    $h = Sha $rel
    if ((Test-Path $man) -and ((Get-Content $man -Raw).Trim() -eq $h)) { continue }
    Write-Host "  partiendo $rel"
    if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
    New-Item -ItemType Directory -Force $dir | Out-Null
    $in = [IO.File]::OpenRead((Resolve-Path -LiteralPath $rel).Path)
    try {
        $buf = New-Object byte[] (4MB); $n = 0
        while ($in.Position -lt $in.Length) {
            $out = [IO.File]::Create((Join-Path (Resolve-Path $dir).Path ('{0:D3}.part' -f $n)))
            try { $resto = [Math]::Min($TROZO, $in.Length - $in.Position)
                  while ($resto -gt 0) { $k = $in.Read($buf, 0, [int][Math]::Min($buf.Length, $resto)); $out.Write($buf, 0, $k); $resto -= $k } }
            finally { $out.Dispose() }
            $n++
        }
    } finally { $in.Dispose() }
    Set-Content -Path $man -Value $h -Encoding ascii
}

# 2) Ejecutable: zip como asset del Release "ejecutable" (solo si cambio).
$exeSha = Sha $EXE
$exeShaFile = 'ps2EntryRunner.sha256'
$subirExe = -not ((Test-Path $exeShaFile) -and ((Get-Content $exeShaFile -Raw).Trim() -eq $exeSha))
if ($subirExe -and -not $SinPush) {
    # GitHub no permite crear un Release en un repositorio vacio: primer commit con lo minimo.
    $ErrorActionPreference = 'Continue'; git rev-parse --verify -q HEAD *> $null; $vacio = ($LASTEXITCODE -ne 0); $ErrorActionPreference = 'Stop'
    if ($vacio) {
        git add .gitignore actualizar_repo.ps1 restaurar.ps1
        git commit -q -m 'Scripts de actualizacion y restauracion'
        git push -q -u origin HEAD; if ($LASTEXITCODE -ne 0) { throw 'Fallo el push inicial' }
    }
    Write-Host "  comprimiendo y subiendo el ejecutable al Release"
    $zip = Join-Path $env:TEMP 'ps2EntryRunner.zip'
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Compress-Archive -LiteralPath $EXE -DestinationPath $zip -CompressionLevel Optimal
    $ErrorActionPreference = 'Continue'   # gh escribe en stderr si el release no existe; se comprueba $LASTEXITCODE
    gh release view ejecutable *> $null
    if ($LASTEXITCODE -ne 0) { gh release create ejecutable --title 'Ejecutable del juego' --notes 'ps2EntryRunner.exe comprimido (restaurar.ps1 lo descarga)'; if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear el Release' } }
    gh release upload ejecutable $zip --clobber
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la subida del ejecutable' }
    Set-Content -Path $exeShaFile -Value $exeSha -Encoding ascii
}

# 3) Commit y push (por tandas para no pasar de 2 GB por push).
if (-not (Test-Path .git)) { throw 'No hay repositorio: ejecuta primero la creacion inicial.' }
if (-not $Mensaje) { $Mensaje = 'Actualizacion ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') }
$tandas = @(Get-ChildItem _partes -Directory | Sort-Object Name)
foreach ($t in $tandas) {
    git add -A -- "_partes/$($t.Name)" "_partes/$($t.Name).sha256"
    if (git status --porcelain -- _partes) {
        git commit -q -m "Partes de $($t.Name.Replace('__','/'))"
        if (-not $SinPush) { git push -q origin HEAD; if ($LASTEXITCODE -ne 0) { throw 'Fallo el push' } }
    }
}
git add -A
if (git status --porcelain) { git commit -q -m $Mensaje }
if (-not $SinPush) { git push -q origin HEAD; if ($LASTEXITCODE -ne 0) { throw 'Fallo el push' } }
Write-Host "OK: repositorio actualizado ($Mensaje)"

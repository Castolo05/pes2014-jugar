# Lanza PES 2014 (port nativo PS2Recomp) en Windows. Equivale a jugar.sh de Linux.
# Uso: doble clic en jugar.bat (o desde PowerShell: .\jugar.ps1 [argumentos extra para el juego]).
#
# Controles y pantalla: configurar_controles.exe (guarda controles.cfg junto a este archivo). Sin ese archivo: flechas o
# WASD = cruceta, X/Espacio = Cruz, C/Esc = Círculo, Z = Cuadrado, V = Triángulo, Q/E = L1/R1, Shift izq./der. = L2/R2,
# Enter = Start, Tab = Select.
#
# Las variables de entorno mandan sobre controles.cfg, como en Linux: PES_FULLSCREEN (0 ventana, 1 sin bordes, 2 completa
# real), PES_FPS_LIMIT, PES_FILTER, PES_FS_RES, PES_RENDER_SCALE, PES_STRETCH, PES_GS_GPU=0 (dibujar en CPU),
# PES_FRAME_SKIP=1, PES_IOP_THREAD=0, PES_VIDEO_MODE=pal|ntsc. Lista completa: docs/PROYECTO_PES2014_COMPLETO.md §3.
$ErrorActionPreference = 'Stop'
$DIR = $PSScriptRoot
$cfg = Join-Path $DIR 'controles.cfg'
$exe = Join-Path $DIR 'PS2Recomp\build_windows\ps2xRuntime\ps2EntryRunner.exe'

function Ajuste([string]$nombre) {
    # Última línea AJUSTE_<nombre>=valor de controles.cfg (sin espacios ni \r), o '' si no está.
    if (-not (Test-Path -LiteralPath $cfg)) { return '' }
    $valor = ''
    foreach ($linea in [System.IO.File]::ReadAllLines($cfg)) {
        if ($linea.StartsWith("AJUSTE_$nombre=")) { $valor = $linea.Substring($nombre.Length + 8).Trim() }
    }
    return $valor
}
function Def([string]$var, [string]$valor) {
    # Pone la variable solo si no viene ya del entorno.
    if (-not [Environment]::GetEnvironmentVariable($var)) { [Environment]::SetEnvironmentVariable($var, $valor) }
}
function Env([string]$var) { [Environment]::GetEnvironmentVariable($var) }

if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host "No encuentro el juego compilado: $exe" -ForegroundColor Red
    Write-Host 'Compílalo con PES2014_PROYECTO\tools\windows\compilar.bat (en PES2014_JUGAR se copia con sincronizar_jugar.bat).'
    exit 1
}

Def 'PS2_CD_IMAGE' (Join-Path $DIR 'rea\PES 2014.iso')
$env:PES_REAL_ADXF = '1'
Def 'PES_GS_GPU' '1'
if (-not (Env 'PES_FPS_LIMIT') -and (Ajuste 'FPS') -eq '30') { $env:PES_FPS_LIMIT = '30' }
if (-not (Env 'PES_STRETCH') -and (Ajuste 'IMAGEN') -eq 'estirada') { $env:PES_STRETCH = '1' }
# Salto de cuadros: apagado por defecto (se dibujan todos los cuadros).
if (-not (Env 'PES_FRAME_SKIP') -and (Ajuste 'SALTO_CUADROS') -eq 'si') { $env:PES_FRAME_SKIP = '1' }
Def 'PES_FRAME_SKIP' '0'
if ((Env 'PES_FRAME_SKIP') -eq '1') { Def 'PES_FRAME_SKIP_PENDING' '2'; Def 'PES_FRAME_MAXSKIP' '1' }
# Modo de vídeo: NTSC (60 Hz) directo salvo AJUSTE_MODO_VIDEO=preguntar.
if (-not (Env 'PES_VIDEO_MODE') -and (Ajuste 'MODO_VIDEO') -ne 'preguntar') {
    $env:PES_VIDEO_MODE = 'ntsc'
    Def 'PES_NTSC_DIRECTO' '1'
}
# Pantalla: en Windows la pantalla completa real siempre es posible (Windows restaura el escritorio al cerrar).
if (-not (Env 'PES_FULLSCREEN')) {
    if ((Ajuste 'PANTALLA') -eq 'ventana') { $env:PES_FULLSCREEN = '0' } else { $env:PES_FULLSCREEN = '2' }
}
$r = Ajuste 'RENDER'; if (-not (Env 'PES_RENDER_SCALE') -and $r) { $env:PES_RENDER_SCALE = $r }
Def 'PES_RENDER_SCALE' '1'
$r = Ajuste 'RESOLUCION'; if (-not (Env 'PES_FS_RES') -and $r) { $env:PES_FS_RES = $r }
Def 'PES_FS_RES' '1024x768'
if (-not (Env 'PES_FILTER')) {
    switch (Ajuste 'FILTRO') { 'nitido' { $env:PES_FILTER = '0' } 'extra' { $env:PES_FILTER = '2' } default { $env:PES_FILTER = '1' } }
}
# Filtro «extra» = bicúbico + suavizado de bordes FXAA a la resolución del juego (PES_AA=1; coste dentro del ruido de medida).
if (-not (Env 'PES_AA') -and (Ajuste 'FILTRO') -eq 'extra') { $env:PES_AA = '1' }
if (-not (Env 'PES_SHOW_FPS') -and (Ajuste 'FPS_PANTALLA') -eq 'si') { $env:PES_SHOW_FPS = '1' }
Def 'PES_SHOW_FPS' '0'
Def 'PES_FPS_LIMIT' '60'
Def 'PES_STRETCH' '0'
Def 'PES_IOP_THREAD' '1'
if (Test-Path -LiteralPath $cfg) { Def 'PES_KEYMAP' $cfg }

# Registro y diagnóstico (igual que jugar.sh): logs\jugar.log (el anterior en jugar.anterior.log); si la partida anterior
# falló, sus volcados de RAM y su registro se guardan en logs\diagnostico\fallo_<fecha>\.
$logs = Join-Path $DIR 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
Def 'PES_DIAG_DIR' (Join-Path $logs 'diagnostico')
Def 'PES_CRASH_DUMP' (Env 'PES_DIAG_DIR')
$diag = Env 'PES_DIAG_DIR'
New-Item -ItemType Directory -Force -Path $diag | Out-Null
$log = Join-Path $logs 'jugar.log'
if ((Test-Path (Join-Path $diag 'ram_excepcion.bin')) -or (Test-Path (Join-Path $diag 'ram_colgado.bin'))) {
    $fallo = Join-Path $diag ('fallo_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    New-Item -ItemType Directory -Force -Path $fallo | Out-Null
    Move-Item -Path (Join-Path $diag 'ram_*.bin') -Destination $fallo -Force
    if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log -Destination $fallo }
    Write-Host "Aviso: la partida anterior falló; sus datos de diagnóstico están en $fallo" -ForegroundColor Yellow
} else {
    Remove-Item -Path (Join-Path $diag 'ram_*.bin') -Force -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $log) { Move-Item -LiteralPath $log -Destination (Join-Path $logs 'jugar.anterior.log') -Force }

Set-Location -LiteralPath (Join-Path $DIR 'PES2014_PS2_extracted')
Write-Host "PES 2014 arrancando... (registro en $log)"
$extra = ($args | ForEach-Object { '"' + $_ + '"' }) -join ' '
# cmd hace la redirección: guarda la salida tal cual (UTF-8), con stdout y stderr juntos como en Linux.
# (Process en vez de llamar a cmd directamente: PowerShell 5.1 y 7 citan distinto los argumentos de programas externos.)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = Join-Path $env:SystemRoot 'System32\cmd.exe'
$psi.Arguments = '/d /c ""' + $exe + '" SLES_556.76 ' + $extra + ' > "' + $log + '" 2>&1"'
$psi.UseShellExecute = $false
$psi.WorkingDirectory = (Get-Location).Path
$proc = [System.Diagnostics.Process]::Start($psi)
$proc.WaitForExit()
$codigo = $proc.ExitCode
if ($codigo -ne 0) {
    Write-Host "El juego terminó con el código $codigo. Mira $log" -ForegroundColor Yellow
    Get-Content -LiteralPath $log -Tail 15 -Encoding UTF8 | ForEach-Object { Write-Host "  $_" }
    Read-Host 'Pulsa Enter para cerrar'
}
exit $codigo
